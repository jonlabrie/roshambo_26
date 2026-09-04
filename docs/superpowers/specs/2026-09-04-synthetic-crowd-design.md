# Synthetic Crowd — Design

**Date:** 2026-09-04
**Status:** Approved in conversation (owner, 2026-09-04) — all three §11 decisions taken as recommended.
**Program context:** Not on the [[friends-family-baseline]] board. This is the instrument that
lets the game's premise be tested at all: the World Throw is the crowd's plurality, and no
deployed environment has ever had a crowd ([[world-throw]] § As-built). Everything on the
social-loop list (spectacle at the reveal, gifting, visiting) stacks on top of a loop that has
not yet been played once.

**Question** (owner, 2026-09-04): the play loop feels thin — is a synthetic crowd the way to
find out whether it is, and what would it tell us?

**Short answers:**

1. **It is two small tools, not one system.** A pure `SyntheticCrowd` module the live server
   can merge into each round's tally behind env config, and an offline simulator that runs the
   same module through thousands of rounds in milliseconds with no database.
2. ⚠ **The bots must be structured, not random.** A uniform crowd yields a random plurality,
   which is the pre-2026-08-16 defect wearing a costume. Archetypes come from the RPS literature
   and are a stated hypothesis about a Roblox crowd, to be recalibrated from real rounds.
3. **Bots enter the tally and never reach settlement.** No fake users, no leaderboard rows, no
   presence. That falls out of the seam chosen in §1 rather than needing a filter.
4. **It answers six questions** (§7), the first of which is whether crowd-reading is fun. That
   one takes an afternoon and one person.

---

## 0. Two things called "crowd" — this spec builds one

- **Tally crowd** — throws that count toward the World Throw and appear in the reveal's
  distribution. No bodies. **This spec.**
- **Visible crowd** — NPC avatars in the arena. A different project with different costs
  (rendering budget on the A13, animation, moderation of names). **Out of scope**, and not a
  prerequisite: numbers on the reveal card are what make the world feel populated.

## 1. The seam: merge in the engine, not in `pickWorldThrow`

The obvious hook is the `pickWorldThrow(roundCount, counts)` callback at the composition root
(`server/src/index.ts`). **It is the wrong seam**, because the engine emits `counts` in
`RoundClosedEvent` and settlement builds the persisted `Round.distribution` from them
(`Settlement.buildDistribution`). Bots added inside the picker would decide the World Throw and
then vanish from the distribution the player is shown, so the reveal card would display a
plurality that disagrees with the throw. The crowd is the world; it must appear in the world's
distribution.

So the merge happens in `RoundEngine` at the LOCK→REVEAL transition:

```
humanCounts = countThrows()                 -- as today
crowdCounts = cfg.crowd ? cfg.crowd.throws(roundCount) : {R:0,P:0,S:0}
counts      = humanCounts + crowdCounts
worldThrow  = cfg.pickWorldThrow(roundCount, counts)
cfg.crowd?.observe(worldThrow)             -- the bots learn what the world did
emit roundClosed { roundId, worldThrow, counts, crowdCounts, throws }
```

`throws` (the per-participant map) stays human-only, and it is the only thing settlement
iterates. **That is why bots never reach `resolveUser`, `PlayerRound`, `BankEvent`, sessions
or presence** — not a filter, just the shape of the data. `crowdCounts` travels alongside so
settlement can record how much of the world was synthetic (§3).

`EngineConfig` gains one optional field:

```ts
crowd?: {
    throws(roundCount: number): Record<Throw, number>;
    observe(worldThrow: Throw): void;
}
```

Absent → identical behaviour to today. The engine's existing timing, phases and the
`revealPending` handshake in `socketAdapter` are untouched; crowd throws are computed
synchronously at close, after the LOCK-phase Roblox flush has landed, so ordering cannot
change.

## 2. The crowd module

`server/src/engine/SyntheticCrowd.ts`, pure, dependency-injected randomness (a seeded PRNG
lives in-repo — mulberry32 or equivalent, ~10 lines — no package).

**A crowd is a bag of policies.** Each bot is one `Policy` plus a small memory: its own last
throw, its own last result against the world, and the last World Throw. `throws()` asks each
bot for a throw and tallies; `observe(worldThrow)` scores every bot with the shared
`calculateResult` and updates its memory. Bots have no pot and never bank; a bot's "result" is
only the input to its next decision.

**Archetypes** (each takes a strength `p`; with probability `1 − p` the bot throws uniformly,
so `p` is the readability dial *within* an archetype and the mix is the dial *across* them):

| id | behaviour | basis |
|---|---|---|
| `random` | uniform | the noise floor; also the null hypothesis |
| `wsls` | after WIN repeat own throw; after LOSS shift clockwise R→S→P→R; after SAFE shift with half strength | Wang, Xu & Zhou 2014, *Sci. Rep.* 4:5830 — win-stay / lose-shift-clockwise, and the "social cycling" it produces at population level |
| `counter` | throw what beats the last World Throw | the naive HUD reader |
| `conform` | throw the last World Throw | the SAFE hedge; conformity is a real style per [[world-throw]] |
| `rocky` | first throw R with 0.5; thereafter never a third repeat; mild rock lean | the novice model; folk-documented rock-first bias |

**Default mix — a hypothesis, tuned by the simulator before it is trusted (§7 Q0):**
`wsls:35, counter:20, conform:15, rocky:10, random:20`, all at `p = 0.7`. The target the
simulator tunes toward: a simple, teachable human rule beats the crowd clearly (BEAT WORLD
≥ 45%) while a blind human stays at 33%, and no rule exceeds ~60% (a crowd that is trivially
beaten is not a world). Those thresholds are proposed here so they are pre-registered rather
than fitted afterwards; the owner may move them.

**Determinism.** Same seed + same human throws → same crowd, round for round. Bot memory
depends on the decided World Throw, which depends on the humans, so a run is reproducible only
given the human input. With zero humans it is fully deterministic — which is exactly the
predictable-demo property TEST_MODE provides today (§7 Q6). Bot memory is not persisted; a
restart re-seeds. Acceptable: the crowd is an instrument, not state.

**Within-round reactivity: none, deliberately.** Bots cannot see the humans' throws in the
current round (nobody can — throws are simultaneous). At small N a human's own throw shifts
the plurality they are trying to beat; that is a property of the game, not of the bots, and
it is one of the things §7 Q2 measures.

## 3. What players see — `totalPlayers` counts the world

Every consumer of `totalPlayers` is a display of *how big was the world this round*: the
ledger card's `N PLAYERS` (`LedgerController.client.luau`), the stats board's `PLAYERS`
figure (`StatsBoardModel.luau`), `playersNow` on `BoardData` (`main.server.luau`), the
`RoundCoordinator` log line. A card reading `R 40% P 35% S 25% | 3 PLAYERS` is incoherent
when 30 bots produced the percentages. So:

- `totalPlayers` = humans + synthetic (the size of the world the player faced).
- `Round.synthetic` (new field, `default: 0`, so every historical row is honest) = the bot
  count. Humans = `totalPlayers − synthetic`, always recoverable.
- `synthetic` rides additively on `GlobalResult`, the `reveal` payload, `ResultsStore`, the
  `/api/v1` results and the startup tape seed. Clients ignore unknown fields; nothing on
  either client changes in this spec.

⚠ **This is owner decision 1 (§11).** It tells a kid "34 players" when four humans are
present. The alternative — `totalPlayers` stays human-only and a new `worldSize` carries the
sum — keeps the label literal at the cost of the card contradicting itself, and of touching
both clients. Recommendation: count the world, record `synthetic`, and revisit the label's
*word* (PLAYERS vs THROWS) as copy, not as data.

`buildDistribution(counts, total)` already takes the total as an argument; settlement passes
`sum(counts)` instead of `throws.size`. Those were equal until now.

## 4. Settlement, stats and the gates this opens

- Settlement iterates `throws` only → humans only. Unchanged code path.
- `PlayerRound`, `BankEvent`, `StreakEvent`, milestones, sessions, presence: humans only,
  by construction.
- `Round.distribution` and the `globalDistribution` aggregate (`socketAdapter`) include the
  crowd. Correct: they describe the world.
- **The stats room's READ column** (`BEAT WORLD`, gated on TEST_MODE off — [[stats-room]])
  becomes meaningful in any environment running the crowd. YIELD and NERVE likewise stop
  measuring who spotted a three-beat cycle.
- `WORLD_THROW_MIN_PARTICIPANTS` is trivially satisfied whenever `CROWD_SIZE ≥ 5`. Intended:
  a crowd *is* a world. The floor keeps protecting environments with no crowd configured.

## 5. Configuration and environments

House pattern: config over commits (round durations, min-participants). Three env vars, read at
the composition root:

| var | meaning | default |
|---|---|---|
| `CROWD_SIZE` | bot count; `0` disables | `0` |
| `CROWD_MIX` | `id:weight,…` over the archetypes in §2; weights normalised; unknown id or non-positive weight refuses at boot with a clear log line | the §2 default |
| `CROWD_SEED` | PRNG seed; unset → random seed, logged, so a run can still be reproduced | unset |

**TEST_MODE guard.** `CROWD_SIZE > 0` with `TEST_MODE=true` logs a warning and disables the
crowd. A cycled World Throw with a plurality distribution that disagrees with it is the exact
lie §1 exists to prevent.

**Per-round log line** so a Studio session can read what the world did:
`[CROWD] round 1187 humans 3 crowd 30 | R 12 P 15 S 6 → P`.

**Environments.** Prod (`playroshambo.com`) is untouched; whether the PWA demo ever leaves
TEST_MODE is a separate owner call. Dev is the App Runner service `roshambo_server_dev`;
turning the crowd on there is an env change on the service (`TEST_MODE=false`,
`CROWD_SIZE=30`, optional seed), not a commit — and it changes the dev backend under any live
Studio session, so it is announced before it is flipped, and confirmed with the query in
`CLAUDE.md` rather than assumed.

## 6. The offline simulator

`server/src/sim/` — pure TypeScript over `GameRules` + `SyntheticCrowd`, run with
`npm run sim -- --rounds 20000 --crowd 30 --mix … --seed 1 [--json]`. No Mongo, no engine
timers; it calls `deriveWorldThrow` directly. Thousands of rounds run in milliseconds.

**A human is just another policy with a pot.** The sim's human players reuse the §2 policy
interface, plus two the crowd does not need — `second` (counter the counter: throw what beats
what beats the last World Throw) and `oracle` (reads every bot's memory, predicts the plurality
exactly, and throws what beats it; the ceiling on readability, unreachable by a human) — and a bank rule: `ride` (never bank; reports the best-pot
distribution), `rung:k` (bank at rung k), `ratio` (the log-utility rule from
`2026-08-26-partial-banking-design.md`).

**Reporters** (each a pure function over the round log, tested on tiny inputs):

- **Win rate per human policy** with a binomial interval — the readability table.
- **Plurality autocorrelation and rotation period** — does the counter-heavy crowd cycle, and
  how fast ([[world-throw]]'s equilibrium claim).
- **Pot trajectories per bank rule** — median and tail of banked points over N rounds; whether
  3ⁿ produces decisions at the observed win rate or pots that never grow / never end.
- **Blind-field spread** — twenty identical `random` humans over 360 rounds, max ÷ median of
  points banked, repeated across seeds. This is the backlog's "2.5× by chance alone" concern,
  measured.
- **Effective N** — win rate of `counter` as a function of `CROWD_SIZE` at fixed mix, to find
  where the human's own throw stops moving the plurality (§7 Q2).

Output is a stdout table; `--json` for anything that wants to chart it.

## 7. The experiments — what each tool can tell us

| # | question | tool | pre-registered reading |
|---|---|---|---|
| Q0 | is the default mix readable-but-not-trivial? | sim | tune until §2 targets hold; record the mix that does |
| **Q1** | **is crowd-reading fun?** | live, dev, one person, ~20 rounds with the HUD | BEAT WORLD ≥ 45% → the loop has the skill it claims; ≈33% → the crowd is too noisy, or the last-five HUD shows the wrong thing, or the premise needs work — and the sim distinguishes the first from the other two |
| Q2 | what N feels like "the world"? | sim (effective N) then live at 2–3 sizes | the smallest `CROWD_SIZE` at which the human's throw no longer moves `counter`'s win rate by more than a few points is the launch bot count for a near-empty server |
| Q3 | is the pot math tuned? | sim (bank rules) | the banking spec's parked "is p_w really 0.30, does the ratio bite" gets numbers at the readable mix |
| Q4 | do READ / YIELD / NERVE discriminate? | sim (blind-field spread) + live READ column | if identical blind players spread 2.5× at 360 throws, the standings floor moves before the stats room is trusted |
| Q5 | does the equilibrium rotate? | sim (autocorrelation) | a counter-heavy crowd shows a period; a `second`-order human beats a first-order one |
| Q6 | can dev leave TEST_MODE? | live | seeded crowd, zero humans → deterministic sequence; the demo keeps its predictability and the real rule is exercised |

Q1 is the one that matters and the cheapest to run. It is also the one whose result is a
judgement (the owner's own twenty minutes), which is why the numeric threshold is written
down first.

## 8. What it cannot tell us, and the follow-on it sets up

The archetypes are a hypothesis about how a ten-year-old on a phone throws in a 60-second
round with history on screen. Real crowds will differ. **The saving grace is already in the
schema:** `Round.distribution` and `Round.synthetic` are persisted every round, so once real
humans play against a crowd, the human component of every round is recoverable. Follow-on,
not in this spec: a fitter that estimates the mix from real rounds (`Round` rows plus
`PlayerRound.playerThrow` sequences) and writes back a calibrated `CROWD_MIX`. The module's
data-first shape is chosen so that fitter is a script over existing rows, not a redesign.

## 9. Testing (TDD, Vitest, `server/`)

- **PRNG**: known-answer sequence for a fixed seed.
- **Each archetype**: given a memory state and a fixed seed, the empirical throw distribution
  over many draws matches its definition at strength `p` (exact assertions — deterministic).
- **Mix parsing**: normalises weights; refuses unknown ids and non-positive weights with the
  message the boot log will print.
- **Crowd module**: `throws()` tallies to `CROWD_SIZE`; `observe()` updates every bot's memory
  with `calculateResult`; same seed + same observed sequence → identical output.
- **Engine merge**: `counts` = human + crowd; `throws` excludes bots; `observe` receives the
  decided World Throw; no `crowd` → today's behaviour byte-for-byte (existing suite).
- **Composition root**: TEST_MODE guard disables the crowd and logs; env parsing.
- **Settlement**: `totalPlayers` and `synthetic` per §3; distribution built from merged counts;
  only human entries settled (existing DB-free tests via `buildCounterUpdate` pattern).
- **Sim reporters**: each on a hand-built five-round log with a known answer; one end-to-end
  smoke at the default mix asserting the `random` human's win rate to the exact deterministic
  value for a fixed seed.

No shared-fixture changes: the Luau side never derives the World Throw
([[duplicated-server-constants]] — the gap is by design).

## 10. Out of scope

- Bot avatars in the arena (§0).
- Bots on any board, in presence, or in the `banzuke`.
- Persisting bot memory across restarts.
- Any client change. The one visible effect is the PLAYERS figure counting the world (§3).
- Turning prod out of TEST_MODE.
- The mix fitter (§8).

## 11. Owner decisions — all three DECIDED as recommended (owner, 2026-09-04: "yes to those three")

1. **Does `totalPlayers` count the crowd?** Recommendation: yes, with `synthetic` recorded
   (§3). Alternative: keep it human-only and add `worldSize`, at the cost of a self-contradicting
   reveal card and two client edits.
2. **The Q1 threshold.** 45% BEAT WORLD over ~20 rounds is proposed as "readable". It is a
   small sample by design — this is a feel test with a number attached, not a measurement.
3. **Dev's standing config after Q0.** Recommendation: once the sim lands a readable mix, dev
   runs `TEST_MODE=false`, `CROWD_SIZE=30` permanently, so every Studio session from then on
   plays the real rule. Prod stays as it is until the owner says otherwise.

## Raw layer

- `server/src/engine/RoundEngine.ts` (LOCK→REVEAL transition, `EngineConfig`,
  `RoundClosedEvent`), `server/src/engine/Settlement.ts` (`buildDistribution`, `settleRound`),
  `server/src/models/Round.ts`, `server/src/engine/ResultsStore.ts`,
  `server/src/transports/socketAdapter.ts` (reveal payload), `server/src/routes/apiV1.ts`
  (results), `server/src/index.ts` (`makeEngine`, env parsing, tape seed).
- Consumers of `totalPlayers`: `roblox/src/client/LedgerController.client.luau`,
  `roblox/src/shared/StatsBoardModel.luau`, `roblox/src/server/main.server.luau` (`playersNow`),
  `roblox/src/server/RoundCoordinator.luau`.
- Rule authority: `shared-fixtures/game-rules.json` § `worldThrowDerivation` (unchanged).
- Related specs: `2026-08-26-partial-banking-design.md` (the parked tuning question),
  `2026-08-18-player-measurement-design.md` (the 360-throw floor and what READ measures).
- Literature: Wang, Xu, Zhou, "Social cycling and conditional responses in the
  Rock-Paper-Scissors game", *Scientific Reports* 4:5830 (2014).
