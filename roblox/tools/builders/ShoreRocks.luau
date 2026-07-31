--!strict
-- Ishigumi-style rock clusters at pool waterlines (spec
-- 2026-07-30-foliage-finish §ShoreRocks): NOT a necklace - one big ANCHOR
-- stone, a few mid ATTENDANTS, sometimes a small WADER half in the water,
-- separated by long stretches of deliberately bare bank. Density peaks at
-- each pool's inflow/outfall LIPS (elevation jumps between water sheets,
-- where moving water actually deposits rock); quiet mid-bank edges get only
-- sparse clusters. Pure, deterministic (integer LCG). The Studio
-- collector/bake mirror is a follow-up.

export type WaterCell = { x: number, z: number, y: number }
export type Params = {
    seed: number,
    cell: number, -- water-map grid pitch
    sheetTol: number, -- |dy| <= sheetTol => same water sheet
    lipRadius: number, -- radius scanned for elevation jumps
    lipMinDrop: number, -- min |dy| within lipRadius to count as a lip
    lipSpacing: number, -- min distance between lip-cluster anchors
    quietSpacing: number, -- min distance between quiet-bank anchors AND from lip anchors
    memberRadiusMin: number, -- attendant polar offset from anchor
    memberRadiusMax: number,
    memberSpacing: number, -- min distance between any two placements in the plan
    attendantsMin: number,
    attendantsMax: number,
    wadersMax: number, -- 0..wadersMax waders per cluster, rolled uniformly
    waderReach: number, -- max wader step toward open water (floor is memberSpacing)
    scaleMin: number,
    scaleMax: number,
}
export type RockPlacement = {
    x: number,
    z: number,
    role: string, -- "anchor" | "attendant" | "wader"
    yaw: number, -- radians
    scale: number,
    lip: boolean, -- true if this cluster was seeded by lip score
}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function key(cx: number, cz: number): string
    return `{cx},{cz}`
end

-- same rounding as the water map
local function cellKey(x: number, z: number, cell: number): string
    return key(math.floor(x / cell + 0.5), math.floor(z / cell + 0.5))
end

-- fixed order: east/west/south/north = (+x, -x, +z, -z)
local DIRS = {
    { dx = 1, dz = 0 },
    { dx = -1, dz = 0 },
    { dx = 0, dz = 1 },
    { dx = 0, dz = -1 },
}

type Index = { [string]: { WaterCell } }

local function buildIndex(cells: { WaterCell }, cell: number): Index
    local index: Index = {}
    for _, c in cells do
        local k = cellKey(c.x, c.z, cell)
        local bucket = index[k]
        if bucket == nil then
            bucket = {}
            index[k] = bucket
        end
        table.insert(bucket, c)
    end
    return index
end

local function sheetPresent(index: Index, cx: number, cz: number, y: number, sheetTol: number): boolean
    local bucket = index[key(cx, cz)]
    if bucket == nil then
        return false
    end
    for _, c in bucket do
        if math.abs(c.y - y) <= sheetTol then
            return true
        end
    end
    return false
end

type EdgeCell = {
    cell: WaterCell,
    landDx: number,
    landDz: number,
}

local function findEdgeCells(
    cells: { WaterCell },
    index: Index,
    cellSize: number,
    sheetTol: number
): { EdgeCell }
    local edges: { EdgeCell } = {}
    for _, c in cells do
        local cx = math.floor(c.x / cellSize + 0.5)
        local cz = math.floor(c.z / cellSize + 0.5)
        local landDx: number? = nil
        local landDz: number? = nil
        for _, d in DIRS do
            if not sheetPresent(index, cx + d.dx, cz + d.dz, c.y, sheetTol) then
                landDx, landDz = d.dx, d.dz
                break
            end
        end
        if landDx ~= nil and landDz ~= nil then
            table.insert(edges, { cell = c, landDx = landDx, landDz = landDz })
        end
    end
    return edges
end

-- max |dy| between c and any cell within lipRadius (XZ euclidean)
local function lipScore(index: Index, cellSize: number, c: WaterCell, lipRadius: number): number
    local kr = math.ceil(lipRadius / cellSize)
    local cx = math.floor(c.x / cellSize + 0.5)
    local cz = math.floor(c.z / cellSize + 0.5)
    local best = 0
    for gx = cx - kr, cx + kr do
        for gz = cz - kr, cz + kr do
            local bucket = index[key(gx, gz)]
            if bucket ~= nil then
                for _, other in bucket do
                    local dx, dz = other.x - c.x, other.z - c.z
                    if dx * dx + dz * dz <= lipRadius * lipRadius then
                        local dy = math.abs(other.y - c.y)
                        if dy > best then
                            best = dy
                        end
                    end
                end
            end
        end
    end
    return best
end

local function withinBand(edgeIndex: Index, cellSize: number, x: number, z: number, band: number): boolean
    local kr = math.ceil(band / cellSize)
    local cx = math.floor(x / cellSize + 0.5)
    local cz = math.floor(z / cellSize + 0.5)
    for gx = cx - kr, cx + kr do
        for gz = cz - kr, cz + kr do
            local bucket = edgeIndex[key(gx, gz)]
            if bucket ~= nil then
                for _, e in bucket do
                    local dx, dz = x - e.x, z - e.z
                    if dx * dx + dz * dz <= band * band then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function nearExisting(existing: { { x: number, z: number } }?, x: number, z: number): boolean
    if existing == nil then
        return false
    end
    for _, e in existing :: { { x: number, z: number } } do
        local dx, dz = x - e.x, z - e.z
        if dx * dx + dz * dz <= 100 then
            return true
        end
    end
    return false
end

type Candidate = {
    x: number,
    z: number,
    landDx: number,
    landDz: number,
    score: number,
    lip: boolean,
}

local function plan(
    cells: { WaterCell },
    params: Params,
    keepOut: ((number, number) -> boolean)?,
    existing: { { x: number, z: number } }?
): { RockPlacement }
    local index = buildIndex(cells, params.cell)
    local edges = findEdgeCells(cells, index, params.cell, params.sheetTol)

    local edgeIndex: Index = {}
    for _, e in edges do
        local k = cellKey(e.cell.x, e.cell.z, params.cell)
        local bucket = edgeIndex[k]
        if bucket == nil then
            bucket = {}
            edgeIndex[k] = bucket
        end
        table.insert(bucket, e.cell)
    end

    -- candidate filter (step 4) + lip/quiet split
    local lipCandidates: { Candidate } = {}
    local quietCandidates: { Candidate } = {}
    for _, e in edges do
        local c = e.cell
        if keepOut ~= nil and keepOut(c.x, c.z) then
            continue
        end
        if nearExisting(existing, c.x, c.z) then
            continue
        end
        local score = lipScore(index, params.cell, c, params.lipRadius)
        local cand: Candidate = {
            x = c.x,
            z = c.z,
            landDx = e.landDx,
            landDz = e.landDz,
            score = score,
            lip = score >= params.lipMinDrop,
        }
        if cand.lip then
            table.insert(lipCandidates, cand)
        else
            table.insert(quietCandidates, cand)
        end
    end

    table.sort(lipCandidates, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)
    table.sort(quietCandidates, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)

    local anchors: { Candidate } = {}
    local function farFromAnchors(cand: Candidate, minDist: number): boolean
        for _, a in anchors do
            local dx, dz = cand.x - a.x, cand.z - a.z
            if dx * dx + dz * dz < minDist * minDist then
                return false
            end
        end
        return true
    end

    for _, cand in lipCandidates do
        if farFromAnchors(cand, params.lipSpacing) then
            table.insert(anchors, cand)
        end
    end
    for _, cand in quietCandidates do
        if farFromAnchors(cand, params.quietSpacing) then
            table.insert(anchors, cand)
        end
    end

    -- cluster growth: one continuous roll stream, anchors in acceptance order
    local state = (params.seed * 2654435761) % 2147483648 + 1
    local function roll(): number
        local r
        state, r = lcg(state)
        return r
    end

    local out: { RockPlacement } = {}
    local function farFromOutput(x: number, z: number, minDist: number): boolean
        for _, p in out do
            local dx, dz = x - p.x, z - p.z
            if dx * dx + dz * dz < minDist * minDist then
                return false
            end
        end
        return true
    end

    for _, a in anchors do
        local anchorYaw = roll() * 2 * math.pi
        local anchorScale = params.scaleMin + roll() * (params.scaleMax - params.scaleMin)
        table.insert(out, {
            x = a.x,
            z = a.z,
            role = "anchor",
            yaw = anchorYaw,
            scale = anchorScale,
            lip = a.lip,
        })

        local attendantCount = params.attendantsMin
            + math.floor(roll() * (params.attendantsMax - params.attendantsMin + 1))
        for _ = 1, attendantCount do
            local placed = false
            for _try = 1, 4 do
                if placed then
                    break
                end
                local ang = roll() * 2 * math.pi
                local radius = params.memberRadiusMin
                    + roll() * (params.memberRadiusMax - params.memberRadiusMin)
                local yaw = roll() * 2 * math.pi
                local scale = params.scaleMin + roll() * (params.scaleMax - params.scaleMin)
                local x = a.x + math.cos(ang) * radius
                local z = a.z + math.sin(ang) * radius
                if
                    (keepOut == nil or not keepOut(x, z))
                    and withinBand(edgeIndex, params.cell, x, z, params.cell * 1.5)
                    and farFromOutput(x, z, params.memberSpacing)
                then
                    table.insert(out, {
                        x = x,
                        z = z,
                        role = "attendant",
                        yaw = yaw,
                        scale = scale,
                        lip = a.lip,
                    })
                    placed = true
                end
            end
        end

        local waderCount = math.floor(roll() * (params.wadersMax + 1))
        for _ = 1, waderCount do
            local stepRoll = roll()
            local jitterRoll = roll()
            local yaw = roll() * 2 * math.pi
            local scaleRoll = roll()
            -- the step FLOOR is memberSpacing: a shorter step lands the wader inside
            -- its own anchor's spacing bubble and farFromOutput rejects it every time
            -- (the original 0-based roll silently zeroed waders out of whole plans)
            local step = params.memberSpacing
                + stepRoll * math.max(params.waderReach - params.memberSpacing, 0)
            local jitter = (jitterRoll * 2 - 1) * 2
            -- water-inward direction is the opposite of the land direction;
            -- both are axis-aligned unit vectors, so the perpendicular is too
            local dx, dz = -a.landDx, -a.landDz
            local px, pz = -dz, dx
            local x = a.x + dx * step + px * jitter
            local z = a.z + dz * step + pz * jitter
            local scale = (params.scaleMin + scaleRoll * (params.scaleMax - params.scaleMin)) * 0.6
            if (keepOut == nil or not keepOut(x, z)) and farFromOutput(x, z, params.memberSpacing) then
                table.insert(out, {
                    x = x,
                    z = z,
                    role = "wader",
                    yaw = yaw,
                    scale = scale,
                    lip = a.lip,
                })
            end
        end
    end

    return out
end

return { plan = plan }
