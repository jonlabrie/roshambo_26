--!strict
-- The canyon's UNTOUCHABLE places: where no scatter may ever put a plant.
--
-- Not a foliage-specific idea, which is why it lives here rather than inside one
-- builder. The moss scatter needed it first (90 clumps had landed on the Square's raked
-- sand and 30 inside the karesansui), but the floor re-plant, the water-margin palette
-- and anything else that scatters must consult the same list, or every new scatter
-- re-litigates which ground is sacred.
--
-- TWO KINDS OF KEEP-OUT, and the distinction is the useful part:
--
--   MATERIAL -- "never on raked sand". Exact, self-maintaining, and immune to shape:
--     the Square's sand is not a rectangle, so a bounding box round it would exclude
--     real planting ground at the corners (measured extent x -78..75 by z -37..53,
--     843 cells, plainly not a filled rect). Prefer this whenever the untouchable
--     thing IS a material.
--   VOLUME -- for places whose ground material is ordinary but whose CONTENT is not.
--     The karesansui's raked field is the case in point: gravel there is the artwork.
--
-- Pure: no Roblox API, so Lune tests it and Studio scripts mirror it. Materials are
-- NAMES, not Enums, for the same reason -- the Studio side maps them.

local CanyonKeepOuts = {}

-- Terrain materials that are themselves untouchable, by name.
CanyonKeepOuts.MATERIALS = {
    "Sand", -- the Square's raked karesansui sand + the arena floor
}

export type Zone = {
    name: string,
    -- axis-aligned box in world XZ; y is ignored (a scatter seats on the ground under
    -- the point, so a 2D footprint is the honest shape for "do not plant here")
    x0: number,
    x1: number,
    z0: number,
    z1: number,
    why: string,
}

CanyonKeepOuts.ZONES = {
    {
        -- RoshamboStage.Karesansui measures x -21..34 by z -12..18. The margin keeps a
        -- clump's SPREAD off the raked field, not merely its pivot: the biggest scatter
        -- meshes run ~3.8 studs across, so 4 studs of margin covers a clump seated
        -- right on the boundary.
        name = "Karesansui",
        x0 = -25,
        x1 = 38,
        z0 = -16,
        z1 = 22,
        why = "the raked gravel field is the artwork",
    },
} :: { Zone }

function CanyonKeepOuts.materialBlocked(materialName: string?): boolean
    if materialName == nil then
        return false
    end
    for _, m in CanyonKeepOuts.MATERIALS do
        if m == materialName then
            return true
        end
    end
    return false
end

-- Which zone, if any, contains this point. Returns the zone so callers can report WHY
-- something was refused rather than silently dropping it.
function CanyonKeepOuts.zoneAt(x: number, z: number): Zone?
    for _, zn in CanyonKeepOuts.ZONES do
        if x >= zn.x0 and x <= zn.x1 and z >= zn.z0 and z <= zn.z1 then
            return zn
        end
    end
    return nil
end

-- The single question a scatter asks. `materialName` is the terrain material under the
-- point, or nil if unknown/not sampled.
function CanyonKeepOuts.blocks(x: number, z: number, materialName: string?): (boolean, string?)
    if CanyonKeepOuts.materialBlocked(materialName) then
        return true, ("material %s is untouchable"):format(materialName :: string)
    end
    local zn = CanyonKeepOuts.zoneAt(x, z)
    if zn then
        return true, ("%s: %s"):format(zn.name, zn.why)
    end
    return false, nil
end

function CanyonKeepOuts.validate(): (boolean, { string })
    local errs: { string } = {}
    local seen: { [string]: boolean } = {}
    for _, zn in CanyonKeepOuts.ZONES do
        if seen[zn.name] then
            table.insert(errs, ("duplicate zone name %q"):format(zn.name))
        end
        seen[zn.name] = true
        if zn.x1 <= zn.x0 then
            table.insert(errs, ("%s: x1 must exceed x0"):format(zn.name))
        end
        if zn.z1 <= zn.z0 then
            table.insert(errs, ("%s: z1 must exceed z0"):format(zn.name))
        end
        if zn.why == "" then
            table.insert(
                errs,
                ("%s: needs a reason -- an unexplained keep-out gets deleted later"):format(zn.name)
            )
        end
    end
    if #CanyonKeepOuts.MATERIALS == 0 and #CanyonKeepOuts.ZONES == 0 then
        table.insert(errs, "no keep-outs at all -- the module would be a no-op")
    end
    return #errs == 0, errs
end

return CanyonKeepOuts
