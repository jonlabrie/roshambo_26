--!strict
-- First day/night subscriber: crossfades the lantern glyphs gilt-gold (day) ↔ amber-glow (night)
-- by reading nightFactor. Standalone auto-run LocalScript (like ChochinSway.client.luau) — nothing
-- starts it. Tagged "GlyphDayNight" (attr layer="day"/"night"): the DAY gilt-gold CanvasGroup
-- (Glyphs.renderDay) fades via GroupTransparency; the NIGHT Neon parts (Glyphs.buildNightNeon) fade
-- via Transparency. DrumController builds them at runtime, so we also apply to items added after
-- startup. Reads live nightFactor from EventBus.DayNight, with the DayNightConfig CurrentNightFactor
-- attribute as a start-order-proof prime + backstop.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

local TAG = "GlyphDayNight"
local current = config:GetAttribute("CurrentNightFactor") or 0

local function applyTo(g: Instance)
    local layer = g:GetAttribute("layer")
    if layer == "day" and g:IsA("CanvasGroup") then
        g.GroupTransparency = current -- day gilt-gold GUI fades OUT as night falls
        -- GroupTransparency=1 is NOT a real "off": at distance SurfaceGuis fall back to a render
        -- path that skips group compositing, so the fully-faded day glyph still draws (dark,
        -- exactly glyph-shaped) OVER the Neon night glyph 0.05 in front of it — which read as
        -- "night glyphs lose their glow at distance". Visible is the true off switch.
        g.Visible = current < 0.999
    elseif layer == "night" and g:IsA("BasePart") then
        g.Transparency = 1 - current -- night Neon geometry fades IN (Transparency=1 truly skips)
    end
end

local function applyAll()
    for _, g in CollectionService:GetTagged(TAG) do
        applyTo(g)
    end
end

applyAll() -- prime any glyphs already built
CollectionService:GetInstanceAddedSignal(TAG):Connect(applyTo) -- glyphs built later get current value

EventBus.DayNight.Event:Connect(function(payload)
    current = payload.nightFactor
    applyAll()
end)

-- backstop: the config attribute is set on every publish and replicates, closing the startup race
-- where this script connects to the BindableEvent after the controller's first fire.
config:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    current = config:GetAttribute("CurrentNightFactor") or current
    applyAll()
end)
