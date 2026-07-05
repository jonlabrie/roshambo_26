--!strict
-- Curated component catalog for player structures. Pure data + an id resolver;
-- StructurePlanner reads this to turn loadout ids into concrete recolor/texture/
-- attachment operations. v1 carries one of each mechanism to prove the pipeline;
-- the real economy catalog (sub-project E) supersedes this. No Roblox datatypes.
local StructureCatalog = {}

export type Entry = {
    id: string,
    type: "recolor" | "texture" | "attachment",
    slot: string,
    payload: any,
}

local ENTRIES: { [string]: Entry } = {
    ["scheme.ink"] = {
        id = "scheme.ink", type = "recolor", slot = "colorScheme",
        payload = { timber = { 74, 55, 38 }, wall = { 120, 100, 74 }, roof = { 45, 48, 56 }, cap = { 45, 48, 56 } },
    },
    ["scheme.vermilion"] = {
        id = "scheme.vermilion", type = "recolor", slot = "colorScheme",
        payload = { timber = { 120, 45, 35 }, wall = { 232, 216, 190 }, roof = { 40, 42, 48 }, cap = { 40, 42, 48 } },
    },
    ["shoji.plain"] = { id = "shoji.plain", type = "texture", slot = "shoji", payload = { assetId = "rbxassetid://0" } },
    ["shoji.crane"] = { id = "shoji.crane", type = "texture", slot = "shoji", payload = { assetId = "rbxassetid://102000000001" } },
    ["tatami.green"] = { id = "tatami.green", type = "texture", slot = "tatami", payload = { assetId = "rbxassetid://102000000010" } },
    ["tatami.gold"] = { id = "tatami.gold", type = "texture", slot = "tatami", payload = { assetId = "rbxassetid://102000000011" } },
    ["flag.clan"] = { id = "flag.clan", type = "attachment", slot = "flags", payload = { prefabId = "flag_clan" } },
    ["flag.noren"] = { id = "flag.noren", type = "attachment", slot = "flags", payload = { prefabId = "flag_noren" } },
}

function StructureCatalog.get(id: string): Entry?
    return ENTRIES[id]
end

return StructureCatalog
