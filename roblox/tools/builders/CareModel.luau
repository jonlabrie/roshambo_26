--!strict
-- The care model (spec 2026-07-29-canyon-garden-floor-design): how far human
-- tending reaches from paths and staged sites, as a distance in STUDS. Pure.
local CareModel = {}

CareModel.GARDEN_FRACTION = 0.35

function CareModel.reach(x: number): number
    return math.clamp(8 + 20 * (x + 430) / 470, 8, 28)
end

function CareModel.band(x: number, distToCare: number): string
    local r = CareModel.reach(x)
    if distToCare <= CareModel.GARDEN_FRACTION * r then
        return "GARDEN"
    elseif distToCare <= r then
        return "TENDED"
    end
    return "PRESERVE"
end

return CareModel
