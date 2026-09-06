# SDD ledger — plan: docs/superpowers/plans/2026-09-06-powder-and-drops.md

Spec: docs/superpowers/specs/2026-09-05-fireworks-show-system-design.md §7, §10 row A, §12; decision 10 on the backlog.
Worktree: .worktrees/powder, branch thread/powder. Baselines recorded at the end of this header by the setup run.
Models: implementers opus (owner's standing choice); reviewers opus/sonnet by diff size; final review fable.
Constraint carried from the concurrent split: this branch never edits roblox/src/server/main.server.luau.

## Pre-flight scan

| tasks | produces → consumes | finding |
|---|---|---|
| 1→4,6 | `isPowderEligible`, `SHELL_PRICES` (existing) | melt (T4) and powder fuel (T6) gate on it; the branch is unreachable while the list is empty — T4 keeps an `it.skip` documenting it |
| 1→2 | fixture `powderIneligible` | T2's fixture test asserts every drop shell is NOT in it |
| 2→3 | `dropForStreak(streak) → { shellId, ticket }` | T3 calls it on the post-win streak already computed at Settlement.ts ~L108 and folds `$inc`/`$push` into the ONE existing atomic update |
| 3→4,5,6 | `User.powder`, `User.goldenTickets` | routes `$inc` powder conditionally; nothing reads goldenTickets yet (C) |
| 4→6 | the `$gte`-filter idiom and error shapes | reserve's powder branch mirrors topup/melt |
| 5 | `PowderGrant` unique index | race test needs `syncIndexes()` in beforeAll (noted in the task) |
| 4,6→7 | route paths | NetworkClient calls name the same paths; no caller yet |
| 6 vs B's reserve | `fuel` gate | the existing FUEL_UNSUPPORTED test for 'powder' is replaced by an unknown-fuel case — noted in T6 |

Per-task: T1 changes `ShellState`'s shape — any `toEqual` on a ShellState literal in existing tests must add `powderEligible` (task says so). T2/T3 JSON tier keys are strings; `toEqual` on `{3: 'peony'}` vs `{"3": "peony"}` is equal in JS (both string keys). T5's duplicate-key handling relies on Mongo error code 11000. T8 docs only.
Rubric-sensitive: `reservationId` remains Math.random base36 in T6 (matches B; D replaces it) — a reviewer may flag; already a deferred minor on B's ledger.

Scan verdict: no conflicts requiring a ruling. Proceed to Task 1.

## Tasks
baseline: server 29 passed, luau 1892 passed, 0 failed, 1892 total
Task 1: implementer a8c6a25c3e78c139f (opus); DONE_WITH_CONCERNS at 59d9182 (staged a fourth file, apiV1.test.ts, whose ShellState literals needed the new field — required by the brief's Step 5; accepted). server 618/618, tsc clean, Luau 1892 (fixture touched).
Task 1: reviewer a6b7669747551d1f4 (sonnet): Approved.
Task 1: minor (deferred): the ineligible-list tests are vacuous while the list is empty (by design; the first rare shell must exercise the branch)
Task 1: complete (commits 8f778e1..59d9182, review clean; trailer verified)
Task 2: implementer aa45567fe723f0f79 (opus); DONE at 689d547; server 631/631; tsc clean.
Task 2: reviewer ac0f6cd31fa241074 (sonnet): Approved, no findings.
Task 2: complete (commits 59d9182..689d547, review clean; trailer verified)
Task 3: implementer a1e4eefd4da8e9f75 (opus); DONE at b5f6282; server 635/635; tsc clean; one counters write confirmed. Concern raised: ticket `$push` with a fresh UUID is not idempotent under a double-settle (milestones use $addToSet for exactly that reason).
Task 3: reviewer a1ae0ef44873d32fa (opus): Approved.
Task 3: minor (deferred → sub-project C): ticket mint is `$push` + random UUID; a re-settle would mint twice (unreachable today: settleRound has one caller on roundClosed, once per transition; note settledRounds in socketAdapter is NOT a settle guard and Round.create's duplicate error is swallowed). One-line closure when C wants it: deterministic id `${roundId}:${userId}` + `$addToSet` (earnedAt is already data.timestamp so the subdocument dedupes). Also: `winFor`'s second parameter is dead; no settlement case for the wa tier; nothing asserts drop tier ids ⊆ SHELL_IDS at the fixture level (Task 2's test checks the shells fixture, which is the same list — acceptable).
Task 3: complete (commits 689d547..b5f6282, review clean; trailer verified)
Task 4: implementer a0f4072cdfb02e299 (opus); DONE at ba161a3; server 642 passed + 1 skipped (the POWDER_INELIGIBLE branch); tsc clean. Concern: a SHELL_IDS entry without a price would credit NaN (the fixture test "every fixture id has a price" guards it).
Task 4: reviewer a6d4a0401d3636a81 (opus): Approved; the seal verified across server/src (powder is only ever incremented; no decrement path exists yet; nothing feeds totalPoints from it).
Task 4: minor (deferred): the it.skip melts `peony` (eligible) — un-skipping needs the subject repointed at the first ineligible shell (comment should say so); no topup concurrency test (mirror the melt one); the NaN concern is already closed by the fixture price test
Task 4: complete (commits b5f6282..ba161a3, review clean; trailer verified)
Task 5: implementer ae1a24af9de803552 (opus); DONE at d0b2e3d; server 645 passed + 1 skipped; tsc clean; race test 5x green. Concern raised: at-most-once — a crash between the grant-row insert and the $inc loses a paid credit and the retry is told `duplicate` (a `credited` flag on the row would make it exactly-once).
Task 5: reviewer a7ec497e40a8dd62c (opus): Approved; race test deterministic (clearTestDb uses deleteMany, index survives).
Task 5: Ruling: the crash window (row inserted, $inc not yet applied → retry told duplicate → paid credit lost) is REAL and is a gating follow-up BEFORE any Robux caller (ProcessReceipt) lands — not this task (no paying caller exists). ⚠ The `credited: boolean` flag I suggested is NOT the fix (crash between $inc and the flip double-credits on retry; crash in the recovery loses it unrecoverably). The exactly-once shape: fold the receipt into the balance document — `User.updateOne({ _id, appliedReceipts: { $ne: receiptId } }, { $inc: { powder }, $push: { appliedReceipts: receiptId } })` — one document, one atomic op; PowderGrant becomes the audit row. Needs an array cap/rotation story. Transactions would also work on Atlas but are untestable on the single-node memory server. Task 8 records this on the backlog with the why-not-the-flag note. Cost if wrong: none today; a lost paid credit if forgotten.
Task 5: minor (deferred): duplicate path returns a pre-$inc powder (stale under a race); null user after insert answers credited without crediting (same family as the window); no upper bound on amount; receiptId uniqueness is global not per-user (document in the model); index build is async at process start (a grant in that window could double-insert).
Task 5: complete (commits ba161a3..d0b2e3d, review clean; trailer verified)
Task 6: implementer a153e91e79418bfa6 (opus); DONE at 9c98677; server 647 passed + 1 skipped; tsc clean. Note: a pre-existing timing test ("names the durations openMs/lockMs/revealMs") flaked once on a full run, green on two reruns — not this branch's code.
Task 6: reviewer aa7072af02e6187a7 (sonnet): Approved.
Task 6: minor (deferred → fold into the final fix wave if one happens): the reserve route's header comment still says "Inventory fuel only here; powder is sub-project A" (apiV1.ts ~L472) — now false
Task 6: complete (commits d0b2e3d..9c98677, review clean; trailer verified)
Task 7: implementer a2966edd92643b446 (opus); DONE at 8f558e0; Luau 1894/1894; stylua/selene clean.
Task 7: reviewer a39995bc0aa859399 (sonnet): Approved, no findings.
Task 7: complete (commits 9c98677..8f558e0, review clean; trailer verified)
Task 8: implementer a32758c8cd5f6c8a5 (opus); DONE at d484d8e; lint 37/9 → 36/8; pushed thread/powder; roblox-ci success https://github.com/jonlabrie/roshambo_26/actions/runs/34054718987 ; server-ci success https://github.com/jonlabrie/roshambo_26/actions/runs/34054718998 ; no merge. Task review and the final whole-branch review dispatched in parallel.
Task 8: reviewer adda5ef4daa1a04c7 (sonnet): Approved, no findings; lint 36/8 confirmed.
Task 8: complete (commits 8f558e0..d484d8e, review clean; trailer verified). All eight tasks complete; final whole-branch review in flight.
Final review: agent af1f9e85426d2ba81 (fable). Verdict: Ready to merge (Yes). Seal verified across the codebase (only writers: +topup/+melt/+grant, −powder-fuel reserve; nothing reaches totalPoints/lifetimeBanked/purchase; never ranked or summed). Important #1 (docs): a tier drop (peony at 3, wa at 5) REPLACES the firecracker that round, and a mortar-less player cannot fire OR melt it until the melt verb ships — record the window on the wiki. Minors: stale reserve header comment (fix before merge); grant duplicate path reports a pre-insert powder; null user after insert answers credited; no amount caps; skip-test comment; "every move is a conditional $inc" overstates for grant (index-guarded); log "at plan time" → "at close"; ticket $push (deferred to C). Rulings check: Task 5 ruling correct, with one addition — the exactly-once rework's no-match retry must answer GRANTED (credit already landed), the opposite of today's duplicate semantics; add to the backlog entry. Plan self-review over-claimed "powder → shells" (only powder → firing exists; row A does not require more).
Final: fix wave dispatched (one implementer): reserve comment; wiki dead-item window sentence; "conditional or receipt-guarded" wording (wiki + User.ts comment); backlog "retry answers Granted" line; skip-test comment; log wording. Deferred: grant duplicate-path balance, null-user, caps (fold into the exactly-once rework); ticket $addToSet (C).
Final: fix wave implementer af8d859adb694c7b1 (sonnet) → 8eaf220 (code) + e96829d (docs); server 647+1 skipped, tsc clean, lint 36/8; pushed. Scoped re-review dispatched.
Final: re-reviewer a08cf54bb72ce7d6e (sonnet): all six items ADDRESSED; no breakage; lint 36/8. Whole-branch review clean. Branch thread/powder at e96829d ready for finishing-a-development-branch.
