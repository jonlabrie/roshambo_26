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
AccessGates.REVEAL_MARGIN = 10 -- studs beyond the deck edge at which the perimeter reveals to a blocked viewer
AccessGates.NAV_Y = 2.35 -- centre height of the corner nav lights (just below the 2.75 newel/cap top)
AccessGates.NAV_W = 0.3 -- nav light size: width along the deck X face
AccessGates.NAV_H = 0.5 -- nav light height (Y)
AccessGates.NAV_T = 0.12 -- nav light depth (deck Z; thin, flush against the newel's front face)
-- The newel's OUTER face is flush to the footprint corner, so its CENTRE sits half a newel-width
-- inboard. Inset the light by that so it centres on the newel instead of hanging off the outer edge.
-- Half of PadOps.NEWEL_W (0.45); fixed across deck sizes (railing dims don't scale, only the footprint).
AccessGates.NAV_X_INSET = 0.225

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

-- The full sealing perimeter for a blocked viewer: four tall walls around the deck footprint
-- (back +Z, front -Z, and both sides ±X). The deck is railed on three sides and open at the back,
-- but avatars can climb the spaced railings, so a single back wall lets a determined intruder hop a
-- side; the perimeter seals every approach. Only ever built for a blocked viewer (client-local), so
-- it never obstructs the owner or an invited guest. Side walls overlap the front/back by GATE_T at
-- the corners so there is no gap.
function AccessGates.deckPerimeter(
    deckCF12: { number },
    deckSize: string
): { { cframe: { number }, size: { number } } }
    local fp = SizeClasses.deckFootprint(deckSize)
    local width = fp.maxX - fp.minX
    local depth = fp.maxZ - fp.minZ
    local h = AccessGates.GATE_H
    local t = AccessGates.GATE_T
    local sideDepth = depth + 2 * t -- overlap the corners
    return {
        { cframe = compose(deckCF12, 0, h / 2, fp.maxZ), size = { width, h, t } }, -- back (+Z)
        { cframe = compose(deckCF12, 0, h / 2, fp.minZ), size = { width, h, t } }, -- front (-Z)
        { cframe = compose(deckCF12, fp.maxX, h / 2, 0), size = { t, h, sideDepth } }, -- right (+X)
        { cframe = compose(deckCF12, fp.minX, h / 2, 0), size = { t, h, sideDepth } }, -- left (-X)
    }
end

-- Horizontal distance from the deck centre at which a blocked viewer's perimeter reveals + turns
-- solid: the footprint's half-diagonal (so corners are covered) plus REVEAL_MARGIN. Client compares
-- this to the LocalPlayer's planar distance from the deck centre (deckCF12[1], deckCF12[3]).
function AccessGates.revealRadius(deckSize: string): number
    local fp = SizeClasses.deckFootprint(deckSize)
    local halfDiag = math.sqrt(fp.maxX * fp.maxX + fp.maxZ * fp.maxZ)
    return halfDiag + AccessGates.REVEAL_MARGIN
end

-- The pad's two public/private mode lights: small rectangles embedded in the front (-Z, canyon-
-- facing) face of each front-corner newel, near the top -- ship-navigation-light style. Both take
-- the same colour (the caller picks it from the owner's mode; this signal is the same for every
-- viewer). 12-number cframe (deck rotation preserved) + 3-number size, like deckPerimeter. The front
-- edge cantilevers over the drop, so the lights read from the valley floor.
function AccessGates.navLights(
    deckCF12: { number },
    deckSize: string
): { { cframe: { number }, size: { number } } }
    local fp = SizeClasses.deckFootprint(deckSize)
    local size = { AccessGates.NAV_W, AccessGates.NAV_H, AccessGates.NAV_T }
    local inset = AccessGates.NAV_X_INSET
    return {
        { cframe = compose(deckCF12, fp.maxX - inset, AccessGates.NAV_Y, fp.minZ), size = size }, -- right front newel
        { cframe = compose(deckCF12, fp.minX + inset, AccessGates.NAV_Y, fp.minZ), size = size }, -- left front newel
    }
end

function AccessGates.evictionPoint(deckCF12: { number }, deckSize: string): { number }
    local fp = SizeClasses.deckFootprint(deckSize)
    return compose(deckCF12, 0, AccessGates.EVICT_Y, fp.maxZ + AccessGates.EVICT_OUT)
end

return AccessGates
