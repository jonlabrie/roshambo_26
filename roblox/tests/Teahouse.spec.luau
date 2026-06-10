--!strict
local harness = require("./harness")
local Teahouse = require("../tools/builders/Teahouse")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Teahouse village", function()
    test("6 huts on the middle terrace, 12 on the top, none on the lowest", function()
        local spec = Teahouse.build(ZenDojo.palette, L)
        local t1, t2, t3 = 0, 0, 0
        for _, c in spec.children :: any do
            if c.name:match("^Teahouse_1_") then
                t1 += 1
            elseif c.name:match("^Teahouse_2_") then
                t2 += 1
            elseif c.name:match("^Teahouse_3_") then
                t3 += 1
            end
        end
        expect(t1).toBe(0)
        expect(t2).toBe(6)
        expect(t3).toBe(12)
    end)

    test("every hut's porch faces the centre (closer to origin than its floor)", function()
        local spec = Teahouse.build(ZenDojo.palette, L)
        for _, house in spec.children :: any do
            local floor, porch
            for _, p in house.children do
                if p.name == "Floor" then
                    floor = p
                elseif p.name == "Porch" then
                    porch = p
                end
            end
            expect(floor ~= nil and porch ~= nil).toBe(true)
            local fx, fz = floor.properties.CFrame[1], floor.properties.CFrame[3]
            local px, pz = porch.properties.CFrame[1], porch.properties.CFrame[3]
            expect(px ^ 2 + pz ^ 2 < fx ^ 2 + fz ^ 2).toBe(true)
        end
    end)
end)
