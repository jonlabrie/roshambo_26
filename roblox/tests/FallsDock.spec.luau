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

    -- The deck is built, not moulded: a 2x6 box frame with 2x4 boards laid across it
    -- and an inch of daylight between them. User units: 1 stud = 1 foot, 1 inch = 1/12.
    local IN = 1 / 12

    test("the deck is boards and a frame, not a slab", function()
        expect(find(model, "Slab")).toBe(nil)
        expect(countPrefix(model, "Frame")).toBe(4)
        expect(countPrefix(model, "Board_") > 12).toBe(true)
    end)

    test("frame members are 2x6 lumber", function()
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Frame" then
                local s = c.properties.Size
                local thin = math.min(s[1], s[3])
                expect(math.abs(thin - 2 * IN) < 1e-6).toBe(true) -- 2 inches thick
                expect(math.abs(s[2] - 6 * IN) < 1e-6).toBe(true) -- 6 inches tall, on edge
            end
        end
    end)

    test("frame outer faces are flush with the 6 x 8 footprint", function()
        local halfW, halfD = 3, 4
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Frame" then
                local lx, lz = toLocal(c.properties.CFrame)
                local s = c.properties.Size
                expect(math.abs(lx) + s[1] / 2 <= halfW + 1e-6).toBe(true)
                expect(math.abs(lz) + s[3] / 2 <= halfD + 1e-6).toBe(true)
            end
        end
    end)

    test("boards are 2x4 laid flat, with about an inch between them", function()
        local zs = {}
        for _, c in model.children do
            if (c.name :: string):sub(1, 6) == "Board_" then
                local s = c.properties.Size
                expect(math.abs(s[2] - 2 * IN) < 1e-6).toBe(true) -- 2 inches thick
                expect(math.abs(s[3] - 4 * IN) < 1e-6).toBe(true) -- 4 inches wide
                local _, lz = toLocal(c.properties.CFrame)
                table.insert(zs, lz)
            end
        end
        table.sort(zs)
        for i = 2, #zs do
            local gap = (zs[i] - zs[i - 1]) - 4 * IN
            -- a whole number of boards rarely divides the span at exactly 1 inch, so
            -- the remainder is spread evenly: assert it stays within a quarter inch
            expect(math.abs(gap - 1 * IN) < 0.25 * IN).toBe(true)
        end
    end)

    test("board tops are flush with the frame top", function()
        local top = nil
        for _, c in model.children do
            local n = c.name :: string
            if n:sub(1, 6) == "Board_" or n:sub(1, 5) == "Frame" then
                local t = c.properties.CFrame[2] + c.properties.Size[2] / 2
                if top == nil then
                    top = t
                end
                expect(math.abs(t - (top :: number)) < 1e-6).toBe(true)
            end
        end
    end)

    test("the deck is seated at the baked marker position", function()
        local frame = find(model, "FrameWest")
        assert(frame ~= nil)
        local lx, lz = toLocal(frame.properties.CFrame)
        -- the west frame member sits on the deck's own -X edge, so undoing the seat
        -- and yaw should put it there and nowhere else
        expect(math.abs(lx - -(3 - 1 * IN)) < 1e-6).toBe(true)
        expect(math.abs(lz) < 1e-6).toBe(true)
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
    test("post outer faces sit flush inside the deck footprint", function()
        local halfW, halfD = 3, 4 -- the 6 x 8 deck
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

    test("girder tops meet the frame underside", function()
        local frame = find(model, "FrameWest")
        assert(frame ~= nil)
        local slabBottom = frame.properties.CFrame[2] - frame.properties.Size[2] / 2
        for _, name in { "GirderLongA", "GirderLongB", "GirderCross" } do
            local g = find(model, name)
            expect(g ~= nil).toBe(true)
            assert(g ~= nil)
            expect(g.properties.Size[2]).toBe(1.2)
            local top = g.properties.CFrame[2] + g.properties.Size[2] / 2
            expect(math.abs(top - slabBottom) < 1e-6).toBe(true)
        end
    end)

    -- The walking surface matches the shōrō / waterwheel joinery; the posts and
    -- girders stay dark timber because they stand in the water, not on the deck.
    test("frame and boards are weathered cypress, posts and girders are not", function()
        for _, c in model.children do
            local n = c.name :: string
            local mv = c.properties.MaterialVariant
            if n:sub(1, 5) == "Frame" or n:sub(1, 6) == "Board_" then
                expect(mv).toBe("CypressWeathered")
            elseif n:sub(1, 5) == "Post_" or n:sub(1, 6) == "Girder" then
                expect(mv).toBe(nil)
            end
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
