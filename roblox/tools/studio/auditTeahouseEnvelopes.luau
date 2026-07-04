-- ZenDojo TEAHOUSE EXPANSION-ENVELOPE AUDIT (2026-07-04, meta-game spec open item).
-- READ-ONLY. For each placed teahouse (workspace.CanyonTeahouses.* + workspace.TeahousePrototype),
-- measures how far the site can grow before hitting rock or built structure, and grades which
-- structural tiers (meta-game spec "pad classes": cliff-perch air vocabulary) it can take.
--
-- Method (per site, all in the model's own yaw frame; front = veranda = pivot.LookVector):
--   * FRONT / LEFT / RIGHT clearance: step 4-stud oriented slabs outward from the bbox face,
--     in a height band from deck level up BAND studs. A slab "blocks" when terrain occupancy
--     inside it exceeds ROCK_FRAC (one ReadVoxels over the slab AABB, voxel centers tested
--     against the oriented slab), or an anchored foreign part intrudes.
--   * UP headroom: same slab march, straight up from the bbox top over the footprint.
--   * STILT DROP: raycast down at the outer edge of a T3 (+16) front extension -> stilt length.
--   Deck level comes from the Deck/EngawaF part tops (NOT pivot/bbox — buried stilts lie).
--
-- Provisional tier gates (tune in CONFIG; stated in the report):
--   T2 stage (+8 front or +4 ring) : front >= 10
--   T3 moon deck (+16 front)      : front >= 18 and stilt drop <= DROP_OK (else cantilever-only note)
--   Second story                  : up >= 14
--   Lateral wing (+12 side)       : left or right >= 12
--
-- Run via MCP execute_luau (Edit DM). Returns the report string; also prints it.

local CONFIG = {
    MAX_PROBE = 40, -- studs probed per direction
    BAND = 12, -- clearance band height above deck (studs)
    UP_PROBE = 24, -- headroom probed above roof
    ROCK_FRAC = 0.02, -- slab terrain-occupancy fraction that counts as blocked
    DROP_MAX = 120, -- raycast length for stilt drop
    DROP_OK = 60, -- stilt length beyond this -> "cantilever-only"
    GATES = { T2 = 10, T3 = 18, STORY = 14, WING = 12 },
}

local Terrain = workspace.Terrain

local function deckTopY(model)
    local best = nil
    for _, name in { "Deck", "EngawaF", "Table" } do
        for _, d in model:GetDescendants() do
            if d.Name == name and d:IsA("BasePart") then
                local top = d.Position.Y + d.Size.Y / 2
                if not best or top < best then -- lowest of the floor-ish parts = walking level
                    best = top
                end
            end
        end
        if best then
            break
        end
    end
    return best
end

-- terrain occupancy fraction inside an oriented box (one ReadVoxels over its AABB)
local function rockFraction(cf, size)
    local half = size / 2
    -- AABB of the oriented box
    local minV, maxV =
        Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, sx in { -1, 1 } do
        for _, sy in { -1, 1 } do
            for _, sz in { -1, 1 } do
                local corner = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
                minV = Vector3.new(
                    math.min(minV.X, corner.X),
                    math.min(minV.Y, corner.Y),
                    math.min(minV.Z, corner.Z)
                )
                maxV = Vector3.new(
                    math.max(maxV.X, corner.X),
                    math.max(maxV.Y, corner.Y),
                    math.max(maxV.Z, corner.Z)
                )
            end
        end
    end
    local region = Region3.new(minV, maxV):ExpandToGrid(4)
    local materials, occupancies = Terrain:ReadVoxels(region, 4)
    local sz = occupancies.Size
    local inside, occ = 0, 0
    local origin = region.CFrame.Position - region.Size / 2
    for x = 1, sz.X do
        for y = 1, sz.Y do
            for z = 1, sz.Z do
                local center = origin + Vector3.new((x - 0.5) * 4, (y - 0.5) * 4, (z - 0.5) * 4)
                local lp = cf:PointToObjectSpace(center)
                if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z then
                    inside += 1
                    if
                        materials[x][y][z] ~= Enum.Material.Air
                        and materials[x][y][z] ~= Enum.Material.Water
                    then
                        occ += occupancies[x][y][z]
                    end
                end
            end
        end
    end
    if inside == 0 then
        return 0
    end
    return occ / inside
end

-- first anchored foreign part intruding on an oriented box (nil if clear)
local function blockingPart(cf, size, ownModel)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { ownModel }
    for _, p in workspace:GetPartBoundsInBox(cf, size, params) do
        if p.Anchored and not p:IsDescendantOf(ownModel) then
            local m = p:FindFirstAncestorOfClass("Model")
            return m and m.Name or p.Name
        end
    end
    return nil
end

-- march 4-stud slabs along dir from startDist; returns clear distance + what stopped it
local function march(baseCF, dir, faceOffset, slabPerpSize, ownModel, maxDist)
    local dist, stopper = 0, nil
    local steps = math.floor(maxDist / 4)
    -- up-hint must not be parallel to dir (vertical march uses the model's right axis)
    local upHint = math.abs(dir:Dot(Vector3.yAxis)) > 0.9 and baseCF.RightVector or baseCF.UpVector
    for k = 1, steps do
        local center = baseCF.Position + dir * (faceOffset + (k - 0.5) * 4)
        local size = Vector3.new(slabPerpSize.X, slabPerpSize.Y, 4)
        local slabCF = CFrame.lookAt(center, center + dir, upHint)
        local frac = rockFraction(slabCF, size)
        if frac > CONFIG.ROCK_FRAC then
            stopper = string.format("rock(%.0f%%)", frac * 100)
            break
        end
        local hit = blockingPart(slabCF, size, ownModel)
        if hit then
            stopper = "part:" .. hit
            break
        end
        dist = k * 4
    end
    return dist, stopper
end

local function stiltDrop(worldPoint)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { Terrain }
    local hit = workspace:Raycast(worldPoint, Vector3.new(0, -CONFIG.DROP_MAX, 0), params)
    if hit then
        return worldPoint.Y - hit.Position.Y
    end
    return math.huge
end

local function auditModel(model)
    local pivot = model:GetPivot()
    local bboxCF, bboxSize = model:GetBoundingBox()
    local deckY = deckTopY(model)
    if not deckY then
        return nil, model.Name .. ": no Deck/EngawaF/Table part found"
    end
    local front = pivot.LookVector -- veranda faces local -Z
    local right = pivot.RightVector
    local up = Vector3.yAxis

    -- band frame centered on bbox XZ at deck band height
    local bandCenterY = deckY + CONFIG.BAND / 2
    local base = CFrame.fromMatrix(Vector3.new(bboxCF.Position.X, bandCenterY, bboxCF.Position.Z), right, up)

    -- footprint extents along model axes
    local halfF = bboxSize.Z / 2 -- along front axis
    local halfR = bboxSize.X / 2 -- along right axis

    local res = { name = model.Name }
    res.front, res.frontStop =
        march(base, front, halfF, Vector3.new(bboxSize.X, CONFIG.BAND, 0), model, CONFIG.MAX_PROBE)
    res.right, res.rightStop =
        march(base, right, halfR, Vector3.new(bboxSize.Z, CONFIG.BAND, 0), model, CONFIG.MAX_PROBE)
    res.left, res.leftStop =
        march(base, -right, halfR, Vector3.new(bboxSize.Z, CONFIG.BAND, 0), model, CONFIG.MAX_PROBE)

    local roofTop = bboxCF.Position.Y + bboxSize.Y / 2
    local upBase = CFrame.fromMatrix(Vector3.new(bboxCF.Position.X, roofTop, bboxCF.Position.Z), right, up)
    res.up, res.upStop = march(upBase, up, 0, Vector3.new(bboxSize.X, bboxSize.Z, 0), model, CONFIG.UP_PROBE)

    -- stilt drop at the outer edge of a T3 (+16) front extension, from deck level
    local edgeCenter = Vector3.new(bboxCF.Position.X, deckY, bboxCF.Position.Z) + front * (halfF + 16)
    res.drop = 0
    for _, s in { -0.4, 0, 0.4 } do
        res.drop = math.max(res.drop, stiltDrop(edgeCenter + right * (bboxSize.X * s)))
    end

    -- grades
    local G = CONFIG.GATES
    res.T2 = res.front >= G.T2
    res.T3 = res.front >= G.T3
    res.T3note = res.T3
            and (res.drop > CONFIG.DROP_OK and "cantilever-only" or string.format("stilts %.0f", res.drop))
        or ""
    res.story = res.up >= G.STORY
    res.wing = (res.left >= G.WING and "L") or (res.right >= G.WING and "R") or false
    return res
end

local models = {}
local folder = workspace:FindFirstChild("CanyonTeahouses")
if folder then
    for _, m in folder:GetChildren() do
        if m:IsA("Model") then
            table.insert(models, m)
        end
    end
end
local proto = workspace:FindFirstChild("TeahousePrototype")
if proto then
    table.insert(models, proto)
end
table.sort(models, function(a, b)
    return a.Name < b.Name
end)

local lines = {
    string.format(
        "TEAHOUSE ENVELOPE AUDIT — gates: T2 front>=%d, T3 front>=%d (drop<=%d else cantilever), story up>=%d, wing side>=%d; band=%d, rockFrac=%.0f%%",
        CONFIG.GATES.T2,
        CONFIG.GATES.T3,
        CONFIG.DROP_OK,
        CONFIG.GATES.STORY,
        CONFIG.GATES.WING,
        CONFIG.BAND,
        CONFIG.ROCK_FRAC * 100
    ),
    "site | front | left | right | up | T2 | T3 | story | wing | stoppers",
}
for _, m in models do
    local r, err = auditModel(m)
    if not r then
        table.insert(lines, "!! " .. err)
    else
        table.insert(
            lines,
            string.format(
                "%s | %d | %d | %d | %d | %s | %s | %s | %s | F:%s L:%s R:%s U:%s",
                r.name,
                r.front,
                r.left,
                r.right,
                r.up,
                r.T2 and "Y" or "-",
                r.T3 and ("Y " .. r.T3note) or "-",
                r.story and "Y" or "-",
                r.wing or "-",
                r.frontStop or "clear",
                r.leftStop or "clear",
                r.rightStop or "clear",
                r.upStop or "clear"
            )
        )
    end
end

local report = table.concat(lines, "\n")
print(report)
return report
