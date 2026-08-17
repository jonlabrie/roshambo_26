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
local StatsData = remotes:WaitForChild("StatsData") :: RemoteEvent

local INK = Color3.fromRGB(40, 30, 18)
local FACE = Color3.fromRGB(244, 238, 222)
local PRINTED_INK = Color3.fromRGB(214, 202, 178)
-- THE CLOCK'S FACE IS ITS OWN CHOICE, not the wall boards'. JosefinSans is the owner's gate pick
-- for lettering, but its NUMERALS were rejected on sight (2026-08-17): it is a geometric display
-- face and its digits are mannered where a clock wants them plain.
--
-- LIVE, so faces can be auditioned without a commit per guess:
--   workspace:SetAttribute("ClockFont", "Inconsolata")
--
-- Probed in Studio rather than guessed -- all of these exist as bundled families and all measure
-- distinctly, so none is silently falling back. Width of "0123456789" at size 100:
--   RobotoMono 455  Inconsolata 480   -- true monospace: every digit the same width, which is
--                                        exactly what a physical flap cell is
--   Oswald     342  TitilliumWeb 370  -- condensed, classic departure-board
--   DenkOne    427  Bangers      422  -- heavy display
--   Michroma   677                    -- very wide, technical
-- OSWALD is the owner's pick (2026-08-17). My default had been RobotoMono, reasoning that a flap
-- board IS monospaced -- one cell, one width, always -- which is a good argument about mechanism
-- and lost to how the face actually looks in the room. Oswald is the classic departure-board
-- answer and the room is a departure board.
--
-- ⚠ IT IS CONDENSED: 342 wide for ten digits against RobotoMono's 455, so a digit fills roughly
-- half its cell rather than two thirds. If it reads narrow, that is the face and not a bug --
-- widen the cell or lift CLOCK_CHAR_FRACTION, do not reach for a wider font.
-- Only ever used if a live ClockFont names a family that will not construct.
local FALLBACK_FONT =
    Font.new("rbxasset://fonts/families/JosefinSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
-- WEIGHT, LIVE ALONGSIDE THE FAMILY. Hardcoding Bold meant a face could not be compared against
-- its own Regular -- and for a MONOSPACED family that is the only way to tell a weight exists at
-- all, since measuring proves nothing: a mono's advance width is fixed by definition, so
-- Inconsolata returns the same 480 for all nine weights whether or not they differ.
--
--   workspace:SetAttribute("ClockFontWeight", "Regular")   -- Thin..Heavy
local function weightFor(): Enum.FontWeight
    local live = workspace:GetAttribute("ClockFontWeight")
    if typeof(live) == "string" then
        local w = (Enum.FontWeight :: any)[live]
        if w then
            return w
        end
    end
    return Enum.FontWeight.Bold
end

local DEFAULT_CLOCK_FAMILY = "Oswald"
local function clockFont(): Font
    local live = workspace:GetAttribute("ClockFont")
    local family = if typeof(live) == "string" and live ~= "" then live else DEFAULT_CLOCK_FAMILY
    local ok, f = pcall(function()
        return Font.new(`rbxasset://fonts/families/{family}.json`, weightFor(), Enum.FontStyle.Normal)
    end)
    return if ok then f else FALLBACK_FONT
end

-- ABOVE 1.0 ON PURPOSE. A digit's drawn height is only ~0.72 of its TextSize (see FlapUnit), so
-- 0.9 was putting ink at roughly 0.65 of the cell -- which is why the clock still read small after
-- being given "50% larger" and getting exactly that. 1.2 puts the numeral near 0.86 of the cell.
-- Safe above 1.0 because a numeral has no descender to clip.
local CLOCK_CHAR_FRACTION = 1.2

-- OPTICAL SEAT FOR THE CLOCK'S FACE, as a fraction of the character's height. NEGATIVE IS UP.
-- Same problem the wall boards have and the same reason it cannot be one number for both: where
-- a numeral sits inside its em is a property of the face, and Oswald rides low where
-- TitilliumWeb does not. Live on `ClockTextNudge`.
-- The colon sits low in its column: a colon's dots straddle the baseline region rather than the
-- cap height the numerals fill, so centring its BOX does not centre what you see. Negative is up.
local COLON_NUDGE_ATTR = "ClockColonNudge"
local DEFAULT_COLON_NUDGE = -0.08
local function colonNudge(): number
    local live = workspace:GetAttribute(COLON_NUDGE_ATTR)
    return if typeof(live) == "number" then live else DEFAULT_COLON_NUDGE
end

local CLOCK_NUDGE_ATTR = "ClockTextNudge"
local DEFAULT_CLOCK_NUDGE = -0.03
local function clockTextNudge(): number
    local live = workspace:GetAttribute(CLOCK_NUDGE_ATTR)
    return if typeof(live) == "number" then live else DEFAULT_CLOCK_NUDGE
end

-- Paper is a horizontal bar and the hinge is a horizontal line, so centred on the seam the two
-- coincide and the bar is bisected by the thing it most resembles. Live-tunable: this is a by-eye
-- number and reading it off an attribute beats another sync-and-rejoin per guess.
local function glyphNudge(sym: string): number
    local live = workspace:GetAttribute(`GlyphNudge{sym}`)
    return if typeof(live) == "number" then live else (Glyphs.SEAM_NUDGE[sym] or 0)
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

-- EVERY LABEL AND GLYPH BUILT, so a live attribute change can reach the ones already on the wall.
-- Both of these are by-eye numbers being auditioned; reading them only at build time meant a
-- Studio restart per candidate, which is a poor loop for the one thing an owner has to judge by
-- looking. Kept as plain lists because they are written once per flap and read only on a change.
-- Records, not bare labels: a live nudge has to recompute a Position from the label's own anchor
-- and character height, which a plain list of TextLabels cannot supply.
local clockLabels: { { label: TextLabel, anchorY: number, charPx: number } } = {}
local glyphFrames: { { frame: Frame, sym: string, side: number, anchorY: number } } = {}

local function textPainter(part: BasePart, canvasW: number, canvasH: number, anchorY: number)
    local clip = surface(part, canvasW, canvasH)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = UDim2.fromOffset(canvasW, canvasH * 2) -- a full character; the panel shows half
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    t.Position = UDim2.new(0.5, 0, anchorY, clockTextNudge() * canvasH * 2)
    t.TextSize = FlapUnit.GLYPH_PX
    t.FontFace = clockFont()
    t.TextColor3 = INK
    t.TextScaled = false
    t.Text = " "
    t.Parent = clip
    table.insert(clockLabels, { label = t, anchorY = anchorY, charPx = canvasH * 2 })
    return function(v: string?)
        t.Text = v or " "
    end
end

local function glyphPainter(part: BasePart, canvasW: number, canvasH: number, anchorY: number)
    local clip = surface(part, canvasW, canvasH)
    -- SQUARE, AND IT MUST FIT THE NARROWER AXIS. A full character is two half-panels tall, which
    -- is right for the throw flipper's square cell -- but the tape's cells are wall-module sized,
    -- taller than they are wide, and a square at full height would be clipped left and right.
    local side = math.min(canvasW, canvasH * 2)
    local set: { [string]: Frame } = {}
    for _, sym in RoundDisplay.SYMBOLS do
        local f = Glyphs.render(clip, sym, INK, FACE)
        -- NO OUTLINE (owner, 2026-08-17: "the white stroke is unneeded"). Glyphs.render draws a
        -- wider outline behind the core so a caller can tint the two separately -- the lanterns
        -- want gilt-on-ink. On an ivory flap face there is nothing for a light keyline to
        -- separate the glyph FROM, so it just reads as a halo. Hidden rather than tinted to
        -- match: tinting it to the ink colour would silently fatten every glyph.
        local outline = f:FindFirstChild("Outline")
        if outline then
            outline.Visible = false
        end
        f.Size = UDim2.fromOffset(side, side)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0.5, 0, anchorY, glyphNudge(sym) * side)
        f.Visible = false
        set[sym] = f
        table.insert(glyphFrames, { frame = f, sym = sym, side = side, anchorY = anchorY })
    end
    return function(v: string?)
        for sym, f in set do
            f.Visible = sym == v
        end
    end
end

-- LIVE RE-TUNING. Both attributes are read on change and applied to what already exists, so a
-- font can be auditioned or a glyph nudged without restarting Play.
for _, attr in { "ClockFont", "ClockFontWeight", CLOCK_NUDGE_ATTR, COLON_NUDGE_ATTR } do
    workspace:GetAttributeChangedSignal(attr):Connect(function()
        local f = clockFont()
        local nudge = clockTextNudge()
        for _, e in clockLabels do
            e.label.FontFace = f
            e.label.Position = UDim2.new(0.5, 0, e.anchorY, nudge * e.charPx)
        end
    end)
end

for _, sym in RoundDisplay.SYMBOLS do
    workspace:GetAttributeChangedSignal(`GlyphNudge{sym}`):Connect(function()
        for _, g in glyphFrames do
            if g.sym == sym then
                g.frame.Position = UDim2.new(0.5, 0, g.anchorY, glyphNudge(sym) * g.side)
            end
        end
    end)
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

-- THE TAPE: the last ten World Throws, newest at the viewer's left.
--
-- GATED ON THE DRUM like everything else that names a throw. The server pushes the tape the
-- moment a round settles, which is ~3.45s before the drum stops -- so a tape applied on arrival
-- would print the answer while the drum was still turning, in the same room as the flipper that
-- exists to withhold it. Held until `drumRest`, exactly as StatsController holds the wall boards.
local shownTape: any = nil
local pendingTape: any = nil

-- ===== THE CHANGEOVER IS A SHOW, NOT AN EVENT =====
-- Every cell used to turn on the same frame, which reads as the board being redrawn rather than
-- as a row of flaps working. They cascade left to right now, and turn half again as slowly as the
-- clock's digits: the tape is the one thing in the room whose whole job is to be watched, and it
-- has the time -- it starts at `drumRest`, 3.45s into a 7s REVEAL, and a ten-cell sweep at this
-- pacing finishes in about 1.3s of the 3.55s left.
local TAPE_STAGGER = 0.12
local TAPE_HALF_SECONDS = 0.0825 -- 50% slower than FlapUnit's default

-- A cascade in flight when the next one starts would interleave two sequences on the same cells.
-- The token lets the newer sweep abandon the older mid-flight rather than fight it.
local tapeToken = 0

local function applyTape(cascade: boolean?)
    local tape = units.roundTape
    if not tape then
        return
    end
    tapeToken += 1
    local token = tapeToken
    local nth = 0
    -- Ordered, not `for c, unit in tape`: a dictionary's iteration order is arbitrary, and the
    -- whole point here is that the cells fire left to right. Column 1 is the viewer's leftmost.
    for c = 1, RoundDisplay.TAPE_COLUMNS do
        local unit = tape[c]
        local i = RoundDisplay.tapeIndexFor(c)
        if unit and i then
            nth += 1
            local entry = shownTape and shownTape[i]
            -- nil is the drum's blank position, which is what a tape shorter than ten throws
            -- shows -- and what every cell shows before a single round has closed.
            local value = entry and entry.worldThrow or nil
            if cascade then
                task.delay((nth - 1) * TAPE_STAGGER, function()
                    if tapeToken == token then
                        unit:set(value)
                    end
                end)
            else
                unit:set(value)
            end
        end
    end
end

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
    elseif id == "roundTape" then
        local made: { [number]: any } = {}
        for c, col in Layout.columns(spec) do
            if RoundDisplay.tapeIndexFor(c) then
                made[c] = FlapUnit.new({
                    board = part,
                    localX = col.x,
                    width = col.w,
                    height = spec.h,
                    paint = glyphPainter,
                    halfSeconds = TAPE_HALF_SECONDS,
                    -- A divider only between two cells that both exist: one bracketing the gap
                    -- would fence off empty board and undo the separation the gap is for.
                    dividerAfter = RoundDisplay.tapeIndexFor(c + 1) ~= nil,
                })
            end
        end
        units[id] = made
        applyTape()
    elseif id == "roundClock" then
        local statics = RoundDisplay.statics()
        local made: { [number]: any } = {}
        local boardFace: Frame? = nil
        for c, col in Layout.columns(spec) do
            if statics[c] then
                -- PRINTED, NOT FLIPPED: a fixed separator gets no mechanism at all. Painted onto
                -- the BOARD's own face between the flaps, so it needs no part of its own.
                --
                -- ONE surface for the whole board, not one per column. A SurfaceGui always maps
                -- to the ENTIRE face, so a canvas sized to a single column would stretch that
                -- column across the whole board.
                if not boardFace then
                    -- Same canvas scale the digit flaps use, so the separator is set at the size
                    -- of the numerals it separates rather than at one of its own.
                    local half = FlapUnit.halfCanvasFor(CLOCK_CHAR_FRACTION)
                    boardFace = surface(part, math.floor(half * 2 * (spec.w / spec.h)), half * 2)
                end
                local t = Instance.new("TextLabel")
                t.BackgroundTransparency = 1
                t.TextSize = FlapUnit.GLYPH_PX
                t.FontFace = clockFont()
                t.TextColor3 = PRINTED_INK
                t.Text = statics[c]
                -- The column's own slice of that face. MINUS, not plus: a SurfaceGui canvas runs
                -- left-to-right as seen from the front, and the viewer's left is local +X -- so
                -- canvas fraction and local X run in OPPOSITE directions. Getting this backwards
                -- put the colon at 0.64 where it belongs at 0.36, directly behind column three's
                -- flap panels, which is why it read as missing rather than misplaced.
                t.AnchorPoint = Vector2.new(0.5, 0.5)
                t.Position = UDim2.fromScale(0.5 - col.x / spec.w, 0.5 + colonNudge())
                t.Size = UDim2.fromScale(col.w / spec.w, 1)
                t.Parent = boardFace
            else
                made[c] = FlapUnit.new({
                    board = part,
                    localX = col.x,
                    width = col.w,
                    height = spec.h,
                    paint = textPainter,
                    charFraction = CLOCK_CHAR_FRACTION,
                    -- A divider only where two FLAP columns meet. The colon already separates
                    -- what sits either side of it, so a bar there would be a second separator
                    -- doing the same job.
                    dividerAfter = c < spec.cols and not statics[c + 1] and not statics[c],
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

StatsData.OnClientEvent:Connect(function(data)
    if shownTape == nil then
        -- First payload on join is history: its newest entry is a round that revealed before this
        -- client existed, so holding it would leave the tape blank until the next reveal.
        shownTape = data.tape
        applyTape()
    else
        pendingTape = data.tape
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        rested = true
        contactAt, reelSpent = nil, true
        if pending then
            landed = pending
        end
        if pendingTape then
            shownTape = pendingTape
            pendingTape = nil
        end
        -- Applied on the cue rather than on arrival: the drum has finished announcing the round
        -- the tape's newest entry describes. THIS is the one that cascades -- it is the round
        -- changeover, and the only moment anyone is watching the tape rather than reading it.
        applyTape(true)
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
