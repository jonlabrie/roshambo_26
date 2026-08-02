--!strict
-- Rides the chōchin and the square deck/newel lanterns up and down with nightFactor.
-- Standalone auto-run LocalScript, like YamadoroDayNight.client.luau — nothing starts it.
--
-- THESE NEVER GO OUT, and that is the point. LanternController drives both kinds as the round
-- telegraph: every lantern in the canyon shows the last World Throw's glyph and fades blank
-- ~10s before the next reveal. They are a thing players READ. Extinguishing them by day —
-- which is what the yamadoro's "stone" curve does — would dim a game display, not an ornament.
-- So they ride the "paper" profile between a daytime floor and full night glow: calmer at
-- noon, never illegible. (Before this script existed they simply burned at full brightness
-- around the clock, which is what made paper lanterns blaze at midday.)
--
-- FINDING THE GLOW IS NOT THE SAME AS FINDING THE TAG. The two kinds are tagged differently:
--   BlockLantern  the tagged part IS the Neon shade, with the PointLight on it. Direct.
--   RoundLantern  the tag sits on GlyphPlateA/B — thin, fully transparent Plastic carrying
--                 the SurfaceGui. The barrel that actually glows (ChochinBody plus ~18
--                 Slice_* segments) is a SIBLING, untagged. So the plate is a handle, not a
--                 target: walk up to the nearest ancestor holding Neon parts and drive those.
-- Two plates per chōchin means the same barrel resolves twice — hence the `seen` set.
--
-- Neon illuminates only itself, so glow and ground-pool are separate channels: Transparency
-- for the first, PointLight.Brightness for the second. See LanternGlow for the curve.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local LanternGlow = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("LanternGlow"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

local PROFILE = "paper"
local MAX_WALK_UP = 3 -- plate -> Swing -> pole is two; three leaves a little slack

type Unit = { parts: { BasePart }, lights: { PointLight } }

local units: { [Instance]: Unit } = {}
local current: number = config:GetAttribute("CurrentNightFactor") or 0

local function collect(root: Instance): Unit?
    local parts: { BasePart } = {}
    local lights: { PointLight } = {}
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
            table.insert(parts, d)
            local light = d:FindFirstChildWhichIsA("Light")
            if light and light:IsA("PointLight") then
                table.insert(lights, light)
            end
        end
    end
    if #parts == 0 then
        return nil
    end
    return { parts = parts, lights = lights }
end

local function applyUnit(unit: Unit)
    local glow = LanternGlow.at(PROFILE, current)
    for _, part in unit.parts do
        part.Transparency = glow.transparency
    end
    for _, light in unit.lights do
        light.Brightness = glow.brightness
        light.Enabled = glow.enabled
    end
end

-- resolve a tagged instance to the thing that actually glows, and remember it. The parts are
-- cached rather than re-walked per nightFactor tick: a canyon of chōchin is ~750 Neon parts
-- and the signal fires on every 0.002 of movement through dusk.
local function register(tagged: Instance)
    if not tagged:IsDescendantOf(workspace) then
        return
    end
    local node: Instance? = tagged
    for _ = 1, MAX_WALK_UP do
        if not node then
            break
        end
        local unit = collect(node)
        if unit then
            if units[node] == nil then
                units[node] = unit
            end
            applyUnit(units[node])
            return
        end
        node = node.Parent
    end
end

local function applyAll()
    for _, unit in units do
        applyUnit(unit)
    end
end

for _, tag in { "RoundLantern", "BlockLantern" } do
    for _, tagged in CollectionService:GetTagged(tag) do
        register(tagged)
    end
    -- StreamingEnabled is on: lanterns arrive and leave as the player moves, and a newly
    -- streamed one must pick up the CURRENT value, not the state it was authored with
    CollectionService:GetInstanceAddedSignal(tag):Connect(register)
    CollectionService:GetInstanceRemovedSignal(tag):Connect(function(tagged)
        local node: Instance? = tagged
        for _ = 1, MAX_WALK_UP do
            if not node then
                break
            end
            if units[node] then
                units[node] = nil
                return
            end
            node = node.Parent
        end
    end)
end

EventBus.DayNight.Event:Connect(function(payload)
    current = payload.nightFactor
    applyAll()
end)

-- backstop for the startup race: the controller may fire before this script connects, but the
-- config attribute is set on every publish and replicates
config:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    current = config:GetAttribute("CurrentNightFactor") or current
    applyAll()
end)
