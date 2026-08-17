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

-- Day glyph palette (plain {r,g,b} 0-255 arrays so the module stays Lune-safe; the render
-- functions convert to Color3 internally). Tuned at the Play gate.
Glyphs.PALETTE = {
    gold = { 212, 176, 102 }, -- day core (gilt)
    ink = { 20, 17, 16 }, -- keyline outline
}

-- Night glyph = the EXACT day glyph shape as a flat Neon-material MeshPart, so it emits + blooms via
-- the scene's BloomEffect (a SurfaceGui can't bloom; a Neon+SurfaceAppearance renders matte + ignores
-- Part.Color). The meshes are the glyphgen 2D shapes extruded flat (ring / round-capped bar / caret),
-- built in normalized glyph units so MeshSize = the glyph's content bbox → scale by min(faceW,h) to
-- match the day glyph footprint. Pure Neon ⇒ Color is live-tunable. Gate-tuned color.
Glyphs.NIGHT = {
    color = { 179, 130, 108 }, -- warm-gold Neon (gate-tuned on the lantern)
    mesh = { -- SOLID (extruded, real thickness) — flat zero-thickness meshes get culled at distance
        R = "rbxassetid://134649637477578", -- ring (annulus)
        P = "rbxassetid://113127066887467", -- round-capped bar
        S = "rbxassetid://93306116397070", -- caret ∧ (two round-capped arms)
    },
}

-- HOW FAR EACH GLYPH SITS OFF A SPLIT-FLAP'S SEAM, as a fraction of the glyph square. Positive
-- is down.
--
-- Paper is a horizontal BAR and the seam is a horizontal LINE, so a glyph centred on the seam is
-- bisected by the thing it most resembles. Ring and chevron have open centres and read fine
-- across it, so only P moves. The owner hit this twice -- once on the round display's flipper and
-- again on the wall boards when they inherited the same images -- which is why the number lives
-- here, beside the assets, rather than privately in whichever renderer noticed first.
--
-- PURE DATA, deliberately: this file's Instance code is confined to the render helpers below so
-- the module stays Lune-safe, and a nudge read from a workspace attribute belongs to the caller.
Glyphs.SEAM_NUDGE = { P = 0.06 } :: { [string]: number }

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
        -- NAMED, so a caller that re-tints later (the HUD's throw buttons light the CORE blue on
        -- selection) can address the two layers without depending on GetChildren's ordering.
        local function layer(name: string, assetId: string, tint: Color3)
            local img = Instance.new("ImageLabel")
            img.Name = name
            img.BackgroundTransparency = 1
            img.Size = UDim2.fromScale(1, 1)
            img.Image = assetId
            img.ImageColor3 = tint
            img.Parent = root
        end
        layer("Outline", imgs.outline, outlineColor or Color3.new(1, 1, 1)) -- behind
        layer("Core", imgs.core, coreColor) -- in front
    end

    root.Parent = parent
    return root
end

-- As `render`, but inside a CanvasGroup so the caller fades the whole glyph with a single
-- GroupTransparency tween. The lanterns need this: they cross-fade every reveal, and tweening
-- two ImageLabels independently drifts them out of step at the edges of the fade.
function Glyphs.renderGroup(
    parent: Instance,
    symbol: string,
    coreColor: Color3,
    outlineColor: Color3?
): CanvasGroup
    local g = Instance.new("CanvasGroup")
    g.Name = "Glyph"
    g.BackgroundTransparency = 1
    g.AnchorPoint = Vector2.new(0.5, 0.5)
    g.Position = UDim2.fromScale(0.5, 0.5)
    g.Size = UDim2.fromScale(1, 1)
    local ar = Instance.new("UIAspectRatioConstraint")
    ar.AspectRatio = 1
    ar.Parent = g

    local imgs = Glyphs.IMAGE[symbol]
    if imgs then
        local function layer(assetId: string, tint: Color3)
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Size = UDim2.fromScale(1, 1)
            img.Image = assetId
            img.ImageColor3 = tint
            img.Parent = g
        end
        layer(imgs.outline, outlineColor or coreColor)
        layer(imgs.core, coreColor)
    end

    g.Parent = parent
    return g
end

-- DAY glyph: the gilt-gold image (current approved look) in an aspect-locked CanvasGroup, tagged
-- for the day/night subscriber (GlyphDayNight.client.luau) which fades it via GroupTransparency.
-- Full-bright (the SurfaceGui is LightInfluence 0) so gold reads gilt on cypress. Roblox globals
-- live here (not module scope) so the module stays Lune-safe.
function Glyphs.renderDay(parent: Instance, symbol: string)
    local imgs = Glyphs.IMAGE[symbol]
    if not imgs then
        return
    end
    local CollectionService = game:GetService("CollectionService")
    local function c3(rgb: { number }): Color3
        return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end
    local g = Instance.new("CanvasGroup")
    g.Name = "GlyphDay"
    g.BackgroundTransparency = 1
    g.AnchorPoint = Vector2.new(0.5, 0.5)
    g.Position = UDim2.fromScale(0.5, 0.5)
    g.Size = UDim2.fromScale(1, 1)
    g.GroupTransparency = 0
    local ar = Instance.new("UIAspectRatioConstraint")
    ar.AspectRatio = 1
    ar.Parent = g
    g:SetAttribute("layer", "day")
    CollectionService:AddTag(g, "GlyphDayNight")
    local function layer(assetId: string, tint: Color3)
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = assetId
        img.ImageColor3 = tint
        img.Parent = g
    end
    layer(imgs.outline, c3(Glyphs.PALETTE.ink)) -- keyline behind
    layer(imgs.core, c3(Glyphs.PALETTE.gold)) -- gold core in front
    g.Parent = parent
end

-- NIGHT glyph: build the symbol's flat Neon MeshPart on the facet front. Pure Neon material (no
-- SurfaceAppearance) → it emits + blooms AND its Color is live-tunable. The mesh is the exact
-- glyphgen shape in normalized units, so its native MeshSize is the glyph's content bbox; scale by
-- min(faceW,h) to match the day glyph footprint. ANCHORED + RETURNED so the caller (DrumController)
-- captures it into its spin set (parenting to the anchored face does NOT carry it under the
-- CFrame-driven spin). Tagged layer="night", Transparency 1 (hidden by day); the subscriber fades it
-- in. Yields (CreateMeshPartAsync). Facet local: Front = −Z (outward).
function Glyphs.buildNightNeon(face: BasePart, symbol: string): { BasePart }
    local meshId = Glyphs.NIGHT.mesh[symbol]
    if not meshId then
        return {}
    end
    local AS = game:GetService("AssetService")
    local CollectionService = game:GetService("CollectionService")
    local nc = Glyphs.NIGHT.color
    local fs = face.Size
    local S = math.min(fs.X, fs.Y) -- match the day glyph square footprint
    local q = AS:CreateMeshPartAsync(Content.fromUri(meshId), {
        CollisionFidelity = Enum.CollisionFidelity.Box,
        RenderFidelity = Enum.RenderFidelity.Precise, -- a focal crown glyph: never LOD away at distance
    })
    local ms = q.MeshSize -- native = the glyph content bbox (normalized units) → scale by S
    q.Name = "GlyphNight"
    q.Anchored = true
    q.CanCollide = false
    q.CanQuery = false
    q.CanTouch = false
    q.CastShadow = false
    q.DoubleSided = true
    q.TextureID = ""
    q.Material = Enum.Material.Neon
    q.Color = Color3.fromRGB(nc[1], nc[2], nc[3])
    q.Transparency = 1 -- hidden by day; the subscriber fades it in
    q.Size = Vector3.new(math.max(ms.X * S, 0.05), math.max(ms.Y * S, 0.05), math.max(ms.Z * S, 0.05)) -- uniform S scale (keeps the extruded thickness)
    q.CFrame = face.CFrame * CFrame.new(0, 0, -(fs.Z / 2 + 0.05)) -- just proud of the Front
    q:SetAttribute("layer", "night")
    CollectionService:AddTag(q, "GlyphDayNight")
    q.Parent = face
    return { q }
end

return Glyphs
