--!strict
-- Live-tunable AmbientBudget config, read from Workspace attributes, in ONE place.
--
-- This is a CLIENT module rather than part of AmbientBudget itself because it needs the `workspace`
-- global, and AmbientBudget must stay free of Roblox globals so Lune can test it. Four ambient
-- controllers need these same attribute reads; one module beats four copies. The shape --
-- a client ModuleScript required by sibling scripts -- is the same one FlapBoard.luau already uses.
--
-- ⚠ CACHED, AND THE RETURNED TABLE IS SHARED. DO NOT MUTATE IT.
-- The first version built a fresh table on every call, so a caller could never corrupt its
-- neighbours. That safety cost more than it was worth: `get()`/`arena()` are called once per
-- Heartbeat by each of five controllers -- and three times a frame by HammerController alone,
-- because each of its loops needs `interval` before it can decide whether to skip -- which came to
-- roughly five table allocations and nineteen `workspace:GetAttribute` reads EVERY FRAME. In the
-- arena, where the bell drive and waterwheel are always visible and nothing is ever culled, that
-- was pure overhead against zero saving (owner, 2026-09-05: the A13 felt worse, not better, and
-- almost all of it was played in the arena).
--
-- So the tables are built once and rebuilt only when one of the attributes actually changes. That
-- makes the steady-state cost of a call a single table read. The trade is that callers now share
-- one table: mutate it and every other controller sees the change. `arena()` therefore builds its
-- OWN table rather than mutating `get()`'s, which is exactly the bug this comment exists to
-- prevent -- the pre-cache version DID mutate it, harmlessly only because the table was disposable.
--
-- Attributes (all optional, all live-tunable during a walk without a rebuild):
--   AmbientRadius     studs; beyond this an ambient prop is not animated
--   AmbientBehindDot  normalized forward dot below which a prop counts as behind the camera
--   AmbientHz         updates per second while a prop IS animated (converted to an interval)
--   ArenaRadius       studs; the wider radius AmbientConfig.arena() applies for the bell drive
--                     and waterwheel, which read from much farther away than an ambient prop
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))

local AmbientConfig = {}

local ATTRS = { "AmbientRadius", "AmbientBehindDot", "AmbientHz", "ArenaRadius" }

local function num(attr: string, default: number): number
    local v = workspace:GetAttribute(attr)
    return if typeof(v) == "number" then v else default
end

local function build(radiusFloor: number?): AmbientBudget.Config
    local d = AmbientBudget.DEFAULT
    local hz = num("AmbientHz", 0)
    -- These are hand-typed into the Explorer live during a phone walk, so a typo must degrade
    -- gracefully rather than blank the world: a negative/mistyped radius would otherwise silently
    -- cull every ambient prop in the place, and a behindDot above 1 would cull everything
    -- regardless of facing.
    local radius = math.max(0, num("AmbientRadius", d.radius))
    return {
        radius = if radiusFloor then math.max(radius, radiusFloor) else radius,
        behindDot = math.clamp(num("AmbientBehindDot", d.behindDot), -1, 1),
        -- An unset or nonsensical AmbientHz falls back to the module default rather than dividing
        -- by zero or inverting a negative.
        interval = if hz > 0 then 1 / hz else d.interval,
    }
end

local cachedAmbient: AmbientBudget.Config? = nil
local cachedArena: AmbientBudget.Config? = nil

-- Invalidate rather than rebuild: the next caller rebuilds, so a burst of attribute edits during
-- live tuning costs one rebuild, not one per keystroke.
for _, attr in ATTRS do
    workspace:GetAttributeChangedSignal(attr):Connect(function()
        cachedAmbient = nil
        cachedArena = nil
    end)
end

-- ⚠ Returns a SHARED table. Read it; never write to it.
function AmbientConfig.get(): AmbientBudget.Config
    local c = cachedAmbient
    if c == nil then
        c = build(nil)
        cachedAmbient = c
    end
    return c :: AmbientBudget.Config
end

-- The arena machinery (bell drive, waterwheel) needs a far wider radius than the ambient props this
-- module was sized for. AmbientBudget.DEFAULT.radius (180) was chosen for a two-foot lantern that is
-- under a pixel past thirty feet; the bell drive and the waterwheel are the centrepiece of the place
-- and are read from the teahouse decks 340-400 studs out. Culling them at the lantern radius freezes
-- the arena from exactly the vantage the fireworks are watched from -- and the waterwheel's foam
-- emitter is not gated, so a culled wheel churns foam while standing still. Live-tunable separately
-- from AmbientRadius, which is the point: one number cannot serve both a lantern and a landmark.
--
-- ⚠ Returns its OWN shared table, built independently. It must never mutate `get()`'s.
function AmbientConfig.arena(): AmbientBudget.Config
    local c = cachedArena
    if c == nil then
        c = build(num("ArenaRadius", 450))
        cachedArena = c
    end
    return c :: AmbientBudget.Config
end

return AmbientConfig
