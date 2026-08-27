# Task 2R report — the lockout instant comes from the timeline, not the poll

Status: **complete**. Gates green, tree otherwise clean.

## Gate output

```
$ cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
$ lune run tests/run
998 passed, 0 failed, 998 total          (993 before; +5 new)
$ stylua --check src tests tools
(no output — clean)
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

Diff: 232 insertions, 20 deletions across 5 files.

| file | ins | del |
|---|---|---|
| `roblox/src/shared/RoundMetronome.luau` | 18 | 0 |
| `roblox/tests/RoundMetronome.spec.luau` | 79 | 20* |
| `roblox/src/server/RoundCoordinator.luau` | 19 | 3 |
| `roblox/src/server/main.server.luau` | 5 | 0 |
| `roblox/src/client/main.client.luau` | 131 | 2 |

\* the spec's deletions are a pure **move**: `m27()` was a local inside the phase `describe`; it is
now at file scope so the lockout block reuses the identical 27s fixture rather than declaring a
second one. No assertion changed.

The client's only two deleted lines are the `roundEnded` edge condition and the
`lockoutAt = ...secondsToLockout` assignment — **neither is in `secondsLeft()`**.

## Step 1–2: the tests failed first

All five new tests failed against the un-implemented module (`expected nil to be 2`,
`attempt to perform arithmetic (sub) on nil and number`, ×3 `expected nil to be 0`), then passed.

Mutation checks on the implementation (`src/shared/RoundMetronome.luau:127-130`):

| mutation | result |
|---|---|
| A — drop the lead: `activeEnd - elapsed` | **2 failures** (`toBeCloseTo(18)`, `toBeCloseTo(1)`) |
| B — allow negative: `math.max(0, …)` → `math.min(999, …)` | **1 failure** (zero-through-the-window) |
| C — remove the `if phase == "ACTIVE"` gate | **0 failures — semantically equivalent** |

C is not a test gap. Outside ACTIVE, `elapsed >= activeEnd` by construction, so
`(activeEnd - 2) - elapsed` is already negative and `math.max(0, …)` clamps it to 0 regardless.
The gate states the intent and protects against a future schedule shape where that stops holding;
it is not currently behaviour-bearing. Recorded rather than papered over.

## Which clock, and why

**`lockoutAt` stays on `os.clock()`. `secondsLeft()` is not touched at all.**

The trap the brief flagged is real and I sidestepped it rather than managed it. The key fact is
that `Reading.lockoutIn` is a **duration**, not an instant — seconds from `now` until picks close —
and a duration belongs to no timeline. So:

- `metronome:read()` is fed `workspace:GetServerTimeNow()` (`main.client.luau:335`), because that
  is the timeline the schedule is published on (`main.server.luau`'s `onSchedule`), and it is the
  same call `HammerController.client.luau:365,400` makes.
- One line later (`main.client.luau:341`) the duration is converted to a **local** deadline:
  `lockoutAt = os.clock() + reading.lockoutIn`.
- `secondsLeft()` (`main.client.luau:362-370`) therefore still reads
  `math.max(0, lockoutAt - os.clock())` — **byte-identical to before this task**. Both sides of the
  subtraction are `os.clock()`; no `GetServerTimeNow` value is ever stored in `lockoutAt`.

I considered moving both sides to `GetServerTimeNow`. Rejected: it would have required editing the
one function whose meaning must not change, and it would have required a matching edit to the poll
fallback at line 798 — two more chances to get the very thing wrong that broke this last time. The
duration conversion costs one addition and the two clocks are read one line apart, so the
conversion error is a fraction of a frame. `lockoutAt` is re-derived on every 10Hz tick anyway
(`refreshClock` at `:955`), so it cannot accumulate drift.

## Step 3: one lockout constant — with a deviation from the brief

The brief says to have `RoundCoordinator` require `RoundMetronome` "the way that file requires its
other shared modules". **`RoundCoordinator.luau` requires nothing.** Nor does any module under
`src/server` or `src/shared` except the two Roblox-runtime entry points — that is the codebase's
stated rule (CLAUDE.md: "Luau modules are dependency-injected and never `require` each other, so
the same files run under Lune (tests) and Roblox"). A Lune-relative `require("../shared/…")` inside
`RoundCoordinator` would throw at Roblox runtime; a `require(script.Parent…)` would throw under
Lune. The instruction is not implementable as written.

What I did instead, which reaches the same end:

- `RoundMetronome.LOCKOUT_SECONDS = 2` (`RoundMetronome.luau:19`) — the constant's new home.
- `main.server.luau` — the file that *does* require shared modules on the server side — requires
  `RoundMetronome` (`:53`) and injects `lockoutMs = RoundMetronome.LOCKOUT_SECONDS * 1000`
  (`:327`). **At runtime the Roblox game server and every client read the same number.**
- `RoundCoordinator` takes `lockoutMs: number?` on `Deps` (`:41`), stores it as `_lockoutMs`
  (`:55`), and uses it at `:223` where `LOCKOUT_BEFORE_END_MS` used to be.
- The optional-ness exists only so the Lune tests can keep building `Deps` by hand. The fallback is
  `RoundCoordinator.DEFAULT_LOCKOUT_MS = 2000` (`:20`), and a new test pins it:
  `expect(RoundCoordinator.DEFAULT_LOCKOUT_MS).toBe(RoundMetronome.LOCKOUT_SECONDS * 1000)`. A
  retune of the shared constant now fails CI rather than quietly leaving `RoundCoordinator.spec`
  asserting a lockout the game no longer has.

**`RoundCoordinator`'s existing tests are untouched and all pass.** It *does* have lockout coverage
— `tests/RoundCoordinator.spec.luau:219` ("accepts a pick during ACTIVE before lockout; rejects
after lockout") and `:283` ("final flush fires once past lockout even under the 5s cadence"), both
of which exercise the 2000ms lead through the default path — so I added none there, per the brief.

`main.server.luau` is not on the brief's file list. It has to be, or the injection has no source.
It is a 5-line addition (one require + one field) and it is in the commit.

## Step 4: the client

`main.client.luau`, all line numbers post-change:

- `:50` requires `RoundMetronome`.
- `:289-313` builds the metronome and pulls `RoundScheduleConfig`. This is a **deliberate mirror**
  of `HammerController.client.luau:21-41` — same attribute names (`StrikeAtServerTime`, `PeriodSec`,
  `RoundId`, `ActiveSec`, `TallySec`, `RevealSec`), same defaults (`20 / 2 / 5`), same
  `GetAttributeChangedSignal("StrikeAtServerTime")` trigger, same `workspace:GetServerTimeNow()`
  argument. Differences: it runs inside `task.spawn` so the `WaitForChild` cannot hold up wiring the
  remote handlers (a blocked top level would miss the first `RoundUpdate` outright).
- `:334-343` `refreshClock()` — the single writer of `phase`, `localPhase` and (when a schedule
  exists) `lockoutAt`.
- `:768` the round-ended edge is now measured on `serverPhase`, not the effective `phase`. This is
  load-bearing and is the one thing beyond the lockout that had to move: the effective phase now
  leads the server, so against `phase` the ACTIVE→non-ACTIVE edge would already have passed by the
  time `RoundUpdate` fired and `roundEnded` would **never** be called — silently killing the
  escalation's consecutive-miss backoff.
- `:784` `RoundUpdate` still corrects `phase` — a nudge for one tick, not a latch (a latch would
  hand the round back to the poll and undo the change).
- `:797-799` the poll's `secondsToLockout` is now the **fallback**, taken only when
  `localPhase == nil` — which is exactly "`refreshClock` has no schedule and will not be touching
  `lockoutAt`".
- `:955` the heartbeat calls `refreshClock()` first, before anything reads `phase` or
  `secondsLeft()` this tick.

`RoundUpdate` remains authoritative for round identity: `currentRoundId` (`:770`), the tape, the
per-round resets and the beat collapse are all unchanged and still driven by the remote.

## Step 5: the standing check, item by item

**1. Every `Reading.X` read exists on what Task 1 and Step 2 return.**
The client reads exactly two fields off the reading:

| read | line | defined at |
|---|---|---|
| `reading.phase` | `main.client.luau:336` | `RoundMetronome.luau:37` (type), `:141` region (returned) |
| `reading.lockoutIn` | `main.client.luau:341` | `RoundMetronome.luau:39` (type), `:141` (returned) |

`reading.secondsLeft` is **not** read by this file — deliberately; that is the number whose
misuse caused the revert. `HammerController` continues to read `drawP / camAngle / omega /
prevStrikeAt / nextStrikeAt`, all untouched.

**2. `lockoutAt` and the value it is compared against are on the same clock.**
Three assignments to `lockoutAt`, and only three:

| line | value | timeline |
|---|---|---|
| `:341` | `os.clock() + reading.lockoutIn` (duration → local deadline) | `os.clock()` |
| `:798` | `os.clock() + info.secondsToLockout` (unchanged from before) | `os.clock()` |
| `:817` | `nil` | — |

Compared at `:369` against `os.clock()`. Same clock on both sides. No `GetServerTimeNow` value ever
reaches `lockoutAt`; the only `GetServerTimeNow()` calls in this file are `:302` and `:335`, both
passed straight into the metronome.

**3. The nil-reading fallback is reachable.**
`RoundMetronome.read` returns `nil` while `_periodSec` or `_strikeAt` is `nil`, which holds until
`setSchedule` runs, which requires (a) `WaitForChild("RoundScheduleConfig")` to return and (b)
`StrikeAtServerTime` and `PeriodSec` to both be numbers (`:294-296` early-returns otherwise). Both
are false for a real interval on every join, and permanently in a place where the config never
replicates. Trace below.

**4. `secondsLeft()`'s formula is unchanged.** Confirmed by diff: `git diff` on the client shows
exactly two deleted lines and neither is inside `secondsLeft()`. The body is still:

```lua
if phase ~= "ACTIVE" then return 0 end
if not lockoutAt then return UNSYNCED_SECONDS end
return math.max(0, lockoutAt - os.clock())
```

Meaning unchanged: **seconds to the lockout**. `HudModel` keeps using it for the ring,
`throwsEnabledFor` (`> 0`) and `sendAtLockout` (`> 0.5`) exactly as it did.

**5. No new local used above its declaration.**

| local | declared | first use |
|---|---|---|
| `RoundMetronome` | `:50` | `:289` |
| `serverPhase` | `:164` | `:768` |
| `localPhase` | `:168` | `:337` |
| `metronome` | `:289` | `:298` |
| `scheduleConfig` | `:291` | `:293` |
| `pullSchedule` | `:292` | `:311` |
| `strikeAt` / `periodSec` | `:293-294` | `:295` |
| `reading` | `:335` | `:336` |
| `refreshClock` | `:334` | `:776`, `:955` |

selene (which fails on warnings) is clean.

## Trace: a client joining mid-round

Round is 27s (ACTIVE 20 / TALLY 2 / REVEAL 5); the player joins 8s into ACTIVE.

1. **t=0, top level.** Requires resolve. `metronome = RoundMetronome.new()` — no schedule.
   `task.spawn` parks on `WaitForChild("RoundScheduleConfig")`. State: `phase = ""`,
   `serverPhase = ""`, `localPhase = nil`, `lockoutAt = nil`.
2. **t≈0.1, heartbeat tick 1.** `refreshClock()` → `read()` returns `nil` → `localPhase = nil`,
   `phase = "" or ""` = `""`, `lockoutAt` **untouched** (stays `nil`). `secondsLeft()` → phase is
   not ACTIVE → `0`. `timerKnown = false`, ring hidden, throws shut. **Identical to today**, where
   `phase` is likewise `""` until the first `RoundUpdate`.
3. **t≈0.3, config replicates.** `pullSchedule()` runs. If the server has not yet published
   `StrikeAtServerTime`, it early-returns and the `GetAttributeChangedSignal` catches the first
   publish; the client stays in state 2 meanwhile. Assume it has: `setSchedule` hard-adopts (first
   schedule).
4. **t≈0.4, next tick.** `read()` now returns a reading. `localPhase = "ACTIVE"`,
   `phase = "ACTIVE"`, `lockoutAt = os.clock() + 9.6` (18s window less the 8.4s elapsed). The ring
   appears **at the correct remaining time**, without having waited for a poll.
5. **t≈0.9, first `RoundUpdate("ACTIVE")` arrives.** `serverPhase == ""` so `roundEnded` does not
   fire (correct — this client played no previous round). `serverPhase = "ACTIVE"`,
   `refreshClock()`, then `phase = "ACTIVE"` (agrees). The ACTIVE reset block runs as always; line
   `:797` sees `localPhase ~= nil` and **skips** the poll's `secondsToLockout`, so the timeline's
   fresher figure is not overwritten by one computed up to a second ago.
6. **Alternative branch — the config never lands.** Steps 3-4 never happen; `localPhase` stays
   `nil` forever; at step 5 line `:797` takes the poll value, `phase` falls through to
   `serverPhase`, and the file behaves **exactly as it did before this task**, poll lag and all.
7. **Next round opens.** At the instant ACTIVE begins on the timeline, `refreshClock` reports
   `phase = "ACTIVE"`, `lockoutIn = 18`. `HudController`'s `span` (`:1683-1685`) latches 18 rather
   than the ~17 the poll used to leave it with, so the ring starts full and depletes over the real
   window.

## Concerns, left in place

1. **The inverted failure mode is now live, and Task 3R must land before a player sees this.**
   `throwsEnabledFor` is `phase == "ACTIVE" and secondsLeft > 0`, and both now come from the local
   timeline, so throws can open **before** the Roblox server's round has. A pick taken then is
   buffered against a round `RoundCoordinator` has not opened. Per instruction I did not touch the
   gate's open condition. Closing is unaffected: `lockoutIn` reaches 0 at the same instant
   `RoundCoordinator._lockoutAtMs` does, now that both read one constant — arguably tighter than
   before, since the poll's figure could be up to a second stale.
2. **Two metronome instances now slew independently** (this file and `HammerController`). Both are
   fed the same attributes by the same signal, so they adopt the same anchor; a divergence could
   only open if one adopted its *first* schedule from a different publish than the other, and it
   would then converge at `SLEW_RATE`. Bounded and self-healing, but it is a second copy of the
   schedule-pull block. A shared reader is worth extracting; it changes `HammerController` too, so
   it belongs in its own diff. Noted in the code at `:281-284`.
3. **`timerKnown` is now true for more of the round** — it is `lockoutAt ~= nil`, and with a
   schedule that is every instant of ACTIVE rather than "only if the poll carried a lockout". This
   is the intended improvement (a client with the schedule but an unsynced game-server clock used
   to get no ring at all), but it is a rendering change the owner should look at in Studio.
4. **The `if phase == "ACTIVE"` gate on `lockoutIn` is currently redundant** (mutation C above).
   Kept for intent. If someone later "simplifies" it away, nothing will fail — that is a comment's
   job, and the comment is there.
5. **Nothing here is verifiable by an automated gate.** No suite loads `main.client.luau`. The
   998 green tests cover `RoundMetronome` and `RoundCoordinator` only. The owner's Studio gate is
   the real one, and its one-line acceptance test is: **does a fresh round's ring start at 18 and
   does the ring appear the instant ACTIVE opens rather than a second into it?** (18, not 20 —
   18 is correct; it is the lockout window, and that is the whole finding of the reverted Task 2.)
