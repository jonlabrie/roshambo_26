# SDD ledger — plan: docs/superpowers/plans/2026-08-03-play-hud-revision.md

Spec: `docs/superpowers/specs/2026-08-03-play-hud-revision-design.md`
Branch: `m4b-zendojo-art-pass` (no worktree — the App Runner dev service auto-deploys this
branch, and item 2 ran the same way)
BASE at start: 7ce47bb

## Pre-flight scan

Ran before Task 1. One conflict found and fixed in the plan before dispatch (commit follows):

- **Broken intermediate state, Tasks 2→8.** `HudController`'s render block assigned
  `confirmStrip.Visible = view.confirmPending or view.releasable`. Task 1 removes both view
  fields, so both operands become nil and `Visible = nil` is a runtime error — the branch
  would not have run in Studio for six tasks. Task 6 deletes that render block AND (after its
  own fix round) the instance itself — the instance's Position read three constants Task 3 had
  removed, so it was a hard load error, not merely dead. **Task 8 verifies absence, it does not
  delete.** Plan text amended accordingly.

No other contradictions between tasks or against the Global Constraints. Nothing the plan
mandates conflicts with the review rubric.

## Known transient states (NOT defects — do not "fix" early)

- `HudModel.autoCommit` survives Task 1 with its tests deleted, and is removed in Task 2.
- `HudController` is edited by Tasks 6, 7, 8 and 9 in sequence. Between Task 2 and Task 8 its
  `paintThrows` call still names `aux.pick` / `view.selected`, which are gone — it degrades to
  `paintThrows(nil, …)` rather than erroring. Task 8 fixes it.

## Tasks

### Task 1 — HudModel: the choose/switch state machine
Task 1: complete. Commit 5a699dd. 904 passed, stylua clean, selene 0 warnings.
Mutation-verified: breaking applyTap's "clear" branch (so a back-out leaves the glyph chosen)
produced 2 failures; reverted.
Review: spec ✅, quality approved.
- Minor (deferred): `view.selected` still reads `selectedThrow`, so the new machine is inert
  until wired. ADJUDICATED — that is precisely Task 2 (view exposes `chosen`) and Task 4
  (main.client drives it). Not a gap; verified against the plan, no action.
- Minor (noted): implementation transcribed from the brief's listing, so the TDD here is
  "confirm the prescribed code satisfies the prescribed tests". The invariant walk and the
  mutation check exceed the brief and carry the real regression value.
- ⚠️ resolved by coordinator: reviewer could not confirm red-green ORDERING from the diff
  (test + impl land in one commit). The mutation check is stronger evidence than ordering —
  it proves the test constrains the implementation. Closed.

### Task 2 — HudModel: view, escalation, sendAtLockout
Task 2: complete. Commit 0c3e39d. 903 passed, stylua/selene clean.
Mutation-verified twice: sendAtLockout ignoring `sent` → 1 failure; `armed` ignoring
`declinedThisRound` → 1 failure. Both reverted.
Review: spec ✅, quality approved.
- Implementer trimmed two describe blocks the brief did not name. Reviewer audited every
  deletion: `plate.pot` (field no longer exists, superseded by a strictly stronger test),
  `pickedThisRound` escalation guard (re-expressed via `chosen`), `fateBound` escalation guard
  (the concept has left this module by design). NO COVERAGE LOST. Scope extension accepted.
- Minor (deferred): the "holds the pick while there is still time" test uses secondsLeft = 5
  rather than a value just above the 0.5 boundary; the old test used 0.6. The boundary itself
  is still pinned at exactly 0.5, so this is looseness, not a hole. Carried to the final review.

### Task 3 — HudLayout: the new skeleton
Task 3: complete. Commits 2f974b8 + 308cf09 (fix round 1). 906 passed, stylua/selene clean.
Mutation-verified: dropping plateBottomOffset's math.max clamp → 1 failure; re-adding a 28px
confirm row → 1 failure. Both reverted.
Review: spec ✅, quality CHANGES NEEDED → fix round 1 → all addressed, re-review clean.

COORDINATOR ERROR, recorded so it is not repeated: my dispatch asserted
`roblox/tests/HudLayout.spec.luau` "does not exist yet". It existed, with 9 tests. The PLAN
hedged correctly ("create if absent") and I hardened that into a false claim. The implementer
replaced the file wholesale on my word and lost 4 tests' coverage for code Task 3 never
touched. Lesson: never state a file's existence in a dispatch without checking it.

Fix round 1 restored: AREA_H + AREA_H_TOUCH independent derivation (the module header's own
warning about a BTN_H tweek silently moving the cluster was, until this, unenforced); the
touch-tier derivation and its inequalities; and the `src/shared` purity guard, ADAPTED to
`typeof(value) == "number" or typeof(value) == "function"` rather than deleted. Report's
rationale corrected — it had claimed all 9 deletions were unsatisfiable by design, true of only 4.
Re-review ran the adversarial check: dropping the TILE term from AREA_H → 1 failure at the
restored test, "expected 86 to be 120". Non-circular, confirmed.
- Minor (deferred): no test confirms the cluster footprint still fits a 375px viewport now that
  PLATE_BOTTOM is gone; the successor constraint is the toast band, which belongs to Task 10.
  Carried to the final review.

### Task 4 — main.client: pick state and the wire
Task 4: complete. Commit 7ad59b1. Gates clean, 906 passed at the time.
Review (opus, since this file has NO Lune coverage): spec ✅, quality approved.
`SubmitPick:FireServer` occurs exactly once, in `sendPick`; `sendPick` has one call site, the
heartbeat's sendAtLockout branch; `sent = true` precedes the fire. Reviewer independently traced
(tap,tap,tap,tick,boundary) orderings — no double-send, no cross-round carry-over, structurally
rather than by timing.
Two implementer deviations, both RULED CORRECT by the reviewer:
- `fateBound` became write-only once buildInputs stopped reading it → inline
  `-- selene: allow(unused_variable)`. Verified narrow and load-bearing (removing it = 1 warning
  naming only fateBound). **TASK 5 MUST DELETE THIS SUPPRESSION** along with fateBound itself.
- `maybeShowReveal`'s fate branch referenced deleted myPick/selectedThrow; translating them was
  required (leaving them would have been implicit global writes). Task 5 deletes the branch.
- Minor (deferred): the report's verification greps were captured before its own last edit, so
  line numbers are 4 off. Substance unaffected; re-verified by the reviewer.
- Minor (deferred): HudController.client.luau:428 comment still says "main.client sets myPick".
  Task 8's territory.

### CROSS-TASK DEFECT found in Task 4's review, fixed at source
Commit 20bb99b. 910 passed. **The 400-500ms post-send tap window.**
`sendAtLockout` fires at secondsLeft <= 0.5 but `throwsEnabledFor` kept taps live until
secondsLeft > 0 failed, and `tapAction` never consulted `sent`. A player could double-tap
another glyph in that tail, watch all three light up, and believe they had withdrawn — while
the server already held their throw. Exactly the dishonesty the feature exists to prevent, and
neither the spec nor the plan anticipated it.
The window is STRUCTURAL: the 0.5s slack exists so the pick reaches the server before the
lockout, so there will always be a period where the throw is on the wire and ACTIVE has not
ended. Resolution: once sent, the round closes to that player — one condition in
`throwsEnabledFor` (`and not inputs.sent`), which drives BOTH tapAction ("ignore") and
view.throwsEnabled (so the HUD dims and the player SEES the round close). No second copy of
the rule in tapAction.
Adversarially verified: removing the clause → 4 failures. Regression-checked: `view.chosen` is
NOT gated on throwsEnabled, so the thrown glyph stays lit through TALLY/REVEAL.
OWNER-VISIBLE CONSEQUENCE, surfaced in chat: the throw buttons now dim for the last ~0.5s of
every round. 19.5 of 20 seconds remain changeable.

### Task 5 — main.client: park the fate branches
Task 5: complete. Commits 9da69c3 + 3b3cfd3 (coordinator note fix). 910 passed, gates clean.
Review: spec ✅, over-deletion audit CLEAN — reviewer traced drumAtRest end to end (set true at
the drumRest cue and by the REVEAL_SAFETY fallback, false on the ACTIVE transition, read only in
maybeShowReveal) and confirmed REVEAL_SAFETY, the whiffed branch, pendingReveal and the "win"
beat all survive intact. The Task 4 selene suppression was removed with fateBound, as required.
- Implementer deviation RULED CORRECT: reworded publish()'s "(fate-bound, phase, pick already
  made)" comment, which named a rule dead since Task 4 and sat one line from a mandated deletion.

PLAN DEFECT found by the reviewer, fixed by me (3b3cfd3): the header note the plan told Task 5
to add — "FATES ARE PARKED. The rock drop, the avatar grow and ACCEPT YOUR FATE are all off" —
is FALSE until Task 13 runs. Task 13 is what empties EffectRegistry.LOSS, deletes applyGrow and
drops fates:begin. Until then the chase still spawns, winners still grow, and the server still
refuses a pick from a player mid-chase. My plan split the parking across two tasks eight apart
and then had the first one announce the second's work as done.
Note now scopes itself to the client half and says a player can still be caught by a fate this
file no longer surfaces. **Task 13 gained a Step 6 to rewrite it** once that becomes false.
Lesson: a comment claiming a feature is off while half of it runs is worse than no comment.

### Task 6 — HudController: cluster reorder + bank button
Task 6: complete. Commits 92cddc5, 0d111f9 (fix 1), 2a7f510 (fix 2), 07fa110 (coordinator bridge).
910 passed, gates clean. Review: spec ✅, geometry verified by arithmetic at BOTH tiers —
buttons+tape fill throwArea with exactly ROW_GAP between them, halo bleeds HALO_BLEED on all four
sides (the anchor flip was carried on anchor AND position, so the classic error did not happen),
and the bank button's top edge lands exactly on CLUSTER_TOP_FROM_BOTTOM (182 desktop / 140 touch),
which is what keeps Task 10's onboarding cards off it.

TWO CRITICALS, BOTH ORIGINATING IN MY BRIEF, both invisible to every gate:
1. **HudController could not load.** Four locals read HudLayout fields Task 3 deleted/renamed
   (PLATE_H, SLOT_H, CONFIRM_H, CONFIRM_GAP) and fed the nils to UDim2 arithmetic. My ledger had
   logged "HudController references removed names — Tasks 6-10 fix them" as an EXPECTED transient
   state without noticing it meant a dead HUD for five consecutive tasks. Fixed by pulling Task
   8's confirm-strip deletion forward (it was the last reader of three of the four) and carrying
   PLATE_H as a one-task literal.
2. **The bank button never pulsed.** setBank runs at 10Hz off render(); my brief had it cancel and
   restart a 0.9s tween every call, giving it ~3% of its travel — a static button with
   imperceptible jitter, and the "unacknowledged pot" signal never appeared. The code it replaced
   had an `if not pulse then` guard for exactly this reason and the rewrite dropped it. Now gated
   on a `pulsing` state variable, with Text assignment OUTSIDE the early return so the figure
   still tracks a changing pot.

COORDINATOR BRIDGE (07fa110): the review found the SAME defect class in OnboardingController —
SLOT_H/SLOT_GAP/PLATE_BOTTOM all nil, file dead, onboarding beats never appearing. Bridged to
BANK_H/BANK_GAP + literal 58 so the branch stays runnable; Task 10 re-derives properly. Also had
to move PLATE_BOTTOM's declaration ABOVE STATIC_ANCHORS, which reads it — my first attempt left a
forward reference that would have resolved to a nil global.

STANDING CHECK now in every remaining client-file dispatch: reconcile every HudLayout.X and
view.X/aux.X read against what those modules actually export. It is the only thing standing in
for a compiler on .client.luau files.
- Minor (deferred): BANK_W = 150 is not tier-scaled; on touch the cluster is 148, so the bank
  button is 2px wider. Cosmetic, deliberately not churned after the geometry was verified exact.
- Minor (deferred): the plate's POT cell reads 0 beside a bank button reading the real figure,
  until Task 7 replaces the plate. Task 7 is next, so the window is one task.

### Task 7 — the plate: right margin (superseded), ledger door, then the bottom row
Commits: df7bb80 (right-margin plate), 781eb41 (the ≡ ledger button), 9d6e0cf (spec),
0b58332 (Task 7A: relocation + hide/reveal + two-stage ≡). 907 passed (910 minus exactly the 3
plateBottomOffset tests, now deleted with the mechanism). Gates clean. NOT yet reviewed — the
owner superseded the placement before the review dispatched, so 7A+7B will be reviewed together.

**THE BIGGEST FINDING OF THE RUN, and it was a false premise in my spec, not a coding error.**
The implementer noticed the plate had carried the ONLY `EventBus.OpenLedger:Fire` in the codebase
and stopped rather than inventing a fix. Verified: two listeners, zero firing sites — the ledger
unreachable, taking MY TEAHOUSE, the preferences footer and every lifetime stat with it.
LedgerController's own header said so explicitly: the plate was "the only interactive information
element in the whole design, precisely so maximal costs no persistent button of its own anywhere
on screen." My spec justified moving it into the camera-drag strip by quoting the owner's
"there are no interactive elements in this display" — and I never checked that against the code.
No test could catch it: the door is not a function, it is the ABSENCE of a caller.
Owner ruled: plate goes genuinely inert, a dedicated ≡ button opens the ledger. Knowingly concedes
the "no persistent button" principle — but the teahouse toggle went because it COLLIDED with the
throw row, not because a button was unaffordable, and this one anchors to the cluster's own edge.

**OWNER SUPERSEDED THE PLACEMENT MID-FLIGHT** (after df7bb80/781eb41 landed, before review):
the plate leaves the jump strip for the BOTTOM ROW, beside the tape, below the ≡. One line,
tape-tile height, normally HIDDEN — revealed by the ≡'s first tap or any change in points/streak,
held 2s, then faded. The ≡ became two-stage: a second tap while the line shows opens the ledger.
Integrated before reviewing rather than after; reviewing superseded code is the only real waste.
The whole jump-button measurement died with it — plateBottomOffset, PLATE_JUMP_GAP, PLATE_W,
PLATE_ROW_H, jumpButton/placePlate/rewatchJump/jumpWatch and 3 tests. **Nothing in the HUD is now
positioned against geometry Roblox owns.** The lesson outlives the code and is recorded in the
spec: anything placed against platform-owned geometry must MEASURE it, never encode its arithmetic.

Coordinator decisions made without asking (stated to the owner): the second-tap window is
"anything on screen" (hold + fade), not a flat 2s — a control still visible must still be
answerable, the same rule that closed the post-send throw window; right-aligned and content-sized;
hidden again after the ledger closes; format `×3  900`.

### Task 7B — RollingNumber (in flight)
Numbers animate to their new values so BANKING READS AS A TRANSFER: the pot drains while the
balance rises, no copy needed. Falls out of one rule (animate any change) because a bank lands as
a single ProfileUpdate carrying both sides; LOSS and WIN then read correctly for free.
Two traps flagged in the dispatch, both already fallen into once on this branch: key the animation
on the TARGET changing not on render() running (the bank-pulse failure), and the bank button must
follow its DISPLAYED figure not the model's or it hides before the count is seen.

### Task 7 REVIEWED & CLOSED (7, 7A, 7B together)
Commits df7bb80, 781eb41, 9d6e0cf, 0b58332 (7A), 8534980 (7B), ffe888e (fix round). 919 passed.
Review (opus): spec ✅, quality APPROVED — no Critical, no Important. Fade generation-guard traced
through 4 interleavings; counting driver continues (not restarts) on a repeated target and
continues from the DISPLAYED value on a new one; bank button's final hide is driven by the
unconditional 10Hz heartbeat so it cannot stick at zero.
ADVERSARIAL: valueAt mutated to return `to - 1` at t=1 → 5 failures across ascending, descending
and monotonicity. The off-by-one that would leave a permanently wrong total on screen cannot ship.
Fix round closed 3 Minors: (1) bank button was tappable while lingering at an emptied pot — now
`bankArmed`, visible-but-unarmed, with the asymmetry vs the ≡ documented (the ≡'s visible window
IS its answerable window; the bank's visible window deliberately outlives its armed one because
what is on screen is an animation of something already done); (2) applyContrast wrote into a
property the fade owns — write guarded on `#plateFadeTweens == 0`, capture side deliberately
unguarded and still reading plateRestTransparency; (3) the ≡ text glyph became three drawn Frames
— it is the ONLY door to the ledger and a missing Gotham glyph would render a box.
- Accepted, not fixed: applyContrast runs twice per day/night publish (attribute + EventBus). It
  is idempotent and the dual subscription is deliberate start-order-proofing.
- ⚠️ FOR TASK 8: `aux.pick` is never published either — main.client's publish() sends only
  {session, tape, timerKnown}. Task 8 must close BOTH aux.pick and view.selected, not just one.
- ⚠️ FOR TASK 10: OnboardingBeats' `bank` beat still anchors to `plate` and the controller still
  places that anchor top-centre, where the plate no longer is. Also the unknown-beat fallback.
- ⚠️ OWNER GATE: the plate's nested AutomaticSize.X (auto-sized Frame containing a scale-sized
  auto-width label plus UIPadding) is the one thing no reading settles — check it sizes to its
  text at both tiers rather than collapsing to its padding.

### Task 8 — SWITCH?, selection emphasis, and both silent nils
Task 8: complete. Commit 7e7ee3f. 919 passed, gates clean.
Review: spec ✅, quality APPROVED — NO findings at any severity.
Closed BOTH dead reads in the selection paint: `view.selected` (removed in Task 2) and `aux.pick`
(never published — publish() sends only {session, tape, timerKnown}). Until this task the paint
rested entirely on the optimistic `pressedSym` and its 0.5s hold, so a chosen glyph went dark
half a second after the tap. Now `view.chosen or pressedSym`.
setChosenPulse idempotence verified by trace (10 identical ticks leave the tween untouched);
halos restored by hand after Cancel; disjoint from setBank's pulse. paintThrows branch order puts
`prompted` before the dimmed-unchosen branch, and HudModel guarantees switchPrompt ~= chosen so
they can never collide. Both call sites pass the new third argument.
- Implementer caught a real bug IN MY PLAN'S CODE: `TweenService:Create(...)` followed by a line
  starting with `(` is Lua's ambiguous-syntax trap — it parses as a call chained onto the previous
  expression, silently becoming `Create(...)(chosenPulse):Play()`. Same trap the Task 6 reviewer
  found in the setBank listing. Grep now confirms zero live instances in the file.

### Task 9 — contrast: strokes off text, escalation backing, toast
Task 9: complete. Commits 8047496 + 157b01e (fix round 1). 919 passed, gates clean.
Review: spec ✅, quality CHANGES NEEDED → fixed → verified.
THE DELIVERABLE HELD: the reviewer independently traced ALL 17 UIStroke sites across src/ to
their parents' declared classes — including LedgerController and TeahouseController, which the
brief never named — and confirmed zero remain on a TextLabel. Rule established branch-wide, not
three offenders patched. TeahouseController has no UIStroke at all.
CRITICAL, introduced by my own brief's Step 1: `escalation` is a FIXED-height frame (130px) and
the 12px padding I told them to add took 24px out of it without resizing either child.
escalationCount [0,92] and a bottom-anchored escalationPrompt [76,106] then OVERLAPPED BY 16px —
the 84px countdown digit sitting behind "CHOOSE A THROW". So the task that exists to fix one
illegibility introduced another in the same element. Fixed by growing the frame to 154 (130
content + its own 24px padding), restoring the pre-padding 8px gap exactly, with a comment tying
height to padding so the next person who pads it knows to grow it.
- Also corrected an inaccurate contrast figure in a comment (18:1 → the real 16.7:1).

### Task 10 — OnboardingController: safe band re-derived
Task 10: complete. Commits 7c44d5c + c672d9a (fix round 1). 921 passed (+2), gates clean.
Review: spec ❌ → fixed → verified. My Task 6 TEMPORARY BRIDGE is gone as planned.
Adversarial: reverting the plate→wallet rename → 2 failures. Tests genuinely constrain it.
CRITICAL — a REASONING failure, not a coding one, and the most instructive of the run. The
`wallet` anchor put a 260px opaque card in the BOTTOM-LEFT corner, over Roblox's movement
thumbstick, and the comment justifying it said this "keeps it clear of every live element."
True of OUR elements; exactly wrong about the platform's. HudController's own header, four lines
in, says "bottom-left : the movement thumbstick. Untouchable." The whole file reasons about cards
vs the HUD's cluster and never about the corners Roblox claims. It was also pointing at the wrong
side of the screen — the real plate is right-anchored beside the tape. Fixed by giving `wallet`
the same placement as throwArea, the one band proven safe at ANY card height and both tiers
because AutomaticSize.Y grows the card upward, away from everything.
GENERAL RULE now in the file: a card must clear the corners ROBLOX owns, not just the ones this
HUD uses.
IMPORTANT — the safe band degraded to "never crash" instead of "never overlap". Luau's math.clamp
ERRORS when min > max, so maxY was guarded with math.max(minY, ...) — which stopped the throw but
collapsed the band to a point, pinning the card's top while its bottom grew with cardH into the
cluster's footprint (past cardH > 126 on a 390px landscape phone at touch tier). Latent, not live:
today's copy wraps to ~109-115. Fixed by inverting which side yields — maxY pinned to the cluster
unconditionally, minY derived from it via math.min. The collapse now sacrifices the TOAST, never
the cluster: covering a transient notice is recoverable, covering a live button is not.
- ⚠️ deferred: TOAST_BAND = 64 is a fixed reservation for an AutomaticSize toast; a 3+ line toast
  can exceed it. Pre-existing design choice carried from the plan, not a Task 10 regression.

### Task 11 — Takeover.luau: the extracted suspension
Task 11: complete. Commit 1875ae1. 921 passed, gates clean.
Review: spec ✅, quality APPROVED. Fidelity diff clean — every timed WaitForChild (10s/5s/10s),
all 5 warns, every pcall, the suspendedVia LATCH and savedWalk's nil-guard moved byte-identical;
only [LEDGER] → [TAKEOVER]. Ref-count traced three ways including release→acquire (a stray release
must not leave depth at -1 and make the next acquire fail to suspend) — correct.
default.project.json confirmed to map src/client as a DIRECTORY, so the new ModuleScript resolves.
IMPLEMENTER CAUGHT WHAT MY BRIEF MISSED: LedgerController's CharacterAdded respawn handler. It
referenced suspend()/savedWalk, which this task privatized, so leaving it behind would have broken
it — and deleting it would have regressed the hardened respawn-refreeze protection that exists
because of a real item-2 bug (guard checked BEFORE a 10s yield and never after → frozen player).
Moved into Takeover with the guard generalized isOpen → depth > 0.
The subtle right call, verified by the reviewer: the respawn handler calls suspend() DIRECTLY, not
acquire(). Going through acquire would increment depth on every respawn, permanently desyncing the
count from open panels and requiring an extra release to ever thaw. And the item-2 bug shape is
NOT reproduced — depth is re-checked after the WaitForChild yield, matching the original.
- ⚠️ FOR TASK 12: Takeover.luau:115's warn still names "the ledger" specifically. Genericize it
  when the teahouse becomes a second holder, or a teahouse-held freeze that fails to re-enable
  tells the player to reopen the wrong panel.
- Minor (deferred): LedgerController:774's "before the release, so a respawn mid-release cannot
  re-freeze behind us" comment is now stale — isOpen is no longer read by the respawn handler and
  release() has no yield points. Wording only, no functional impact.

### Task 12 — the teahouse becomes a takeover
Task 12: complete. Commits dcaedde + bcd47d5 (fix round 1). 921 passed, gates clean.
Review (opus): spec ✅ → one Important → fixed. THE OWNER'S REPORTED DEFECT IS FIXED: the ✕'s
absolute y no longer contains viewportHeight at all, so it cannot go negative at any size
(verified at 844x390, 320x568 and 1920x1080). Old code put it at -182 on a landscape phone.
The ScrollingFrame split (22 children re-laid out) was judged the BETTER of two valid options, not
gold-plating: it reserves a real 44px non-scrolling header so the ✕ can never scroll away. It
genuinely scrolls — AutomaticCanvasSize.Y with a UIListLayout, not the zero-canvas trap.
IMPORTANT, and a defect that only appeared BECAUSE the fix worked: `panel` is a Frame and `Active`
was never set, so it did not consume input. Harmless at 340x520 in a corner; fatal now that it
covers the whole viewport at DisplayOrder 20 over HudController's still-live DisplayOrder-0
buttons. Tapping apparently-empty washi in the lower right hit the LEDGER DOOR behind it → ledger
opens at the SAME DisplayOrder → both takeovers up, Takeover depth 2. The "one panel at a time"
invariant defeated through the back. A tap slightly lower submits an unseen throw.
What makes it a fair catch: LedgerController documents this exact rule, in this repo, about this
exact problem ("a Frame that is not Active does not consume input, so every tap inside the panel
would fall through") and pairs it with a full-screen scrim. The teahouse was built "on the
ledger's pattern" while missing the two things that MAKE that pattern a takeover.
Fixed with scrim + panel.Active = true + Escape — the ledger has three exits from a
movement-suspending panel and this had one. Also inverted setOpen to render BEFORE acquiring
(the ledger's deliberate ordering: suspending before painting strands a frozen player).
- Also: Takeover.luau's header no longer claims a specific ledger↔teahouse interleaving that the
  call sites do not actually exercise (close-then-open means it always drops to depth 0).

### Task 13 — park the fates (server half)
Task 13: complete. Commit c6d4366. 923 passed (+2), gates clean.
Review: spec ✅, quality APPROVED, no findings.
The elegant part held: EffectRegistry.LOSS = {} is the WHOLE park for the client visuals.
Reviewer traced it end to end — empty pool → EffectSelector returns nil → ChoreographyMachine
emits a nil effect → FateController's `cue.effect:sub(1,4) == "fate"` short-circuits. FateController
needed NO edit and receives no flight.
Adversarial: repopulating LOSS with the byThrow table → exactly 1 failure. Re-enabling fates
breaks a test rather than passing silently, which was the point of writing it.
Over-deletion audit clean across the ~2000-line server file: TweenService and DrumStep survive only
as prose in the timing-recipe comment; the per-player reveal branch still does applyLocalResult /
pushStats / fireProfile for every result; FateRegistry, fates:isBound and the seam comment all
survive. The reveal-timing recipe is preserved above onReveal with BOTH halves — the
StrikeAtServerTime + DrumStep.SETTLE_SECONDS clamp, and "Humanoid scale replicates server→client
only" (an avatar effect triggered client-side is visible to nobody but its owner).
- IMPLEMENTER CAUGHT ANOTHER BAD ASSUMPTION IN MY BRIEF: I said EffectSelector.spec's byThrow test
  used a fixture registry. It used the REAL one, so parking LOSS broke it. They converted it to a
  fixture, which is what the SPEC always said should be true — so the fix converged the suite with
  the design rather than patching CI green. byThrow stays genuinely covered.

### Task 14 — retire confirmThrows
Task 14: complete. Commit 86003d7. Roblox 923 passed, server 210 passed, gates clean.
Review: spec ✅, quality APPROVED, no findings.
Adversarial: re-adding confirmThrows to buildProfilePayload → 3 server test failures. Guarded.
SCOPE CORRECTION, ruled necessary: my brief named 4 files; confirmThrows was ALSO wired through
roblox/src/server/main.server.luau (HudPrefs type, prefsFor, prefsFromProfile, the fireProfile
payload and the SetHudPreference handler). The reviewer read all of it and confirmed
escalationPrompts still flows intact in BOTH directions — the real risk, since both preferences
travelled the same functions and the same remote. Every producer now emits exactly one key and
every consumer reads exactly that key; no partial-object risk.
Footer re-centred: makePrefSwitch lost its `column` param and the remaining block anchors from the
footer's centre, so a lone switch does not read as something that failed to load.

## ALL 14 TASKS COMPLETE — proceeding to the final whole-branch review.

## FINAL WHOLE-BRANCH REVIEW (opus) + fix wave — COMPLETE
Fix wave ed6fda0, spec corrections 67d4146. Re-review: all six ADDRESSED, no regressions.
FINAL GATES, run by me: Luau 924 passed / stylua clean / selene 0 warnings; server 210 passed;
tree clean; 32 commits 7ce47bb..67d4146.

Four Important findings that only a whole-branch read could surface, none visible to any gate:
1. SWITCH? was CLIPPED ON PHONES — 36px pill, 13px GothamBold, no scaling; "SWITCH?" needs ~60px,
   so it rendered as roughly "WITC" on the exact tier the design was written from. Fixed by
   widening to BTN_W + TextScaled + UITextSizeConstraint(13). Lands at ~9-10px — right at the
   legibility floor. OWNER GATE ITEM.
2. The escalation overlay COVERED THE BANK BUTTON on a short landscape phone — a regression from
   Task 9's own fix (growing 130→154 to stop its labels overlapping consumed the clearance; at
   130 it cleared by 0.3px). Now clamped against CLUSTER_TOP_FROM_BOTTOM per tier. Verified at
   H=354 (10px gap) and H=1044 (no clamp needed).
3. THE SPEC CONTRADICTED THE SHIPPED MODEL on the branch's central rule — §1 still said taps stay
   live for all of ACTIVE while the code carries `and not inputs.sent`. Left alone, the next
   reader removes the clause as inconsistent and reopens the 400-500ms dishonest-tap window.
   Spec now states it, marks it load-bearing, and records why.
4. THE FALSE PREMISE THAT COST THIS BRANCH ITS WORST BUG survived verbatim in THREE file headers
   ("the plate is the only interactive information element... so maximal costs no persistent
   button"). That sentence, taken at face value, is what left EventBus.OpenLedger with zero firing
   sites. All three now name the ≡ and LedgerController's says WHY the plate stopped being the door.

Promoted from deferred: SEND_AT was unpinned FROM ABOVE — it could have been changed from 0.5 to
anything up to 4.9 with all 923 tests still green, and that constant governs how long backing out
stays honest. Now pinned both sides; mutation to 1.0 → exactly 1 failure.

Deferred minors triaged and accepted: BANK_W's 2px overhang (verified harmless — it overhangs LEFT
into empty space, 6px clear of the ≡, and they share no vertical band); TOAST_BAND=64 (only the
drum anchor consults the band; a 4-line toast would be needed to breach it); applyContrast's
double fire (idempotent, and the dual subscription is deliberate start-order-proofing four other
controllers use); LedgerController:774's stale comment (fixed in the wave).

WORKSPACE DELIBERATELY KEPT, not deleted as the skill suggests: this ledger is the owner's map to
every ruling and every owner-gate item, and the Studio gate has not happened yet.
