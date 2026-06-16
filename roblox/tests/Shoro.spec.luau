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
