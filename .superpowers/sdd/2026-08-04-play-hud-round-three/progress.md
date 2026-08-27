# SDD ledger — plan: docs/superpowers/plans/2026-08-04-play-hud-round-three.md

Branch: `m4b-zendojo-art-pass`. Base at start: `1964b73`.

Spec: `docs/superpowers/specs/2026-08-04-play-hud-round-three-design.md`

Six tasks:
1. The bank row gives back 6px (HudLayout + HudController + OnboardingController)
2. RingTimer stops counting segments and starts measuring a sweep (pure)
3. HudController draws the ring as a pie
4. The SWITCH -> UNDO rename, in the shared model
5. The SWITCH -> UNDO rename, in the client
6. UNDO? covers the button, and lasts long enough to read

Pre-flight scan: no task contradicts another or the Global Constraints. Task 1 pins
`BANK_H == 36` as a literal and Tasks 4/5 add no new tests (they are renames); both are
deliberate and explained in the plan text.

**Nothing in this round is verifiable by any automated gate.** Owner's Studio gate follows the
last task. Do not push without telling the owner — every push to this branch auto-deploys the
dev App Runner service under their live session.

---
Task 1: complete — commit `f0eee55`. Spec ✅, quality approved, no fix rounds.
  BANK_H 40->36; BANK_GAP is now the actual gap in all three call sites; OnboardingController's
  three anchors route through CLUSTER_TOP_FROM_BOTTOM and four stranded locals were deleted.
  The forward-reference trap was caught by the implementer (declaration moved to :79-81).
  964 Luau tests, stylua clean, selene 0 warnings. Reviewer re-ran all three gates itself.
  Reclaimed exactly 6px: (40-36) + (10-8).

Task 2: complete — commit `6ff8df9`. Spec ✅, quality approved, no fix rounds.
  RingTimer: SEGMENTS/lit/angleAt/segmentWidth deleted (pinned as nil by test); added
  MIN_SWEEP_DEGREES=6, sweepDegrees, sweep. isWarning byte-identical.
  BOTH mutations reproduced by the reviewer: MIN_SWEEP_DEGREES->0 fails the 2 floor tests;
  `theta < 180` fails the half-turn test. Neither is vacuous.
  Reviewer INDEPENDENTLY re-derived the half-disc geometry and agrees: a half-disc at
  UIGradient.Rotation R shows the clockwise arc [R-180, R] from the top. No angle paints wrong.
  970 Luau tests, stylua clean, selene 0 warnings.
  KNOWN, EXPECTED, LEFT BROKEN FOR TASK 3 — HudController.client.luau still calls the deleted
  members at 5 sites: :919 (segmentWidth, SEGMENTS), :952, :953, :962 (angleAt, SEGMENTS),
  :1354 (lit, SEGMENTS). :919 runs at module load, so the client errors on require until Task 3.

Task 3: complete — commit `f2f32a2`. Spec ✅, quality approved, no fix rounds.
  The ring is now track circle + half A + half B + opaque disc, ZIndex 1/2/3/4 (explicit,
  load-bearing) with the readout at 5. RING_INSET 4->3. Geometry confirmed against the spec
  table: touch 44->OD 38->disc 32; desktop 76->OD 70->disc 60. Disc BackgroundTransparency 0.
  Digits GothamBold 20/34. Zero references to the deleted RingTimer members anywhere.
  Reviewer hand-walked the paint in both branches and re-derived Rotation = a + 180 itself:
  the ring DEPLETES, it does not fill. Nothing inside the ring is Active.
  970 Luau tests, stylua clean, selene 0 warnings.

Task 3: minor (deferred): the track circle and both half-discs are unnamed
  (HudController.client.luau:990-992) — Studio's Explorer shows three indistinguishable
  `Frame` children under RoundRing. No player-visible effect; costs 3 lines. FOR THE FINAL WAVE.

Task 3: FOR THE OWNER'S STUDIO GATE (nothing here is checkable by any gate):
  - the 0.4999->0.5 gradient step is a sub-pixel ramp, not a true step. Worst case is
    ringFrac = 0 while secondsLeft <= ESCALATE_AT (TALLY/REVEAL): half A is painted RING_HOT
    and fully covered, so a visible seam there would be a RED hairline down the diameter of an
    ostensibly empty ring. Lever: narrow to 0.49999. Do NOT collapse to one keypoint —
    NumberSequence interpolates.
  - whether UIGradient.Transparency cuts cleanly against a 0.5-scale UICorner (watch the arc's
    outer edge near the cut for a chewed or squared boundary).
  - "20" at 20px on a 32px disc is the tight case; ringDisc does not clip, so overflow spills
    onto the pie rather than truncating.
  - the final second: MIN_SWEEP_DEGREES = 6 is ~2px along a 38px phone ring. Does it survive
    antialiasing, or does the ring read as empty while the buttons are still live?

Task 4: complete — commit `e6c78bd`. Spec ✅, quality approved, no fix rounds.
  Pure rename in HudModel + spec: switchPrompt->undoPrompt on all three exported types,
  SWITCH_PROMPT_SECONDS->UNDO_PROMPT_SECONDS (VALUE STILL 1 — Task 6 changes it),
  switchPromptExpired->undoPromptExpired. All mechanic comments now say UNDO and are still true.
  The settings-toggle sense of "switch" (spec :115 "the preference switch") correctly left.
  970 Luau tests, stylua clean, selene 0 warnings.
  LEFT BROKEN FOR TASK 5 — main.client.luau: switchPrompt/switchPromptAt locals, the applyTap
  call, switchPromptExpired. HudController: switchPill/switchLabel/setSwitchPrompt,
  view.switchPrompt reads, the literal "SWITCH?" and several comments.

Task 5: complete — commit `73724e5`. Spec ✅, quality approved, no fix rounds.
  Rename carried into main.client.luau and HudController.client.luau. Reviewer independently
  reconciled EVERY view.X read in render against HudModel.View's actual return table — all nine
  match, no silent-nil hazard. All five unrelated "switch" senses correctly left.
  The pill's Size/TextSize/MaxTextSize/ZIndex/corner/stroke and the "SWITCH?" literal are
  byte-identical, as intended — they belong to Task 6.
  970 Luau tests, stylua clean, selene 0 warnings.

PLAN DEFECT FOUND BY THE IMPLEMENTER (mine, not theirs): Task 5's Step 3 verify grep included a
  bare `SWITCH?`, which cannot be empty while the display literal is still SWITCH? — that literal
  is deliberately Task 6's. The implementer followed the narrower dispatch list and flagged the
  conflict rather than silently picking one. Task 6's own grep resolves it.

Task 6: complete — commit `c447ed2`. Spec ✅ (adjudicated below), gates green.
  UNDO_PROMPT_SECONDS 1->2. undoPill.Size = (BTN_W, BTN_H), corner 6->8, Text "UNDO?",
  MaxTextSize 13->22, GothamBold kept. `Active` is never assigned on undoPill — verified
  directly by the orchestrator, not only by the implementer.
  970 Luau tests, stylua clean, selene 0 warnings.

  TWO CONCERNS RAISED, BOTH ADJUDICATED AS DEFECTS IN MY INSTRUCTIONS, NOT THE CODE:
  a) `grep -rn "SWITCH"` can never be empty: LedgerController:712-867 uses SWITCH_W / SWITCH_H /
     SWITCH_KNOB for the preference TOGGLE SWITCHES — the unrelated settings sense. Correctly
     left. My verification grep was over-broad; the narrow `SWITCH?` grep IS empty.
  b) Task 4's history note contained the literal old word, which my Step 7 grep would have
     flagged. The implementer reworded it to "the previous word described something this button
     has never done". Read it: still true, still explains the why. ACCEPTED, no churn.

FINAL WHOLE-BRANCH REVIEW (opus): fit for the owner's Studio gate. NO Critical, NO Important.
  Verified across seams no task-scoped review could see: the layout stack and the onboarding safe
  band still describe the same skeleton at both tiers (card clearance above the bank button is
  unchanged at 14px static / 30px clamped); the ring still sits in its slot without touching the
  buttons or tape; zero dangling RingTimer references; the rename has no silent-nil seam across
  its two commits; the ring DEPLETES rather than fills; the whole UNDO gesture traced end to end.
  Four Minor findings, all prose/naming.

FINAL FIX WAVE — commit `9a18224`, re-reviewed clean. All four addressed, new prose verified TRUE:
  1. HudModel:137 "one-second question" -> two-second (a cross-commit seam: Task 4 renamed the
     function, Task 6 changed the value, neither owned the line).
  2. HudController:578/610 sizing rationale cited the OLD pill's 36px/68px content boxes; the
     pill has no padding now, so the real boxes are 44/76.
  3. paintThrows's `prompted` branch is fully occluded by the opaque full-button overlay. Branch
     DELIBERATELY KEPT as the fallback if the pill is ever shrunk or made translucent; comment
     now says so, and says nobody has seen that paint since 2026-08-02.
  4. The pie's layers are named Track / SweepA / SweepB (Disc already was). At rest Track and
     SweepB are the SAME colour, so the Explorer could not tell them apart — and two of the
     owner's own gate checks need exactly that.

ROUND THREE COMPLETE. 7 commits, 1964b73..9a18224. 970 Luau tests, stylua clean, selene 0.
NOT PUSHED — pushing auto-deploys the dev App Runner under the owner's live Studio session.
