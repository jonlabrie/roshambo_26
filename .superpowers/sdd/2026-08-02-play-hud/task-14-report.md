# Task 14 report: Day/night contrast for the HUD

## What was implemented

`roblox/src/client/HudController.client.luau` gained a new self-contained section at the end of
the file (banner-commented, matching the file's existing style) that subscribes to day/night and
adjusts two HUD elements the render loop never touches:

| Element | Property | Authored (night) | Day target |
|---|---|---|---|
| Plate backing (`plate`, top-centre) | `BackgroundTransparency` | 0.3 (script constant, captured) | 0.05 (more opaque = darker against a pale sky) |
| Tape-tile rim (`tapeTiles[i].rim`, the 5 result tiles' `UIStroke`) | `Color` | `TAN_RIM` (captured) | `INK` (deepened) |
| Tape-tile rim | `Thickness` | 1 (captured) | 2 |
| Tape-tile rim | `Transparency` | 0.3 (captured) | 0.05 |

**Why these two elements and not the throw buttons:** `render()` already repaints the throw
buttons' fill/rim (`BackgroundColor3`, `BackgroundTransparency`, `t.rim.Color`,
`t.rim.Transparency`) and the tape tiles' fill (`BackgroundColor3`, aged ivory→amber) on every
`HudState` event, for game-state reasons (selection, tape ageing) unrelated to time of day.
Driving those same properties from the day/night subscriber would just get overwritten on the
next render call. The plate's own backing and each tape tile's `UIStroke` are the only elements
in the file that `render()` never writes, so they were the safe, conflict-free target — this also
matches "keep it proportionate" (two elements, not a repaint of the whole HUD).

One supporting change was needed to reach the rims at all: the tape tile's `stroke(...)` call
previously discarded its return value. I captured it (`local tileRim = stroke(...)`) and added
`rim: UIStroke` to the `TapeTile` type so the day/night subscriber has a handle to mutate later.

## Capture mechanism

Two small helpers, `captureNumber` and `captureColor`, mirror `WaterVfxDayNight:68-75` exactly:
on first call for a given instance+key they read the *live* property, stash it on an attribute
(`AuthoredTransparency` / `AuthoredThickness` / `AuthoredColor`), and return it. Every later call
for that same instance+key returns the *stored attribute*, never the live property — so a second
`applyContrast()` call can never read back a value the first call already mutated. `applyContrast`
is a pure function of `nightFactor` and the once-captured authored baseline; calling it twice with
the same `nightFactor` produces bit-identical output.

Priming happens once, synchronously, at the bottom of the file — before the first `HudState` or
`DayNight` event can arrive — so the very first capture reads the true script-authored values
(0.3 transparency, `TAN_RIM`, thickness 1), not anything already touched by `render()` or a prior
day/night apply.

## Lerp, not scale

All three driven numeric/color properties are combined with `lerpNumber(dayTarget, authored, t)`
or `dayColor:Lerp(authoredColor, nightFactor)` — i.e. `value = dayTarget + (authored - dayTarget)
* nightFactor`, so `nightFactor = 1` reproduces the authored value exactly and `nightFactor = 0`
reaches the day target exactly. None of today's authored values happen to be zero (0.3
transparency, thickness 1, a real color), so scaling would technically have worked *today* — but
the brief's rule was followed anyway, both to stay consistent with the other three subscribers'
pattern and because a future author changing any of these constants to 0 would silently break a
scale-based approach. Lerp is correct regardless.

## `DayNightLockT` untouched

```
$ git diff -- roblox/src/shared/DayNight.luau
(empty)
```

`DayNightLockT` lives on the `workspace` attribute (set/read in `roblox/src/server/main.server.luau`),
not in `DayNight.luau` itself, and neither file was touched by this task. I did not open Studio or
change the lock value at all — Studio verification across 0.0/0.19/0.40/1.0 is explicitly the
controller's job per the task instructions, not mine.

## Gates

```
$ stylua --check src tests tools && selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ lune run tests/run
871 passed, 0 failed, 871 total
```

(Two `[WARN]` lines in the Lune output are from a pre-existing `HandlerQueue.spec` deliberately
exercising error handling — unrelated to this change, present before it too.)

## Commit

`5cbcf72` — `feat(roblox): HUD contrast tracks nightFactor so day stays legible`
(`roblox/src/client/HudController.client.luau`, +89/-3)

## Self-review

- **Completeness:** subscribes via both `EventBus.DayNight` and the `CurrentNightFactor`
  attribute-changed signal, primes once before either can fire, and drives exactly the two
  elements the brief names (plate backing, tile rims).
- **YAGNI:** did not touch the throw buttons, tape-tile fill, bank/fate buttons, or timer — none
  were named by the brief, and touching the first two would conflict with `render()`'s ownership.
  Did not introduce a new shared module; the lerp/capture helpers are ~20 lines local to this file,
  which is proportionate for two elements and doesn't justify extracting a `HudNightDim` module.
- **Can a second apply compound the first?** No. Every driven value is `f(dayTarget, authoredCapture,
  nightFactor)` where `authoredCapture` is read from an attribute that is written once and never
  overwritten by `applyContrast` itself (it's a different attribute name from the live property).
  Calling `applyContrast()` any number of times with the same `nightFactor` yields the same output;
  varying `nightFactor` sweeps deterministically between the two named endpoints with no drift.
