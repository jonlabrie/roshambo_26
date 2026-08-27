# Task 2: Karesansui Builder + Generated Asset + Stage Wiring — Report

## Status
**DONE**

## Commit
- `d04f4dc` — feat(roblox): Karesansui generated asset — slate kerb, raked field slabs, EngawaBarrier guards

## Test Summary
- **549 total tests** (543 existing + 6 new Karesansui tests)
- All passing, 0 failed
- New tests verify:
  - Part count and naming (kerb×4, field×1, guard×4 per panel)
  - Corridor non-intersection (inviolable rule)
  - Field positioning inside kerbs, proud of terrace
  - Guard properties (invisible, 3.5 tall, EngawaBarrier, collidable)
  - Kerb vocabulary (Slate, gravel palette, proud top)
  - Field material variant selection by panel's long axis

## Quality
- **Formatting**: stylua ✓ (no changes required)
- **Linting**: selene ✓ (0 errors, 0 warnings)
- **Asset Generation**: `roblox/assets/Karesansui.model.json` created successfully
  - 18 parts (2 panels × 9 parts each)
  - East panel: 4 kerbs, 4 guards, 1 field (RakedSandEW variant)
  - South panel: 4 kerbs, 4 guards, 1 field (RakedSandEW variant)

## Files Modified/Created
- ✓ Created: `roblox/tools/builders/Karesansui.luau` (64 lines)
- ✓ Created: `roblox/tests/Karesansui.spec.luau` (99 lines)
- ✓ Created: `roblox/assets/Karesansui.model.json` (generated)
- ✓ Modified: `roblox/tools/genmodels.luau` (+1 require, +1 registry entry)
- ✓ Modified: `roblox/default.project.json` (+1 stage child declaration)
- ✓ Modified: `roblox/src/shared/WorkspaceConvention.luau` (+1 to DECLARED_STAGE_CHILDREN)

## Design Verification
- **Kerb geometry**: Mitre-cut (N/S span full width; E/W inset between them), dressed-slate (Material=Slate, palette.gravel color), seated proud of terrace floor (top=floorY+kerbProud)
- **Field slab**: Raked-sand variants selected by panel orientation (NS for tall panels, EW for wide panels), proud of terrace (slabTopY=floorY+slabProud)
- **Guard walls**: Invisible (Transparency=1), collidable (CanCollide=true), 3.5 studs tall, CollisionGroup="EngawaBarrier", follow kerb lines exactly
- **Corridor safety**: Verified via overlap test against K.corridors (eastCorridor, shopCorridor) — NOTHING intersects

## No Concerns
All requirements from the brief implemented exactly as specified. TDD workflow followed (failing test → builder → wiring → verify green). Asset pipeline fully integrated.
