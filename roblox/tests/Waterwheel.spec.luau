--!strict
local harness = require("./harness")
local Waterwheel = require("../tools/builders/Waterwheel")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Waterwheel cluster builder", function()
    test("one Wheel part per layout center, at that center", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local wheels = 0
        for _, c in spec.children :: any do
            local i = c.name:match("^Wheel(%d+)$")
            if i then
                wheels += 1
                local ctr = L.waterwheel.centers[tonumber(i) :: number]
                expect(c.properties.CFrame[1]).toBe(ctr[1])
                expect(c.properties.CFrame[3]).toBe(ctr[3])
            end
        end
        expect(wheels).toBe(#L.waterwheel.centers)
    end)
    test("eight paddles ring every wheel", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local counts: { [string]: number } = {}
        for _, c in spec.children :: any do
            local w = c.name:match("^Paddle(%d+)_%d+$")
            if w then
                counts[w] = (counts[w] or 0) + 1
            end
        end
        for i = 1, #L.waterwheel.centers do
            expect(counts[tostring(i)]).toBe(8)
        end
    end)
    test("the driver carries the RatchetDrum", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "RatchetDrum" then
                found = true
            end
        end
        expect(found).toBe(true)
    end)
end)

describe("Waterwheel (overshot)", function()
    test("emits a Headrace flume part feeding the wheel top", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Headrace"]).toBe(true)
        expect(names["Wheel1"]).toBe(true)
    end)
    test("support posts reach the clearing floor, not a submerged bed", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Support") then
                local cy = c.properties.CFrame[2]
                local h = c.properties.Size[2]
                expect(cy - h / 2 <= L.waterwheel.bedY + 1).toBe(true)
            end
        end
    end)
end)
