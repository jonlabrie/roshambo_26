# Home Portal Robustness Fixes Report

## Summary
Two defensive robustness improvements applied to the home-portal teleport flow:
1. Arena→deck teleport uses `DeckPlacement.resolve()` fallback for future-proofed unauthorized sizes
2. Portal-control build gates on both `portalOwned` and `lit` state

**Commit:** `beed8b3` — `fix(roblox): arena->deck teleport uses DeckPlacement.resolve; control build also gates on lit (home portal review)`

---

## Fix 1: deckCFForClaim Fallback

**File:** `roblox/src/server/main.server.luau` (line 1010)

**Change:** Replace raw index with `DeckPlacement.resolve()` call

```lua
-- Before:
return spec.deckPlacements[built.deckSize], built.deckSize

-- After:
return DeckPlacement.resolve(spec.deckPlacements, built.deckSize, spec.maxSize), built.deckSize
```

**Verification:**
- `DeckPlacement` already required at line 393 ✓
- Signature confirmed: `DeckPlacement.resolve(deckPlacements: Placements, deckSize: string, maxSize: string) -> { number }?`
- Signature matches exactly as specified ✓
- Returns the placement for `deckSize`, falls back to `maxSize` if `deckSize` is unauthored

---

## Fix 2: Portal-Control Build Gate

**File:** `roblox/src/server/TreatmentApplier.luau` (line 199)

**Change:** Add `lit` check to portal-control conditional

```lua
-- Before:
if treatment.portalOwned == true then

-- After:
if treatment.portalOwned == true and treatment.lit == true then
```

**Rationale:**
- Prevents dormant/unlit treatments from ever getting a control, even if a future site sets `portalOwned = true` without checking `lit`
- Currently behavior-preserving (all `portalOwned` settings come from `lit = true` treatments), but adds defensive hardening

---

## Test & Build Results

| Component | Result | Details |
|-----------|--------|---------|
| Lune tests | ✓ Pass | 446 passed, 0 failed |
| stylua format | ✓ Pass | No formatting issues |
| selene lint | ✓ Pass | 0 errors, 0 warnings |
| rojo build | ✓ Pass | Built successfully to rbxl |

**Command:** `cd roblox && lune run tests/run && stylua --check src tests && selene src && rojo build -o /tmp/hp-h.rbxl`

---

## Files Changed

1. `roblox/src/server/main.server.luau` (1 line)
2. `roblox/src/server/TreatmentApplier.luau` (1 line)

**Total diff:** +1 line defensive gate, +1 line resolve-fallback = 2 insertions, 2 deletions (net 0)
