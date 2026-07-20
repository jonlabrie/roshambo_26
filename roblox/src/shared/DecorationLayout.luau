--!strict
-- Pure decoration render resolver (2026-07-19 deck-decoration framework). Given the deck bounds,
-- the built teahouse's deck-local AABB (nil for a bare deck), and the stored decoration list,
-- returns per-prop render data: each clamped onto the deck, and marked invisible when it would sit
-- under the built teahouse. Mirrors B3's display-clamp philosophy — the STORED placement is never
-- changed; only what renders adapts. Lune-tested; no Roblox datatypes.
local BuildingPlacer = require("./BuildingPlacer")
local DecorationCatalog = require("./DecorationCatalog")

local DecorationLayout = {}

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }

-- AABB overlap with edge-touch treated as NON-overlap (strict inequalities): a prop whose footprint
-- merely touches the teahouse edge stays visible.
local function overlaps(a: Bounds, b: Bounds): boolean
    return a.minX < b.maxX and a.maxX > b.minX and a.minZ < b.maxZ and a.maxZ > b.minZ
end

function DecorationLayout.resolve(deckFP: Bounds, teahouseFP: Bounds?, decorations: { any }): { any }
    local out = {}
    for _, d in decorations do
        local fp = DecorationCatalog.footprint(d.propId)
        if fp == nil then
            continue -- unknown propId (shouldn't survive validation): skip, never crash
        end
        local clamped = BuildingPlacer.clamp(fp, deckFP, { offset = d.offset, facing = d.facing })
        local bounds = BuildingPlacer.footprintBounds(fp, clamped)
        local visible = true
        if teahouseFP ~= nil and overlaps(bounds, teahouseFP) then
            visible = false
        end
        table.insert(out, {
            id = d.id,
            propId = d.propId,
            offset = clamped.offset,
            facing = clamped.facing,
            visible = visible,
        })
    end
    return out
end

return DecorationLayout
