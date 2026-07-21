--!strict
-- Shared R/P/S glyph geometry — the single source of truth for how a World-Throw
-- symbol is drawn, mirroring the PWA's src/components/Symbols.tsx. Each glyph is a
-- colored CORE flanked by a white OUTLINE (the SVG's two-pass stroke):
--   Rock  = a ring          (circle, white stroke 4.5 then color 2.5)
--   Paper = a rounded bar    (line,  white stroke 5   then color 3)
--   Scissors = ∧ chevron     (apex up, white 4.5 then color 2.5)
-- `parts` is PURE (colors are {r,g,b} arrays, no Instances) so it is Lune-tested;
-- `render` turns descriptors into native UI at runtime (Color3/Instance only here).
local Glyphs = {}

export type GlyphPart = {
    kind: string, -- "ring" | "bar"
    color: { number }, -- {r,g,b} 0..1
    thickness: number?, -- ring: stroke width as a fraction of the glyph square
    pos: { number }?, -- bar: {x,y} scale of centre (anchor 0.5,0.5)
    size: { number }?, -- bar: {w,h} scale
    rotation: number?, -- bar: degrees
}

local WHITE = { 1, 1, 1 }

-- Ring stroke fractions (SVG r=8 of 24; white 4.5 / color 2.5 → ~0.19 / ~0.10).
local RING_OUT, RING_CORE = 0.19, 0.10
-- Bar heights (SVG white 5 / color 3 of 24 → ~0.21 / ~0.125); paper width ≈ 14/24.
local BAR_OUT_H, BAR_CORE_H, BAR_W = 0.21, 0.125, 0.60
-- Chevron arm geometry: two bars from the apex (top-centre) down to the lower corners.
-- SVG (12,9)→(6,15) and (12,9)→(18,15): 45° arms, length √72/24 ≈ 0.354, mids at
-- (9,12) and (15,12) of 24 → scale (0.375,0.5) and (0.625,0.5). Apex-up ⇒ mids above
-- the glyph centre after we re-base y to the 0.30..0.70 band the chevron occupies.
local CHEV_LEN = 0.42
local CHEV_OUT_H, CHEV_CORE_H = 0.19, 0.10

function Glyphs.parts(
    symbol: string,
    coreColor: { number },
    opts: { outlineColor: { number }? }?
): { GlyphPart }
    local outline = (opts and opts.outlineColor) or WHITE
    if symbol == "R" then
        return {
            { kind = "ring", color = outline, thickness = RING_OUT },
            { kind = "ring", color = coreColor, thickness = RING_CORE },
        }
    elseif symbol == "P" then
        return {
            { kind = "bar", color = outline, pos = { 0.5, 0.5 }, size = { BAR_W, BAR_OUT_H }, rotation = 0 },
            {
                kind = "bar",
                color = coreColor,
                pos = { 0.5, 0.5 },
                size = { BAR_W, BAR_CORE_H },
                rotation = 0,
            },
        }
    else -- "S": ∧ apex up. Left arm rotated -45°, right arm +45°; both mids in the upper band.
        local ly, ry = 0.42, 0.42 -- arm-midpoint y (< 0.5 ⇒ apex-up region)
        return {
            {
                kind = "bar",
                color = outline,
                pos = { 0.34, ly },
                size = { CHEV_LEN, CHEV_OUT_H },
                rotation = -45,
            },
            {
                kind = "bar",
                color = outline,
                pos = { 0.66, ry },
                size = { CHEV_LEN, CHEV_OUT_H },
                rotation = 45,
            },
            {
                kind = "bar",
                color = coreColor,
                pos = { 0.34, ly },
                size = { CHEV_LEN, CHEV_CORE_H },
                rotation = -45,
            },
            {
                kind = "bar",
                color = coreColor,
                pos = { 0.66, ry },
                size = { CHEV_LEN, CHEV_CORE_H },
                rotation = 45,
            },
        }
    end
end

-- Runtime: build the native UI. Color3/Instance APIs live ONLY here.
function Glyphs.render(
    parent: Instance,
    symbol: string,
    coreColor: Color3,
    sizePx: number,
    opts: { outlineColor: { number }? }?
): Frame
    local root = Instance.new("Frame")
    root.Name = "Glyph"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromScale(1, 1)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    local ar = Instance.new("UIAspectRatioConstraint") -- keep the glyph square so the ring stays round
    ar.AspectRatio = 1
    ar.Parent = root

    local function c3(rgb: { number }): Color3
        return Color3.new(rgb[1], rgb[2], rgb[3])
    end

    for _, p in Glyphs.parts(symbol, { coreColor.R, coreColor.G, coreColor.B }, opts) do
        if p.kind == "ring" then
            local f = Instance.new("Frame")
            f.BackgroundTransparency = 1
            f.Size = UDim2.fromScale(0.9, 0.9)
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromScale(0.5, 0.5)
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0)
            corner.Parent = f
            local stroke = Instance.new("UIStroke")
            stroke.Color = c3(p.color)
            stroke.Thickness = math.max(1, math.round((p.thickness :: number) * sizePx))
            stroke.Parent = f
            f.Parent = root
        else -- bar
            local f = Instance.new("Frame")
            f.BackgroundColor3 = c3(p.color)
            f.BorderSizePixel = 0
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromScale((p.pos :: { number })[1], (p.pos :: { number })[2])
            f.Size = UDim2.fromScale((p.size :: { number })[1], (p.size :: { number })[2])
            f.Rotation = p.rotation or 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0) -- capsule (rounded caps)
            corner.Parent = f
            f.Parent = root
        end
    end

    root.Parent = parent
    return root
end

return Glyphs
