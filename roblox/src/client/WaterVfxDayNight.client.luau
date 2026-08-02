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
local AUTHORED_LIGHT_INFLUENCE = "AuthoredLightInfluence"
local AUTHORED_COLOR = "AuthoredColor"

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

-- capture once, then always read the capture: applying to a live value would scale an
-- already-scaled number and fade the falls further on every dusk
local function capture(inst: Instance, key: string, live: number): number
    local stored = inst:GetAttribute(key)
    if typeof(stored) == "number" then
        return stored
    end
    inst:SetAttribute(key, live)
    return live
end

-- ColorSequence is a supported attribute type, so the authored ramp is captured the same way
-- the scalars are. Converting through plain {t,r,g,b} keeps the curve itself in VfxNightDim,
-- where it can be tested under Lune without a Roblox datatype.
local function neutralised(emitter: ParticleEmitter): ColorSequence
    local stored = emitter:GetAttribute(AUTHORED_COLOR)
    local authored: ColorSequence
    if typeof(stored) == "ColorSequence" then
        authored = stored
    else
        authored = emitter.Color
        emitter:SetAttribute(AUTHORED_COLOR, authored)
    end
    local keys = {}
    for i, kp in authored.Keypoints do
        keys[i] = { t = kp.Time, r = kp.Value.R, g = kp.Value.G, b = kp.Value.B }
    end
    local shifted = VfxNightDim.neutraliseColor(keys, current)
    local out = {}
    for i, k in shifted do
        out[i] = ColorSequenceKeypoint.new(k.t, Color3.new(k.r, k.g, k.b))
    end
    return ColorSequence.new(out)
end

local function applyTo(inst: Instance)
    if inst:IsA("Beam") then
        local v = VfxNightDim.at({
            brightness = capture(inst, AUTHORED_BRIGHTNESS, inst.Brightness),
            lightEmission = 0, -- Beams have no LightEmission; the field is unused for them
            lightInfluence = capture(inst, AUTHORED_LIGHT_INFLUENCE, inst.LightInfluence),
        }, current)
        inst.Brightness = v.brightness
        inst.LightInfluence = v.lightInfluence
    elseif inst:IsA("ParticleEmitter") then
        local v = VfxNightDim.at({
            brightness = capture(inst, AUTHORED_BRIGHTNESS, inst.Brightness),
            lightEmission = capture(inst, AUTHORED_LIGHT_EMISSION, inst.LightEmission),
            lightInfluence = capture(inst, AUTHORED_LIGHT_INFLUENCE, inst.LightInfluence),
        }, current)
        inst.Brightness = v.brightness
        inst.LightEmission = v.lightEmission
        inst.LightInfluence = v.lightInfluence
        inst.Color = neutralised(inst)
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
