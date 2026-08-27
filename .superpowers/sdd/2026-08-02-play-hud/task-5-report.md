# Task 5 Report: Expose the ledger fields on the profile route

## Summary

Implemented exactly per the brief:

1. Extracted and exported `buildProfilePayload(user: IUser)` in `server/src/routes/apiV1.ts`,
   above `createApiV1`. Every new/optional field defaulted with `??` (`unresolvedWin ?? false`,
   `escalationPrompts ?? true`, `seenBeats ?? []`, and each of the nine `counters.*` fields `?? 0`)
   so documents written before the 2026-08-02 play-HUD migration still resolve cleanly.
2. `GET /players/:robloxUserId` now spreads `buildProfilePayload(user)` into its response instead
   of hand-listing `totalPoints`/`pointsAtStake`/`currentStreak`/`stakingStreak`/`bestStreak`.
3. Added `PUT /players/:robloxUserId/preferences-hud` — accepts `{ escalationPrompts?: boolean,
   seenBeat?: string }`. `escalationPrompts` is a plain `$set`; `seenBeat` is `$addToSet` (add-only,
   never removes a beat). 400s if neither field is present in the body. Sits after `router.use(requireApiKey)`
   like every other route in the file, so it's already API-key gated — no auth code added or removed.

## Pre-existing fields preserved on `GET /players/:robloxUserId`

Before this task the handler returned: `robloxUserId`, `displayName`, `totalPoints`,
`pointsAtStake`, `currentStreak`, `stakingStreak`, `bestStreak`, `identityTier`.

Of these, `totalPoints`, `pointsAtStake`, `currentStreak`, `stakingStreak`, `bestStreak` are inside
`buildProfilePayload`'s output (verbatim, per the brief's spec) and are now produced by the spread.
`robloxUserId`, `displayName`, and `identityTier` are **not** in `buildProfilePayload`'s list (it
takes a bare `IUser`, no request params, and doesn't echo identity-tier bookkeeping) — I kept all
three explicitly in the `res.json({...})` call alongside the spread:

```ts
res.json({
    robloxUserId: req.params.robloxUserId,
    displayName: user.displayName,
    identityTier: user.identityTier,
    ...buildProfilePayload(user),
});
```

Nothing was dropped. `Cache-Control: no-store` and the optional `?country=` update-on-mismatch
logic above the response were untouched.

## Test additions (`server/src/routes/apiV1.test.ts`)

- Added `buildProfilePayload` to the existing `import { createApiV1 } from './apiV1'` line.
- `describe('buildProfilePayload', ...)` — the brief's two cases verbatim (full payload; empty/legacy doc).
- Extended `describe('GET /players/:robloxUserId', ...)` with a case asserting the gate, preference,
  full `counters` object, and that `robloxUserId`/`identityTier` still come through alongside the
  new fields (guards against a future edit re-dropping them).
- New `describe('PUT /players/:robloxUserId/preferences-hud', ...)`: sets `escalationPrompts`;
  adds a `seenBeat` twice (once already-present, once new) and asserts no duplicate and both beats
  retained (`$addToSet` semantics, add-only); 400 on an empty body; 401 without the API key.

## TDD evidence

**RED** — `npm test -- apiV1` (run before any implementation, only the test file edited):

```
 FAIL  src/routes/apiV1.test.ts > /api/v1 > buildProfilePayload > carries the gate, the preference and every counter
TypeError: buildProfilePayload is not a function

 FAIL  src/routes/apiV1.test.ts > /api/v1 > buildProfilePayload > tolerates a document written before these fields existed
TypeError: buildProfilePayload is not a function

 FAIL  src/routes/apiV1.test.ts > /api/v1 > PUT /players/:robloxUserId/preferences-hud > sets escalationPrompts
Error: expected 200 "OK", got 404 "Not Found"

 FAIL  src/routes/apiV1.test.ts > /api/v1 > PUT /players/:robloxUserId/preferences-hud > adds a seenBeat without duplicating it, and never removes one
Error: expected 200 "OK", got 404 "Not Found"

 FAIL  src/routes/apiV1.test.ts > /api/v1 > PUT /players/:robloxUserId/preferences-hud > 400 when the body has neither field
Error: expected 400 "Bad Request", got 404 "Not Found"

 Test Files  1 failed (1)
      Tests  6 failed | 37 passed (43)
```

This is exactly the expected failure: `buildProfilePayload` wasn't exported yet (module-load
`TypeError`), and the new PUT route didn't exist yet (Express falls through to 404). The ledger
assertion inside the existing `GET /players/:robloxUserId` test also failed (`counters` undefined)
for the same reason — the handler hadn't been touched yet.

**GREEN** — `npm test -- apiV1` after implementation:

```
 Test Files  1 passed (1)
      Tests  43 passed (43)
```

**Full suite** — `npm test` (server root):

```
 Test Files  13 passed (13)
      Tests  211 passed (211)
```

**Build** — `npm run build` (tsc): clean, no errors.

## Self-review

- Completeness: both response shapes match the brief's interfaces verbatim (`counters` object with
  all nine named keys; `PUT .../preferences-hud` body/response shape as specified).
- Quality: no duplication — the GET handler and the (future) HUD-consuming code both go through the
  single `buildProfilePayload` function; the `$set`/`$addToSet` compose cleanly for the case where
  a request sends both fields in one call.
- YAGNI: didn't add anything beyond what the brief asked for — no extra query params, no extra
  fields, no speculative validation beyond the type checks the brief specified.
- Test honesty: the RED run was captured with only the test file changed (implementation not yet
  written), confirming the failures are for the right reason (missing export / missing route), not
  a typo or unrelated break. All test assertions check response *values*, not just status codes.
- `shared-fixtures/game-rules.json` and both `GameRules` implementations: untouched, as required.
- No `.rbxl`/`.rbxlx` files touched (server-only task).

## Files changed

- `server/src/routes/apiV1.ts`
- `server/src/routes/apiV1.test.ts`

## Commit

`bc5c225` — `feat(server): profile route carries ledger counters, win gate and HUD preferences`
