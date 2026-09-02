--!strict
-- Pure decision module for deck mortars (deck-mortars feature, 2026-09-04): players own
-- mortars (mortar:S/M/L) that render on their teahouse deck at front-edge defaults, movable
-- via stored placements. This module makes ALL placement decisions (defaults, stored
-- overrides, clamping, teahouse-overlap nudge) plus the muzzle world-position math; runtime
-- files only call it. Consumes nothing -- bounds are passed in. Lune-tested; no Roblox
-- datatypes.
--
-- Front edge = local MINZ. The canyon-facing side is -Z in deck-local space: verified in the
-- live place 2026-09-04 against T01 -- the Nobori (built to read from across the canyon) sits
-- on the -Z side and the back-door PortalControl on +Z. (The plan originally asserted +Z and
-- shipped the tubes onto the back edge, behind the teahouse.)
--
-- Clamp philosophy mirrors DecorationLayout/BuildingPlacer: a STORED placement is never
-- mutated, only what resolve() returns adapts.
local MortarPlacement = {}

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Resolved = { mount: string, x: number, z: number, aim: string }
export type StoredPlacement = { offset: { number }, facing: string?, mount: string?, aim: string? }
export type Tube = { bore: number, length: number }

-- ⚠ Mirrors MORTAR_IDS in server/src/fireworks.ts (Object.keys(MORTAR_PRICES)) -- both are the
-- shop's gear ladder S -> M -> L; if one adds/reorders a tier without the other, defaults drift.
MortarPlacement.MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }

-- ⚠ Mirrors REQUIREMENTS in server/src/fireworks.ts (the `.mortar` field of each shell's
-- requirement) -- the client is never told a shell's requirement (server/src/fireworks.ts:
-- "The client is told PRICES, never requirements"), so the Studio server can't fetch this from
-- the backend and instead carries its own minimal copy. If TS adds/changes a gear requirement
-- without a matching edit here, the Studio server would happily let a shell fire from the
-- player's eye level instead of its mortar's muzzle -- but as of the final-review fix round
-- (deck-mortars) that drift now fails CI: shared-fixtures/firework-shells.json's `mortars` list
-- is the enforced contract, asserted against THIS table by tests/MortarPlacement.spec.luau and
-- against TS's REQUIREMENTS by fireworks.test.ts. Promoting a shell to gear-required (or changing
-- its tier) touches all three: REQUIREMENTS, this table, AND the fixture.
MortarPlacement.SHELL_MORTAR = {
    peony = "mortar:S",
    willow = "mortar:M",
    kiku = "mortar:S",
    wa = "mortar:M",
    yashi = "mortar:M",
    kamuro = "mortar:L",
} :: { [string]: string }

-- Proving-range proportions (1 stud = 1 ft): bore is tube inner diameter, length is tube length.
MortarPlacement.TUBE = {
    ["mortar:S"] = { bore = 1 / 6, length = 0.85 },
    ["mortar:M"] = { bore = 1 / 3, length = 1.5 },
    ["mortar:L"] = { bore = 0.5, length = 2.5 },
} :: { [string]: Tube }

-- The three aims a mount can fire along, deck-local: L/R yaw off center, C fires straight
-- over the front edge.
MortarPlacement.AIMS = { "L", "C", "R" }

-- Elevation angle (degrees from vertical) each mount fires its tube at -- owner-tunable art
-- knob, not derived from anything.
MortarPlacement.ELEVATION = { floor = 12, rail = 25 }

-- ⚠ Mirrors PadOps' CAP_TOP/CAP_W/NEWEL_W (src/server/PadOps.luau: charcoal top rail + corner
-- newels) -- a rail-mounted mortar sits on the SAME cap rail PadOps builds, so if PadOps' cap
-- height/width or newel width change, this table must follow or a rail mortar renders floating
-- off (or clipping into) the actual rail. newelMargin = NEWEL_W (0.45) + 0.5 breathing room so
-- the mortar's own footprint never overlaps a corner post.
MortarPlacement.RAIL = { capTop = 2.75, capWidth = 0.45, newelMargin = 0.95 }

-- Tube-bottom height above the mount point: timber base block on the floor, rail saddle block
-- on the cap rail.
MortarPlacement.BASE_OFFSET = { floor = 0.5, rail = 0.35 }

-- Deck-local aim direction (unit XZ, no Y) for each named aim: C points straight over the
-- front edge (-Z); L/R yaw 30 degrees off center. File-local -- only axisLocal consumes it.
local AIM_DIR = {
    L = { -0.5, -0.8660254037844386 },
    C = { 0, -1 },
    R = { 0.5, -0.8660254037844386 },
}

-- Generic gear footprint half-extent used to clamp a placement's center onto the deck --
-- deliberately size-independent (unlike buildings/decorations, which clamp by their own
-- footprint) since a mortar's tube is a thin vertical prop, not a wide base.
local PLACEMENT_HALF = 0.5

-- Exported centered footprint for the client's editor drag (MoveController): the SAME
-- size-independent half-extent every tier clamps against above, just shaped like
-- DecorationCatalog.footprint()'s {minX,maxX,minZ,maxZ} so BuildingPlacer.clamp/canFitFacing
-- can consume it identically to a decoration's footprint. One tier-agnostic table, not a
-- per-id lookup -- there is only one gear footprint, same as the clamp above.
MortarPlacement.FOOTPRINT = {
    minX = -PLACEMENT_HALF,
    maxX = PLACEMENT_HALF,
    minZ = -PLACEMENT_HALF,
    maxZ = PLACEMENT_HALF,
} :: Bounds

local function clamp(v: number, lo: number, hi: number): number
    return math.clamp(v, lo, hi)
end

local function clampPoint(bounds: Bounds, x: number, z: number): (number, number)
    return clamp(x, bounds.minX + PLACEMENT_HALF, bounds.maxX - PLACEMENT_HALF),
        clamp(z, bounds.minZ + PLACEMENT_HALF, bounds.maxZ - PLACEMENT_HALF)
end

local function strictlyInside(x: number, z: number, fp: Bounds): boolean
    return x > fp.minX and x < fp.maxX and z > fp.minZ and z < fp.maxZ
end

-- Default X for owned tier `i` of `n`, spread evenly across the middle half of the deck's X
-- span: one mortar centers; two sit at +-25% of span; three at -25%/0/+25%, etc.
local function defaultX(bounds: Bounds, i: number, n: number): number
    local center = (bounds.minX + bounds.maxX) / 2
    local quarterSpan = (bounds.maxX - bounds.minX) / 4
    if n <= 1 then
        return center
    end
    local fraction = -1 + 2 * (i - 1) / (n - 1)
    return center + fraction * quarterSpan
end

-- Teahouse nudge: a resolved spot strictly inside teahouseFP moves to the front edge (keeping
-- its clamped x); if still inside, walk x outward in 1-stud steps (alternating +/-), clamped
-- to the RAW deck bounds (not the narrower placement inset -- escaping a hide-zone outranks
-- staying inset), until clear or the bounds clamp stops changing the candidate. Always returns
-- a position -- never nil, never touches the caller's stored table.
local function nudge(bounds: Bounds, x: number, z: number, teahouseFP: Bounds?): (number, number)
    if teahouseFP == nil or not strictlyInside(x, z, teahouseFP) then
        return x, z
    end
    local frontZ = bounds.minZ + 1
    if not strictlyInside(x, frontZ, teahouseFP) then
        return x, frontZ
    end
    local lastPos, lastNeg = nil :: number?, nil :: number?
    local maxStep = math.ceil(bounds.maxX - bounds.minX) + 1
    for step = 1, maxStep do
        local posC = clamp(x + step, bounds.minX, bounds.maxX)
        if not strictlyInside(posC, frontZ, teahouseFP) then
            return posC, frontZ
        end
        local negC = clamp(x - step, bounds.minX, bounds.maxX)
        if not strictlyInside(negC, frontZ, teahouseFP) then
            return negC, frontZ
        end
        if posC == lastPos and negC == lastNeg then
            break -- the bounds clamp stopped progress in both directions
        end
        lastPos, lastNeg = posC, negC
    end
    return x, frontZ -- exhausted the deck without clearing; still must return a position
end

-- The gear's default mount when there is no stored record at all (every owned id not present
-- in `stored`). PULLED by the owner at the 2026-09-05 gate: a new owner's tubes saddle the
-- front rail out of the box (staggered via `railDefault`, aimed "C" over the canyon).
-- ⚠ This governs ABSENT records only -- a stored record without a `mount` field is a LEGACY
-- placement and reads "floor" at its saved spot (see `resolve`); the lever must never
-- relocate what a player already placed.
local DEFAULT_MOUNT = "rail"

-- The staggered default deck-local spot for the i-th of n owned mortars mounted on the rail
-- with NO stored override: the SAME i/n stagger the floor defaults use (defaultX), clamped
-- into the rail's newel margins instead of the floor placement inset, pinned to the cap rail's
-- z, aimed straight ("C"). Exported so it's directly testable even while DEFAULT_MOUNT stays
-- "floor" this round and `resolve`'s public surface can't otherwise reach this branch.
function MortarPlacement.railDefault(deckBounds: Bounds, i: number, n: number): (number, number, string)
    local x = clamp(
        defaultX(deckBounds, i, n),
        deckBounds.minX + MortarPlacement.RAIL.newelMargin,
        deckBounds.maxX - MortarPlacement.RAIL.newelMargin
    )
    local z = deckBounds.minZ + MortarPlacement.RAIL.capWidth / 2
    return x, z, "C"
end

-- Resolves every OWNED mortar's deck-local placement: defaults for anything not in `stored`,
-- stored overrides (clamped) otherwise, then a teahouse nudge if `teahouseFP` is given.
-- Unknown/unowned ids in `stored` are ignored; every owned id always gets a row. A stored
-- record's `mount`/`aim` pass through (missing -> DEFAULT_MOUNT/"C"); `facing` is legacy and
-- ignored. A rail mount clamps its OWN way (RAIL.newelMargin inset, cap-rail z) and never
-- nudges -- the teahouse cannot occupy the rail, so there is nothing to escape.
function MortarPlacement.resolve(
    deckBounds: Bounds,
    owned: { string },
    stored: { [string]: StoredPlacement }?,
    teahouseFP: Bounds?
): { [string]: Resolved }
    local ownedSet: { [string]: boolean } = {}
    for _, id in owned do
        ownedSet[id] = true
    end

    local orderedOwned = {}
    for _, id in MortarPlacement.MORTAR_ORDER do
        if ownedSet[id] then
            table.insert(orderedOwned, id)
        end
    end

    local out: { [string]: Resolved } = {}
    local n = #orderedOwned
    for i, id in orderedOwned do
        local override = stored and stored[id]
        -- A stored record missing `mount` is LEGACY (pre-rail-mounts) and means floor-at-its-
        -- saved-spot -- never DEFAULT_MOUNT, which would relocate saved placements onto the
        -- rail now that the lever is pulled. DEFAULT_MOUNT applies only when there is no
        -- record at all.
        local mount = if override then (override.mount or "floor") else DEFAULT_MOUNT
        local aim = (override and override.aim) or "C"
        local x, z
        if mount == "rail" then
            if override then
                x = clamp(
                    override.offset[1],
                    deckBounds.minX + MortarPlacement.RAIL.newelMargin,
                    deckBounds.maxX - MortarPlacement.RAIL.newelMargin
                )
                z = deckBounds.minZ + MortarPlacement.RAIL.capWidth / 2
            else
                x, z = MortarPlacement.railDefault(deckBounds, i, n)
            end
        else
            if override then
                x, z = clampPoint(deckBounds, override.offset[1], override.offset[2])
            else
                x, z = clampPoint(deckBounds, defaultX(deckBounds, i, n), deckBounds.minZ + 1)
            end
            if teahouseFP then
                x, z = nudge(deckBounds, x, z, teahouseFP)
            end
        end
        out[id] = { mount = mount, x = x, z = z, aim = aim }
    end
    return out
end

-- The tube's deck-local unit axis for a mount/aim pair: elevation tilts it off vertical (+Y),
-- aim yaws it left/right/center. Always unit length (sin/cos of one angle, rotated by a unit
-- XZ direction).
function MortarPlacement.axisLocal(mount: string, aim: string): (number, number, number)
    local el = math.rad(MortarPlacement.ELEVATION[mount])
    local dir = AIM_DIR[aim]
    local ax, az = dir[1], dir[2]
    return math.sin(el) * ax, math.cos(el), math.sin(el) * az
end

-- World mount point and world unit axis for a resolved mortar: the mount local point is
-- (resolved.x, mountY, resolved.z) with mountY = 0 for a floor mortar or RAIL.capTop for a
-- rail mortar (the rail's cap-rail top surface); both the point and the axis are transformed
-- through the SAME 12-number row-major deck row `muzzleWorld` used (PadSites.deckPlacements
-- convention: position then 3x3 rotation, world = pos + R * local, R's rows
-- {r[4],r[5],r[6]; r[7],r[8],r[9]; r[10],r[11],r[12]}) -- the point gets the translation, the
-- axis (a direction, not a point) gets only R * axis.
function MortarPlacement.pose(
    deckRow: { number },
    resolved: Resolved,
    _mortarId: string
): (number, number, number, number, number, number)
    local mountY = resolved.mount == "rail" and MortarPlacement.RAIL.capTop or 0
    local lx, ly, lz = resolved.x, mountY, resolved.z
    local ax, ay, az = MortarPlacement.axisLocal(resolved.mount, resolved.aim)

    local px, py, pz = deckRow[1], deckRow[2], deckRow[3]
    local r1, r2, r3 = deckRow[4], deckRow[5], deckRow[6]
    local r4, r5, r6 = deckRow[7], deckRow[8], deckRow[9]
    local r7, r8, r9 = deckRow[10], deckRow[11], deckRow[12]

    local mx = px + r1 * lx + r2 * ly + r3 * lz
    local my = py + r4 * lx + r5 * ly + r6 * lz
    local mz = pz + r7 * lx + r8 * ly + r9 * lz

    local axx = r1 * ax + r2 * ay + r3 * az
    local axy = r4 * ax + r5 * ay + r6 * az
    local axz = r7 * ax + r8 * ay + r9 * az

    return mx, my, mz, axx, axy, axz
end

-- World muzzle origin and heading for a resolved mortar: the origin sits up the tube's world
-- axis from the mount point by BASE_OFFSET[mount] (base/saddle block) plus the tube's own
-- length -- render AND trajectory read these same six numbers. Replaces `muzzleWorld`.
function MortarPlacement.launch(
    deckRow: { number },
    resolved: Resolved,
    mortarId: string
): (number, number, number, number, number, number)
    local tube = MortarPlacement.TUBE[mortarId]
    if tube == nil then
        error(`MortarPlacement.launch: unknown mortar id '{mortarId}'`)
    end
    local mx, my, mz, hx, hy, hz = MortarPlacement.pose(deckRow, resolved, mortarId)
    local run = MortarPlacement.BASE_OFFSET[resolved.mount] + tube.length
    local ox = mx + hx * run
    local oy = my + hy * run
    local oz = mz + hz * run
    return ox, oy, oz, hx, hy, hz
end

return MortarPlacement
