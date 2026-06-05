--!strict
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local harness = require("./harness")
local GameRules = require("../src/shared/GameRules")
local describe, test, expect = harness.describe, harness.test, harness.expect

local fixtures = serde.decode("json", fs.readFile("../shared-fixtures/game-rules.json"))

describe("GameRules (shared fixtures)", function()
    for _, row in fixtures.matchups do
        test(`{row.player} vs world {row.world} -> {row.result}`, function()
            expect(GameRules.calculateResult(row.player, row.world)).toBe(row.result)
        end)
    end

    for _, row in fixtures.potProgression do
        test(`pot {row.currentPot} + {row.result} -> pot {row.nextPot}, delta {row.delta}`, function()
            expect(GameRules.nextPot(row.currentPot, row.result)).toBe(row.nextPot)
            expect(GameRules.potDelta(row.currentPot, row.result)).toBe(row.delta)
        end)
    end

    for _, row in fixtures.streakRules do
        test(`streak {row.currentStreak} + {row.result} -> {row.nextStreak}`, function()
            expect(GameRules.nextStreak(row.currentStreak, row.result)).toBe(row.nextStreak)
        end)
    end
end)
