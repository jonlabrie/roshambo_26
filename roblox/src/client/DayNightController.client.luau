--!strict
-- Renders the day/night SCHEDULE on this client and publishes the nightFactor signal.
-- Standalone auto-running LocalScript (like ChochinSway.client.luau) — nothing starts it.
--
-- It does exactly two things to the world:
--   1. sets Lighting.ClockTime on the night-dominant schedule (drives Roblox's own sun/moon —
--      the natural day/night). It does NOT touch Brightness/Ambient/Fog/ColorCorrection, so
--      chōchin, glyphs, waterfalls, etc. keep their own light levels.
--   2. fires EventBus.DayNight { t, nightFactor, phase } when nightFactor moves, so subscribers
--      (glyph look, waterfall glow, …) react. It also stamps the current payload onto the config
--      attributes so a subscriber that starts mid-cycle reads the current value at once.
--
-- t is derived from workspace:GetServerTimeNow() (Roblox's globally-synced Unix clock) + the fixed
-- CycleEpoch, so every client in every server instance shows the same time-of-day at once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DayNight = require(shared:WaitForChild("DayNight"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

local WRITE_HZ = 10 -- ClockTime writes/sec
local EPS = 0.002 -- nightFactor change that warrants an EventBus fire
local writeAccum = 0
local lastNightFactor = -1
local lastPhase = ""

local function currentT(): number
    local epoch = config:GetAttribute("CycleEpoch") or 0
    local length = config:GetAttribute("CycleLength") or 600
    local offset = config:GetAttribute("PhaseOffset") or 0
    local raw = (workspace:GetServerTimeNow() - epoch) / length + offset
    return raw - math.floor(raw) -- [0,1)
end

local function publish(t: number)
    local ph = DayNight.phaseAt(t)
    if math.abs(ph.nightFactor - lastNightFactor) < EPS and ph.phase == lastPhase then
        return
    end
    lastNightFactor = ph.nightFactor
    lastPhase = ph.phase
    -- stamp current value so late subscribers read it immediately (BindableEvents don't replay)
    config:SetAttribute("CurrentNightFactor", ph.nightFactor)
    config:SetAttribute("CurrentPhase", ph.phase)
    config:SetAttribute("CurrentT", t)
    EventBus.DayNight:Fire({ t = t, nightFactor = ph.nightFactor, phase = ph.phase })
end

local function tick()
    -- ProvingController (Studio-only) sets this attribute while its night toggle is on, so
    -- its own Lighting.ClockTime = 22 write survives instead of being overwritten within
    -- 100ms by this WRITE_HZ-10 loop. The attribute never exists outside Studio, so this
    -- gate is inert in a published place. Gate the WHOLE write, not just ClockTime -- publish()
    -- also derives from t via currentT(), and skipping it keeps nightFactor/phase subscribers
    -- (glyphs, waterfall glow) agreeing with what the sky actually shows during an override.
    if Lighting:GetAttribute("ProvingNightOverride") then
        return
    end
    local t = currentT()
    Lighting.ClockTime = DayNight.clockTimeAt(t) % 24 -- the ONLY thing we set on Lighting
    publish(t)
end

tick() -- prime immediately on join

RunService.RenderStepped:Connect(function(dt)
    writeAccum += dt
    if writeAccum < 1 / WRITE_HZ then
        return
    end
    writeAccum = 0
    tick()
end)
