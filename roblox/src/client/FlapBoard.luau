--!strict
-- Split-flap renderer for ONE board part. Client-side by construction: the SurfaceGui is parented
-- to a world part from a LocalScript, and client-created instances do not replicate — which is
-- exactly what makes a per-viewer board need no new mechanism (spec §6.1).
--
-- Lifted from BoardController.client.luau, which drew the removed jumbotron and has been retired
-- (plan ruling R1). Cell metrics now arrive from StatsBoardModel.metrics instead of being file
-- constants, so one renderer serves a 16x9 banzuke sheet and a 38x2.4 clerestory band alike.
local TweenService = game:GetService("TweenService")

local FlapBoard = {}
FlapBoard.__index = FlapBoard

export type Metrics = { canvasW: number, canvasH: number, glyphSize: number }
export type Config = {
    part: BasePart,
    rows: number,
    cols: number,
    metrics: Metrics,
    -- FlapScheduler.plan, injected so this module requires nothing and the caller owns the
    -- tuning per board. The third parameter is FlapScheduler's Opts, and it is plumbed
    -- deliberately: `drums` below cannot work without it.
    plan: (current: string, target: string, opts: any?) -> { any },
    faces: { Enum.NormalId }?,
    -- ONE DRUM PER COLUMN, and this is what a physical board actually has (owner, 2026-08-17):
    -- "a drum that is only ever going to show digits should only ever have digits on it. It's a
    -- different drum." A seconds flap carries ten digits and has never had a `U` on it to roll
    -- past. Without this every cell shared one 49-character drum, so a countdown going 3 -> 2
    -- travelled the long way round through the alphabet.
    --
    -- When present, each column is planned against its OWN drum and the columns are staggered
    -- here rather than by the scheduler, which cannot know a column's real index when it is
    -- handed a single character. Absent, the whole line is planned once as before.
    drums: { string }?,
    staggerMs: number?,
    -- PRINTED COLUMNS, not flipping ones (owner, 2026-08-17): "the colon should be printed
    -- between the minute and seconds columns, not in a flipper column of its own". A separator
    -- is painted on the board, not mounted on a drum -- no real board puts a fixed colon on a
    -- flap. These columns get no tile, no seam and no fold: just ink on the dark frame, and the
    -- planner skips them entirely so they can never be asked to turn.
    static: { [number]: string }?,
    -- Per-column width multipliers, defaulting to 1. Lets a printed separator take half a flap's
    -- width instead of a whole one; the grid is no longer uniform, so cells are positioned
    -- cumulatively rather than by index.
    colWidths: { number }?,
}

local PAD = 0.08 -- inset fraction within each cell
local DEFAULT_STAGGER_MS = 60 -- matches FlapScheduler's own default

local function toChars(str: string): { string }
    local out: { string } = {}
    for _, code in utf8.codes(str) do
        table.insert(out, utf8.char(code))
    end
    return out
end
-- JosefinSans was the owner's gate pick on 2026-06-07 (`77d8940`, "softer, elegant"). It was
-- replaced by Merriweather two hours later the same evening (`331f13d`) with no gate note --
-- an unapproved substitution that then rode into this module with the extraction. Restored
-- 2026-08-17 at the owner's word: "typeface is wrong, let's see JosefinSans".
-- FontFace, not the legacy Font enum, because the enum has no weight. Probed against the
-- bundled family 2026-08-17: Thin..Bold all measure differently, ExtraBold and Heavy return
-- Bold's exact bounds -- so Bold is the heaviest real face and anything above it falls back.
local BOARD_FONT =
    Font.new("rbxasset://fonts/families/JosefinSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
-- ===== A REAL SPLIT-FLAP, NOT A SQUASH (owner, 2026-08-17) =====
-- "You're not actually animating flips, you're just scrolling numbers?" -- correct, and worse
-- than scrolling: the old cell squashed the CHARACTER vertically and swapped it, so the cell
-- never split at all.
--
-- The mechanism a real board has, and this now has:
--   * The cell is two clipped halves. Both show the same character, which is centred ON THE SEAM
--     so its top half falls in the upper clip and its bottom half in the lower one.
--   * A LEAF sits over them, carrying the outgoing character above the seam and the incoming one
--     below it -- the two faces of one physical flap.
--   * Falling: the upper clip is switched to the NEW character immediately and the leaf, hinged
--     at the seam, closes downward over it -- so the old top is progressively eaten from above
--     while the new top is revealed behind.
--   * Landing: the leaf re-opens below the seam carrying the NEW character's bottom half, sweeping
--     down over the old one, and the lower clip commits at the end.
--
-- THE CHARACTER NEVER MOVES. Only the clip window does. That is what separates a flap from a
-- squash: the ink is still, and a physical edge sweeps across it.
local HALF_SECONDS = 0.04 -- each half of the flip; a full turn is twice this
local TILE_COLOR = Color3.fromRGB(244, 238, 222)
local SEAM_COLOR = Color3.fromRGB(150, 142, 124)
local INK = Color3.fromRGB(40, 30, 18)
local PRINTED_INK = Color3.fromRGB(214, 202, 178)

type Cell = {
    upper: TextLabel,
    lower: TextLabel,
    leaf: Frame,
    leafLabel: TextLabel,
    text: string,
    token: number,
}

local function label(parent: Instance, cellW: number, cellH: number, anchorY: number, size: number): TextLabel
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.TextColor3 = INK
    t.TextScaled = false
    t.TextSize = size
    t.FontFace = BOARD_FONT
    t.TextXAlignment = Enum.TextXAlignment.Center
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.Text = " "
    t.ZIndex = 3
    -- FULL CELL HEIGHT, CENTRED ON THE SEAM, inside a half-height clip. `anchorY` says which edge
    -- of the clip the seam is: 1 for the upper half (seam at its bottom), 0 for the lower.
    t.Size = UDim2.fromOffset(cellW, cellH)
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    t.Position = UDim2.fromScale(0.5, anchorY)
    -- All-caps ride high because the line box reserves descender space; drop them to optical
    -- centre, exactly as the single-label cell did.
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0.1, 0)
    pad.Parent = t
    t.Parent = parent
    return t
end

local function clip(parent: Instance, cellW: number, halfH: number, top: boolean, z: number): Frame
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1
    f.ClipsDescendants = true
    f.Size = UDim2.fromOffset(cellW, halfH)
    f.Position = UDim2.fromOffset(0, if top then 0 else halfH)
    f.ZIndex = z
    f.Parent = parent
    return f
end

local function buildFace(cfg: Config, faceEnum: Enum.NormalId): { { Cell } }
    local gui = Instance.new("SurfaceGui")
    gui.Name = "FlapFace"
    gui.Face = faceEnum
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(cfg.metrics.canvasW, cfg.metrics.canvasH)
    gui.Parent = cfg.part

    -- Cumulative column layout. With uniform widths this reduces exactly to the old
    -- `(c - 1) / cols`, so nothing changes for a board that does not ask for weights.
    local units, offsets = 0, {}
    for c = 1, cfg.cols do
        offsets[c] = units
        units += (cfg.colWidths and cfg.colWidths[c]) or 1
    end

    local rowH = cfg.metrics.canvasH / cfg.rows
    local grid: { { Cell } } = {}
    for r = 1, cfg.rows do
        grid[r] = {}
        for c = 1, cfg.cols do
            local printed = cfg.static and cfg.static[c]
            local colW = cfg.metrics.canvasW * (((cfg.colWidths and cfg.colWidths[c]) or 1) / units)
            local tileW = colW * (1 - PAD)
            local tileH = rowH * (1 - PAD)
            local halfH = tileH / 2

            local tile = Instance.new("Frame")
            tile.Size = UDim2.fromOffset(tileW, tileH)
            tile.Position = UDim2.fromOffset(
                cfg.metrics.canvasW * (offsets[c] / units) + colW * PAD / 2,
                (r - 1) * rowH + rowH * PAD / 2
            )
            -- A printed column carries no flap face: the separator reads as painted on the frame
            -- between two flaps rather than as a third flap that happens never to move.
            tile.BackgroundTransparency = if printed then 1 else 0
            tile.BackgroundColor3 = TILE_COLOR
            tile.BorderSizePixel = 0
            tile.ClipsDescendants = true
            tile.ZIndex = 2
            tile.Parent = gui

            if printed then
                -- One static label, no halves and no leaf. A painted separator has no mechanism,
                -- and giving it one would cost seven instances per cell to animate nothing.
                local t = label(tile, tileW, tileH, 0.5, cfg.metrics.glyphSize)
                t.Text = printed
                t.TextColor3 = PRINTED_INK
                grid[r][c] = {
                    upper = t,
                    lower = t,
                    leaf = tile,
                    leafLabel = t,
                    text = printed,
                    token = 0,
                    w = tileW,
                    halfH = halfH,
                    printed = true,
                } :: any
                continue
            end

            -- The two halves. Each holds a FULL-height label centred on the seam, so the upper
            -- clip shows the character's top half and the lower clip its bottom half.
            local upperClip = clip(tile, tileW, halfH, true, 2)
            local lowerClip = clip(tile, tileW, halfH, false, 2)
            local upper = label(upperClip, tileW, tileH, 1, cfg.metrics.glyphSize)
            local lower = label(lowerClip, tileW, tileH, 0, cfg.metrics.glyphSize)

            -- The leaf: the moving flap, above both halves. Hinged at the seam in both
            -- directions, which is why its AnchorPoint is reassigned mid-flip rather than fixed.
            local leaf = Instance.new("Frame")
            leaf.Name = "Leaf"
            leaf.BackgroundColor3 = TILE_COLOR
            leaf.BorderSizePixel = 0
            leaf.ClipsDescendants = true
            leaf.Visible = false
            leaf.ZIndex = 3
            leaf.Size = UDim2.fromOffset(tileW, halfH)
            leaf.Parent = tile
            -- THE LEAF'S INK FOLDS WITH THE LEAF. Sized in SCALE of the leaf (200%, so it is a
            -- full cell tall when the leaf is at half height) and TextScaled, so as the leaf
            -- collapses toward the hinge the character compresses into it. The first version
            -- pinned the character still and shrank a clip over it, which wipes rather than
            -- folds -- the owner's word was "unreadable", and that is why.
            --
            -- The size constraint is what keeps the handoff invisible: TextScaled alone would
            -- pick its own size at full height and jump against the static halves, so it is
            -- capped at exactly the glyph size those halves use.
            local leafLabel = label(leaf, tileW, tileH, 1, cfg.metrics.glyphSize)
            leafLabel.Size = UDim2.fromScale(1, 2)
            leafLabel.TextScaled = true
            local cap = Instance.new("UITextSizeConstraint")
            cap.MaxTextSize = cfg.metrics.glyphSize
            cap.Parent = leafLabel
            leafLabel.ZIndex = 4

            local seam = Instance.new("Frame")
            seam.Size = UDim2.fromOffset(tileW, math.max(1, tileH * 0.035))
            seam.Position = UDim2.fromOffset(0, halfH)
            seam.AnchorPoint = Vector2.new(0, 0.5)
            seam.BackgroundColor3 = SEAM_COLOR
            seam.BorderSizePixel = 0
            seam.ZIndex = 5
            seam.Parent = tile

            grid[r][c] = {
                upper = upper,
                lower = lower,
                leaf = leaf,
                leafLabel = leafLabel,
                text = " ",
                token = 0,
                w = tileW,
                halfH = halfH,
            } :: any
        end
    end
    return grid
end

-- One turn of one flap. Two tweens hinged at the seam: the outgoing face closing down over the
-- incoming top, then the incoming face opening down over the outgoing bottom.
local function flapTo(cell: any, char: string)
    if cell.printed or cell.text == char then
        return
    end
    local outgoing = cell.text
    cell.text = char
    cell.token += 1
    local token = cell.token
    local leaf, leafLabel = cell.leaf, cell.leafLabel

    -- FALLING. The upper half commits to the new character straight away; the leaf carries the
    -- OLD one and folds down over it, so the new top is revealed from under a descending edge.
    --
    -- THE LOWER HALF SHOWS THE OUTGOING CHARACTER FOR THE WHOLE FALL, and is set here rather
    -- than left to the landing tween. It used to commit only when the landing FINISHED, so any
    -- flip interrupted before then left the bottom half stale -- and at ReelStep's 0.05s interval
    -- against an 0.08s turn, every flip is interrupted. The owner saw exactly that: "for much of
    -- the rotation only the top panel is displaying anything, the bottom panel is blank."
    cell.upper.Text = char
    cell.lower.Text = outgoing
    leafLabel.Text = outgoing
    leafLabel.Position = UDim2.fromScale(0.5, 1) -- centred on the leaf's bottom = the seam
    leaf.AnchorPoint = Vector2.new(0, 1)
    leaf.Position = UDim2.fromOffset(0, cell.halfH)
    leaf.Size = UDim2.fromOffset(cell.w, cell.halfH)
    leaf.Visible = true

    local fall =
        TweenService:Create(leaf, TweenInfo.new(HALF_SECONDS), { Size = UDim2.fromOffset(cell.w, 0) })
    fall:Play()
    fall.Completed:Once(function()
        -- A newer step overtook this one mid-turn: abandon quietly rather than fight it. At the
        -- reel's fastest interval flaps genuinely do overlap, and a physical board blurs too.
        if cell.token ~= token then
            return
        end
        -- LANDING. The leaf now shows the incoming face and opens downward over the old bottom.
        leafLabel.Text = char
        leafLabel.Position = UDim2.fromScale(0.5, 0) -- centred on the leaf's top = the seam
        leaf.AnchorPoint = Vector2.new(0, 0)
        leaf.Position = UDim2.fromOffset(0, cell.halfH)
        leaf.Size = UDim2.fromOffset(cell.w, 0)
        local land = TweenService:Create(
            leaf,
            TweenInfo.new(HALF_SECONDS),
            { Size = UDim2.fromOffset(cell.w, cell.halfH) }
        )
        land:Play()
        land.Completed:Once(function()
            if cell.token ~= token then
                return
            end
            cell.lower.Text = char
            leaf.Visible = false
        end)
    end)
end

function FlapBoard.new(cfg: Config)
    local self = setmetatable({
        _cfg = cfg,
        _faces = {},
        _current = {} :: { [number]: string },
        _dead = false,
    }, FlapBoard)
    for _, face in cfg.faces or { Enum.NormalId.Front } do
        table.insert(self._faces, buildFace(cfg, face))
    end
    return self
end

function FlapBoard.setRow(self: any, row: number, line: string)
    if self._dead or row < 1 or row > self._cfg.rows then
        return
    end
    local current = self._current[row] or ""
    self._current[row] = line

    local function schedule(col: number, atMs: number, char: string)
        task.delay(atMs / 1000, function()
            if self._dead then
                return
            end
            for _, grid in self._faces do
                local cell = grid[row][col]
                if cell then
                    flapTo(cell, char)
                end
            end
        end)
    end

    local drums = self._cfg.drums
    if drums then
        local cur, tgt = toChars(current), toChars(line)
        local stagger = self._cfg.staggerMs or DEFAULT_STAGGER_MS
        local static = self._cfg.static
        for col = 1, self._cfg.cols do
            local drum = if static and static[col] then nil else drums[col]
            if drum then
                -- One character in, so every returned step is col 1; the real column index and
                -- its stagger are applied here.
                for _, step in self._cfg.plan(cur[col] or " ", tgt[col] or " ", { drum = drum }) do
                    schedule(col, step.atMs + (col - 1) * stagger, step.char)
                end
            end
        end
        return
    end

    -- No byte-based truncation anywhere on this path: a :sub() could split a multibyte glyph
    -- and crash utf8.codes inside the scheduler. Columns past `cols` are dropped by the
    -- nil-cell guard inside `schedule` instead.
    for _, step in self._cfg.plan(current, line) do
        schedule(step.col, step.atMs, step.char)
    end
end

function FlapBoard.setAll(self: any, lines: { string })
    for i, line in lines do
        self:setRow(i, line)
    end
end

function FlapBoard.destroy(self: any)
    self._dead = true
    for _, gui in self._cfg.part:GetChildren() do
        if gui:IsA("SurfaceGui") and gui.Name == "FlapFace" then
            gui:Destroy()
        end
    end
    table.clear(self._faces)
end

return FlapBoard
