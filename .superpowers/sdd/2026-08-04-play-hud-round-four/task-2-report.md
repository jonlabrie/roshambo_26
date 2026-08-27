# Task 2 Report: RollingNumber scales with distance, easing turns over

## What changed

`roblox/src/shared/RollingNumber.luau`:
- Deleted `RollingNumber.DURATION` (flat 0.5s).
- Added `RollingNumber.MIN_DURATION = 0.4`, `MAX_DURATION = 2.5`, `SCALE_CAP = 10000`.
- Added `RollingNumber.durationFor(delta: number): number` — logarithmic in `|delta|`, clamped to
  `[MIN_DURATION, MAX_DURATION]`, capped at `SCALE_CAP`.
- Replaced the local `easeOut` (quadratic ease-out, `1 - (1-t)^2`) with `smoothstep`
  (`t*t*(3-2t)`), and updated `valueAt`'s single call site plus its comment (which had referenced
  `easeOut(0)`/`easeOut(1)` by name).

`roblox/tests/RollingNumber.spec.luau`: replaced the old `describe("RollingNumber.DURATION", ...)`
block verbatim with the brief's `durationFor` and `valueAt` easing describe blocks (Step 1 text,
unmodified). All prior describe blocks (endpoints, overshoot, monotonic, from==to, integer) were
left untouched, as instructed.

## Computed durations vs. the brief's comment

Computed independently in Python using the shipped formula (`MIN=0.4, MAX=2.5, CAP=10000`,
`fraction = log(1+min(|d|,CAP)) / log(1+CAP)`):

| delta | computed | brief's comment |
|---|---|---|
| 1 | 0.5580390319223916 | 0.56s |
| 30 | 1.1829563888470256 | 1.18s |
| 300 | 1.7012332829322574 | 1.70s |
| 3000 | 2.22554482798788 | 2.23s |
| 10000 | 2.5 | 2.50s |

All match the brief's comment to the stated precision. The comment is correct; no discrepancy.

## Gate output

```
$ cd roblox && lune run tests/run
979 passed, 0 failed, 979 total

$ stylua --check src tests tools
(no output — OK)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

(Two `[WARN] [QUEUE] ...` lines appear in every `lune run tests/run` invocation, before and after
all my changes — they come from `tests/HandlerQueue.spec:80: boom`, an unrelated test that
intentionally exercises an error/overflow path. Not related to this task; final tally is always
"979 passed, 0 failed, 979 total" on green.)

## Step 5: mutation verification

All three mutations were applied to `RollingNumber.luau`, run, and reverted (`cp` round-trip to a
backup, `lune run tests/run` confirmed 979/979 green again after each revert).

### Mutation 1 — smoothstep reverted to quadratic ease-out (`1 - (1-t)*(1-t)`)

```
FAIL  RollingNumber.valueAt — the easing is a payoff, not a decay > the midpoint is the midpoint
      .../RollingNumber.spec:168: expected 75 to be 50
FAIL  RollingNumber.valueAt — the easing is a payoff, not a decay > it winds up rather than bolting
      .../RollingNumber.spec:174: expected false to be true
977 passed, 2 failed, 979 total
```

**Finding:** the brief says "the three easing tests must fail" — only **two** did. The third
("and settles rather than stopping dead", `valueAt(0,100,0.75)`) passed under the old ease-out:
`1 - (1-0.75)^2 = 0.9375` → rounds to 94, and the test's bounds are `> 75` and `< 95`, so 94 slips
through both. That test is not vacuous in general (it's part of what makes the tests-as-a-whole
catch the regression, and it still exercises the "not stopping dead" shape), but on its own it
does not discriminate old ease-out from smoothstep at `t=0.75` — the two curves are close enough
there. Reported as instructed rather than treated as a pass.

### Mutation 2 — `durationFor` returns `MIN_DURATION` unconditionally

```
FAIL  RollingNumber.durationFor — a big bank should feel like a payoff > beyond the cap it is exactly MAX_DURATION — no pot runs away with the screen
      .../RollingNumber.spec:148: expected 0.4 to be 2.5
FAIL  RollingNumber.durationFor — a big bank should feel like a payoff > the curve's shape: a big bank takes seconds, a small one does not
      .../RollingNumber.spec:155: expected false to be true
977 passed, 2 failed, 979 total
```

Both the cap test and the curve-shape test failed, as the brief predicted. (The "never leaves
[MIN,MAX]" and "monotonic" tests did NOT fail — a constant value trivially satisfies both — which
is expected and not a gap, since the brief specifically named "curve-shape and cap tests.")

### Mutation 3 — `math.abs(delta)` → `delta`

```
FAIL  RollingNumber.durationFor — a big bank should feel like a payoff > direction does not matter — only distance
      .../RollingNumber.spec:126: expected -inf to be 0.5580390319223916
978 passed, 1 failed, 979 total
```

**What actually happened:** with a negative delta (test loop starts at `d=1`, so `durationFor(-1)`
is evaluated first), `magnitude = min(-1, 10000) = -1`, then `math.log(1 + (-1)) = math.log(0)`.
In this Luau/Lune runtime that evaluates to `-inf` rather than throwing an error or producing
`nan` — the test framework compared `-inf` to the positive expected duration and failed cleanly
with the message above, rather than crashing the harness. Confirmed this is not a silent pass: the
direction test fails, and it fails loudly enough to name the exact wrong value.

All three mutations were restored; `lune run tests/run` returned to 979 passed, 0 failed after
each.

## HudController — left broken on purpose

Per instructions, `roblox/src/client/HudController.client.luau` was **not** touched. It has one
call site that still reads the now-deleted `RollingNumber.DURATION`:

- `roblox/src/client/HudController.client.luau:246`:
  `local t = (os.clock() - c.startedAt) / RollingNumber.DURATION`
  (immediately followed by `c.displayed = RollingNumber.valueAt(c.from, c.target, t)` at line 247,
  which itself is fine since `valueAt`'s signature didn't change — only line 246's divisor is
  broken.)

This is the only reference to `RollingNumber.DURATION` in `roblox/src` (confirmed via
`grep -rn "RollingNumber" roblox/src` — the only other RollingNumber lines in that file are the
`require` at line 49 and two unrelated comments at 219/873/1339). Because `lune run tests/run`
never loads client-runtime files (only `src/shared` and other Lune-compatible modules), this
break is invisible to the harness — `RollingNumber.DURATION` now evaluates to `nil`, so line 246
would divide by `nil` at runtime in Studio/Play, which errors. Task 3 must replace line 246 with
something that calls `RollingNumber.durationFor(delta)` (where `delta` is presumably
`c.target - c.from` or similar, based on the `Counter` struct's fields) instead of dividing by the
deleted constant.

## Concerns

- None blocking. The one soft finding is the Mutation-1 third easing test not discriminating on
  its own at `t=0.75` (documented above) — the test suite as a whole still fully pins the
  smoothstep change via the other two tests in that block, so this is not a coverage gap worth
  blocking on, just worth flagging as asked.

## Round 1 fix: "and settles rather than stopping dead" was decoration

The coordinator's finding was correct and went further than my original note: the settles test's
`< 95` bound didn't just weaken discrimination, it made the test **incapable of failing** under
the exact mutation (ease-out revert) it exists to catch — 94 (ease-out) and 84 (smoothstep) both
satisfy `< 95`. That's not "less sensitive," that's decoration.

**Sibling check — "it winds up rather than bolting" (t = 0.25):**
- smoothstep(0.25) = 0.0625 × (3 − 0.5) = 0.15625 → `valueAt` returns 16
- ease-out(0.25) = 1 − 0.75² = 0.4375 → `valueAt` returns 44
- Bounds are `< 25` and `> 5`. 44 fails `< 25`, so ease-out is genuinely excluded — this test
  already discriminates correctly and needed no change.

**Fix applied** — `roblox/tests/RollingNumber.spec.luau`, "and settles rather than stopping dead":
tightened the upper bound from `< 95` to `< 90` (smoothstep gives 84, ease-out gives 94; 90 sits
between them with real margin either side) and rewrote the comment to record why 90 specifically —
naming both curves' values so the bound's provenance isn't a mystery to the next reader.

**Re-ran mutation 1** (smoothstep reverted to `1 - (1-t)*(1-t)`) after the fix:

```
FAIL  RollingNumber.valueAt — the easing is a payoff, not a decay > the midpoint is the midpoint
      .../RollingNumber.spec:168: expected 75 to be 50
FAIL  RollingNumber.valueAt — the easing is a payoff, not a decay > it winds up rather than bolting
      .../RollingNumber.spec:174: expected false to be true
FAIL  RollingNumber.valueAt — the easing is a payoff, not a decay > and settles rather than stopping dead
      .../RollingNumber.spec:185: expected false to be true
976 passed, 3 failed, 979 total
```

All three easing tests now fail under mutation 1, as the brief originally expected. Reverted the
mutation and confirmed 979 passed, 0 failed again. Full gates (`lune run tests/run`,
`stylua --check src tests tools`, `selene src tools`) all green after the fix. Committed.
`HudController.client.luau` was not touched.
