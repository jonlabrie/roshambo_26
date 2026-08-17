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

-- FIX 5: `cols` is READ now (BandModel.line's width and the change-suppression cache both key
-- off it), not just recorded. `lastLine` moved in here, per segment, so suppression is per-width
-- rather than a single global that would go stale the moment two segments disagree on `cols`.
local segments: { [Instance]: { board: any, cols: number, lastLine: string? } } = {}
local metronome = RoundMetronome.new()
local pendingWorldThrow: string? = nil
local worldRested = false
local ownThrow: string? = nil

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
        lastLine = nil,
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

-- FIX 3: NOT EventBus.HudPick — that fires on every accepted TAP (including a tap on a
-- different glyph that leaves the actual pick unchanged, and a second tap on the chosen glyph
-- that backs the pick out) rather than on every accepted PICK. EventBus.HudState is
-- main.client.luau's 10Hz publish of its authoritative local state, `inputs.chosen` is the same
-- field the tap handler itself writes and later sends at lockout, and it is already nil after a
-- back-out and at round start — so, unlike HudPick, this needs no separate clearing below.
EventBus.HudState.Event:Connect(function(inputs)
    ownThrow = inputs.chosen
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
        -- A new OPEN is the round boundary: clear last round's world throw. `ownThrow` needs NO
        -- clearing here (FIX 3) — it now tracks main.client.luau's `chosen`, which HudState
        -- already reports as nil at round start and after any back-out, so a stale pick from
        -- this reset racing a fresh pick in early OPEN is no longer possible.
        if worldRested or pendingWorldThrow then
            pendingWorldThrow, worldRested = nil, false
        end
    end
    local state = {
        phase = reading and reading.phase,
        secondsLeft = reading and reading.secondsLeft,
        worldThrow = pendingWorldThrow,
        worldRested = worldRested,
        ownThrow = ownThrow,
    }
    -- FIX 5: per segment, at ITS OWN `cols` — not a hardcoded 16 shared by every segment
    -- regardless of what its board attribute actually says. The suppression cache moves with it.
    for _, seg in segments do
        local line = BandModel.line(state, seg.cols)
        if line ~= seg.lastLine then
            seg.lastLine = line
            seg.board:setRow(1, line)
        end
    end
end)
