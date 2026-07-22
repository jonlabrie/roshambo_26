# Day/Night Cycle Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a server-authoritative, globally-synced, night-dominant day/night cycle for the ZenDojo arena that takes over `Lighting` and publishes a single `nightFactor ∈ [0,1]` on the client `EventBus` for visual systems to bind to.

**Architecture:** A pure, Lune-tested core (`DayNight.luau`, no Roblox types) maps a normalized cycle position `t ∈ [0,1)` → phase + `nightFactor` + a plain-data Lighting state. The server publishes fixed cycle constants (`CycleEpoch`, `CycleLength`, `PhaseOffset`) once at boot as attributes on `ReplicatedStorage.DayNightConfig`. Each client derives `t` locally from `workspace:GetServerTimeNow()` (Roblox's globally-synced Unix clock) + the fixed epoch, applies the Lighting state, and fires `EventBus.DayNight` when `nightFactor` changes. No per-frame network traffic; every player in every server instance sees the same time-of-day at the same real moment.

**Tech Stack:** Luau, Rojo, Lune (headless test harness at `roblox/tests/`), the milestone-4a client `EventBus` (`BindableEvent` table).

## Global Constraints

- **Lune-safe core:** `DayNight.luau` must not reference `Instance`, `Color3`, `Enum`, `workspace`, `game`, or any Roblox global at module scope or in any function. Colors are `{r, g, b}` arrays (0–1); everything else is numbers/strings/tables. (It runs under both Lune tests and the Roblox client.)
- **Phase proportions (as `t`-fractions of one loop, must sum to 1):** dawn `[0.00, 0.10)` 10%, day `[0.10, 0.28)` 18%, dusk `[0.28, 0.53)` 25%, night `[0.53, 1.00)` 47%.
- **`nightFactor` contract:** exactly `0` through day, exactly `1` through night, smoothstepped `1→0` across dawn and `0→1` across dusk; continuous at every band boundary.
- **Global clock:** `t = ((workspace:GetServerTimeNow() − CycleEpoch) / CycleLength + PhaseOffset) % 1`. `CycleEpoch` is a **fixed absolute constant** baked into the server (NOT boot time). Starting `CycleLength = 1200` (20 min), `PhaseOffset = 0`.
- **EventBus channel name:** exactly `"DayNight"`, payload `{ t: number, nightFactor: number, phase: string }`, `phase ∈ {"dawn","day","dusk","night"}`.
- **Test harness:** Lune specs live at `roblox/tests/<Name>.spec.luau`, use `require("./harness")` → `describe, test, expect`; matchers available are `toBe`, `toEqual`, `toBeCloseTo`, `toBeTruthy`, `toBeNil`. Run with `lune run tests/run` from `roblox/`.
- **Lint before commit:** `stylua --check src tests && selene src` from `roblox/`.
- **No gameplay change:** purely visual/ambient. Does not touch round logic, the World Throw, or any RemoteEvent.

---

## File Structure

- **Create `roblox/src/shared/DayNight.luau`** — pure core: `PHASES`, `smoothstep`, `phaseAt(t)`, `lightingAt(t)`. Auto-synced into `ReplicatedStorage.RoshamboShared` by Rojo (the whole `src/shared` dir is already mapped).
- **Create `roblox/tests/DayNight.spec.luau`** — Lune tests for the pure core.
- **Create `roblox/src/client/DayNightController.client.luau`** — standalone auto-running `LocalScript` (same pattern as `ChochinSway.client.luau`): reads config, derives `t`, applies `Lighting`, fires `EventBus.DayNight`, exposes the current payload to late subscribers via an attribute on the config object.
- **Modify `roblox/src/client/EventBus.luau`** — add `"DayNight"` to `NAMES`.
- **Modify `roblox/src/server/main.server.luau`** — publish `ReplicatedStorage.DayNightConfig` (a `Configuration` instance) with the three attributes at boot.

Note: `*.client.luau` controllers auto-run (they are not started by `main.client.luau` — e.g. `ChochinSway.client.luau` is standalone), so `main.client.luau` needs **no** change.

---

## Task 1: `DayNight.luau` pure core

**Files:**
- Create: `roblox/src/shared/DayNight.luau`
- Test: `roblox/tests/DayNight.spec.luau`

**Interfaces:**
- Consumes: nothing (leaf module).
- Produces:
  - `DayNight.PHASES: { { name: string, from: number, to: number } }` — 4 ordered bands.
  - `DayNight.phaseAt(t: number) -> { nightFactor: number, phase: string }` — `t` normalized internally via `% 1`.
  - `DayNight.lightingAt(t: number) -> { clockTime: number, brightness: number, outdoorAmbient: {number}, ambient: {number}, fogEnd: number, fogColor: {number}, ccTint: {number}, ccBrightness: number }` — `clockTime` monotonic increasing `5 → 29` across the loop (client applies `% 24`); colors are `{r,g,b}` 0–1.

- [ ] **Step 1: Write the failing test file**

Create `roblox/tests/DayNight.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local DayNight = require("../src/shared/DayNight")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- a t sitting squarely inside each band
local MID = { dawn = 0.05, day = 0.19, dusk = 0.405, night = 0.76 }

describe("DayNight pure core", function()
    test("PHASES cover [0,1) contiguously and sum to 1", function()
        expect(#DayNight.PHASES).toBe(4)
        expect(DayNight.PHASES[1].from).toBe(0)
        expect(DayNight.PHASES[4].to).toBe(1)
        local total = 0
        local cursor = 0
        for _, band in DayNight.PHASES do
            expect(band.from).toBeCloseTo(cursor) -- no gaps/overlaps
            total += band.to - band.from
            cursor = band.to
        end
        expect(total).toBeCloseTo(1)
    end)

    test("phaseAt names the right band in each band", function()
        expect(DayNight.phaseAt(MID.dawn).phase).toBe("dawn")
        expect(DayNight.phaseAt(MID.day).phase).toBe("day")
        expect(DayNight.phaseAt(MID.dusk).phase).toBe("dusk")
        expect(DayNight.phaseAt(MID.night).phase).toBe("night")
    end)

    test("nightFactor is exactly 0 through day and 1 through night", function()
        expect(DayNight.phaseAt(0.15).nightFactor).toBe(0)
        expect(DayNight.phaseAt(MID.day).nightFactor).toBe(0)
        expect(DayNight.phaseAt(MID.night).nightFactor).toBe(1)
        expect(DayNight.phaseAt(0.99).nightFactor).toBe(1)
    end)

    test("nightFactor is continuous at every band boundary", function()
        -- sample just inside each boundary from both sides; the gap must be tiny
        local eps = 1e-4
        for _, b in { 0.10, 0.28, 0.53 } do
            local lo = DayNight.phaseAt(b - eps).nightFactor
            local hi = DayNight.phaseAt(b + eps).nightFactor
            expect(math.abs(hi - lo) < 0.01).toBe(true)
        end
        -- wrap boundary t=0: end-of-night (→1) meets start-of-dawn (→1)
        expect(DayNight.phaseAt(0.0).nightFactor).toBeCloseTo(1)
    end)

    test("nightFactor decreases monotonically across dawn (1→0)", function()
        local prev = 2
        for i = 0, 10 do
            local nf = DayNight.phaseAt(0.10 * (i / 10) * 0.999).nightFactor
            expect(nf <= prev + 1e-6).toBe(true)
            prev = nf
        end
        expect(prev < 0.05).toBe(true) -- reached ~0 by end of dawn
    end)

    test("nightFactor increases monotonically across dusk (0→1)", function()
        local prev = -1
        for i = 0, 10 do
            local t = 0.28 + (0.53 - 0.28) * (i / 10) * 0.999
            local nf = DayNight.phaseAt(t).nightFactor
            expect(nf >= prev - 1e-6).toBe(true)
            prev = nf
        end
        expect(prev > 0.95).toBe(true)
    end)

    test("phaseAt normalizes t outside [0,1)", function()
        expect(DayNight.phaseAt(1.19).phase).toBe("day") -- 1.19 % 1 = 0.19
        expect(DayNight.phaseAt(-0.81).phase).toBe("day") -- -0.81 % 1 = 0.19
    end)

    test("lightingAt returns in-range values", function()
        for _, t in MID do
            local L = DayNight.lightingAt(t)
            expect(L.brightness >= 0 and L.brightness <= 3).toBe(true)
            expect(L.fogEnd > 0).toBe(true)
            for _, ch in L.outdoorAmbient do
                expect(ch >= 0 and ch <= 1).toBe(true)
            end
            for _, ch in L.fogColor do
                expect(ch >= 0 and ch <= 1).toBe(true)
            end
        end
    end)

    test("lightingAt clockTime is monotonic increasing across the loop (5→29)", function()
        local prev = -1
        for i = 0, 40 do
            local ct = DayNight.lightingAt((i / 41)).clockTime
            expect(ct >= prev - 1e-6).toBe(true)
            prev = ct
        end
        expect(DayNight.lightingAt(0).clockTime).toBeCloseTo(5)
        expect(DayNight.lightingAt(0.999).clockTime < 29.01).toBe(true)
    end)

    test("day is brighter than night", function()
        expect(DayNight.lightingAt(MID.day).brightness > DayNight.lightingAt(MID.night).brightness).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -20`
Expected: FAIL — errors that `../src/shared/DayNight` cannot be required (module doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `roblox/src/shared/DayNight.luau`:

```lua
--!strict
-- Pure, Lune-safe core of the day/night cycle. Maps a normalized cycle position
-- t ∈ [0,1) (uniform time) to the current phase, a normalized nightFactor, and a
-- plain-data Lighting state the client applies. NO Roblox types here (no Color3/
-- Enum/Instance/workspace) — colors are {r,g,b} arrays 0–1; it runs under both the
-- Lune tests and the Roblox client. See docs/.../2026-07-22-day-night-cycle-design.md.
local DayNight = {}

-- Night-dominant proportions as t-fractions of one loop; MUST stay contiguous + sum to 1.
DayNight.PHASES = {
    { name = "dawn", from = 0.00, to = 0.10 }, -- nightFactor ramps 1 → 0
    { name = "day", from = 0.10, to = 0.28 }, -- nightFactor 0
    { name = "dusk", from = 0.28, to = 0.53 }, -- the amber "magic hour"; ramps 0 → 1
    { name = "night", from = 0.53, to = 1.00 }, -- nightFactor 1 (the primary state)
}

local function smoothstep(x: number): number
    if x <= 0 then
        return 0
    elseif x >= 1 then
        return 1
    end
    return x * x * (3 - 2 * x)
end

local function frac(t: number): number
    return t - math.floor(t) -- normalize any real into [0,1)
end

-- phase + normalized nightFactor at cycle position t.
function DayNight.phaseAt(t: number): { nightFactor: number, phase: string }
    local x = frac(t)
    if x < 0.10 then
        -- dawn: 1 → 0
        return { phase = "dawn", nightFactor = 1 - smoothstep(x / 0.10) }
    elseif x < 0.28 then
        return { phase = "day", nightFactor = 0 }
    elseif x < 0.53 then
        -- dusk: 0 → 1
        return { phase = "dusk", nightFactor = smoothstep((x - 0.28) / (0.53 - 0.28)) }
    else
        return { phase = "night", nightFactor = 1 }
    end
end

-- Starting mood targets (gate-tuned in Play). Colors are {r,g,b} 0–1.
local DAY = {
    brightness = 2.0,
    outdoorAmbient = { 0.55, 0.55, 0.55 },
    ambient = { 0.35, 0.35, 0.35 },
    fogEnd = 4000,
    fogColor = { 0.78, 0.82, 0.88 },
    ccTint = { 1.0, 1.0, 1.0 },
    ccBrightness = 0.0,
}
local NIGHT = {
    brightness = 0.4,
    outdoorAmbient = { 0.10, 0.12, 0.18 }, -- moonlit blue-grey, NOT pitch black (playability)
    ambient = { 0.06, 0.07, 0.11 },
    fogEnd = 1200,
    fogColor = { 0.05, 0.07, 0.12 },
    ccTint = { 0.75, 0.82, 1.0 }, -- cool
    ccBrightness = -0.05,
}

local function lerp(a: number, b: number, k: number): number
    return a + (b - a) * k
end
local function lerp3(a: { number }, b: { number }, k: number): { number }
    return { lerp(a[1], b[1], k), lerp(a[2], b[2], k), lerp(a[3], b[3], k) }
end

-- clockTime swept per band so the built-in sun/moon matches the night-dominant schedule.
-- Monotonic increasing 5 → 29 over the loop; the client applies (clockTime % 24).
local CLOCK = {
    { to = 0.10, a = 5, b = 8 }, -- dawn
    { to = 0.28, a = 8, b = 16 }, -- day
    { to = 0.53, a = 16, b = 19 }, -- dusk
    { to = 1.00, a = 19, b = 29 }, -- night (29 % 24 = 5, i.e. wraps to next dawn)
}
local function clockAt(x: number): number
    local from = 0
    for _, band in CLOCK do
        if x < band.to then
            return lerp(band.a, band.b, (x - from) / (band.to - from))
        end
        from = band.to
    end
    return 29
end

-- Plain-data Lighting state at cycle position t.
function DayNight.lightingAt(t: number): {
    clockTime: number,
    brightness: number,
    outdoorAmbient: { number },
    ambient: { number },
    fogEnd: number,
    fogColor: { number },
    ccTint: { number },
    ccBrightness: number,
}
    local x = frac(t)
    local nf = DayNight.phaseAt(x).nightFactor
    return {
        clockTime = clockAt(x),
        brightness = lerp(DAY.brightness, NIGHT.brightness, nf),
        outdoorAmbient = lerp3(DAY.outdoorAmbient, NIGHT.outdoorAmbient, nf),
        ambient = lerp3(DAY.ambient, NIGHT.ambient, nf),
        fogEnd = lerp(DAY.fogEnd, NIGHT.fogEnd, nf),
        fogColor = lerp3(DAY.fogColor, NIGHT.fogColor, nf),
        ccTint = lerp3(DAY.ccTint, NIGHT.ccTint, nf),
        ccBrightness = lerp(DAY.ccBrightness, NIGHT.ccBrightness, nf),
    }
end

return DayNight
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd roblox && lune run tests/run 2>&1 | tail -5`
Expected: all specs pass (the total count rises by the DayNight cases; `0 failed`).

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no diff from stylua; `0 errors 0 warnings` from selene. (If stylua reports a diff, run `stylua src tests` and re-check.)

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/DayNight.luau roblox/tests/DayNight.spec.luau
git commit -m "feat(roblox): DayNight pure core — phaseAt/lightingAt (night-dominant, Lune-tested)"
```

---

## Task 2: EventBus contract + server config publish

**Files:**
- Modify: `roblox/src/client/EventBus.luau:4`
- Modify: `roblox/src/server/main.server.luau` (add a boot-time config publish near the top, after `ReplicatedStorage` is defined ~line 4)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `EventBus.DayNight` — a `BindableEvent`; fire with `EventBus.DayNight:Fire({ t, nightFactor, phase })`, subscribe with `EventBus.DayNight.Event:Connect(fn)`.
  - `ReplicatedStorage.DayNightConfig` — a `Configuration` instance with number attributes `CycleEpoch`, `CycleLength`, `PhaseOffset`, replicated to all clients.

- [ ] **Step 1: Add the EventBus channel**

In `roblox/src/client/EventBus.luau`, change line 4 from:

```lua
local NAMES = { "Cue", "TickerMessage", "MoveTeahouse", "MoveDecoration" }
```

to:

```lua
local NAMES = { "Cue", "TickerMessage", "MoveTeahouse", "MoveDecoration", "DayNight" }
```

- [ ] **Step 2: Publish the config at server boot**

In `roblox/src/server/main.server.luau`, immediately after the service `local`s at the top of the file (after the line `local LocalizationService = game:GetService("LocalizationService")`, ~line 6), insert:

```lua
-- Day/Night cycle: publish the fixed, global cycle constants once at boot as attributes on a
-- replicated Configuration. Clients derive t locally from workspace:GetServerTimeNow() (Roblox's
-- globally-synced Unix clock) + this FIXED epoch, so every player in every server instance sees the
-- same time-of-day at the same real moment. The server streams nothing afterward. (Foundation only;
-- the glyph/waterfall subscribers bind to EventBus.DayNight — see the day/night design spec.)
local DAY_NIGHT_EPOCH = 1735689600 -- fixed absolute anchor (2025-01-01T00:00:00Z, synced Unix seconds)
local dayNightConfig = Instance.new("Configuration")
dayNightConfig.Name = "DayNightConfig"
dayNightConfig:SetAttribute("CycleEpoch", DAY_NIGHT_EPOCH)
dayNightConfig:SetAttribute("CycleLength", 1200) -- seconds per full loop (20 min); gate-tuned
dayNightConfig:SetAttribute("PhaseOffset", 0) -- fraction, aligns the global clock; gate-tuned
dayNightConfig.Parent = ReplicatedStorage
```

- [ ] **Step 3: Verify the config replicates (Studio)**

Start `rojo serve` (from `roblox/`) and connect the Rojo plugin, then Play. In the command bar or an `execute_luau` (Client datamodel):

```lua
local cfg = game:GetService("ReplicatedStorage"):FindFirstChild("DayNightConfig")
return cfg
    and string.format(
        "epoch=%s length=%s offset=%s",
        tostring(cfg:GetAttribute("CycleEpoch")),
        tostring(cfg:GetAttribute("CycleLength")),
        tostring(cfg:GetAttribute("PhaseOffset"))
    )
    or "no DayNightConfig"
```

Expected: `epoch=1735689600 length=1200 offset=0`.

- [ ] **Step 4: Lint + tests**

Run: `cd roblox && stylua --check src tests && selene src && lune run tests/run 2>&1 | tail -3`
Expected: lint clean; tests still `0 failed` (no new unit tests — this task is runtime-verified in Step 3).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/EventBus.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): DayNight EventBus channel + server publishes global cycle config"
```

---

## Task 3: `DayNightController.client.luau` renderer

**Files:**
- Create: `roblox/src/client/DayNightController.client.luau`

**Interfaces:**
- Consumes:
  - `DayNight.phaseAt`, `DayNight.lightingAt` from `ReplicatedStorage.RoshamboShared.DayNight`.
  - `EventBus.DayNight` from `script.Parent.EventBus`.
  - `ReplicatedStorage.DayNightConfig` attributes `CycleEpoch`, `CycleLength`, `PhaseOffset`.
- Produces:
  - Fires `EventBus.DayNight:Fire({ t, nightFactor, phase })` whenever `nightFactor` changes by ≥ ε (0.002) or the phase name changes.
  - Writes the current payload onto `DayNightConfig` attributes `CurrentNightFactor` (number), `CurrentPhase` (string), `CurrentT` (number) each fire, so a late-joining subscriber reads the current value immediately (no replay on a BindableEvent).

- [ ] **Step 1: Write the controller**

Create `roblox/src/client/DayNightController.client.luau`:

```lua
--!strict
-- Renders the day/night cycle on this client and publishes the nightFactor contract.
-- Standalone auto-running LocalScript (like ChochinSway.client.luau) — nothing starts it.
-- Reads the fixed global cycle constants from ReplicatedStorage.DayNightConfig, derives t from
-- workspace:GetServerTimeNow() (globally-synced Unix clock) so every client/instance agrees,
-- applies Lighting (+ Atmosphere/ColorCorrection children, created once), and fires
-- EventBus.DayNight when nightFactor moves. It also stamps the current payload back onto the
-- config's attributes so a subscriber that starts mid-cycle reads the current value at once.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DayNight = require(shared:WaitForChild("DayNight"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

local function c3(rgb: { number }): Color3
    return Color3.new(rgb[1], rgb[2], rgb[3])
end

-- One-time Lighting children so we can drive fog softly + tint at night.
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
cc.Parent = Lighting

local WRITE_HZ = 10 -- Lighting writes/sec
local EPS = 0.002 -- nightFactor change that warrants an EventBus fire
local writeAccum = 0
local lastNightFactor = -1
local lastPhase = ""

local function currentT(): number
    local epoch = config:GetAttribute("CycleEpoch") or 0
    local length = config:GetAttribute("CycleLength") or 1200
    local offset = config:GetAttribute("PhaseOffset") or 0
    local raw = (workspace:GetServerTimeNow() - epoch) / length + offset
    return raw - math.floor(raw) -- [0,1)
end

local function applyLighting(t: number)
    local L = DayNight.lightingAt(t)
    Lighting.ClockTime = L.clockTime % 24
    Lighting.Brightness = L.brightness
    Lighting.OutdoorAmbient = c3(L.outdoorAmbient)
    Lighting.Ambient = c3(L.ambient)
    Lighting.FogEnd = L.fogEnd
    Lighting.FogColor = c3(L.fogColor)
    cc.TintColor = c3(L.ccTint)
    cc.Brightness = L.ccBrightness
end

local function publish(t: number)
    local ph = DayNight.phaseAt(t)
    if math.abs(ph.nightFactor - lastNightFactor) < EPS and ph.phase == lastPhase then
        return
    end
    lastNightFactor = ph.nightFactor
    lastPhase = ph.phase
    local payload = { t = t, nightFactor = ph.nightFactor, phase = ph.phase }
    -- stamp current value so late subscribers read it immediately (BindableEvents don't replay)
    config:SetAttribute("CurrentNightFactor", ph.nightFactor)
    config:SetAttribute("CurrentPhase", ph.phase)
    config:SetAttribute("CurrentT", t)
    EventBus.DayNight:Fire(payload)
end

-- prime immediately so the scene doesn't flash the old static Lighting on join
do
    local t = currentT()
    applyLighting(t)
    publish(t)
end

RunService.RenderStepped:Connect(function(dt)
    writeAccum += dt
    if writeAccum < 1 / WRITE_HZ then
        return
    end
    writeAccum = 0
    local t = currentT()
    applyLighting(t)
    publish(t)
end)
```

- [ ] **Step 2: Play gate — the full runtime verification**

This task cannot be Lune-tested (it drives real `Lighting`/`RunService`). Verify in **Play** (Rojo connected):

1. **Lighting cycles.** Temporarily set a short loop: in the command bar (server side), `game.ReplicatedStorage.DayNightConfig:SetAttribute("CycleLength", 60)`. Watch a full 60s loop — the scene sweeps day → dusk (amber) → moonlit night → dawn and back, never pitch black.
2. **`nightFactor` fires + moves.** Client command bar:
   ```lua
   game.ReplicatedStorage.RoshamboShared -- ensure shared present
   local bus = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("EventBus"))
   bus.DayNight.Event:Connect(function(p) print("nightFactor", p.nightFactor, p.phase) end)
   ```
   Expected: prints a changing `nightFactor` moving through `0…1` with phase names, several times over the 60s loop.
3. **Late subscriber gets the current value.** Read `game.ReplicatedStorage.DayNightConfig:GetAttribute("CurrentNightFactor")` at any moment — it reflects the live value (a controller/subscriber starting now reads it without waiting for the next fire).
4. **Global sync (the core guarantee).** Open a **second** Play session (Studio "Test → Start" with 2 players, or two clients) and confirm both derive the same `t`/`nightFactor` at the same wall-clock moment — because both use `GetServerTimeNow()` + the same fixed epoch. (In a single Studio test both clients share one server; the real cross-instance guarantee follows from the fixed epoch + global clock and is confirmed by the identical formula.)
5. **Restore** `CycleLength` to 1200 (or restart the server so the boot value returns).

**One attempt, then STOP and show the user** the cycling scene (day + dusk + night screenshots) before proceeding.

- [ ] **Step 3: Lint + tests**

Run: `cd roblox && stylua --check src tests && selene src && lune run tests/run 2>&1 | tail -3`
Expected: lint clean; tests `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/client/DayNightController.client.luau
git commit -m "feat(roblox): DayNightController — renders the cycle + fires the nightFactor contract"
```

---

## Self-Review

**1. Spec coverage:**
- Server-authoritative, global, fixed-epoch clock → Task 2 (config publish) + Task 3 (`currentT` formula). ✓
- Night-dominant proportions (10/18/25/47) → Task 1 `PHASES` + Global Constraints. ✓
- Pure Lune-tested `phaseAt`/`lightingAt` with `{r,g,b}` colors → Task 1. ✓
- `clockTime` mapped through bands (not linear) → Task 1 `clockAt`/`CLOCK`. ✓
- `nightFactor` contract on `EventBus.DayNight` `{t,nightFactor,phase}` → Task 2 (channel) + Task 3 (fires). ✓
- Late subscriber gets current value → Task 3 (`CurrentNightFactor`/`CurrentPhase`/`CurrentT` attributes; simpler + more robust than re-firing a BindableEvent). ✓
- Throttled Lighting writes (~10 Hz) + `nightFactor` ε → Task 3 (`WRITE_HZ`, `EPS`). ✓
- Takes over `Lighting` (was static `ClockTime 14`) → Task 3 `applyLighting`. ✓
- Non-goals (no gameplay/round change) → nothing in the plan touches round logic or remotes. ✓
- Open decisions deferred to gate: `CycleLength`/proportions/epoch/offset (Task 2/3 values), throttle rates (Task 3), and **Atmosphere vs legacy Fog + moon/stars** — the plan drives legacy `FogEnd`/`FogColor` + a `ColorCorrectionEffect` and leaves `Atmosphere`/moon-stars out of the foundation (a gate/enhancement decision, per the spec's open list). Noted, not a gap.

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to". Every code step shows complete code; every command shows expected output. ✓

**3. Type consistency:** `phaseAt` returns `{nightFactor, phase}` — consumed with those exact field names in `DayNightController` (`ph.nightFactor`, `ph.phase`) and the spec test. `lightingAt` field names (`clockTime`, `brightness`, `outdoorAmbient`, `ambient`, `fogEnd`, `fogColor`, `ccTint`, `ccBrightness`) match one-to-one between Task 1's return and Task 3's `applyLighting`. `EventBus.DayNight` payload `{t, nightFactor, phase}` consistent across Task 2 interface and Task 3 fire. Config attribute names (`CycleEpoch`, `CycleLength`, `PhaseOffset`) match between Task 2 publish and Task 3 read. ✓
