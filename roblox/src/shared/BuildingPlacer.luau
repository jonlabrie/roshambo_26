--!strict
-- Pure placer for Piece A. Turns a {offset, facing, openSide} placement into the building's
-- deck-LOCAL transform (12-number CFrame, Spec.cframe order) and answers fit questions. No
-- Roblox datatypes (Lune-tested). `facing` snaps to the deck's 4 edges; `openSide` selects the
-- shoji L-wrap (consumed by StructureBuilder, not here).
local BuildingPlacer = {}

export type Placement = { offset: { number }, facing: string, openSide: string }

local YAW = { N = 0, E = 90, S = 180, W = 270 }

function BuildingPlacer.facingYaw(facing: string): number
    local y = YAW[facing]
    if y == nil then
        error(`BuildingPlacer.facingYaw: bad facing '{facing}'`)
    end
    return y
end

-- Y-axis rotation matrix (row-major) for a CCW yaw in degrees, plus a (dx,0,dz) translation.
function BuildingPlacer.placeCF(p: Placement): { number }
    local rad = math.rad(BuildingPlacer.facingYaw(p.facing))
    local c, s = math.cos(rad), math.sin(rad)
    local dx, dz = p.offset[1], p.offset[2]
    -- pos, then R = [ c 0 s ; 0 1 0 ; -s 0 c ]
    return { dx, 0, dz, c, 0, s, 0, 1, 0, -s, 0, c }
end

type FP = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Rotate a footprint's half-extents by a 90-deg-multiple yaw. 0/180 keep (halfX,halfZ);
-- 90/270 swap them. Footprints are centered on the building's own origin, so we track
-- half-extents then re-center at the placement offset.
function BuildingPlacer.fits(buildingFP: FP, deckFP: FP, p: Placement): boolean
    local halfX = (buildingFP.maxX - buildingFP.minX) / 2
    local halfZ = (buildingFP.maxZ - buildingFP.minZ) / 2
    local yaw = BuildingPlacer.facingYaw(p.facing)
    if yaw == 90 or yaw == 270 then
        halfX, halfZ = halfZ, halfX
    end
    local dx, dz = p.offset[1], p.offset[2]
    return (dx - halfX) >= deckFP.minX
        and (dx + halfX) <= deckFP.maxX
        and (dz - halfZ) >= deckFP.minZ
        and (dz + halfZ) <= deckFP.maxZ
end

return BuildingPlacer
