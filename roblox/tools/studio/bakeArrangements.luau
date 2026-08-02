--!strict
-- bakeArrangements.luau — the canyon-wide arrangements sweep (foliage finish T15).
-- Run via MCP execute_luau (Edit datamodel). Writes ONLY to
-- CanyonWorld.Foliage.ArrangementsDraft, which it rebuilds from scratch each run.
--
-- foliageArrangements.luau holds the site GRAMMAR and the tuned arrangements; this holds
-- the SITES — where in this particular canyon each one belongs. Sites are derived from
-- the world, never hand-listed, so the sweep can be re-run after the terrain moves.
--
-- FIVE SITE SOURCES
--   tunnelMouth  pad-slot bores. Tunnels are carved VOIDS — there is no Instance to find,
--                and searching the object graph for "tunnel" finds nothing (it did, and I
--                reported to the user that the canyon had none; it has dozens). Read
--                VOXELS: a bore voxel is air, with rock overhead, and footing below; a
--                MOUTH is a bore voxel orthogonally adjacent to a column open to the sky.
--   bridgeEnd    abutments of SuspensionBridge + RiverCrossing. Bridge3 is inside the
--                Arena square and is excluded by the keep-out, correctly.
--   waterEdge    the shore-rock waterlines from the T14a pass, clustered into pools.
--   pathEdge     the foot and head of every path model that climbs 20+ studs.
--   promontory   BenchLanding and JunctionLanding, capped at two: ShrineTrio leads with a
--                68k hero and a third would not pay for itself.
--
-- TWO BUGS THIS FILE EXISTS TO NOT REPEAT
--   1. Offsetting a stair anchor perpendicular to the RADIAL direction from the world
--      origin is meaningless — it put 12 of 43 anchors on the walking surface. Offset
--      across the LOCAL TANGENT, found from the nearest marker 6-20 studs away.
--   2. A voxel sweep clipped to z -124..112 misses pad slots T13 (z -161) and T01
--      (z +140) entirely. Bound the sweep by the PADS, not by a guess.
-- And one tuning note: the first pass gated anchors 13 studs off any existing plant and
-- placed 3 of 43. The canyon already holds 1,787 plants; an arrangement belongs IN the
-- planting, not in a clearing it has to carve. 10 studs, with a wider second-chance pass
-- at 8 for named landmarks (bridge abutments, big pools), places 40.

local ServerStorage = game:GetService("ServerStorage")

local DRY_RUN = false -- true reports the site table and places nothing

local ARENA = { x0 = -32, x1 = 100, z0 = -36, z1 = 52 }
local RES = 4
local PATH_GATE = 7
local RING_DROP = 8
local TREE_GATE, TREE_GATE_LANDMARK = 10, 8
local RADII = { 10, 14, 18, 23, 28 }
local RADII_LANDMARK = { 34, 40, 46, 52 }

export type Tree = { species: string, dx: number, dz: number, scale: number, yawDeg: number? }

local function t(species: string, dx: number, dz: number, scale: number, yawDeg: number?): Tree
    return { species = species, dx = dx, dz = dz, scale = scale, yawDeg = yawDeg }
end

-- mirrors foliageArrangements.luau; the sentinels are split into five one-tree variants so
-- that eleven pad mouths do not read as eleven copies of the same gold katsura
local ARRANGEMENTS: { [string]: { Tree } } = {
    KatsuraGate = {
        t("XfHinokiMT", -5, 0, 0.9),
        t("XfKatsuraM", 3, 7, 1.0, 215),
        t("XfHinokiYb", -7, 4, 1.0),
    },
    MapleMirror = { t("XfMapleA", 0, 0, 1.0), t("XfMapleM", -8, 5, 0.85), t("FernClump", 4, -3, 1.0) },
    KanzanPair = { t("XfKanzanA", 0, 0, 1.0), t("XfSpruceYr", 8, 3, 1.0), t("XfKanzanM", 14, -2, 0.9) },
    SugiSentinels = { t("SugiMidC", 0, 0, 1.0), t("SugiMidA", 11, 2, 0.85) },
    BambooScreen = { t("RealisticBamboo", 0, 0, 1.0), t("RealisticBamboo", 9, 3, 0.85) },
    YoungWood = {
        t("XfHinokiYr", 0, 0, 1.0),
        t("XfSpruceYr", 7, 3, 0.9),
        t("XfFirYr", -6, 5, 1.0),
        t("XfHinokiYb", 3, 8, 1.0),
        t("XfSpruceYb", -3, -4, 1.0),
    },
    HanamiStand = { t("XfCherryA", 0, 0, 1.0), t("PineNiwakiD", -9, 5, 0.8), t("XfCherryM", 8, 6, 0.85) },
    ShrineTrio = { t("SugiHero_SugiSmart", 0, 0, 1.0), t("SugiMidB", 9, 5, 0.85), t("SugiMidA", -8, 4, 0.8) },
    SentinelGold = { t("XfKatsuraM", 0, 0, 1.0) },
    SentinelPine = { t("PineNiwakiA", 0, 0, 0.9) },
    SentinelMaple = { t("XfMapleM", 0, 0, 0.95) },
    SentinelCherry = { t("XfCherryM", 0, 0, 0.9) },
    SentinelHinoki = { t("XfHinokiMT", 0, 0, 0.9) },
}
local SENTINELS = { "SentinelGold", "SentinelPine", "SentinelMaple", "SentinelCherry", "SentinelHinoki" }
local GATES = { "KatsuraGate", "BambooScreen", "YoungWood", "HanamiStand" }

local terrain = workspace.Terrain
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { terrain }

local function ground(x: number, z: number): (number?, boolean)
    local hit = workspace:Raycast(Vector3.new(x, 420, z), Vector3.new(0, -520, 0), rayParams)
    if not hit then
        return nil, false
    end
    return hit.Position.Y, hit.Material == Enum.Material.Water
end

local function nearest(pt: Vector3, list: { Vector3 }): number
    local best = math.huge
    for _, q in list do
        local d = (q - pt).Magnitude
        if d < best then
            best = d
        end
    end
    return best
end

local function collect(): ({ Vector3 }, { [string]: { Vector3 } }, { Vector3 })
    local pathPts, byModel = {}, {}
    for _, m in workspace.CanyonWorld.Paths:GetChildren() do
        byModel[m.Name] = {}
        for _, d in m:GetDescendants() do
            -- Magnitude > 40 drops parts stranded at the world origin; they poison every
            -- endpoint and proximity test that reads this set
            if d:IsA("BasePart") and d.Position.Magnitude > 40 then
                table.insert(pathPts, d.Position)
                table.insert(byModel[m.Name], d.Position)
            end
        end
    end
    local plants = {}
    for _, root in { workspace.CanyonWorld.Foliage.Heroes, workspace.CanyonWorld.Foliage.Preserve } do
        for _, m in root:GetDescendants() do
            if m:IsA("Model") and m:FindFirstChildWhichIsA("BasePart") then
                table.insert(plants, m:GetPivot().Position)
            end
        end
    end
    return pathPts, byModel, plants
end

local pathPts, pathByModel, plants = collect()

local function judge(x: number, z: number, treeGate: number): number?
    if x >= ARENA.x0 and x <= ARENA.x1 and z >= ARENA.z0 and z <= ARENA.z1 then
        return nil
    end
    local y, water = ground(x, z)
    if not y or water then
        return nil
    end
    local at = Vector3.new(x, y, z)
    if nearest(at, pathPts) < PATH_GATE or nearest(at, plants) < treeGate then
        return nil
    end
    -- footing ring: a centre probe alone accepts perches whose ground falls away
    local lo, hi = math.huge, -math.huge
    for a = 0, 3 do
        local th = a * math.pi / 2
        local gy = ground(x + math.cos(th) * 5, z + math.sin(th) * 5)
        if not gy then
            return nil
        end
        lo, hi = math.min(lo, gy), math.max(hi, gy)
    end
    if hi - lo > RING_DROP then
        return nil
    end
    return y
end

local function findAnchor(seedPos: Vector3, prefer: Vector3?, radii: { number }, gate: number): Vector3?
    local dirs: { Vector3 } = {}
    if prefer then
        table.insert(dirs, prefer)
    end
    for a = 0, 11 do
        local th = a * math.pi / 6
        table.insert(dirs, Vector3.new(math.cos(th), 0, math.sin(th)))
    end
    for _, r in radii do
        for _, d in dirs do
            local x, z = seedPos.X + d.X * r, seedPos.Z + d.Z * r
            local y = judge(x, z, gate)
            if y then
                return Vector3.new(x, y, z)
            end
        end
    end
    return nil
end

type Seed = { name: string, arrangement: string, pos: Vector3, dir: Vector3?, note: string }
local seeds: { Seed } = {}
local function addSeed(name: string, arrangement: string, pos: Vector3, dir: Vector3?, note: string)
    table.insert(seeds, { name = name, arrangement = arrangement, pos = pos, dir = dir, note = note })
end

-- the pad slots name themselves through the bamboo screens planted against their walls
local function padSlots(): { [string]: Vector3 }
    local slots = {}
    for _, m in workspace.CanyonWorld.Foliage.Heroes.PadBamboo:GetChildren() do
        local tag = m.Name:match("^(T%d%d)")
        if tag then
            local q = m:GetPivot().Position
            slots[tag] = slots[tag] and slots[tag]:Lerp(q, 0.5) or q
        end
    end
    return slots
end

-- nearest mouth of a carved bore to a point, by voxel occupancy
local function mouthNear(centre: Vector3, reach: number): (Vector3?, Vector3?, number)
    local region = Region3.new(centre - Vector3.new(60, 34, 60), centre + Vector3.new(60, 34, 60))
        :ExpandToGrid(RES)
    local ok, _mats, occ = pcall(function()
        return terrain:ReadVoxels(region, RES)
    end)
    if not ok then
        return nil, nil, math.huge
    end
    local sx, sy, sz = #occ, #occ[1], #occ[1][1]
    local base = region.CFrame.Position - region.Size / 2
    local function solid(ix: number, iy: number, iz: number): boolean
        if ix < 1 or ix > sx or iy < 1 or iy > sy or iz < 1 or iz > sz then
            return true
        end
        return occ[ix][iy][iz] > 0.5
    end
    local sky = {}
    for ix = 1, sx do
        sky[ix] = {}
        for iz = 1, sz do
            sky[ix][iz] = {}
            local open = true
            for iy = sy, 1, -1 do
                if occ[ix][iy][iz] > 0.5 then
                    open = false
                end
                sky[ix][iz][iy] = open
            end
        end
    end
    local bestPos, bestOut, bestD = nil, nil, math.huge
    for ix = 1, sx do
        for iz = 1, sz do
            for iy = 2, sy - 1 do
                if not solid(ix, iy, iz) and not sky[ix][iz][iy] and solid(ix, iy - 1, iz) then
                    for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
                        local jx, jz = ix + d[1], iz + d[2]
                        if
                            jx >= 1
                            and jx <= sx
                            and jz >= 1
                            and jz <= sz
                            and not solid(jx, iy, jz)
                            and sky[jx][jz][iy]
                        then
                            local q = Vector3.new(
                                base.X + (ix - 0.5) * RES,
                                base.Y + (iy - 0.5) * RES,
                                base.Z + (iz - 0.5) * RES
                            )
                            local dd = (q - centre).Magnitude
                            if dd < bestD then
                                bestD, bestPos, bestOut = dd, q, Vector3.new(d[1], 0, d[2])
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    if bestPos and bestD <= reach then
        return bestPos, bestOut, bestD
    end
    return nil, nil, bestD
end

local slots = padSlots()
local tags = {}
for tag in slots do
    table.insert(tags, tag)
end
table.sort(tags)
local sentinelIndex = 0
for _, tag in tags do
    local pos, outward = mouthNear(slots[tag], 45)
    if pos then
        sentinelIndex += 1
        addSeed(
            `Tunnel_{tag}`,
            SENTINELS[(sentinelIndex - 1) % #SENTINELS + 1],
            pos,
            outward,
            `pad mouth {tag}`
        )
    end
end

for _, b in workspace.CanyonWorld.Structures.Bridges:GetChildren() do
    if b.Name == "SuspensionBridge" or b.Name == "RiverCrossing" then
        local cf, size = b:GetBoundingBox()
        local alongZ = size.Z > size.X
        local axis = alongZ and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
        local half = (alongZ and size.Z or size.X) / 2 + 6
        addSeed(`{b.Name}_A`, "SugiSentinels", cf.Position + axis * half, axis, "abutment")
        addSeed(`{b.Name}_B`, "SugiSentinels", cf.Position - axis * half, -axis, "abutment")
    end
end

local pools: { { pos: Vector3, n: number } } = {}
for _, r in workspace.CanyonWorld.Foliage.ShoreRocks:GetChildren() do
    local q = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and (r :: BasePart).Position)
    if q then
        local hit = nil
        for _, g in pools do
            if (g.pos - q).Magnitude < 55 then
                hit = g
                break
            end
        end
        if hit then
            hit.n += 1
            hit.pos = hit.pos:Lerp(q, 1 / hit.n)
        else
            table.insert(pools, { pos = q, n = 1 })
        end
    end
end
table.sort(pools, function(a, b)
    return a.n > b.n
end)
for i = 1, math.min(#pools, 7) do
    addSeed(
        `Pool_{i}`,
        (i % 2 == 1) and "MapleMirror" or "KanzanPair",
        pools[i].pos,
        nil,
        `{pools[i].n} shore rocks`
    )
end

local gateIndex = 0
for name, pts in pathByModel do
    local lo, hi = nil, nil
    for _, q in pts do
        if not lo or q.Y < lo.Y then
            lo = q
        end
        if not hi or q.Y > hi.Y then
            hi = q
        end
    end
    if lo and hi and (hi.Y - lo.Y) >= 20 then
        for _, entry in { { lo, "foot" }, { hi, "head" } } do
            local at = entry[1] :: Vector3
            local ref, bd = nil, math.huge
            for _, q in pts do
                local d = (q - at).Magnitude
                if d > 6 and d < 20 and d < bd then
                    bd, ref = d, q
                end
            end
            local tangent = ref and (ref - at).Unit or Vector3.new(1, 0, 0)
            gateIndex += 1
            addSeed(
                `{name}_{entry[2]}`,
                GATES[(gateIndex - 1) % #GATES + 1],
                at,
                Vector3.new(-tangent.Z, 0, tangent.X),
                "stair end"
            )
        end
    end
end

addSeed("Prom_BenchLanding", "ShrineTrio", Vector3.new(-350, 201, 56), nil, "bench landing")
addSeed("Prom_JunctionLanding", "ShrineTrio", Vector3.new(-148, 180, -76), nil, "junction landing")

local resolved: { { seed: Seed, pos: Vector3 } } = {}
local dropped: { Seed } = {}
for _, s in seeds do
    local anchor = findAnchor(s.pos, s.dir, RADII, TREE_GATE)
    if not anchor then
        anchor = findAnchor(s.pos, s.dir, RADII_LANDMARK, TREE_GATE_LANDMARK)
    end
    if anchor then
        table.insert(resolved, { seed = s, pos = anchor })
    else
        table.insert(dropped, s)
    end
end

if DRY_RUN then
    for _, e in resolved do
        print(
            ("[arr] %-26s %-15s (%d,%d,%d)"):format(
                e.seed.name,
                e.seed.arrangement,
                e.pos.X,
                e.pos.Y,
                e.pos.Z
            )
        )
    end
    for _, s in dropped do
        print(`[arr] UNPLACEABLE {s.name} ({s.note})`)
    end
    return
end

local kit = ServerStorage:FindFirstChild("FoliageKit") :: Folder
assert(kit, "ServerStorage.FoliageKit missing")
local foliage = workspace.CanyonWorld.Foliage
local existing = foliage:FindFirstChild("ArrangementsDraft")
if existing then
    existing:Destroy()
end
local draft = Instance.new("Folder")
draft.Name = "ArrangementsDraft"
draft.Parent = foliage

local placed, skipped = 0, 0
for _, e in resolved do
    local group = Instance.new("Model")
    group.Name = `Arr_{e.seed.name}`
    group:SetAttribute("Arrangement", e.seed.arrangement)
    group:SetAttribute("Site", e.seed.note)
    group.Parent = draft
    for _, tree in ARRANGEMENTS[e.seed.arrangement] do
        local tx, tz = e.pos.X + tree.dx, e.pos.Z + tree.dz
        local gy, water = ground(tx, tz)
        local template = kit:FindFirstChild(tree.species)
        if gy and not water and template then
            local clone = (template :: Model):Clone()
            -- ScaleTo is ABSOLUTE and several templates ship at a non-1 base scale
            -- (RealisticBamboo is 4.93); a relative change must multiply GetScale()
            clone:ScaleTo(clone:GetScale() * tree.scale)
            local depth = tonumber(template:GetAttribute("PlantDepth")) or 0
            local yaw = tree.yawDeg or (tree.dx * 37 + tree.dz * 13) % 360
            clone:PivotTo(CFrame.new(tx, gy - depth, tz) * CFrame.Angles(0, math.rad(yaw), 0))
            for _, d in clone:GetDescendants() do
                if d:IsA("BasePart") then
                    d.Anchored = true
                    d.CastShadow = false
                    d.CanCollide = false
                    d.CanQuery = false
                    d.CanTouch = false
                    if d:IsA("MeshPart") then
                        d.RenderFidelity = Enum.RenderFidelity.Automatic
                    end
                elseif d:IsA("BillboardGui") then
                    d:Destroy()
                end
            end
            clone:SetAttribute("Species", tree.species)
            clone:SetAttribute("Arrangement", e.seed.arrangement)
            clone.Parent = group
            placed += 1
        else
            skipped += 1
        end
    end
    if #group:GetChildren() == 0 then
        group:Destroy()
    end
end

print(
    ("[arr] %d arrangements, %d trees placed, %d skipped, %d seeds unplaceable"):format(
        #draft:GetChildren(),
        placed,
        skipped,
        #dropped
    )
)
for _, s in dropped do
    print(`[arr] unplaceable: {s.name} ({s.note})`)
end
