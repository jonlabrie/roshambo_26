--!strict
-- THE ROUND DISPLAY'S THROW FLIPPER — one large flap that shows the World Throw.
--
-- NOT a FlapBoard cell. The owner asked for "the same standard glyph outlines as those found on
-- the drum and the lanterns", which are `Glyphs.IMAGE`: a core+outline ImageLabel pair rendered
-- from the PWA's SVGs, not the text characters the flap drum carries. Sharing the assets is the
-- point -- the same shape appears on the drum, the lanterns, the HUD and here, so a player learns
-- one vocabulary rather than four.
--
-- The fold illusion is FlapBoard's, so the two read as the same machine.
--
-- IT OWNS NO CLOCK. It used to run its own spin loop on a private interval, which is precisely how
-- it ended up 2.45s ahead of the HUD's ring. The caller now hands it a glyph every frame, computed
-- from the same ReelStep the ring uses, so the two cannot drift.
local TweenService = game:GetService("TweenService")

local GlyphFlipper = {}
GlyphFlipper.__index = GlyphFlipper

export type Config = {
    part: BasePart,
    -- Glyphs.render, injected so this module requires nothing (the DI convention every other
    -- client module here follows).
    render: (parent: Instance, symbol: string, coreColor: Color3, outlineColor: Color3?) -> Frame,
    symbols: { string }, -- the cycle order while spinning
    faces: { Enum.NormalId }?,
}

-- Matching FlapBoard's cell exactly, so the flipper reads as one of the same flaps at scale.
local TILE = Color3.fromRGB(244, 238, 222)
local SEAM = Color3.fromRGB(150, 142, 124)
local INK = Color3.fromRGB(40, 30, 18)
local PAD = 0.08
local FULL = UDim2.fromScale(1, 1)
local SQUASHED = UDim2.fromScale(1, 0.05)
-- Paint order under ZIndexBehavior.Global: tile, then the glyph's outline, then its core, then
-- the seam on top of everything.
local TILE_Z, GLYPH_Z, OUTLINE_Z, CORE_Z, SEAM_Z = 2, 3, 3, 4, 5
local FLIP_SECONDS = 0.04

local function buildFace(cfg: Config, faceEnum: Enum.NormalId): { [string]: Frame }
    local gui = Instance.new("SurfaceGui")
    gui.Name = "FlapFace"
    gui.Face = faceEnum
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    -- Square canvas for a square panel; the glyphs are aspect-locked by Glyphs.render anyway.
    gui.CanvasSize = Vector2.new(512, 512)
    gui.Parent = cfg.part

    local tile = Instance.new("Frame")
    tile.Name = "Tile"
    tile.Size = UDim2.fromScale(1 - PAD, 1 - PAD)
    tile.Position = UDim2.fromScale(PAD / 2, PAD / 2)
    tile.BackgroundColor3 = TILE
    tile.BorderSizePixel = 0
    tile.ClipsDescendants = true
    tile.ZIndex = TILE_Z
    tile.Parent = gui

    -- EVERY GLYPH IS BUILT ONCE AND HIDDEN. Rebuilding image layers per flip would re-decode
    -- assets seven times a second through the whole spin; visibility is free.
    local glyphs: { [string]: Frame } = {}
    for _, sym in cfg.symbols do
        local frame = cfg.render(tile, sym, INK, TILE)
        frame.Name = `Glyph_{sym}`
        frame.Visible = false
        frame.ZIndex = GLYPH_Z
        -- ZINDEX ON THE LAYERS, NOT JUST THE FRAME. This SurfaceGui renders with
        -- ZIndexBehavior.Global, where paint order is ZIndex alone and the hierarchy counts for
        -- nothing -- a child does NOT draw above its parent. Glyphs.render leaves its two
        -- ImageLabels at the default ZIndex 1, which put them underneath the opaque ivory tile
        -- at 2: drawn at full size, correctly placed, and completely covered. The flipper showed
        -- a blank flap for exactly this reason.
        for _, layer in frame:GetChildren() do
            if layer:IsA("ImageLabel") then
                layer.ZIndex = if layer.Name == "Core" then CORE_Z else OUTLINE_Z
            end
        end
        glyphs[sym] = frame
    end

    local seam = Instance.new("Frame")
    seam.Size = UDim2.fromScale(1, 0.035)
    seam.Position = UDim2.fromScale(0, 0.5)
    seam.AnchorPoint = Vector2.new(0, 0.5)
    seam.BackgroundColor3 = SEAM
    seam.BorderSizePixel = 0
    seam.ZIndex = SEAM_Z
    seam.Parent = tile

    return glyphs
end

function GlyphFlipper.new(cfg: Config)
    local self = setmetatable({
        _cfg = cfg,
        _faces = {},
        _shown = nil :: string?,
        _dead = false,
    }, GlyphFlipper)
    for _, face in cfg.faces or { Enum.NormalId.Front } do
        table.insert(self._faces, buildFace(cfg, face))
    end
    return self
end

-- `symbol` nil means blank: no glyph visible, the flap showing its bare face.
function GlyphFlipper.show(self: any, symbol: string?)
    if self._dead or self._shown == symbol then
        return
    end
    self._shown = symbol
    for _, glyphs in self._faces do
        for sym, frame in glyphs do
            local squash = TweenService:Create(frame, TweenInfo.new(FLIP_SECONDS), { Size = SQUASHED })
            if sym == symbol then
                frame.Size = SQUASHED
                frame.Visible = true
                TweenService:Create(frame, TweenInfo.new(FLIP_SECONDS), { Size = FULL }):Play()
            elseif frame.Visible then
                squash:Play()
                squash.Completed:Once(function()
                    frame.Visible = false
                end)
            end
        end
    end
end

function GlyphFlipper.destroy(self: any)
    self._dead = true
    for _, gui in self._cfg.part:GetChildren() do
        if gui:IsA("SurfaceGui") and gui.Name == "FlapFace" then
            gui:Destroy()
        end
    end
    table.clear(self._faces)
end

return GlyphFlipper
