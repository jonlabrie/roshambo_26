--!strict
-- Shared R/P/S glyph images — the World-Throw glyphs rendered from the PWA SVGs
-- (src/components/Symbols.tsx) to Roblox image assets with true centred strokes and round
-- caps/joins (native UIStroke can't: it draws outward-only, so a ring's keyline came out
-- lopsided and the chevron's arms wouldn't fuse). TWO WHITE layers per symbol — a core and a
-- uniformly-wider outline — so they stay recolourable: the caller tints the outline (ink) and
-- core (gold) via ImageColor3 at render time. Sources: scratchpad glyphgen.js (SDF raster).
local Glyphs = {}

export type Layers = { core: string, outline: string }

Glyphs.IMAGE = {
    R = { core = "rbxassetid://114994259059574", outline = "rbxassetid://140343170738928" }, -- +20% (2026-07-21)
    P = { core = "rbxassetid://99397686079954", outline = "rbxassetid://138541026420460" }, -- 10% shorter (2026-07-21)
    S = { core = "rbxassetid://101645881657743", outline = "rbxassetid://100753938615553" },
} :: { [string]: Layers }

-- Day/night palette (plain {r,g,b} 0-255 arrays so the module stays Lune-safe; renderDayNight
-- converts to Color3 internally). Tuned at the Play gate.
Glyphs.PALETTE = {
    gold = { 212, 176, 102 }, -- day core (gilt)
    ink = { 20, 17, 16 }, -- keyline outline
    amber = { 255, 178, 92 }, -- night core (warm glow)
    amberHalo = { 255, 146, 60 }, -- night bloom
}

-- Build the glyph as two stacked ImageLabels (outline behind, core in front), each a centred
-- square (aspect-locked so the ring stays round on a non-square panel). Instance/Color3 live
-- ONLY here, so the module stays Lune-safe (tests only touch Glyphs.IMAGE).
function Glyphs.render(parent: Instance, symbol: string, coreColor: Color3, outlineColor: Color3?): Frame
    local root = Instance.new("Frame")
    root.Name = "Glyph"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromScale(1, 1)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    local ar = Instance.new("UIAspectRatioConstraint")
    ar.AspectRatio = 1
    ar.Parent = root

    local imgs = Glyphs.IMAGE[symbol]
    if imgs then
        local function layer(assetId: string, tint: Color3)
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Size = UDim2.fromScale(1, 1)
            img.Image = assetId
            img.ImageColor3 = tint
            img.Parent = root
        end
        layer(imgs.outline, outlineColor or Color3.new(1, 1, 1)) -- behind
        layer(imgs.core, coreColor) -- in front
    end

    root.Parent = parent
    return root
end

-- Build the glyph as a DAY CanvasGroup (gilt gold, the current look) + a NIGHT CanvasGroup
-- (warm-amber core over a soft amber halo), stacked in the same SurfaceGui. A day/night subscriber
-- crossfades them via each group's GroupTransparency (GlyphDayNight.client.luau). SurfaceGui stays
-- LightInfluence 0, so both are full-bright — gold reads gilt on cypress by day, amber reads self-lit
-- against the dark by night (faux-glow, no light cast). Roblox globals live here (not module scope)
-- so the module stays Lune-safe.
function Glyphs.renderDayNight(parent: Instance, symbol: string)
    local imgs = Glyphs.IMAGE[symbol]
    if not imgs then
        return
    end
    local CollectionService = game:GetService("CollectionService")
    local function c3(rgb: { number }): Color3
        return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end
    -- one image layer, centred + scaled (scale 1 = fills the aspect-locked group)
    local function layer(into: Instance, assetId: string, tint: Color3, scale: number, transparency: number)
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.Size = UDim2.fromScale(scale, scale)
        img.Image = assetId
        img.ImageColor3 = tint
        img.ImageTransparency = transparency
        img.Parent = into
    end
    -- an aspect-locked CanvasGroup (so the ○ ring stays round on a non-square facet)
    local function makeGroup(name: string, layerKind: string, startTransparency: number): CanvasGroup
        local g = Instance.new("CanvasGroup")
        g.Name = name
        g.BackgroundTransparency = 1
        g.AnchorPoint = Vector2.new(0.5, 0.5)
        g.Position = UDim2.fromScale(0.5, 0.5)
        g.Size = UDim2.fromScale(1, 1)
        g.GroupTransparency = startTransparency
        local ar = Instance.new("UIAspectRatioConstraint")
        ar.AspectRatio = 1
        ar.Parent = g
        g:SetAttribute("layer", layerKind)
        CollectionService:AddTag(g, "GlyphDayNight")
        g.Parent = parent
        return g
    end

    -- DAY: gilt gold (current approved look), visible by day.
    local day = makeGroup("GlyphDay", "day", 0)
    layer(day, imgs.outline, c3(Glyphs.PALETTE.ink), 1, 0) -- keyline behind
    layer(day, imgs.core, c3(Glyphs.PALETTE.gold), 1, 0) -- gold core in front

    -- NIGHT: amber glyph over a soft amber halo, hidden by day (faded in by nightFactor).
    local night = makeGroup("GlyphNight", "night", 1)
    layer(night, imgs.outline, c3(Glyphs.PALETTE.amberHalo), 1.3, 0.5) -- widest, softest = halo bloom
    layer(night, imgs.outline, c3(Glyphs.PALETTE.ink), 1, 0) -- ink keyline for definition
    layer(night, imgs.core, c3(Glyphs.PALETTE.amber), 1, 0) -- amber core (glows)
end

return Glyphs
