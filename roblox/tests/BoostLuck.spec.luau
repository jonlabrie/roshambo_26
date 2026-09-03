--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local BoostLuck = require("../src/shared/BoostLuck")

describe("BoostLuck — the pity ramp", function()
    test("the base chance is the floor: zero misses rolls the recipe's own odds", function()
        expect(BoostLuck.chanceFor(0.3, 0)).toBe(0.3)
    end)

    test("each miss adds PITY_STEP x base: 0.3 walks 0.45, 0.6, 0.75, 0.9, 1", function()
        local function near(got: number, want: number)
            expect(math.abs(got - want) < 1e-9).toBe(true)
        end
        near(BoostLuck.chanceFor(0.3, 1), 0.45)
        near(BoostLuck.chanceFor(0.3, 2), 0.6)
        near(BoostLuck.chanceFor(0.3, 3), 0.75)
        near(BoostLuck.chanceFor(0.3, 4), 0.9)
    end)

    test("the ramp caps at certainty -- a drought cannot outlast the ramp", function()
        expect(BoostLuck.chanceFor(0.3, 5)).toBe(1)
        expect(BoostLuck.chanceFor(0.3, 50)).toBe(1)
        -- at the cap, ANY roll below 1 hits
        local boosted = BoostLuck.roll(0.3, 5, 0.999)
        expect(boosted).toBe(true)
    end)

    test("a hit resets the streak; a miss extends it", function()
        local boosted, misses = BoostLuck.roll(0.3, 4, 0.05) -- hits
        expect(boosted).toBe(true)
        expect(misses).toBe(0)
        boosted, misses = BoostLuck.roll(0.3, 1, 0.5) -- 0.5 >= 0.45: miss
        expect(boosted).toBe(false)
        expect(misses).toBe(2)
    end)

    test("chance = 1 recipes always hit, misses stay 0", function()
        local boosted, misses = BoostLuck.roll(1, 0, 0.999)
        expect(boosted).toBe(true)
        expect(misses).toBe(0)
    end)

    test("baseChance finds the first boost-carrying phase; nil when a recipe has none", function()
        local recipe = {
            phases = {
                { at = 0, kind = "report", anchor = "origin" },
                { at = 3, kind = "burst", anchor = "apex", boost = { chance = 0.3 } },
            },
        }
        expect(BoostLuck.baseChance(recipe)).toBe(0.3)
        expect(BoostLuck.baseChance({ phases = { { at = 0, kind = "report", anchor = "origin" } } })).toBe(
            nil
        )
    end)
end)
