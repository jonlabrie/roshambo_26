# Task 6 report — Powder fuel on `shows/reserve`

**Status:** complete. Commit `9c98677` on `thread/powder`.

## What was implemented

`POST /api/v1/players/:robloxUserId/shows/reserve` now accepts `fuel: 'powder'` alongside
`fuel: 'inventory'`.

- The fuel guard became `show.fuel !== 'inventory' && show.fuel !== 'powder'` — an unknown fuel
  (e.g. `'wishes'`) still gets 400 `FUEL_UNSUPPORTED`.
- The powder branch sits **after** the existing mortar-ownership loop, so gear ownership is
  checked for both fuels before anything is debited (the brief's placement; the ownership loop
  was already fuel-agnostic, so no change was needed there).
- Every cue's shell must be powder-eligible: 409 `POWDER_INELIGIBLE` with `shellId` on the first
  offender. `POWDER_INELIGIBLE` is empty today, so this is a latch for the first rare shell.
- Cost = Σ `SHELL_PRICES[shellId]` over the cues (duplicates counted per cue, not per shell id).
- Debited in ONE conditional update: `findOneAndUpdate({ _id: user._id, powder: { $gte: cost } },
  { $inc: { powder: -cost } }, { new: true })`. No match → 409 `INSUFFICIENT_POWDER` with
  `{ needed: cost, held: user.powder ?? 0 }` and nothing written.
- 200 body: `{ reservationId, stageId, fuel: 'powder', cues, debited: { powder: cost },
  remaining: { powder: updated.powder } }`.
- The inventory path is otherwise untouched; its 200 body gained `fuel: 'inventory'`.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/routes/apiV1.ts`
  (+22 in the reserve route, one guard line changed, one response field added)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/routes/apiV1.test.ts`
  (two new powder tests; the `fuel: 'powder'` → `FUEL_UNSUPPORTED` assertion replaced by
  `fuel: 'wishes'`, and that test renamed; one `fuel: 'inventory'` assertion added to the
  inventory happy path so the new response field is covered)

No other file was touched. `roblox/src/server/main.server.luau` was not edited.

## RED / GREEN evidence

RED (tests written, implementation not yet present) —
`npx vitest run src/routes/apiV1.test.ts -t 'reserve'`:

```
 Test Files  1 failed (1)
      Tests  3 failed | 4 passed | 93 skipped (100)
```

The three failures were the two new powder tests (`expected 409 "Conflict", got 400 "Bad Request"`
and the same on the 200 case — the route was still rejecting powder outright) and the inventory
happy path's new `fuel: 'inventory'` assertion.

GREEN, same scope: `Tests  7 passed | 93 skipped (100)`.

Full server suite + typecheck (`npm test`, `npx tsc --noEmit`) from `server/`:

```
 Test Files  30 passed (30)
      Tests  647 passed | 1 skipped (648)
TSC OK
```

Run twice, both clean.

## Self-review

- **`SHELL_PRICES[c.shellId]` cannot be `undefined`.** Two gates precede it: `validateShow` has
  already validated every cue (so `shellId` is a known shell), and `isPowderEligible` returns false
  for anything outside `SHELL_IDS`. So the reduce cannot produce `NaN` and slip a `$gte: NaN`
  filter into Mongo. This is load-bearing but implicit — if `validateShow` ever loosens, the
  eligibility check is the remaining guard, and it does the right thing.
- **Ordering is deliberate**: eligibility (a property of the show) is checked before the balance
  (a property of the player), so a player who is both broke and holding an ineligible shell is
  told the fixable thing first, and no debit is attempted.
- **Atomicity**: single conditional update, same shape as the inventory path and the topup/melt
  routes. Concurrent powder reserves cannot overspend — the `$gte` filter is the guard. There is
  no test for concurrent *powder* reserves (the existing concurrency test covers inventory); the
  mechanism is identical, but the coverage is asymmetric.
- **`held: user.powder ?? 0`** reports the balance as read *before* the failed update, not a
  re-read. Under a concurrent debit the reported `held` can be stale by the time the client sees
  it. The inventory path has exactly the same property (`held` comes from the pre-read `user`), so
  this is consistent rather than a new wart.
- **No inventory is touched on the powder path** — asserted directly (`after!.fireworks.size` is
  0 for a player who reserved a three-cue show on powder).
- Server sources are outside the root eslint scope (both files report "File ignored by default"),
  so lint is a no-op here; formatting follows the surrounding route exactly.

## Concerns

1. One flaky failure was observed on the first full-suite run — `apiV1.test.ts` >
   "names the durations openMs/lockMs/revealMs", a timing-sensitive round-duration assertion
   unrelated to this change. It passed on both subsequent full runs and on every scoped run. Worth
   knowing about if CI goes red on that name; it is not from this task.
2. `remaining: { powder }` and `debited: { powder }` use a different shape from the inventory
   path's per-shell-id maps. That is what the brief specifies and the client can branch on `fuel`,
   but any consumer that treats `debited` as "a map of shell id → count" will now see a `powder`
   key. Sub-project B's Roblox-side consumer should be checked when it lands.
3. Powder-fuelled shows grant no inventory and consume none, so a powder show leaves no trace in
   `fireworks`. Anything that reconstructs "what did this player launch" from inventory deltas
   will undercount powder shows; the reservation record is the only witness.
