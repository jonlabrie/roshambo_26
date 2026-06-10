--!strict
local harness = require("./harness")
local Teahouse = require("../tools/builders/Teahouse")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Teahouse village", function()
    test("7 huts on tier 1, 9 on tier 2, 15 on tier 3 (none on the shrine level)", function()
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
        expect(t1).toBe(7)
        expect(t2).toBe(9)
        expect(t3).toBe(15)
    end)

    test("no hut sits directly above/below one on an adjacent tier", function()
        local spec = Teahouse.build(ZenDojo.palette, L)
        local byTier = { {}, {}, {} }
        for _, house in spec.children :: any do
            local ti = tonumber(house.name:match("^Teahouse_(%d)_"))
            local floor
            for _, p in house.children do
                if p.name == "Floor" then
                    floor = p
                end
            end
            local x, z = floor.properties.CFrame[1], floor.properties.CFrame[3]
            table.insert(byTier[ti], math.atan2(z, x))
        end
        for ti = 1, 2 do
            for _, a in byTier[ti] do
                for _, b in byTier[ti + 1] do
                    local d = math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
                    expect(d > 0.12).toBe(true)
                end
            end
        end
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

    test("every hut on tiers 1 & 2 has an engawa, two posts and a bridge deck", function()
        local spec = Teahouse.build(ZenDojo.palette, L)
        for _, house in spec.children :: any do
            local ti = tonumber(house.name:match("^Teahouse_(%d)_"))
            if ti == 1 or ti == 2 then
                local have = {}
                for _, p in house.children do
                    have[p.name] = true
                end
                expect(have["Engawa"]).toBe(true)
                expect(have["EngawaPostL"]).toBe(true)
                expect(have["EngawaPostR"]).toBe(true)
                expect(have["DeckBR"]).toBe(true) -- bridge deck, tag "BR"
            end
        end
    end)

    test("tier 3 huts are dry — no engawa", function()
        local spec = Teahouse.build(ZenDojo.palette, L)
        for _, house in spec.children :: any do
            if house.name:match("^Teahouse_3_") then
                for _, p in house.children do
                    expect(p.name ~= "Engawa").toBe(true)
                end
            end
        end
    end)
end)
