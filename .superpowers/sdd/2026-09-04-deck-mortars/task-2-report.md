# Task 2 report: MortarPlacement — defaults, overrides, clamp, nudge, muzzle math

## What I implemented

`roblox/src/shared/MortarPlacement.luau` — a pure, `--!strict`, Lune-loadable decision module
for deck mortars:

- `MortarPlacement.MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }`, with a drift-caveat
  comment against `MORTAR_IDS` in `server/src/fireworks.ts`.
- `MortarPlacement.TUBE` keyed by mortar id, `{ bore, length }`: S `{1/6, 0.85}`,
  M `{1/3, 1.5}`, L `{0.5, 2.5}`.
- `export type Placement = { x: number, z: number, facing: string }`.
- `MortarPlacement.resolve(deckBounds, owned, stored, teahouseFP) -> { [string]: Placement }`:
  - Defaults sit at `z = maxZ - 1` (front edge), X spread evenly across the middle half of the
    deck's X span, one entry per owned tier in `MORTAR_ORDER` order (n=1 -> center; n=2 -> ±25%
    of span; n=3 -> −25%/0/+25%; generalizes for any n).
  - Stored placements override defaults per mortar id; both stored and default are clamped into
    `[minX+0.5, maxX-0.5] × [minZ+0.5, maxZ-0.5]`. Stored input is never mutated (verified by the
    spec).
  - Teahouse nudge: a resolved spot strictly inside `teahouseFP` moves to the front edge first
    (`z = maxZ - 1`, keeping its clamped x); if still inside, walks x outward in 1-stud steps,
    alternating +/-, until the point clears the footprint or the walk saturates. Always returns a
    position (never nil), never touches the caller's `stored` table.
  - Unknown/unowned ids in `stored` are ignored; every OWNED id always gets a row.
- `MortarPlacement.muzzleWorld(deckRow, placement, mortarId) -> (x, y, z)`: transforms the
  deck-local point `(placement.x, BASE_TOP + tube.length, placement.z)` (BASE_TOP = 0.5) through
  the 12-number row-major deck CFrame using `world = pos + R * local`, with R's rows
  `{r[4],r[5],r[6]; r[7],r[8],r[9]; r[10],r[11],r[12]}` per the brief's Step 3 and the
  `Spec.cframe` convention.

Test: `roblox/tests/MortarPlacement.spec.luau` — the brief's Step 1 spec, verbatim in content
(stylua reformatted a few long lines/tables; no logic changes — see Self-review).

## Test results

Full Lune suite green after implementation: **1638 passed, 0 failed, 1638 total** (the two `[WARN]`
lines above the summary are pre-existing, unrelated `HandlerQueue.spec` output, not from this
change).

## TDD Evidence

**RED** — `lune run tests/run` after writing only the spec (module didn't exist yet):

```
error requiring module "../src/shared/MortarPlacement": could not resolve child component "MortarPlacement"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
    Script '__mlua_require', Line 13
    Script '/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/MortarPlacement.spec', Line 4
[Stack End]
```

**GREEN** — `lune run tests/run` after implementing `MortarPlacement.luau`:

```
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom

1638 passed, 0 failed, 1638 total
```

Lint: `stylua --check src tests tools && selene src tools` from `roblox/` — clean (`0 errors, 0
warnings, 0 parse errors`) after running `stylua src tests tools` once to apply the repo's line-
wrap style to the new files (see Self-review).

## Files changed

- `roblox/src/shared/MortarPlacement.luau` (new, 163 lines)
- `roblox/tests/MortarPlacement.spec.luau` (new, 73 lines)

Commit: `9fcf650` — `feat(mortars): MortarPlacement -- front-edge defaults, overrides, clamp,
teahouse nudge, muzzle math`

## Self-review findings

- Every produced symbol matches the brief's exact names/shapes: `MORTAR_ORDER`, `TUBE`,
  `Placement`, `resolve`, `muzzleWorld`. Checked signatures and return shapes against the
  Interfaces block line by line.
- Spec file: I wrote the brief's Step-1 block verbatim, then ran `stylua src tests tools` (not
  just `--check`) because the verbatim text failed `stylua --check` on a few lines (a long
  boolean-and chain, one multi-key table literal, and `-(-22)` reformatted to `- -22`). This only
  reformats whitespace/line-wraps — I diffed the pre- and post-format assertions and confirmed no
  test logic changed. Doing this was necessary to satisfy the house lint gate (`stylua --check`
  is part of Step 5 and CI); leaving the brief's exact formatting would have shipped a lint
  failure.
- Verified the row-major muzzle transform by hand against both spec cases (identity rotation and
  a 90° yaw row) before running the suite — matches.
- Verified the teahouse-nudge test's numbers by hand: with `teahouseFP` matching the deck's full
  X width, the only way to satisfy `expect(inside).toBe(false)` is for the escape walk to reach
  the deck's raw edge (x = 8), where `8 < teahouse.maxX (8)` is false by strict inequality —
  clamping the escape walk to the *placement* inset (`maxX - 0.5 = 7.5`) can never trigger this,
  since 7.5 is still strictly inside an 8-wide teahouse. See Concerns below for the judgment call
  this required.
- No YAGNI creep: no extra public API, no unused fields, no speculative generality beyond what
  `resolve`'s n-item default-spread formula needs to generalize past n=1..3.

## Concerns

- **Interpretive judgment call, not spelled out in the brief**: the teahouse-nudge x-walk clamps
  candidate positions to the *raw* deck bounds (`[minX, maxX]`), not the narrower
  `[minX+0.5, maxX-0.5]` placement inset used everywhere else. I inferred this from the brief's
  test case, where the teahouse footprint spans the full deck width — under the tighter inset,
  the walk can never escape (since 7.5 < 8 = teahouse.maxX always), so the test could not pass.
  Reasoning documented inline in the `nudge()` function's leading comment ("escaping a hide-zone
  outranks staying inset"). Flagging this for review since it's the one place I filled a gap the
  brief didn't fully pin down — a mortar rescued by this path can end up flush at the physical
  deck edge rather than inset by 0.5 studs.
- Default `facing` for a fresh (non-stored) placement is `"N"` — not asserted by any test since
  `muzzleWorld` ignores `facing` entirely (it's render-only metadata per the brief). Chose `"N"`
  to match the existing `SiteCoordinator.luau` convention for a centered/default facing.
