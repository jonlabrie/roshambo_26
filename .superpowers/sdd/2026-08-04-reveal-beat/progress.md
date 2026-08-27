# SDD ledger — plan: docs/superpowers/plans/2026-08-04-reveal-beat.md

Branch: `m4b-zendojo-art-pass`. Base at start: `4017264`.
Spec: `docs/superpowers/specs/2026-08-04-reveal-beat-design.md`

THE RULE: the drum is authoritative. Nothing reflects the world throw anywhere until drumRest.
THE OTHER RULE: the tape tile is NEVER dropped — it is the round's permanent record.

Five tasks:
1. Retract the early splash (delete, don't disable)
2. Server: revealSeconds 3 -> 5
3. RevealBeat.luau — the beat's timings, shared + tested
4. The ring's glyph becomes a fadeable CanvasGroup
5. Sequence the beat, incl. the collapse path

Pre-flight scan: no contradictions. Task 1 deliberately restores code Task 5 then moves again —
that is intentional, so the retraction and the resequencing read as separate diffs.

CONTEXT THAT CAUSED THIS ROUND: the owner watched several rounds and saw a black disc where the
world-throw glyph should be. Root cause found and fixed pre-plan (`9721960`): every ScreenGui here
runs in GLOBAL ZIndexBehavior (Instance.new's default) while the code is commented as if it were
Sibling, so the glyph's default-ZIndex-1 image layers rendered BEHIND the opaque ZIndex-4 disc.
It got past review because a reviewer asserted Sibling and I recorded it as verified, and because
I read `Visible = true` off the instances and reported the glyph as rendering. VISIBLE IS NOT PIXELS.

**Nothing here is verifiable by any automated gate.** Owner's Studio gate follows.
Do not push without telling the owner — this round changes a SERVER phase duration, so the
auto-deploy will change round pacing under any live session.

---
Task 1: complete — commit `6934d40`. Verified directly by the orchestrator (deletion task; the
  checks are mechanical). 980 Luau tests, stylua, selene clean. 253 lines deleted, 54 added.
  Greps clean for drumSettling / glideResidual / SPLASH_RESIDUAL / splashDone.
  EventBus.Splash:Fire appears exactly once; the implementer verified its restored position
  against the pre-round-four commit `73724e5` rather than by eye.
  KICK_OMEGA and the Hermite characterisation both survive — the latter now also records WHY the
  header was wrong before ("the smoothstep alone reads 72% where the real curve reads 83-88%").

Task 2: complete — commit below. Done directly, not dispatched: one config line plus a comment.
  server/src/index.ts revealSeconds 3 -> 5. 211 server tests pass.
  Checked for drift: nothing in the PWA (`src/`) reads the reveal length, and apiV1.test.ts's
  `revealMs: 3000` assertion is against its OWN fixture (revealSeconds: 3), so it is self-consistent
  and unaffected.

Task 3: complete — commit `19eacb7`. 984 Luau tests, stylua, selene clean.
  RevealBeat.luau: HOLD_SECONDS 2, FADE_SECONDS 0.4, TAPE_DELAY_SECONDS = HOLD + FADE = 2.4,
  RUNWAY_SECONDS 3.8 (MEASURED, not derived — kept as a literal with its provenance).
  Mutation confirmed: TAPE_DELAY = HOLD alone (tape landing mid-fade) fails the ordering test
  with "expected 2 to be 2.4". That assertion is the only automated thing in this whole round
  that can catch a regression in the beat.

Task 4: complete — commit `1f0a3f5`. 984 Luau tests, stylua, selene clean. Build verified directly.
  The ring's glyphs are CanvasGroups now: one GroupTransparency to fade (instead of two ImageLabels
  drifting apart at the edges), and the ZIndex hole is closed PROPERLY — a CanvasGroup composites
  its descendants as one element, so only its own ZIndex matters and the hand-lifted per-layer
  ZIndexes from the stopgap are deleted rather than left redundant.
  The white keyline survives: `Glyphs.renderGroup(box, sym, INK_CREAM, Color3.new(1, 1, 1))`.
  The two builders disagree on their outline default (render -> white, renderGroup -> core colour),
  so omitting that fourth argument would have silently flattened the glyph. Confirmed present.
  setRingGlyph is latched on the (symbol, fading) pair — render runs at 10Hz and an unlatched
  tween would be cancel-restarted ~every repaint and render static.
  Type updated Frame -> CanvasGroup at the declaration.
  Noted: aux.worldThrowFading is nil until Task 5, so the fade branch is dead until then.

Task 5: complete — commit `b42c60c`. The beat is sequenced. `landTape()` is the sole emitter and
  clears the flight record as it emits, so the tile lands exactly once on all five paths (normal,
  collapse-before-fade, collapse-mid-fade, collapse-after-landing, REVEAL_SAFETY release) plus the
  overlapping-rounds case, which `maybeShowReveal`'s defensive landTape() flushes before it
  overwrites the record. Generation counter verified: superseded delays cannot write over a newer
  round. `aux` contract updated in both files (main.client's was TWO fields stale).

FINAL WHOLE-BRANCH REVIEW (opus): fit for the gate, two Important findings — and the first one is
the most consequential thing found in this whole session.

  1. THE SAFETY FALLBACK HAS BEEN BEATING THE DRUM ON EVERY ROUND. `REVEAL_SAFETY = 3` was armed
     from RevealResult ARRIVING; the drum rests at max(strike + 1.45, revealArrival) + 2.0. Those
     are the same magnitude, and RoundCoordinator accepts a reveal fetched during TALLY, so the
     reveal can precede the strike. CONFIRMED EMPIRICALLY against my own earlier probe: RevealResult
     t=8.28s, ring glyph t=11.31s — 8.28 + 3.00 + one frame. Three consecutive rounds, all released
     by the FALLBACK, never by drumRest. So the glyph and splash have been appearing while the drum
     was still gliding — the exact spoiler this whole round exists to forbid — and Task 2 made it
     WORSE by giving the early release room to run.
     Fixed (`ece877b`): armed from `gongHit`, sized in DrumStep as SETTLE + 0.5 margin = 3.95s, or
     + STALL_MAX = 9.95s when the throw was not in hand at the strike. Backstop kept for a missed
     gongHit. TheaterController had the identical bug and is fixed the same way (`1b467ab`) — its
     own ACTIVE comment had admitted the race in prose for months.

  2. RUNWAY_SECONDS = 3.8 was measured from the WRONG EVENT (the fallback, not rest). Nominal
     arithmetic says the drum rests 5.45s into a 7s gap, leaving 1.55s — LESS than the beat's 2.4s.
     The comment now says plainly that the true runway is UNMEASURED and provisional until the gate
     (`9390787`). If it is short, the hold shortens.

  Minors fixed: the PWA's result overlay was a bare 3000ms tuned to the old reveal (`4cbbd88`);
  HammerController's period default now DERIVES 27 from the three phase constants instead of
  restating it (`79fdbe7`); BoardController's dead pre-rest "WORLD THREW" path carries a comment
  recording THE RULE so it cannot be revived without moving to drumRest.

ROUND COMPLETE. 10 commits, 4017264..79fdbe7. 986 Luau + 211 server tests, stylua, selene clean.
NOT PUSHED — and this round changes a SERVER phase duration, so the auto-deploy will change round
pacing under any live Studio session. Tell the owner before pushing.

OPEN, for the gate: whether the beat completes at all (see finding 2); whether the glyph now
actually renders (pixels, not Visible); and the ~1.4s of empty dark disc after the fade.
Known-deferred: both client files now duplicate strike tracking by design — LanternController is
the likely third consumer and the right trigger to extract it.
