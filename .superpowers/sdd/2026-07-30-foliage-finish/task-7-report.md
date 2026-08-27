# Task 7 Report: Keep-out gate + terrain material in samples (ZoneScatter)

## Summary

Enforced `PlanOptions.keepOut` (declared in Task 5, unused until now) as the
first gate in `ZoneScatter.plan`'s internal `accepts()` closure, and added
`Sample.material: string?` so `CanyonKeepOuts.blocks(x, z, material)` can be
passed directly as the callback. Clump-child probes now also carry the
nearest sample's `depth` (left off in Task 6) alongside the new `material`.

## Files changed

- `roblox/tools/builders/ZoneScatter.luau`
  - `Sample` type: added `material: string?`.
  - `accepts(zone, s)`: first check is now
    `if o.keepOut ~= nil and o.keepOut(s.x, s.z, s.material) then return false end`
    — runs before the recipe lookup, so it vetoes regardless of which zone/recipe
    would otherwise have accepted the sample.
  - Clump-child probe construction (inside the clump loop) extended from
    `{ x = cx, z = cz, y = cy, steep = ... }` to also carry
    `depth = cs and cs.depth or nil` and `material = cs and cs.material or nil`,
    so clump children are gated on both submersion and keep-out identically to
    their parent placement.
- `roblox/tests/ZoneScatter.spec.luau`
  - Appended `describe("ZoneScatter keep-out gate", ...)` with the two tests
    from the brief:
    1. An injected `keepOut` (arbitrary `x > 50` predicate) vetoes both plain
       ground placements and clump children (clumpChance=1, clumpSize=3).
    2. `CanyonKeepOuts.blocks(x, z, m)` passed as the callback verbatim keeps
       every placement out of the Karesansui zone (`CanyonKeepOuts.zoneAt`
       returns `nil` for every accepted placement's coordinates).

## TDD evidence

**RED** (`lune run tests/run`, before implementation):
```
FAIL  ZoneScatter keep-out gate > an injected keep-out vetoes ground and clump children alike
      .../ZoneScatter.spec:571: expected false to be true
FAIL  ZoneScatter keep-out gate > CanyonKeepOuts slots straight in as the callback
      .../ZoneScatter.spec:599: expected {name=Karesansui, ...} to be nil
690 passed, 2 failed, 692 total
```
(All 690 pre-existing tests green; only the 2 new tests failed, confirming
they exercise the not-yet-enforced `keepOut` path.)

**GREEN** (after implementation):
```
692 passed, 0 failed, 692 total
```
(The `[WARN] [QUEUE] ...` lines around the pass count are pre-existing noise
from an unrelated `HandlerQueue.spec` fault-injection test, not a failure.)

**Lint:**
```
stylua --check src tools tests   -> clean
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

## Commit

`c0f3337` — `feat(roblox): one keep-out authority - the planner consults CanyonKeepOuts`

## Self-review

- Verified `accepts()`'s keep-out check runs before the recipe-nil check, so
  an unknown recipe doesn't mask a keep-out veto (order doesn't matter for
  correctness here since both return `false`, but matches the brief's
  specified placement — first gate).
- Verified the two keep-out mechanisms compose correctly: `resolveZone`
  still short-circuits on `zone.recipe == "KeepOut"` (the ad-hoc
  FoliageZones parts) independently of `accepts()`'s new `o.keepOut` callback
  (the authored `CanyonKeepOuts` authority) — the brief calls this "the
  planner consults both," and both paths are exercised by the existing
  "KeepOut wins over overlapping zone" test (recipe-based) and the two new
  tests (callback-based).
- Checked other callers of `ZoneScatter` (`tools/studio/foliageZoneRecipes.luau`,
  `tools/studio/scatterPreserve.luau`) — Studio-only, not exercised by Lune
  tests, and out of this task's declared scope (wiring `keepOut`/`material`
  into the actual Studio scatter run is a later task). No changes needed
  there for this task to be correct and self-contained.
- Confirmed no stale comments: the `PlanOptions.keepOut` field had no
  "declared but not enforced" comment in the source to update: that phrasing
  only lived in the task brief.
- Full suite (692 tests) and CI-scope lint both clean; no pre-existing test
  regressed.

No follow-up concerns identified.
