# Task 4 Report: Resolving a win — RISK or BANK

## Summary

Implemented `resolveWin(userId, choice)` in `server/src/wallet.ts` and a new
`POST /api/v1/resolve-win` route in `server/src/routes/apiV1.ts`, exactly as specified in
`task-4-brief.md`. Extended `server/src/wallet.test.ts` in place (existing `bankPot` describe
block untouched, new `resolveWin` describe block added below it, matching its
`connectTestDb`/`clearTestDb`/`disconnectTestDb` + `User.create(...)` style).

## Changes

- `server/src/wallet.ts`
  - `bankPot`'s update document now also does `$inc: { lifetimeBanked: ... }` and
    `$set: { unresolvedWin: false }`, so banking both records the real lifetime-banked ledger
    figure and lifts the win gate.
  - New `resolveWin(userId, choice: 'risk' | 'bank')`: RISK does a conditional
    `findOneAndUpdate({ _id, unresolvedWin: true }, { $set: { unresolvedWin: false } })` — a
    no-op (returns `null`) if the player wasn't bound. BANK delegates to `bankPot`; if that
    returns `null` (nothing staked — should be unreachable after a real WIN, but is the worst
    failure mode if it ever happened), it falls back to the same gate-only clear so the player
    is never stranded unable to throw again.
- `server/src/routes/apiV1.ts`
  - Added `resolveWin` to the `from '../wallet'` import.
  - Added `POST /resolve-win` immediately after `/bank`, following its exact model:
    `resolveUser` lookup, `BAD_REQUEST`/`RESOLVE_FAILED` error shape, and a response echoing
    `totalPoints`, `pointsAtStake`, `stakingStreak`, `currentStreak`, `unresolvedWin`. A `null`
    from `resolveWin` (already resolved, or a duplicate tap) is not treated as an error — the
    route falls back to the pre-lookup `user` snapshot so the client still gets convergent
    state back.
- `server/src/wallet.test.ts`
  - Added `resolveWin` to the `from './wallet'` import.
  - Added the six-case `describe('resolveWin', ...)` block from the brief verbatim: RISK
    clears the gate and leaves the pot; BANK clears the gate and moves the pot;
    BANK records `lifetimeBanked`; BANK with nothing staked still clears the gate (the
    stranded-player case); a double-tap BANK doesn't double-bank; a RISK when not bound is a
    no-op.

## TDD Evidence

**RED** — `cd server && npm test -- wallet`

Before implementing `resolveWin`, ran with only the test file changed (import + six new
tests added, `wallet.ts` untouched):

```
 FAIL  src/wallet.test.ts > resolveWin > RISK clears the gate and leaves the pot riding
TypeError: resolveWin is not a function
...
 FAIL  src/wallet.test.ts > resolveWin > BANK also records lifetimeBanked
TypeError: resolveWin is not a function
...
 FAIL  src/wallet.test.ts > resolveWin > BANK with nothing staked still clears the gate
TypeError: resolveWin is not a function
...
 FAIL  src/wallet.test.ts > resolveWin > is idempotent — a double-tap does not bank twice
TypeError: resolveWin is not a function
...
 FAIL  src/wallet.test.ts > resolveWin > RISK when not bound is a no-op, not an error
TypeError: resolveWin is not a function

 Test Files  1 failed (1)
      Tests  6 failed | 2 passed (8)
```

Failure is expected: `resolveWin` wasn't exported from `wallet.ts` yet. The two pre-existing
`bankPot` tests still passed, confirming the test file edit didn't disturb them.

**GREEN** — `cd server && npm test -- wallet`

After implementing `resolveWin` in `wallet.ts` and wiring the route:

```
 Test Files  1 passed (1)
      Tests  8 passed (8)
```

**Full suite** — `cd server && npm test`

```
 Test Files  13 passed (13)
      Tests  204 passed (204)
```

**Build** — `cd server && npm run build` — `tsc` completed with no errors.

## Self-Review

- Implementation matches the brief's code verbatim (both the `wallet.ts` diff and the route
  block) — no invented conventions, no scope creep.
- `bankPot`'s original contract is preserved: `pointsAtStake` → `totalPoints`,
  `stakingStreak` → 0, `currentStreak` untouched, `null` when nothing staked, conditional
  filter on `pointsAtStake` still guards double-banking races. The two original tests pass
  unchanged.
- The stranded-player fallback in `resolveWin`'s BANK branch is exercised by the
  "BANK with nothing staked still clears the gate" test and is real dead-simple code (a second
  conditional `findOneAndUpdate` gated on `unresolvedWin: true`) — not just a comment.
- The route's `null ?? user` fallback for `state` was read against `apiV1.ts`'s `/bank` route
  style before writing; response field list matches the brief's five fields exactly.
- Did not touch `shared-fixtures/game-rules.json` or either `GameRules` implementation, and
  didn't need to.
- No `.rbxl`/`.rbxlx` involved in this change.
- YAGNI: no extra validation, no extra fields, no defensive code beyond what the brief and its
  worst-failure-mode note asked for.
