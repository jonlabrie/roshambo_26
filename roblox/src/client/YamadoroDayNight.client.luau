--!strict
-- Lights the yamadoro fireboxes at night and puts them out by day, by reading nightFactor.
-- Standalone auto-run LocalScript (like ChochinSway.client.luau) — nothing starts it.
--
-- Yamadoro are the RUSTIC trail lantern: unlike the chōchin (paper, maintained, on the formal
-- higher/teahouse paths, and burning around the clock as RoundLantern result displays), these
-- are stone, set once, and only alight after dusk. The canyon is night-first, so lit is the
-- primary state — but a lamp burning at noon reads as a bug, not as atmosphere.
--
-- Each firebox is a Neon "FireboxCore" part tagged "YamadoroFirebox" with a PointLight child.
-- Neon illuminates ONLY itself, so the visible glow and the pool of light on the ground are
-- two separate things: Transparency drives the former, PointLight.Brightness the latter.
--
-- Reads live nightFactor from EventBus.DayNight, with the DayNightConfig CurrentNightFactor
-- attribute as a start-order-proof prime + backstop (the config is built by the server at boot,
-- so it does not exist in Edit — this script only does anything in Play).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local LanternGlow = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("LanternGlow"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

local TAG = "YamadoroFirebox"
-- the curve lives in LanternGlow ("stone" profile) so the paper lanterns can share the
-- machinery without sharing the behaviour — they never go out, these do
local PROFILE = "stone"

local current: number = config:GetAttribute("CurrentNightFactor") or 0

local function applyTo(core: Instance)
    if not core:IsA("BasePart") then
        return
    end
    -- Transparency=1 truly skips the draw, so the stone reads as an empty dark opening by day
    local glow = LanternGlow.at(PROFILE, current)
    core.Transparency = glow.transparency
    local light = core:FindFirstChildWhichIsA("Light")
    if light and light:IsA("PointLight") then
        light.Brightness = glow.brightness
        light.Enabled = glow.enabled -- a light at Brightness 0 still costs a renderer slot
    end
end

local function applyAll()
    for _, core in CollectionService:GetTagged(TAG) do
        applyTo(core)
    end
end

applyAll() -- prime whatever is already streamed in
-- StreamingEnabled is ON, so lanterns arrive and leave as the player moves down the trail;
-- newly-streamed cores must pick up the current value rather than their authored night state.
CollectionService:GetInstanceAddedSignal(TAG):Connect(applyTo)

EventBus.DayNight.Event:Connect(function(payload)
    current = payload.nightFactor
    applyAll()
end)

-- backstop: the config attribute is set on every publish and replicates, closing the startup
-- race where this script connects to the BindableEvent after the controller's first fire.
config:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    current = config:GetAttribute("CurrentNightFactor") or current
    applyAll()
end)
