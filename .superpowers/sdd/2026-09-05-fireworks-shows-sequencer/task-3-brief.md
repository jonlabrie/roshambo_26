### Task 3: `ShowPlayer.luau` — the pure timeline and per-stage scheduling

**Files:**
- Create: `roblox/src/shared/ShowPlayer.luau`
- Test: `roblox/tests/ShowPlayer.spec.luau`

**Interfaces:**
- Consumes: `ShowPlan.Cue`.
- Produces (module `ShowPlayer`):
  - `ShowPlayer.TAIL_MS = 6000`
  - `ShowPlayer.durationMs(cues): number` — last `t_ms` + `TAIL_MS`
  - `ShowPlayer.schedule(busyUntilMs: number?, nowMs: number, cues): { startAtMs: number, endAtMs: number }` — starts now if the stage is free, else the moment it frees
  - `ShowPlayer.timeline(cues, startAtMs: number): { { atMs: number, index: number, cue: Cue } }` — one entry per cue, in order, `index` one-based (Luau side; it is only used to name a cue in logs)
  - `ShowPlayer.delaysFrom(nowMs, timeline): { number }` — seconds to wait from now for each entry, never negative

- [ ] **Step 1: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShowPlayer = require("../src/shared/ShowPlayer")

local CUES = {
    { t_ms = 0, slot = "hand", shellId = "firecracker" },
    { t_ms = 1500, slot = "mortar:S", shellId = "peony" },
    { t_ms = 1500, slot = "mortar:M", shellId = "wa" },
    { t_ms = 4000, slot = "mortar:L", shellId = "kamuro" },
}

describe("ShowPlayer.durationMs", function()
    test("last cue plus the tail", function()
        expect(ShowPlayer.durationMs(CUES)).toBe(4000 + ShowPlayer.TAIL_MS)
    end)
    test("a one-cue show is just the tail", function()
        expect(ShowPlayer.durationMs({ CUES[1] })).toBe(ShowPlayer.TAIL_MS)
    end)
end)

describe("ShowPlayer.schedule -- one show per stage at a time", function()
    test("a free stage starts now", function()
        expect(ShowPlayer.schedule(nil, 10000, CUES)).toEqual({ startAtMs = 10000, endAtMs = 10000 + 4000 + ShowPlayer.TAIL_MS })
    end)
    test("a stage busy in the past is free", function()
        expect(ShowPlayer.schedule(9000, 10000, CUES).startAtMs).toBe(10000)
    end)
    test("a busy stage queues the show behind the current one", function()
        local s = ShowPlayer.schedule(12500, 10000, CUES)
        expect(s.startAtMs).toBe(12500)
        expect(s.endAtMs).toBe(12500 + 4000 + ShowPlayer.TAIL_MS)
    end)
end)

describe("ShowPlayer.timeline / delaysFrom", function()
    test("one entry per cue, in order, offset by the start", function()
        local tl = ShowPlayer.timeline(CUES, 5000)
        expect(#tl).toBe(4)
        expect(tl[1]).toEqual({ atMs = 5000, index = 1, cue = CUES[1] })
        expect(tl[3]).toEqual({ atMs = 6500, index = 3, cue = CUES[3] })
        expect(tl[4].atMs).toBe(9000)
    end)
    test("delays are seconds from now and never negative", function()
        local tl = ShowPlayer.timeline(CUES, 5000)
        expect(ShowPlayer.delaysFrom(5000, tl)).toEqual({ 0, 1.5, 1.5, 4 })
        expect(ShowPlayer.delaysFrom(6000, tl)).toEqual({ 0, 0.5, 0.5, 3 })
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3`
Expected: fails on the missing module.

- [ ] **Step 3: Write minimal implementation**

```lua
--!strict
-- WHEN EACH CUE FIRES. Pure: the game server owns the clock and task.delay; this module only
-- turns a show plus a start time into the moments to fire, and decides when a show may start on
-- a stage that is already playing one (spec §2.5: one show per stage at a time; a second go
-- queues behind the current show on that stage only). Testable under Lune because it never
-- touches a service.
local ShowPlayer = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Entry = { atMs: number, index: number, cue: Cue }

-- How long after the LAST cue a stage stays busy: enough for the tallest shell to burst and fade.
ShowPlayer.TAIL_MS = 6000

function ShowPlayer.durationMs(cues: { Cue }): number
    local last = 0
    for _, c in cues do
        if c.t_ms > last then
            last = c.t_ms
        end
    end
    return last + ShowPlayer.TAIL_MS
end

function ShowPlayer.schedule(busyUntilMs: number?, nowMs: number, cues: { Cue }): { startAtMs: number, endAtMs: number }
    local startAt = nowMs
    if busyUntilMs ~= nil and busyUntilMs > nowMs then
        startAt = busyUntilMs
    end
    return { startAtMs = startAt, endAtMs = startAt + ShowPlayer.durationMs(cues) }
end

function ShowPlayer.timeline(cues: { Cue }, startAtMs: number): { Entry }
    local out: { Entry } = {}
    for i, c in ipairs(cues) do
        table.insert(out, { atMs = startAtMs + c.t_ms, index = i, cue = c })
    end
    return out
end

function ShowPlayer.delaysFrom(nowMs: number, timeline: { Entry }): { number }
    local out = {}
    for _, e in timeline do
        table.insert(out, math.max(0, (e.atMs - nowMs) / 1000))
    end
    return out
end

return ShowPlayer
```

- [ ] **Step 4: Run tests, format and lint**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`
Expected: green and clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/ShowPlayer.luau roblox/tests/ShowPlayer.spec.luau
git commit -m "feat(shows): ShowPlayer.luau -- pure timeline and one-show-per-stage scheduling

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

