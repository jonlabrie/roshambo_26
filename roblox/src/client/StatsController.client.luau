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
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local StatsFixtures = require(shared:WaitForChild("StatsFixtures"))
local FlapBoard = require(script.Parent:WaitForChild("FlapBoard"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local StatsData = remotes:WaitForChild("StatsData") :: RemoteEvent
local StatsPersonal = remotes:WaitForChild("StatsPersonal") :: RemoteEvent

local FIXTURE_ATTR = "StatsFixtures"
-- The band ids belong to RoundBandModel's driver, not to this file. Same tag, different clock.
local function isBand(id: string): boolean
    return id:sub(1, 4) == "band"
end

local boards: { [Instance]: { board: any, id: string, rows: number, cols: number } } = {}
local latestStats: any = nil
local latestPersonal: any = nil

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
        return Model.compose(Model.worldSections(s and s.tape, s and s.heat), o)
    elseif id == "fuda" then
        return Model.compose(Model.fudaSections(p), o)
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

local function register(part: Instance)
    if not part:IsA("BasePart") or boards[part] then
        return
    end
    local id = part:GetAttribute("BoardId")
    if typeof(id) ~= "string" or isBand(id) then
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
        }),
    }
    boards[part] = entry
    repaint(entry)
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
    repaintAll()
end)

StatsPersonal.OnClientEvent:Connect(function(data)
    latestPersonal = data
    repaintAll()
end)

-- Live, so the owner can flip fixtures on and off in Studio and watch the walls change without
-- rejoining. Costs one attribute listener.
workspace:GetAttributeChangedSignal(FIXTURE_ATTR):Connect(repaintAll)
