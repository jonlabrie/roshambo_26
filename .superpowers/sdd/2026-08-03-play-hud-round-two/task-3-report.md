# Task 3 report: `HudLayout` — the ring's slot

**Status:** DONE (corrected)
**Original commit:** `ecf1231` — "feat(roblox): the bottom row is as tall as the ring, not the tape"
**Correction commit:** `1bb192a` — "fix(roblox): the ring takes the hamburger's slot, not the tape's row"

## Correction

The original brief was wrong about where the ring sits: it takes the **hamburger's slot**
(inboard-left of the throw cluster, level with the button row), not a slot in the tape's row.
The bottom row never needed to grow. Per the coordinator's correction (spec/plan fixed in
`2563b97`):
- Deleted `BOTTOM_ROW_H` / `BOTTOM_ROW_H_TOUCH` entirely.
- `AREA_H` / `AREA_H_TOUCH` restored to their original derivation (`BTN_H + ROW_GAP + TILE`).
- `RING_D`, `RING_D_TOUCH`, `RING_THICKNESS`, `RING_THICKNESS_TOUCH`, `RING_GAP` kept as-is — the
  ring is still sized to a throw button, now because it sits *beside* the button row.
- Ring block comment rewritten to state the correct slot.
- Test file: deleted the "bottom row is as tall as its tallest occupant" test; replaced the
  `AREA_H` test with one that pins the absence of growth (`BOTTOM_ROW_H` is `nil`); reverted the
  "primitives" describe block's `AREA_H`/`AREA_H_TOUCH` assertions to their original `TILE`-based
  form.

## Gates (post-correction)
- `lune run tests/run`: 948 passed, 0 failed (949 minus the deleted bottom-row test).
- `stylua --check src tests tools`: clean.
- `selene src tools`: 0 errors, 0 warnings.

## Final values (match pre-Task-3 baseline)
| Value | Value |
| --- | --- |
| `AREA_H` | 120 |
| `AREA_H_TOUCH` | 78 |
| `CLUSTER_TOP_FROM_BOTTOM` | 182 |
| `CLUSTER_TOP_FROM_BOTTOM_TOUCH` | 140 |
| `RING_D` / `RING_D_TOUCH` | 76 / 44 |
| `RING_THICKNESS` / `RING_THICKNESS_TOUCH` | 6 / 3 |
| `BOTTOM_ROW_H` | (deleted, `nil`) |

Confirmed by direct `require` + print, matching the module's own test assertions.

## Placement (unchanged, still correct)
Ring block (`RING_D`/`RING_D_TOUCH`/`RING_THICKNESS`/`RING_THICKNESS_TOUCH`/`RING_GAP`) sits
immediately after `HudLayout.TILE_TOUCH` — after both `BTN_H_TOUCH` and `TILE_TOUCH` are
declared — and before `BANK_H`. No `nil` arithmetic.

## Concerns
None. `HudController` still reads the old `HudLayout` shape (fixed in Tasks 4–6); Lune does not
compile `.client.luau` so nothing fails here.
