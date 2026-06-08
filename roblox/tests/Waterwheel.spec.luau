--!strict
local harness = require("./harness")
local Waterwheel = require("../tools/builders/Waterwheel")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Waterwheel builder", function()
    test("has the spinning Wheel part centered at layout wheelPos", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "Wheel" then
                found = true
                expect(c.properties.CFrame[1]).toBe(L.flume.wheelPos[1])
                expect(c.properties.Size[2]).toBe(2 * L.flume.wheelRadius)
            end
        end
        expect(found).toBe(true)
    end)
    test("eight paddles ring the wheel", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local paddles = 0
        for _, c in spec.children :: any do
            if c.name:match("^Paddle%d$") then
                paddles += 1
            end
        end
        expect(paddles).toBe(8)
    end)
end)
