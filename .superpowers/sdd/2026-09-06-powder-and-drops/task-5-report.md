# Task 5 report — the external grant seam (`PowderGrant`, idempotent by receipt)

**Status:** complete. Commit `d0b2e3d` — `feat(powder): the external grant seam -- PowderGrant rows make every receipt credit at most once`.

## What was implemented

`POST /api/v1/players/:robloxUserId/powder/grant` — the one door through which powder enters
from outside the game economy (Robux receipts, gifts, ops grants). Idempotent by `receiptId`:
a `PowderGrant` row is inserted FIRST behind a unique index, so a duplicate-key error (Mongo
11000) is the signal "already granted" and the `$inc` on `User.powder` runs at most once,
under replays and under races alike.

- 400 `BAD_AMOUNT` (non-integer or ≤ 0), `BAD_RECEIPT` (non-string, empty, or > 128 chars),
  `BAD_SOURCE` (not one of `robux | gift | ops`) — all validated before any write.
- 404 `RESOLVE_FAILED` if identity cannot resolve.
- 200 `{ powder, credited: amount, duplicate: false }` on first sight.
- 200 `{ powder, credited: 0, duplicate: true }` on a replay of the same `receiptId`.

No product ids here — the Roblox `ProcessReceipt` caller arrives in a later sub-project.

## Files changed

- `server/src/models/PowderGrant.ts` (new) — one row per external grant; `receiptId` unique,
  plus `userId`, `amount`, `source` enum, `createdAt`. Modelled on `server/src/models/BankEvent.ts`.
- `server/src/routes/apiV1.ts` — imports `PowderGrant`; new route inserted after `powder/topup`
  and before `fireworks/melt`.
- `server/src/routes/apiV1.test.ts` — `PowderGrant` import, `await PowderGrant.syncIndexes()`
  added to the suite's `beforeAll` after `connectTestDb()`, and the brief's three-test
  `describe('powder/grant — the external seam, idempotent by receipt')` block nested inside
  `describe('fireworks')` alongside the existing powder block.

## RED / GREEN evidence

**RED** — `npx vitest run src/routes/apiV1.test.ts -t "powder/grant"` before the route existed:

```
Tests  3 failed | 95 skipped (98)
Error: expected 200 "OK", got 404 "Not Found"
Error: expected 400 "Bad Request", got 404 "Not Found"
AssertionError: expected +0 to be 7   (the race test)
```

Ordering note: the model file was created before the RED run on purpose. The test file
imports `PowderGrant`, so without the model the failure would have been a module-resolution
error rather than the 404s the brief specifies as the RED signal. The behaviour under test —
the route — was absent for the RED run.

**GREEN** — `cd server && npm test`:

```
Test Files  30 passed (30)
     Tests  645 passed | 1 skipped (646)
```

`npx tsc --noEmit` → clean.

**Flake check** — the race test is the one with a timing dependency, so the grant block was
run five more times in isolation: `Tests 3 passed | 95 skipped` on every run. `clearTestDb()`
uses `deleteMany` rather than dropping collections, so the index built by `syncIndexes()` in
`beforeAll` survives every `beforeEach` — the arrangement is stable by construction, not by luck.

## Self-review

- **The insert-first ordering is the whole guarantee, and it is correct.** The row lands before
  the balance moves, so the failure mode of a crash is a granted row with no credit (at-most-once),
  never a credit with no row (which would double on retry).
- **Validation precedes `resolveUser`**, which upserts — so a malformed grant cannot mint an
  identity. The `robloxUserId` param guard (digits only) already covers the path segment.
- Errors other than 11000 are rethrown into the 500 handler rather than being swallowed as
  duplicates. A rethrown insert error means no row and no credit — the retry is clean.
- The route matches the shape of its neighbours (`powder/topup`, `fireworks/melt`): same
  try/catch, same 400/409/500 vocabulary, same one-authoritative-write discipline.
- `autoIndex` is not disabled in `server/src/index.ts`, so mongoose builds the unique index on
  first model use in the deployed server, matching the test's `syncIndexes()`.

## Concerns (none blocking; all inherited from the brief's specified code)

1. **At-most-once means a crash in the window loses a paid credit.** If the process dies between
   the `PowderGrant.create` and the `$inc`, the row exists, so `ProcessReceipt`'s retry is told
   `duplicate: true` and the player has paid Robux for powder they never received. The safer
   shape for a *paid* grant is a `credited: false` flag on the row, flipped after the `$inc`,
   with the duplicate path completing an uncredited row instead of reporting success. Worth
   revisiting when the `ProcessReceipt` caller lands — that is when real money starts flowing
   through this seam.
2. **`duplicate: true` can report a stale `powder`.** It returns the balance read *before* the
   winning request's `$inc`, so a loser in a race may report 0 while the true balance is 7. The
   `credited: 0` field is still correct and the tests pass, but a caller trusting `powder` from a
   duplicate response would show the player a stale wallet. A re-read before responding would fix it.
3. **`receiptId` is unique globally, not per user.** Deliberate for Robux receipts (already
   globally unique), but an ops or gift id scheme that reuses short ids across players would
   silently no-op the second player's grant. Whoever mints gift/ops receipt ids needs to know
   the key is global.
4. **`amount` has no upper bound.** `Number.isInteger` rejects NaN/Infinity/floats, but an ops
   grant of a billion is accepted. Acceptable while the route is API-key-gated and server-to-server.
