# Task 2: Teahouses Model Field + GET/PUT Endpoints — COMPLETE

## Status
COMPLETE. All tests passing; no regressions.

## Implementation Summary

### Changes Made

1. **User Model** (`server/src/models/User.ts`)
   - Added `teahouses: Map<string, unknown>` to `IUser` interface
   - Added `teahouses: { type: Map, of: Schema.Types.Mixed, default: {} }` to UserSchema

2. **API Routes** (`server/src/routes/apiV1.ts`)
   - Imported `validateLoadout` and `validateSizeClass` from `../loadout`
   - Added `GET /players/:robloxUserId/teahouses` — returns `{ teahouses: {} }` for wanderers, with `Cache-Control: no-store`
   - Added `PUT /players/:robloxUserId/teahouses/:sizeClass` — validates loadout and sizeClass, upserts into user.teahouses, persists

3. **Tests** (`server/src/routes/apiV1.test.ts`)
   - Appended 5-test describe block `teahouses persistence`:
     - GET returns empty map for new users
     - PUT/GET round-trip
     - Multiple sizes + overwrites
     - Validation errors (400)
     - API key requirement (401)

### Test Results

**Focused Run** (`npm test -- apiV1`):
```
Test Files  1 passed (1)
      Tests  22 passed (22)
```

**Full Suite** (`npm test`):
```
Test Files  12 passed (12)
      Tests  95 passed (95)
```

All tests passing; no regressions.

## Commit

```
019605c feat(server): teahouse loadout persistence (User.teahouses + /api/v1 GET/PUT)
```

## Test Coverage

- **RED phase**: Endpoints 404'd; 4 tests failed
- **GREEN phase**: All endpoints wired; 22 apiV1 tests pass
- **REGRESSION**: Full suite confirms no impact on other 73 tests

## Spec Compliance

- Wanderer handling (no user created): ✓ GET returns `{}`, auto-creates via `resolveUser`
- Validation: ✓ Defers to Task 1 helpers (`validateLoadout`, `validateSizeClass`)
- Persistence: ✓ User.save() flushes to MongoDB
- Size-class cap: ✓ 8-class limit enforced via `validateSizeClass`
- Caching: ✓ `no-store` on GET for clock-sync safety
- API key gating: ✓ Inherited from `requireApiKey` middleware

## Concerns

None. Implementation matches brief exactly.
