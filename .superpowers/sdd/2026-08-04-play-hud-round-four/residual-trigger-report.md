# `drumSettling` triggers on the residual angle, not the clock

**Date:** 2026-08-04 · design of record `docs/superpowers/specs/2026-08-04-play-hud-round-four-design.md` §2 (amended)

## What changed

| file | change |
| --- | --- |
| `roblox/src/shared/DrumStep.luau` | `SPLASH_LEAD_SECONDS` deleted. Added `SPLASH_RESIDUAL_RADIANS = (2*math.pi/FACES)/2` and `DrumStep.glideResidual(d, omega, s)`. |
| `roblox/src/client/DrumController.client.luau` | `SETTLING_S` deleted; the cue now fires the first frame `DrumStep.glideResidual(glideD, omega, s) <= SPLASH_RESIDUAL`, with the **live** `omega`. |
| `roblox/tests/DrumStep.spec.luau` | the `SPLASH_LEAD_SECONDS` describe replaced by two: the residual's invariants, and the threshold's. |
| `roblox/src/client/main.client.luau`, `roblox/src/client/EventBus.luau` | **comments only** — three sites said "~0.7s", now false. No code touched. |

The residual is derived from the controller's own glide, not restated:

```
theta(s)  = glideP0 - d*(3s^2 - 2s^3) - omega*G*(s^3 - 2s^2 + s),  landTheta = glideP0 - d
residual(s) = theta(s) - landTheta
            = d*(1 - (3s^2 - 2s^3)) - omega*G*(s^3 - 2s^2 + s)
```

It is a **Hermite**, not a bare smoothstep: `omega` is not zeroed until the glide completes, so the
spin's exit velocity is carried in. The module header previously implied a plain smoothstep and that
misled a reader — the smoothstep alone reads 72% travelled where the real curve reads 83–88%. The
`glideResidual` comment now says so explicitly.

## The computed lead

Threshold = half a facet = `(2π/12)/2` = **0.261799 rad = 15.000°**, derived from `FACES`, not
hardcoded. `landTargetFor` gives `d ∈ [ω·G/2, ω·G/2 + π/2)` = `[4.0000, 5.5708)` at `ω = 4, G = 2`.

Solved against the real module (bisection, 60 iterations):

| landing | `d` | `s` at crossing | **lead** | splash lands at |
| --- | --- | --- | --- | --- |
| shortest travel (best) | 4.0000 | 0.744168 | **0.5117 s** | 2.938 s after the strike |
| longest travel (worst) | 5.5708 | 0.820764 | **0.3585 s** | 3.092 s after the strike |

Residual at the crossing is 15.000° in both cases — by construction, which is the point: the old
fixed 0.7s lead left 28.1°–53.4°, a full facet or more, so the window showed a *neighbouring* symbol
while the splash named the result. It never can now.

Compare: `drumRest` at 3.450 s. So the splash gains 0.36–0.51 s and is correct on **every** landing
rather than the lucky ones.

## Gate output

From `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`:

```
lune run tests/run            985 passed, 0 failed, 985 total
stylua --check src tests tools   (clean)
selene src tools              0 errors, 0 warnings, 0 parse errors
```

(The `[QUEUE] dropping request` / `handler error ... boom` lines in the test output are
`HandlerQueue.spec`'s deliberate stderr fixtures, unrelated.)

**No automated gate loads `DrumController.client.luau`.** Reading was the gate; the trace below is it.

## Once-per-round trace (read from `DrumController.client.luau`)

1. **`gongHit`** (EventBus handler, ~line 239) — `omega = stage:GetAttribute("DrumKick") or DRUM_KICK`,
   `mode = "spin"`, **`settlingFired = false`** (reset #2). This is the reset that covers the path
   where `RoundUpdate`'s stall guard force-lands the drum to `"hold"` without passing through the
   spin branch; it is retained.
2. **spin branch** (line 158) — on `spinUntil` with a throw in hand: `glideD = theta - landTheta`,
   `glideT0 = os.clock()`, **`settlingFired = false`** (reset #1), `mode = "glide"`. `omega` is
   deliberately *not* zeroed here — the glide carries it, which is why `glideResidual` needs it.
3. **glide branch, `s < 1`** (line 180) — `if not settlingFired and glideResidual(glideD, omega, s) <= SPLASH_RESIDUAL`
   → fire `drumSettling`, latch `settlingFired = true`. The latch makes it at most once per glide.
4. **glide branch, `s >= 1`** (line 175) — `mode = "hold"`, `omega = 0`, fire `drumRest`. The residual
   test lives *only* in the `s < 1` arm, so the cue **cannot fire at or after rest**; and `"hold"`
   is never re-entered into `"glide"` without another `gongHit`.
5. **respin** — back to (1); both resets re-arm the cue.

**Cannot fire twice:** the only fire site is behind `settlingFired`, set in the same statement.
**Cannot be skipped silently:** if a single huge frame jumps from `s < threshold-crossing` straight
past `s >= 1`, the cue is never fired — but `main.client.luau`'s `drumRest` handler sets
`drumSettling = true` ("drumRest implies it, even if that cue was dropped"), and `REVEAL_SAFETY`
covers a dropped cue besides. The splash still lands, just at the old timing.

## Concerns

1. **A `DrumKick` stage override is now self-correcting, and that is the whole point** — but it is
   still untested, because nothing under Lune can see a Roblox attribute. What *is* proved is that
   the trigger stays correct for any `ω`: monotonicity of the residual needs `d ≥ ω·G/3`, and
   `landTargetFor(throw, omega * GLIDE_SEC / 2)` guarantees `d ≥ ω·G/2` using the same live `omega`.
   The spec test asserts monotonicity across the full `d` range at the shipped `ω`; the *algebraic*
   guarantee for other `ω` is argued here and in the code comment, not asserted.
2. **A very small `DrumKick`** (say 0.1) would make `d` possibly smaller than the threshold, firing
   the cue at glide start. That is not a defect — with `d` that small the drum is already within half
   a facet of home at `s = 0`, so the correct symbol *is* in the window. The invariant holds by
   construction rather than by luck, but it is worth knowing before anyone reads a 0-second lead as a
   bug.
3. **The lead band assertion is a band, with margin** (`0.30 < leadShortest < 0.70`,
   `0.25 < leadLongest < 0.70`, plus `leadLongest < leadShortest`), not the exact 0.5117/0.3585.
   Retiming the glide or the kick *should* move the lead; only a lead that has collapsed to nothing
   or grown unreadably long fails. Deliberate — but it means a modest retune will not be flagged.
4. **Three comment-only edits outside the named files.** The brief said nothing else in
   `main.client.luau` changes; I read that as behaviour, and left the code untouched, but three
   comments (two there, one in `EventBus.luau`) asserted "~0.7s" and were now simply false. Flagging
   it rather than burying it: revert those three hunks if the constraint was meant literally.
