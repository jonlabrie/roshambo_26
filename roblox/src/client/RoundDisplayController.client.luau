--!strict
-- Drives the round display: a throw flipper and a 0:00 countdown, high on the cavern's west wall.
--
-- WHY THE ROOM NEEDS IT: the Stats room is under ~18 studs of rock, out of sight and earshot of
-- the taiko drum that is the round's authoritative signal. Without it, walking in here means
-- silently dropping out of the game.
--
-- These four flaps are PHYSICAL (FlapUnit) rather than GUI, because Roblox GUI cannot foreshorten
-- and four attempts at faking a fold in it all read as a wipe or a shrink. Sixteen parts buys a
-- real hinge here; the wall boards' 1,050 cells keep the GUI approximation.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Layout = require(shared:WaitForChild("StatsRoomLayout"))
local RoundDisplay = require(shared:WaitForChild("RoundDisplayModel"))
local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))
local Glyphs = require(shared:WaitForChild("Glyphs"))
local DrumStep = require(shared:WaitForChild("DrumStep"))
local FlapUnit = require(script.Parent:WaitForChild("FlapUnit"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local INK = Color3.fromRGB(40, 30, 18)
local FACE = Color3.fromRGB(244, 238, 222)
local PRINTED_INK = Color3.fromRGB(214, 202, 178)
local FONT =
    Font.new("rbxasset://fonts/families/JosefinSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

-- Paper is a horizontal bar and the hinge is a horizontal line, so centred on the seam the two
-- coincide and the bar is bisected by the thing it most resembles. Live-tunable: this is a by-eye
-- number and reading it off an attribute beats another sync-and-rejoin per guess.
local function glyphNudge(sym: string): number
    local live = workspace:GetAttribute(`GlyphNudge{sym}`)
    return if typeof(live) == "number" then live else (if sym == "P" then 0.06 else 0)
end

-- A face carrying a full-height character, of which this panel shows half. `anchorY` 1 centres it
-- on the panel's bottom edge (the hinge, for an upper half); 0 centres it on the top edge.
local function surface(part: BasePart, canvasW: number, canvasH: number): Frame
    local gui = Instance.new("SurfaceGui")
    gui.Name = "FlapFace"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(canvasW, canvasH)
    -- SIBLING, explicitly. These surfaces default to Global, where paint order is ZIndex alone
    -- and a child does NOT draw above its parent -- which is how the throw glyph came to be drawn
    -- at full size, correctly placed, and completely hidden under its own tile.
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = part
    local clip = Instance.new("Frame")
    clip.Size = UDim2.fromScale(1, 1)
    clip.BackgroundTransparency = 1
    clip.ClipsDescendants = true
    clip.Parent = gui
    return clip
end

local function textPainter(part: BasePart, canvasW: number, canvasH: number, anchorY: number)
    local clip = surface(part, canvasW, canvasH)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = UDim2.fromOffset(canvasW, canvasH * 2) -- a full character; the panel shows half
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    t.Position = UDim2.fromScale(0.5, anchorY)
    t.TextSize = FlapUnit.GLYPH_PX
    t.FontFace = FONT
    t.TextColor3 = INK
    t.TextScaled = false
    t.Text = " "
    t.Parent = clip
    return function(v: string?)
        t.Text = v or " "
    end
end

local function glyphPainter(part: BasePart, canvasW: number, canvasH: number, anchorY: number)
    local clip = surface(part, canvasW, canvasH)
    local side = canvasH * 2
    local set: { [string]: Frame } = {}
    for _, sym in RoundDisplay.SYMBOLS do
        local f = Glyphs.render(clip, sym, INK, FACE)
        f.Size = UDim2.fromOffset(side, side)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0.5, 0, anchorY, glyphNudge(sym) * side)
        f.Visible = false
        set[sym] = f
    end
    return function(v: string?)
        for sym, f in set do
            f.Visible = sym == v
        end
    end
end

local metronome = RoundMetronome.new()
local units: { [string]: { [number]: any } } = {} -- boardId -> column -> FlapUnit
local throwUnit: any = nil

-- `landed` is what the flipper is showing: the throw of the last round the DRUM has finished
-- announcing. `pending` arrives on RevealTheater ~3.45s before the drum stops -- stashed, never
-- shown, until `rested`.
local landed: string? = nil
local pending: string? = nil
local rested = false
local lastClock: string? = nil

-- CONTACT, LATCHED THE WAY THE HUD LATCHES IT (HudController's `reelStartedAt`): from the REVEAL
-- phase edge plus the shu-moku's swing, NOT from the `gongHit` cue, which can drop.
local contactAt: number? = nil
local reelSpent = false

local function board(id: string): Layout.Board?
    for _, b in Layout.BOARDS do
        if b.id == id then
            return b
        end
    end
    return nil
end

local function register(part: Instance)
    if not part:IsA("BasePart") then
        return
    end
    local id = part:GetAttribute("BoardId")
    if typeof(id) ~= "string" or units[id] or (id == "roundThrow" and throwUnit) then
        return
    end
    local spec = board(id)
    if not spec then
        return
    end

    if id == "roundThrow" then
        local col = Layout.columns(spec)[1]
        throwUnit = FlapUnit.new({
            board = part,
            localX = col.x,
            width = col.w,
            height = spec.h,
            paint = glyphPainter,
        })
    elseif id == "roundClock" then
        local statics = RoundDisplay.statics()
        local made: { [number]: any } = {}
        for c, col in Layout.columns(spec) do
            if statics[c] then
                -- PRINTED, NOT FLIPPED: a fixed separator gets no mechanism at all. Painted
                -- straight onto the board's own face between the flaps.
                local clip = surface(
                    part,
                    math.floor(FlapUnit.HALF_CANVAS * (col.w / spec.h) * 2),
                    FlapUnit.HALF_CANVAS * 2
                )
                local t = Instance.new("TextLabel")
                t.BackgroundTransparency = 1
                t.Size = UDim2.fromScale(1, 1)
                t.TextSize = FlapUnit.GLYPH_PX
                t.FontFace = FONT
                t.TextColor3 = PRINTED_INK
                t.Text = statics[c]
                t.Parent = clip
                clip.Parent.Parent = part
                -- Position the separator's own surface over its column by giving it a part-sized
                -- canvas and offsetting the label; simpler than a second part for one colon.
                t.Position = UDim2.fromScale(0.5 + col.x / spec.w, 0.5)
                t.AnchorPoint = Vector2.new(0.5, 0.5)
                t.Size = UDim2.fromScale(col.w / spec.w, 1)
            else
                made[c] = FlapUnit.new({
                    board = part,
                    localX = col.x,
                    width = col.w,
                    height = spec.h,
                    paint = textPainter,
                })
            end
        end
        units[id] = made
    end
end

local function unregister(part: Instance)
    local id = part:GetAttribute("BoardId")
    if id == "roundThrow" and throwUnit then
        throwUnit:destroy()
        throwUnit = nil
    elseif typeof(id) == "string" and units[id] then
        for _, u in units[id] do
            u:destroy()
        end
        units[id] = nil
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
    -- DrumStep.SETTLE_SECONDS later.
    pending = r.worldThrow
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        rested = true
        contactAt, reelSpent = nil, true
        if pending then
            landed = pending
        end
    end
end)

-- 10Hz, matching HudController's `render`: fast enough to catch a phase edge without visible lag,
-- and all the clock's seconds field needs.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt: number)
    accumulator += dt
    if accumulator < 0.1 then
        return
    end
    accumulator = 0

    local reading = metronome:read(workspace:GetServerTimeNow())
    local phase = reading and reading.phase

    if phase == "OPEN" then
        if rested or pending or contactAt or reelSpent then
            rested, pending, contactAt, reelSpent = false, nil, nil, false
        end
    elseif phase == "REVEAL" and not reelSpent and contactAt == nil then
        contactAt = os.clock() + DrumStep.STRIKE_SWING_SECONDS
    end

    local clockUnits = units.roundClock
    if clockUnits then
        local line = RoundDisplay.clock({ phase = phase, secondsLeft = reading and reading.secondsLeft })
        if line ~= lastClock then
            lastClock = line
            for c, unit in clockUnits do
                unit:set(line:sub(c, c))
            end
        end
    end
end)

-- THE REEL AT FRAME RATE, for the same reason the HUD's ring is: ReelStep's fastest interval is
-- 0.05s, which the 10Hz tick cannot resolve -- driven from it the flap would cycle at half speed
-- and stutter. `set` is latched, so the frames between changes cost one comparison.
RunService.RenderStepped:Connect(function()
    if not throwUnit then
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
    throwUnit:set(s.glyph)
end)
