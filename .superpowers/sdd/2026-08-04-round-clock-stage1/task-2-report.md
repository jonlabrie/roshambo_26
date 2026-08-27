# Task 2 report — the HUD's clock comes from the timeline

Commit: `582abfe` — `feat(roblox): the countdown starts at twenty`
Single file changed: `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/src/client/main.client.luau`
(+94 / −11). Not pushed.

---

## 1. What changed

All line numbers below are post-commit, in `roblox/src/client/main.client.luau`.

**Line 50** — `local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))`, alongside
the file's other `RoshamboShared` requires.

**Lines 149–170 — the phase locals split in two.** What was one `phase` is now:

| local | meaning |
|---|---|
| `phase` (162) | the EFFECTIVE phase — what the HUD renders, what `HudModel` reads |
| `serverPhase` (163) | the last phase `RoundUpdate` reported; fallback, corrector, and the basis of the round-ended edge |
| `localPhase` (166) | the timeline reading's phase, `nil` until a schedule lands |
| `localSecondsLeft` (167) | the timeline reading's countdown, `nil` until a schedule lands |
| `lockoutAt` (170) | unchanged — still `os.clock() + info.secondsToLockout` from the remote |

**Lines 273–311 — the timeline.** `local metronome = RoundMetronome.new()` (287) plus a
`task.spawn` that does `ReplicatedStorage:WaitForChild("RoundScheduleConfig")`, defines
`pullSchedule`, connects `GetAttributeChangedSignal("StrikeAtServerTime")`, and calls it once.

This is a *deliberate line-by-line mirror* of `HammerController.client.luau:22–41`: same attribute
names (`StrikeAtServerTime`, `PeriodSec`, `RoundId`, `ActiveSec`, `TallySec`, `RevealSec`), same
`typeof(...) ~= "number"` guard on the two required ones, same defaults (20 / 2 / 5), same
`workspace:GetServerTimeNow()` passed to `setSchedule`.

Two deliberate deviations from HammerController, both commented in place:
- **the `WaitForChild` runs inside `task.spawn`.** HammerController blocks its top level on the
  config; this file must not — its top level is what connects `RoundUpdate`, `RevealResult`,
  `ProfileUpdate`, `RevealTheater` and `BoardData`, and a block there would miss the first
  RoundUpdate outright. It is also consistent with this file's own existing rule at line 86–88
  (`strikeLeadSeconds` uses `FindFirstChild`, "because the HUD must not block on the arena's
  config folder"). Until the folder lands, `read()` returns nil and rule 1 covers it.
- **no `CamMesh` / stage work** — not this file's business.

**Lines 313–331 — `refreshClock()`**, the single writer of `phase`, `localPhase` and
`localSecondsLeft`:

```lua
local function refreshClock()
    local r = metronome:read(workspace:GetServerTimeNow())
    localPhase = if r then r.phase else nil
    localSecondsLeft = if r then r.secondsLeft else nil
    phase = localPhase or serverPhase
end
```

**Lines 341–367 — `secondsLeft()`.** Returns 0 outside ACTIVE (unchanged), then prefers
`localSecondsLeft` — guarded on `localPhase == phase`, so the moment `RoundUpdate` corrects the
phase the reading (which is about a different boundary) is not used. Falls through to the exact
prior body: `UNSYNCED_SECONDS`, else `lockoutAt - os.clock()`.

**Line 433 — `timerKnown`** widened from `lockoutAt ~= nil` to
`localSecondsLeft ~= nil or lockoutAt ~= nil`. Either source gives the ring a real span; left
alone it would hide a perfectly good ring on a client that has the schedule but whose
`RoundUpdate` arrived with a nil `secondsToLockout`.

**Lines 770–786 — the `RoundUpdate` handler.**
- 770: the round-ended edge now reads `serverPhase == "ACTIVE" and info.phase ~= "ACTIVE"`
  (was `phase == ...`). **This one is load-bearing** — see check item 5.
- 777: `serverPhase = info.phase`
- 778: `refreshClock()` — resample so `localPhase`/`localSecondsLeft` describe this instant
- 786: `phase = info.phase` — rule 3, the correction
- everything else in the handler (round id, tape, the ACTIVE reset block, `lockoutAt`) untouched.

**Line 950 — the 10Hz heartbeat** calls `refreshClock()` first, before anything reads `phase` or
`secondsLeft()` that tick.

Nothing on the wire changed. No server file, no shared module, no other client file.

---

## 2. Gate output

```
$ cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
$ lune run tests/run
993 passed, 0 failed, 993 total
$ stylua --check src tests tools
(silent — clean)
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

Same 993 as Task 1: **no automated gate loads this file.** `tests/run` never requires a
`.client.luau`. The gates prove formatting and lint only. Reading is the gate; §3 is it.

---

## 3. The standing check, item by item

**1. Every `Reading.X` read resolves to a field Task 1 returns.**
Exactly two reads, both in `refreshClock` (326–331):
- `r.phase` — line 328. Returned by `RoundMetronome.read` at `RoundMetronome.luau:122`, typed on
  `Reading` at line 30.
- `r.secondsLeft` — line 329. Returned at `RoundMetronome.luau:123`, typed at line 31.

No other field of the reading is touched anywhere in this file — `drawP`, `camAngle`, `omega`,
`periodSec`, `prevStrikeAt`, `nextStrikeAt` are read only by HammerController, which is untouched.

**2. The clock is `workspace:GetServerTimeNow()`.**
- line 327 — `metronome:read(workspace:GetServerTimeNow())`
- line 305 — `metronome:setSchedule({...}, workspace:GetServerTimeNow())`

`grep -n "os.clock\|tick()\|DateTime"` over the file returns four `os.clock` sites, all
pre-existing and all on local-deadline duties that were never on the schedule's timeline:
line 367 (`lockoutAt - os.clock()`, the RoundUpdate-carried lockout — same clock it was written
with at line 794), 657 and 956 (the UNDO? prompt's 2s fuse), 794 (`lockoutAt` assignment). No
`tick()`, no `DateTime`. Nothing crosses clocks: the metronome only ever sees
`GetServerTimeNow`, and `lockoutAt` only ever sees `os.clock`.

**3. Every new local declared above its first use.**

| local | declared | first use |
|---|---|---|
| `RoundMetronome` | 50 | 287 |
| `phase` | 162 | 342 |
| `serverPhase` | 163 | 330 |
| `localPhase` | 166 | 328 |
| `localSecondsLeft` | 167 | 329 |
| `metronome` | 287 | 296 (inside the spawn, which runs after) |
| `scheduleConfig` | 289 | 291 |
| `pullSchedule` | 290 | 309 |
| `strikeAt` / `periodSec` | 291 / 292 | 293 |
| `refreshClock` | 326 | 778 |
| `r` | 327 | 328 |

`refreshClock` (326) closes over `metronome` (287), `serverPhase` (163), `localPhase` (166),
`localSecondsLeft` (167), `phase` (162) — all declared above it, so none resolves to a nil global.
`secondsLeft` (341) closes over `phase`, `localSecondsLeft`, `localPhase`, `lockoutAt` (170) and
`UNSYNCED_SECONDS` (339) — all above. Both are used only from lines 778 / 950 / inside
`buildInputs` (396), all far below.

**4. The nil-reading fallback is reachable and correct.** Traced in §4.

**5. Nothing that used to read `info.phase` was left reading a now-stale local.**
Every read of `phase` in the file, post-change:
- **342** (`secondsLeft`) — wants the effective phase. Correct.
- **396** (`buildInputs` → `HudModel`) — wants the effective phase. Correct, and it is the whole
  point of the task.
- **952** (heartbeat, `if phase == "ACTIVE" then roundCouldThrow = true`) — "was the player free
  to throw at any point this round". Effective phase is right; it now latches up to ~1.5s earlier,
  which is harmless because line 793 already sets it true unconditionally on the ACTIVE
  `RoundUpdate`.
- **770** — moved to `serverPhase`. **This was the one real trap.** The edge means "the server's
  round has closed", and the effective phase now *leads* the server. Against `phase` the edge
  would already have passed by the time the handler fired, `roundEnded()` would never be called
  again, and `HudModel`'s consecutive-miss backoff would silently stop counting — a nagging
  escalation that never backs off, with no error anywhere. `serverPhase` still holds the
  *previous* report at line 770 (it is assigned at 777), so the comparison is byte-for-byte what
  it was before.

Also checked and left alone, because they read `info` directly rather than the local, and belong
to the server's view (rule 2): the round id at 763, the tape at 764, the whole `info.phase ==
"ACTIVE"` reset block at 778–801, and `lockoutAt` at 794/803.

---

## 4. Trace: a client joins mid-round

`RoundScheduleConfig` is created by `main.server.luau:44` and its attributes are only written in
`onSchedule` (`main.server.luau:364–375`), which runs on a poll — so a joining client can have the
folder, or the folder with a full attribute set, or neither.

1. **t=0, script start.** `metronome = RoundMetronome.new()` — `_strikeAt` and `_periodSec` are
   nil. The `task.spawn` parks on `WaitForChild`. The top level keeps going and connects every
   remote handler, so nothing is missed.
2. **t≈0.1s, first heartbeat tick.** `refreshClock()` → `metronome:read(...)` hits
   `RoundMetronome.luau:74` (`period == nil or strike == nil`) → **nil**. `localPhase = nil`,
   `localSecondsLeft = nil`, `phase = nil or serverPhase` = `""`. `secondsLeft()` returns 0
   (`phase ~= "ACTIVE"`). `timerKnown` = false. Identical to today's cold start.
3. **First `RoundUpdate` lands** (worst case ~1.25s + RTT after the boundary; say it says ACTIVE
   with `secondsToLockout = 16.4`). 770: `serverPhase` is `""`, no edge. 777: `serverPhase =
   "ACTIVE"`. 778: `refreshClock()` — still nil if the schedule has not arrived, so `phase =
   "ACTIVE"` via the fallback. 786: `phase = "ACTIVE"` (rule 3, same value). 794: `lockoutAt =
   os.clock() + 16.4`.
4. **t≈0.1s later, next tick.** `refreshClock()` → still nil → `phase = serverPhase = "ACTIVE"`,
   `localSecondsLeft = nil`. `secondsLeft()` skips the timeline branch (`localSecondsLeft` is nil)
   and returns `lockoutAt - os.clock()` ≈ 16.3. `timerKnown` = true via `lockoutAt`.
   **This is exactly today's behaviour, including the 18-not-20.** Rule 1 holds: no schedule, no
   local clock, degrade to the remote — never a blank or frozen HUD.
5. **`RoundScheduleConfig` replicates.** `WaitForChild` returns; `pullSchedule()` runs. If the
   attributes are already set it calls `setSchedule` at once; if they are not, the two
   `typeof(...) ~= "number"` guards return early and the `StrikeAtServerTime` changed-signal picks
   it up at the next `onSchedule` (≤ one poll).
6. **First tick after `setSchedule`.** `read()` now returns a reading. `localPhase = "ACTIVE"`,
   `localSecondsLeft` = seconds to the end of ACTIVE. `phase = localPhase`. `secondsLeft()` takes
   the timeline branch. From here the countdown is on the published schedule and the next round
   opens at **20**.
7. **A client that never gets the folder at all** (server never created it) parks in the spawn
   forever and stays at step 4 for the whole session. That is the intended degradation.

The fallback path is reachable at every one of steps 2, 4 and 7, and is the *same* code that ran
before this change.

---

## 5. What happens when the timeline and `RoundUpdate` disagree

`RoundUpdate` fires only on a phase *change* the poll noticed, so this is per-boundary, not
continuous.

**The normal case is disagreement, and it is the point of the change.** ACTIVE opens at T₀; the
timeline says ACTIVE at T₀ and the countdown starts at 20; the poll notices somewhere in
[T₀, T₀+1.25s] and `RoundUpdate("ACTIVE")` arrives after RTT. When it does, both sources say
ACTIVE — no disagreement to resolve, `phase = info.phase` is a no-op, and the countdown keeps
running off the timeline.

**Genuine disagreement** — say TALLY (2s long) is noticed so late that `RoundUpdate("TALLY")`
arrives when the timeline has already moved to REVEAL:

1. line 786 takes the server's phase: `phase = "TALLY"`, while `localPhase = "REVEAL"`.
2. `secondsLeft()` sees `localPhase ~= phase` and refuses the reading, falling back to the
   lockout branch — which returns 0 anyway, since `phase ~= "ACTIVE"`.
3. **The correction is a nudge, not a latch.** The next heartbeat tick (≤ `TICK` = 100ms) runs
   `refreshClock()` and `phase` returns to `localPhase`.

That release is deliberate and I want it on the record: a correction that *held* until the two
agreed would keep `phase` pinned to the server's report for the entire 0–1.5s poll window at every
boundary, which is exactly the lag this stage removes — it would silently undo the task. And a
latch on a *late TALLY* would stick for a whole period, because the local timeline will not say
"TALLY" again for ~25s. So: take the server's phase at the instant it speaks, then let the
timeline drive.

**Nothing in this file snaps or rewrites the schedule.** `setSchedule` is called only from
`pullSchedule`, only with what the server published. `RoundMetronome` owns convergence
(`SLEW_TOLERANCE` 2.0s, `SLEW_RATE` 0.05) and already does it. Rule 3 satisfied without a second
slewing mechanism.

---

## 6. Concerns

### ⚠ BLOCKING — the meaning of `secondsLeft` changed, and the throw gate has not caught up

**This is the hazard I was told to notice and leave. It is worse than "throws open early", and
Task 3 as written does not fix it. It must be fixed before this reaches a player.** I left a
matching `⚠` comment at `main.client.luau:353–361` so the next reader sees it in the code.

The old `secondsLeft()` returned **seconds to the LOCKOUT** — the server computes
`_lockoutAtMs = ACTIVE_end − 2000` (`RoundCoordinator.luau:9, 208`) and ships the remainder as
`secondsToLockout`. That 2s subtraction, not the poll, is most of why a fresh countdown reads 18:
even with a perfect clock the old number could only ever start at `activeSec − 2`.

The new `secondsLeft()` returns **seconds to the END OF ACTIVE**, because that is the only thing
that starts at 20 and satisfies the plan's acceptance test. But `HudModel` uses that one number
for three jobs, and two of them are the lockout's:

- `HudModel.luau:84` — `throwsEnabledFor` closes on `secondsLeft > 0`. Taps now stay live until
  ACTIVE ends, **2s past the server's lockout**.
- `HudModel.luau:149–162` — `sendAtLockout` fires at `secondsLeft <= 0.5`, i.e. `ACTIVE_end −
  0.5s`, **1.5s past the server's lockout**. `RoundCoordinator:submitPick` (line 60–62) then
  returns `LOCKED`, `main.server.luau:459–461` prints and drops it, and the client is told
  nothing — the `whiffed` toast only covers flush-whiffs, not `LOCKED` rejections.

Net effect as committed: **every held pick is submitted after the lockout and silently discarded.**
The player sees their glyph lit all round and no result. `HudModel.luau:147` even says the quiet
part out loud — "`secondsLeft` is secondsToLockout, so zero IS the lockout" — and that comment is
now false.

The plan's Task 3 Step 1 only guards *opening* early; Step 2 asks the implementer to "confirm the
lockout is unaffected and the throw gate still closes at the lockout exactly as it does today",
which after this commit is simply not true and cannot be confirmed. **Task 3 needs widening.** The
clean shape, and the one I'd recommend:

> `HudModel.Inputs` grows a second number — the displayed countdown (to the phase boundary) and
> the actionable one (to the lockout) are different facts and should stop sharing a field.
> `view.secondsLeft` (the ring, `HudController:1708/1713`) takes the display value;
> `throwsEnabledFor`, `escalate` and `sendAtLockout` take the lockout value. `main.client` can
> derive the lockout value from the timeline too — `reading.secondsLeft − LOCKOUT_LEAD` during
> ACTIVE, with `LOCKOUT_LEAD` mirroring `RoundCoordinator.LOCKOUT_BEFORE_END_MS` — or keep using
> the server-carried `lockoutAt`, which the plan's Task 3 Step 2 prefers. Either way the gate must
> close on the LOCKOUT and the ring must count to the BOUNDARY.

I did not do it here: it is a change to `HudModel` (a tested shared module) and to the throw gate,
both explicitly out of scope for this task.

### The early-open hazard is milder than the plan implies

Worth recording for whoever picks up Task 3: because a pick is *held locally* until
`sendAtLockout` (`main.client.luau:653–666`, and the "NOTHING HERE TALKS TO THE SERVER" comment
above it), a tap made in the 0–1.5s where the local phase leads the server does **not** hit the
wire early. It sits in `chosen` and goes out at the lockout, long after the server's phase caught
up. So the "swallowed first tap" the plan fears is not reachable through the tap path as the file
stands today — the reachable fault is the *late* one above. Task 3's guard is still worth having
(it is cheap, and it protects against a future change that sends on tap), but it should not be
mistaken for the fix.

### Duplicated schedule literals — recommend extracting, not here

Three files now name `RoundScheduleConfig`'s attributes and their defaults:
`HammerController.client.luau:22–41` (and again at 219–224 for the cam mesh),
`main.client.luau:289–310`, and `main.client.luau:86–88` (`strikeLeadSeconds`, which already
duplicated `TallySec`'s default of 2 before this task). `TheaterController.client.luau:135` reads
the folder too.

The brief allows this and asks me to report rather than extract, which I have. The extraction I'd
suggest is a shared `RoundSchedule.luau` exposing `RoundSchedule.pull(config): Schedule?` with the
names and defaults in one place — but it must not take a Roblox global into `src/shared`, so it
would receive the `Configuration` instance and use only `:GetAttribute`, and it changes
HammerController (whose cam-mesh geometry is derived from the same attributes) as well as this
file. That is a separate diff with its own reading gate.

### Smaller notes

- **Off-heartbeat `publish()` calls** (from `ProfileUpdate`, `RevealTheater`, `EventBus.HudPick`,
  …) now use a `localSecondsLeft` sampled up to 100ms ago, where before `secondsLeft()`
  recomputed live from `os.clock()`. The ring is repainted at 10Hz by the heartbeat regardless, so
  this is invisible; I mention it only because it is a real change in kind (sampled vs. computed).
- **`refreshClock()` calls `read()` at 10Hz**, which advances `RoundMetronome`'s internal slew
  state (`_lastNow`, and the `strike += step` convergence at `RoundMetronome.luau:78–84`). This is
  a *separate metronome instance* from HammerController's, so the bell's cam is not affected in
  any way — but be aware the two instances slew independently and can differ by a few
  milliseconds during convergence. Harmless for a countdown displayed as `math.ceil`.
- **Not verifiable by any gate.** Everything above is a reading argument. The owner's Studio gate
  is what settles it, and the one-line test is unchanged: *does a fresh countdown start at 20?*
  If it starts at 18 the HUD is still on the poll. Add one more thing to look for now:
  **does a held pick actually get counted?** Per the blocking concern, today it should not.
