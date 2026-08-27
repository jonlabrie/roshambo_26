# SDD ledger — plan: docs/superpowers/plans/2026-08-04-play-hud-round-four.md

Branch: `m4b-zendojo-art-pass`. Base at start: `6d65959`.

Spec: `docs/superpowers/specs/2026-08-04-play-hud-round-four-design.md`

Five tasks:
1. The ring's digits sit up, and UNDO becomes a card
2. RollingNumber scales with the distance, and turns its easing over
3. The counters leave the heartbeat  <-- LOAD-BEARING: without it Task 2 makes things WORSE
4. The payoff draws the eye
5. The splash lands with the drum

Pre-flight scan: one DELIBERATE cross-task break — Task 2 deletes `RollingNumber.DURATION` while
`HudController` still reads it, and Task 3 repairs it. The Lune harness never loads client files,
so the suite stays green throughout and cannot flag it. Recorded here so no reviewer treats it as
a defect of Task 2. No other contradictions found.

**Nothing in this round is verifiable by any automated gate.** Owner's Studio gate follows.
Do not push without telling the owner — every push to this branch auto-deploys the dev App Runner
service under their live session.

---
Task 1: complete — commits `aede666` + fix round 1 `7f013f7`. Spec ✅, quality approved after one
  fix round. 970 Luau tests, stylua clean, selene 0 warnings.
  Ring digits: AnchorPoint (0.5,0.5) + Position y -COUNT_NUDGE, where
  COUNT_NUDGE = max(1, round(TextSize * 0.06)) -> 2 desktop / 1 touch. TextSize is assigned at
  :1042, the nudge reads it at :1053 — no forward reference. The glyph box (:1061) is
  byte-identical: it is geometric artwork and was already centred.
  UNDO: BackgroundColor3 WASHI -> IVORY, TextColor3 INK_CREAM -> INK. Size, corner 8, ZIndex 4/5,
  the SEL_BLUE stroke, TextScaled and MaxTextSize 22 all untouched. `Active` still never assigned.

  FIX ROUND 1 (Important) — the repaint falsified a comment ROUND THREE's fix wave had just
  written: paintThrows's occluded `prompted` branch said "undoPill is opaque WASHI". Not stale
  trivia — the comment instructs a maintainer to look at that branch first if the pill is ever
  shrunk or made translucent, and the branch's own fallback paints IVORY. So the contrast it was
  built to provide is now IVORY-on-IVORY. Comment corrected AND the consequence recorded; the
  branch's paint values deliberately left alone (it is unreachable today; redesigning it is not
  this round's job). Verified by reading the full 5-line diff rather than dispatching a reviewer.

Task 2: complete — commits `2558f73` + fix round 1 `6684ada`. Spec ✅, quality approved.
  RollingNumber: DURATION deleted (pinned nil by test); added MIN_DURATION 0.4, MAX_DURATION 2.5,
  SCALE_CAP 10000, durationFor(delta). Easing ease-out -> smoothstep.
  Curve recomputed INDEPENDENTLY by the reviewer and matches the module's own comment:
  0 -> 0.4, 1 -> 0.558, 30 -> 1.183, 300 -> 1.701, 3000 -> 2.226, 10000+ -> 2.5.
  All three mutations re-run by the reviewer, not taken on trust. math.abs IS load-bearing:
  without it math.log(0) yields -inf in this runtime (not an error), so a negative delta would
  silently produce -inf rather than failing loudly.
  979 Luau tests, stylua clean, selene 0 warnings.

  FIX ROUND 1 (found by the implementer, a defect in MY plan text): the "settles" easing test used
  bounds (>75, <95) at t=0.75, and quadratic ease-out returns 94 there — so it passed under BOTH
  curves and could not fail under the change it existed to detect. Tightened to < 90, which sits
  between smoothstep's 84 and ease-out's 94 with margin either side. Mutation re-run: all three
  easing tests now fail. The sibling "winds up" test already discriminated (16 vs 44 at t=0.25).

Task 2: minor (deferred): RollingNumber.luau:9-10, the module header still says the caller
  supplies "elapsed fraction of DURATION" — the constant this task deleted. FOR THE FINAL WAVE.

  LEFT BROKEN FOR TASK 3 — HudController.client.luau:246,
  `local t = (os.clock() - c.startedAt) / RollingNumber.DURATION`. The only functional reference.

Task 3: complete — commit `47bdadd`. Spec ✅, quality approved. 979 tests, stylua, selene clean.
  paintCounters (:938) is now the ONE place the plate line and bank figure are painted; render
  (:1369) owns only the targets (mirrors written at :1386-1389, read by the driver, nowhere else).
  RunService added at :42. RenderStepped at :964 is check-then-paint, verified: the frame that
  crosses the line still enters the handler, valueAt CLAMPS t and pins the endpoint exactly, and
  startedAt is cleared only AFTER c.displayed is assigned — so the final frame lands the exact
  value. Reversed, every count would rest one step short of the truth, permanently.
  Per-leg duration stored on the Counter, computed AFTER c.from = c.displayed, so an interrupted
  count continues from what is on screen.
  setBank's guard VERIFIED INDEPENDENTLY to hold at frame rate: `if want == pulsing then return`
  sits ABOVE every tween touch (the earlier regression had cancel/restart above its guard).
  potPulses drops on the same tick pot hits 0, so `want` flips once and the whole drain
  early-returns. `visible` cannot flicker — counterPot is frozen between renders and displayedPot
  is monotonic within a leg.

Task 3: IMPORTANT FINDING, CARRIED INTO TASK 4 (not a defect of this diff — a seam the round
  opened): PLATE_HOLD = 2 (:298) vs RollingNumber.MAX_DURATION = 2.5. revealPlate is armed by the
  MODEL change, so the hold and the count start on the same tick, and the count is no longer
  capped at 0.5s. Any delta above ~1120 outlives the hold. At 6561 (eight straight wins, the
  biggest payoff in the game) the 2.35s count lands its final total on the exact frame the plate
  reaches full transparency. The feature's whole point is invisible in its best case.

Task 3: minor (not worth acting on, reviewer's judgement): bankButton.Text rebuilt per frame
  during a points-only count (~130 identical string allocations). Roblox skips the property write
  when equal, so no re-layout — GC churn only, bounded at 2.5s.

Task 4: complete — commits `27f29b1` + `f92685a` + fix round 1 `8db4177`. Spec ✅, approved.
  979 tests, stylua clean, selene 0 warnings.
  PIECE 1: setCelebrating (latched) lifts the plate's existing GOLD stroke and turns the figure
  gold while the balance climbs. The plate only — the bank button is draining and must not
  celebrate.
  PIECE 2: PLATE_HOLD 2s could not outlive a 2.5s count. Now max(PLATE_HOLD, remaining + 0.6).
  A 6561 bank (eight straight wins) counts 2.404s, holds 3.004s, and the landed total sits fully
  opaque for 0.600s. Before: the plate hit full transparency 0.054s BEFORE the number arrived.
  Small moves unchanged — everything at or below a 27-point delta holds exactly 2.000s as before.

  FIX ROUND 1, four items, all verified correct:
  a) IMPORTANT, and MY brief caused it — setCelebrating keyed on the counter MOVING, not RISING.
     A purchase (teahouse, deck, portal, decoration) lowers the balance, so spending 500 points
     then playing one round made the plate swell gold while the number counted DOWN — exactly
     what Piece 1's own comment forbids. Now `and pointsCounter.target > pointsCounter.from`.
     A decrease still reveals and still gets the extended hold; only the gold is suppressed.
     Verified robust across an interrupted count, because tickCounter re-keys `from` to the
     DISPLAYED value, so the test always means "this leg is rising".
  b) a one-frame rim pop on the FIRST bank: revealPlate's direct write was overridden by the
     still-running celebrate tween, which had captured its start value at Play(). Fixed with a
     tween handle + PlaybackState check rather than a cancel — cancelling only the rim would
     leave the label still easing, half a gesture. Reviewer traced a third case (cancelled
     tween) neither of us listed and showed it unreachable: only startPlateFade competes for
     that property and it cannot fire inside the 0.15s celebrate window.
  c) the construction site hardcoded the values the new constants named, 52 lines above them.
     Hoisted and passed.
  d) join-time 0 -> balance count (up to 2.5s, and after fix (a) it would have been GOLD, so a
     new player's first look at their wallet would celebrate nothing). All three counters now
     seed on the first render off the same nil-test the reveal guard uses.

Task 4: minor (deferred): the ordering comment in render says revealPlate must follow
  paintCounters for the plateHoldSeconds reason, but not for the SECOND reason — revealPlate's
  PlaybackState guard also depends on it. Someone making the hold reorder-tolerant could break
  the rim guard with no warning from that comment. FOR THE FINAL WAVE.
Task 4: minor (latent, unreachable today): plateHoldSeconds ignores the streak counter. A streak
  delta can never exceed ~1113, so it cannot outlive the hold. Asymmetry, not a defect.

Task 5: complete — commit `0d3dec5`. Spec ✅, approved with findings. 982 tests, stylua, selene clean.
  DrumStep.SPLASH_LEAD_SECONDS = 0.7; DrumController fires a new `drumSettling` cue once per glide;
  main.client splits the gate — the SPLASH releases on drumSettling (2.75s), everything that names
  the WORLD's throw (tape badge, lastRound, revealedWorldThrow, the first-win beat, and the
  pendingReveal consume) still waits for drumRest (3.45s). Verified unmoved.
  Latch resets at DrumController :164 and :234. The reviewer confirmed the implementer's subtle
  point: RoundUpdate's stall guard (:213-227) force-lands the drum to "hold" WITHOUT passing the
  spin branch, so only the :234 gongHit reset covers that route.
  Wallet staleness checked against the SERVER, not assumed: RevealTheater (which unblocks the
  glide) fires in the same loop iteration as RevealResult and ProfileUpdate("local"), so
  drumSettling lands >= 1.3s after the wallet data. Firing earlier cannot beat it.

Task 5: FOR THE OWNER — a design question the review surfaced, NOT a defect:
  The brief's acceptance test measured FRACTION OF ANGULAR TRAVEL (>80%). That is not the same
  as "the correct symbol is in the window". Computing the RESIDUAL ANGLE at the splash instant:
    best-case landing  28.1 degrees remaining, still turning at  80 deg/s
    worst-case landing 53.4 degrees remaining, still turning at 142 deg/s
  Facets are 30 degrees apart and each carries a DIFFERENT symbol. So at 0.7s the window is
  showing a facet 1-2 positions off the detent — the WRONG glyph — and the correct one only
  dominates 0.19-0.34s LATER. On a LOSS the splash names the outcome while the drum still reads
  a different throw. That is the spoiler the gate exists to prevent, compressed to a third of a
  second. SplashController sets TextTransparency directly with no fade-in, so nothing swallows it.
  0.45-0.50s is the lead at which the correct facet is genuinely in the window (still 0.45s
  earlier than today). MY chosen number and MY acceptance criterion; the implementer computed
  both correctly. Owner's call.

Task 5: minor (FOR THE FINAL WAVE): DrumStep.luau:39-40 says "smoothstep ... ~88%" while its own
  test at DrumStep.spec.luau:62-65 proves it is a HERMITE and that the smoothstep alone reads 72%.
  The module's own doc misdirects the next person who retunes the lead. Also ~88% is best-case
  only; typical/worst is 83%.
Task 5: minor (FOR THE FINAL WAVE): the test hardcodes DRUM_KICK = 4, a CLIENT constant that is
  also live-overridable via the DrumKick stage attribute. Not merely stale if it changes — the
  assertion INVERTS: at omega=1 the worst case is 0.780 and the test FAILS. Move DRUM_KICK into
  DrumStep beside SPIN_SECONDS/GLIDE_SECONDS, which were moved there for exactly this reason.
Task 5: minor (FOR THE FINAL WAVE): main.client.luau:301 is a 185-char comment line, a botched
  wrap; every other line wraps at <=109 and stylua does not reflow comments.

FINAL WHOLE-BRANCH REVIEW (opus): found ONE CRITICAL that no task-scoped review could see, plus
  two Important seams that are Studio judgement calls.

FINAL FIX WAVE — commits `339d0dd` + `a3da900`. Verified directly by the orchestrator.
  CRITICAL: Task 4's join-time seed did not work. It keyed on `lastPlatePoints == nil` — a
  FIRST-RENDER test — but main.client's 10Hz loop publishes from script load while `wallet` is
  still all zeros, and the real profile only arrives after an HTTP round-trip to App Runner.
  So the seed captured 0, and the real balance landing was a RISING count: every join opened
  with the plate revealing, gold rim lifted, figure gold, racing 0 to the player's lifetime
  balance. ~3.5s of celebration for a payoff that never happened, on frame one, for everyone.
  Fixed by carrying main.client's existing `profileSeen` in `aux` (a render-only wiring fact,
  same class as `timerKnown` — HudModel.view derives nothing from it) and latching
  `countersSeeded`. `seededNow` also suppresses the plate's reveal on the arrival render.
  If the profile never arrives nothing is stuck: tickCounter is not gated on the seed.
  ALSO: DrumStep's header corrected (Hermite, 83-88%, and the residual-vs-travel distinction
  recorded); DRUM_KICK moved into DrumStep as KICK_OMEGA so the test cannot be a hostage to a
  client constant that a stage attribute can override; the 185-char comment re-wrapped.

ROUND FOUR COMPLETE. 11 commits, 6d65959..a3da900. 982 Luau tests, stylua clean, selene 0.
NOT PUSHED — 23 commits unpushed; pushing auto-deploys the dev App Runner under the owner's
live Studio session.

TWO OPEN DECISIONS FOR THE OWNER (both recorded above in full):
  1. SPLASH_LEAD_SECONDS = 0.7 leaves a 0.19-0.34s window where the drum shows a neighbouring
     facet while the splash names the result. 0.45-0.50 does NOT fix it (worst case still 28
     degrees off); a safe FIXED lead is ~0.36s, which barely beats today. The real fix is to
     trigger on RESIDUAL ANGLE rather than the clock — variable 0.36-0.53s, correct in every
     case, and robust to a DrumKick retune in a way no constant can be.
  2. Two Studio judgement calls: the bank drain can finish ~0.4s before the balance stops
     climbing if the player banks DURING the pot's own count-up; and on a big win the splash
     prints the true pot while the button beneath still shows the counting figure.

STILL DEFERRED, all judged "can wait": RollingNumber's header naming the deleted DURATION; the
render ordering comment's second reason; plateHoldSeconds ignoring the streak (unreachable);
bankButton.Text's per-frame rebuild (bounded, no re-layout).

OWNER'S RULING on open decision 1 — "trigger on angle, not clock". Spec §2 amended (`69f2c97`),
implemented in `743ff38`. SPLASH_LEAD_SECONDS DELETED.
  DrumStep gains SPLASH_RESIDUAL_RADIANS (derived as half a facet from the module's own FACES, so
  it cannot drift) and glideResidual(d, omega, s) — the Hermite residual, pure and Lune-tested.
  DrumController fires drumSettling the first frame the residual falls within half a facet, using
  the LIVE omega, so a DrumKick stage-attribute override stays correct where a constant could not.
  Measured lead: 0.512s at the shortest travel, 0.359s at the longest. Splash lands 2.94-3.09s
  (was 3.45s before the round, 2.75s with the fixed lead). Residual at the cue is exactly 15.000
  degrees in both cases — half a facet — so the window can NEVER show a neighbouring symbol.
  Both settlingFired resets kept, including the gongHit one that covers the stall-guard force-land.
  Three comment-only edits outside the named files (main.client x2, EventBus x1) asserted "~0.7s"
  and were false; corrected. No code changed there — verified by diff.
  985 Luau tests, stylua clean, selene 0 warnings.
