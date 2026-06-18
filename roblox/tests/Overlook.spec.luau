--!strict
local harness = require("./harness")
local Overlook = require("../tools/builders/Overlook")
local ArenaLayout = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local model = Overlook.build(ZenDojo.palette, ArenaLayout)

local function find(node, name)
    for _, c in node.children do
        if c.name == name then
            return c
        end
    end
    return nil
end
local function countPrefix(node, prefix)
    local n = 0
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then
            n += 1
        end
    end
    return n
end

describe("Overlook", function()
    test("builds both deck slabs", function()
        expect(find(model, "UpperDeck") ~= nil).toBe(true)
        expect(find(model, "LowerDeck") ~= nil).toBe(true)
    end)
    test("each deck stands on kake-zukuri posts", function()
        expect(countPrefix(model, "Post") >= 6).toBe(true) -- >=3 posts per deck
    end)
    test("has a bamboo rail and a connecting stair", function()
        expect(countPrefix(model, "Rail") >= 1).toBe(true)
        expect(countPrefix(model, "Step") >= 2).toBe(true)
    end)
    test("carries warm lanterns (hero chochin + rail ishidoro)", function()
        expect(find(model, "Chochin") ~= nil).toBe(true)
        expect(countPrefix(model, "Ishidoro") >= 1).toBe(true)
    end)
    test("the upper deck slab is placed above the lower deck slab", function()
        local upperY = find(model, "UpperDeck").properties.CFrame[2]
        local lowerY = find(model, "LowerDeck").properties.CFrame[2]
        expect(upperY > lowerY).toBe(true)
    end)
end)
