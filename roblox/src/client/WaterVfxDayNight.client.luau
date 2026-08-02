--!strict
-- Dims the waterfall VFX after dark — cascades, whitewater, foam, ripples, spray and mist.
-- Standalone auto-run LocalScript, like YamadoroDayNight and PaperLanternDayNight.
--
-- These are authored with LightInfluence 0, so they ignore scene lighting and render at full
-- daylight brightness at midnight; the falls looked the same at noon and at 2am. This scales
-- the two self-emission channels instead — see VfxNightDim for why that is the right knob and
-- LightInfluence is not.
--
-- SCALE THE AUTHORED VALUE, AND CAPTURE IT EXACTLY ONCE. Each emitter keeps its own look (the
-- hero fall is authored brighter than a gentle run; foam sits at LightEmission 0.25 while
-- whitewater sits at 0.60), so the multiplier is applied to what the artist set, not to a
-- shared constant. The authored numbers are stashed on the instance the first time it is
-- seen, and every later apply reads from that stash — otherwise a second pass would scale an
-- already-scaled value and the falls would fade a little more on each dusk.
--
-- SCOPE IS TWO ROOTS, NOT EVERY EMITTER IN THE PLACE. The water VFX are split across
-- CanyonWorld.Arena (the falls: UpcanyonVFX, DowncanyonVFX, ReachNVFX, W##_*_VFX, VFXRoot —
-- 115 objects, all under a "VFX"-named ancestor) and CanyonWorld.Water (the river runs
-- W06_UpperRun / W09_MidRun / W03_OutfallRun — 20 objects, NOT under any "VFX" folder). An
-- Arena-only scan with a name test silently missed the river; the census total is 135, and
-- both roots are needed to reach it.
--
-- Inside the Arena the "VFX"-named ancestor test is kept deliberately, so that future
-- non-water effects added there — fireworks, hammer impacts, reveal theater — do NOT inherit
-- water's night behaviour. Nothing here is tagged and tagging 135 objects would mean mutating
-- the place, so ancestry is the selector.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local VfxNightDim = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("VfxNightDim"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

local AUTHORED_BRIGHTNESS = "AuthoredBrightness"
local AUTHORED_LIGHT_EMISSION = "AuthoredLightEmission"

local tracked: { Instance } = {}
local current: number = config:GetAttribute("CurrentNightFactor") or 0

local canyon = workspace:WaitForChild("CanyonWorld")
local arena = canyon:WaitForChild("Arena")
local water = canyon:WaitForChild("Water")

local function isWaterVfx(inst: Instance): boolean
    if not (inst:IsA("Beam") or inst:IsA("ParticleEmitter")) then
        return false
    end
    -- the river runs are not inside any "VFX"-named folder, so membership of the Water
    -- root is qualification enough there
    if inst:IsDescendantOf(water) then
        return true
    end
    local node: Instance? = inst.Parent
    while node and node ~= workspace do
        if node.Name:find("VFX") then
            return true
        end
        node = node.Parent
    end
    return false
end

local function applyTo(inst: Instance)
    local scale = VfxNightDim.scaleAt(current)
    if inst:IsA("Beam") then
        local authored = inst:GetAttribute(AUTHORED_BRIGHTNESS)
        if typeof(authored) ~= "number" then
            authored = inst.Brightness
            inst:SetAttribute(AUTHORED_BRIGHTNESS, authored)
        end
        inst.Brightness = (authored :: number) * scale.brightness
    elseif inst:IsA("ParticleEmitter") then
        local b = inst:GetAttribute(AUTHORED_BRIGHTNESS)
        if typeof(b) ~= "number" then
            b = inst.Brightness
            inst:SetAttribute(AUTHORED_BRIGHTNESS, b)
        end
        local le = inst:GetAttribute(AUTHORED_LIGHT_EMISSION)
        if typeof(le) ~= "number" then
            le = inst.LightEmission
            inst:SetAttribute(AUTHORED_LIGHT_EMISSION, le)
        end
        inst.Brightness = (b :: number) * scale.brightness
        inst.LightEmission = (le :: number) * scale.lightEmission
    end
end

local function track(inst: Instance)
    if not isWaterVfx(inst) then
        return
    end
    table.insert(tracked, inst)
    applyTo(inst)
end

local function applyAll()
    for i = #tracked, 1, -1 do
        local inst = tracked[i]
        if inst.Parent == nil then
            table.remove(tracked, i) -- streamed out
        else
            applyTo(inst)
        end
    end
end

for _, root in { arena, water } do
    for _, d in root:GetDescendants() do
        track(d)
    end
    -- StreamingEnabled is on and the water runs the length of the canyon, so emitters arrive
    -- as the player moves; a newly-streamed one must take the CURRENT scale, not the daylight
    -- value it was authored with
    root.DescendantAdded:Connect(track)
end

EventBus.DayNight.Event:Connect(function(payload)
    current = payload.nightFactor
    applyAll()
end)

config:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    current = config:GetAttribute("CurrentNightFactor") or current
    applyAll()
end)
