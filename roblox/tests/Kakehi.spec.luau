--!strict
local harness = require("./harness")
local Kakehi = require("../tools/builders/Kakehi")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Kakehi builder", function()
    test("trough segments descend monotonically from pool to wheel", function()
        local spec = Kakehi.build(ZenDojo.palette, L)
        local ys = {}
        for _, c in spec.children :: any do
            local i = c.name:match("^Trough(%d)$")
            if i then
                ys[tonumber(i) :: number] = c.properties.CFrame[2]
            end
        end
        for i = 2, #ys do
            expect(ys[i] < ys[i - 1]).toBe(true)
        end
        expect(#ys >= 3).toBe(true)
    end)
    test("every trough segment clears the apron gravel (y > 2)", function()
        local spec = Kakehi.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Trough%d$") then
                expect(c.properties.CFrame[2] > 2).toBe(true)
            end
        end
    end)
    test("support posts land on integer ground (y base 0)", function()
        local spec = Kakehi.build(ZenDojo.palette, L)
        local posts = 0
        for _, c in spec.children :: any do
            if c.name:match("^FlumePost%d$") then
                posts += 1
                expect(math.abs(c.properties.CFrame[2] - c.properties.Size[2] / 2) < 0.01).toBe(true)
            end
        end
        expect(posts >= 2).toBe(true)
    end)
end)
