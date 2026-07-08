--!strict
local harness = require("./harness")
local StagePersistence = require("../src/shared/StagePersistence")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- Minimal Instance mocks: only GetChildren + IsA are exercised by persistTargets.
local function model(name: string)
    return {
        Name = name,
        IsA = function(_self: any, c: string): boolean
            return c == "Model"
        end,
    }
end
local function part(name: string)
    return {
        Name = name,
        IsA = function(_self: any, c: string): boolean
            return c == "BasePart" or c == "Part"
        end,
    }
end
local function root(children: { any })
    return {
        GetChildren = function(_self: any): { any }
            return children
        end,
    }
end
local function names(list: { any }): { string }
    local n = {}
    for _, m in list do
        table.insert(n, m.Name)
    end
    return n
end

describe("StagePersistence.persistTargets", function()
    test("collects direct-child Models and skips non-Models", function()
        local r = root({ model("A"), part("B"), model("C") })
        expect(names(StagePersistence.persistTargets({ r :: any }))).toEqual({ "A", "C" })
    end)
    test("flattens Models across multiple roots in order", function()
        local r1 = root({ model("A") })
        local r2 = root({ model("C"), model("D") })
        expect(names(StagePersistence.persistTargets({ r1 :: any, r2 :: any }))).toEqual({ "A", "C", "D" })
    end)
    test("empty roots list yields empty result", function()
        expect(StagePersistence.persistTargets({})).toEqual({})
    end)
    test("a root with no Models yields nothing", function()
        local r = root({ part("B") })
        expect(StagePersistence.persistTargets({ r :: any })).toEqual({})
    end)
end)
