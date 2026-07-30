--!strict
-- Crossfades Lighting's ambient floor between day and night by reading nightFactor.
-- Standalone auto-run LocalScript (like GlyphDayNight.client.luau) — nothing starts it.
--
-- WHY THIS EXISTS: DayNightController sets ClockTime and deliberately nothing else, leaving
-- Ambient/Fog/ColorCorrection to subscribers. Nothing ever subscribed, so the canyon's ambient
-- floor stayed at its DAY value all night: OutdoorAmbient 135,131,124 is ~53% grey applied to
-- every sky-exposed surface regardless of the hour. The sun would set and the landscape would
-- go flat rather than dark — and with GlobalShadows off there is no occlusion to supply
-- contrast either.
--
-- The visible symptom was that the lanterns appeared to cast no light at all. They were not
-- broken: 46 of them sat at Brightness 0.30, which is a negligible delta on top of a surface
-- already at 53% grey. Dropping the night ambient ~4x is what let them read as pools of light.
--
-- Night ambient is COOL (blue-shifted) while day is warm-neutral, so the residual reads as
-- moonlight rather than as an underexposed afternoon.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

-- DAY values are the canyon's authored ambient — keep these in step with the place if it is
-- ever re-graded in Edit, since this script overwrites Lighting on every fire.
local DAY_OUTDOOR = Color3.fromRGB(135, 131, 124)
local DAY_AMBIENT = Color3.fromRGB(75, 73, 70)
local NIGHT_OUTDOOR = Color3.fromRGB(30, 34, 46)
local NIGHT_AMBIENT = Color3.fromRGB(14, 15, 20)

local current: number = config:GetAttribute("CurrentNightFactor") or 0

local function apply()
    -- Color3:Lerp is gamma-space here, which is what we want: these are authored screen values
    -- picked by eye at each end, not physical radiance to be blended linearly.
    Lighting.OutdoorAmbient = DAY_OUTDOOR:Lerp(NIGHT_OUTDOOR, current)
    Lighting.Ambient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, current)
end

apply() -- prime before the first EventBus fire

EventBus.DayNight.Event:Connect(function(payload)
    current = payload.nightFactor
    apply()
end)

-- backstop: the config attribute is set on every publish and replicates, closing the startup
-- race where this script connects to the BindableEvent after the controller's first fire.
config:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    current = config:GetAttribute("CurrentNightFactor") or current
    apply()
end)
