--!strict
-- Renders the split-flap jumbotron on the placeholder board part (spec §4).
-- Placeholder fidelity: one TextLabel per cell with a Y-squash tween standing
-- in for the fold illusion; 4b dresses this without changing the scheduling.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local board = workspace:WaitForChild("RoshamboStage"):WaitForChild("JumbotronBoard")

local COLS = 18 -- fewer, bigger tiles read at distance (gate feedback 2026-06-07)
local ROWS = { "LAST5", "WORLDREC", "HOTSTREAK", "PLAYERS", "TICKER1", "TICKER2" }
local GLYPH = { R = "○", P = "─", S = "∧" }

local faces: { { { TextLabel } } } = {} -- face -> row -> col
local current: { [number]: string } = {} -- row -> displayed line

-- Cell metrics. KEY CONSTRAINT (learned the hard way 2026-06-07): Roblox
-- TextLabel.TextSize is hard-capped at 100px and TextScaled does not reliably
-- scale up on this SurfaceGui. So instead of a big canvas + big TextSize, use a
-- SMALL canvas where the 100px-capped glyph is already large relative to it;
-- the SurfaceGui stretches that small canvas across the 96-stud board, so a
-- TextSize-90 glyph maps to ~10 studs tall — readable across the bowl.
local CELL_W = 1 / COLS -- scale (positions/sizes are fractions of the face)
local CELL_H = 1 / #ROWS -- scale
local PAD = 0.08 -- inset fraction within each cell
local CANVAS_H = #ROWS * 150 -- ~150 canvas-px per row → the 90px glyph reads big
local CANVAS_W = math.floor(CANVAS_H * 168 / 96) -- match the 168x96 board aspect
local GLYPH_SIZE = 90 -- just under the 100px engine cap

local function buildFace(faceEnum: Enum.NormalId): { { TextLabel } }
    local gui = Instance.new("SurfaceGui")
    gui.Face = faceEnum
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(CANVAS_W, CANVAS_H)
    gui.Parent = board
    local grid: { { TextLabel } } = {}
    for r = 1, #ROWS do
        grid[r] = {}
        for c = 1, COLS do
            local cell = Instance.new("TextLabel")
            cell.Size = UDim2.fromScale(CELL_W * (1 - PAD), CELL_H * (1 - PAD))
            cell.Position =
                UDim2.fromScale((c - 1) * CELL_W + CELL_W * PAD / 2, (r - 1) * CELL_H + CELL_H * PAD / 2)
            cell.BackgroundColor3 = Color3.fromRGB(244, 238, 222)
            cell.TextColor3 = Color3.fromRGB(40, 30, 18)
            cell.TextScaled = false
            cell.TextSize = GLYPH_SIZE
            cell.Font = Enum.Font.GothamBlack -- heaviest built-in face
            cell.Text = " "
            cell.ZIndex = 2
            cell.Parent = gui
            -- split-flap midline: thin fold seam drawn OVER the glyph.
            local seam = Instance.new("Frame")
            seam.Size = UDim2.fromScale(1, 0.04)
            seam.Position = UDim2.fromScale(0, 0.48)
            seam.BackgroundColor3 = Color3.fromRGB(150, 142, 124)
            seam.BorderSizePixel = 0
            seam.ZIndex = 5
            seam.Parent = cell
            grid[r][c] = cell
        end
    end
    return grid
end

local CELL_FULL = UDim2.fromScale(CELL_W * (1 - PAD), CELL_H * (1 - PAD))
local CELL_SQUASHED = UDim2.fromScale(CELL_W * (1 - PAD), 0.004)

local function flapTo(cell: TextLabel, char: string)
    local squash = TweenService:Create(cell, TweenInfo.new(0.04), { Size = CELL_SQUASHED })
    squash:Play()
    squash.Completed:Once(function()
        cell.Text = char
        TweenService:Create(cell, TweenInfo.new(0.04), { Size = CELL_FULL }):Play()
    end)
end

local function setRow(row: number, line: string)
    -- No byte-based truncation: a :sub() could split a multibyte glyph and
    -- crash utf8.codes. Steps for columns beyond COLS are dropped by the
    -- nil-cell guard below.
    local target = line
    local plan = FlapScheduler.plan(current[row] or "", target)
    current[row] = target
    for _, step in plan do
        task.delay(step.atMs / 1000, function()
            for _, grid in faces do
                local cell = grid[row][step.col]
                if cell then
                    flapTo(cell, step.char)
                end
            end
        end)
    end
end

faces[1] = buildFace(Enum.NormalId.Front)
faces[2] = buildFace(Enum.NormalId.Back)

BoardData.OnClientEvent:Connect(function(d)
    local tape = ""
    for i = 1, math.min(5, #(d.tape or {})) do
        tape ..= (GLYPH[d.tape[i].worldThrow] or "?") .. " "
    end
    setRow(1, "LAST5 " .. tape)
    if d.worldRec then
        setRow(2, `REC {d.worldRec.points} {d.worldRec.name}`)
    end
    if d.hotStreak then
        setRow(3, `HOT {d.hotStreak.streak} {d.hotStreak.name}`)
    end
    setRow(4, `PLAYERS {d.playersNow}`)
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        setRow(5, "WORLD CHOOSES SOON")
    elseif info.phase == "TALLY" then
        setRow(5, "WORLD CHOOSES NOW")
    end
end)

RevealTheater.OnClientEvent:Connect(function(r)
    setRow(6, `WORLD THREW {GLYPH[r.worldThrow] or "?"}`)
end)

EventBus.TickerMessage.Event:Connect(function(line: string)
    setRow(5, line)
end)

-- Reference ZenDojo to satisfy the require (theme data is live-referenced;
-- boardHeader is used by 4b's SurfaceGui label).
local _ = ZenDojo.labels.boardHeader
