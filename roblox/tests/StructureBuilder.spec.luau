--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local Catalog = require("../src/shared/StructureCatalog")
local Builder = require("../src/shared/StructureBuilder")

local function fakeOps(log: { any })
    return {
        clonePrefab = function(style: string)
            table.insert(log, { op = "clone", style = style })
            return { tag = "MODEL" }
        end,
        readManifest = function(_m)
            return { roles = { "cap" }, shojiBays = { 1 }, hasTatami = false, flagMounts = { "FlagMount_1" } }
        end,
        mirrorX = function(_m)
            table.insert(log, { op = "mirror" })
        end,
        recolor = function(_m, role: string, _c)
            table.insert(log, { op = "recolor", role = role })
        end,
        setTexture = function(_m, target: string, _a)
            table.insert(log, { op = "texture", target = target })
        end,
        attachPrefab = function(_m, mount: string, _p)
            table.insert(log, { op = "attach", mount = mount })
        end,
        pivotTo = function(_m, _cf)
            table.insert(log, { op = "pivot" })
        end,
    }
end

test("build drives ops in order: clone, mirror(if openSide left), recolor, texture, attach, pivot", function()
    local log: { any } = {}
    local mount = {
        cframe = { 1, 2, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        openSide = "left",
        footprint = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 },
    }
    local loadout = {
        baseStyle = "teahouse-1story",
        colorScheme = "scheme.ink",
        shoji = { [1] = "shoji.crane" },
        flags = { { mount = "FlagMount_1", item = "flag.clan" } },
    }
    local model = Builder.build(loadout, mount, Catalog, fakeOps(log))
    expect((model :: any).tag).toBe("MODEL")
    expect(log).toEqual({
        { op = "clone", style = "teahouse-1story" },
        { op = "mirror" },
        { op = "recolor", role = "cap" },
        { op = "texture", target = "ShojiBay:1" },
        { op = "attach", mount = "FlagMount_1" },
        { op = "pivot" },
    })
end)

test("build skips mirror for a right (native) openSide mount", function()
    local log: { any } = {}
    local mount = {
        cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        openSide = "right",
        footprint = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 },
    }
    Builder.build({ baseStyle = "teahouse-1story" }, mount, Catalog, fakeOps(log))
    expect(log).toEqual({ { op = "clone", style = "teahouse-1story" }, { op = "pivot" } })
end)
