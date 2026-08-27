---
shelf: world
updated: 2026-08-27
---

# The Core Loop

**Read this first to understand what Roshambo actually is.** The foundations used to live
only in `CLAUDE.md` and in code; they belong here (owner, 2026-08-16). The opponent — and
why this is a game of skill — is [[world-throw]]. Timing and HUD are [[round-and-hud]].

## The shape of it

Every round, every player throws R, P or S. The server settles them all against a single
**World Throw** — the majority of what the players threw — so one throw beats the whole
world at once. That is the product: *you against the world*, not you against a bot.

## The three outcomes

Authority: `shared-fixtures/game-rules.json`. Three implementations are gated against that
fixture in CI (`server/src/engine/GameRules.ts` authoritative, `roblox/src/shared/
GameRules.luau`, `src/lib/gameRules.ts`), so drift fails the build rather than being a
promise to keep them in sync.

| You throw | vs the World | Result | Pot | Streaks |
|---|---|---|---|---|
| the throw that **beats** the world | | **WIN** | 0→1, then **×3** | +1 |
| the **same** as the world | | **SAFE** | preserved | reset to 0 |
| the throw the world **beats** | | **LOSS** | **forfeited** | reset to 0 |

Note the spec/code divergence: `requirements.md` says matching the world is a LOSS; the
code makes it SAFE, and SAFE is the design (it is the hedge that makes crowd-conformity a
real strategy — see [[world-throw]]).

Pot runs **3ⁿ**: 0 → 1 → 3 → 9 → 27 → 81 → …

## The decision: Bank or Stake

This is the only choice the player makes beyond the throw itself, and it is where
judgement lives.

- **Stake** — leave the pot riding. It triples on the next WIN, survives a SAFE, and is
  wiped by a LOSS.
- **Bank** — convert the pot into `totalPoints`, permanently.
- **Bank down a rung** — drop the pot to any lower rung of the ladder and bank the difference,
  keeping the rest riding. ⚠ **SERVER ONLY as of 2026-08-27; no client can ask for it yet.**
  `GameRules.keepOptions(pot)` is the list of rungs a pot may be dropped to, gated on
  `shared-fixtures/game-rules.json` and mirrored in Luau. `bankPot(userId, platform, keep)`
  takes it, `keep` defaulting to 0 — which is the full bank, so every shipped client is
  unchanged. Rungs rather than a slider keep every pot a power of three and every banked
  difference an integer.
  ⚠ **`stakingStreak` is now zeroed only when the POT REACHES ZERO**, not whenever a bank
  happens (owner ruling 2026-08-26) — a player who hedges still has money on the same run.
  `currentStreak` is untouched by banking of either kind, as it always was.
  See `docs/superpowers/specs/2026-08-26-partial-banking-design.md` for the strategy analysis:
  the optimal fraction is a RATIO (`(bank÷pot + 1)/4`), not a constant, and riding the whole
  pot becomes optimal once the bank is 3× the pot.

⚠ **Bank-vs-Stake is also the constraint on every status display**: any metric either branch
changes puts a thumb on the scale of this decision. See [[status-display]].

The pot is never "wagered" in the gambling sense and the copy must never say so — the
owner's standing RISK/BANK ruling is on [[round-and-hud]]: a player may collect or keep
playing, and never stakes what they already own.

## The economy, and which number means what

Four fields that are easy to confuse, and picking the wrong one produces a wrong
leaderboard:

- `pointsAtStake` — the live pot. Volatile; one LOSS away from zero.
- `totalPoints` — the **spendable wallet**. Changes only on bank, and is **decremented by
  purchases** (`server/src/routes/store.ts`, `routes/apiV1.ts`).
- `lifetimeBanked` — **career earnings**, monotonic. Never decreases.
- `bestPot` — the largest pot ever *reached*, kept via `$max`. Note it records what was
  reached, not what was kept.

⚠ **Do not rank players by `totalPoints`.** It is a wallet, so a player who spends on
fireworks or a teahouse *falls down the board*. `lifetimeBanked` is the correct basis for
standings.

**Corrected 2026-08-18:** this warning used to say the shipped leaderboards "do exactly this".
They do not — `server/src/leaderboards.ts` sorts `topByCareer` by `lifetimeBanked`, and has
since 2026-08-16, the day this page was written. The rule stands; the accusation was stale on
arrival. (`totalPoints` does still travel in `LEADERBOARD_FIELDS`, which is what makes ranking
by it an easy mistake to make — that is the live hazard, not the current sort.)

## Trap: `pointsDelta` is not an increment

`GameRules.potDelta` records, on a WIN, the **new pot value** rather than the gain
(characterised from production behaviour; `server/src/engine/GameRules.ts:18-24`). A run
of 0→1→3→9 writes deltas `1, 3, 9` for a pot worth 9. **Summing `PlayerRound.pointsDelta`
does not give points earned** — any points-per-round or earnings stat must derive from
bank events or `lifetimeBanked`, not from a naive sum.

## What is recorded per round

- `Round` — `worldThrow`, `distribution {R,P,S}`, `totalPlayers`, `timestamp`. The
  distribution means the crowd's shape is preserved for every round ever played, which is
  what makes retrospective skill analysis possible.
- `PlayerRound` — one row per player per round: `playerThrow`, `playerResult`,
  `pointsDelta`, `timestamp`, `platform`, indexed by player+time. Windowed stats
  (last-10 / daily / weekly) are aggregations over this, not new plumbing.

## Raw layer

`shared-fixtures/game-rules.json` (rule authority), `server/src/engine/GameRules.ts`,
`server/src/engine/Settlement.ts`, `server/src/models/{User,Round,PlayerRound}.ts`,
`requirements.md` (superseded original spec).
