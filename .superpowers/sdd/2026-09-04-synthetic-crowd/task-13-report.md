# Task 13 report — Full verification and the handoff to the owner

**Status:** DONE — everything green, branch pushed, CI seen green. No commit from this task.
Nothing merged, nothing deployed, no `aws` command run. The App Runner flip remains the owner's.

## Step 1 — Everything green (from `server/`)

| gate | command | result |
|---|---|---|
| tests | `npm test` | **28 files, 579 tests, 579 passed**, 9.49s |
| typecheck | `npx tsc --noEmit` | **clean** (exit 0, no output) |
| simulator | `npm run sim -- --rounds 1000` | **table printed**, below |

Local node is **v22.22.3** (`.nvmrc` pins 24.x) — all three gates passed on it anyway, and CI
ran the pinned version.

### Sim header line (confirms the settled default is what ships)

```
# readability  rounds=1000 crowd=30 strength=0.7 seed=1
# mix random:20,wsls:30,counter:10,conform:30,rocky:10
```

### Readability table (`--rounds 1000 --seed 1`, ±95% CI ≈ 3%)

```
human     BEAT WORLD   ±95%    safe    loss    banked      max pot*
random         26.2%   2.7%   43.1%   30.7%       405           81
counter        43.0%   3.1%   51.5%    5.5% 1162261467    387420489
conform         5.4%   1.4%   43.1%   51.5%         9            3
wsls           34.8%   3.0%   44.5%   20.7%     19683         6561
second         51.6%   3.1%    5.4%   43.0%      1701          243
oracle         56.1%   3.1%   27.5%   16.4%   7971615      1594323
* max pot is measured AFTER each round's bank decision

world throw transitions (n=999): same 43.0%  counter 51.6%  other 5.4%
```

This 1000-round run reproduces Task 11's settled 20000-round result within noise
(`second` 51.6 vs 51.9, `counter` 43.0 vs 42.2, `random` 26.2 vs 29.4 — `random` is the
noisiest column at this round count and the one already flagged below).

### The three Q0 targets, at mix `wsls:30, counter:10, conform:30, rocky:10, random:20` @ strength 0.7

| target | measured | verdict |
|---|---|---|
| some teachable rule ≥ 45% | `second` 51.6% (51.4–52.4% at 20000 rounds, seeds 1–3) | **PASS** |
| no non-oracle rule above ~60% | max non-oracle 51.6% | **PASS** |
| `random` in 30–34% | 26.2% here; 29.4–29.8% at 20000 rounds, seeds 1–3 | **MISS** |

The `random` miss is unchanged from Task 11 and was diagnosed there as **structural, not a
tuning failure**: a blind player's own throw sits in the tally it is judged against, and the
size of that self-vote's effect scales with the plurality margin. Every mix that spreads the
world's transitions enough to keep the best rule under 60% also narrows the margins, and
`random` settles at ~29.7%. Across ~40 probed cells it never left 29.1–30.6%. It wants a
controller/owner decision: widen the band to 29–34% with the mechanism recorded, or accept the
documented miss.

### The other two experiments, one line each

- **Blind spread** (`--experiment blind-spread --rounds 360 --seed 1`, 20 blind players banking
  at 9, 20 runs): max ÷ median banked **mean 1.43, worst 1.66** — luck alone spreads identical
  blind players by well under 2×, so the leaderboard is not a lottery.
- **Effective N** (`--experiment effective-n --rounds 5000 --seed 1`): the `counter` reader's
  rate rises 13.5% (crowd 5) → 44.4% (30) → 48.2% (50) → **51.7% (100)**, i.e. a human's own
  throw stops moving the plurality somewhere around crowd 50–100. Note the curve is
  **non-monotonic at crowd 15** (35.8% @10 → 28.2% @15 → 39.7% @20, CI ±1.3%) because
  `allocate` gives each crowd size a different integer archetype split — crowd 15 is a
  materially different crowd, not a bigger one, so the table must not be read as smooth.

## Step 2 — Branch state

`git status --short` at the start and end of this task showed only ` M .superpowers/sdd/.gitignore`
(left alone per instructions; the untracked plan dir is already ignored by it). No source file
is dirty.

`git log --oneline main..HEAD` — **15 commits, `9f9c79f` … `a38c6d3`**, exactly as expected:

```
a38c6d3 docs(wiki): the dev-flip checklist names every page that says the crowd rule is not live
3de3bb1 docs(wiki): synthetic crowd as-built, env vars, the dev flip procedure, ship entry
e79540b tune(crowd): default mix settled by the readability experiment -- second 51.9%, counter 42.2%, random 29.4%
c33d17a fix(sim): refuse non-finite numeric flags and rounds < 1 -- a typo no longer prints a believable table
359797e feat(sim): npm run sim -- readability, blind-spread and effective-n experiments, table or --json
83f85c1 feat(sim): reporters -- win rates with CI, world-throw transitions, banked totals, blind-field spread
8ab146e feat(sim): runSimulation -- humans as policies with pots, three bank rules, the oracle ceiling
c35ce0d feat(server): wire the synthetic crowd from env into the engine; one [CROWD] line per round
b10a33f feat(settlement): totalPlayers is the size of the world; Round.synthetic records the bots in it
b1ac300 feat(engine): merge the synthetic crowd into the tally at LOCK->REVEAL, before the World Throw is picked
1d23924 fix(crowd): validate CROWD_MIX and CROWD_SEED before the TEST_MODE guard -- a typo refuses to boot in every mode
88de2c0 feat(crowd): CROWD_SIZE / CROWD_MIX / CROWD_SEED, refused when malformed, disabled under TEST_MODE
4e2ea80 feat(crowd): SyntheticCrowd -- exact archetype allocation, per-bot memory, observe() teaches the world throw
54f5864 feat(crowd): six archetype policies as distributions over R/P/S -- wsls, counter, conform, rocky, second, random
9f9c79f feat(crowd): seeded mulberry32 PRNG -- the reproducibility the synthetic crowd needs
```

## Step 3 — Push

```
$ git push -u origin thread/crowd
 * [new branch]      thread/crowd -> thread/crowd
branch 'thread/crowd' set up to track 'origin/thread/crowd'.
```

First push of the branch. Remote is `https://github.com/jonlabrie/roshambo_26.git`.

## Step 4 — CI, seen green

| workflow | run | conclusion |
|---|---|---|
| **server-ci** | https://github.com/jonlabrie/roshambo_26/actions/runs/33870848462 | **success** (job `test`, 38s) |

`gh run watch --exit-status` was available (gh 2.98.0) and exited 0; confirmed afterwards with
`gh run list --branch thread/crowd --json conclusion` → `"success"`. Steps all green:
checkout → setup-node → `npm ci` → `npm run build` → `npm test`.

Only `server-ci` triggered, which is correct — it is path-filtered to `server/**`, and the
frontend/roblox workflows' paths were untouched by this branch. The one annotation is the
repo-wide, pre-existing `actions/checkout@v4` / `actions/setup-node@v4` Node-20-deprecation
warning, unrelated to this work.

The standing rule (a push is not done until its CI run is seen green) is satisfied.

## Step 5 — STOP. The flip is the owner's.

The dev-flip procedure lives at **`docs/wiki/systems/deploy.md` § "Flipping dev to the real
World Throw with a synthetic crowd"** (line ~124), with the rule itself and the crowd's
as-built detail in **`docs/wiki/world/world-throw.md` § Synthetic crowd**. The checklist there
also names every page that currently says the crowd rule is not live, so the flip's
documentation edits are enumerated.

**Not done here, by design:** no merge to `main`, no rebase, no App Runner update, no `aws`
command of any kind. Q1 — the owner's twenty minutes playing dev after the flip — is the next
step and is the owner's.

## Concerns

1. **The `random` band miss (26–30% vs the pre-registered 30–34%)** is the one open judgement
   call, carried forward unresolved from Task 11. It needs an owner ruling, not more tuning.
2. **`conform` is a near-dead rule at 5.4%** — a player who copies the last World Throw loses
   ~52% of rounds. Defensible as "three rules, one of which is a trap", but it should be a
   deliberate design call rather than a leftover of the tuning.
3. **The effective-n curve is non-monotonic at crowd 15** and will mislead anyone who reads it
   as a smooth curve; the `allocate`-rounding cause should travel with the table wherever it
   is published.
4. Local node is v22 while `.nvmrc` pins 24.x. Everything passed on both, so this is a note,
   not a failure.
