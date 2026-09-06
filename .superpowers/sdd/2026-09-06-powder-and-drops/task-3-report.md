# Task 3 report — `powder` and `goldenTickets`; settlement grants by tier

**Status:** complete. Commit `b5f6282` — *feat(powder): powder and goldenTickets on the user; settlement grants by streak tier inside the one atomic write*.

## Implemented

The flat `fireworks.firecracker: 1` grant in settlement is now the drop table. Two fields were added to the user to receive it.

- `server/src/models/User.ts` — `IUser.powder: number` (schema `{ type: Number, default: 0 }`) and `IUser.goldenTickets: { id: string; earnedAt: Date }[]` (schema `{ type: [Schema.Types.Mixed], default: [] }`), both declared next to `fireworks` in the interface and next to it again in the schema, with the brief's comments verbatim.
- `server/src/engine/Settlement.ts` — imports `dropForStreak` from `'../drops'` and `randomUUID` from `'crypto'`. After `const streak = …` and before the write: `const drop = result === 'WIN' ? dropForStreak(streak) : null;`. In the update, `$inc` gained `...(drop ? { [\`fireworks.${drop.shellId}\`]: 1 } : {})` in place of the flat firecracker line, and `$push` for the ticket sits alongside `$inc`/`$set`/`$max` in the same call.
- `server/src/engine/Settlement.test.ts` — `it('a WIN grants one firecracker', …)` replaced by the brief's `describe('the drop table (spec §7): …')` with its five cases. `'a LOSS grants nothing'` kept, as were the pre-existing `'a SAFE grants nothing either — the grant rides WIN alone'` and every other case in the file.

`powder` is written by nothing in this task — it is declared here so the fields land together, and Task 4's melt is its first writer. The first-win test asserts it reads `0` by default.

## RED

`npx vitest run src/engine/Settlement.test.ts` before the implementation: **5 failed | 25 passed**. All five new cases failed, and for the reasons the brief predicted:

- *third win: a peony* — `expected undefined to be 1` for `fireworks.get('peony')`; the flat grant had written a firecracker.
- *sixth win* / *seventh win* — `AssertionError: Target cannot be null or undefined` on `expect(after!.goldenTickets).toHaveLength(1)`; the field did not exist on the schema.
- *first win* / *a SAFE grants nothing* — `expected undefined to deeply equal []` on `goldenTickets`, same cause.

## GREEN

`npm test` (whole server suite): **30 files passed, 635 tests passed**, 8.5s. `npx tsc --noEmit`: clean, no output.

## One-write confirmation

`grep -n "findByIdAndUpdate\|updateOne\|\.save()\|findOneAndUpdate" src/engine/Settlement.ts` returns exactly two hits:

- **L152** — the counter write, `User.findByIdAndUpdate(user._id, { $set, $inc, $max, …$push })`. This is the single atomic update, and both the shell `$inc` and the ticket `$push` are inside it. No second round-trip was added.
- **L190** — the pre-existing milestone `$addToSet`, unchanged by this task and separate by design (it runs against the post-write state so a pot reached this round earns its milestone now).

The `$push` is spread conditionally at the top level of the update document, so on a non-ticket win the key is absent rather than present-and-empty — Mongo rejects an empty `$push`, so this is load-bearing, not cosmetic.

## Self-review

- **The grant is still WIN-only.** `drop` is `null` for SAFE and LOSS, and both `$inc` and `$push` spread to `{}` in that case. The kept LOSS test and the pre-existing SAFE test both still pass, and the new SAFE case asserts `fireworks.size === 0` — a stronger claim than the old per-key one.
- **The shell key is interpolated, not concatenated by hand.** `drop.shellId` comes from `DROP_TABLE`, whose values are fixture-asserted literals (`firecracker`, `peony`, `wa`), so no user-controlled string reaches a dotted Mongo path.
- **`earnedAt` uses `data.timestamp`, not `new Date()`** — per the brief. The ticket is stamped with the round's time, so re-settling would stamp identically rather than drifting.
- **Ticket minting is not idempotent.** `$push` with a fresh `randomUUID` means settling the same round twice would mint two tickets, unlike the milestone `$addToSet` immediately below it. The brief specifies `$push` and describes the field as append-only, and settlement is called once per round by the engine, so this is correct as written — but it is the one place in this update where a double-settle is not harmless. Flagging for sub-project C, which books redemptions.
- **`[Schema.Types.Mixed]`** means the ticket shape is unvalidated by Mongoose; the interface is the only contract. That is the brief's choice and matches the neighbouring `deckDecorations`.

## Concerns

Only the double-settle note above, and one scope observation: nothing yet reads `powder`, so its default is exercised by exactly one assertion until Task 4. Neither blocks this task.
