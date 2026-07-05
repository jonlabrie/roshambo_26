--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local Catalog = require("../src/shared/StructureCatalog")
local Planner = require("../src/shared/StructurePlanner")

local function baseMount(): any
    return { cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, hand = "right", footprint = { x = 26, z = 20 } }
end

test("recolors: emits one entry per manifest role present in the palette", function()
    local manifest = { roles = { "timber", "roof", "cap" }, shojiBays = {}, hasTatami = false, flagMounts = {} }
    local plan = Planner.plan({ baseStyle = "teahouse-1story", colorScheme = "scheme.ink" }, baseMount(), manifest, Catalog)
    expect(plan.recolors).toEqual({
        { role = "timber", color = { 74, 55, 38 } },
        { role = "roof", color = { 45, 48, 56 } },
        { role = "cap", color = { 45, 48, 56 } },
    })
end)

test("recolors: empty when no colorScheme in loadout", function()
    local manifest = { roles = { "timber" }, shojiBays = {}, hasTatami = false, flagMounts = {} }
    local plan = Planner.plan({ baseStyle = "teahouse-1story" }, baseMount(), manifest, Catalog)
    expect(plan.recolors).toEqual({})
end)

test("textures: per-bay shoji prints + tatami, only for bays the manifest exposes", function()
    local manifest = { roles = {}, shojiBays = { 1, 2, 3 }, hasTatami = true, flagMounts = {} }
    local loadout = { baseStyle = "teahouse-1story", shoji = { [1] = "shoji.crane", [3] = "shoji.plain" }, tatami = "tatami.gold" }
    local plan = Planner.plan(loadout, baseMount(), manifest, Catalog)
    expect(plan.textures).toEqual({
        { target = "ShojiBay:1", assetId = "rbxassetid://102000000001" },
        { target = "ShojiBay:3", assetId = "rbxassetid://0" },
        { target = "Tatami", assetId = "rbxassetid://102000000011" },
    })
end)

test("textures: tatami skipped when the base has no tatami surface", function()
    local manifest = { roles = {}, shojiBays = {}, hasTatami = false, flagMounts = {} }
    local plan = Planner.plan({ baseStyle = "teahouse-1story", tatami = "tatami.gold" }, baseMount(), manifest, Catalog)
    expect(plan.textures).toEqual({})
end)

test("attachments: flags map to their mount; unknown mounts are skipped", function()
    local manifest = { roles = {}, shojiBays = {}, hasTatami = false, flagMounts = { "FlagMount_1", "FlagMount_2" } }
    local loadout = {
        baseStyle = "teahouse-1story",
        flags = { { mount = "FlagMount_1", item = "flag.clan" }, { mount = "FlagMount_9", item = "flag.noren" } },
    }
    local plan = Planner.plan(loadout, baseMount(), manifest, Catalog)
    expect(plan.attachments).toEqual({ { mount = "FlagMount_1", prefabId = "flag_clan" } })
end)
