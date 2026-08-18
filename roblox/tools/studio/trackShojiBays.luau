--!strict
-- Cuts a real channel per shoji screen into every teahouse prefab's front/back/left/right runs,
-- and consolidates each side's per-bay Rail parts into one continuous sill. PASTE INTO THE
-- STUDIO COMMAND BAR (Edit datamodel, via execute_luau).
--
-- Today every part of a bay -- paper, kumiko, stiles, rails, glow -- sits on ONE plane, and two
-- of the L's four front panels share that plane (survey, 2026-08-18): they would collide if
-- slid past each other. This gives each leaf its own groove, spaced ShojiRun.GROOVE_PITCH apart
-- and centred on the wall, so an entire run can stack in a single bay without clipping.
--
-- IDEMPOTENT: every coordinate is a function of (side, bay index, run's bay count) and the ONE
-- part that never moves (the Solid variant's Panel) -- never of what the tool finds already in
-- place. Re-running prints the same table with every delta 0.00, and it is safe after a partial
-- run: a side whose rails are already consolidated into one sill re-derives the identical sill
-- from the same inputs and replaces it with itself.
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

-- Survey constants (measured 2026-08-18; stated without a prefab qualifier, so they are taken
-- as universal across S/M/L -- only bay COUNT differs per prefab/side).
--
-- A single-bay Rail is 6.20 studs along its run for a 6.00 pitch -- 0.10 of overhang past its
-- own bay's half-pitch on each side. A run's consolidated sill keeps that SAME end overhang
-- rather than stopping flush at the outer bays' centres, so the sill's outer edges land exactly
-- where the outermost original rail's edges already did.
local RAIL_RUN_SIZE = 6.20
-- How far a groove stack is let into the sill beyond the leaves' own stile depth (0.16), so the
-- sill visibly houses the channels rather than merely touching them (spec section 2.1).
local SILL_MARGIN = 0.16

local WALL_PLANE_EPS = 0.01 -- studs; guard tolerance for "the wall's own plane is one number"
local MOVE_EPS = 1e-6 -- studs; below this a leaf is reported as unmoved (delta 0.00)

-- Which world axis is a side's wall NORMAL to, and which axis does its run of bays lie along.
-- Front/back walls face along Z, so their bays step along X; side walls face along X, so their
-- bays step along Z (task brief, "side walls run the other way").
local NORMAL_AXIS: { [string]: string } = { front = "Z", back = "Z", left = "X", right = "X" }
local RUN_AXIS: { [string]: string } = { front = "X", back = "X", left = "Z", right = "Z" }

local function axisOf(v: Vector3, axis: string): number
    return if axis == "X" then v.X else v.Z
end

-- Replace one axis of a Vector3, keeping the other two exactly as they are.
local function withAxis(v: Vector3, axis: string, value: number): Vector3
    return if axis == "X" then Vector3.new(value, v.Y, v.Z) else Vector3.new(v.X, v.Y, value)
end

-- Build a Vector3 from a (normal, run, y) triple without caring which world axis is which.
local function vecFor(normalAxis: string, normalVal: number, runVal: number, yVal: number): Vector3
    if normalAxis == "X" then
        return Vector3.new(normalVal, yVal, runVal)
    end
    return Vector3.new(runVal, yVal, normalVal)
end

type LeafMove = { part: BasePart, oldVal: number, newVal: number }
type BayRow = { prefab: string, side: string, index: number, oldVal: number, newVal: number }
type RailRef = {
    y: number,
    sizeY: number,
    color: Color3,
    material: Enum.Material,
    canCollide: boolean,
    castShadow: boolean,
    shownTransparency: number?,
}
type SidePlan = {
    prefab: string,
    side: string,
    normalAxis: string,
    runAxis: string,
    count: number,
    wallPlane: number,
    runCentre: number,
    sillDepth: number,
    sillRun: number,
    firstShoji: Model,
    leafMoves: { LeafMove },
    bayRows: { BayRow },
    railsToDestroy: { BasePart },
    sills: { RailRef },
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

        -- each bay's own position along the run, straight off its (untouched) Solid panel
        local bayRun: { [number]: number } = {}
        for i = 1, count do
            bayRun[i] = axisOf(panels[i].Position, runAxis)
        end

        -- leaf parts: everything in a bay's Shoji variant except its Rail members
        local leafMoves: { LeafMove } = {}
        local bayRows: { BayRow } = {}
        local railsToDestroy: { BasePart } = {}
        local railRefs: { RailRef } = {}

        for i = 1, count do
            local shoji = shojiModels[i]
            local target = wallPlane + ShojiRun.grooveOffset(i, count)
            local paperOld: number? = nil

            for _, p in shoji:GetDescendants() do
                if p:IsA("BasePart") then
                    if p.Name == "Rail" then
                        local st = p:GetAttribute("ShownTransparency")
                        table.insert(railsToDestroy, p)
                        table.insert(railRefs, {
                            y = p.Position.Y,
                            sizeY = p.Size.Y,
                            color = p.Color,
                            material = p.Material,
                            canCollide = p.CanCollide,
                            castShadow = p.CastShadow,
                            shownTransparency = if typeof(st) == "number" then st else nil,
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

        if #railRefs == 0 then
            error(
                `[trackShojiBays] {prefabName} {side}: no Rail parts found to consolidate -- nothing was changed.`
            )
        end

        -- group the found rails by height (Y); one sill per distinct height, ascending
        local byHeightKey: { [number]: RailRef } = {}
        local heightKeys: { number } = {}
        for _, ref in railRefs do
            local key = math.floor(ref.y * 1000 + 0.5) -- dedupe within a thousandth of a stud
            if not byHeightKey[key] then
                byHeightKey[key] = ref
                table.insert(heightKeys, key)
            end
        end
        table.sort(heightKeys)
        local sills: { RailRef } = {}
        for _, key in heightKeys do
            table.insert(sills, byHeightKey[key])
        end

        table.insert(plans, {
            prefab = prefabName,
            side = side,
            normalAxis = normalAxis,
            runAxis = runAxis,
            count = count,
            wallPlane = wallPlane,
            runCentre = (bayRun[1] + bayRun[count]) / 2,
            sillDepth = count * ShojiRun.GROOVE_PITCH + SILL_MARGIN,
            sillRun = (count - 1) * ShojiRun.PITCH + RAIL_RUN_SIZE,
            firstShoji = shojiModels[1],
            leafMoves = leafMoves,
            bayRows = bayRows,
            railsToDestroy = railsToDestroy,
            sills = sills,
        })
    end
end

if #plans == 0 then
    error("[trackShojiBays] found no Bay_<side>_<index> models in any prefab -- nothing was changed.")
end

-- ============================== PHASE 2: MUTATE ==============================
-- Every plan above was fully validated read-only. Nothing here can discover a bad shape, so it
-- is safe to apply all of them.

local movedParts = 0
local movedNonzero = 0
local sillsCreated = 0
local report: { string } = {}

for _, plan in plans do
    for _, row in plan.bayRows do
        local delta = row.newVal - row.oldVal
        table.insert(
            report,
            string.format(
                "%-22s %-6s bay %-2d  old %7.2f  new %7.2f  delta %6.2f",
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
        movedParts += 1
        if math.abs(move.newVal - move.oldVal) > MOVE_EPS then
            movedNonzero += 1
        end
    end

    for _, rail in plan.railsToDestroy do
        rail:Destroy()
    end

    for _, sillRef in plan.sills do
        local size = vecFor(plan.normalAxis, plan.sillDepth, plan.sillRun, sillRef.sizeY)
        local pos = vecFor(plan.normalAxis, plan.wallPlane, plan.runCentre, sillRef.y)

        local sill = Instance.new("Part")
        sill.Name = "Rail"
        sill.Anchored = true
        sill.CanCollide = sillRef.canCollide
        sill.CastShadow = sillRef.castShadow
        sill.Material = sillRef.material
        sill.Color = sillRef.color
        sill.Size = size
        sill.CFrame = CFrame.new(pos)
        if sillRef.shownTransparency ~= nil then
            sill:SetAttribute("ShownTransparency", sillRef.shownTransparency)
        end
        sill.Parent = plan.firstShoji
        sillsCreated += 1

        table.insert(
            report,
            string.format(
                "%-22s %-6s sill  y=%-6.2f  size=(%.2f, %.2f, %.2f)  pos=(%.2f, %.2f, %.2f)",
                plan.prefab,
                plan.side,
                sillRef.y,
                size.X,
                size.Y,
                size.Z,
                pos.X,
                pos.Y,
                pos.Z
            )
        )
    end
end

print("[trackShojiBays] channel + sill report:")
for _, line in report do
    print("  " .. line)
end
print(
    string.format(
        "[trackShojiBays] moved %d leaf parts (%d with a nonzero delta) across %d side-runs; created %d sills",
        movedParts,
        movedNonzero,
        #plans,
        sillsCreated
    )
)
print("[trackShojiBays] SAVE/PUBLISH THE PLACE -- StructurePrefabs is place-only and rojo build drops it.")
