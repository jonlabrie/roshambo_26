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

describe("LedgerModel.shares", function()
    -- Task 9: the ledger's LAST ROUND band apportions the server's crowd-split `distribution`
    -- with this SAME exported function rather than a second copy, so it can never disagree with
    -- the win-rate bar on a tie.
    test("is exported so a second caller can reuse it", function()
        expect(type(LedgerModel.shares)).toBe("function")
    end)

    test("a 1/1/1 split sums to exactly 100, not 99", function()
        -- The case naive independent rounding gets wrong: 1/3 -> 33.33... rounds to 33 for each
        -- of three categories, summing to 99. Largest-remainder hands the leftover unit to the
        -- first tied category instead.
        local out = LedgerModel.shares({ 1, 1, 1 })
        expect(out[1] + out[2] + out[3]).toBe(100)
        expect(out[1]).toBe(34)
        expect(out[2]).toBe(33)
        expect(out[3]).toBe(33)
    end)

    test("re-apportions an already-rounded (server) triple that itself sums to 99", function()
        -- The wire shape this function actually receives: RevealResult's `distribution` is the
        -- server's OWN Math.round-per-category percentages (buildDistribution in
        -- server/src/engine/Settlement.ts), which for a 1-1-1 vote split arrives as {33,33,33} --
        -- already off by one. Feeding that back through `shares` must still land on exactly 100.
        local out = LedgerModel.shares({ 33, 33, 33 })
        expect(out[1] + out[2] + out[3]).toBe(100)
        expect(out[1]).toBe(34)
        expect(out[2]).toBe(33)
        expect(out[3]).toBe(33)
    end)

    test("an all-zero split (nobody threw) returns all zeros, not NaN", function()
        local out = LedgerModel.shares({ 0, 0, 0 })
        expect(out[1]).toBe(0)
        expect(out[2]).toBe(0)
        expect(out[3]).toBe(0)
    end)
end)
