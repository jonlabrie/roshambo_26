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
