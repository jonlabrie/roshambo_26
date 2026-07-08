--!strict
-- The single definition of teahouse size classes for sub-project D. Pure data +
-- footprint helpers (Lune-tested). `scale` is a TESTING PROXY on the one prefab
-- (applied via Model:ScaleTo); the destination is authored per-size prefabs, at
-- which point scale -> 1 and each size's stored loadout points at its authored
-- baseStyle, with NO change here. Footprints are PLOT sizes (site/spacing/clearing),
-- not the building itself. S = today's teahouse (base footprint); M = 1.3x, L = 1.6x
-- (chosen 2026-07-08 to sit right against the canyon scale; was 1.5/2.0 = too big).

local SizeClasses = {}

export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }

SizeClasses.BASE_FOOTPRINT = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 } :: Footprint
SizeClasses.order = { "L", "M", "S" } -- largest first
SizeClasses.scale = { S = 1.0, M = 1.3, L = 1.6 } :: { [string]: number }
SizeClasses.rank = { S = 1, M = 2, L = 3 } :: { [string]: number }

function SizeClasses.fitsWithin(size: string, maxSize: string): boolean
    return SizeClasses.rank[size] <= SizeClasses.rank[maxSize]
end

function SizeClasses.footprintFor(sizeClass: string): Footprint
    local s = SizeClasses.scale[sizeClass]
    local b = SizeClasses.BASE_FOOTPRINT
    return { minX = b.minX * s, maxX = b.maxX * s, minZ = b.minZ * s, maxZ = b.maxZ * s }
end

return SizeClasses
