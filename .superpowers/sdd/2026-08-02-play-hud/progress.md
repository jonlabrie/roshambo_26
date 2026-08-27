# SDD ledger — plan: docs/superpowers/plans/2026-08-02-play-hud.md

Branch: `m4b-zendojo-art-pass`
Spec: `docs/superpowers/specs/2026-08-02-play-hud-design.md`
Started: 2026-08-02

Pre-flight scan: clean after three underspecified spots were closed in the plan
(commit on 2026-08-02) — one `SetHudPreference` remote for both the escalation switch
and the beat-seen write; dimmed throw row raises transparency and stays visible;
onboarding never stacks two cards.

**Studio verification is the CONTROLLER's job, not an implementer's.** Several tasks
carry "verify in Studio" steps. Implementers do code + tests + gates + commit and stop;
the controller batches Studio passes and takes them to the owner. Standing rule: one
visual attempt, then stop and ask.

## Progress

Task 1: complete (commits 00cf909..4ffb9f7, review clean)
  - Glyphs.renderGroup added; LanternController off Unicode onto real assets.
  - Deviation, disclosed and accepted: roblox/tests/Glyphs.spec.luau ALREADY EXISTED with
    broader coverage than the plan assumed. Extended in place rather than overwritten.
    The plan's "create the test file" wording was wrong; later tasks should check first.
  - Reviewer's named-risk checks: selene shadowing on `local shared` (clean, no such lint);
    ImageColor3 not retargeted in setGroupSymbol (safe — both layers are always INK).
  - Studio verification deliberately deferred to the controller (batched, see header).

Task 2: complete (commits eb393c5..3888e1b, review clean)
  - 12 defaulted fields on User; 7/7 focused, 193/193 full suite.
Task 2: minor (deferred): models.test.ts 'unresolvedWin is independent of pointsAtStake'
  tests only one combination (false + stake 27), never the criss-cross (true + stake 0).
  Not vacuous — it would catch a naive `pointsAtStake > 0` derivation — and it is the
  brief's verbatim test, so a spec-level test-design note, not an implementation defect.
  Raised by the implementer itself and confirmed by the reviewer.

Task 3: complete (commits 3888e1b..ff907bb, review clean)
  - buildCounterUpdate wired into settleRound's existing single write.
  - Reviewer verified the three named risks: $set/$inc/$max keys are disjoint (no Mongo
    conflict), PlayerRound-before-wallet ordering intact, exactly one round + one throw
    counted per participant. 198/198 suite, tsc clean.

Task 4: complete (commits ff907bb..92ca50f, review clean)
  - resolveWin + POST /resolve-win; bankPot now also clears the gate and accrues
    lifetimeBanked on the SAME atomic write. 204/204 suite, tsc clean.
  - Reviewer traced all three money risks in code (not just tests): same-choice double-bank
    is prevented on both branches, every BANK exit path clears the gate (no stranded player),
    lifetimeBanked is one write with totalPoints.
Task 4: minor (deferred, MITIGATED FORWARD): cross-choice race in wallet.ts:97-114 — RISK
  guards on unresolvedWin, BANK guards on the observed pointsAtStake, so two CONFLICTING
  concurrent requests can both pass their own filter and silently turn "keep riding" into a
  bank. Inherited from the brief's specified algorithm, not implementer error; needs two
  different choices in flight, not a double-tap (that is guarded). Closed forward: Task 11
  now REQUIRES an `answering` latch that disables both buttons on the first tap. If Task 11
  ships that latch, the final review should confirm it and can close this.

Task 5: complete (commits 0cecbf1..bc5c225, review clean)
  - buildProfilePayload exported + PUT preferences-hud. 211/211 suite, tsc clean.
  - Field-loss risk cleared: all EIGHT pre-existing GET /players fields still returned
    (robloxUserId/displayName/identityTier explicit, the five wallet fields via the builder).
  - SERVER SLICE COMPLETE (T2-T5). Everything from here is Roblox/Luau.

Task 6: review found 1 Important — the three-miss backoff was not uniform. The arm expression
  ORed three LIVE conditions, so a player who threw, won nothing (pot 0) and missed one round
  fell out of the OR and went silent after ONE miss. Most common case, least grace. The
  reviewer also noted the tests restated the OR rather than walking the state across a miss.
  PLAN CONTRADICTED ITSELF (header said uniform, code said otherwise) -> escalated to owner.
  OWNER RULING: uniform. armed = consecutiveMisses < 3, nothing else. The arm reasons only
  ever described who STARTS armed. Session collapses to { consecutiveMisses }.
  Plan Task 6 rewritten + one-miss regression block added. Fix round 1 dispatched.
Task 6: fix round 1/5 (1 addressed, 0 open; commits b040798..c6574b8)
Task 6: complete (commits bc5c225..c6574b8, review clean after 1 fix round)
  - Uniform backoff shipped; Session is now { consecutiveMisses } only. 843 tests pass.
  - Re-reviewer hand-traced the regression test against the OLD module and confirmed it
    would have failed there — it exercises the scenario, not restates the fix.

Task 7: review found 1 Important + 2 Minor. Important: winRatePct (round-to-nearest) and
  bar.win (largest-remainder) are the SAME quantity computed two ways, and disagree by a point
  on any exact three-way split — headline 33% vs bar segment 34%. Not a plan conflict (nothing
  required two calculations), so fixed directly rather than escalated.
Task 7: fix round 1/5 (3 addressed, 0 open; commits ac604c1..765f16c)
Task 7: complete (commits c6574b8..765f16c, review clean after 1 fix round)
  - winRatePct = bar[1], one number defined once; View exported; shares() comment corrected.
  - Re-reviewer recomputed the untouched {386,131,92,163} case under BOTH formulas: 34 either
    way, so that pre-existing test is a genuine non-regression, not a weakened expectation.
  - Apportionment internals byte-identical to what the first review cleared. 852 tests pass.

Task 8: complete (commits 765f16c..e07373c, review clean)
  - OnboardingBeats: 4 beats, 7 tests, 859 suite. Movement-guard test present.
  - Reviewer's one warning, RESOLVED BY CONTROLLER: the anchor ids (drum / throwArea /
    choiceOverlay / plate) resolve to nothing yet — no module in src/ defines them. That is
    by design; Task 13 owns anchoring the cards. CARRIED FORWARD: Task 13's dispatch must
    name all four and require the renderer to resolve each one.

Task 9: review (opus) found 1 Important + 2 Minor. Important: the ResolveWin handler was
  `if res.ok then ... end` with no else — and a successful postResolveWin is the ONLY
  in-session path that clears the gate (onReconciled passes through by design;
  applyLocalResult cannot run for a gated player because they cannot throw). A dropped
  request left the player permanently unable to play, silently.
Task 9: fix round 1/5 (1 addressed, 0 open; commits 7aa299e..bc0abcc)
Task 9: complete (commits e07373c..bc0abcc, review clean after 1 fix round)
  - Reviewer verified all four applyServer pass-through choices against the REAL apiV1
    response shapes. onReconciled passing through (not defaulting false) is what stops every
    gated player being silently unbound once per round. Both remotes declared in
    default.project.json, so no WaitForChild hang. 867 tests.
Task 9: minor (deferred): the gate FAILS OPEN on a PlayerProfiles cache miss
  (main.server.luau `if prof and prof.unresolvedWin`). Correct direction — a failed join-sync
  must not brick a session — and Settlement rewrites the flag next settled round, so it
  self-heals within one round. Verified acceptable, not a defect.
Task 9: minor (deferred): inverse divergence — local reveal SAFE/LOSS against a backend WIN
  skips the prompt for one round, then self-heals. Inherent to local-reveal-then-reconcile.
Task 9: note: no test covers the new warn branch. Consistent with the file — 12 other
  warn-on-failure lines in main.server.luau have none; it is the runtime wiring entry point,
  not the unit-tested layer. Accepted by the re-reviewer.

Task 10: implemented (commits bc0abcc..7bd21a5). Review (opus): spec OK, quality Approved,
  but 2 Important + 5 Minor. Reviewer verified the four named risks CLEAN:
  - spoiler gate moved intact (skip predicate character-identical; ordering preserved; the
    3s safety and its identity guard survive). One LEAK CLOSED: the old tickerSay named the
    world throw OUTSIDE the gate, while the drum was still turning.
  - Active discipline: exactly 4 interactive objects (plate + 3 throws). `Active` appears
    once, as `escalation.Active = false`. Glyphs.render adds no buttons (checked out-of-diff).
  - deleted widgets have zero remaining references anywhere in src/.
  - roundEnded fires exactly once per ACTIVE->non-ACTIVE edge; couldThrow is an exact mirror
    of the server's only two refusals (fates:isBound, prof.unresolvedWin).
  BOTH Importants are PLAN GAPS, not implementer error -> escalated to owner:
  (a) no bank-at-will path any more; bank exists only inside the post-win choice.
  (b) ACCEPT YOUR FATE lost its affordance; fate-bound is now visually identical to
      win-bound / already-picked / past-lockout, with no signal at all.
Task 10: minor (deferred): toast queue is FIFO with TOAST_SECONDS 4 x TOAST_MAX 6 = up to
  24s backlog against a ~25s round, so a gated reveal headline can surface a round late.
Task 10: minor (deferred): with lockoutAt nil the timer hairline pins FULL and MOTIONLESS
  for the whole round while throws stay enabled past the real lockout. Hide it instead.
Task 10: minor (deferred): a whiffed pick stays illuminated, contradicting its own toast.
Task 10: minor (deferred): oldest tape tile ages to AGED_IVORY while its glyph stays INK —
  too close in value; the glyph tint must age with the tile. Task 15 sweep.
Task 10: note: BoardController STILL holds Unicode glyphs and is not a no-op as reported —
  setRow runs a full FlapScheduler plan against an empty faces table on every TickerMessage.
  Harmless, but the record was wrong. Jumbotron is absent from default.project.json.
Task 10: OWNER RULING on both Importants — the blocking RISK/BANK overlay is WITHDRAWN.
  Reason: "RISK IT" is wager language on a mechanic that is deliberately not a wager, and
  Roblox proscribes simulated gambling in a kid-first experience. Replaced by a persistent
  pot indicator + BANK THESE; throwing again IS riding. This restores bank-at-will (Important
  #1) and gives ACCEPT YOUR FATE a slot (Important #2) — a LOSS forfeits the pot, so the pot
  indicator and the fate prompt can never coexist and share one slot.
  Spec + plan rewritten. Task 11 now implements the new mechanic AND removes the gate that
  Tasks 3/4/9 shipped green. Task 11 also absorbs 2 of Task 10's minors (frozen timer
  hairline, whiffed pick stays lit) and the escalationPrompts/ProfileUpdate gap.
Task 10: complete (commits bc0abcc..7bd21a5, review clean; 2 Important resolved forward by
  owner ruling into Task 11, 4 minors deferred)

Task 11: complete (commits 70504a2..8bc5e32, review clean, 3 minors)
  - Pot indicator + BANK THESE shipped; win gate removed end to end across Luau + TypeScript.
  - Reviewer verified all six named risks: no over-deletion (every KEEP-list item confirmed
    in unchanged code), grep for ResolveWin/resolveWin/choiceUp returns ONE hit and it is a
    comment, slot exclusivity is STRUCTURAL (bankButton is parented to potGroup, so it gets
    no input at all when the fate tenant is up), pulse tween cancels on every transition out
    and restores transparency, HudModel deletions were the right ones with every fate test
    kept, and both Step 7b carry-overs landed.
  - Implementer rehomed 3 deleted resolveWin tests into describe('bankPot') rather than lose
    the only coverage of clearing unresolvedWin / accruing lifetimeBanked / idempotence.
    Reviewer confirmed they still bite. Good catch by the implementer.
  - Implementer also found a REAL latent bug beyond the brief: BankRequest cached a stale
    unresolvedWin=true after banking, diverging from what bankPot writes. Judged in scope —
    postResolveWin had been the other writer of that cache field.
Task 11: minor (deferred): View.slot typed `string` not the literal union, so a typo in
  HudController's kind comparison is caught by nothing (type checking is not in the gate).
Task 11: minor (deferred): SetHudPreference writes its cache before a fire-and-forget PUT
  whose result is discarded — a failed write leaves the session asserting a preference the DB
  does not have, silently reverting on next join. Consistent with the handler's existing
  shape, but unacknowledged.
Task 11: minor (deferred): render's `aux.timerKnown ~= false` fails OPEN on a missing field.
  Unreachable today (one publisher, always sets it).

Task 12: implemented (commit a489c61, DONE_WITH_CONCERNS). Review (opus): spec OK, quality
  NEEDS WORK — 3 Important:
  (a) respawn race: CharacterAdded checks isOpen BEFORE a 10s WaitForChild yield and never
      after, so die-then-close leaves the player frozen with no panel on screen. The exact
      failure the safety requirement names.
  (b) a transient join-sync failure leaves ledgerCounters nil for the whole session, and the
      client nil-gate then blanks the ENTIRE panel — hero band, best streak and the
      preference switch too, none of which are counters. The minimal HUD self-heals via
      reconciliation; the ledger never does, and nothing on screen says why.
  (c) the counters gap was REAL (verified: no path carried them before this diff) and the
      plumbing was the right call, but the optimistic advance has no reconciliation and can
      only drift UPWARD — local reveals count rounds the backend never settled, so a lifetime
      total visibly goes DOWN on rejoin. Reviewer independently proposed re-seeding at panel
      open, which also deletes bumpCounters entirely. Plan updated with Step 4b.
Task 12: minor (deferred): the bank toast uses onboarding beat 4's copy verbatim, so the
  first bank will say it twice once Task 13 lands. Fix in Task 13.
Task 12: minor (deferred): PlayerModule resolution runs at top level ~700 lines before
  OpenLedger is connected; BindableEvent fires are not queued, so a plate tap in that window
  is silently dropped. Resolve controls lazily on first open().
Task 12: minor (deferred): cards use fixed pixel offsets with no ClipsDescendants, so content
  spills over the footer on a short landscape phone. Overflow property, not a breakpoint —
  distinct from the NARROW_PX placeholder Task 15 settles.
Task 12: fix round 1/5 (3 addressed, 0 open; commits a489c61..6676545)
Task 12: complete (commits 8bc5e32..6676545, review clean after 1 fix round)
  - Respawn race closed (isOpen re-tested after the yield; savedWalk moved below it).
  - Counters seeded unconditionally; client nil-gate deleted, so the hero band and the
    preference switch no longer ride on a counters fetch.
  - bumpCounters / THROW_COUNTER / bank accrual DELETED (grep clean). New RequestLedger
    remote: OpenLedger -> server -> 3s per-uid debounced getPlayer -> re-seed -> fireProfile.
    Debounce timestamp is written BEFORE the spawn, so a fast tapper gets one fetch per 3s.
  - RequestSync correctly rejected: it makes no network call and EconomySync fires it up to
    20x per join on a 1s retry loop.
  - RequestLedger IS declared in default.project.json and both WaitForChild names match.
    *** STUDIO NEEDS A ROJO RE-SYNC BEFORE TESTING — both waits are untimed. ***
Task 12: minor (deferred): the ledger fetch also writes hudPrefs from the response, so a
  preference toggled inside the request's latency window visibly flips back, and the block
  comment above it claims only counters are taken. One-line fix: drop that write.
Task 12: minor (deferred): the RequestLedger debounce is per-player only. 50 players spamming
  the plate reaches ~1000 GET/min against HttpService's ~500/min per-server budget, which
  would throttle the ROUND LOOP's own calls. Needs mass collusion, not one exploiter.
Task 12: minor (deferred): the fetch re-populates ledgerCounters/hudPrefs after a yield, so a
  player who leaves mid-request leaks one small table. Pre-existing shape at the join fetch.
Task 12: accepted trade (not a defect): banking from inside the open panel leaves BANKED
  stale until reopen — the direct consequence of the no-local-accumulation ruling.

Task 13: 2 Important + 1 elevated Minor. Root cause of two of them: events were latched as
  CONSUMED at fire time, but whether a card renders is decided later by the never-stack guard.
  So a first bank could produce neither toast nor card, and "Tap a throw." usually never fired
  on a first session (the join card ate it, and its flag was already latched).
  Fix: new EventBus.OnboardShown(event, outcome) ack — callers latch on SHOWN, not FIRED, and
  retry on the event's next natural occurrence. NOT queueing: the controller stays stateless
  between fires and the never-stack rule is intact.
Task 13: fix round 1/5 (3 addressed, 0 open; commits ed2de99..e5e8e75)
Task 13: fix round 2/5 (3 addressed, 0 open; commits e5e8e75..76eba76) — round 1 clamped only
  the TRACKED drum path; DRUM_FALLBACK stayed un-clamped and could cover BANK THESE on a phone
  at DisplayOrder 10. Same absolute rule, path the finding had not named. Also failed the bank
  toast open (a dead OnboardingController could otherwise silence banking permanently).
Task 13: complete (commits 6676545..76eba76, review clean after 2 fix rounds)
  - Implementer independently found and fixed a real defect in its own self-review (throwArea
    card could cover BANK THESE), renamed the stale choiceOverlay anchor rather than silently
    diverging, and found ANOTHER plumbing gap: seenBeats never reached the client.
  - Re-reviewer verified safeYBounds' extraction is byte-identical to the approved round-1
    math, and that math.max(minY, candidate) makes clamp inversion impossible by construction
    (Luau's math.clamp ERRORS when min > max, and this runs on Heartbeat).
Task 13: minor (deferred): pendingBankToast is a single slot, so with a DEAD controller two
  banks within 1s drop the earlier toast. Strictly narrower than the bug it replaced.

Task 14: complete (commits 76eba76..5cbcf72, review clean)
  - HUD contrast tracks nightFactor. Reviewer verified all three pattern rules hold: dual
    subscription plus a synchronous prime read, capture-once guarded on typeof(stored) so
    repeated dusk->dawn->dusk cannot compound, and lerp everywhere. DayNight.luau diff empty.
  - Reviewer also confirmed render() never writes the same targets, so no double-writer race.

ALL 14 CODE TASKS COMPLETE. Task 15 (device-emulator sweep + OWNER GATE) is the controller's
own Studio work, not a subagent's. Final whole-branch review next.

FINAL WHOLE-BRANCH REVIEW (opus, 31 commits / 30 files / ~4000 insertions):
  Verdict "mergeable, with two things I'd fix first". Confirmed the mid-plan reversal is
  CLEAN — grep for ResolveWin/resolveWin/postResolveWin/choiceOverlay//resolve-win across
  roblox/src, roblox/tests and server/src returns ZERO live references. main.client.luau
  shrank ~880 -> 458 lines with no Instance.new at all. Interactive budget is exactly on
  target and .Active = true appears exactly ONCE in the branch.
  Must-fix 1 (docs truth) fixed by the CONTROLLER: the spec still described the pre-ruling
  escalation rule and the withdrawn RISK/BANK overlay in three places (70eef6c).
  Must-fix 2 + six should-fixes went to ONE fix wave (db6e0b9..1cebe95).
FINAL FIX WAVE re-review: 7 of 8 ADDRESSED. Finding 5 NOT addressed AND the wave's own
  finding-2 change resurrected it — removing the RequestLedger repopulation deleted the only
  self-heal for hudPrefs/hudSeenBeats, so a failed join GET re-taught all four onboarding
  beats to a returning player and silently flipped their preference, with no recovery until
  rejoin. Regression INTRODUCED by the wave, so one targeted round rather than shipping it
  (ccf8525). Root cause was a modelling error: "the profile has not answered" and "the
  profile says nothing was seen" were the same value. seenBeats is now nil when unknown, all
  four beats wait on a real list, and RequestLedger self-heals again behind a hudWriteSeq
  guard so a raced refresh yields to a concurrent write.
GATES GREEN ON HEAD: stylua clean, selene 0/0/0, lune 876/876, server 208/208.
NOTE: one server run reported 1/208 failing at 23.8s vs a normal 4.1s; three re-runs green.
  Reads as a pre-existing timing flake. Worth identifying if it recurs in CI.

Task 15 (controller Studio pass, first attempt): Studio was already Rojo-synced — ResolveWin
  correctly ABSENT, SetHudPreference + RequestLedger present, all four shared modules incl.
  the new HudLayout, and all three new controllers in StarterPlayer.
  LIVE INPUT-SINK CENSUS in Play, enabled GUIs only: RoshamboHud contributes exactly FIVE —
  Plate, ThrowArea.R/P/S, Pot.BankThese — with Slot.AcceptFate visible=false. One slot
  tenant, never two. Onboarding Card visible=false when idle; RoshamboLedger enabled=false.
  Exactly the intended budget, verified at runtime rather than by reading.
  Rendering confirmed: plate top-centre (STREAK/POT/POINTS), real Glyphs everywhere (tape +
  buttons), pot disc + BANK THESE in the slot, onboarding beat 1 firing on first join, and
  the optimistic pot pulse working WITHOUT the backend fields (applyLocalResult path).
  DEFECT FOR THE OWNER'S EYE: the onboarding card is low-contrast against a dusk scene and
  "TAP TO DISMISS" is nearly invisible.
  *** 42 commits UNPUSHED, so the dev App Runner backend does NOT have the 12 profile
  fields, the counters block, or PUT /preferences-hud. Ledger counters, the preference
  switch and server-side unresolvedWin cannot be gated until a push deploys them. ***

PUSHED 2026-08-02: 4a82491..ccf8525 (42 commits). App Runner roshambo_server_dev redeployed
  and reached RUNNING.
BACKEND VERIFIED END-TO-END from the Studio client after the deploy:
  source=ledger, counters{rounds=1 W=1 throwsP=1 bestPot=3}, unresolvedWin=true,
  escalationPrompts=true, seenBeats={drum}. The seenBeats value is the strongest signal —
  the drum card was dismissed in an EARLIER Play session, the SetHudPreference write landed,
  and it came back from the database after a full redeploy. RequestLedger round-trip works.
*** UNVERIFIED, NEEDS A HUMAN CLICK: the ledger did not open on a synthetic plate click.
  The cursor DID change to the pointer over the plate, and the console showed no client
  error. Wiring reads correct (HudController:156 -> EventBus.OpenLedger:Fire();
  LedgerController:833 connects it). Two candidate causes, NOT distinguished:
  (a) LedgerController connects OpenLedger at the BOTTOM of the file, after WaitForChild
      calls, and BindableEvent fires are not queued — the Task 12 deferred minor, which my
      attempt makes look more likely than "bounded at 5s and the tap costs nothing";
  (b) the MCP synthetic click may not route through Roblox's GUI input pipeline the way a
      real tap does, in which case there is no defect at all.
  DO NOT fix on a guess. One human tap on the plate distinguishes them.

OWNER GATE 1 (2026-08-02) — punch list + confirm-throw. Commits 70dc9cb, 02efc2b, 5380b1b,
  26953ae, b33607a, 6d1364d. Gates: 900 Luau (+29), 209 server, stylua/selene clean.
  RESOLVED from the earlier gate: the ledger DOES open — my synthetic MCP click was the
  artefact, not a defect. No fix was needed and none was made.
  Shipped: onboarding card contrast; blue lit selection with the other two dimmed AND warmed
  (the owner's two notes pulled opposite ways — "almost disappear" vs "orange/yellow on the
  other two" — so the synthesis recedes them while keeping the warm/cool split legible;
  owner said "sounds right"); immediate press feedback; mobile tier at 44x44
  (THROW_TOUCH_SCALE 0.58 — owner raised it from their literal 50%/38px).
  REVEAL TIMING, now finished properly. The first pass fixed only TheaterController and made
  things WORSE — client choreography landed on time while the owner's own example, the avatar
  grow, stayed early. Root causes found and fixed:
    - applyGrow is SERVER-side (main.server.luau:357). It had to stay there: Humanoid scale
      replicates server->client only, so a client trigger would show the grow to nobody but
      the winner. Delayed against the server's own StrikeAtServerTime, clamped by TallySec —
      fails late, never early, and there is no cue to miss.
    - main.client.luau:328 flipped the slot to ACCEPT YOUR FATE on RevealTheater — an
      unambiguous "you lost" 3s before the drum. Now held by the existing pendingReveal path.
    - STRUCTURAL FIND: the drum's settle time had NO shared definition — two literals in
      DrumController plus a 0.45s swing in HammerController. Consolidated into shared/DrumStep
      with SETTLE_SECONDS derived and test-asserted.
    - BoardController:160 has the same bug, deliberately untouched (dormant, jumbotron gone).
  NEW FEATURE — confirm-throw: required only when pointsAtStake > 0 (implementer's reading,
  flagged for correction); first tap selects, second commits; a different glyph moves the
  selection; AUTO-COMMITS AT LOCKOUT by owner ruling (a confirm must guard a mis-tap, never
  cost a round). Rule lives in HudModel and is tested there. confirmThrows persisted as the
  SECOND preferences-footer switch — the footer was sized for exactly this.
Known residual: ~0.5s after a round reopens, a fate-bound player can tap a throw the server
  refuses (the server's fate gate is not client-timed). The pending fate clears the lit tile.
UNPUSHED at this point: 6 commits.

OWNER GATE 2 (2026-08-03). Commits 5b45925, f40ad10. 918 Luau (+18), 209 server, gates clean.
  TEAHOUSE TOGGLE REHOMED. My earlier scoping call was WRONG: I explicitly deferred rehoming
  it on the reasoning that "the new HUD simply no longer collides with it" — but I moved the
  throw cluster into its corner. Both are AnchorPoint (1,1); the throws' right edge is at
  1 - JUMP_CLEARANCE (85%) and the toggle is 140x40 at the corner, so they clear on a wide
  viewport and OVERLAP on a narrow one. Owner hit it on mobile.
  Owner's call: delete the persistent toggle, the ledger is the door (MY TEAHOUSE). Consistent
  with the design's own rule — the plate is the only persistent interactive element precisely
  so nothing else needs a button — and the always-on interactive count drops by one.
  Implementer caught two things the brief did NOT specify:
    - the toggle was the panel's only CLOSE as well as its only open, so the panel gained its
      own small X. Without that the ledger could open a panel with no way out.
    - the whiff path never cleared selectedThrow, so autoCommit would have re-fired a pick the
      server had just refused. Adjacent bug, closed.
  Panel contents confirmed NOT standing dead zones (panel.Visible=false at :137; the earlier
  runtime census was reading each button's own property, ancestor hidden as expected).
  MY TEAHOUSE went in the ledger HEADER beside the X, not the footer: the two preference
  switches already span 472px, and a second footer row would cut the body from 68-83px to
  20-35px on a landscape phone.
  UN-CONFIRM shipped: tap the lit glyph to release back to selected; a different glyph moves
  the selection; nothing is final until lockout. Release is structurally incapable of emptying
  the selection ("release" is only returned for the already-selected glyph), asserted over a
  96-combination tap matrix.
UNPUSHED at this point: 8 commits.

Commit 5c40c88: made the "a release never empties the selection" rule REAL rather than
  contractual. It had been split across two files — HudModel's action vocabulary has no
  "deselect", but the state transition itself lived inline in main.client.luau, so a future
  edit to the release branch could have cleared selectedThrow with nothing to catch it. That
  would make autoCommit return nil at lockout and resolve the round against the pick the
  player had explicitly taken back. Extracted HudModel.applyTap (pure) and moved the
  controller onto it; side effects stayed in the controller.
  The implementer VERIFIED the new test bites: temporarily made release clear selectedThrow,
  confirmed 2 failures, reverted, re-ran green. A test that passes either way is worse than
  none, so this check was the point of the exercise.
  I had relayed the phrase "structurally incapable" from an earlier report without checking
  what it rested on; the owner asked, and it was stronger than the code earned. Now it isn't.
PUSHED 2026-08-03: ccf8525..5c40c88 (9 commits). 923 Luau, 209 server.
