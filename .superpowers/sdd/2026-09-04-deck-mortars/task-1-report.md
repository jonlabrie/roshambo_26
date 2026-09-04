# Task 1 Report: Backend — persistence, validation, routes

## What I implemented

Exactly the brief's Steps 1-7, mirroring the existing `deckDecorations` pattern:

1. `server/src/models/User.ts` — `IUser` interface gains
   `mortarPlacements: Record<string, { offset: [number, number]; facing: 'N' | 'E' | 'S' | 'W' }>;`
   beside `mortars`; schema gains `mortarPlacements: { type: Schema.Types.Mixed, default: {} },`
   beside `mortars`.
2. `server/src/loadout.ts` — new `validateMortarPlacements(value: unknown, owned: string[]): Check`,
   verbatim per the brief, placed beside `validateDecorations`/before `validateAccess`. Not
   exported/imported `Check` — it's a same-file local type already used by every other validator
   in the file.
3. `server/src/routes/apiV1.ts`:
   - `PUT /players/:robloxUserId/mortar-placements` — resolveUser → validate against
     `user.mortars ?? []` → assign → `user.markModified('mortarPlacements')` → save → echo
     `{ mortarPlacements }`. Placed directly above the existing `/access` PUT route.
   - `GET /players/:robloxUserId/fireworks` — response gains
     `mortarPlacements: user.mortarPlacements ?? {}`.
   - Import line for `../loadout` extended with `validateMortarPlacements`.

## What I tested and results

- `server/src/loadout.test.ts` — added `describe('validateMortarPlacements', …)` (3 `it`s, 6
  assertions in the third) verbatim from the brief's Step 1, importing `validateMortarPlacements`.
- `server/src/routes/apiV1.test.ts` — added two tests to the existing `fireworks` describe block,
  verbatim from the brief's Step 5: round-trip PUT→GET, and a 400 rejection for an unowned mortar.
- Full suite: `npm test` (from `server/`, via nvm 24.12.0) — **481 passed / 0 failed** across 20
  test files. Only output noise is a pre-existing Mongoose deprecation warning
  (`findOneAndUpdate`'s `new` option) unrelated to this change, present before my edits too.
- `npx tsc --noEmit` — clean, no errors.

## TDD Evidence

### RED — validator (Step 2)

Command:
```
cd server && npx vitest run src/loadout.test.ts
```
Output (excerpt):
```
FAIL  src/loadout.test.ts > validateMortarPlacements > accepts a well-formed owned placement map
TypeError: validateMortarPlacements is not a function
...
 Test Files  1 failed (1)
      Tests  3 failed | 58 passed (61)
```
Expected: `validateMortarPlacements` didn't exist yet in `loadout.ts`, so the import resolved to
`undefined` and calling it threw. Confirms the tests were exercising real code, not vacuously
passing.

### GREEN — validator (Step 3)

Command:
```
cd server && npx vitest run src/loadout.test.ts
```
Output:
```
 Test Files  1 passed (1)
      Tests  61 passed (61)
```

### RED — routes (Step 5, before Step 6)

Command:
```
cd server && npx vitest run src/routes/apiV1.test.ts -t "mortar placements"
```
Output (excerpt):
```
FAIL  src/routes/apiV1.test.ts > /api/v1 > fireworks > mortar placements round-trip and ride the fireworks GET
Error: expected 200 "OK", got 404 "Not Found"
```
Expected: the PUT route didn't exist yet, so Express fell through to 404.

### GREEN — routes (Step 6)

Command:
```
cd server && npx vitest run src/routes/apiV1.test.ts -t "mortar"
```
Output:
```
 Test Files  1 passed (1)
      Tests  4 passed | 70 skipped (74)
```

### GREEN — full suite (Step 7, pre-commit)

Command:
```
cd server && npm test
```
Output (tail):
```
 Test Files  20 passed (20)
      Tests  481 passed (481)
```

## Files changed

- `server/src/models/User.ts` — interface + schema field
- `server/src/loadout.ts` — `validateMortarPlacements` + `MORTAR_FACINGS`
- `server/src/routes/apiV1.ts` — import, new PUT route, fireworks GET carriage
- `server/src/loadout.test.ts` — `describe('validateMortarPlacements', …)`
- `server/src/routes/apiV1.test.ts` — two new tests in the `fireworks` describe

## Self-review findings

- Diff matches the brief's code snippets verbatim (validator, model field, route shape).
- `markModified('mortarPlacements')` is present before `save()`, per the brief's explicit warning.
- Ownership check uses `user.mortars ?? []` (the caller's actual owned list), not the static
  `MORTAR_IDS` — matches the brief's note that ownership, not just id shape, gates placement.
- Only the 5 intended files were staged for commit; unrelated pre-existing working-tree changes
  (`.superpowers/sdd/.gitignore`, `art/birds/uguisu/uguisu_authored.blend`) were left untouched
  and unstaged.
- `npx tsc --noEmit` is clean; no lint script exists in `server/package.json` so none was run.
- No YAGNI creep: no extra fields, no extra routes, no extra validation beyond what the brief and
  its tests specify.

## Issues or concerns

None. Task complete as specified.

---

## Fix report: review findings addressed

Review verdict: Approved with findings to fix. `validateMortarPlacements` was less strict than
its stated sibling `validatePlacement`, in three ways:

1. **Unknown keys silently accepted** — an entry like `{ offset, facing, evil: 1 }` passed and
   `evil` got persisted into the Mixed field.
2. **No offset magnitude bound** — `Number.isFinite` alone let `1e300` through; siblings cap at
   `MAX_PLACEMENT_OFFSET`.
3. **Duplicate `MORTAR_FACINGS` set** — should reuse the existing `PLACEMENT_FACINGS` (loadout.ts:55)
   instead of a second copy of the same four letters.

### What changed

`server/src/loadout.ts` (`validateMortarPlacements`):
- Removed the module-level `MORTAR_FACINGS` set.
- Added a key-allowlist loop over each placement entry (`k !== 'offset' && k !== 'facing'` →
  `{ ok: false, error: 'BAD_PLACEMENT' }`), mirroring `validatePlacement`'s own key check and its
  error code.
- Offset validation now loops with `Math.abs(n) > MAX_PLACEMENT_OFFSET` added to the existing
  finite check (still `BAD_OFFSET`), reusing the same `MAX_PLACEMENT_OFFSET` constant
  `validatePlacement`/`validateDecorations` already use.
- Facing check now tests against `PLACEMENT_FACINGS` instead of the removed `MORTAR_FACINGS`
  (still `BAD_FACING`).

`server/src/loadout.test.ts`: imported `MAX_PLACEMENT_OFFSET`; extended the existing
`describe('validateMortarPlacements', …)` block with two new failing-first tests:
- `rejects an extra key on a placement entry, mirroring validatePlacement`
- `rejects offsets beyond MAX_PLACEMENT_OFFSET, accepting exactly at the boundary` (also asserts
  the `1e300` case and the exact-boundary accept, `{ offset: [MAX_PLACEMENT_OFFSET,
  -MAX_PLACEMENT_OFFSET], facing: 'N' }` → `{ ok: true }`).

Existing error codes for other failure paths (`MORTAR_PLACEMENTS_NOT_OBJECT`, `MORTAR_NOT_OWNED`,
`PLACEMENT_NOT_OBJECT`) were left as-is — not flagged by the review, and changing them was out of
scope for this fix.

### Tests run

RED (before the fix, both new assertions failing):
```
cd server && npx vitest run src/loadout.test.ts -t "validateMortarPlacements"
```
```
 FAIL  ... rejects an extra key on a placement entry, mirroring validatePlacement
 FAIL  ... rejects offsets beyond MAX_PLACEMENT_OFFSET, accepting exactly at the boundary
 Test Files  1 failed (1)
      Tests  2 failed | 3 passed | 58 skipped (63)
```

GREEN (after the fix):
```
cd server && npx vitest run src/loadout.test.ts -t "validateMortarPlacements"
```
```
 Test Files  1 passed (1)
      Tests  5 passed | 58 skipped (63)
```

Full suite before committing:
```
cd server && npm test
```
```
 Test Files  20 passed (20)
      Tests  483 passed (483)
```
(483 = 481 from the initial implementation + 2 new tests.)

`npx tsc --noEmit` — clean.

### Commit

New commit (no amend), same message style and trailers:
`1468c8a` — `fix(mortars): validator strictness -- reject unknown keys, bound offset magnitude, reuse PLACEMENT_FACINGS`
