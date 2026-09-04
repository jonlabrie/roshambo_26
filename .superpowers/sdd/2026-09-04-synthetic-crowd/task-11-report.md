# Task 11 report — Q0: tune the default mix, record the result

**Status:** DONE_WITH_CONCERNS — two of the three pre-registered targets hold at all three
seeds; the third (`random` in 30–34%) misses by 0.2–0.6 points and is shown below to be
structural rather than a mix parameter.

**Commit:** `e79540b` — tune(crowd): default mix settled by the readability experiment

## Settled default

```ts
export const DEFAULT_MIX: Mix = { wsls: 30, counter: 10, conform: 30, rocky: 10, random: 20 };
export const DEFAULT_STRENGTH = 0.7;   // unchanged
```

## What the baseline actually showed, and why the brief's Step 2 pointed the wrong way

At the old default the crowd was a **metronome**, not a crowd: `second` beat the world 82.4%,
exactly equal to the oracle — i.e. one teachable rule solved the crowd completely — while the
naive `counter` reader was punished at 6.8%.

The mechanism (not previously written down anywhere): **`wsls`'s lose-shift is CLOCKWISE, and
clockwise from a losing throw lands exactly on the counter-throw.** So `wsls` and `counter` pull
the World Throw the same way. With wsls:35 + counter:20 that is 55% of the crowd pushing one
rotation, and the world rotated counter-wards 82.4% of rounds. The brief's remedy (raise
`counter`, raise strength, lower `random`) would have tightened the metronome.

A second structural fact that made the tuning tractable: **the three teachable rates are the
three world-transition probabilities**, and they sum to ~100% at any strength.
`counter` = P(world stays), `conform` = P(world rotates the other way), `second` = P(world
rotates counter-wards). Verified in every run below (e.g. 42.2 + 5.9 + 51.9 = 100.0). So the
target "best rule in 45–60%" is exactly "no world transition more likely than ~60%", and the
lever is the *balance of pulls*, not the amount of noise.

## Run table

All runs: `--rounds 20000 --crowd 30`. Rates are BEAT WORLD %. Reported ±95% CI is 0.6–0.7%.

### Ordered runs following the controller ruling

| # | mix (wsls/counter/conform/rocky/random) | str | seed | random | counter | conform | wsls | second | oracle |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 35/20/15/10/20 (old default) | 0.7 | 1 | 31.1 | 6.8 | 10.8 | 31.5 | **82.4** | 82.4 |
| 1 | " | 0.7 | 2 | 30.8 | 7.0 | 10.7 | 31.8 | **82.3** | 82.3 |
| 1 | " | 0.7 | 3 | 30.6 | 7.0 | 10.5 | 31.5 | **82.5** | 82.5 |
| 2 | 40/10/15/10/25  — ruling (a) | 0.7 | 1 | 30.0 | 12.4 | 19.6 | 28.2 | **68.1** | 68.1 |
| 2 | " | 0.7 | 2 | 29.5 | 12.8 | 19.7 | 28.4 | **67.6** | 67.8 |
| 2 | " | 0.7 | 3 | 29.2 | 12.8 | 20.0 | 27.8 | **67.3** | 67.4 |
| 3 | 40/10/15/10/25 — ruling (b) | 0.6 | 1 | 30.1 | 14.7 | 21.5 | 28.1 | **63.8** | 63.9 |
| 3 | " | 0.6 | 2 | 29.7 | 14.3 | 21.3 | 27.8 | **64.4** | 64.4 |
| 3 | " | 0.6 | 3 | 30.2 | 14.7 | 20.9 | 28.2 | **64.4** | 64.4 |
| 4 | 40/10/15/10/25 | 0.55 | 1–3 | 29.6–30.2 | 15.0–15.7 | 22.0–22.3 | 27.7–28.2 | **62.2–62.7** | 62.2–62.6 |
| 5 | 40/10/15/10/25 | 0.5 | 1–3 | 29.6–29.8 | 16.3–16.9 | 23.1–23.6 | 27.3–27.9 | **59.8–60.6** | 59.8–60.6 |
| 6 | 40/10/15/10/30 — ruling (c) | 0.6 | 1–3 | 28.7–30.0 | 15.6–16.2 | 21.5–22.0 | 27.7–28.0 | **62.3–62.8** | 62.3–62.8 |
| 7 | 40/10/15/10/30 — ruling (c) | 0.5 | 1–3 | 29.1–29.6 | 17.6–17.8 | 23.5–24.0 | 26.9–27.7 | **58.2–58.7** | 58.2–58.7 |

Run 7 is the first that clears the 45–60% band on both sides (`second` 58.2–58.7%). But it
clears it by *flattening everything toward noise*: the oracle drops with it (58.2%), meaning the
crowd is not less solved, just less rewarding. And `random` fell to 29.1–29.6%, further from the
target than the baseline. Following the ruling's list to its end did not produce a mix meeting
all three targets, so I diagnosed rather than kept dialing.

### Diagnostic sweep (seed 1 only) — pulls rebalanced instead of noise added

Holding `random:20`, `rocky:10` and varying the counter-pull (`wsls` + `counter`) against the
stay-put pull (`conform`):

| mix | str | random | counter | conform | wsls | second |
|---|---|---|---|---|---|---|
| 30/15/25/10/20 | 0.7 | 29.8 | 24.2 | 9.2 | 30.7 | **66.6** |
| 35/10/25/10/20 | 0.7 | 29.4 | 26.8 | 11.7 | 29.7 | **61.5** |
| **30/10/30/10/20** | **0.7** | **29.4** | **42.2** | **5.9** | **32.8** | **51.9** |
| 25/15/30/10/20 | 0.7 | 29.7 | 39.8 | 5.0 | 33.5 | **55.2** |
| 20/15/35/10/20 | 0.7 | 29.7 | **45.6** | 2.8 | 35.6 | 51.7 |
| 25/10/35/10/20 | 0.7 | 29.8 | **50.0** | 4.0 | 35.3 | 45.9 |
| 20/10/40/10/20 | 0.7 | 30.1 | **65.5** | 1.8 | 46.5 | 32.7 |

Past `conform:35` the world becomes sticky and `counter` runs away over 60% — the same failure
mirrored. The band 45–60% lives at roughly `conform` 30 with the counter-pull halved.

The same sweep repeated at strength 0.75, 0.8 and 0.85, and at `random` weights 10 and 15, moved
the teachable rates but left `random` at **29.1–30.6% in every single cell**. Strengths 0.5–0.85
were covered; the hard bound 0.4–0.85 was respected throughout.

### Final candidates, seeds 1–3

| candidate | seed | random | counter | conform | wsls | second | oracle |
|---|---|---|---|---|---|---|---|
| **A** 30/10/30/10/20 @0.7 | 1 | 29.4 | 42.2 | 5.9 | 32.8 | **51.9** | 56.5 |
| A | 2 | 29.8 | 42.6 | 6.0 | 32.8 | **51.4** | 56.1 |
| A | 3 | 29.6 | 42.0 | 5.7 | 33.0 | **52.4** | 56.0 |
| B 25/15/30/10/20 @0.7 | 1 | 29.7 | 39.8 | 5.0 | 33.5 | **55.2** | 56.0 |
| B | 2 | 29.4 | 40.4 | 5.1 | 33.8 | **54.5** | 55.6 |
| B | 3 | 30.2 | 39.9 | 4.9 | 33.2 | **55.1** | 56.1 |

**Chose A.** Both sit in the band, but in B the oracle (55.6–56.1%) clears the best teachable
rule by under one point — `second` is nearly a perfect predictor, which is the trivial regime the
target exists to prevent. In A the oracle clears every teachable rule by ~4 points, so the crowd
retains genuine unreadability, and A's best rule (51.4–52.4%) sits closest to the middle of the
45–60% band, the most robust place against seed noise and future recalibration.

**Why A is the smallest sufficient change:** it keeps `DEFAULT_STRENGTH` at 0.7 (so
`experiments.test.ts` needed no edit at all), keeps `random:20` and `rocky:10` untouched, and
moves only the two weights the diagnosis identified — `counter` 20→10 (exactly ruling (a)'s
target) and `conform` 15→30, with `wsls` 35→30 to keep the total at 100. Every mix in the sweep
whose L1 distance from the old default was smaller than A's (e.g. 30/15/25 at distance 20) left
the best rule above 60%.

## Targets, judged

| target | result | verdict |
|---|---|---|
| some teachable rule ≥ 45% | `second` 51.4–52.4%, `counter` 42.0–42.6% | **PASS** at all 3 seeds |
| no non-oracle rule above ~60% | max non-oracle 52.4% | **PASS** at all 3 seeds |
| `random` in 30–34% | 29.4–29.8% | **MISS** by 0.2–0.6 points at all 3 seeds |

### On the `random` miss — it is a property of the game, not of the mix

The controller's ruling anticipated `random` landing ~2 points below 33% (≈31%) because a blind
player's own throw is in the tally it is judged against. The measured structural value is ~3.3
points below (≈29.7%). The extra point has a mechanism: the size of the self-vote's effect
depends on the **plurality margin**. When the crowd is a metronome the margin is wide and one
vote almost never flips the world, so the bias is small — which is exactly why the old default
scored 30.6–31.1% and was inside the band. Every mix that spreads the world's transitions enough
to bring the best rule under 60% also narrows the margins, and `random` settles at ~29.7%.

This is a genuine conflict between two pre-registered targets, not a tuning failure: `random` in
30–34% and "no rule above 60%" are not simultaneously satisfiable at crowd 30 with the readability
experiment's six-human field. Across ~40 probed cells (5 strengths × 8 mixes × 3 random weights)
`random` never left 29.1–30.6%. Per the ruling I stopped and recorded the closest candidate rather
than keep dialing. **This wants a controller decision in Task 12:** either widen the band to
29–34% with the mechanism recorded in the wiki, or accept the miss as documented.

## `allocate(10, DEFAULT_MIX)` derivation (by hand)

`ids` = `POLICY_IDS` filtered to non-zero weight, **in POLICY_IDS order**
(`random, wsls, counter, conform, rocky, second`) → `[random, wsls, counter, conform, rocky]`
(`second` has no weight, so it is excluded).

| id | weight | quota = 10 × w / 100 | floor | fraction |
|---|---|---|---|---|
| random | 20 | 2.0 | 2 | .0 |
| wsls | 30 | 3.0 | 3 | .0 |
| counter | 10 | 1.0 | 1 | .0 |
| conform | 30 | 3.0 | 3 | .0 |
| rocky | 10 | 1.0 | 1 | .0 |

Floors sum to 2+3+1+3+1 = **10 = size**, so the remainder is 0 and the largest-remainder step
hands out nothing. Output, in `ids` order, each id repeated its count:

```
['random','random','wsls','wsls','wsls','counter','conform','conform','conform','rocky']
```

Because the new mix divides exactly, that test no longer exercised the largest-remainder
tie-break at all. Rather than lose the coverage silently I added a dedicated test using the old
mix (`allocate(10, {wsls:35,counter:20,conform:15,rocky:10,random:20})` → quotas 2, 3.5, 2, 1.5,
1; floors sum to 9; the one remainder goes to the `.5` tie broken toward the earlier `POLICY_IDS`
entry, `wsls`).

## Files changed

- `server/src/engine/SyntheticCrowd.ts` — `DEFAULT_MIX`; the comment above it rewritten from the
  old hypothesis to the settled result and its mechanism. `DEFAULT_STRENGTH` unchanged.
- `server/src/engine/SyntheticCrowd.test.ts` — `DEFAULT_MIX` pin, `allocate(10, DEFAULT_MIX)`
  expectation and its derivation comment, plus the new tie-break test.
- `server/src/sim/experiments.test.ts` — **not changed**; strength stayed 0.7 and the mix there
  reads `DEFAULT_MIX`.

## Verification

- `npm test` → **28 files, 579 tests, all passing**
- `npx tsc --noEmit` → clean
- Commit contains only the two source files; `dist/` and the unrelated dirty
  `.superpowers/sdd/.gitignore` were not staged.

## Saved outputs (for Task 12's wiki paste)

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/.superpowers/sdd/2026-09-04-synthetic-crowd/sim-readability.txt` — `--rounds 20000 --seed 1`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/.superpowers/sdd/2026-09-04-synthetic-crowd/sim-blind.txt` — `--experiment blind-spread --rounds 360 --seed 1`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/.superpowers/sdd/2026-09-04-synthetic-crowd/sim-effn.txt` — `--experiment effective-n --rounds 5000 --seed 1`

(The npm-script banner lines were stripped so the files hold only experiment output.)

## Two observations for later, not acted on here

1. **`conform` is now a near-dead rule at 5.7–6.0%.** The world rarely rotates "the other way",
   so a player who copies the last World Throw loses ~52% of rounds. That is a defensible design
   (three rules, one of which is a trap) but it should be a deliberate call, not a leftover.
2. **`effective-n` is non-monotonic at crowd 15** (35.8% at crowd 10 → 28.2% at 15 → 39.7% at 20;
   see `sim-effn.txt`). That is not sampling noise — the CI is ±1.3%. It is `allocate` rounding:
   each crowd size gets a different integer archetype split, so crowd 15 is a materially different
   crowd, not a bigger one. Worth a note wherever that table is published, since the experiment's
   caption invites reading it as a smooth curve.
