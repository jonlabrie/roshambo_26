# Task 1 report: Retract the early splash

## What was deleted

### `roblox/src/shared/DrumStep.luau`
- `DrumStep.SPLASH_RESIDUAL_RADIANS` and its full "WHEN THE PERSONAL RESULT MAY LAND" comment
  block (the spec-§2 rationale for a half-facet threshold).
- `DrumStep.glideResidual(d, omega, s)` — the function that computed how much angle the glide
  still owed.

### `roblox/src/client/DrumController.client.luau`
- The `SPLASH_RESIDUAL` local (and its comment).
- The `settlingFired` latch, plus **both** reset points: beside `glideT0` where `mode = "glide"`
  is assigned (comment: "a new glide: the settling cue is owed again"), and in the `gongHit`
  handler (comment: "THE SECOND RESET...").
- The `if not settlingFired and DrumStep.glideResidual(...) <= SPLASH_RESIDUAL then ... EventBus.Cue:Fire({ kind = "drumSettling" }) end` block inside the glide's still-travelling arm.
- Also corrected a now-stale comment above `DRUM_KICK` that referenced "the settling cue's
  residual" (not explicitly listed in the brief, but it would have documented a deleted concept).

### `roblox/src/client/main.client.luau`
- The `drumSettling` and `splashDone` locals and the "Two gates, not one" comment above them.
- `maybeShowSplash()` in full.
- The `maybeShowSplash()` call at the top of `maybeShowReveal`.
- The `drumSettling` branch of the `EventBus.Cue` handler (`drumRest` now only sets `drumAtRest`).
- The `drumSettling` / `splashDone` resets in the `RoundUpdate` ACTIVE-reopen block.
- The `drumSettling = true` line in the `REVEAL_SAFETY` fallback (now sets only `drumAtRest`).
- Also restored the top-of-file summary comment and the `pendingReveal`-declaration comment to
  their pre-round-four wording (both referenced the now-deleted `maybeShowSplash` / two-gate
  model) — confirmed against git history at commit `73724e5` (last commit before round four).

### `roblox/tests/DrumStep.spec.luau`
- The `DrumStep.glideResidual` describe block (`at s = 0`, `at s = 1`, monotonicity).
- The `DrumStep.SPLASH_RESIDUAL_RADIANS` describe block (threshold bound, lead-time band, "drum's
  own timings are unchanged").
- The `D_MIN`/`D_MAX`/`FACES`(local)/`crossingS` helpers that existed only to support those tests.
- Kept the existing `SETTLE_SECONDS is swing + spin + glide, derived` and `every leg is a
  positive duration` tests untouched.
- Added a small new test pinning `DrumStep.KICK_OMEGA == 4` (previously only asserted inside the
  deleted SPLASH_RESIDUAL block), with a comment explaining KICK_OMEGA's value is still worth
  covering even though the residual machinery around it is gone.

### `roblox/src/client/EventBus.luau`
- Rewrote the `"Splash"` entry's comment: it described firing from `maybeShowSplash` on the
  `drumSettling` cue; now describes firing from `maybeShowReveal` on the same `drumRest` gate as
  everything else.

## What was deliberately kept, and why

- **`DrumStep.KICK_OMEGA`** — moved out of `DrumController` for an independent, still-valid
  reason: it lived as a private local (`DRUM_KICK`) in a client file where the "DrumKick" stage
  attribute could retune it at runtime with no test able to see it. Kept, and its comment
  rewritten to drop the now-gone residual-specific justification while keeping the genuine one.
- **The corrected Hermite characterisation** — the "IT IS A HERMITE, NOT A BARE SMOOTHSTEP..."
  paragraph in `DrumStep.luau`'s header, which correctly describes the θ(s) curve
  `DrumController` still computes directly for its own glide animation. Kept (trimmed of the
  function-parameter-specific wording that only made sense attached to `glideResidual`), with one
  new paragraph added explaining that the residual computation itself is gone and why, so a future
  reader doesn't rebuild it.
- **`drumRest`** and everything gated on it — untouched. It remains the single gate: the tape
  badge, `revealedRoundId`/`revealedWorldThrow`, the ledger's LAST ROUND band, the win onboarding
  beat, and now the splash again all wait on it.
- The splash fire was folded back into `maybeShowReveal` at **exactly** its pre-round-four
  position — verified against `git show 73724e5:roblox/src/client/main.client.luau` — after the
  badge/`revealedRoundId` assignment block, guarded by `if p.result then`, immediately before
  `publish()`.

## Gate output

```
$ cd roblox && lune run tests/run
[WARN] [QUEUE] dropping request for u: queue full (8)      <- pre-existing, unrelated
[WARN] [QUEUE] handler error for u: .../HandlerQueue.spec:80: boom   <- pre-existing, unrelated
980 passed, 0 failed, 980 total

$ stylua --check src tests tools
(no output, rc=0)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

## Verification greps

```
$ grep -rn "drumSettling\|glideResidual\|SPLASH_RESIDUAL\|splashDone" roblox/src roblox/tests
(no output)

$ grep -c "EventBus.Splash:Fire" roblox/src/client/main.client.luau
1
```

Both clean, as required.

## Concerns

None. One judgment call worth flagging: the brief's Step 1 only explicitly names
`SPLASH_RESIDUAL_RADIANS`/`glideResidual` for deletion in `DrumStep.luau`, but the surrounding
comment on `DrumStep.KICK_OMEGA` (lines above it) and the deleted-function's own doc header both
*named* those two identifiers in prose, which would have failed the final grep. I rewrote those
prose references (in `DrumStep.luau` and `DrumStep.spec.luau`) to describe the same facts without
using the literal deleted-symbol names, rather than leaving dangling references to code that no
longer exists.
