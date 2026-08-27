# SDD ledger — plan: docs/superpowers/plans/2026-08-03-play-hud-round-two.md

Spec: `docs/superpowers/specs/2026-08-03-play-hud-round-two-design.md`
Branch: `m4b-zendojo-art-pass` (no worktree — the App Runner dev service auto-deploys this
branch, and both previous runs went the same way)
BASE at start: c27e2ea. Prior run (14 tasks) closed at 67d4146; 924 Luau + 210 server green.

## Pre-flight scan

Three ordering risks found, all carried into the dispatches rather than the plan (they are
placement constraints, not text changes):

1. **HudLayout's ring block must come AFTER `BTN_H_TOUCH`.** `RING_D = HudLayout.BTN_H` and
   `RING_D_TOUCH = HudLayout.BTN_H_TOUCH`, and `BTN_H_TOUCH` is derived partway down the file.
   A block placed above it reads nil and every downstream derivation silently becomes garbage.
2. **The ring's CLICK HANDLERS must come after `plateVisible` is declared** (~HudController:314).
   The ring itself can be built earlier, but its two-stage test reads `plateVisible`, and a
   forward reference resolves to a nil global. This is the exact class that has bitten twice.
3. **The bottom row gets tight on a narrow viewport.** plate + ring + tape now spans
   `TAPE_W + RING_GAP + RING_D + RING_GAP + plateW` inboard of `1 - JUMP_CLEARANCE`. At the touch
   tier on a 320px-wide screen that leaves ~16px of left margin. Landscape (844) is the real
   target and is fine, but every geometry task must state the arithmetic rather than assume.

No contradictions between tasks or against the Global Constraints.

## Known transient states (NOT defects — do not "fix" early)

- Task 4 adds the ring's two-stage gesture while `ledgerButton` still exists; Task 5 deletes the
  hamburger. Two doors coexist for one task, deliberately — a task that both added and removed
  the door could not be reviewed against either state.
- Task 4 places the ring at `-EDGE`; Task 5 introduces `EDGE_BOTTOM` and moves every vertical
  anchor including the ring's.
- Task 7 ships the splash unconditionally; Task 8 makes it a preference.

## Tasks

### Task 1 — RingTimer: the segmented sweep
Task 1: complete. Commits cfaf794 + f7726ac (coordinator test fix). 936 passed, gates clean.
Review: spec ✅, quality APPROVED. Reviewer independently re-derived all four functions rather
than trusting the tests, and confirmed: `lit` hits exactly 0 and exactly N at the endpoints and
holds the at-least-one-segment property down to 1e-9; `angleAt`'s max is 360 - 360/n < 360 for
ANY segment count; `segmentWidth`'s ceil+1 guarantees overlap at any radius, not just the tested
one.
Adversarial (mine): ceil→floor → 1 failure, the at-least-one-segment test. Adversarial
(reviewer's): dropping angleAt's -1 → 3 failures. The off-by-one I worried about in the brief is
caught by the first assertion alone.
- Minor, FIXED by me (f7726ac): segmentWidth's test asserted `>= pitch` where the design needs
  strict overlap — an implementation that dropped the +1 margin would have passed while making
  the ring read dotted. Now `>` across a spread of radii and counts, not just the 23/36 the ring
  happens to use today.
- Minor (deferred): isWarning has no negative-secondsLeft test. Harmless — at or below 0 nothing
  is lit, so no segment takes the colour either way.

### Task 2 — HudModel: shared threshold, 1s fuse, dismissal
Task 2: complete. Commit 812bccd. 943 passed (+7), gates clean.
Review: spec ✅, quality APPROVED, no findings.
SAFE BY CONSTRUCTION, not merely by test: the reviewer traced every read of `declinedThisRound`
and found exactly ONE — inside `armed`, which feeds only `escalate`. throwsEnabledFor, tapAction,
sendAtLockout and onRoundEnded are all structurally blind to it. So widening its meaning to cover
"dismissed the nag" could not leak into whether the player can throw.
Mutation: ESCALATE_AT 5→9 → 1 failure. Notably it broke the PRE-EXISTING literal-pinned test, not
the new derived one. Reviewer's verdict, which I accept: both belong. The literal test pins the
VALUE (5 is a product decision), the derived test pins the WIRING (ring and prompt share one
source). Removing the literal would leave the actual number unverified.
RingTimer.isWarning takes the threshold as a REQUIRED parameter with no default, so it cannot
drift back to a private copy.

### Task 3 — HudLayout: the ring's slot
Task 3: complete. Commit ecf1231. 949 passed (+6), gates clean.
Review: spec ✅, quality APPROVED, no findings.
Declaration order verified line by line — every field each new line reads is assigned strictly
above it. This was pre-flight risk #1 and it did not materialise.
Arithmetic: BOTTOM_ROW_H 34→76 / 24→44; AREA_H 120→162 / 78→98;
CLUSTER_TOP_FROM_BOTTOM 182→224 / 140→160. RING_THICKNESS 6 desktop, 3 touch.
ONBOARDING BAND VERIFIED on a 354px landscape-phone canvas: maxY=170, minY clamps 178→170, card
bottom at 170, cluster top at 194 → 24px gap, exactly SAFE_MARGIN. The clamp DID engage, which
confirms the collapse sacrifices the toast and not the cluster — the fix from the previous run
holding under a 20px-taller cluster.
Amended AREA_H tests judged necessary and still independent: BOTTOM_ROW_H is separately pinned
against bare primitives, so AREA_H building on it is a staircase, not a self-reference.
Adversarial: RING_D→TILE → 2 failures.

### Task 3 CORRECTED — the ring is not in the tape's row
Commits ecf1231 + 1bb192a. 948 passed, gates clean.
**COORDINATOR ERROR, and the most expensive of this run so far.** The ring's position was specced
when it was going to sit beside the tape; the owner then decided it REPLACES the hamburger, and I
never reconciled the two. The hamburger sits inboard-left of the throw cluster at THROW BUTTON ROW
height, not in the tape's row. So BOTTOM_ROW_H = max(TILE, RING_D) was inventing room in a row the
ring never enters — it would have shipped a cluster 42px taller on desktop and 20px on touch for
nothing, and moved the wallet plate for nothing.
Caught by the owner, not by any review: every reviewer checked the arithmetic was SELF-CONSISTENT,
which it was. Nobody could check it against a layout that existed only in the owner's head.
Lesson: when a decision moves an element, re-read every OTHER statement about that element before
carrying on. The two statements were four messages apart and both were mine to reconcile.
Corrected: BOTTOM_ROW_H deleted, AREA_H back to 120/78, CLUSTER_TOP_FROM_BOTTOM back to 182/140 —
all matching the pre-Task-3 baseline. Ring constants kept (RING_D 76/44, thickness 6/3): still
right, and now doubly so, since the ring sits BESIDE the button row and BTN_H is exactly that
row's height. A test now pins the ABSENCE of the growth so it cannot creep back.
Tasks 4 and 5 both got simpler — Task 4 loses its move-the-plate step, Task 5's plate change is
now just the vertical drop plus becoming a button.

### Task 4 — the ring, built and driven
Task 4: complete. Commit 01bfc42. 948 passed, gates clean.
Review (opus): spec ✅, quality APPROVED, 2 Minors.
The plate did NOT move — the stale brief's Step 1b was correctly ignored in favour of the
corrected plan. Both reconciliations clean (18 HudLayout reads, all View/aux reads, all RingTimer
reads). Handlers at :990/:993, ~680 lines BELOW plateVisible's declaration at :315 — pre-flight
risk #2 did not materialise.
GEOMETRY VERIFIED at both tiers: the ring's bottom is the button row's bottom and its height IS
BTN_H, so it exactly fills the row, top and bottom. Clearances 8px to the buttons, 10px (ROW_GAP)
to tape/plate/bank. The only overlap is ledgerButton, the deliberate transient.
Trig verified: (D/2 + R·sin a, D/2 − R·cos a) puts segment 1 at the top and sweeps clockwise, and
Rotation makes each segment tangent. Segments overlap the arc pitch at both tiers (8 vs 6.11;
5 vs 3.58).
SPOILER GATE verified phase by phase: revealedWorldThrow has ONE write site, inside the same
`if p.roundId` block as revealedRoundId, behind maybeShowReveal's drumAtRest early-return. Nothing
shows a world throw before drum rest. TALLY and pre-rest REVEAL show a blank ring.
timerKnown == false lights ZERO segments and blanks the digits — no "plenty of time" lie.
- Minor 1: the REPORT claimed RING_D == LEDGER_SIZE at both tiers. False on desktop (76 vs 40);
  what is identical is the POSITION FORMULA. **Task 5 must delete LEDGER_SIZE because the
  hamburger is gone, NOT because it equals RING_D.** Recorded so nobody reasons from the wrong
  premise.
- Minor 2 → folded into Task 5: main.client.luau:22's header documents the aux contract as
  { session, tape, timerKnown } and is now one field short of what publish() sends.
- ⚠️ owner gate: the chosen-tile halo bleeds 7px left and now clears the ring by 1px (it shared
  the same edge with the 40px hamburger before). Also the ring's washi disc is outside
  applyContrast's scope, so it keeps its night value against a pale day canyon.

### Task 5 — hairline + hamburger deleted, cluster dropped, plate is a door
Task 5: complete. Commits eb2a2e0 + 45513b0 (fix round). 949 passed, gates clean.
Review (opus): spec ✅, quality APPROVED, no functional defect.
`span` SURVIVES with live readers (:1219-1220) — it was the hairline's variable and the ring
depends on it. Every bottom-anchored element moved to EDGE_BOTTOM together; none left behind.
The 6px over-reservation in CLUSTER_TOP_FROM_BOTTOM errs SAFE at both consumers (onboarding band
and escalation clamp both sit higher, i.e. further from live buttons).
REVIEWER RULED MY INSTINCT WRONG, correctly: leaving the onboarding beat at the `wallet` anchor
rather than adding a `ring` anchor was right. Static anchors get NO clamp — applyAnchor assigns
raw — so a right-anchored 220px card pointed at the ring lands 104px OFF the left edge at 320px
touch. The same instinct already put a card on the thumbstick earlier in this branch.
Fix round closed 5 items. The one that mattered: LedgerController's header claimed the ≡ was the
door and the plate was not — both false. THIRD occurrence in that same file; the first cost this
branch its worst bug (the "plate is the only interactive element" premise that left OpenLedger
with zero firing sites). Also corrected EDGE_BOTTOM's rationale, which was factually wrong
(EDGE is read as a side margin NOWHERE) though the decision was right for a better reason.
- ⚠️ OWNER GATE: the plate now SINKS TOUCHES and grows leftward. Capped at 100px, worst-case left
  edge is 238.8px at 568px landscape (clear) but **28px at 320px portrait** — near the
  thumbstick's territory in the bottom row. Portrait is not the default orientation and the plate
  shows ~2.35s per reveal, so this is a look-at-it item, not a blocker. The honest fix if it
  bites is the one that worked for the jump button: MEASURE the thumbstick, do not predict it.

### Task 6 — escalation halved + dismissable; SWITCH? confirmed
Task 6: complete. Commits f6ba5bf + 9ec9179 (fix round). 949 passed, gates clean.
Review: spec ❌ → fixed → spec met. Quality approved throughout.
IMPLEMENTER CAUGHT THE TRAP: the naive 154→77 halving does NOT close — content would be 53px for
74px of children. Rather than shipping overlapping labels (exactly the bug that reached the owner
on the previous branch) they re-derived ESCALATION_H = 98, the true floor.
**MY BRIEF'S GAP, caught by the reviewer:** I scoped the task to HEIGHT. The owner asked for "50%
smaller" and the frame was `UDim2.new(0.8, 0, 0, H)` — 80% of screen WIDTH, untouched. So the
footprint fell 36%, not 50%, and width was always the bigger lever: 675px of panel on an 844px
landscape to hold ~130px of content. Fixed with ESCALATION_W = 210.
Footprint: 390px phone 48,048 → 20,580 px² (−57.2%); 844px landscape 103,981 → 20,580 (−80.2%).
Both exceed the ask; the wider the screen, the bigger the win, because width was what dominated.
Note the reviewer marked spec ❌ while marking quality APPROVED — the right call, and it only
works because the brief and the design spec are separate documents. Judged against my brief alone
this would have passed clean.
Dismissal traced: one firer, one listener, sets the EXISTING declinedThisRound (no new field),
cleared on every ACTIVE reopen, and HudModel gates only `escalate` on it — throwing, sendAtLockout
and round scoring are untouched. Press feedback fires on MouseButton1Down independent of the click.
Clamp re-verified after the drop to EDGE_BOTTOM: 16.3px clear at H=354, 374.5px at H=1044.

### Task 7 — the result splash
Task 7: complete. Commits 81bd2e4 + 8438398 (fix round). 949 passed, gates clean.
Review (opus): spec ✅, quality APPROVED.
THE RISKY BIT HELD UP. `forfeited` depends on RevealResult reaching the client before
ProfileUpdate. The reviewer verified at the source that neither pushStats nor applyLocalResult
YIELDS, so both remotes queue in one server frame in that order; and separately that the drum
cannot consume pendingReveal early in the normal path (drumRest needs RevealTheater, fired one
line before the RevealResult loop). A 27-point loss genuinely prints 27. And if the ordering ever
failed the failure mode is a MISSING figure, never a wrong one — the right shape.
Note this is remote-vs-remote ordering to one client, which IS preserved. The codebase's known
hazard ([[roblox-remote-event-replication-race]]) is remote-vs-INSTANCE-replication, a different
guarantee. Worth keeping the distinction.
Generation guard traced through two-results-in-quick-succession: cannot strand the splash visible
or hidden. Spoiler gate confirmed — Splash:Fire appears exactly once, inside maybeShowReveal
behind its drumAtRest return, and cannot fire for a whiff/spectator/joiner because r.result is nil.
REVEAL_SAFETY still fires it if the drumRest cue drops.
Fixed: `0 points forfeited` (the MOST COMMON loss — after any loss, after banking, every first
loss) now reads "nothing was riding on that one"; `×1` → `streak ×1` so it cannot read as a
multiplier.
DELIBERATELY NOT FIXED, comment added so nobody "fixes" it: the first win fires both the splash
and the onboarding beat on one tick. That is NOT the bank case — there a toast and a card said
literally the same sentence in the same region. Here one celebrates and one teaches, in different
regions, and the splash is non-Active so it steals nothing.
- FOR TASK 9: pendingReveal is nil'd inside maybeShowReveal, so distribution/totalPlayers must be
  copied into a persistent `lastRound` there. And `r.pick` is captured NOWHERE since the SAFE
  headline was removed — spec §3 needs it for the band's five fields.

### Task 8 — resultSplash, the second preference
Task 8: complete. Commits ad735af + dea15b8 (fix round). 958 Luau + 211 server passed.
Review: spec ✅, quality APPROVED. All six seams verified by reading — including the Roblox
server's HudPrefs plumbing, which the MIRROR task's brief (retiring confirmThrows) had missed.
Naming it up front worked.
**THE ADVERSARIAL CHECK FOUND A HOLE IN WHAT IS CHECKABLE AT ALL, not a bug.** Sabotaging
SetHudPreference's merge base — the exact change that makes one switch silently reset the other —
left 211 server AND 949 Luau tests green. The rule lived in main.server.luau, a Roblox-runtime file
Lune never loads, and the Express suite does not touch Luau. So it sat in the one place neither
gate can see. The task verified the merge was right TODAY by reading it; nothing kept it right
through the next edit.
Closed with the pattern this branch has used twice already: extract the rule into a pure
src/shared module. HudPrefs.luau now owns DEFAULTS, merge(current, patch) (new table, boolean-only
overwrites, never mutates current) and fromProfile. main.server.luau calls it instead of inlining.
Sabotage now fails 4 of 958.
Worth remembering: a silently-resetting preference is close to undetectable in play — you toggle
one switch and the other quietly reverts some time later, and nothing ever fails.

### Task 9 — the ledger's LAST ROUND band
Task 9: complete. Commits 45cd23a + 09e390c (fix round). 962 Luau + 211 server passed.
Review: spec ✅, quality APPROVED.
Both Task-7 carryovers closed, plus a third the implementer found: without firing publishLedger()
from maybeShowReveal, the band would have shown the PREVIOUS round until an unrelated ProfileUpdate
happened along.
Layout audit clean: BODY_TOP literal gone, bodyTop()/heroTop() re-derive, the footer is
bottom-anchored so it stays reachable regardless of the band, and the hero sits at its original
HEADER_H on a fresh join.
LedgerModel.shares is genuinely ONE function with two call sites, and it renormalises against the
input's own total — so it yields 34/33/33 from either raw {1,1,1} or the server's pre-rounded
{33,33,33}, which only sums to 99. Naive rounding would have lost that point silently.
Fixed in the round: (1) the R/P/S bar wore the WIN/SAFE/LOSS triad while sitting DIRECTLY under a
result label using that same triad — a green "Rock" under a green "WIN" reads as "green means
winning". Now IVORY/TAN/AGED separated by VALUE not hue, which survives 14px. (2) the band would
have drawn a confident 34/33/33 for a round nobody played, because Settlement.ts returns a
placeholder {33,33,33} at totalPlayers==0. Hidden at the DISPLAY — the server placeholder has
other readers and settlement is not this branch's business.

## ALL 9 TASKS COMPLETE — proceeding to the final whole-branch review.

## FINAL WHOLE-BRANCH REVIEW (opus) + fix wave — COMPLETE
Fix wave 0952ab4. FINAL GATES, run by me: Luau 962 / stylua clean / selene 0 warnings;
server 211; tree clean; 18 commits c27e2ea..0952ab4.

**CRITICAL, and the most instructive failure of the whole session.** Task 9's LAST ROUND band
pushed the ledger's bodyTop() from 160 to 300, and nothing clamped the remainder. On an 844x390
landscape phone the body computed NEGATIVE; Roblox clamps AbsoluteSize to 0, so the body and all
three cards inside it rendered zero-tall. Every lifetime figure, the throws breakdown and the feed
became PERMANENTLY UNREACHABLE from the player's first reveal onward. The tab row also landed on
the preference switches.
Why nine reviews missed it: every one of them checked the band's INTERNAL arithmetic, which was
correct, rather than the panel's TOTAL vertical budget. The band fit; the panel did not.
Fixed by moving the band INTO the scrolling body as the first card of the LIFETIME stack, under a
UIListLayout — so it is content, not chrome, and can never starve anything. Body height restored
to 82.6 / 48.76 at the two phone sizes and improved to 430.8 on desktop. Hiding it on a fresh join
closes the gap for free, which absolute positioning would not have.
This also still honours the owner's "at the top of the ledger" — it is the first thing in the
ledger's content.

Also fixed: SplashController's header claimed the deleted hamburger was a door — the THIRD file in
two rounds to carry a false claim about the ledger's doors, and the first such claim cost this
branch its worst bug. The spec line it was copied from was corrected too. The plate's label could
bleed over the tape (AutomaticSize child in a capped parent with no clipping). Four stale comments.
And the two preferences were made symmetric — resultSplash's toggle rode a coincidence
(ProfileUpdate landing before drum rest) rather than republishing LedgerState like its sibling.

## OWNER'S STUDIO GATE — nothing here is settled by reading
1. The ledger on a phone after one round — the Critical's fix needs eyes.
2. Does the ring read as a ring? 36 segments, 3px thick, 44px diameter on touch.
3. The ring is a blank dark donut for ~5s of every round (TALLY + REVEAL + spin). Correct by the
   no-lying-about-time rule, but a lot of dead chrome in the most eye-catching element.
4. Does the ring invite a tap? The only teaching is one onboarding beat, and it fires on the first
   BANK — so a player who loses before winning is never told. SPEC-VS-PLAN DIVERGENCE worth the
   owner's ruling: spec §6 says "fired the first time a result lands".
5. Does the halved escalation still command attention? 210x98, −57% on a phone, −80% landscape.
6. The splash's felt duration: 2s + 0.4s fade.
7. Carried: the chosen-tile halo clears the ring by 1px; the ring's disc is outside applyContrast
   so it keeps its night value by day; the plate at 320px portrait sits 28px from the left edge.

## RING BACKING (owner's fourth gate) — commits 7f8b73a + 16f1af3
The ring read badly against the moving canyon. Owner's fix: a throw-button-sized backing behind it,
neutral and partly transparent; the ring shrinks to fit; the inner disc grows.
Geometry landed right first time — RING_INSET = 4, radius re-derived, and `RingTimer.segmentWidth`
carried the overlap guarantee automatically (7 vs 5.41 desktop, 4 vs 2.88 touch).
**COLOUR WAS WRONG AND I CAUGHT IT BEFORE THE OWNER DID.** The first pass used IVORY_DIM at 0.25 —
which is exactly what paintThrows uses for a DISABLED throw button (:543 "starts disabled", :686).
The ledger's only door would have rendered permanently greyed out, beside three buttons using that
same fill to mean "not pressable". Changed to WASHI at 0.3 — not arbitrary: it is precisely what
the hamburger used before Task 5 deleted it, so the ring inherits the clothes of the control it
replaced, and joins the plate/bank/escalation family.
Disc kept, with reasoning worth preserving: it shares the WASHI CONSTANT with the backing, so it
looks redundant — but transparencies COMPOUND. Backing 0.3 alone is ~70% opaque; the disc's 0.15
over it composites to 1 − 0.15×0.3 = ~95.5%. A real darkening for the digits' ground. The
compositing math is now an in-code comment so nobody re-derives it.

LESSON, and it is the shape of this whole session: the instruction was followed correctly and the
result was still wrong, because a palette constant carried a meaning the brief never mentioned.
Same shape as the ring's position, the escalation's width and the SWITCH? overlay — each time the
code did what was asked and the asking was incomplete.
