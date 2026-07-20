--!strict
-- Pure gate geometry for teahouse access control (2026-07-19). Derives the deck-back privacy gate
-- and the eviction target from a deck's CFrame + size. No Roblox datatypes (12-number row-major
-- CFrame arrays, 3-number size arrays) -> Lune-tested. Composition mirrors PortalTarget.deckLanding:
-- world = deckPos + deckRot * localOffset, deck rotation preserved. Deck-local: -Z front/view, +Z
-- back/access (open edge). The gate is TALL (GATE_H) to seal -- distinct from the low fall-guard --
-- and is only ever built for a blocked viewer.
local SizeClasses = require("./SizeClasses")

local AccessGates = {}

AccessGates.GATE_H = 12 -- seal height (well above the ~7-stud jump)
AccessGates.GATE_T = 1 -- wall thickness
AccessGates.EVICT_OUT = 4 -- studs beyond the back edge, onto the path
AccessGates.EVICT_Y = 3 -- HRP standing height above the deck datum

-- compose a deck-local translation (ox,oy,oz) with the deck CFrame: rotate the offset by the deck's
-- rotation and add to the deck position; keep the deck rotation. Returns a 12-number array.
local function compose(deckCF12: { number }, ox: number, oy: number, oz: number): { number }
    local px, py, pz = deckCF12[1], deckCF12[2], deckCF12[3]
    local r00, r01, r02 = deckCF12[4], deckCF12[5], deckCF12[6]
    local r10, r11, r12 = deckCF12[7], deckCF12[8], deckCF12[9]
    local r20, r21, r22 = deckCF12[10], deckCF12[11], deckCF12[12]
    local wx = px + r00 * ox + r01 * oy + r02 * oz
    local wy = py + r10 * ox + r11 * oy + r12 * oz
    local wz = pz + r20 * ox + r21 * oy + r22 * oz
    return { wx, wy, wz, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

function AccessGates.deckBackGate(
    deckCF12: { number },
    deckSize: string
): { cframe: { number }, size: { number } }
    local fp = SizeClasses.deckFootprint(deckSize)
    local width = fp.maxX - fp.minX
    -- centered on X, raised half-height, at the +Z back edge
    local cframe = compose(deckCF12, 0, AccessGates.GATE_H / 2, fp.maxZ)
    return { cframe = cframe, size = { width, AccessGates.GATE_H, AccessGates.GATE_T } }
end

function AccessGates.evictionPoint(deckCF12: { number }, deckSize: string): { number }
    local fp = SizeClasses.deckFootprint(deckSize)
    return compose(deckCF12, 0, AccessGates.EVICT_Y, fp.maxZ + AccessGates.EVICT_OUT)
end

return AccessGates
