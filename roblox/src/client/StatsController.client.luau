--!strict
-- The Stats room's four content walls. Finds its boards by CollectionService tag (they are
-- place-only geometry — Rojo manages only what default.project.json names), builds one FlapBoard
-- per tagged part, and repaints whenever data or the fixtures toggle changes.
--
-- PER-VIEWER COMES FREE (spec section 6.1): this is a LocalScript, so every SurfaceGui it parents
-- to a world part exists only on this client. The `fuda` slip is private for that reason alone —
-- no Adornee, no PlayerGui, no new mechanism.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Layout = require(shared:WaitForChild("StatsRoomLayout"))
local Model = require(shared:WaitForChild("StatsBoardModel"))
local Glyphs = require(shared:WaitForChild("Glyphs"))
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local StatsFixtures = require(shared:WaitForChild("StatsFixtures"))
local FlapBoard = require(script.Parent:WaitForChild("FlapBoard"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local StatsData = remotes:WaitForChild("StatsData") :: RemoteEvent
local StatsPersonal = remotes:WaitForChild("StatsPersonal") :: RemoteEvent

-- THE WALL BOARDS' FACE, live so it can be auditioned the way the clock's was. Oswald won the
-- round timer on sight (owner, 2026-08-17) and the wall boards are still to be judged -- but they
-- are a different job: the timer shows four big numerals read at a glance, these show lines of
-- lettering read as text, and a condensed display face is not automatically right for both.
--
--   workspace:SetAttribute("BoardFont", "Oswald")
--
-- Applies to boards already built. A name that will not construct falls back to the default
-- rather than erroring, so a typo reads as "nothing changed" and not as a broken wall.
-- WEIGHT, LIVE ALONGSIDE THE FAMILY. Hardcoding Bold meant a face could not be compared against
-- its own Regular -- and for a MONOSPACED family that is the only way to tell a weight exists at
-- all, since measuring proves nothing: a mono's advance width is fixed by definition, so
-- Inconsolata returns the same 480 for all nine weights whether or not they differ.
--
--   workspace:SetAttribute("BoardFontWeight", "Regular")   -- Thin..Heavy
local function weightFor(): Enum.FontWeight
    local live = workspace:GetAttribute("BoardFontWeight")
    if typeof(live) == "string" then
        local w = (Enum.FontWeight :: any)[live]
        if w then
            return w
        end
    end
    return Enum.FontWeight.Bold
end

local BOARD_FONT_ATTR = "BoardFont"
-- TITILLIUMWEB is the owner's pick for the walls (2026-08-17), against Oswald on the round
-- timer. Two faces for two jobs: the timer shows four big numerals read at a glance, the walls
-- show lines of lettering read as text.
local DEFAULT_BOARD_FAMILY = "TitilliumWeb"
local function boardFont(): Font
    local live = workspace:GetAttribute(BOARD_FONT_ATTR)
    local family = if typeof(live) == "string" and live ~= "" then live else DEFAULT_BOARD_FAMILY
    local ok, f = pcall(function()
        return Font.new(`rbxasset://fonts/families/{family}.json`, weightFor(), Enum.FontStyle.Normal)
    end)
    if ok then
        return f
    end
    return Font.new(
        `rbxasset://fonts/families/{DEFAULT_BOARD_FAMILY}.json`,
        weightFor(),
        Enum.FontStyle.Normal
    )
end

-- Walks the built cells rather than keeping a register of every label: a board is ~200 cells and
-- the room ~1,050, so a list would be thousands of entries maintained for an operation that
-- happens when somebody is choosing a font.
-- How far the caps are nudged down for optical centring, as a fraction of the cell. Entirely a
-- property of the face: 0.1 suited JosefinSans and sits TitilliumWeb low.
local TEXT_NUDGE_ATTR = "BoardTextNudge"
local DEFAULT_TEXT_NUDGE = 0.02
local function textNudge(): number
    local live = workspace:GetAttribute(TEXT_NUDGE_ATTR)
    return if typeof(live) == "number" then live else DEFAULT_TEXT_NUDGE
end

local function applyBoardFont(part: Instance)
    local f = boardFont()
    local n = UDim.new(textNudge(), 0)
    for _, d in part:GetDescendants() do
        if d:IsA("TextLabel") then
            d.FontFace = f
        elseif d:IsA("UIPadding") then
            d.PaddingTop = n
        end
    end
end

local FIXTURE_ATTR = "StatsFixtures"
-- The round display's own parts belong to RoundDisplayController, not to this file. Same tag,
-- different clock entirely: these walls repaint on a 60s data poll, that one ticks every frame.
local function isRoundDisplay(id: string): boolean
    return id:sub(1, 5) == "round"
end

local boards: { [Instance]: { board: any, id: string, rows: number, cols: number } } = {}
local latestStats: any = nil
local latestPersonal: any = nil

-- ===== THE DRUM GATE, AND WHY THESE TWO BOARDS NEED ONE =====
--
-- THE WORLD THROW IS THE PLURALITY OF PLAYER THROWS (GameRules.deriveWorldThrow), so a board
-- showing "ROCK 45% PAPER 29% SCISSORS 26%" has NAMED the World Throw. `world` carries the
-- throw outright. Both read the tape, and the tape gains its newest entry at settlement --
-- about 3.45s before the drum out in the arena comes to rest.
--
-- Until 2026-08-17 neither board was gated, and both were safe only by accident: the stats poll
-- was 60s against a 60s round, so it aliased and happened to land after the drum had settled.
-- Fixing the aliasing (the owner noticed the summary only ever refreshed with ~4s left in a
-- round) would have turned that accident into a spoiler on every reveal.
--
-- So tape-derived boards paint from `shownTape`, which only advances on the `drumRest` cue --
-- the same gate LanternController, TheaterController and main.client all hold their reveals on.
-- A dropped cue costs a round's freshness, never a spoiler.
local TAPE_BOARDS = { world = true, summary = true }
local shownTape: any = nil
local pendingTape: any = nil

local function newestId(tape: any): string?
    return tape and tape[1] and tape[1].id
end

local function useFixtures(): boolean
    return workspace:GetAttribute(FIXTURE_ATTR) == true
end

local function linesFor(id: string, rows: number, cols: number): { string }?
    local o = { rows = rows, cols = cols }
    local s = if useFixtures() then StatsFixtures.STATS else latestStats
    local p = if useFixtures() then StatsFixtures.PERSONAL else latestPersonal
    if id == "banzuke" then
        return Model.compose(Model.standingsSections(s and s.leaders), o)
    elseif id == "skill" then
        return Model.compose(Model.skillSections(s and s.recordsWeek, s and s.recordsAll), o)
    elseif id == "judgement" then
        return Model.compose(Model.judgementSections(s and s.recordsWeek), o)
    elseif id == "world" then
        -- `shownTape`, not `s.tape`: the drum gate above.
        local tape = if useFixtures() then StatsFixtures.STATS.tape else shownTape
        return Model.compose(Model.worldSections(tape, s and s.heat), o)
    elseif id == "fuda" then
        return Model.compose(Model.fudaSections(p), o)
    elseif id == "summary" then
        -- The vestibule's other slip. Reads the same StatsData the walls do -- `tape` is already
        -- in the payload for the form guide, so this board costs one adapter and no new wire.
        local tape = if useFixtures() then StatsFixtures.STATS.tape else shownTape
        return Model.compose(Model.summarySections(tape), o)
    end
    return nil
end

local function repaint(entry: { board: any, id: string, rows: number, cols: number })
    local lines = linesFor(entry.id, entry.rows, entry.cols)
    if lines then
        entry.board:setAll(lines)
    end
end

local function repaintAll()
    for _, entry in boards do
        repaint(entry)
    end
end

local function repaintTapeBoards()
    for _, entry in boards do
        if TAPE_BOARDS[entry.id] then
            repaint(entry)
        end
    end
end

-- THE SAME THREE SHAPES THE WHOLE EXPERIENCE USES. The drum carries ○ ─ ∧ as characters, but
-- Glyphs.IMAGE is what the taiko drum, the lanterns, the HUD and the round display's flipper all
-- wear -- so drawing them here as font glyphs made these boards the one place a throw looked like
-- something else (owner, 2026-08-17).
--
-- Returns nil for anything that is not a throw glyph, which is how FlapBoard tells a glyph cell
-- from a letter cell without knowing what a glyph is.
local CHAR_TO_SYMBOL: { [string]: string } = {}
for sym, ch in Model.GLYPH do
    CHAR_TO_SYMBOL[ch] = sym
end

local INK = Color3.fromRGB(40, 30, 18)
local TILE = Color3.fromRGB(244, 238, 222)

-- Live on the same attribute the round display reads, so one setting moves both.
local function glyphNudge(sym: string): number
    local live = workspace:GetAttribute(`GlyphNudge{sym}`)
    return if typeof(live) == "number" then live else (Glyphs.SEAM_NUDGE[sym] or 0)
end

-- `_cellW` is deliberately unused: the glyph is a SQUARE sized off the cell's height, so that a
-- ring stays round in a cell that is taller than it is wide. Kept in the signature because it is
-- FlapBoard's contract, not this builder's choice.
local function glyphFor(
    parent: Instance,
    char: string,
    _cellW: number,
    cellH: number,
    anchorY: number
): Frame?
    local sym = CHAR_TO_SYMBOL[char]
    if not sym then
        return nil
    end
    local f = Glyphs.render(parent, sym, INK, TILE)
    -- No outline: on an ivory face there is nothing for a light keyline to separate the glyph
    -- FROM, so it reads as a halo. Same call the round display makes.
    local outline = f:FindFirstChild("Outline")
    if outline then
        outline.Visible = false
    end
    -- A FULL-CELL SQUARE CENTRED ON THE SEAM, matching how a character is set: the upper clip
    -- then shows its top half and the lower clip its bottom, and the flip works unchanged.
    f.Name = `Glyph_{sym}`
    f.Size = UDim2.fromOffset(cellH, cellH)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    -- OFF THE SEAM. Paper is a horizontal bar and the seam a horizontal line, so centred it is
    -- bisected by the thing it most resembles -- the same fault the round display's flipper had,
    -- inherited here the moment these boards started wearing the same images. One default, in
    -- Glyphs beside the assets, so the two cannot drift apart.
    f.Position = UDim2.new(0.5, 0, anchorY, glyphNudge(sym) * cellH)
    f.Visible = false
    -- These surfaces render ZIndexBehavior.Global, where paint order is ZIndex alone and a child
    -- does NOT draw above its parent -- so the layers need lifting clear of the tile themselves.
    f.ZIndex = 3
    for _, layer in f:GetChildren() do
        if layer:IsA("ImageLabel") then
            layer.ZIndex = if layer.Name == "Core" then 4 else 3
        end
    end
    return f
end

local function register(part: Instance)
    if not part:IsA("BasePart") or boards[part] then
        return
    end
    local id = part:GetAttribute("BoardId")
    if typeof(id) ~= "string" or isRoundDisplay(id) then
        return
    end
    -- A shuttered board is CLOSED, not broken (spec section 8) — it gets no renderer at all, so
    -- there is nothing behind the leaves to leak through if one is ever opened by hand.
    if part:GetAttribute("Shuttered") == true then
        return
    end
    local rows = tonumber(part:GetAttribute("Rows")) or 1
    local cols = tonumber(part:GetAttribute("Cols")) or 1
    local entry = {
        id = id,
        rows = rows,
        cols = cols,
        board = FlapBoard.new({
            part = part,
            rows = rows,
            cols = cols,
            -- Aspect from the PART, not from the layout table: the Studio tool seats each board
            -- against measured rock and an owner may nudge one afterwards. Reading the part keeps
            -- the canvas matched to whatever is actually there, so glyphs never stretch.
            metrics = Model.metrics(rows, cols, part.Size.X / part.Size.Y),
            plan = FlapScheduler.plan,
            -- THE DRUM COMES FROM THE TRANSITION, NOT THE COLUMN (owner, 2026-08-18). The round
            -- display bolts a drum to each column because its columns have a fixed kind; these
            -- do not -- a name column holds a letter on one row and a space on the next, and a
            -- figure column holds a digit, a comma or a `%` depending on the board and the
            -- window. So the ladder picks the smallest drum carrying both characters, which
            -- keeps a digit-to-digit roll on ten characters where the 9-step cap never fires.
            drums = function(_col, current, target)
                return FlapScheduler.drumFor(current, target)
            end,
            textNudge = textNudge(),
            glyphFor = glyphFor,
        }),
    }
    boards[part] = entry
    repaint(entry)
    -- Also here, not just on the changed signal: a board built AFTER the attribute was set would
    -- otherwise come up in the default face while its neighbours wore the chosen one.
    applyBoardFont(part)
end

local function unregister(part: Instance)
    local entry = boards[part]
    if entry then
        entry.board:destroy()
        boards[part] = nil
    end
end

for _, part in CollectionService:GetTagged(Layout.TAG) do
    register(part)
end
CollectionService:GetInstanceAddedSignal(Layout.TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(Layout.TAG):Connect(unregister)

StatsData.OnClientEvent:Connect(function(data)
    latestStats = data
    -- HOLD ONLY A ROUND THE DRUM HAS NOT FINISHED ANNOUNCING. Everything else lands at once:
    -- the same round's payload with other fields moved, and -- deliberately -- the FIRST payload
    -- on join, whose newest entry is a round that revealed before this client existed. Holding
    -- that one for a `drumRest` up to a minute away would leave both boards reading NO DATA YET
    -- on arrival, which is the section 8 failure the empty state exists to avoid. The residual
    -- window is a player joining inside the 3.45s between strike and rest who then walks to a
    -- board within it, and the drum is not visible from either room anyway.
    if shownTape ~= nil and newestId(data.tape) ~= newestId(shownTape) then
        pendingTape = data.tape
    else
        shownTape = data.tape
    end
    repaintAll()
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" and pendingTape then
        shownTape = pendingTape
        pendingTape = nil
        repaintTapeBoards()
    end
end)

StatsPersonal.OnClientEvent:Connect(function(data)
    latestPersonal = data
    repaintAll()
end)

-- Live, so the owner can flip fixtures on and off in Studio and watch the walls change without
-- rejoining. Costs one attribute listener.
workspace:GetAttributeChangedSignal(FIXTURE_ATTR):Connect(repaintAll)

for sym in Glyphs.SEAM_NUDGE do
    workspace:GetAttributeChangedSignal(`GlyphNudge{sym}`):Connect(function()
        for part in boards do
            for _, d in part:GetDescendants() do
                if d:IsA("Frame") and d.Name == `Glyph_{sym}` then
                    -- The anchor is 1 for an upper half and 0 for a lower; it is already in the
                    -- frame's own Position, so only the offset is rewritten.
                    local cellH = d.AbsoluteSize.Y
                    d.Position = UDim2.new(0.5, 0, d.Position.Y.Scale, glyphNudge(sym) * cellH)
                end
            end
        end
    end)
end

for _, attr in { BOARD_FONT_ATTR, BOARD_FONT_ATTR .. "Weight", TEXT_NUDGE_ATTR } do
    workspace:GetAttributeChangedSignal(attr):Connect(function()
        for part in boards do
            applyBoardFont(part)
        end
    end)
end
