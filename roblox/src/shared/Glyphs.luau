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
    R = { core = "rbxassetid://136434628991867", outline = "rbxassetid://115980003300543" },
    P = { core = "rbxassetid://110118985579185", outline = "rbxassetid://138179191212780" },
    S = { core = "rbxassetid://101645881657743", outline = "rbxassetid://100753938615553" },
} :: { [string]: Layers }

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

return Glyphs
