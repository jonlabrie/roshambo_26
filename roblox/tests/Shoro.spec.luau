--!strict
local harness = require("./harness")
local Shoro = require("../tools/builders/Shoro")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Shoro builder", function()
    test("four posts at the postSpacing corner radius (yaw-invariant)", function()
        -- The pavilion is yawed (pavilion.yaw) and sits at pavilion.pos, so a post's
        -- individual x/z are rotated and translated — but its distance from the
        -- pavilion CENTRE is the corner radius (postSpacing/2 each axis), fixed under yaw.
        local spec = Shoro.build(ZenDojo.palette, L)
        local s = L.pavilion.postSpacing / 2
        local cornerR = math.sqrt(s * s + s * s)
        local cx, cz = L.pavilion.pos[1], L.pavilion.pos[3]
        local posts = 0
        for _, c in spec.children :: any do
            if c.name:match("^Post%d$") then
                posts += 1
                local x, z = c.properties.CFrame[1] - cx, c.properties.CFrame[3] - cz
                expect(math.sqrt(x * x + z * z)).toBeCloseTo(cornerR)
            end
        end
        expect(posts).toBe(4)
    end)
    test("beam carries the bell: beam present above bell crown", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "BellBeam" then
                found = true
                expect(c.properties.CFrame[2] > L.bell.pos[2] + L.bell.height / 2).toBe(true)
            end
        end
        expect(found).toBe(true)
    end)
end)

describe("Shoro art pass", function()
    test("posts wear the weathered cypress variant", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Post%d$") then
                expect(c.properties.MaterialVariant).toBe("CypressWeathered")
            end
        end
    end)
    test("emits a stepped tokyō bracket stack over each of the 4 posts", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local n = 0
        for _, c in spec.children :: any do
            if c.name:match("^Bracket%d+_%d+$") then
                n += 1
            end
        end
        expect(n >= 8).toBe(true) -- >= 2 courses per post
    end)
    test("emits the procedural hip roof: 8 face wedges, 4 hip stringers, a rafter fan", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local faces, stringers, rafters = 0, 0, 0
        for _, c in spec.children :: any do
            if c.name:match("^RoofFace%d_%d$") then
                faces += 1
                expect(c.className).toBe("WedgePart")
                expect(c.properties.MaterialVariant).toBe("SlateTile")
            end
            if c.name:match("^HipStringer%d$") then
                stringers += 1
            end
            if c.name:match("^Rafter%d+$") then
                rafters += 1
            end
        end
        expect(faces).toBe(8) -- 4 triangular faces × 2 wedges
        expect(stringers).toBe(4)
        expect(rafters >= 40).toBe(true)
        -- the old flat wedges / finial are gone
        for _, c in spec.children :: any do
            expect(c.name:match("^RoofWedge%d$")).toBeNil()
        end
    end)
end)
