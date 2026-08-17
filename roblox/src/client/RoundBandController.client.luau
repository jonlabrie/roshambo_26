--!strict
-- Drives the four clerestory band segments (spec section 6.3). Separate from StatsController
-- because it runs on a different clock: the walls repaint on a 60s poll, the band ticks every
-- half-second off the same published schedule the HUD reads.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Layout = require(shared:WaitForChild("StatsRoomLayout"))
local Model = require(shared:WaitForChild("StatsBoardModel"))
local BandModel = require(shared:WaitForChild("RoundBandModel"))
local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local FlapBoard = require(script.Parent:WaitForChild("FlapBoard"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local segments: { [Instance]: { board: any, cols: number } } = {}
local metronome = RoundMetronome.new()
local pendingWorldThrow: string? = nil
local worldRested = false
local ownThrow: string? = nil
local lastLine: string? = nil

local function register(part: Instance)
    if not part:IsA("BasePart") or segments[part] then
        return
    end
    local id = part:GetAttribute("BoardId")
    if typeof(id) ~= "string" or id:sub(1, 4) ~= "band" then
        return
    end
    local rows = tonumber(part:GetAttribute("Rows")) or 1
    local cols = tonumber(part:GetAttribute("Cols")) or 1
    segments[part] = {
        cols = cols,
        board = FlapBoard.new({
            part = part,
            rows = rows,
            cols = cols,
            metrics = Model.metrics(rows, cols, part.Size.X / part.Size.Y),
            plan = FlapScheduler.plan,
        }),
    }
end

for _, part in CollectionService:GetTagged(Layout.TAG) do
    register(part)
end
CollectionService:GetInstanceAddedSignal(Layout.TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(Layout.TAG):Connect(function(part)
    local seg = segments[part]
    if seg then
        seg.board:destroy()
        segments[part] = nil
    end
end)

-- Same source the HUD's countdown uses (main.client.luau's `pullSchedule`): the replicated
-- RoundScheduleConfig attributes, read through RoundMetronome so the band slews with the HUD
-- rather than drifting against it.
task.spawn(function()
    local cfg = ReplicatedStorage:WaitForChild("RoundScheduleConfig")
    local function pull()
        local strikeAt = cfg:GetAttribute("StrikeAtServerTime")
        local periodSec = cfg:GetAttribute("PeriodSec")
        if typeof(strikeAt) ~= "number" or typeof(periodSec) ~= "number" then
            return
        end
        metronome:setSchedule({
            roundId = cfg:GetAttribute("RoundId") :: string?,
            strikeAt = strikeAt,
            periodSec = periodSec,
            openSec = (cfg:GetAttribute("OpenSec") :: number?) or 51,
            lockSec = (cfg:GetAttribute("LockSec") :: number?) or 2,
            revealSec = (cfg:GetAttribute("RevealSec") :: number?) or 7,
        }, workspace:GetServerTimeNow())
    end
    pull()
    for _, attr in { "StrikeAtServerTime", "PeriodSec", "RoundId", "OpenSec", "LockSec", "RevealSec" } do
        cfg:GetAttributeChangedSignal(attr):Connect(pull)
    end
end)

EventBus.HudPick.Event:Connect(function(sym: string)
    ownThrow = sym
end)

RevealTheater.OnClientEvent:Connect(function(r)
    -- STASHED, NOT SHOWN. RevealTheater lands at the top of REVEAL and the drum does not settle
    -- until DrumStep.SETTLE_SECONDS after the strike; painting here would name the throw about
    -- three seconds before the drum does. This is the exact defect the retired BoardController
    -- carried (plan ruling R1).
    pendingWorldThrow = r.worldThrow
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        worldRested = true
    end
end)

-- Half-second cadence: fast enough that the seconds field is never visibly stale, slow enough
-- that the flap cells are not asked to re-plan mid-roll. Nothing is sent to a board unless the
-- composed line actually changed, so a still second costs one string compare.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt: number)
    accumulator += dt
    if accumulator < 0.5 then
        return
    end
    accumulator = 0
    local reading = metronome:read(workspace:GetServerTimeNow())
    if reading and reading.phase == "OPEN" then
        -- A new OPEN is the round boundary: clear last round's throw, world and own alike.
        if worldRested or pendingWorldThrow then
            pendingWorldThrow, worldRested, ownThrow = nil, false, nil
        end
    end
    local line = BandModel.line({
        phase = reading and reading.phase,
        secondsLeft = reading and reading.secondsLeft,
        worldThrow = pendingWorldThrow,
        worldRested = worldRested,
        ownThrow = ownThrow,
    }, 16)
    if line == lastLine then
        return
    end
    lastLine = line
    for _, seg in segments do
        seg.board:setRow(1, line)
    end
end)
