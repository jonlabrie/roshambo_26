--!strict
-- The single definition of teahouse size classes for sub-project D. Pure data +
-- footprint helpers (Lune-tested). `scale` is a TESTING PROXY on the one prefab
-- (applied via Model:ScaleTo); the destination is authored per-size prefabs, at
-- which point scale -> 1 and each size's stored loadout points at its authored
-- baseStyle, with NO change here. Footprints are PLOT sizes (site/spacing/clearing),
-- not the building itself. S = today's teahouse (base footprint); M and L target 1.3x and
-- 1.6x the SQUARE FOOTAGE of S -- so the LINEAR scale is sqrt(1.3)/sqrt(1.6), NOT 1.3/1.6
-- per dimension (applying them linearly bloated L to 1.6*1.6 = 2.56x area). Area factors
-- chosen 2026-07-08 to sit right against the canyon scale.
-- INTENT: the shipping M and L are AUTHORED per-size prefabs, not a scaled S. The `scale`
-- below is a TESTING PROXY on the single S prefab only, retired when the authored prefabs
-- land (at which point scale -> 1 and each size points at its own baseStyle).

local SizeClasses = {}

export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }

SizeClasses.BASE_FOOTPRINT = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 } :: Footprint
SizeClasses.order = { "L", "M", "S" } -- largest first
-- `area` is the design intent: target square footage relative to S.
SizeClasses.area = { S = 1.0, M = 1.3, L = 1.6 } :: { [string]: number }
-- `scale` is the LINEAR factor applied to the prefab (Model:ScaleTo) and to footprintFor:
-- sqrt(area), so the AREA scales by `area` while each dimension scales by its square root.
SizeClasses.scale = { S = 1.0, M = math.sqrt(1.3), L = math.sqrt(1.6) } :: { [string]: number }
SizeClasses.rank = { S = 1, M = 2, L = 3 } :: { [string]: number }

function SizeClasses.fitsWithin(size: string, maxSize: string): boolean
    return SizeClasses.rank[size] <= SizeClasses.rank[maxSize]
end

function SizeClasses.footprintFor(sizeClass: string): Footprint
    local s = SizeClasses.scale[sizeClass]
    local b = SizeClasses.BASE_FOOTPRINT
    return { minX = b.minX * s, maxX = b.maxX * s, minZ = b.minZ * s, maxZ = b.maxZ * s }
end

-- The DECK/pad extent (symmetric, centered on the mount) — distinct from the legacy
-- post-only BASE_FOOTPRINT. S = 26 x 20. Scales each side by sqrt(area) via `scale`.
SizeClasses.DECK_BASE = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } :: Footprint

function SizeClasses.deckFootprint(deckSize: string): Footprint
    local s = SizeClasses.scale[deckSize]
    local b = SizeClasses.DECK_BASE
    return { minX = b.minX * s, maxX = b.maxX * s, minZ = b.minZ * s, maxZ = b.maxZ * s }
end

-- the lower-ranked of two sizes (S < M < L)
function SizeClasses.minSize(a: string, b: string): string
    return if SizeClasses.rank[a] <= SizeClasses.rank[b] then a else b
end

-- next tier up: nil -> "S", S -> "M", M -> "L", L -> nil
function SizeClasses.nextTier(size: string?): string?
    if size == nil then
        return "S"
    elseif size == "S" then
        return "M"
    elseif size == "M" then
        return "L"
    end
    return nil
end

-- what materializes at a perch: deck capped by the perch, teahouse = biggest owned capped by
-- the deck (nil = bare deck). Returns nil when the player owns no deck (not an owner).
function SizeClasses.resolveBuilt(
    maxDeckSize: string?,
    teahouseSizes: { string },
    perchMax: string,
    deckDisplay: string?,
    teahouseDisplay: string?
): { deckSize: string, teahouseSize: string? }?
    if maxDeckSize == nil then
        return nil
    end
    -- deck: owned max, capped by the perch, then by the display (clamp only ever shrinks)
    local deckSize = SizeClasses.minSize(maxDeckSize, perchMax)
    if deckDisplay ~= nil then
        deckSize = SizeClasses.minSize(deckSize, deckDisplay)
    end
    -- teahouse: 'none' display = bare deck
    if teahouseDisplay == "none" then
        return { deckSize = deckSize, teahouseSize = nil }
    end
    local maxTea: string? = nil
    for _, s in teahouseSizes do
        if maxTea == nil or SizeClasses.rank[s] > SizeClasses.rank[maxTea] then
            maxTea = s
        end
    end
    if maxTea == nil then
        return { deckSize = deckSize, teahouseSize = nil }
    end
    local teahouseSize = maxTea
    if teahouseDisplay ~= nil then
        teahouseSize = SizeClasses.minSize(teahouseSize, teahouseDisplay)
    end
    teahouseSize = SizeClasses.minSize(teahouseSize, deckSize) -- teahouse <= (displayed) deck
    return { deckSize = deckSize, teahouseSize = teahouseSize }
end

-- the per-size prefab name for a style: "teahouse-1story" + "M" -> "teahouse-1story-m".
-- baseStyle stays the STYLE; size picks the authored prefab (scaling retired).
function SizeClasses.prefabName(baseStyle: string, size: string): string
    return `{baseStyle}-{string.lower(size)}`
end

-- per-size WALL footprint (symmetric, centred), MEASURED from the authored S/M/L prefabs' Solid
-- wall panels (outer faces; roof eaves overhang the deck and are excluded). Retires the scaled
-- BUILDING_BASE: sizes are now distinct authored buildings (S 2x1 12.4x6.4, M 3x2 18.4x12.4,
-- L 4x3 24.4x18.4). Used for the non-fatal deck fit-check.
local BUILDING_HALF = { S = { 6.2, 3.2 }, M = { 9.2, 6.2 }, L = { 12.2, 9.2 } } :: { [string]: { number } }
function SizeClasses.buildingFootprint(size: string): Footprint
    local h = BUILDING_HALF[size]
    return { minX = -h[1], maxX = h[1], minZ = -h[2], maxZ = h[2] }
end

return SizeClasses
