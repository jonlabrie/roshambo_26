--!strict
-- Pure planner for the structure builder. Turns a player loadout + a pad mount +
-- the base prefab's slot manifest into a concrete Plan of Instance operations.
-- No Roblox datatypes (Lune-tested); CFrames are 12-number arrays like Spec.cframe.
local StructurePlanner = {}

export type Color = { number }
export type Loadout = {
    baseStyle: string,
    colorScheme: string?,
    shoji: { [number]: string }?,
    tatami: string?,
    flags: { { mount: string, item: string } }?,
}
export type Mount = { cframe: { number }, hand: string, footprint: { x: number, z: number } }
export type Manifest = { roles: { string }, shojiBays: { number }, hasTatami: boolean, flagMounts: { string } }
export type Recolor = { role: string, color: Color }
export type Texture = { target: string, assetId: string }
export type Attachment = { mount: string, prefabId: string }
export type Plan = {
    recolors: { Recolor },
    textures: { Texture },
    attachments: { Attachment },
    mirror: boolean,
    pivotCF: { number },
}

type Catalog = { get: (string) -> any }

local function resolveRecolors(loadout: Loadout, manifest: Manifest, catalog: Catalog): { Recolor }
    local out: { Recolor } = {}
    if not loadout.colorScheme then
        return out
    end
    local entry = catalog.get(loadout.colorScheme)
    if not entry or entry.type ~= "recolor" then
        return out
    end
    for _, role in manifest.roles do
        local color = entry.payload[role]
        if color then
            table.insert(out, { role = role, color = color })
        end
    end
    return out
end

function StructurePlanner.plan(loadout: Loadout, mount: Mount, manifest: Manifest, catalog: Catalog): Plan
    return {
        recolors = resolveRecolors(loadout, manifest, catalog),
        textures = {},
        attachments = {},
        mirror = false,
        pivotCF = mount.cframe,
    }
end

return StructurePlanner
