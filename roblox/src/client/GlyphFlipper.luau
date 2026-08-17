--!strict
-- THE ROUND DISPLAY'S THROW FLIPPER — one large flap that shows the World Throw.
--
-- NOT a FlapBoard cell. The owner asked for "the same standard glyph outlines as those found on
-- the drum and the lanterns", which are `Glyphs.IMAGE`: a core+outline ImageLabel pair rendered
-- from the PWA's SVGs, not the text characters the flap drum carries. Sharing the assets is the
-- point -- the same shape appears on the drum, the lanterns, the HUD and here, so a player learns
-- one vocabulary rather than four.
--
-- IT OWNS NO CLOCK. It used to run its own spin loop on a private interval, which is precisely how
-- it ended up 2.45s ahead of the HUD's ring. The caller hands it a glyph every frame, computed
-- from the same ReelStep the ring uses, so the two cannot drift.
--
-- THE MECHANISM IS FlapBoard's, so the two read as one machine: two clipped halves showing a glyph
-- centred on the seam, and a leaf hinged there carrying the outgoing face above and the incoming
-- face below. The glyph never moves; only the clip window does.
local TweenService = game:GetService("TweenService")

local GlyphFlipper = {}
GlyphFlipper.__index = GlyphFlipper

export type Config = {
    part: BasePart,
    -- Glyphs.render, injected so this module requires nothing (the DI convention every other
    -- client module here follows).
    render: (parent: Instance, symbol: string, coreColor: Color3, outlineColor: Color3?) -> Frame,
    symbols: { string },
    faces: { Enum.NormalId }?,
}

-- Matching FlapBoard's cell exactly, so the flipper reads as one of the same flaps at scale.
local TILE = Color3.fromRGB(244, 238, 222)
local SEAM = Color3.fromRGB(150, 142, 124)
local INK = Color3.fromRGB(40, 30, 18)
local PAD = 0.08
local CANVAS = 512
local HALF_SECONDS = 0.04 -- each half of the turn; a full flip is twice this
-- Paint order under ZIndexBehavior.Global: tile and halves, the glyph's outline, its core, the
-- leaf above all of it, and the seam on top.
local TILE_Z, GLYPH_Z, OUTLINE_Z, CORE_Z, LEAF_Z, SEAM_Z = 2, 3, 3, 4, 5, 6

-- PER-GLYPH VERTICAL NUDGE, as a fraction of the panel (owner, 2026-08-17: "the Paper glyph needs
-- to be slightly lower, so that it's entirely on the lower panel instead of split by the hinge").
-- Paper is a horizontal bar and the hinge is a horizontal line, so centred on the seam the two
-- coincide and the bar is bisected by the very thing it looks like. Ring and chevron have open
-- centres and read fine across the hinge, so only P moves. Gate-tunable by eye.
local NUDGE: { [string]: number } = { P = 0.10 }

type Face = {
    upper: { [string]: Frame },
    lower: { [string]: Frame },
    leaf: Frame,
    leafSet: { [string]: Frame },
    side: number,
    halfH: number,
}

-- One glyph set inside one clip. Each frame is FULL-PANEL height centred on the seam, so an upper
-- clip shows the glyph's top half and a lower clip its bottom half.
local function glyphSet(parent: Instance, cfg: Config, side: number, anchorY: number): { [string]: Frame }
    local set: { [string]: Frame } = {}
    for _, sym in cfg.symbols do
        local frame = cfg.render(parent, sym, INK, TILE)
        frame.Name = `Glyph_{sym}`
        frame.Visible = false
        frame.ZIndex = GLYPH_Z
        frame.Size = UDim2.fromOffset(side, side)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.new(0.5, 0, anchorY, (NUDGE[sym] or 0) * side)
        -- ZINDEX ON THE LAYERS, NOT JUST THE FRAME. This SurfaceGui renders with
        -- ZIndexBehavior.Global, where paint order is ZIndex alone and the hierarchy counts for
        -- nothing -- a child does NOT draw above its parent. Glyphs.render leaves its two
        -- ImageLabels at the default ZIndex 1, which put them underneath the opaque ivory tile at
        -- 2: drawn at full size, correctly placed, and completely covered.
        for _, layer in frame:GetChildren() do
            if layer:IsA("ImageLabel") then
                layer.ZIndex = if layer.Name == "Core" then CORE_Z else OUTLINE_Z
            end
        end
        set[sym] = frame
    end
    return set
end

local function clip(parent: Instance, side: number, halfH: number, top: boolean): Frame
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1
    f.ClipsDescendants = true
    f.Size = UDim2.fromOffset(side, halfH)
    f.Position = UDim2.fromOffset(0, if top then 0 else halfH)
    f.ZIndex = TILE_Z
    f.Parent = parent
    return f
end

local function reveal(set: { [string]: Frame }, symbol: string?)
    for sym, frame in set do
        frame.Visible = sym == symbol
    end
end

local function buildFace(cfg: Config, faceEnum: Enum.NormalId): Face
    local gui = Instance.new("SurfaceGui")
    gui.Name = "FlapFace"
    gui.Face = faceEnum
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(CANVAS, CANVAS)
    gui.Parent = cfg.part

    local side = CANVAS * (1 - PAD)
    local halfH = side / 2

    local tile = Instance.new("Frame")
    tile.Name = "Tile"
    tile.Size = UDim2.fromOffset(side, side)
    tile.Position = UDim2.fromOffset(CANVAS * PAD / 2, CANVAS * PAD / 2)
    tile.BackgroundColor3 = TILE
    tile.BorderSizePixel = 0
    tile.ClipsDescendants = true
    tile.ZIndex = TILE_Z
    tile.Parent = gui

    local upperClip = clip(tile, side, halfH, true)
    local lowerClip = clip(tile, side, halfH, false)

    local leaf = Instance.new("Frame")
    leaf.Name = "Leaf"
    leaf.BackgroundColor3 = TILE
    leaf.BorderSizePixel = 0
    leaf.ClipsDescendants = true
    leaf.Visible = false
    leaf.ZIndex = LEAF_Z
    leaf.Size = UDim2.fromOffset(side, halfH)
    leaf.Parent = tile

    local seam = Instance.new("Frame")
    seam.Size = UDim2.fromOffset(side, math.max(1, side * 0.035))
    seam.Position = UDim2.fromOffset(0, halfH)
    seam.AnchorPoint = Vector2.new(0, 0.5)
    seam.BackgroundColor3 = SEAM
    seam.BorderSizePixel = 0
    seam.ZIndex = SEAM_Z
    seam.Parent = tile

    return {
        -- The seam is the upper clip's BOTTOM edge and the lower clip's TOP, so a glyph centred
        -- on it sits at anchorY 1 above and 0 below.
        upper = glyphSet(upperClip, cfg, side, 1),
        lower = glyphSet(lowerClip, cfg, side, 0),
        leaf = leaf,
        leafSet = glyphSet(leaf, cfg, side, 1),
        side = side,
        halfH = halfH,
    }
end

function GlyphFlipper.new(cfg: Config)
    local self = setmetatable({
        _cfg = cfg,
        _faces = {},
        _shown = nil :: string?,
        _token = 0,
        _dead = false,
    }, GlyphFlipper)
    for _, face in cfg.faces or { Enum.NormalId.Front } do
        table.insert(self._faces, buildFace(cfg, face))
    end
    return self
end

-- `symbol` nil means blank: the flap showing its bare face, which is what LOCK and the swing use.
function GlyphFlipper.show(self: any, symbol: string?)
    if self._dead or self._shown == symbol then
        return
    end
    local outgoing = self._shown
    self._shown = symbol
    self._token += 1
    local token = self._token

    for _, face in self._faces do
        -- FALLING. The upper half commits to the incoming glyph at once; the leaf carries the
        -- outgoing one down over it, hinged at the seam, so the new top is revealed from under a
        -- descending edge rather than swapped in place.
        reveal(face.upper, symbol)
        for sym, frame in face.leafSet do
            -- centred on the leaf's bottom = the seam, keeping each glyph's own nudge
            frame.Position = UDim2.new(0.5, 0, 1, (NUDGE[sym] or 0) * face.side)
        end
        reveal(face.leafSet, outgoing)
        -- THE LOWER HALF SHOWS THE OUTGOING GLYPH FOR THE WHOLE FALL. It used to commit only
        -- when the landing FINISHED, so any turn interrupted before then left the bottom blank --
        -- and at ReelStep's 0.05s interval against an 0.08s turn, every turn is interrupted.
        -- That is the blank bottom panel the owner saw through most of the spin.
        reveal(face.lower, outgoing)
        face.leaf.AnchorPoint = Vector2.new(0, 1)
        face.leaf.Position = UDim2.fromOffset(0, face.halfH)
        face.leaf.Size = UDim2.fromOffset(face.side, face.halfH)
        face.leaf.Visible = true

        local fall = TweenService:Create(
            face.leaf,
            TweenInfo.new(HALF_SECONDS),
            { Size = UDim2.fromOffset(face.side, 0) }
        )
        fall:Play()
        fall.Completed:Once(function()
            -- A newer glyph overtook this turn: abandon quietly. At the reel's fastest interval
            -- (0.05s) flaps genuinely do overlap, and a physical board blurs too.
            if self._dead or self._token ~= token then
                return
            end
            -- LANDING. The leaf turns over to the incoming glyph and opens downward over the old
            -- bottom half, which commits when it finishes.
            for sym, frame in face.leafSet do
                -- centred on the leaf's top = the seam, keeping each glyph's own nudge
                frame.Position = UDim2.new(0.5, 0, 0, (NUDGE[sym] or 0) * face.side)
            end
            reveal(face.leafSet, symbol)
            face.leaf.AnchorPoint = Vector2.new(0, 0)
            face.leaf.Position = UDim2.fromOffset(0, face.halfH)
            face.leaf.Size = UDim2.fromOffset(face.side, 0)
            local land = TweenService:Create(
                face.leaf,
                TweenInfo.new(HALF_SECONDS),
                { Size = UDim2.fromOffset(face.side, face.halfH) }
            )
            land:Play()
            land.Completed:Once(function()
                if self._dead or self._token ~= token then
                    return
                end
                reveal(face.lower, symbol)
                face.leaf.Visible = false
            end)
        end)
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
