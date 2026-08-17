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
local GLYPH_FULL = UDim2.fromScale(1, 1)
local GLYPH_SQUASHED = UDim2.fromScale(1, 0.05)

local function buildFace(cfg: Config, faceEnum: Enum.NormalId): { { TextLabel } }
    local gui = Instance.new("SurfaceGui")
    gui.Name = "FlapFace"
    gui.Face = faceEnum
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(cfg.metrics.canvasW, cfg.metrics.canvasH)
    gui.Parent = cfg.part
    local cellW, cellH = 1 / cfg.cols, 1 / cfg.rows
    local grid: { { TextLabel } } = {}
    for r = 1, cfg.rows do
        grid[r] = {}
        for c = 1, cfg.cols do
            local tile = Instance.new("Frame")
            tile.Size = UDim2.fromScale(cellW * (1 - PAD), cellH * (1 - PAD))
            tile.Position =
                UDim2.fromScale((c - 1) * cellW + cellW * PAD / 2, (r - 1) * cellH + cellH * PAD / 2)
            tile.BackgroundColor3 = Color3.fromRGB(244, 238, 222)
            tile.BorderSizePixel = 0
            tile.ClipsDescendants = true
            tile.ZIndex = 2
            tile.Parent = gui

            local seam = Instance.new("Frame")
            seam.Size = UDim2.fromScale(1, 0.035)
            seam.Position = UDim2.fromScale(0, 0.5)
            seam.AnchorPoint = Vector2.new(0, 0.5)
            seam.BackgroundColor3 = Color3.fromRGB(150, 142, 124)
            seam.BorderSizePixel = 0
            seam.ZIndex = 4
            seam.Parent = tile

            local glyph = Instance.new("TextLabel")
            glyph.Size = GLYPH_FULL
            glyph.BackgroundTransparency = 1
            glyph.TextColor3 = Color3.fromRGB(40, 30, 18)
            glyph.TextScaled = false
            glyph.TextSize = cfg.metrics.glyphSize
            glyph.FontFace = BOARD_FONT
            glyph.TextXAlignment = Enum.TextXAlignment.Center
            glyph.TextYAlignment = Enum.TextYAlignment.Center
            glyph.Text = " "
            glyph.ZIndex = 3
            glyph.Parent = tile

            -- All-caps ride high because the line box reserves descender space; drop them to
            -- optical centre. Sibling of the seam so the padding never shifts the seam.
            local pad = Instance.new("UIPadding")
            pad.PaddingTop = UDim.new(0.1, 0)
            pad.Parent = glyph

            grid[r][c] = glyph
        end
    end
    return grid
end

local function flapTo(cell: TextLabel, char: string)
    local squash = TweenService:Create(cell, TweenInfo.new(0.04), { Size = GLYPH_SQUASHED })
    squash:Play()
    squash.Completed:Once(function()
        cell.Text = char
        TweenService:Create(cell, TweenInfo.new(0.04), { Size = GLYPH_FULL }):Play()
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
        for col = 1, self._cfg.cols do
            local drum = drums[col]
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
