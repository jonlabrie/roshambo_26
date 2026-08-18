--!strict
-- Cuts a real channel per shoji screen into every teahouse prefab's front/back/left/right runs.
-- PASTE INTO THE STUDIO COMMAND BAR (Edit datamodel, via execute_luau).
--
-- Today every part of a bay -- paper, kumiko, stiles, rails, glow -- sits on ONE plane, and two
-- of the L's four front panels share that plane (survey, 2026-08-18): they would collide if
-- slid past each other. This gives each leaf its own groove, spaced ShojiRun.GROOVE_PITCH apart
-- and centred on the wall, so an entire run can stack in a single bay without clipping.
--
-- RAILS STAY PER BAY (fix, 2026-08-18). An earlier version of this tool merged each side's Rail
-- parts into one continuous sill, parented under bay 1's Shoji variant. That broke
-- StructureOps.applyBays, which shows/hides a WHOLE variant Model per bay: the moment bay 1 of a
-- wall is set to `solid` or `door` -- an ordinary loadout choice, and `solid` is the DEFAULT for
-- every side but the front -- the merged sill vanished along with bay 1's Shoji variant, while
-- bays 2..N still showed their screens. A threshold that disappears when one bay changes state
-- is worse than a seam. So each rail stays in its OWN bay's Shoji variant, keeping its name, its
-- run-axis position and length, and every cosmetic property; the only thing that changes is its
-- depth on the wall's normal axis, deepened and recentred to house that bay's own groove.
-- Abutting 6.20-wide rails on a 6.00 pitch already read continuous (they overlap by 0.20), which
-- is how the prefabs ship today, before any deepening.
--
-- IDEMPOTENT: every coordinate is a function of (side, bay index, run's bay count) and the ONE
-- part that never moves (the Solid variant's Panel) -- never of what the tool finds already in
-- place. Re-running prints the same table with every delta 0.00, and it is safe after a partial
-- run.
--
-- Place-only prefab edit (ServerStorage.StructurePrefabs is not in git) -- SAVE/PUBLISH THE
-- PLACE afterwards.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REQUIRE A CLONE, NOT THE MODULE. Studio's VM caches a ModuleScript's RESULT forever, and this
-- tool gets re-run repeatedly while the channel geometry is tuned -- a session that required
-- ShojiRun once keeps getting that stale result however current the source is (this bit
-- buildStatsBoards.luau twice on 2026-08-17: a half-applied change is worse than none, because
-- it looks like the edit simply did not work). A clone is a DIFFERENT instance, so require()
-- cannot serve it from cache and the source is evaluated fresh. Parent it alongside the original
-- first so any relative require inside it still resolves against its real siblings, then
-- destroy it.
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local ShojiRun
do
    local clone = shared:WaitForChild("ShojiRun"):Clone()
    clone.Name = "ShojiRun_trackShojiBays_tmp"
    clone.Parent = shared
    local ok, result = pcall(require, clone)
    clone:Destroy()
    if not ok then
        error("[trackShojiBays] ShojiRun failed to load: " .. tostring(result))
    end
    ShojiRun = result
end

-- Shape check on what the clone gave us -- not a cache guard any more, just a clear failure if
-- the module is mid-edit or broken, so a bad load errors loudly instead of half-applying.
if
    typeof(ShojiRun) ~= "table"
    or typeof(ShojiRun.grooveOffset) ~= "function"
    or typeof(ShojiRun.PITCH) ~= "number"
    or typeof(ShojiRun.GROOVE_PITCH) ~= "number"
then
    error("[trackShojiBays] ShojiRun is missing grooveOffset/PITCH/GROOVE_PITCH -- nothing was changed.")
end

local PREFABS = { "teahouse-1story-s", "teahouse-1story-m", "teahouse-1story-l" }
local SIDES = { "front", "back", "left", "right" }

-- How far a groove stack is let past the leaves' own stile depth (0.16), so each rail visibly
-- houses its bay's channels rather than merely touching them (spec section 2.1).
local SILL_MARGIN = 0.16

local WALL_PLANE_EPS = 0.01 -- studs; guard tolerance for "the wall's own plane is one number"
local MOVE_EPS = 1e-6 -- studs; below this a part is reported as unmoved (delta 0.00)

-- Which world axis is a side's wall NORMAL to, and which axis does its run of bays lie along.
-- Front/back walls face along Z, so their bays step along X; side walls face along X, so their
-- bays step along Z (task brief, "side walls run the other way").
local NORMAL_AXIS: { [string]: string } = { front = "Z", back = "Z", left = "X", right = "X" }
local RUN_AXIS: { [string]: string } = { front = "X", back = "X", left = "Z", right = "Z" }

local function axisOf(v: Vector3, axis: string): number
    if axis == "X" then
        return v.X
    elseif axis == "Y" then
        return v.Y
    end
    return v.Z
end

-- Replace one axis of a Vector3, keeping the other two exactly as they are.
local function withAxis(v: Vector3, axis: string, value: number): Vector3
    if axis == "X" then
        return Vector3.new(value, v.Y, v.Z)
    elseif axis == "Y" then
        return Vector3.new(v.X, value, v.Z)
    end
    return Vector3.new(v.X, v.Y, value)
end

-- Which of a Rail part's own LOCAL Size axes currently projects onto the wall's WORLD normal
-- direction. A Rail's authored depth (0.16) is always its own local Z -- the survey's numbers
-- read width x height x depth, i.e. local X x Y x Z -- but a side wall's bays are yawed 90
-- degrees from the front/back orientation, so that local Z axis lands on WORLD X there instead
-- of WORLD Z. Reading it off the part's actual CFrame, rather than assuming local Z always maps
-- to world Z, is what makes the resize correct on both orientations without guessing which.
local function depthAxisOf(part: BasePart, normalAxis: string): string
    local worldNormal = if normalAxis == "X" then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
    local rot = part.CFrame.Rotation
    local dotX = math.abs(rot.XVector:Dot(worldNormal))
    local dotY = math.abs(rot.YVector:Dot(worldNormal))
    local dotZ = math.abs(rot.ZVector:Dot(worldNormal))
    if dotX >= dotY and dotX >= dotZ then
        return "X"
    elseif dotZ >= dotY then
        return "Z"
    end
    return "Y"
end

type LeafMove = { part: BasePart, oldVal: number, newVal: number }
type BayRow = { prefab: string, side: string, index: number, oldVal: number, newVal: number }
type RailMove = { part: BasePart, index: number, y: number, depthAxis: string, oldDepth: number }
type SidePlan = {
    prefab: string,
    side: string,
    normalAxis: string,
    runAxis: string,
    count: number,
    wallPlane: number,
    sillDepth: number,
    leafMoves: { LeafMove },
    bayRows: { BayRow },
    railMoves: { RailMove },
}

-- ============================== PHASE 1: GATHER + VALIDATE ==============================
-- Read-only. Every prefab/side/bay is checked before anything is mutated, so a bad shape
-- anywhere errors out before a single part moves, rather than leaving a half-tracked house.

local prefabsFolder = ServerStorage:FindFirstChild("StructurePrefabs")
if not prefabsFolder then
    error("[trackShojiBays] ServerStorage.StructurePrefabs missing -- nothing was changed.")
end

local plans: { SidePlan } = {}

for _, prefabName in PREFABS do
    local prefab = prefabsFolder:FindFirstChild(prefabName)
    if not prefab then
        error(
            `[trackShojiBays] no prefab '{prefabName}' under ServerStorage.StructurePrefabs -- nothing was changed.`
        )
    end

    for _, side in SIDES do
        -- collect this side's Bay_<side>_<i> models, in index order
        local byIndex: { [number]: Model } = {}
        local maxIndex = 0
        for _, c in prefab:GetChildren() do
            if c:IsA("Model") then
                local s, idxStr = c.Name:match("^Bay_(%a+)_(%d+)$")
                if s == side then
                    local idx = tonumber(idxStr) :: number
                    byIndex[idx] = c
                    maxIndex = math.max(maxIndex, idx)
                end
            end
        end
        local count = 0
        for _ in byIndex do
            count += 1
        end
        if count == 0 then
            continue -- this prefab has no bays on this side (S has no left/right)
        end
        if count ~= maxIndex then
            error(
                `[trackShojiBays] {prefabName} {side}: bay indices are not a contiguous 1..{count} run (highest seen {maxIndex}) -- nothing was changed.`
            )
        end

        local normalAxis, runAxis = NORMAL_AXIS[side], RUN_AXIS[side]

        local panels: { [number]: BasePart } = {}
        local shojiModels: { [number]: Model } = {}
        for i = 1, count do
            local bay = byIndex[i]
            if not bay then
                error(`[trackShojiBays] {prefabName} {side}: bay {i} missing -- nothing was changed.`)
            end
            local solid = bay:FindFirstChild("Solid")
            local panel = solid and solid:FindFirstChildWhichIsA("BasePart", true)
            if not panel then
                error(
                    `[trackShojiBays] {prefabName} Bay_{side}_{i}: no Solid variant / part found -- nothing was changed.`
                )
            end
            local shoji = bay:FindFirstChild("Shoji")
            if not (shoji and shoji:IsA("Model")) then
                error(
                    `[trackShojiBays] {prefabName} Bay_{side}_{i}: no Shoji variant -- nothing was changed.`
                )
            end
            panels[i] = panel :: BasePart
            shojiModels[i] = shoji :: Model
        end

        -- wallPlane: every bay's Solid panel must agree on the normal axis -- it is the one
        -- part that never moves, so it is the reference for where the wall actually is.
        local wallPlane = axisOf(panels[1].Position, normalAxis)
        for i = 2, count do
            local v = axisOf(panels[i].Position, normalAxis)
            if math.abs(v - wallPlane) > WALL_PLANE_EPS then
                error(
                    `[trackShojiBays] {prefabName} {side}: bay {i}'s Solid panel sits at {normalAxis}={v} but bay 1 sits at {wallPlane} -- the wall is not one plane. Nothing was changed.`
                )
            end
        end

        local sillDepth = count * ShojiRun.GROOVE_PITCH + SILL_MARGIN

        -- leaf parts: everything in a bay's Shoji variant except its Rail members. Rails are
        -- read here too, but only to plan a depth resize + recentre IN PLACE -- see the header.
        local leafMoves: { LeafMove } = {}
        local bayRows: { BayRow } = {}
        local railMoves: { RailMove } = {}

        for i = 1, count do
            local shoji = shojiModels[i]
            local target = wallPlane + ShojiRun.grooveOffset(i, count)
            local paperOld: number? = nil

            for _, p in shoji:GetDescendants() do
                if p:IsA("BasePart") then
                    if p.Name == "Rail" then
                        local depthAxis = depthAxisOf(p, normalAxis)
                        table.insert(railMoves, {
                            part = p,
                            index = i,
                            y = p.Position.Y,
                            depthAxis = depthAxis,
                            oldDepth = axisOf(p.Size, depthAxis),
                        })
                    else
                        local old = axisOf(p.Position, normalAxis)
                        table.insert(leafMoves, { part = p, oldVal = old, newVal = target })
                        if p.Name == "Shoji" then
                            paperOld = old
                        end
                    end
                end
            end

            if paperOld == nil then
                error(
                    `[trackShojiBays] {prefabName} Bay_{side}_{i}: Shoji variant has no paper part named 'Shoji' -- nothing was changed.`
                )
            end
            table.insert(
                bayRows,
                { prefab = prefabName, side = side, index = i, oldVal = paperOld, newVal = target }
            )
        end

        if #railMoves == 0 then
            error(`[trackShojiBays] {prefabName} {side}: no Rail parts found -- nothing was changed.`)
        end

        table.insert(plans, {
            prefab = prefabName,
            side = side,
            normalAxis = normalAxis,
            runAxis = runAxis,
            count = count,
            wallPlane = wallPlane,
            sillDepth = sillDepth,
            leafMoves = leafMoves,
            bayRows = bayRows,
            railMoves = railMoves,
        })
    end
end

if #plans == 0 then
    error("[trackShojiBays] found no Bay_<side>_<index> models in any prefab -- nothing was changed.")
end

-- ============================== PHASE 2: MUTATE ==============================
-- Every plan above was fully validated read-only. Nothing here can discover a bad shape, so it
-- is safe to apply all of them.

local movedLeaves = 0
local movedLeavesNonzero = 0
local resizedRails = 0
local resizedRailsNonzero = 0
local report: { string } = {}

for _, plan in plans do
    for _, row in plan.bayRows do
        local delta = row.newVal - row.oldVal
        table.insert(
            report,
            string.format(
                "%-22s %-6s bay %-2d  leaf old %7.2f  new %7.2f  delta %6.2f",
                row.prefab,
                row.side,
                row.index,
                row.oldVal,
                row.newVal,
                delta
            )
        )
    end

    for _, move in plan.leafMoves do
        local part = move.part
        local pos = withAxis(part.Position, plan.normalAxis, move.newVal)
        part.CFrame = CFrame.new(pos) * part.CFrame.Rotation
        movedLeaves += 1
        if math.abs(move.newVal - move.oldVal) > MOVE_EPS then
            movedLeavesNonzero += 1
        end
    end

    for _, rm in plan.railMoves do
        local part = rm.part
        -- resize the rail's own depth axis (local, from depthAxisOf), then recentre it on the
        -- wall plane (world, via normalAxis) -- resizing a BasePart keeps its centre fixed, so
        -- these two writes do not fight each other.
        part.Size = withAxis(part.Size, rm.depthAxis, plan.sillDepth)
        local pos = withAxis(part.Position, plan.normalAxis, plan.wallPlane)
        part.CFrame = CFrame.new(pos) * part.CFrame.Rotation
        resizedRails += 1
        local delta = plan.sillDepth - rm.oldDepth
        if math.abs(delta) > MOVE_EPS then
            resizedRailsNonzero += 1
        end
        table.insert(
            report,
            string.format(
                "%-22s %-6s bay %-2d  rail y=%-6.2f  old depth %5.2f  new depth %5.2f  delta %6.2f",
                plan.prefab,
                plan.side,
                rm.index,
                rm.y,
                rm.oldDepth,
                plan.sillDepth,
                delta
            )
        )
    end
end

print("[trackShojiBays] channel + rail report:")
for _, line in report do
    print("  " .. line)
end
print(
    string.format(
        "[trackShojiBays] moved %d leaves (%d with a nonzero delta), resized %d rails (%d with a nonzero delta) across %d side-runs",
        movedLeaves,
        movedLeavesNonzero,
        resizedRails,
        resizedRailsNonzero,
        #plans
    )
)
print("[trackShojiBays] SAVE/PUBLISH THE PLACE -- StructurePrefabs is place-only and rojo build drops it.")
