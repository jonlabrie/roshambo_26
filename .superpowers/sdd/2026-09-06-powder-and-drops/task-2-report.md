# Task 2 report — The drop table (`drops.ts` + fixture)

**Status:** complete. Commit `689d547` — *feat(powder): the drop table -- streak tiers as a fixture contract; a golden ticket at the ticket streak*.

## What was implemented

- `shared-fixtures/firework-drops.json` (new) — the drop contract: `default: "firecracker"`,
  `tiers: { "3": "peony", "5": "wa" }`, `ticketAtStreak: 6`, plus 11 `cases` rows covering the
  tiers, the between-tier fallback, the ticket streak and the one above it, and the three
  defensive inputs (0, -3, 2.5). Values verbatim from the brief.
- `server/src/drops.ts` (new) — `DROP_TABLE` literals and `dropForStreak(streak): Drop`.
  Non-integer or `< 1` streak returns `{ default, ticket: false }` rather than throwing; otherwise
  `tiers[streak] ?? default`, ticket iff `streak === ticketAtStreak`. Runtime code does not import
  the fixture (house pattern) — the test holds the two equal.
- `server/src/drops.test.ts` (new) — brief's test verbatim in substance: `DROP_TABLE` vs fixture,
  every drop shell present in `firework-shells.json` and absent from its `powderIneligible`, and
  one generated case per fixture row.

## RED / GREEN evidence

RED (before `drops.ts` existed), `cd server && npx vitest run src/drops.test.ts`:

```
 FAIL  src/drops.test.ts [ src/drops.test.ts ]
Error: Cannot find module './drops' imported from .../server/src/drops.test.ts
 Test Files  1 failed (1)
```

GREEN, same command after implementing: `Test Files 1 passed (1) / Tests 13 passed (13)`.

Full backend suite, `cd server && npm test`: **30 files, 631 tests, all passing**.
`npx tsc --noEmit`: clean.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/shared-fixtures/firework-drops.json` (new)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/drops.ts` (new)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/drops.test.ts` (new)

Exactly those three staged; the untracked `.superpowers/sdd/2026-09-06-powder-and-drops/` planning
directory was left unstaged, as it was before this task.

## Self-review

- **Fixture/literal equality is real, not cosmetic.** `toEqual` compares the JSON's string keys
  (`"3"`) against the TS object's numeric-literal keys (`3`); both are string keys at runtime, so
  the assertion genuinely catches a tier edited on one side only. Confirmed by the passing test,
  not by reasoning alone.
- **The cross-fixture check is the useful one.** `peony` and `wa` are both gear shells
  (`mortar:S` / `mortar:M` in `firework-shells.json`), so a tier drop is often unfireable on
  arrival — that is intended (Task 4 melts it), and the test's `powderIneligible` assertion is what
  guarantees such a drop is at least meltable. It passes today only because `powderIneligible` is
  empty; it will start earning its keep the moment a rare shell is added.
- **Defensive inputs.** `Number.isInteger` rejects `2.5`, `NaN`, `Infinity` and `-0`… (`-0` is an
  integer but `< 1`, so it also lands on the default). No input path throws.
- **Types.** `tiers` is annotated `Record<number, string>` so `tiers[streak]` type-checks; without
  `noUncheckedIndexedAccess` the index yields `string`, and the `?? default` is therefore belt-and-
  braces at the type level but load-bearing at runtime. Left as the brief wrote it.
- **Scope.** Nothing outside the three files was touched; `roblox/src/server/main.server.luau`
  untouched. `drops.ts` has no imports and no side effects, so Task 3 can call it from settlement
  without pulling anything in.

## Concerns

1. **`ticketAtStreak` is an equality, not a crossing.** `streak === 6` means a player whose streak
   somehow skips 6 (it cannot today — streaks increment by one) gets no ticket, and re-reaching 6
   after a loss grants another. The fixture's `why` on the streak-7 row calls this "one ticket per
   crossing", which is accurate only because streaks are monotone +1 within a run. If a future rule
   ever jumps a streak, Task 3 (not this pure table) is where the crossing would need tracking.
2. **`server/tsconfig.json` excludes `src/**/*.test.ts`**, so `npx tsc --noEmit` does not type-check
   the new test — the fixture-import types are only exercised by Vitest's esbuild transform, which
   erases types. This matches the existing `fireworks.test.ts` and is not a regression, but the
   "tsc clean" claim above should be read as covering `drops.ts` only.
3. **Tiers are starting values.** Per the brief and the fixture comment, `3 → peony`, `5 → wa` and
   the ticket at 6 are the spec's opening numbers awaiting the owner's feel-test, not rulings.
