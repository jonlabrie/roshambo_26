# Round Metronome Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bell engine's event-arrival-measured client clock with a published absolute round schedule and a pure client metronome, so every visual runs as jitter-free clockwork and reveal-data lateness is absorbed only by the throw drum.

**Architecture:** Express `/state` states its phase durations; the Roblox server (which already syncs to Express time via RoundClock) converts each round's schedule onto the `workspace:GetServerTimeNow()` timeline and publishes it as attributes on a ReplicatedStorage Configuration (the DayNightConfig pattern); a new pure `RoundMetronome` module maps (schedule, now) → draw/cam/strike outputs with slew-limited corrections; HammerController self-times the strike from it; the drum's glide waits for the reveal data.

**Tech Stack:** Express/TypeScript + Vitest (`server/`), Luau + Lune test harness (`roblox/`), Rojo-replicated attributes, `workspace:GetServerTimeNow()`.

**Spec:** `docs/superpowers/specs/2026-07-23-round-metronome-design.md`

## Global Constraints

- Roblox Luau modules under `src/shared/` are pure and dependency-injected — no `game`/`workspace`/Roblox APIs; only `.client.luau`/`.server.luau` entry files touch the engine.
- All roblox commands run from `roblox/`: `lune run tests/run` (all tests must pass), `stylua --check src tests tools`, `selene src tools` (warnings fail CI).
- Server commands run from `server/`: `npm test` (Vitest; requires the repo's dev MongoDB env per `server/.env` — the suite runs against `connectTestDb`).
- Commit after every task; commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Times in the metronome and schedule attributes are SECONDS on the GetServerTimeNow timeline; Express payloads and RoundCoordinator internals are MILLISECONDS on local epoch time. Convert only in `main.server.luau`.
- The strike instant is defined as reveal start = activeEnd + tally.

---

### Task 1: Express `/state` publishes phase durations

**Files:**
- Modify: `server/src/engine/RoundEngine.ts` (add `durationsMs()` after `snapshot()`, ~line 60)
- Modify: `server/src/routes/apiV1.ts` (the `/state` handler, ~line 19)
- Test: `server/src/routes/apiV1.test.ts` (the `GET /state` describe, ~line 43)

**Interfaces:**
- Produces: `GET /api/v1/state` body gains `durations: { activeMs: number, tallyMs: number, revealMs: number }`. `RoundEngine.durationsMs(): { activeMs, tallyMs, revealMs }`. Task 2's fake `/state` payloads mirror this shape.

- [ ] **Step 1: Write the failing test**

In `server/src/routes/apiV1.test.ts`, inside `describe('GET /state', ...)` add:

```ts
it('states its phase durations (round-metronome schedule source)', async () => {
    const res = await request(makeApp(makeEngine(), new ResultsStore()))
        .get('/api/v1/state').set('X-API-Key', API_KEY).expect(200);
    expect(res.body.durations).toEqual({ activeMs: 20000, tallyMs: 2000, revealMs: 3000 });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `server/`): `npx vitest run src/routes/apiV1.test.ts -t "phase durations"`
Expected: FAIL — `expected undefined to deeply equal { activeMs: 20000, ... }`

- [ ] **Step 3: Implement**

In `server/src/engine/RoundEngine.ts`, after the `snapshot()` method:

```ts
    durationsMs(): { activeMs: number; tallyMs: number; revealMs: number } {
        return {
            activeMs: this.cfg.activeSeconds * 1000,
            tallyMs: this.cfg.tallySeconds * 1000,
            revealMs: this.cfg.revealSeconds * 1000,
        };
    }
```

In `server/src/routes/apiV1.ts`, add one field to the `/state` response object (after `serverTime: now,`):

```ts
            durations: engine.durationsMs(),
```

- [ ] **Step 4: Run the server suite**

Run: `npm test`
Expected: all Vitest suites PASS (13 files, 189+ tests).

- [ ] **Step 5: Commit**

```bash
git add server/src/engine/RoundEngine.ts server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): /state publishes phase durations for the round metronome"
```

---

### Task 2: RoundCoordinator computes and emits the round schedule

**Files:**
- Modify: `roblox/src/server/RoundCoordinator.luau` (Callbacks type ~line 13; constructor state ~line 34; poll body — insert after the `if state.phase ~= self._phase then ... end` block, before `self:_maybeFlush()`, ~line 224)
- Test: `roblox/tests/RoundCoordinator.spec.luau` (append a new `describe` at the end)

**Interfaces:**
- Consumes: `/state` payloads now carry `durations = { activeMs, tallyMs, revealMs }` (Task 1). Existing deps: `clock.hasSync()`, `clock:toLocalTime(serverMs) → localMs`.
- Produces: optional callback `onSchedule(sched)` with `sched = { roundId: string, roundCount: number, strikeAtMs: number (local epoch ms), periodMs: number, activeMs: number, tallyMs: number, revealMs: number }`. Fired on roundId change or when the recomputed strike moves > 150 ms; skipped when `durations` is absent or clock unsynced. Task 3 consumes this exact shape.

- [ ] **Step 1: Write the failing tests**

Append to `roblox/tests/RoundCoordinator.spec.luau`:

```lua
describe("RoundCoordinator schedule publish (round metronome)", function()
    local DUR = { activeMs = 20000, tallyMs = 2000, revealMs = 3000 }
    local function makeScheduleRig(states: { any })
        local schedules: { any } = {}
        local idx = 0
        local coordinator
        local deps = {
            net = {
                getState = function(_self): any
                    idx = math.min(idx + 1, #states)
                    return states[idx]
                end,
                getRoundResult = function(): any
                    return { ok = false, status = 404 }
                end,
                postThrows = function(): any
                    return { ok = true, data = { accepted = 0, rejected = {} } }
                end,
                getInstanceResults = function(): any
                    return { ok = false, status = 404 }
                end,
            },
            -- fixed 500ms offset: local = server - 500
            clock = {
                addSample = function() end,
                hasSync = function()
                    return true
                end,
                toLocalTime = function(_self, serverMs: number)
                    return serverMs - 500
                end,
            },
            buffer = ThrowBuffer.new(),
            rules = GameRules,
            log = function() end,
            random = function()
                return 0
            end,
            now = function()
                return 0
            end,
            instanceId = "spec",
            callbacks = {
                onSchedule = function(s)
                    table.insert(schedules, s)
                end,
            },
        }
        coordinator = RoundCoordinator.new(deps)
        return coordinator, schedules
    end
    local function stateOk(over: any)
        local s = {
            ok = true,
            rttMs = 40,
            localReceiveMs = 0,
            data = {
                roundId = "r1",
                phase = "ACTIVE",
                phaseEndsAt = 100000,
                serverTime = 90000,
                roundCount = 7,
                tape = {},
                durations = DUR,
            },
        }
        for k, v in over do
            s.data[k] = v
        end
        return s
    end

    test("ACTIVE publishes strike = phase end + tally (in local ms)", function()
        local c, schedules = makeScheduleRig({ stateOk({}) })
        c:pollOnce()
        expect(#schedules).toBe(1)
        -- toLocalTime(100000) = 99500; + tallyMs 2000
        expect(schedules[1].strikeAtMs).toBe(101500)
        expect(schedules[1].periodMs).toBe(25000)
        expect(schedules[1].roundId).toBe("r1")
        expect(schedules[1].roundCount).toBe(7)
        expect(schedules[1].activeMs).toBe(20000)
    end)

    test("TALLY strike = phase end; REVEAL strike = next round's", function()
        local c, schedules =
            makeScheduleRig({ stateOk({ phase = "TALLY" }), stateOk({ phase = "REVEAL" }) })
        c:pollOnce()
        c:pollOnce()
        expect(#schedules).toBe(2)
        expect(schedules[1].strikeAtMs).toBe(99500) -- TALLY ends at the strike
        expect(schedules[2].strikeAtMs).toBe(99500 + 22000) -- REVEAL end + active + tally
    end)

    test("re-publishes only past the 150ms wobble gate", function()
        local c, schedules = makeScheduleRig({
            stateOk({}),
            stateOk({ phaseEndsAt = 100100 }), -- strike moves 100ms: suppressed
            stateOk({ phaseEndsAt = 100300 }), -- 300ms from published: republished
        })
        c:pollOnce()
        c:pollOnce()
        c:pollOnce()
        expect(#schedules).toBe(2)
        expect(schedules[2].strikeAtMs).toBe(101800)
    end)

    test("silent without durations or clock sync", function()
        local noDur = stateOk({})
        noDur.data.durations = nil
        local c, schedules = makeScheduleRig({ noDur })
        c:pollOnce()
        expect(#schedules).toBe(0)
    end)
end)
```

Note: match the existing spec's poll entry point — if the file's other tests call something other than `c:pollOnce()` (e.g. `c:pollOnce()`), use that exact name in all four tests.

- [ ] **Step 2: Run to verify failure**

Run (from `roblox/`): `lune run tests/run`
Expected: the four new tests FAIL (`onSchedule` never fires / count 0 ≠ 1); all pre-existing tests still pass.

- [ ] **Step 3: Implement**

In `roblox/src/server/RoundCoordinator.luau`:

Add to `Callbacks` type:

```lua
    onSchedule: ((sched: any) -> ())?,
```

Add to the constructor's state table:

```lua
        _publishedStrikeMs = nil :: number?,
        _publishedRoundId = nil :: string?,
```

Insert after the `if state.phase ~= self._phase then ... end` block (before `self:_maybeFlush()`):

```lua
    -- Publish the round's absolute schedule (round-metronome spec): the strike is
    -- reveal start = activeEnd + tally. Republish on roundId change or when sync
    -- refinement moves the strike > 150ms; clients slew, so small edits are cheap.
    local dur = state.durations
    if dur and d.clock:hasSync() then
        local endLocal = d.clock:toLocalTime(state.phaseEndsAt)
        local strikeAtMs
        if state.phase == "ACTIVE" then
            strikeAtMs = endLocal + dur.tallyMs
        elseif state.phase == "TALLY" then
            strikeAtMs = endLocal
        else -- REVEAL: the NEXT round's strike
            strikeAtMs = endLocal + dur.activeMs + dur.tallyMs
        end
        if
            self._publishedStrikeMs == nil
            or self._publishedRoundId ~= state.roundId
            or math.abs(strikeAtMs - self._publishedStrikeMs) > 150
        then
            self._publishedStrikeMs = strikeAtMs
            self._publishedRoundId = state.roundId
            if d.callbacks and d.callbacks.onSchedule then
                d.callbacks.onSchedule({
                    roundId = state.roundId,
                    roundCount = state.roundCount,
                    strikeAtMs = strikeAtMs,
                    periodMs = dur.activeMs + dur.tallyMs + dur.revealMs,
                    activeMs = dur.activeMs,
                    tallyMs = dur.tallyMs,
                    revealMs = dur.revealMs,
                })
            end
        end
    end
```

- [ ] **Step 4: Verify green + lint**

Run: `lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: all tests pass, 0 lint findings. (If stylua objects, run `stylua src tests tools` and re-check.)

- [ ] **Step 5: Commit**

```bash
git add roblox/src/server/RoundCoordinator.luau roblox/tests/RoundCoordinator.spec.luau
git commit -m "feat(roblox): RoundCoordinator emits the absolute round schedule"
```

---

### Task 3: main.server publishes RoundScheduleConfig

**Files:**
- Modify: `roblox/src/server/main.server.luau` (Configuration creation near the DayNightConfig block ~line 15-30; `onSchedule` callback in the `RoundCoordinator.new` deps ~line 233)

**Interfaces:**
- Consumes: `onSchedule(sched)` from Task 2 (`strikeAtMs` in local epoch ms — the same clock as `deps.now()`).
- Produces: `ReplicatedStorage.RoundScheduleConfig` (Configuration) with attributes `RoundId: string`, `RoundCount: number`, `StrikeAtServerTime: number` (GetServerTimeNow SECONDS), `PeriodSec/ActiveSec/TallySec/RevealSec: number`. Task 5 reads exactly these names.

- [ ] **Step 1: Create the Configuration**

In `roblox/src/server/main.server.luau`, immediately after the `dayNightConfig.Parent = ReplicatedStorage` line:

```lua
-- Round schedule for the client metronome (round-metronome spec): absolute times
-- on the GetServerTimeNow timeline, refreshed by RoundCoordinator's onSchedule.
local roundScheduleConfig = Instance.new("Configuration")
roundScheduleConfig.Name = "RoundScheduleConfig"
roundScheduleConfig.Parent = ReplicatedStorage
```

- [ ] **Step 2: Publish in the coordinator callbacks**

In the `RoundCoordinator.new({ ... callbacks = { ... } })` table, after the `onReveal` entry add:

```lua
        onSchedule = function(s)
            -- local epoch ms -> GetServerTimeNow seconds: both clocks are "now" here,
            -- so carry the delta across.
            local strikeSt = workspace:GetServerTimeNow() + (s.strikeAtMs - deps.now()) / 1000
            roundScheduleConfig:SetAttribute("RoundId", s.roundId)
            roundScheduleConfig:SetAttribute("RoundCount", s.roundCount)
            roundScheduleConfig:SetAttribute("PeriodSec", s.periodMs / 1000)
            roundScheduleConfig:SetAttribute("ActiveSec", s.activeMs / 1000)
            roundScheduleConfig:SetAttribute("TallySec", s.tallyMs / 1000)
            roundScheduleConfig:SetAttribute("RevealSec", s.revealMs / 1000)
            -- StrikeAtServerTime LAST: clients pull the whole schedule on its change.
            roundScheduleConfig:SetAttribute("StrikeAtServerTime", strikeSt)
        end,
```

- [ ] **Step 3: Lint + tests**

Run: `lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: green (main.server has no Lune coverage by convention; this verifies nothing broke).

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): publish RoundScheduleConfig on the GetServerTimeNow timeline"
```

---

### Task 4: RoundMetronome pure module

**Files:**
- Create: `roblox/src/shared/RoundMetronome.luau`
- Test: `roblox/tests/RoundMetronome.spec.luau`
- Modify: `roblox/default.project.json` — ONLY if shared modules are individually listed there; if `src/shared` maps as a folder (check how `RoundClock` appears), no change is needed.

**Interfaces:**
- Consumes: nothing (pure; times are plain seconds).
- Produces (Task 5 consumes exactly):
  - `RoundMetronome.new() → m`
  - `m:setSchedule({ roundId: string?, strikeAt: number, periodSec: number, activeSec: number, tallySec: number, revealSec: number }, now: number)`
  - `m:read(now) → nil | { drawP: number, camAngle: number, omega: number, periodSec: number, prevStrikeAt: number, nextStrikeAt: number }` (camAngle ≡ 0 mod 2π at every strike instant; drawP ramps 0→1 over the round `[strike − active − tally, +period)`)
  - `m:strikesBetween(t0, t1) → number` (strike instants in `(t0, t1]`)

- [ ] **Step 1: Write the failing tests**

Create `roblox/tests/RoundMetronome.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local RoundMetronome = require("../src/shared/RoundMetronome")
local describe, test, expect = harness.describe, harness.test, harness.expect

local TAU = 2 * math.pi
local function sched(strikeAt: number)
    return { roundId = "r", strikeAt = strikeAt, periodSec = 25, activeSec = 20, tallySec = 2, revealSec = 3 }
end

describe("RoundMetronome", function()
    test("read is nil before any schedule", function()
        expect(RoundMetronome.new():read(100)).toBeNil()
    end)

    test("maps the timeline: cam hits 0 at the strike, draw ramps over the round", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        local atStrike = m:read(122)
        expect(atStrike.camAngle % TAU).toBeCloseTo(0, 0.0001)
        expect(atStrike.drawP).toBeCloseTo(22 / 25, 0.0001) -- (active+tally)/period
        local mid = m:read(105) -- round started at 100
        expect(mid.drawP).toBeCloseTo(5 / 25, 0.0001)
        expect(mid.omega).toBeCloseTo(TAU / 25, 0.0001)
        expect(mid.nextStrikeAt).toBeCloseTo(122, 0.0001)
        expect(mid.prevStrikeAt).toBeCloseTo(97, 0.0001)
    end)

    test("free-runs: strikes recur every period with no further schedule", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        expect(m:strikesBetween(121, 123)).toBe(1)
        expect(m:strikesBetween(123, 146)).toBe(0)
        expect(m:strikesBetween(123, 148)).toBe(1) -- 147
        expect(m:strikesBetween(100, 1100)).toBe(40)
        expect((m:read(122 + 40 * 25).camAngle) % TAU).toBeCloseTo(0, 0.001)
    end)

    test("racing-wheel regression: a mid-round join still yields omega = 2pi/period", function()
        -- the old measured clock read 2pi/7.4 when joining 17.6s into a 25s round
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 114.6) -- joined with 7.4s to the strike
        expect(m:read(114.6).omega).toBeCloseTo(TAU / 25, 0.0001)
        expect(m:read(114.6).drawP).toBeCloseTo(14.6 / 25, 0.0001)
    end)

    test("small refinements slew (bounded, converging), never step", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        m:read(100)
        m:setSchedule(sched(122.4), 101)
        local prev = m:read(101).nextStrikeAt
        expect(prev < 122.4).toBe(true) -- not adopted instantly
        for t = 102, 115 do
            local cur = m:read(t).nextStrikeAt
            expect(cur - prev <= 0.05 * 1 + 0.0001).toBe(true) -- rate-capped
            expect(cur + 0.0001 >= prev).toBe(true) -- monotone toward target
            prev = cur
        end
        expect(prev).toBeCloseTo(122.4, 0.001) -- converged
    end)

    test("big shifts snap (restart) and period changes adopt cleanly (20->60 launch)", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        m:read(100)
        m:setSchedule(sched(126), 101) -- 4s > tolerance: hard re-anchor
        expect(m:read(101).nextStrikeAt).toBeCloseTo(126, 0.0001)
        m:setSchedule({ roundId = "r2", strikeAt = 200, periodSec = 65, activeSec = 60, tallySec = 2, revealSec = 3 }, 140)
        local r = m:read(150)
        expect(r.omega).toBeCloseTo(TAU / 65, 0.0001)
        expect(r.nextStrikeAt).toBeCloseTo(200, 0.0001)
    end)

    test("next-round schedules land in the same congruence class (no phantom shift)", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        m:read(100)
        m:setSchedule(sched(147), 123) -- next round, exactly one period on
        expect(m:read(123).nextStrikeAt).toBeCloseTo(147, 0.0001)
        expect(m:read(123).camAngle).toBeCloseTo(TAU * 1 / 25, 0.0001)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `lune run tests/run`
Expected: FAIL — `RoundMetronome` module not found.

- [ ] **Step 3: Implement**

Create `roblox/src/shared/RoundMetronome.luau`:

```lua
--!strict
-- The single client-side round timeline (spec: 2026-07-23-round-metronome-design).
-- Pure and clock-agnostic: callers pass `now` in seconds (GetServerTimeNow at
-- runtime, plain numbers in tests). Slew-not-snap: schedule refinements within
-- SLEW_TOLERANCE bend the effective timeline at SLEW_RATE so gear rotation never
-- steps; larger shifts (server restart, new period) hard re-anchor.
local RoundMetronome = {}
RoundMetronome.__index = RoundMetronome

local SLEW_TOLERANCE = 2.0 -- seconds; beyond this, snap
local SLEW_RATE = 0.05 -- seconds of correction per second of wall time

export type Schedule = {
    roundId: string?,
    strikeAt: number,
    periodSec: number,
    activeSec: number,
    tallySec: number,
    revealSec: number,
}

export type Reading = {
    drawP: number,
    camAngle: number,
    omega: number,
    periodSec: number,
    prevStrikeAt: number,
    nextStrikeAt: number,
}

function RoundMetronome.new()
    return setmetatable({
        _strikeAt = nil :: number?, -- effective anchor (one strike instant)
        _targetStrikeAt = nil :: number?,
        _periodSec = nil :: number?,
        _activeSec = 0,
        _tallySec = 0,
        _revealSec = 0,
        _lastNow = nil :: number?,
    }, RoundMetronome)
end

-- Strike instants tile every period: map the incoming anchor into the congruence
-- class nearest the current one, so a next-round schedule isn't read as a shift.
local function nearest(strikeAt: number, period: number, ref: number): number
    return strikeAt + math.round((ref - strikeAt) / period) * period
end

function RoundMetronome.setSchedule(self: any, sched: Schedule, _now: number)
    self._activeSec = sched.activeSec
    self._tallySec = sched.tallySec
    self._revealSec = sched.revealSec
    if self._strikeAt == nil or self._periodSec ~= sched.periodSec then
        -- first schedule, or a period change (e.g. the 20s->60s launch): adopt
        self._strikeAt = sched.strikeAt
        self._targetStrikeAt = sched.strikeAt
        self._periodSec = sched.periodSec
        return
    end
    local target = nearest(sched.strikeAt, sched.periodSec, self._strikeAt)
    if math.abs(target - self._strikeAt) > SLEW_TOLERANCE then
        self._strikeAt = sched.strikeAt -- hard re-anchor (restart / discontinuity)
        self._targetStrikeAt = sched.strikeAt
    else
        self._targetStrikeAt = target -- converge inside read()
    end
end

function RoundMetronome.read(self: any, now: number): Reading?
    local period: number? = self._periodSec
    local strike: number? = self._strikeAt
    if period == nil or strike == nil then
        return nil
    end
    local target: number = self._targetStrikeAt or strike
    if target ~= strike then
        local dt = math.max(0, now - (self._lastNow or now))
        local maxStep = SLEW_RATE * dt
        local step = math.clamp(target - strike, -maxStep, maxStep)
        strike += step
        self._strikeAt = strike
    end
    self._lastNow = now
    local omega = 2 * math.pi / period
    local k = math.floor((now - strike) / period)
    local prevStrikeAt = strike + k * period -- last instant <= now
    local nextStrikeAt = prevStrikeAt + period
    local camAngle = omega * (now - prevStrikeAt) -- == 0 (mod 2pi) at every strike
    -- the round containing `now`: starts active+tally before its own strike
    local anchorStart = strike - (self._activeSec + self._tallySec)
    local roundStart = anchorStart + math.floor((now - anchorStart) / period) * period
    local drawP = math.clamp((now - roundStart) / period, 0, 1)
    return {
        drawP = drawP,
        camAngle = camAngle,
        omega = omega,
        periodSec = period,
        prevStrikeAt = prevStrikeAt,
        nextStrikeAt = nextStrikeAt,
    }
end

-- Number of strike instants in (t0, t1].
function RoundMetronome.strikesBetween(self: any, t0: number, t1: number): number
    local period: number? = self._periodSec
    local strike: number? = self._strikeAt
    if period == nil or strike == nil or t1 <= t0 then
        return 0
    end
    return math.floor((t1 - strike) / period) - math.floor((t0 - strike) / period)
end

return RoundMetronome
```

- [ ] **Step 4: Verify green + lint**

Run: `lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: all tests pass (new suite included), lint clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/RoundMetronome.luau roblox/tests/RoundMetronome.spec.luau
git commit -m "feat(roblox): RoundMetronome — pure scheduled round timeline with slew"
```

---

### Task 5: HammerController runs off the metronome

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau`

**Interfaces:**
- Consumes: `ReplicatedStorage.RoundScheduleConfig` attributes (Task 3 names), `RoundMetronome` API (Task 4).
- Produces: unchanged externals — `DriveOmega` stage attribute (now `driverDir * CAM_DIR * omega * REDUCTION`), the swing → `gongHit` EventBus cue at contact, `CamPhaseDeg`/`DrawStuds`/`DrawHold`/`JackDir`/`DriverDir` knobs.

This task deletes the measured clock and both event anchors. Concretely:

- [ ] **Step 1: Require + wire the metronome**

Near the module's other requires (it already has `local shared = ReplicatedStorage:WaitForChild("RoshamboShared")` for CamProfile/CamMesh; if the local is named differently, match it):

```lua
local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))

-- The published round schedule (RoundScheduleConfig) drives ALL timing; see the
-- round-metronome spec. StrikeAtServerTime is written last on the server, so one
-- changed-signal on it pulls a coherent schedule.
local metronome = RoundMetronome.new()
local scheduleConfig = ReplicatedStorage:WaitForChild("RoundScheduleConfig")
local function pullSchedule()
    local strikeAt = scheduleConfig:GetAttribute("StrikeAtServerTime")
    local periodSec = scheduleConfig:GetAttribute("PeriodSec")
    if typeof(strikeAt) ~= "number" or typeof(periodSec) ~= "number" then
        return
    end
    metronome:setSchedule({
        roundId = scheduleConfig:GetAttribute("RoundId") :: string?,
        strikeAt = strikeAt,
        periodSec = periodSec,
        activeSec = (scheduleConfig:GetAttribute("ActiveSec") :: number?) or 20,
        tallySec = (scheduleConfig:GetAttribute("TallySec") :: number?) or 2,
        revealSec = (scheduleConfig:GetAttribute("RevealSec") :: number?) or 3,
    }, workspace:GetServerTimeNow())
end
scheduleConfig:GetAttributeChangedSignal("StrikeAtServerTime"):Connect(pullSchedule)
pullSchedule()
```

- [ ] **Step 2: Delete the measured clock**

Remove entirely:
- `local camOmega = 2 * math.pi / 22 ...` (~line 102) and the stale comment block above it about measuring the round rate (keep the drive-train header from the docs commit, minus the "camOmega is the measured round rate…" sentences).
- `local lastActiveAt: number? = nil`, `local omegaLocked = false`, `local prevRoundId` (wherever declared), `local anchorAt: number? = nil` (KEEP `anchorNet` — the strike still geometrically pins the high point; add `local anchorAt: number? = nil` back ONLY as the scheduled strike time, see Step 4).
- Inside the `RoundUpdate.OnClientEvent` handler: delete the whole period-measurement block; the handler shrinks to:

```lua
RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        striking = false -- new round: the draw ramp owns the log again
    end
end)
```

- [ ] **Step 3: Draw heartbeat reads the metronome**

Replace the draw Heartbeat's `p` computation (`local period = if camOmega > 0 ... p = math.clamp(...)`) with:

```lua
    local p
    if hold then
        p = 1
    else
        local r = metronome:read(workspace:GetServerTimeNow())
        if not r then
            return -- no schedule yet: hold rest pose
        end
        p = r.drawP
    end
```

(The surrounding `DrawHold`/`striking` logic and the `arm.CFrame` line stay as they are.)

- [ ] **Step 4: Strike becomes self-timed; cam free-runs between scheduled strikes**

Refactor the `EventBus.Cue.Event:Connect(... "gongStrike" ...)` handler into a named function and delete the EventBus subscription (nothing emits `gongStrike` after Task 6):

```lua
-- The strike is SELF-TIMED from the metronome (spec: strike on schedule; late
-- reveal data is absorbed by the drum, never by the bell). `atTime` is the
-- scheduled strike instant: the cam anchors there, not at frame time.
local function strike(atTime: number)
    striking = true
    local dp = dowels[1].Position
    local fineDeg = (stage:GetAttribute("CamPhaseDeg") :: number) or CAM_PHASE_DEG
    anchorNet = math.atan2(dp.Z - CAM_AXLE_YZ.Y, dp.Y - CAM_AXLE_YZ.X) + math.rad(fineDeg)
    anchorAt = atTime
    -- ... (the ENTIRE existing swing/gongHit/light/ring/splash/recoil body,
    --      unchanged, from `local swing = TweenService:Create(` to `swing:Play()`)
end
```

In the cam Heartbeat, replace the camNet derivation (`local camNet ... if anchorNet and anchorAt then ... else ... end`) and the omega uses with:

```lua
    local nowSt = workspace:GetServerTimeNow()
    local r = metronome:read(nowSt)
    if r == nil then
        return
    end
    if lastMetroNow and not striking and metronome:strikesBetween(lastMetroNow, nowSt) > 0 then
        strike(r.prevStrikeAt)
    end
    lastMetroNow = nowSt
    local camNet
    if anchorNet and anchorAt then
        camNet = anchorNet + CAM_DIR * r.omega * (nowSt - anchorAt)
    else
        -- before this client's first strike: constant-speed free-run, phase-locked
        -- to the strike instants (high point lands near the dowel from round one)
        camNet = CAM_DIR * r.camAngle
    end
```

Add `local lastMetroNow: number? = nil` next to `anchorNet`/`anchorAt`. Every later use of `camOmega` in this Heartbeat (driver `drot`, jack `jrot`, the `DriveOmega` publish) becomes `r.omega`:

```lua
    stage:SetAttribute("DriveOmega", driverDir * CAM_DIR * r.omega * REDUCTION)
```

- [ ] **Step 5: Verify + lint**

Run: `lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: green (controller has no Lune coverage; this catches syntax/lint). Then grep for leftovers — `grep -n "camOmega\|omegaLocked\|lastActiveAt\|prevRoundId" src/client/HammerController.client.luau` must return nothing.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/client/HammerController.client.luau
git commit -m "feat(roblox): HammerController runs off the RoundMetronome — measured clock deleted"
```

---

### Task 6: gongStrike leaves the choreography; drum spins until the data lands

**Files:**
- Modify: `roblox/src/shared/ChoreographyMachine.luau` (revealCues seed list, ~line 28)
- Modify: `roblox/tests/ChoreographyMachine.spec.luau` (~line 50 kinds assertion; scan the file for other gongStrike expectations)
- Modify: `roblox/src/client/DrumController.client.luau` (gongHit handler ~line 209; spin→glide gate ~line 146)

**Interfaces:**
- Consumes: `gongHit` cue (unchanged, from Task 5's swing contact).
- Produces: `revealCues` no longer emits `gongStrike` (Hammer self-times). Drum behavior: spins on every `gongHit`; glides only once `latestWorldThrow` is present (or a 6 s stall cap), landing that throw; clears the stored throw on use.

- [ ] **Step 1: Update the choreography spec expectation (failing test first)**

In `roblox/tests/ChoreographyMachine.spec.luau` line ~50:

```lua
        expect(kinds).toEqual({ "drumrollStop", "basinErupt", "heroTileLand" })
```

Scan the rest of the spec for `gongStrike` and remove/renumber any other occurrence. Run `lune run tests/run` — expect this spec to FAIL against the unmodified module.

- [ ] **Step 2: Remove the cue**

In `roblox/src/shared/ChoreographyMachine.luau`, the seed list becomes:

```lua
        {
            { atMs = 0, idx = 1, kind = "drumrollStop" },
            { atMs = 0, idx = 2, kind = "basinErupt" },
            { atMs = 0, idx = 3, kind = "heroTileLand", worldThrow = reveal.worldThrow },
        }
```

(`gongStrike` is self-timed by HammerController since Task 5.) Run `lune run tests/run` — green.

- [ ] **Step 3: Drum — spin always, glide on data**

In `roblox/src/client/DrumController.client.luau`:

Near `local latestWorldThrow: string? = nil` add:

```lua
local lastLandedThrow: string? = nil
local STALL_MAX = 6 -- s past min spin to wait for the reveal before settling anyway
```

The gongHit handler loses its no-data bail (the strike is now scheduled; data may
still be in flight — that's the point):

```lua
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongHit" then
        omega = (stage:GetAttribute("DrumKick") :: number) or DRUM_KICK
        spinUntil = os.clock() + SPIN_SEC
        strikeT0 = os.clock()
        mode = "spin"
        -- the dowel smacks the paddle: fast 90° to rest PARALLEL to the log
        kickState = "flick"
        kickBase = kickAngle
        kickTarget = kickAngle + math.pi / 2
        kickDur = KICK_FLICK_DUR
        kickT0 = os.clock()
    end
end)
```

In the Heartbeat's spin branch, the glide gate waits for the data (consume-on-use;
the one RevealTheater arrival between strikes is this round's by construction):

```lua
    if mode == "spin" then
        theta -= omega * _dt
        local haveThrow = latestWorldThrow ~= nil
        if os.clock() >= spinUntil and (haveThrow or os.clock() >= spinUntil + STALL_MAX) then
            local throw = latestWorldThrow or lastLandedThrow or "R"
            lastLandedThrow = throw
            latestWorldThrow = nil
            landTheta = landTargetFor(throw, omega * GLIDE_SEC / 2)
            glideP0 = theta
            glideD = theta - landTheta
            glideT0 = os.clock()
            mode = "glide"
        end
        applyTheta()
```

(The existing stuck-guard in the `RoundUpdate` handler stays as the final backstop.)

- [ ] **Step 4: Verify + lint**

Run: `lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/ChoreographyMachine.luau roblox/tests/ChoreographyMachine.spec.luau roblox/src/client/DrumController.client.luau
git commit -m "feat(roblox): strike self-timed — choreography drops gongStrike; drum spins until the reveal lands"
```

---

### Task 7: Full verification + live Play gate

**Files:** none (verification only)

- [ ] **Step 1: Full local CI parity**

From `roblox/`: `lune run tests/run && lune run tools/genmodels && git status --short assets && stylua --check src tests tools && selene src tools`
From `server/`: `npm test && npm run build`
Expected: everything green; `assets/` diff empty (this plan generates no model changes).

- [ ] **Step 2: Push and confirm CI**

```bash
git push
gh run list --limit 3
```

Expected: `roblox-ci` and `server-ci` both `success` (note: this machine's old gh CLI has no `--json`/`--branch` flags).

- [ ] **Step 3: Live Play gate (user at the wheel)**

Ask the user to Play in Studio and verify, in order:
1. Wheel/gears turn at a stately constant rate from the first seconds (period 25 s ⇒ wheel ~12.5 s/rev), across SEVERAL Stop/Play cycles — including starting mid-round (the racing-wheel regression).
2. The bell strikes on cadence every ~25 s; the cam cliff meets the dowel at each release.
3. The drum spins on the strike and settles on the correct World Throw shortly after (data arrives ~during the spin); no early return before data.
4. `DriveOmega` on RoshamboStage reads ~0.50 rad/s (2π/25 × 2) every session.

STOP after this gate and wait for the user's verdict before any further polish (standing rule: one attempt, then ask).
