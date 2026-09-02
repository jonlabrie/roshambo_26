--!strict
-- Pure decision module for deck mortars (deck-mortars feature, 2026-09-04): players own
-- mortars (mortar:S/M/L) that render on their teahouse deck at front-edge defaults, movable
-- via stored placements. This module makes ALL placement decisions (defaults, stored
-- overrides, clamping, teahouse-overlap nudge) plus the muzzle world-position math; runtime
-- files only call it. Consumes nothing -- bounds are passed in. Lune-tested; no Roblox
-- datatypes.
--
-- Front edge = local maxZ: deck rows are view-oriented, and the canyon-facing side is +Z in
-- deck-local space -- the same convention DecorationLayout/BuildingPlacer use for "front".
--
-- Clamp philosophy mirrors DecorationLayout/BuildingPlacer: a STORED placement is never
-- mutated, only what resolve() returns adapts.
local MortarPlacement = {}

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Placement = { x: number, z: number, facing: string }
export type StoredPlacement = { offset: { number }, facing: string }
export type Tube = { bore: number, length: number }

-- ⚠ Mirrors MORTAR_IDS in server/src/fireworks.ts (Object.keys(MORTAR_PRICES)) -- both are the
-- shop's gear ladder S -> M -> L; if one adds/reorders a tier without the other, defaults drift.
MortarPlacement.MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }

-- ⚠ Mirrors REQUIREMENTS in server/src/fireworks.ts (the `.mortar` field of each shell's
-- requirement) -- the client is never told a shell's requirement (server/src/fireworks.ts:
-- "The client is told PRICES, never requirements"), so the Studio server can't fetch this from
-- the backend and instead carries its own minimal copy. If TS adds/changes a gear requirement
-- without a matching edit here, the Studio server will happily let a shell fire from the
-- player's eye level instead of its mortar's muzzle -- no test catches that drift (there is no
-- shared-fixtures file for this one, unlike MORTAR_ORDER/GameRules). Promoting a shell to
-- gear-required (or changing its tier) touches BOTH tables.
MortarPlacement.SHELL_MORTAR = {
    peony = "mortar:S",
    willow = "mortar:M",
    kiku = "mortar:S",
} :: { [string]: string }

-- Proving-range proportions (1 stud = 1 ft): bore is tube inner diameter, length is tube length.
MortarPlacement.TUBE = {
    ["mortar:S"] = { bore = 1 / 6, length = 0.85 },
    ["mortar:M"] = { bore = 1 / 3, length = 1.5 },
    ["mortar:L"] = { bore = 0.5, length = 2.5 },
} :: { [string]: Tube }

-- Timber base height the render task sits every mortar tube on top of.
local BASE_TOP = 0.5

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
    local frontZ = bounds.maxZ - 1
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

-- Resolves every OWNED mortar's deck-local placement: defaults for anything not in `stored`,
-- stored overrides (clamped) otherwise, then a teahouse nudge if `teahouseFP` is given.
-- Unknown/unowned ids in `stored` are ignored; every owned id always gets a row.
function MortarPlacement.resolve(
    deckBounds: Bounds,
    owned: { string },
    stored: { [string]: StoredPlacement }?,
    teahouseFP: Bounds?
): { [string]: Placement }
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

    local out: { [string]: Placement } = {}
    local n = #orderedOwned
    for i, id in orderedOwned do
        local x, z, facing
        local override = stored and stored[id]
        if override then
            x, z = clampPoint(deckBounds, override.offset[1], override.offset[2])
            facing = override.facing
        else
            x, z = clampPoint(deckBounds, defaultX(deckBounds, i, n), deckBounds.maxZ - 1)
            facing = "N"
        end
        if teahouseFP then
            x, z = nudge(deckBounds, x, z, teahouseFP)
        end
        out[id] = { x = x, z = z, facing = facing }
    end
    return out
end

-- World x,y,z of a mortar tube's muzzle: transforms the deck-local point
-- (placement.x, BASE_TOP + tube.length, placement.z) through the 12-number row-major deck
-- CFrame (PadSites.deckPlacements convention: position then 3x3 rotation), world = pos + R *
-- local, with R's rows {r[4],r[5],r[6]; r[7],r[8],r[9]; r[10],r[11],r[12]} -- matching how
-- Spec.cframe lays out model.json CFrames.
function MortarPlacement.muzzleWorld(
    deckRow: { number },
    placement: Placement,
    mortarId: string
): (number, number, number)
    local tube = MortarPlacement.TUBE[mortarId]
    if tube == nil then
        error(`MortarPlacement.muzzleWorld: unknown mortar id '{mortarId}'`)
    end
    local lx, ly, lz = placement.x, BASE_TOP + tube.length, placement.z
    local px, py, pz = deckRow[1], deckRow[2], deckRow[3]
    local r1, r2, r3 = deckRow[4], deckRow[5], deckRow[6]
    local r4, r5, r6 = deckRow[7], deckRow[8], deckRow[9]
    local r7, r8, r9 = deckRow[10], deckRow[11], deckRow[12]
    local wx = px + r1 * lx + r2 * ly + r3 * lz
    local wy = py + r4 * lx + r5 * ly + r6 * lz
    local wz = pz + r7 * lx + r8 * ly + r9 * lz
    return wx, wy, wz
end

return MortarPlacement
