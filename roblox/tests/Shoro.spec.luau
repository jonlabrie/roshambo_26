--!strict
local harness = require("./harness")
local Shoro = require("../tools/builders/Shoro")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Shoro builder", function()
    test("four posts at the postSpacing corner radius (yaw-invariant)", function()
        -- The pavilion is yawed (pavilion.yaw) to clear the gantry, so a post's
        -- individual x/z are rotated — but its distance from the origin is the
        -- corner radius (postSpacing/2 along each axis) and stays fixed under yaw.
        local spec = Shoro.build(ZenDojo.palette, L)
        local s = L.pavilion.postSpacing / 2
        local cornerR = math.sqrt(s * s + s * s)
        local posts = 0
        for _, c in spec.children :: any do
            if c.name:match("^Post%d$") then
                posts += 1
                local x, z = c.properties.CFrame[1], c.properties.CFrame[3]
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
