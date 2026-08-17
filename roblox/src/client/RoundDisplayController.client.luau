--!strict
-- Drives the round display: the throw flipper and the 0:00 countdown, high on the cavern's west
-- wall. Replaces RoundBandController and the four clerestory segments it drove.
--
-- WHY THE ROOM NEEDS THIS AT ALL: the Stats room is under ~18 studs of rock, out of sight and
-- earshot of the taiko drum that is the round's authoritative signal. Without it, walking in
-- here means silently dropping out of the game.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Layout = require(shared:WaitForChild("StatsRoomLayout"))
local Model = require(shared:WaitForChild("StatsBoardModel"))
local RoundDisplay = require(shared:WaitForChild("RoundDisplayModel"))
local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local Glyphs = require(shared:WaitForChild("Glyphs"))
local DrumStep = require(shared:WaitForChild("DrumStep"))
local FlapBoard = require(script.Parent:WaitForChild("FlapBoard"))
local GlyphFlipper = require(script.Parent:WaitForChild("GlyphFlipper"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local clock: any = nil -- FlapBoard over roundClock
local flipper: any = nil -- GlyphFlipper over roundThrow
local metronome = RoundMetronome.new()

-- `landed` is what the flipper is actually showing: the throw of the last round the DRUM has
-- finished announcing. `pending` is the throw for the round in flight, which arrives on
-- RevealTheater about 3.45s before the drum stops -- stashed, never shown, until `rested`.
local landed: string? = nil
local pending: string? = nil
local rested = false
local lastClock: string? = nil

-- CONTACT, LATCHED THE WAY THE HUD LATCHES IT (HudController's `reelStartedAt`). Derived from the
-- REVEAL phase edge plus the shu-moku's swing, NOT from the `gongHit` cue -- that cue can drop,
-- which is the entire reason main.client carries a reveal-safety fallback, and a dropped cue would
-- leave this flap blank for the whole settle. `reelSpent` stops a re-arm after the drum has
-- answered, since "REVEAL and no answer yet" and "REVEAL, answered" look identical from here.
local contactAt: number? = nil
local reelSpent = false

local function register(part: Instance)
    if not part:IsA("BasePart") then
        return
    end
    local id = part:GetAttribute("BoardId")
    if id == "roundClock" and not clock then
        local rows = tonumber(part:GetAttribute("Rows")) or 1
        local cols = tonumber(part:GetAttribute("Cols")) or 4
        clock = FlapBoard.new({
            part = part,
            rows = rows,
            cols = cols,
            metrics = Model.metrics(rows, cols, part.Size.X / part.Size.Y),
            plan = FlapScheduler.plan,
            -- The owner's ruling made concrete: digit columns get a digits-only drum, the colon
            -- gets a drum of its own. Nothing here can roll through the alphabet.
            drums = RoundDisplay.drums(),
            static = RoundDisplay.statics(),
        })
    elseif id == "roundThrow" and not flipper then
        flipper = GlyphFlipper.new({
            part = part,
            render = Glyphs.render,
            symbols = RoundDisplay.SYMBOLS,
        })
    end
end

local function unregister(part: Instance)
    local id = part:GetAttribute("BoardId")
    if id == "roundClock" and clock then
        clock:destroy()
        clock = nil
    elseif id == "roundThrow" and flipper then
        flipper:destroy()
        flipper = nil
    end
end

for _, part in CollectionService:GetTagged(Layout.TAG) do
    register(part)
end
CollectionService:GetInstanceAddedSignal(Layout.TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(Layout.TAG):Connect(unregister)

-- The same replicated schedule the HUD reads, through the same pure metronome, so the room and
-- the arena never disagree about how long is left.
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

RevealTheater.OnClientEvent:Connect(function(r)
    -- STASHED, NOT SHOWN. This lands at the top of REVEAL; the drum does not settle until
    -- DrumStep.SETTLE_SECONDS later. Painting here is the spoiler five displays in this project
    -- have each been corrected for.
    pending = r.worldThrow
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        rested = true
        contactAt, reelSpent = nil, true -- the drum has answered; the reel's job is done
        if pending then
            landed = pending
        end
    end
end)

-- THE STATE TICK at 10Hz, matching the cadence HudController's `render` runs at -- fast enough to
-- catch a phase edge without a visible lag, and all the clock's seconds field needs.
local accumulator = 0
local function currentPhase(): string?
    local reading = metronome:read(workspace:GetServerTimeNow())
    return reading and reading.phase, reading and reading.secondsLeft
end

RunService.Heartbeat:Connect(function(dt: number)
    accumulator += dt
    if accumulator < 0.1 then
        return
    end
    accumulator = 0

    local phase, secondsLeft = currentPhase()

    if phase == "OPEN" then
        -- A fresh round: the reel is armed again but does not run during OPEN.
        if rested or pending or contactAt or reelSpent then
            rested, pending, contactAt, reelSpent = false, nil, nil, false
        end
    elseif phase == "REVEAL" and not reelSpent and contactAt == nil then
        contactAt = os.clock() + DrumStep.STRIKE_SWING_SECONDS
    end

    if clock then
        local line = RoundDisplay.clock({ phase = phase, secondsLeft = secondsLeft })
        if line ~= lastClock then
            lastClock = line
            clock:setRow(1, line)
        end
    end
end)

-- THE REEL AT FRAME RATE, and for the same reason the HUD's is: ReelStep's fastest interval is
-- 0.05s, which the 10Hz tick above cannot resolve -- driven from it the flap would cycle at half
-- speed and stutter. `show` is latched, so the frames between changes cost one comparison.
RunService.RenderStepped:Connect(function()
    if not flipper then
        return
    end
    local reading = metronome:read(workspace:GetServerTimeNow())
    local s = RoundDisplay.throwState({
        phase = reading and reading.phase,
        previousThrow = landed,
        worldThrow = pending,
        worldRested = rested,
        contactElapsed = if contactAt then os.clock() - contactAt else nil,
    })
    flipper:show(s.glyph)
end)
