# SDD ledger — plan: docs/superpowers/plans/2026-08-04-round-clock-stage1.md

Branch: `m4b-zendojo-art-pass`. Base at start: `43b46b1`.
Spec: `docs/superpowers/specs/2026-08-04-round-structure-design.md` (§3, stage 1 of 4)

STAGE 1 ONLY. No wire change, no phase renames, no server code.

Three tasks:
1. RoundMetronome.read yields phase + secondsLeft (pure, tested)
2. main.client drives phase/countdown from the metronome; RoundUpdate becomes the corrector
3. Throws cannot open before the server's round does

WHY THIS IS SMALL: the timeline already exists. RoundMetronome is already pure, clock-agnostic,
slew-not-snap, fed by RoundScheduleConfig on the GetServerTimeNow clock, and already drives the
bell cam. It just never reported the phase, and only HammerController read it.

THE INVERTED FAILURE MODE (why task 3 exists): the phase used to arrive LATE, so throws opened late
and a player lost a second or two. A local timeline can arrive EARLY, and a pick made before the
server's round opens is buffered against a round that has not started — the server cannot be
corrupted, but the player's first tap can be silently swallowed. The gate must fail LATE, never
early.

**Nothing here is verifiable by any automated gate for tasks 2-3.** Owner's Studio gate follows.
The one-line acceptance test: DOES A FRESH COUNTDOWN START AT 20? 18 means it is still on the poll.

---
Task 1: complete — commit `5fab0c9`. 993 Luau tests, stylua, selene clean.
  RoundMetronome.read now returns `phase` and `secondsLeft` alongside the cam fields, derived from
  the roundStart/period it already computed — no second derivation.
  Half-open boundaries: a phase owns its start instant, not its end.
  ALL THREE MUTATIONS produced real failures (`<`->`<=` broke 3 tests; secondsLeft measuring the
  round's end instead of the phase's broke 2; swapping the ACTIVE/REVEAL labels broke 4).
  Diff is PURELY ADDITIVE — zero deletions in module and spec — so HammerController's inputs
  (drawP, camAngle, omega, prevStrikeAt, nextStrikeAt) and the 6 pre-existing tests are untouched.

Task 2: REVERTED — `582abfe` committed, `633ca8a` reverts it. Tree clean, 993 tests green.

  THE PLAN'S PREMISE WAS WRONG, AND THE IMPLEMENTER FOUND IT.
  I diagnosed "a fresh countdown reads 18 instead of 20 because the phase arrives ~2s late via
  the poll". False. The old countdown was:
      local function secondsLeft(): number
          if phase ~= "ACTIVE" then return 0 end
          if not lockoutAt then return UNSYNCED_SECONDS end
          return math.max(0, lockoutAt - os.clock())
      end
  It is TIME TO LOCKOUT, computed LOCALLY off a synced lockoutAt. 18 = 20 − the 2s lockout. It was
  never poll-delayed and it was never wrong — it counts down to the moment you can no longer change
  your throw, which is exactly why the buttons die when it hits 0 (the owner described precisely
  this and I read it as a symptom).

  WHAT TASK 2 BROKE: HudModel uses that ONE number for three jobs — the ring, `throwsEnabledFor`
  (`secondsLeft > 0`) and `sendAtLockout` (`secondsLeft > 0.5`). Redefining it as time-to-round-end
  left throws open 2s past the lockout and fired the send 1.5s late, so RoundCoordinator answered
  LOCKED and EVERY HELD PICK WAS SILENTLY DISCARDED. Caught and flagged rather than shipped.

  WHAT IS ACTUALLY LATE: only the phase TRANSITION, by ~1s of poll — the instant the ring appears
  and disappears. Not the number in it. So Stage 1's real value is about a second on the transition,
  not two on the countdown.

  KEPT: Task 1 (`5fab0c9`). RoundMetronome.phase/secondsLeft is additive, tested, and simply
  unconsumed for now.

  OPEN FOR THE OWNER: `secondsLeft` is overloaded — one number serving the display, the gate and
  the wire. Showing time-to-lockout is arguably the CORRECT display (it is the deadline that
  matters to a player). If so, Stage 1 narrows to phase-transition timing only and this number is
  never touched.
Task 2R: complete — commit `77c2775`. 998 Luau tests (was 993), stylua, selene clean.
  RoundMetronome.LOCKOUT_SECONDS = 2 is now THE constant; Reading gains `lockoutIn`.
  THE CLOCK TRAP WAS SOLVED BETTER THAN I SPEC'D IT: `lockoutIn` is a DURATION, not an instant, so
  it belongs to no timeline. read() is fed workspace:GetServerTimeNow() (the schedule's clock) and
  one line later `lockoutAt = os.clock() + reading.lockoutIn`. No GetServerTimeNow value ever
  reaches lockoutAt, so `secondsLeft()` is BYTE-IDENTICAL — confirmed by diff, 2 deleted lines in
  the client and neither in that function. The implementer explicitly rejected moving both sides to
  server time because it would have meant editing the function whose meaning must not change.
  Brief deviation, correct: RoundCoordinator requires nothing (the codebase's DI rule), so
  main.server.luau injects lockoutMs instead, with a test pinning the test-only fallback to the
  shared constant.
  Also necessary: the round-ended edge moved to a new `serverPhase` — against the now-leading local
  phase it would never have fired, silently killing the escalation backoff.

Task 3R: complete — commit `f642dbd`. 998 Luau tests, stylua, selene clean.
  Six executable lines: `throwPhase()` returns serverPhase when the local timeline says ACTIVE but
  the server has not confirmed, else the local phase; buildInputs passes it.
  THE SAFETY ARGUMENT IS STRUCTURAL, not asserted: the condition reduces to the pre-timeline open
  condition INTERSECTED with the timeline's agreement — a strict subset — so throws can never open
  earlier than they did before 77c2775.
  And the held pick still reaches the wire, also structurally: sendAtLockout returns nil for an
  ACTIVE phase with time left and the pick for ANY non-ACTIVE phase, while throwPhase only ever
  substitutes non-ACTIVE for ACTIVE. So it can turn a nil into the pick, never the pick into a nil.
  Suppression is unreachable. This is the failure that discarded every held pick last time.
  secondsLeft() and lockoutAt untouched.

STAGE 1 COMPLETE. 998 Luau + 211 server tests, tree clean. NOT PUSHED.
  Net: `5fab0c9` (metronome knows the phase) + `77c2775` (lockout derived locally) + `f642dbd`
  (the guard). One attempt built and reverted in between, for the right reason.

OPEN FOR THE OWNER'S STUDIO GATE:
  - throws should now open ~1s earlier, at the true round boundary rather than on poll discovery.
    THE TEST: tap the instant the ring reappears. It must register, or be refused by a dim glyph —
    never light up and then go dark.
  - the countdown still starts at 18 and still counts to the LOCKOUT. That is correct and was never
    the bug; do not read 18 as a regression.
  - known walk-back (Task 3R concern 1): the gated phase also rides HudState, so the RING now
    latches when throws open rather than up to a poll earlier. Still starts at 18 and depletes
    correctly, but it gives back part of 2R's timing win for the ring specifically. Decoupling it
    needs a HudModel field and a HudController edit — deliberately out of this stage.
  - a LATE local timeline can still send after the server's lockout (arrived with 77c2775, not
    introduced by the guard).

NEXT: stages 2-4 of the round-structure spec, each with its own plan — push transport, the
OPEN/LOCK/REVEAL restructure, then the ceremony.
