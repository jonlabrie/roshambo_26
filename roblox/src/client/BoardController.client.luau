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

local COLS = 28
local ROWS = { "LAST5", "WORLDREC", "HOTSTREAK", "PLAYERS", "TICKER1", "TICKER2" }
local GLYPH = { R = "○", P = "─", S = "∧" }

local faces: { { { TextLabel } } } = {} -- face -> row -> col
local current: { [number]: string } = {} -- row -> displayed line

-- Cell metrics: 2x canvas density + heavy face for read-at-distance
-- (gate feedback 2026-06-07: board doubled, font legibility).
local CELL_W, CELL_H = 72, 104
local CELL_STEP_X, CELL_STEP_Y = 80, 116

local function buildFace(faceEnum: Enum.NormalId): { { TextLabel } }
    local gui = Instance.new("SurfaceGui")
    gui.Face = faceEnum
    gui.CanvasSize = Vector2.new(2240, 720)
    gui.Parent = board
    local grid: { { TextLabel } } = {}
    for r = 1, #ROWS do
        grid[r] = {}
        for c = 1, COLS do
            local cell = Instance.new("TextLabel")
            cell.Size = UDim2.fromOffset(CELL_W, CELL_H)
            cell.Position = UDim2.fromOffset((c - 1) * CELL_STEP_X + 8, (r - 1) * CELL_STEP_Y + 12)
            cell.BackgroundColor3 = Color3.fromRGB(244, 238, 222)
            cell.TextColor3 = Color3.fromRGB(58, 46, 30)
            cell.TextScaled = true
            cell.Font = Enum.Font.GothamBlack
            cell.Text = " "
            cell.Parent = gui
            grid[r][c] = cell
        end
    end
    return grid
end

local function flapTo(cell: TextLabel, char: string)
    local squash = TweenService:Create(cell, TweenInfo.new(0.04), { Size = UDim2.fromOffset(CELL_W, 8) })
    squash:Play()
    squash.Completed:Once(function()
        cell.Text = char
        TweenService:Create(cell, TweenInfo.new(0.04), { Size = UDim2.fromOffset(CELL_W, CELL_H) }):Play()
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
        setRow(5, "THE WORLD CHOOSES SOON")
    elseif info.phase == "TALLY" then
        setRow(5, "THE WORLD CHOOSES NOW")
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
