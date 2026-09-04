---
shelf: world
updated: 2026-09-04
checked: 2026-08-27
---

# The World Throw

The premise of the game, and the thing every stat in the [[stats-room]] ultimately measures.
The mechanics it settles — outcomes, pot, banking, the points fields — are [[core-loop]].

## What it is

**The World Throw is the throw MOST players in the round made — the plurality of the tally,
which with three options is often not a majority.** Not random. "Majority" is the product
word and the patent's word; plurality is the implementation (§ As-built, and the claim-construction
question under § Patent basis). Corrected 2026-09-04: this line said "MAJORITY choice" for three
weeks after the page itself recorded that a true majority frequently does not exist.
Roshambo is "you against the world" — a single player versus the aggregate crowd — and
that framing is the product. Owner, 2026-08-16: *"we have to successfully embody 'the
majority' as a worthwhile opponent or we'll fail entirely."*

Consequences that follow, and that any design must respect:

- **Reading the crowd is genuine skill**, exactly as reading an opponent is skill in
  two-player RPS after several throws. Outcomes are not fortune.
- **This is why the HUD shows the last five rounds.** If the World Throw were random
  that history would be information-free. It is shown because it is *predictive*.
  See [[round-and-hud]].
- **Throwing the majority is SAFE** (pot preserved, streaks reset), so conforming to the
  crowd is a hedge and defecting from it is the play for gain. Conformity vs
  contrarianism is therefore a real, measurable player style, not a flavour label.
- Perfect collective prediction is self-defeating: if everyone counters last round's
  majority, that counter *becomes* the majority. The equilibrium rotates, which is a
  Keynesian-beauty-contest depth-of-reasoning game.

## Patent basis

The game implements **US 8,025,570 B2** — "Massively multiplayer game method and system",
inventor **Jon Edgar Labrie**, filed 2004-02-23, granted 2011-09-27. Google Patents lists it
as active, expiring **2027-12-11** (⚠ from Google Patents, not verified against USPTO).

**What the claims actually cover.** The claim is broad in most respects: it recites selecting
an item from a set by three or more players, transmitting to a server, the server designating
an item "based on all the selected items received", and a *generic cyclic dominance rule-set*
over an ordered set {X1…Xn} — so it is not limited to rock-paper-scissors, nor to three
options. That breadth is the patent's strength.

⚠ **The narrow part is how the item is designated, and it says MAJORITY.** Both independent
claims — **1 and 6** — close with the same limitation:

> "wherein the designated item is the item selected by a **majority of players**"

**The specification offers no alternative method.** Checked 2026-08-16 for the language that
would open it up ("alternatively", "in another embodiment", "predetermined criteria", "other
methods", "not limited to") anywhere near the designation step: there is none. Every passage
reinforces the one method — *"The option chosen by the majority of players is called the
'Majority' throw."*

**"Plurality" appears in the patent only as the term of art for "more than one"** — "a
plurality of edge server devices", "a plurality of devices". It is never used to mean "the
most votes".

**The tension this creates with the implementation.** [[core-loop]] designates by PLURALITY
(argmax), because with three options a strict majority (>50%) frequently does not exist —
roughly uniform play puts each option near 33%. Under a literal reading of claim 1 the server
would have nothing to designate in most rounds. That cuts both ways: it is a genuine question
mark over whether the claims cover the shipped product, and it is simultaneously the strongest
argument for construing "majority" broadly, since a construction that renders the invention
inoperable most of the time is disfavoured.

**⚠ OPEN — needs a patent attorney, not an engineering judgement.** Claim construction is a
legal question and this underpins the product's exclusivity. Facts worth putting in front of
counsel, all of which bound the options:

- A **broadening reissue** must be filed within two years of grant (35 U.S.C. §251); grant was
  2011-09-27, so that window closed in 2013.
- A **continuation** requires a pending parent application.
- Expiry is ~16 months out as of 2026-08, which bounds what this is worth spending on.

**Do not quietly align the code to a guess.** `GameRules.deriveWorldThrow` is one pure
function with fixture cases, so the designation rule is cheap to change once there is advice.
Changing it on an engineering hunch would be worse than leaving it.

Full text: `https://patents.google.com/patent/US8025570B2/en`. One formula in the rendered
claim ("0<p<(n+½)") looks garbled in transit and should be read from the original before
anyone relies on it.

## As-built

**The majority rule is implemented** (2026-08-16). `GameRules.deriveWorldThrow` derives the
World Throw from the round's own tally, wired at the composition root; `RoundEngine` already
handed the counts to `pickWorldThrow`, so nothing else had to change. Held to
`shared-fixtures/game-rules.json` (`worldThrowDerivation`), 9 cases.

**It is PLURALITY, not majority.** With three options a true majority (>50%) frequently does
not exist — R 40 / P 35 / S 25 has none — so the rule is argmax. "Majority" is the product
word; plurality is the implementation.

Two deliberate fallbacks to random:

- **A tie for top** picks randomly among the tied only — never a throw nobody made.
- **Below `WORLD_THROW_MIN_PARTICIPANTS` (default 5, env-tunable)** the crowd is too small to
  be a world. At small N a player's own throw is decisive: joining either side of a 2–2 split
  *creates* the plurality they needed to beat, so they can only draw. A solo player would set
  the World Throw single-handedly and be permanently SAFE.

**Active on DEV since 2026-09-04**, against the synthetic crowd (§ Synthetic crowd below):
`TEST_MODE=false`, `CROWD_SIZE=30`, and the boot log confirms it. **Prod still runs
`TEST_MODE=true`**, the deterministic R→P→S cycle. Both are live facts — query the service
([[deploy]]), do not trust this line. Dev was redeployed from source the same day after the
mix re-tune (below), and its boot line read `mix random:15,wsls:30,counter:10,conform:35,rocky:10`
— the boot line's `mix …` is the answer to "which mix is dev running", not this sentence.

## Synthetic crowd (built 2026-09-04)

Spec `docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md`; plan
`docs/superpowers/plans/2026-09-04-synthetic-crowd.md`.

**What it is.** A tally crowd — bot throws that count toward the World Throw and appear in the
reveal's distribution, with no avatars. `RoundEngine` merges the bots' counts into the tally at
LOCK→REVEAL **before** `pickWorldThrow`, so the distribution on the card and the throw it
produced always agree; the per-participant `throws` map stays human-only, which is why bots
never reach settlement, `PlayerRound`, presence or any board. `Round.synthetic` records the
bot count; **`totalPlayers` is the size of the world (humans + bots)** — owner decision
2026-09-04, and the PLAYERS figure on the ledger and the stats board now means exactly that.

**Archetypes** (`server/src/engine/CrowdPolicies.ts`): `wsls` (win-stay / lose-shift-clockwise,
Wang–Xu–Zhou 2014), `counter`, `conform`, `rocky`, `random`, and the sim-only `second`. Each
is a distribution given a small memory, blended with uniform at a strength; the mix across
archetypes is the other dial. ⚠ **A hypothesis about a Roblox crowd, not a measurement.** The
recalibration path is the persisted `Round.distribution` minus the synthetic share (spec §8).

**Config** — `CROWD_SIZE` (0 = off), `CROWD_MIX` (`id:weight,…`), `CROWD_SEED`. Malformed
values refuse to boot. `CROWD_SIZE` under `TEST_MODE=true` is ignored with a warning. A
malformed `CROWD_MIX` or `CROWD_SEED` refuses to boot in **every** mode, `TEST_MODE` included —
so a typo cannot wait for flip day — except when the crowd is switched off outright, which is
`CROWD_SIZE` of zero and skips parsing entirely (ruling 2026-09-04). Read the
defaults from `DEFAULT_MIX` / `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts`
rather than from here.

**The simulator** — `cd server && npm run sim -- --experiment readability|blind-spread|effective-n`.
Re-run it rather than quoting the numbers below; they are one seed on one day.

Readability at the settled default mix (`--rounds 20000 --seed 1`). **Each row is that modelled
human ALONE against the 30-bot crowd** — one `runSimulation` per row, same seed; the transitions
line is the random-only run's, the world a blind human plays in:

```
# readability  rounds=20000 crowd=30 strength=0.7 seed=1
# mix random:15,wsls:30,counter:10,conform:35,rocky:10

human     BEAT WORLD   ±95%    safe    loss    banked      max pot*
random         29.6%   0.6%   41.0%   29.5%    531441        59049
counter        50.1%   0.7%   46.5%    3.4% 1.4780938567112483e+38 1.6423203268260662e+37
conform         2.6%   0.2%   64.5%   32.9%        15            3
wsls           34.9%   0.7%   43.4%   21.6%   3720087       531441
second         37.8%   0.7%    6.9%   55.3%      1215          243
oracle         57.4%   0.7%   26.0%   16.6% 17793060798303 2541865828329
* max pot is measured AFTER each round's bank decision

world throw transitions (n=19999): same 56.7%  counter 39.2%  other 4.1%
(a blind world is 33/33/33; "counter" high means the crowd rotates the way everyone-counters predicts)
```

`counter`'s `banked` and `max pot` are far past 2^53 and print in float notation: a ~46% SAFE
rate lets its ratio-banked pot compound almost without bound in the sim. Read that row as an
order of magnitude and nothing finer.

Seeds 2–5 (same command, `--seed 2` … `5`): `counter` 49.9–50.8%, `second` 37.3–38.0%, `wsls`
34.6–34.9%, `random` 29.6–30.0%, `conform` 2.4–2.6%, oracle 57.2–57.9%; transitions same
56.5–57.1%, counter 38.7–39.5%, other 4.0–4.3%.

Blind-field spread (`--experiment blind-spread --rounds 360 --seed 1`):

```
# blind-spread  rounds=360 crowd=30 strength=0.7 seed=1
# mix random:15,wsls:30,counter:10,conform:35,rocky:10

20 blind players, bank at 9, 20 runs of 360 rounds
max ÷ median banked: mean 1.32  worst 1.56
per run: 1.20 1.25 1.22 1.50 1.42 1.13 1.29 1.38 1.21 1.27 1.38 1.24 1.47 1.56 1.33 1.17 1.19 1.52 1.53 1.25
```

Effective N (`--experiment effective-n --rounds 5000 --seed 1`):

```
# effective-n  rounds=5000 crowd=30 strength=0.7 seed=1
# mix random:15,wsls:30,counter:10,conform:35,rocky:10

crowd   counter BEAT WORLD   ±95%
    5                38.6%   1.3%
    7                27.1%   1.2%
   10                35.8%   1.3%
   15                36.3%   1.3%
   20                49.0%   1.4%
   30                50.4%   1.4%
   50                55.7%   1.4%
  100                62.5%   1.3%
(where the rate stops moving, the human's own throw has stopped moving the plurality)
```

⚠ At crowd 100 the naive read climbs to 62.5%, past the ~60% ceiling that was pre-registered
for crowd 30 — a bigger crowd is the same crowd with less of the human's own vote diluting the
plurality. If `CROWD_SIZE` ever moves well above 30, re-run this and re-tune.

**Crowd presets — a living table** (started 2026-09-04, owner request; extend it as presets
are discovered, never prune a measured row). Every row is `CROWD_SIZE=30` at strength 0.7
unless stated, measured by the simulator at 20000 rounds, seed 1, **each rule alone** in the
tally, whole percentages. The transitions column is also `counter`'s fate in disguise: *same*
is a `counter` WIN, *forward* a SAFE, *backward* a LOSS — so *backward* is the winning rule's
loss rate, the number that decides whether banking ever feels necessary. To add a row:

```bash
cd server && npm run sim -- --rounds 20000 --seed 1 --mix <id:weight,…> [--strength p]
```

| preset | `CROWD_MIX` (or setting) | world: same / forward / backward | best rule → BEAT WORLD | blind | oracle | feel |
|---|---|---|---|---|---|---|
| off | `CROWD_SIZE=0` | random below 5 humans | none | 33% | — | blind world until five humans are in |
| cycle (prod) | `TEST_MODE=true` (crowd ignored) | 0 / 100 / 0 | `second` 100% | — | — | not a crowd: the R→P→S demo; `counter` is SAFE forever |
| pure random | `random:1` | 33 / 33 / 34 | none, all ~29% | 29% | 29% | the null; a plurality of noise |
| pure rocky | `rocky:1` | 34 / 33 / 34 | none, all ~29% | 29% | 44% | blind to every rule; only the oracle sees the rock lean |
| pure conform | `conform:1` | 100 / 0 / 0 | `counter` 100% | 33% | 100% | frozen world |
| pure counter | `counter:1` | 0 / 100 / 0 | `second` 100% | 33% | 100% | metronome, forward |
| pure wsls | `wsls:1` | 0 / 85 / 15 | `second` 80% | 31% | 80% | metronome with a stutter — the lose-shift is clockwise |
| pre-tuning hypothesis | `wsls:35,counter:20,conform:15,rocky:10,random:20` | 9 / 84 / 7 | `second` 82% | 31% | 82% | metronome; `counter` punished at 5% |
| first settled | `wsls:30,counter:10,conform:30,rocky:10,random:20` | 51 / 43 / 6 | `counter` 44% | 30% | 56% | contested: `counter` 44 vs `second` 42, neither clears 45 |
| **default (dev)** | unset = `wsls:30,counter:10,conform:35,rocky:10,random:15` | 57 / 39 / 4 | `counter` 50% | 30% | 57% | sticky; readable by round ten; `counter` loses ~4% |
| wsls-heavy, noise-light | `wsls:35,counter:10,conform:30,rocky:10,random:15` | 48 / 46 / 6 | `second` 44% | 30% | 58% | balanced; `counter` 41, `second` 44, neither clears 45 |
| rotating | `wsls:30,counter:15,conform:30,rocky:10,random:15` | 46 / 49 / 5 | `second` 48% | 30% | 57% | rewards the second-order read; `counter` 38 |
| wsls-heavy, conform-light | `wsls:35,counter:10,conform:25,rocky:10,random:20` | 33 / 57 / 9 | `second` 55% | 30% | 58% | rotating; `counter` 27; highest backward rate of any mix here |
| strong rotation | `wsls:30,counter:15,conform:25,rocky:10,random:20` | 29 / 65 / 6 | `second` 62% | 30% | 63% | over the ~60% ceiling |
| default @ strength 0.5 | *sim only* (`--strength 0.5`; no env var) | 52 / 39 / 9 | `counter` 46% | 29% | 49% | nearly solved by one rule (oracle 3 pts up) but `counter` loses ~9% |
| default @ strength 0.8 | *sim only* | 52 / 43 / 4 | `counter` 46% | 30% | 63% | just over the floor; seeds 1–3 gave 45.7–46.2 |
| default @ strength 0.85 | *sim only* | 59 / 39 / 2 | `counter` 53% | 30% | 67% | stickier still; `counter` almost never loses |

Two levers the table makes visible. **Strength is the loss-rate dial**: lowering it adds
backward rotations (0.85 → 2%, 0.7 → 4%, 0.5 → 9%) without moving the blind row, and it has no
env var yet — `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts` is code-only, so a
`CROWD_STRENGTH` variable is the first thing to add if Q1 says banking feels unnecessary.
**`conform` vs `counter` weight is the sticky-vs-rotating dial**: it decides which of the two
teachable rules the crowd rewards, and the pure rows show the extremes.

**How the mix was settled, and against which targets.** Pre-registered before tuning (spec §2,
bands as amended in the build ledger): the best simple, teachable rule beats the crowd at
**45–60%** BEAT WORLD, nothing non-oracle exceeds ~60%, and a blind human sits in **29–34%**. At
the settled mix, each rule alone, all three hold at seeds 1–5: `counter` 49.9–50.8%, ceiling
clear (oracle ~57%, ~7 points above the best rule, so no single rule solves the crowd), blind
29.6–30.0%.

How it got here, in order (chronology in `log.md`):

1. **The first hypothesis** (`wsls:35,counter:20,conform:15,rocky:10,random:20`) was a
   metronome: `wsls`'s lose-shift is *clockwise*, which lands on the counter-throw, so `wsls` and
   `counter` pulled the world the same way and their signals compounded — `second` beat it 82%,
   the naive `counter` reader was punished at 7%. Raising `conform` rather than adding `random`
   was the fix: it opposes the rotation instead of blurring it.
2. **The first settled mix** (`conform:30`, `random:20`) was tuned against a **contaminated
   table**: the readability experiment ran all six modelled humans in ONE tally, so their votes
   shaped the World Throw each was scored against — `counter` + `oracle` pushed the plurality
   forward, which is exactly the move `second` needs. In company `second` scored 51.9%; alone
   42.0%, and alone the best rule (`counter`) reached only 44.0–44.5%. No rule cleared 45%.
3. **Fixed and re-tuned 2026-09-04.** `experiments.readability` now runs one simulation per
   modelled human (`experiments.test.ts` checks every row against a solo `runSimulation`). The
   re-tune moved **one bot of thirty from `random` to `conform`** (`allocate(30)`: 5 random,
   9 wsls, 3 counter, 10 conform, 3 rocky). Why that lever: the smallest possible change to the
   crowd, integer weights, strength untouched, and mid-band across five seeds. The alternatives
   probed: strength 0.8 cleared 45% by about a point only (45.7–46.2%, within two CIs of the
   floor); `counter:15,random:15` cleared it via `second` (47–48%) but by punishing the naive
   read (`counter` 38–39%), the rule a newcomer finds first. Direction note: the build ledger's
   Task 11 ruling pointed "toward less predictability" because the failure it saw was
   over-readability; the honest table was *under*-readable, so this lever went the other way,
   under the same constraints (one lever, smallest sufficient, integers, strength 0.4–0.85).

- ⚠ **The blind band is 29–34%, widened from "≈33%" by ruling 2026-09-04** (owner ratification
  still owed at handoff). A blind human's own throw is inside the tally it is judged against,
  so it drags the plurality toward itself; once the best rule is held under 60% the plurality
  margins are narrow enough that the blind rate sits near 29.5–30% *whatever* the mix — probed
  across ~40 mix cells during the build and again here, and it did not move. The `random` row
  is a null hypothesis, not a design target.
- **What the crowd rewards now:** reading the world as *sticky*. It repeats itself ~57% of
  rounds and rotates forward ~39%, so "throw what beats the last World Throw" (`counter`) wins
  half the time and is SAFE most of the rest (LOSS ~3.5%). `second` (throw what the last World
  Throw *beat*) is the punished second-order read at ~38%; `wsls` sits at ~35%.
- Consequence, and expected: `conform` is a dead rule (~2.5% BEAT WORLD). It only wins on the
  rare backward rotation, which the transitions line puts at ~4%.

**Pre-registered Q1** (owner decision 2026-09-04): one person, ~20 rounds on dev against the
default crowd with the last-five HUD; **≥ 45% BEAT WORLD** reads as "crowd-reading is a skill
here"; a rate down in the blind band (29–34%, above) means the crowd is too noisy or the HUD
shows the wrong thing. Result: not yet run. Dev runs the re-tuned mix since the 2026-09-04
source redeploy (As-built, above), so it can be.
⚠ **The owner cannot run the discovery half of Q1** (they know the rules); their twenty rounds
are a FEEL test plus a calibration check: play `counter` deliberately → expect ~50% over a long
run; twenty rounds is ±20 points, so read the tape's transition shape instead — the world
repeats a bit under 6 in 10, moves forward ~4 in 10, backward almost never. Discovery is for
newcomers, read by trajectory (rounds 11–20 vs 1–10), by what they say the world was doing, and
by whether they kept throwing — not by a 45% line in twenty rounds.

Read a long-run ~50% as "found the rule". A first-time human will almost certainly try `counter`
first, and against this crowd that is most of the available edge; the oracle's ~57% is the
ceiling. The 45% line is met by a single rule-follower alone, so the question the experiment
left open — move the line or re-tune the crowd — is closed: the crowd was re-tuned.
