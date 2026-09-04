# Task 2 report: MortarPlacement — mount-aware resolve, pose, launch

## Final-review fix round

**Finding:** whole-branch review flagged that the spec's promised "one-line lever" (flip the
default mount from `"floor"` to `"rail"`) would ERROR every placement-less deck. `resolve`'s
rail branch had `assert(override, "mount = 'rail' requires a stored override")` and no default
path — the only way to reach `mount == "rail"` with `override == nil` is exactly the no-record,
default-mount-is-rail case the lever is supposed to enable, and that path immediately asserted.

**Fix (`roblox/src/shared/MortarPlacement.luau`):**

- Added `local DEFAULT_MOUNT = "floor"`, the single constant `resolve` reads for a mortar with
  no stored record at all (previously the literal `"floor"` was inlined). Comment names it
  explicitly as the owner's Task 7 gate lever.
- Added `MortarPlacement.railDefault(deckBounds, i, n) -> (x, z, aim)`: the staggered
  deck-local rail spot for the i-th of n owned mortars — reuses the SAME `defaultX(deckBounds,
  i, n)` stagger the floor defaults use, clamps into `RAIL.newelMargin` insets (instead of the
  floor placement inset), pins `z = minZ + RAIL.capWidth / 2`, and always returns `aim = "C"`.
  Exported specifically so the no-override rail mechanism is directly testable even though
  `resolve`'s public surface can't reach it while `DEFAULT_MOUNT` stays `"floor"` this round.
- `resolve`'s rail branch now has two legs instead of an assert: `override` present → clamp
  `override.offset[1]` (unchanged from before); `override` absent → delegate to
  `MortarPlacement.railDefault(deckBounds, i, n)`. The `assert` is gone — the no-override rail
  path is now legal, not fatal. Flipping `DEFAULT_MOUNT` to `"rail"` next round is now genuinely
  a one-line, non-erroring change: every owned mortar without a stored record would route
  through `railDefault` instead of the removed assert.

**Test approach:** `resolve()` itself cannot be driven down the no-override rail path this
round, because `DEFAULT_MOUNT` is a file-local constant fixed at `"floor"` — there is no public
way to make `resolve` treat an absent record as `"rail"` without changing that constant. So per
the coordinator's guidance, the fix routes that case through a shared, exported helper
(`railDefault`) and the new test — `"railDefault: staggers S/M/L along the cap, clamped to the
newel margins, aim C, never throws"` — calls it directly for `i = 1..3` of `n = 3` (the same
shape `ALL`/`MORTAR_ORDER` produce) and asserts: `aim == "C"` every time, `z` pinned to
`minZ + capWidth/2`, `x` staying within `[minX + newelMargin, maxX - newelMargin]`, and the
three `x`s strictly increasing (S < M < L, the same stagger direction the floor defaults use).
The test's mere completion without an error is itself the "never throws" proof — RED-state
before the fix was `attempt to call a nil value` (the function didn't exist yet), so the test
also proves the function/path exists.

TDD evidence:

RED (`lune run tests/run`, test added, `railDefault` not yet implemented):
```
FAIL  MortarPlacement — default-first gear placement > railDefault: staggers S/M/L along the cap, clamped to the newel margins, aim C, never throws
      tests/MortarPlacement.spec:112: attempt to call a nil value
1652 passed, 1 failed, 1653 total
```

GREEN (after implementing `DEFAULT_MOUNT` + `railDefault` + the two-leg rail branch):
```
1653 passed, 0 failed, 1653 total
```

Lint (full output):
```
$ stylua --check src tests tools   # one formatting fix applied via `stylua src tests tools` (the new
                                    # test's long name line needed reflow), then re-verified clean
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

Files changed (this round): `roblox/src/shared/MortarPlacement.luau`,
`roblox/tests/MortarPlacement.spec.luau`.

Self-review: re-read the full diff before committing — the change is additive and minimal
(one new local constant, one new exported helper, the rail branch's `assert` replaced by an
`if override … else …`); the existing "legacy records and absent records…" test (explicit
`mount = "rail"` override, which still requires and reads `offset`) and all other MortarPlacement
tests still pass unchanged, confirming the explicit-override rail path is byte-identical to
before. `git status` before staging showed only the two intended files plus the pre-existing
unrelated working-tree changes (`.superpowers/sdd/.gitignore`, `art/birds/uguisu/...blend`),
which were left untouched.

Concern carried forward unchanged from the original round: `main.server.luau` and
`TreatmentApplier.luau` still reference the deleted `muzzleWorld`/old `BASE_TOP` — out of scope
here too, Task 4's job.

Commit: `8e1a61b` fix(mortars): rail-default lever no longer errors -- resolve's rail branch
grows a no-override path

---

## What was implemented

`roblox/src/shared/MortarPlacement.luau`:

- New exported constants: `AIMS = { "L", "C", "R" }`, `ELEVATION = { floor = 12, rail = 25 }`,
  `RAIL = { capTop = 2.75, capWidth = 0.45, newelMargin = 0.95 }` (drift-caveat comment against
  `PadOps.luau`'s `CAP_TOP`/`CAP_W`/`NEWEL_W` — checked those literal values: `CAP_TOP = 2.75`,
  `CAP_W = 0.45`, `NEWEL_W = 0.45`, so `newelMargin = 0.45 + 0.5 = 0.95` matches), `BASE_OFFSET =
  { floor = 0.5, rail = 0.35 }`.
- File-local `AIM_DIR` table (`L`/`C`/`R` unit XZ directions), consumed only by `axisLocal`.
- `type Resolved = { mount: string, x: number, z: number, aim: string }` replaces the old
  `Placement` type. `StoredPlacement` gained optional `mount`/`aim` fields; `facing` is now
  optional (still accepted on legacy records, ignored).
- `resolve()`: floor path (defaults/clamp/nudge) is untouched logic — same `clampPoint`,
  `defaultX`, `nudge` calls in the same order. Added a `mount`/`aim` read: missing on the
  stored record → `"floor"`/`"C"`; `mount = "rail"` takes a separate branch — clamps
  `offset[1]` into `[minX + newelMargin, maxX - newelMargin]`, sets
  `z = minZ + capWidth / 2`, and never nudges (rail can't overlap the teahouse).
- `axisLocal(mount, aim)` — new pure function, `(sin(el)*ax, cos(el), sin(el)*az)`.
- `pose(deckRow, resolved, _mortarId)` — new function computing world mount point + world unit
  axis by running both the mount-local point (with `mountY = 0`/`RAIL.capTop`) and the local
  axis through the same 12-number row-major deck row `muzzleWorld` used (point gets translation
  + rotation, axis gets rotation only). `mortarId` param kept per the brief's signature but is
  unused by pose itself, so named `_mortarId` to satisfy selene's unused-variable lint.
- `launch(deckRow, resolved, mortarId)` — new function, replaces `muzzleWorld` (deleted).
  Calls `pose`, then walks `BASE_OFFSET[mount] + TUBE[mortarId].length` up the world axis for
  the origin; heading is the axis unchanged.
- `muzzleWorld` deleted entirely, per the brief ("its sole caller is updated by a later task").

`roblox/tests/MortarPlacement.spec.luau`:

- Replaced the `muzzleWorld` test block with the brief's four new tests verbatim, including the
  tight-form 90°-yaw assertion (`math.abs(oz - (-22)) < 1e-9`) per the controller ruling.

## Old-assertion adjustment

One existing test needed an adjustment: **"stored placements override defaults and get
clamped, never mutated"** previously asserted `out["mortar:S"].facing == "E"`. The new
`Resolved` type (per the Interfaces block) has no `facing` field — `facing` is explicitly
"ignored" per the brief. Since the stored record in that test has no `mount`/`aim`, I replaced
the facing assertion with the correct new-shape expectation: `mount == "floor"` and
`aim == "C"`. This is a shape change only, not a behavior change (the coordinates and clamp
values in that test are byte-identical to before). No other existing test referenced `facing`
in an assertion (`"a spot inside teahouse..."` sets `facing = "N"` on the stored input but never
asserts it back), so no other adjustments were needed.

## TDD evidence

RED (`lune run tests/run`, after replacing the test block, before implementing):
```
FAIL  MortarPlacement — default-first gear placement > legacy records and absent records resolve floor/C; rail records ride the cap
      tests/MortarPlacement.spec:89: expected nil to be floor
FAIL  MortarPlacement — default-first gear placement > axisLocal: C leans toward -Z by the mount's elevation; L/R yaw 30 degrees
      tests/MortarPlacement.spec:100: attempt to call a nil value
FAIL  MortarPlacement — default-first gear placement > launch: identity deck row, rail C -- muzzle sits up the tilted axis, heading matches
      tests/MortarPlacement.spec:115: attempt to call a nil value
FAIL  MortarPlacement — default-first gear placement > launch: 90-degree yaw deck row rotates both point and heading
      tests/MortarPlacement.spec:130: attempt to call a nil value
1648 passed, 4 failed, 1652 total
```

After implementing, one pre-existing test failed on the shape change (`facing` gone):
```
FAIL  MortarPlacement — default-first gear placement > stored placements override defaults and get clamped, never mutated
      tests/MortarPlacement.spec:37: expected nil to be E
1651 passed, 1 failed, 1652 total
```

GREEN (after the old-assertion adjustment):
```
1652 passed, 0 failed, 1652 total
```

Lint:
```
$ stylua --check src tests tools   # (one formatting fix applied via `stylua src tests tools`, then re-verified clean)
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

## Files changed

- `roblox/src/shared/MortarPlacement.luau`
- `roblox/tests/MortarPlacement.spec.luau`

## Self-review findings

- Reviewed the full `git diff` for both files before committing; floor-path logic (`clampPoint`,
  `defaultX`, `nudge`) is byte-for-byte unchanged, only the surrounding record-reading/output
  shape changed, matching the brief's "floor path unchanged" requirement.
- Confirmed `RAIL.newelMargin` derivation against the live `PadOps.luau` constants
  (`CAP_TOP/CAP_H/CAP_W = 2.75, 0.3, 0.45`; `NEWEL_H/NEWEL_W = 2.75, 0.45`) rather than trusting
  the brief's numbers blind — they match.
- Confirmed no other `.luau` file in `src/`/`tests/`/`tools/` references the deleted `Placement`
  type or calls `axisLocal`/`pose`/`launch` yet (only the intended two files changed).
- Ran `git status` before staging/committing to confirm only the two intended files were staged
  (the working tree also has unrelated pre-existing modifications to
  `.superpowers/sdd/.gitignore` and `art/birds/uguisu/uguisu_authored.blend` from before this
  task started — left untouched and unstaged).

## Concerns

- `MortarPlacement.muzzleWorld` is now deleted, but `src/server/main.server.luau:1384` (`local
  wx, wy, wz = MortarPlacement.muzzleWorld(row, spot, requiredMortar)`) and
  `src/server/TreatmentApplier.luau` (its own `MORTAR_BASE_TOP` local plus a comment referencing
  `BASE_TOP`) still reference the old API/constant. This is expected and explicitly scoped out
  of this task per the brief ("its sole caller is updated by a later task — you only update THIS
  module and its spec file") — `lune run tests/run` only runs the `tests/` spec suite, so this
  does not fail CI at this stage, but the Roblox place will not build/type-check cleanly against
  `main.server.luau` until Task 4 lands. Flagging so it isn't mistaken for an oversight.
- `resolve()`'s rail branch asserts `override` is present when `mount == "rail"` is read off it
  — this can only happen when `override.mount == "rail"`, so the assert is unreachable dead
  code in practice, but I left it as a defensive invariant since Luau's type system can't prove
  `override ~= nil` from `mount` alone inside the loop.
