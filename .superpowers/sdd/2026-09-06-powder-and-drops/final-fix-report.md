# Final fix wave — powder branch review

Branch `thread/powder`, review base `d484d8e`. One dispatch, eight items, two commits.

## Code (commit 1: `8eaf220`)

1. `server/src/routes/apiV1.ts:472` (shows/reserve header comment) — replaced "Inventory fuel
   only here; powder is sub-project A." with "Inventory fuel debits the shells themselves;
   powder fuel (sub-project A) debits the summed list price from `powder` — both in one
   conditional update."
2. `server/src/routes/apiV1.test.ts:1061-1063` (`it.skip('melt refuses a powder-ineligible
   shell'`) — extended the skip comment: "When un-skipping, repoint `shellId` at the first entry
   of `powderIneligible` — `peony` is an eligible placeholder."
3. `server/src/models/User.ts:68` (`powder` field comment) — "Every move is a conditional
   $inc" changed to "Every move is a conditional $inc, or a plain $inc guarded by the receipt
   row on the grant path."

Test output:
```
Test Files  30 passed (30)
     Tests  647 passed | 1 skipped (648)
```
`npx tsc --noEmit` — clean, no output.

## Docs (commit 2: `e96829d`)

4. `docs/wiki/world/fireworks.md` § "Powder and drops" — appended after the drops paragraph
   (after "...closes that in one line."): "⚠ Until the Hanabiya melt verb ships, a tier drop
   REPLACES that round's firecracker, so a player without the matching mortar receives a shell
   they can neither fire nor melt (peony needs `mortar:S`, wa `mortar:M`); the melt verb closes
   the window — weigh it before the dev redeploy."
5. Same section, flows paragraph — "Every move is a conditional `$inc`." changed to "Every move
   is a conditional `$inc`, or on the grant path a plain `$inc` guarded by the receipt row's
   unique index."
6. `docs/wiki/program/backlog.md`, "Powder grant must be exactly-once..." item — appended: "The
   rework's retry on a matched-nothing update must answer GRANTED (the credit already landed) —
   the opposite of today's `duplicate: true` meaning on a lost credit; do not copy today's
   semantics."
7. `docs/wiki/log.md`, `## [2026-09-06] ship | Powder + drops …` entry — changed "At plan time
   the branch tip ran green" to "At close the branch tip ran green" (phrase only, nothing else
   appended).

Lint line:
```
36 error(s), 8 warning(s) across 58 pages
```
Unchanged from the pre-fix baseline (36/8) — no new lint issues introduced.

## Push

```
d484d8e..e96829d  thread/powder -> thread/powder
```
Pushed successfully to origin; `thread/powder` tracks origin as before.

## Commits

- `8eaf220` — fix(powder): reserve header no longer says inventory-only; skip-test and powder
  comments say what they mean
- `e96829d` — docs(wiki): the drop-before-melt window; grant wording; the exactly-once retry
  answers Granted
