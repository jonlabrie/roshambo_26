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

-- Cell metrics: 18 cols × 6 rows over a high-res canvas. Big bold glyphs that
-- nearly fill the tile so the board reads from across the bowl (gate feedback
-- 2026-06-07: tiles were unreadable — too many, too thin, seam cut the glyph).
local CANVAS_W, CANVAS_H = 4608, 1536
local CELL_STEP_X = CANVAS_W / COLS -- 256
local CELL_STEP_Y = CANVAS_H / #ROWS -- 256
local CELL_GAP = 14
local CELL_W = CELL_STEP_X - CELL_GAP
local CELL_H = CELL_STEP_Y - CELL_GAP
local GLYPH_SIZE = math.floor(CELL_H * 0.92) -- glyph nearly fills the tile height

local function buildFace(faceEnum: Enum.NormalId): { { TextLabel } }
    local gui = Instance.new("SurfaceGui")
    gui.Face = faceEnum
    gui.CanvasSize = Vector2.new(CANVAS_W, CANVAS_H)
    gui.Parent = board
    local grid: { { TextLabel } } = {}
    for r = 1, #ROWS do
        grid[r] = {}
        for c = 1, COLS do
            local cell = Instance.new("TextLabel")
            cell.Size = UDim2.fromOffset(CELL_W, CELL_H)
            cell.Position =
                UDim2.fromOffset((c - 1) * CELL_STEP_X + CELL_GAP / 2, (r - 1) * CELL_STEP_Y + CELL_GAP / 2)
            cell.BackgroundColor3 = Color3.fromRGB(244, 238, 222)
            cell.TextColor3 = Color3.fromRGB(40, 30, 18)
            cell.TextSize = GLYPH_SIZE
            cell.Font = Enum.Font.GothamBlack -- heaviest built-in face
            cell.Text = " "
            cell.Parent = gui
            -- split-flap midline: thin fold seam, drawn UNDER the glyph (low
            -- ZIndex) so it doesn't slice the character's legibility.
            local seam = Instance.new("Frame")
            seam.Size = UDim2.new(1, 0, 0, 6)
            seam.Position = UDim2.new(0, 0, 0.5, -3)
            seam.BackgroundColor3 = Color3.fromRGB(196, 188, 168)
            seam.BorderSizePixel = 0
            seam.ZIndex = 1
            seam.Parent = cell
            cell.ZIndex = 2
            grid[r][c] = cell
        end
    end
    return grid
end

local function flapTo(cell: TextLabel, char: string)
    local squash = TweenService:Create(cell, TweenInfo.new(0.04), { Size = UDim2.fromOffset(CELL_W, 12) })
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
