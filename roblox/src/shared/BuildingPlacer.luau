--!strict
-- Pure placer for Piece A. Turns a {offset, facing} placement into the building's
-- deck-LOCAL transform (12-number CFrame, Spec.cframe order) and answers fit questions. No
-- Roblox datatypes (Lune-tested). `facing` snaps to the deck's 4 edges.
local BuildingPlacer = {}

export type Placement = { offset: { number }, facing: string }

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

-- Slide a placement the minimum distance so its rotation-aware footprint fits inside the deck
-- (B4). Facing is preserved; a degenerate axis (building wider than the deck) centers on that
-- axis. Returns a NEW placement — never mutates the input; callers may persist the result.
function BuildingPlacer.clamp(buildingFP: FP, deckFP: FP, p: Placement): Placement
    local halfX = (buildingFP.maxX - buildingFP.minX) / 2
    local halfZ = (buildingFP.maxZ - buildingFP.minZ) / 2
    local yaw = BuildingPlacer.facingYaw(p.facing)
    if yaw == 90 or yaw == 270 then
        halfX, halfZ = halfZ, halfX
    end
    local function axis(v: number, half: number, lo: number, hi: number): number
        if half * 2 > (hi - lo) then
            return (lo + hi) / 2
        end
        return math.clamp(v, lo + half, hi - half)
    end
    return {
        offset = {
            axis(p.offset[1], halfX, deckFP.minX, deckFP.maxX),
            axis(p.offset[2], halfZ, deckFP.minZ, deckFP.maxZ),
        },
        facing = p.facing,
    }
end

-- Whether a building at this facing CAN fit inside the bounds at any offset (B4): the
-- rotation-aware extents must not exceed the bounds' dimensions. clamp()'s degenerate-axis
-- centering makes an un-fitting facing render outside the bounds, so callers must screen
-- facings with this first (rotate UI skips them; the commit handler rejects them).
function BuildingPlacer.canFitFacing(buildingFP: FP, boundsFP: FP, facing: string): boolean
    local halfX = (buildingFP.maxX - buildingFP.minX) / 2
    local halfZ = (buildingFP.maxZ - buildingFP.minZ) / 2
    local yaw = BuildingPlacer.facingYaw(facing)
    if yaw == 90 or yaw == 270 then
        halfX, halfZ = halfZ, halfX
    end
    return halfX * 2 <= (boundsFP.maxX - boundsFP.minX) and halfZ * 2 <= (boundsFP.maxZ - boundsFP.minZ)
end

-- Deck-local axis-aligned bounds of a centered footprint placed at p.offset with p.facing.
-- 90/270 swap the half-extents (rotation-aware), matching fits()/clamp(). Used to test
-- decoration-vs-teahouse overlap and to clamp decorations to the deck.
function BuildingPlacer.footprintBounds(fp: FP, p: Placement): FP
    local halfX = (fp.maxX - fp.minX) / 2
    local halfZ = (fp.maxZ - fp.minZ) / 2
    local yaw = BuildingPlacer.facingYaw(p.facing)
    if yaw == 90 or yaw == 270 then
        halfX, halfZ = halfZ, halfX
    end
    local dx, dz = p.offset[1], p.offset[2]
    return { minX = dx - halfX, maxX = dx + halfX, minZ = dz - halfZ, maxZ = dz + halfZ }
end

return BuildingPlacer
