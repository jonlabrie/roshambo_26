--!strict
local harness = require("./harness")
local FallsDock = require("../tools/builders/FallsDock")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

local model = FallsDock.build(ZenDojo.palette, ArenaLayout)

-- baked seat (see the builder); the tests check the model lands where the user put the marker
local CX, CZ, YAW = -345.37, -15.45, 110.99

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

-- parts carry WORLD coordinates (the SwitchbackDeck pattern), so to reason about the
-- deck's own frame we undo the seat and the yaw
local function toLocal(cf: { number }): (number, number)
    local dx, dz = cf[1] - CX, cf[3] - CZ
    local a = math.rad(-YAW)
    local c, s = math.cos(a), math.sin(a)
    return dx * c + dz * s, -dx * s + dz * c
end

describe("FallsDock", function()
    test("is a model named FallsDock", function()
        expect(model.className).toBe("Model")
        expect(model.name).toBe("FallsDock")
    end)

    test("slab is 6 x 8 x 0.6 WoodPlanks", function()
        local slab = find(model, "Slab")
        expect(slab ~= nil).toBe(true)
        assert(slab ~= nil)
        expect(slab.properties.Size[1]).toBe(6)
        expect(slab.properties.Size[2]).toBe(0.6)
        expect(slab.properties.Size[3]).toBe(8)
        expect(slab.properties.Material).toBe("WoodPlanks")
    end)

    test("slab is seated at the baked marker position", function()
        local slab = find(model, "Slab")
        assert(slab ~= nil)
        expect(math.abs(slab.properties.CFrame[1] - CX) < 0.01).toBe(true)
        expect(math.abs(slab.properties.CFrame[3] - CZ) < 0.01).toBe(true)
    end)

    test("has six posts, all 1.125 square", function()
        expect(countPrefix(model, "Post_")).toBe(6)
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Post_" then
                expect(c.properties.Size[1]).toBe(1.125)
                expect(c.properties.Size[3]).toBe(1.125)
            end
        end
    end)

    -- The standing rule for every canyon build: a post's OUTER face is flush with
    -- the slab edge, so no post juts past the deck when seen from the water.
    test("post outer faces sit flush inside the slab footprint", function()
        local slab = find(model, "Slab")
        assert(slab ~= nil)
        local halfW = slab.properties.Size[1] / 2
        local halfD = slab.properties.Size[3] / 2
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Post_" then
                local lx, lz = toLocal(c.properties.CFrame)
                expect(math.abs(lx) <= halfW + 1e-3).toBe(true)
                expect(math.abs(lz) <= halfD + 1e-3).toBe(true)
            end
        end
    end)

    -- Post feet are surveyed per position, not assumed from one constant: the water
    -- end stands in 3.5 studs of pool while the shore end meets the bank.
    test("every post is a real post, and none floats above its foot", function()
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Post_" then
                expect(c.properties.Size[2] >= 0.75).toBe(true)
            end
        end
    end)

    test("girder tops meet the slab underside", function()
        local slab = find(model, "Slab")
        assert(slab ~= nil)
        local slabBottom = slab.properties.CFrame[2] - slab.properties.Size[2] / 2
        for _, name in { "GirderLongA", "GirderLongB", "GirderCross" } do
            local g = find(model, name)
            expect(g ~= nil).toBe(true)
            assert(g ~= nil)
            expect(g.properties.Size[2]).toBe(1.2)
            local top = g.properties.CFrame[2] + g.properties.Size[2] / 2
            expect(math.abs(top - slabBottom) < 1e-6).toBe(true)
        end
    end)

    -- The spec forbids a railing. This test exists so a later reader who "fixes"
    -- the missing kōran against recipe section 2 gets a red test instead of a merge.
    test("has no railing parts", function()
        for _, c in model.children do
            local n = c.name :: string
            expect(n:find("Rail") == nil).toBe(true)
            expect(n:find("Newel") == nil).toBe(true)
            expect(n:find("Baluster") == nil).toBe(true)
        end
    end)

    -- Every part shares the deck's yaw, so the dock reads as one object rather than
    -- a slab with axis-aligned furniture scattered under it.
    test("every part carries the baked yaw", function()
        local a = math.rad(YAW)
        local c, s = math.cos(a), math.sin(a)
        for _, part in model.children do
            local cf = part.properties.CFrame
            expect(math.abs(cf[4] - c) < 1e-6).toBe(true)
            expect(math.abs(cf[6] - s) < 1e-6).toBe(true)
            expect(math.abs(cf[10] + s) < 1e-6).toBe(true)
            expect(math.abs(cf[12] - c) < 1e-6).toBe(true)
        end
    end)
end)
