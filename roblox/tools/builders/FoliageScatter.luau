--!strict
-- Deterministic foliage/lantern scatter — pure point generation (region + density +
-- seed → {x,z} list). The live greening pass raycasts Y onto the terrain. Reusable
-- canyon-wide (the downcanyon view is the first caller). No math.random (banned under
-- Lune + non-reproducible): a small LCG keyed off the seed.
local FoliageScatter = {}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648 -- next state, [0,1)
end

-- density = expected points per square stud. Walks a grid whose cell ≈ 1/sqrt(density)
-- and jitters one point per cell so the scatter reads organic, not gridded.
function FoliageScatter.points(
    region: { xMin: number, xMax: number, zMin: number, zMax: number },
    density: number,
    seed: number
): { { number } }
    local cell = 1 / math.sqrt(math.max(density, 1e-6))
    local pts = {}
    local state = (seed * 2654435761) % 2147483648 + 1
    local x = region.xMin
    while x < region.xMax do
        local z = region.zMin
        while z < region.zMax do
            local jx, jz
            state, jx = lcg(state)
            state, jz = lcg(state)
            local px = math.clamp(x + jx * cell, region.xMin, region.xMax)
            local pz = math.clamp(z + jz * cell, region.zMin, region.zMax)
            table.insert(pts, { px, pz })
            z += cell
        end
        x += cell
    end
    return pts
end

return FoliageScatter
