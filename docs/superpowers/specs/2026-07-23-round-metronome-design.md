# Round Metronome — Design

**Date:** 2026-07-23
**Status:** Approved (brainstorm gate)
**Branch:** m4b-zendojo-art-pass

## Problem

The bell engine's client timing is reconstructed from event *arrivals*, and it fails
two ways:

1. **Two independent anchors.** The shu-moku's draw ramp anchors to the ACTIVE
   RoundUpdate's arrival; the cam re-pins itself on the dowel at each strike and
   free-runs between. The Roblox server polls Express `/state` every ~1–1.25 s and
   fires RoundUpdate only on *detected* phase change, so each anchor lands up to
   ~1.25 s late, independently, varying per round (the historical ±10° cam wobble).
2. **The measured clock locks wrong (the racing-wheel bug).** HammerController
   measures the round period once (ACTIVE→ACTIVE) and freezes it. But at Play start
   the coordinator's first poll fires RoundUpdate with the *current mid-round*
   phase, so the first "ACTIVE" sample is the join moment, not a round start. The
   measured "period" is the time remaining in the joined round (0–25 s); anything
   over the 5 s outlier floor locks the entire drive train at the wrong rate for
   the session. ~60% of Play sessions hit the bad window; a session that joins
   17.6 s into a round runs the machine at ~3.4× (observed live: wheel/shaft
   1.436 rad/s, cam 0.844 rad/s ⇒ a 7.4 s "round").

Rounds are a fixed, server-known length (ACTIVE 20 + TALLY 2 + REVEAL 3 = 25 s
today; ~60 s planned at launch). The client should *know* the schedule, not infer
it from event arrival times.

## Design

One sentence: chain the two clock syncs that already exist, publish each round's
absolute schedule once, and run every visual off that shared timeline as pure
clockwork; absorb all data lateness after the strike, at the drum.

Decided at the gate: **the bell always strikes on schedule** — if the reveal data
is late, the drum spins longer; the machine never waits.

### 1. Schedule pipeline (server → clients)

**Express `/state` (additive):** the payload gains
`durations: { activeMs, tallyMs, revealMs }` from the engine config it already
holds. Vitest-covered. Launch's 20→60 s change stays a single config edit.

**Roblox server (RoundCoordinator + main.server):** the coordinator already maps
Express time → local time via RoundClock (min-RTT / Cristian). Per poll it derives
the round's absolute schedule and converts it onto the `workspace:GetServerTimeNow()`
timeline (natively replicated to every client — the DayNightConfig/CycleEpoch
pattern). It publishes a **`RoundScheduleConfig`** Configuration in
ReplicatedStorage with attributes:

- `RoundId` (string), `RoundCount` (number)
- `StrikeAtServerTime` (number, GetServerTimeNow seconds) — the next bell strike,
  defined as reveal start = activeEnd + tally. The strike anchors the timeline
  because it is the one visually critical instant (cam cliff meets dowel), and
  TALLY is the natural grace window covering the reveal-data fetch.
- `PeriodSec`, `ActiveSec`, `TallySec`, `RevealSec` (numbers)

Publish policy: write on roundId change; mid-round, rewrite only if the freshly
computed schedule disagrees with the published one by > ~150 ms (min-RTT sync
refines over early rounds). No ticks, no new remotes; attribute replication also
hands late joiners the current schedule instantly.

### 2. RoundMetronome (pure shared module)

`roblox/src/shared/RoundMetronome.luau` — dependency-injected, Lune-tested; owns
all timing math. Controllers become thin readers.

- `setSchedule({ roundId, strikeAt, periodSec, activeSec, tallySec, revealSec })`
  — called on replicated-attribute change.
- `read(now)` → `{ drawP, camAngle, shaftOmega, nextStrikeAt }`
  - `drawP`: 0→1 across the period (today's ramp shape).
  - `camAngle`: constant ω = 2π/period, phased so the high point is on the dowel
    at `strikeAt`; the `CamPhaseDeg` knob survives as a fine offset.
  - `shaftOmega`: signed shaft rate for the `DriveOmega` publish.
- **Slew, not snap:** schedule shifts ≤ ~400 ms are absorbed by bending the rate a
  bounded few percent until re-converged (gears never visibly jump). Shifts > ~2 s
  (Express restart, new world) hard re-anchor: one visible resync, accepted.

### 3. Consumers

- **HammerController:** deletes the measured clock wholesale — `camOmega`
  measurement, `omegaLocked`, `lastActiveAt` draw anchoring, per-strike
  `anchorNet` re-pinning. Draw + cam read the metronome each Heartbeat; the strike
  fires when `now >= nextStrikeAt` (self-timed). Swing, `gongHit` at contact, and
  downstream VFX cues unchanged.
- **WheelController:** untouched; `DriveOmega` is now published from
  `shaftOmega`.
- **DrumController:** `gongHit` starts the spin as today; the glide additionally
  waits for `latestWorldThrow` to be present *for this round*, then lands the
  detent. "This round" is by construction: `latestWorldThrow` is cleared at each
  strike, and the one RevealTheater arrival between strikes is the current
  round's. Late data = longer spin; nothing else in the arena knows.
- **TheaterController:** reveal effects stay data-driven; it stops emitting
  `gongStrike` (Hammer self-times). Phase cues keep flowing for other listeners.

### 4. Failure modes

Rule: the machine never stops; data lateness degrades only the drum's settle time.

- **No schedule yet (fresh client):** rest pose until the first `setSchedule`;
  window is milliseconds (attributes replicate with the snapshot). No guessable
  fallback rate.
- **Express unreachable:** schedule stops refreshing; the metronome free-runs the
  last known schedule (strikes keep their cadence). The drum's existing
  stuck-guard covers missing reveal data. Recovery slews or re-anchors per §2.
- **Express restart / roundId discontinuity:** > 2 s shift → hard re-anchor.
- **Play start mid-round:** benign — the client reads the current schedule and
  lands mid-timeline at the correct rate/phase/strike time. The racing-wheel bug
  class is structurally gone.
- **Round length change (20→60):** arrives as new durations; clean re-anchor.

### 5. Testing

- `roblox/tests/RoundMetronome.spec.luau` (Lune): schedule mapping at known
  times; the cam high-point-at-strike invariant across arbitrary schedules; slew
  bounds (≤400 ms shifts never step the output; rate bend capped); the 2 s hard
  re-anchor threshold; free-run when updates stop; mid-timeline join correctness —
  including a regression encoding the racing wheel (join 17.6 s into a 25 s round
  → rate must be 2π/25, not 2π/7.4).
- Server (Vitest): `/state` `durations` shape + values from `EngineConfig`.
- Controllers stay thin and untested by convention; the live Play gate verifies
  wiring: strike lands on cadence, drum absorbs a delayed reveal, wheel rate
  steady across Play restarts.

## Out of scope

- PWA (own socket flow; no bell machine).
- Pick-lockout timing (already clock-synced via RoundClock; unchanged).
- Gearing ratios (wheel stays welded at 2× cam; at 60 s rounds it slows to a
  stately 30 s/rev).
