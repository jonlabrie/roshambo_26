# Task 2 Report: Profile fields for the ledger, the win gate and onboarding

## Summary

Added twelve defaulted fields to `IUser` and `UserSchema` in `server/src/models/User.ts`:
`unresolvedWin`, `escalationPrompts`, `seenBeats`, `roundsPlayed`, `wins`, `safes`, `losses`,
`lifetimeBanked`, `bestPot`, `throwsR`, `throwsP`, `throwsS`. All values match the brief
verbatim, including the `escalationPrompts: true` default (the one field that isn't zero/false/empty)
and the comment explaining why `unresolvedWin` can't be derived from `pointsAtStake`.

Extended the existing `server/src/models/models.test.ts` in place with a new
`describe('User defaults — play HUD fields', ...)` block, matching the file's existing
import/style conventions. Per the brief, these two cases use `new User({...})` (schema
defaults applied without touching the DB) so they need no `connectTestDb`/`clearTestDb`
hooks — they sit as a sibling describe block alongside the existing `describe('schema
additions', ...)` block that does connect.

## Files changed

- `server/src/models/User.ts` — interface fields after `pointsAtStake: number;`, schema fields
  after `pointsAtStake: { type: Number, default: 0 },`
- `server/src/models/models.test.ts` — new describe block appended at end of file

## TDD evidence

### RED

Command: `npm test -- models` (from `server/`), run after adding the test block but before
touching `User.ts`.

```
 FAIL  src/models/models.test.ts > User defaults — play HUD fields > defaults every new play-HUD field so existing docs need no migration
AssertionError: expected undefined to be false // Object.is equality

- Expected:
false

+ Received:
undefined

 ❯ src/models/models.test.ts:57:33
     55|     it('defaults every new play-HUD field so existing docs need no mig…
     56|         const u = new User({ deviceId: 'd1' });
     57|         expect(u.unresolvedWin).toBe(false);
       |                                 ^

 FAIL  src/models/models.test.ts > User defaults — play HUD fields > unresolvedWin is independent of pointsAtStake
AssertionError: expected undefined to be false // Object.is equality
 ❯ src/models/models.test.ts:71:33

 Test Files  1 failed (1)
      Tests  2 failed | 5 passed (7)
```

This is the expected failure: `User.ts` had no `unresolvedWin` field yet, so Mongoose leaves
it `undefined` on a freshly-constructed (unsaved) document — exactly the brief's predicted
"FAIL — `u.unresolvedWin` is `undefined`". The 5 pre-existing tests in the file still passed,
confirming the new block was additive and isolated.

### GREEN

Command: `npm test -- models` (from `server/`), run after adding the interface + schema fields
to `User.ts`.

```
 RUN  v4.1.9 /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/server

 Test Files  1 passed (1)
      Tests  7 passed (7)
   Start at  16:20:14
   Duration  1.08s
```

Then the full suite, as the global constraints require before committing:

Command: `npm test` (from `server/`)

```
 Test Files  13 passed (13)
      Tests  193 passed (193)
   Start at  16:20:17
   Duration  4.42s
```

(Output included repeated Mongoose `findOneAndUpdate` deprecation warnings — pre-existing,
unrelated to this change, not introduced by it.)

## Commit

`3888e1b` — `feat(server): profile fields for the ledger, win gate and onboarding`

Files staged and committed: `server/src/models/User.ts`, `server/src/models/models.test.ts`.

## Self-review

- **Completeness**: all 12 fields from the brief present in both the interface and the schema,
  spelled exactly as specified, in the exact insertion points the brief named
  (`User.ts:14-30` interface region, `:44-62` schema region — after `pointsAtStake`).
- **Defaults**: verified every field has a schema-level `default` (required by the global
  constraint that existing production documents need no migration). `escalationPrompts` is the
  sole `true` default; everything else is `false`/`0`/`[]`, matching the brief's explicit
  callout.
- **Quality/YAGNI**: no fields, indexes, validators, or methods added beyond what the brief
  specified. Didn't touch `stakingStreak`/`currentStreak` (noted in the task context as
  unrelated). Didn't touch `shared-fixtures/game-rules.json` or `GameRules`.
- **Test honesty**: the two new tests construct documents with `new User(...)` and never call
  `.save()`, so they exercise Mongoose's schema-default application only — they do not touch
  the in-memory Mongo instance, consistent with the brief's stated intent and confirmed by the
  RED failure trace (no DB errors, just `undefined` field access). The second test's use of
  `unresolvedWin: false` as an explicit constructor argument is a slightly weak proof of "not
  derived from pointsAtStake" (it never sets `unresolvedWin: true` alongside a positive stake to
  show the two vary independently), but this is the exact test given in the brief verbatim, and
  the accompanying schema comment plus the field's own presence is what actually prevents future
  derivation from `pointsAtStake`. Flagging for visibility, not changing — the brief was explicit
  this is the code to write.
- **Style match**: new describe block follows the file's existing `describe`/`it` structure,
  arrow-function bodies, and comment style (see the existing `padPreferences`/`maxDeckSize`
  blocks it sits beside).
- **No unrelated changes**: `git show --stat` confirms only the two intended files changed,
  47 insertions, 0 deletions.

No concerns beyond the minor test-strength note above, which reflects the brief's own test
design rather than an implementation gap.
