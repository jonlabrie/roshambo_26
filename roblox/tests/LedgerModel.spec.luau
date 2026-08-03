--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local LedgerModel = require("../src/shared/LedgerModel")
local GameRules = require("../src/shared/GameRules")

local function counters(over: any): any
    local base = {
        roundsPlayed = 0,
        wins = 0,
        safes = 0,
        losses = 0,
        lifetimeBanked = 0,
        bestPot = 0,
        throwsR = 0,
        throwsP = 0,
        throwsS = 0,
    }
    for k, v in over or {} do
        base[k] = v
    end
    return base
end

describe("LedgerModel.view", function()
    test("pays-next comes from GameRules, not a hardcoded multiplier", function()
        -- if the pot progression ever changes, the ledger must change with it automatically
        local v = LedgerModel.view(counters({}), { pot = 27, streak = 3, points = 1240 }, GameRules)
        expect(v.paysNext).toBe(GameRules.nextPot(27, "WIN"))
    end)

    test("a zero pot still shows what a first win pays", function()
        local v = LedgerModel.view(counters({}), { pot = 0, streak = 0, points = 0 }, GameRules)
        expect(v.paysNext).toBe(GameRules.nextPot(0, "WIN"))
        expect(v.paysNext > 0).toBe(true)
    end)

    test("win rate is a whole percentage of rounds played", function()
        local v = LedgerModel.view(
            counters({ roundsPlayed = 386, wins = 131, safes = 92, losses = 163 }),
            { pot = 0, streak = 0, points = 0 },
            GameRules
        )
        expect(v.winRatePct).toBe(34)
    end)

    test("win rate NEVER disagrees with the bar's win segment", function()
        -- They are the same quantity. Computed separately, a three-way tie makes the headline
        -- read 33% while the bar segment reads 34% -- round-to-nearest says 33, largest-remainder
        -- hands the leftover unit to wins. A player looking at both sees a contradiction.
        local cases = {
            { roundsPlayed = 3, wins = 1, safes = 1, losses = 1 },
            { roundsPlayed = 300, wins = 100, safes = 100, losses = 100 },
            { roundsPlayed = 386, wins = 131, safes = 92, losses = 163 },
            { roundsPlayed = 7, wins = 2, safes = 2, losses = 3 },
            { roundsPlayed = 1, wins = 0, safes = 0, losses = 1 },
            { roundsPlayed = 9, wins = 3, safes = 3, losses = 3 },
        }
        for _, c in cases do
            local v = LedgerModel.view(counters(c), { pot = 0, streak = 0, points = 0 }, GameRules)
            expect(v.winRatePct).toBe(v.bar.win)
        end
    end)

    test("a player who has never thrown does not divide by zero", function()
        local v = LedgerModel.view(counters({}), { pot = 0, streak = 0, points = 0 }, GameRules)
        expect(v.winRatePct).toBe(0)
        expect(v.bar.win).toBe(0)
        expect(v.mix.R).toBe(0)
    end)

    test("the result bar always sums to exactly 100", function()
        -- three independently rounded percentages leave a gap in the bar; largest-remainder fixes it
        local cases = {
            { roundsPlayed = 3, wins = 1, safes = 1, losses = 1 },
            { roundsPlayed = 7, wins = 2, safes = 2, losses = 3 },
            { roundsPlayed = 386, wins = 131, safes = 92, losses = 163 },
            { roundsPlayed = 1, wins = 0, safes = 0, losses = 1 },
        }
        for _, c in cases do
            local v = LedgerModel.view(counters(c), { pot = 0, streak = 0, points = 0 }, GameRules)
            expect(v.bar.win + v.bar.safe + v.bar.loss).toBe(100)
        end
    end)

    test("the throw mix always sums to exactly 100", function()
        local v = LedgerModel.view(
            counters({ throwsR = 1, throwsP = 1, throwsS = 1 }),
            { pot = 0, streak = 0, points = 0 },
            GameRules
        )
        expect(v.mix.R + v.mix.P + v.mix.S).toBe(100)
    end)

    test("the mix is proportional and preserves order", function()
        local v = LedgerModel.view(
            counters({ throwsR = 181, throwsP = 120, throwsS = 85 }),
            { pot = 0, streak = 0, points = 0 },
            GameRules
        )
        expect(v.mix.R > v.mix.P).toBe(true)
        expect(v.mix.P > v.mix.S).toBe(true)
    end)

    test("live values pass through untouched", function()
        local v = LedgerModel.view(counters({}), { pot = 27, streak = 3, points = 1240 }, GameRules)
        expect(v.live.pot).toBe(27)
        expect(v.live.streak).toBe(3)
        expect(v.live.points).toBe(1240)
    end)
end)
