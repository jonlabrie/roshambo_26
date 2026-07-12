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

return BuildingPlacer
