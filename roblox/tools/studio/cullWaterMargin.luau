-- MCP/Edit: apply the care gradient to the water-margin flora (spec sub-project 2,
-- phase 1). PARKS instances to ServerStorage -- never deletes -- so every cut is
-- recoverable and the decision stays reversible.
--
-- THE MARGIN'S PROBLEM IS MONOCULTURE, AND SUBTRACTION IS MOST OF THE FIX. The
-- waterline band is 874 parts of just three species (reeds 285, tall weeds 311, weed
-- stalks 278) spread evenly over the whole canyon, x -436..+217. Evenly is the defect:
-- the same weed mass reads as wild where nobody tends and as neglect where the resort
-- does. So weeds come out in GARDEN, thin in TENDED, and stay untouched in PRESERVE.
--
-- CARE LEVEL is measured from REAL PATH GEOMETRY (every path model's Step_/Riser_
-- parts), which only became possible once the river path existed:
--   reach(x) = clamp(8 + 20*(x+430)/470, 8, 28)      -- studs, wide east, narrow west
--   GARDEN  = within 35% of reach     TENDED = within reach     else PRESERVE
-- Staged sites override longitude -- the falls dock carries its own 15-stud garden
-- radius, making it a tended island in wild country.
--
-- ⚠️ TENDED IS THINNED BY SPACING, NOT AT RANDOM. Removing a random half leaves random
-- clumps and gaps, which reads as damage. Tending a margin means pulling the CROWDED
-- ones, so this repeatedly removes whichever instance has the most neighbours inside
-- `thinSpacing` until none is crowded -- dense mats open up, isolated plants are left
-- alone. Deterministic: ties break on a position hash, so a re-run parks the same set.
--
-- large_fern is cut at EVERY level: spec section 4 recorded all 69 as cut entirely and
-- parked, and that decision was never executed -- 66 were still standing 2026-07-30.
--
-- Set CONFIG.dryRun = false to apply. Restore by moving the parked folder's children
-- back under CanyonWorld.Foliage.WaterFoliage.<band>.

local CONFIG = {
    weeds = { reedy_mid_14 = true, tall_weeds_04 = true, weed_stalks_09 = true },
    -- cut at every care level, not just in the garden
    cullAlways = { large_fern_01 = true, large_fern_02 = true },
    reachMin = 8,
    reachMax = 28,
    gardenFrac = 0.35,
    -- TENDED weeds crowded closer than this get pulled. 3.0 is MEASURED, not guessed:
    -- these weeds sit in tight clumps (native nearest-neighbour median 1.9 studs, 10th
    -- percentile 1.1), so the removal curve is steep -- 2.0 takes 28%, 3.0 takes 49%,
    -- 3.5 takes 56%, and my first guess of 7.0 took 78%, which is not thinning but
    -- near-clearing and would have flattened the very gradient this pass exists for.
    thinSpacing = 3.0,
    stagedSites = {
        { name = "FallsDock", x = -345.4, z = -15.4, garden = 15 },
        { name = "Karesansui", x = 6.5, z = 3.0, garden = 30 },
        { name = "Overlook", x = 72.8, z = 18.8, garden = 22 },
    },
    parkName = "MarginCull_2026_07_30",
    dryRun = true,
}

local SS = game:GetService("ServerStorage")
local CELL = 16

--------------------------------------------------------------------------------
-- index every path centreline anchor into a spatial hash
--------------------------------------------------------------------------------
local grid = {}
local anchors = 0
for _, m in ipairs(workspace.CanyonWorld.Paths:GetChildren()) do
    if m:IsA("Model") then
        for _, c in ipairs(m:GetChildren()) do
            if c:IsA("BasePart") and (c.Name:match("^Step_") or c.Name:match("^Riser_")) then
                local k = math.floor(c.Position.X / CELL) .. "," .. math.floor(c.Position.Z / CELL)
                local b = grid[k]
                if not b then
                    b = {}
                    grid[k] = b
                end
                table.insert(b, c.Position)
                anchors += 1
            end
        end
    end
end

local function nearestPath(x, z)
    local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
    local best = 1e9
    for dx = -2, 2 do
        for dz = -2, 2 do
            local b = grid[(cx + dx) .. "," .. (cz + dz)]
            if b then
                for _, p in ipairs(b) do
                    local d = (p.X - x) ^ 2 + (p.Z - z) ^ 2
                    if d < best then
                        best = d
                    end
                end
            end
        end
    end
    return math.sqrt(best)
end

local function careLevel(x, z)
    for _, s in ipairs(CONFIG.stagedSites) do
        if math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) <= s.garden then
            return "GARDEN"
        end
    end
    local reach = math.clamp(CONFIG.reachMin + 20 * (x + 430) / 470, CONFIG.reachMin, CONFIG.reachMax)
    local d = nearestPath(x, z)
    if d <= reach * CONFIG.gardenFrac then
        return "GARDEN"
    elseif d <= reach then
        return "TENDED"
    end
    return "PRESERVE"
end

--------------------------------------------------------------------------------
-- classify
--------------------------------------------------------------------------------
local function speciesOf(name)
    return (name:gsub("_%d+$", ""):gsub("_good$", ""))
end

local wf = workspace.CanyonWorld.Foliage:FindFirstChild("WaterFoliage")
if not wf then
    return "no CanyonWorld.Foliage.WaterFoliage"
end

local toPark = {} -- { inst, band, why }
local tendedWeeds = {} -- candidates for spacing-based thinning
local kept = { GARDEN = 0, TENDED = 0, PRESERVE = 0 }

for _, band in ipairs(wf:GetChildren()) do
    for _, c in ipairs(band:GetChildren()) do
        local p = c:IsA("Model") and c:GetPivot().Position or (c:IsA("BasePart") and c.Position)
        if p then
            local sp = speciesOf(c.Name)
            local level = careLevel(p.X, p.Z)
            if CONFIG.cullAlways[sp] then
                table.insert(
                    toPark,
                    { inst = c, band = band.Name, why = "large_fern cull (" .. level .. ")" }
                )
            elseif CONFIG.weeds[sp] and level == "GARDEN" then
                table.insert(toPark, { inst = c, band = band.Name, why = "weed in GARDEN" })
            elseif CONFIG.weeds[sp] and level == "TENDED" then
                table.insert(tendedWeeds, { inst = c, band = band.Name, x = p.X, z = p.Z })
            else
                kept[level] += 1
            end
        end
    end
end

--------------------------------------------------------------------------------
-- thin TENDED weeds by crowding, deterministically
--------------------------------------------------------------------------------
local S2 = CONFIG.thinSpacing ^ 2
local alive = {}
for i, e in ipairs(tendedWeeds) do
    alive[i] = e
    -- integer position hash: a stable tiebreak, no transcendentals (arch-portable)
    e.tie = (math.floor(e.x * 100) * 73856093 + math.floor(e.z * 100) * 19349663) % 1000003
end

local function neighbourCount(i)
    local e = alive[i]
    if not e then
        return -1
    end
    local n = 0
    for j, f in pairs(alive) do
        if j ~= i then
            if (f.x - e.x) ^ 2 + (f.z - e.z) ^ 2 < S2 then
                n += 1
            end
        end
    end
    return n
end

local thinned = 0
while true do
    local worstI, worstN, worstTie = nil, 0, -1
    for i in pairs(alive) do
        local n = neighbourCount(i)
        if n > worstN or (n == worstN and n > 0 and alive[i].tie > worstTie) then
            worstI, worstN, worstTie = i, n, alive[i].tie
        end
    end
    if not worstI or worstN == 0 then
        break
    end
    local e = alive[worstI]
    table.insert(toPark, { inst = e.inst, band = e.band, why = "TENDED weed thinned (crowded)" })
    alive[worstI] = nil
    thinned += 1
end
local tendedKept = 0
for _ in pairs(alive) do
    tendedKept += 1
end

--------------------------------------------------------------------------------
-- report / apply
--------------------------------------------------------------------------------
local byWhy = {}
for _, e in ipairs(toPark) do
    byWhy[e.why] = (byWhy[e.why] or 0) + 1
end
local lines = { ("path anchors indexed: %d"):format(anchors), "" }
local whys = {}
for k in pairs(byWhy) do
    table.insert(whys, k)
end
table.sort(whys)
for _, k in ipairs(whys) do
    table.insert(lines, ("  %-34s %4d"):format(k, byWhy[k]))
end
table.insert(
    lines,
    ("\nTENDED weeds: %d thinned, %d kept (spacing %.1f)"):format(thinned, tendedKept, CONFIG.thinSpacing)
)
table.insert(
    lines,
    ("kept elsewhere: GARDEN %d, TENDED %d, PRESERVE %d"):format(kept.GARDEN, kept.TENDED, kept.PRESERVE)
)
table.insert(lines, ("\nTOTAL TO PARK: %d"):format(#toPark))

if CONFIG.dryRun then
    table.insert(lines, "dryRun -- nothing moved. Set dryRun = false to apply.")
    return table.concat(lines, "\n")
end

local parkRoot = SS:FindFirstChild("ParkedFoliage")
if not parkRoot then
    parkRoot = Instance.new("Folder")
    parkRoot.Name = "ParkedFoliage"
    parkRoot.Parent = SS
end
local park = parkRoot:FindFirstChild(CONFIG.parkName)
if park then
    return ("%s already exists in ServerStorage.ParkedFoliage -- cull already applied"):format(
        CONFIG.parkName
    )
end
park = Instance.new("Folder")
park.Name = CONFIG.parkName
park.Parent = parkRoot

local bandFolders = {}
for _, e in ipairs(toPark) do
    local bf = bandFolders[e.band]
    if not bf then
        bf = Instance.new("Folder")
        bf.Name = e.band
        bf.Parent = park
        bandFolders[e.band] = bf
    end
    e.inst.Parent = bf
end

table.insert(lines, ("\nPARKED to ServerStorage.ParkedFoliage.%s"):format(CONFIG.parkName))
return table.concat(lines, "\n")
