# Task 4 report — `powder/topup` and `fireworks/melt`; `powder` on the reads

**Status:** complete. Commit `ba161a3` on `thread/powder`.

## Implemented

- `GET …/players/:id/economy` now returns `powder: user.powder ?? 0`.
- `GET …/players/:id/fireworks` now returns `powder: user.powder ?? 0`.
- `POST …/players/:id/powder/topup { points }` — points → powder, ONE WAY.
  `400 BAD_AMOUNT` unless a positive integer (rejects `0`, negatives, fractions,
  strings, `undefined`); `404 RESOLVE_FAILED`; `409 INSUFFICIENT_POINTS { held }`;
  `200 { powder, totalPoints }`.
- `POST …/players/:id/fireworks/melt { shellId, count }` — shells → powder at
  `SHELL_PRICES[shellId]`. `400 BAD_SHELL` / `BAD_COUNT` / `POWDER_INELIGIBLE`;
  `404 RESOLVE_FAILED`; `409 NONE_HELD { held }`;
  `200 { shellId, count: remaining, powder, credited }`.
- `isPowderEligible` imported from `../fireworks`.

Both balance moves are a single conditional `findOneAndUpdate` — the balance check
lives in the filter (`totalPoints: { $gte: points }` / `fireworks.<id>: { $gte: count }`)
and the move in `$inc`, matching the idiom of `fireworks/spend` and `/purchase`.
No read-then-save anywhere. Nothing in either route moves powder toward
`totalPoints`: the only `$inc` on `powder` is positive, the only `$inc` on
`totalPoints` is negative.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/routes/apiV1.ts`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/routes/apiV1.test.ts`

Nothing else was staged; `.superpowers/sdd/…` remains untracked. `roblox/src/server/main.server.luau` untouched.

## RED / GREEN evidence

RED — `npx vitest run src/routes/apiV1.test.ts -t "powder"` before implementation:

```
Tests  7 failed | 1 passed | 87 skipped (95)
```

Failures were exactly the expected shape: `expected 200 "OK", got 404 "Not Found"` on
the two POST routes, `[404, 404]` instead of `[200, 409]` on the concurrency test, and
`undefined` instead of `0` for `powder` on the two reads. (The 1 pass is a pre-existing
`powderEligible` assertion matched by the `-t "powder"` filter.)

GREEN — `cd server && npm test`:

```
Test Files  30 passed (30)
     Tests  642 passed | 1 skipped (643)
```

The 1 skip is the deliberate `it.skip('melt refuses a powder-ineligible shell')`, carrying
the comment "un-skip when the first ineligible shell exists" — `POWDER_INELIGIBLE` is
unreachable while `shared-fixtures/firework-shells.json`'s `powderIneligible` list is empty.

`npx tsc --noEmit` — clean, no output.

## Self-review

- **Test placement.** The new `describe('powder (spec §7): …')` sits inside the existing
  `describe('fireworks', …)`, immediately before the `shows/reserve` sub-describe, at
  matching indentation. Users are seeded with `User.create({ robloxId: 'NNN', … })` per
  the block's own NB comment about `resolveUser` upserting on `robloxUserId`.
- **Ordering in melt.** Validation runs `BAD_SHELL` → `BAD_COUNT` → `POWDER_INELIGIBLE`
  before `resolveUser`, so a malformed request never upserts a user. The test asserting
  `{ shellId: 'moonshot' }` → `BAD_SHELL` depends on that order and passes.
- **`held` on the 409s.** Both conflict bodies report the balance from the pre-update
  `resolveUser` read, not from a second query. Under a genuine race that number can be
  stale by the time the client sees it, but it is advisory only — the authority is the
  filter that already refused the write. The concurrency test asserts the outcome that
  matters (exactly one 200, one 409, and `powder` credited once at 5 for `wa`).
- **`credited` is computed before the update** and echoed, not derived from the new
  balance — correct, since `powder` may have been moved by a concurrent grant.
- **The seal holds.** Grepped the route file: `powder` appears only as a read
  (`user.powder ?? 0`, `updated.powder`) and as a positive `$inc`. No path converts
  powder back to points.

## Concerns

- **`held` staleness on 409** (above) — cosmetic, worth knowing if a client ever renders
  it as authoritative.
- **`POWDER_INELIGIBLE` is dead code today**, guarded only by a skipped test. It is one
  line and the skip names its un-skip condition, so the cost is a lint-visible branch
  rather than silent rot. Whoever adds the first rare shell must un-skip that test and
  point it at the real ineligible id (it currently uses `peony` as a placeholder subject).
- **`SHELL_PRICES` is `Record<string, number>`**, so `SHELL_PRICES[shellId]` type-checks
  even for an unlisted id. The `SHELL_IDS.includes` guard above it is what makes
  `credited` well-defined; if a shell is ever added to `SHELL_IDS` without a price, this
  route would credit `NaN`. `fireworks.test.ts` already asserts the id list against the
  fixture, but not that every id has a price — a small gap, out of scope here.
- **No route exists yet that SPENDS powder.** Until sub-project A's shop route lands,
  powder accumulates with no sink; that is the plan's sequencing, not a defect of this task.
