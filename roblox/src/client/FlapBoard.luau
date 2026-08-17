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
    -- step/stagger tuning per board (a 1-row band wants a snappier roll than a 10-row sheet).
    plan: (current: string, target: string) -> { any },
    faces: { Enum.NormalId }?,
}

local PAD = 0.08 -- inset fraction within each cell
local BOARD_FONT = Enum.Font.Merriweather
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
            glyph.Font = BOARD_FONT
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
    -- No byte-based truncation anywhere on this path: a :sub() could split a multibyte glyph
    -- and crash utf8.codes inside the scheduler. Columns past `cols` are dropped by the
    -- nil-cell guard below instead.
    local plan = self._cfg.plan(self._current[row] or "", line)
    self._current[row] = line
    for _, step in plan do
        task.delay(step.atMs / 1000, function()
            if self._dead then
                return
            end
            for _, grid in self._faces do
                local cell = grid[row][step.col]
                if cell then
                    flapTo(cell, step.char)
                end
            end
        end)
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
