# Task 2 report: RingTimer stops counting segments and starts measuring a sweep

## What changed

- `roblox/src/shared/RingTimer.luau` — near-total rewrite, applied verbatim from the brief.
  Deleted `SEGMENTS`, `lit`, `angleAt`, `segmentWidth`. Added `MIN_SWEEP_DEGREES = 6`,
  `sweepDegrees(fraction)`, `sweep(fraction) -> {rotationA, rotationB, bLit}`. `isWarning`
  unchanged.
- `roblox/tests/RingTimer.spec.luau` — near-total rewrite, applied verbatim from the brief,
  covering `sweepDegrees`, `sweep` (rotation pair + lit/track branch), a reconstruction test
  that recomputes the painted arc from the rotations and checks it against `sweepDegrees`, and
  a "segmented ring is gone" test asserting the four deleted names are `nil`.

No client files were touched. `roblox/src/client/HudController.client.luau` still calls
`RingTimer.lit` and `RingTimer.SEGMENTS`, both now gone from the module — this is **expected
breakage**, left in place per instructions. It compiles fine under the Lune test harness (which
never loads client files) but the actual game client is now broken until Task 3 rewrites
`HudController` to use `RingTimer.sweep`/`sweepDegrees`. Do not deploy/publish this commit alone
to a live client without Task 3 following immediately.

## Step 2 — tests written first, watched fail

Ran `lune run tests/run` against the new spec with the old `RingTimer.luau` still in place:

```
FAIL  RingTimer.sweepDegrees ... (7 failures, all "attempt to call a nil value")
FAIL  RingTimer.sweep ... (8 failures, all "attempt to call a nil value")
FAIL  RingTimer — the segmented ring is gone > nothing counts segments any more
      expected 36 to be nil

954 passed, 16 failed, 970 total
```

Matches the brief's expectation exactly: `sweepDegrees`/`sweep` don't exist yet, and the four
deleted names (`SEGMENTS` etc.) are still present.

## Step 4 — implementation in, tests pass

```
970 passed, 0 failed, 970 total
```

(The `[WARN] [QUEUE] dropping request...` / `handler error ... boom` lines are pre-existing
noise from `HandlerQueue.spec` — an intentional negative-path test in that unrelated suite, not
a RingTimer issue.)

## Step 5 — mutation testing (the point of this task)

**Mutation 1: `MIN_SWEEP_DEGREES = 6` → `0`.**

```
FAIL  RingTimer.sweepDegrees ... > ANY time remaining sweeps at least MIN_SWEEP_DEGREES
      /Users/.../RingTimer.spec:24: expected 0.036000000000000004 to be 0
FAIL  RingTimer.sweepDegrees ... > the floor is big enough to actually see
      /Users/.../RingTimer.spec:31: expected false to be true

968 passed, 2 failed, 970 total
```

Both targeted tests failed, nothing else did. Restored to `6`, re-ran, back to 970/0.

**Mutation 2: `if theta <= 180 then` → `if theta < 180 then`.**

```
FAIL  RingTimer.sweep — the two gradient rotations that draw that arc > exactly half a turn is still the track branch
      /Users/.../RingTimer.spec:74: expected true to be false

969 passed, 1 failed, 970 total
```

Exactly the one targeted test failed ("exactly half a turn is still the track branch"), no
collateral failures elsewhere — including the strong reconstruction test
("the painted arc matches the requested sweep, all the way round"), which stayed green because
at `theta == 180` both branches paint the same net arc (0–180), just via a different `bLit`
flag; only the direct branch-identity test catches the flip. Restored to `<=`, re-ran, back to
970/0.

Both mutations are load-bearing: neither test is vacuous.

## Gate output (Step 6)

```
$ cd roblox && lune run tests/run
970 passed, 0 failed, 970 total

$ stylua --check src tests tools
(clean, no output)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

## Commit

```
6ff8df9 feat(roblox): the ring is a swept arc, not a count of segments
 2 files changed, 158 insertions(+), 61 deletions(-)
```

Not pushed, per instructions.

## Anything the brief did not settle / concerns

- The brief's own commit-message instruction has no `Co-Authored-By` trailer, unlike this
  session's default git-commit convention. I followed the brief verbatim since it gave an
  explicit `git commit -m "..."` command as the final step.
- Confirmed (not just assumed) that `HudController.client.luau` is the only file referencing
  the four deleted `RingTimer` members — the Lune harness doesn't load client files, so this
  breakage is invisible to `lune run tests/run` but real for anyone running the actual game
  client on this branch until Task 3 lands.
- No other findings; the implementation and tests match the brief's verbatim code exactly.
