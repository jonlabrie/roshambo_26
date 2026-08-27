# Task 2: VacantState.resolve — Report

## Summary

Completed Task 2 (VacantState.resolve) following TDD discipline. Created module `roblox/src/shared/VacantState.luau` with discriminated `Treatment` union type and pure `resolve()` function that maps pad occupancy + class to visual treatments. Added comprehensive test suite `roblox/tests/VacantState.spec.luau`.

## Implementation

**File:** `roblox/src/shared/VacantState.luau`
- Export type `Treatment = { kind: "structure", loadout: any, lit: boolean } | { kind: "garden" }`
- Function: `resolve(occupant: string?, ownerLoadout: any?, vacantForm: string?) -> Treatment`
- Logic:
  - Claimed (occupant ≠ nil): returns structure with ownerLoadout (or dormant fallback), lit=true
  - Vacant "pocket-garden": returns garden marker
  - Vacant cliff (dormant-structure or omitted): returns dormant structure, lit=false
- Helper: `dormant()` returns a fresh `{ baseStyle = "teahouse-1story", colorScheme = "scheme.dormant" }` table each call

**Tests:** `roblox/tests/VacantState.spec.luau`
- 4 test cases covering: vacant cliff (omitted/explicit), claimed with loadout, claimed without loadout (defensive), vacant valley
- All assertions pass; reference identity test (`expect(t.loadout).toBe(owner)`) confirms pass-through semantics

## Results

- **Test suite:** 278 passing (274 baseline + 4 new VacantState tests); 0 failed
- **Commit:** `ff9f981` — "feat(roblox): VacantState.resolve — occupancy+class -> structure|garden treatment"
- **No regressions:** Full suite green; no Roblox datatypes or random calls

## Concerns

None. Module is pure, Lune-testable, no dependencies on runtime Roblox APIs or PadRegistry. Ready for downstream consumers (PadApplier and other incrementing tasks).
