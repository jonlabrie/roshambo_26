--!strict
local harness = require("./harness")
local GameRules = require("../src/shared/GameRules")
local PlayerProfiles = require("../src/shared/PlayerProfiles")
local describe, test, expect = harness.describe, harness.test, harness.expect

local SERVER_ROW =
    { totalPoints = 5, pointsAtStake = 9, currentStreak = 2, stakingStreak = 2, bestStreak = 4 }

describe("PlayerProfiles", function()
    test("applyServer stores and get returns the wallet", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        expect(p:get("9")).toEqual(SERVER_ROW)
        expect(p:get("nope")).toBeNil()
    end)

    test("local WIN grows the pot optimistically and bumps streaks", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        p:applyLocalResult("9", "WIN")
        expect(p:get("9")).toEqual({
            totalPoints = 5,
            pointsAtStake = 27,
            currentStreak = 3,
            stakingStreak = 3,
            bestStreak = 4,
        })
    end)

    test("local SAFE preserves pot, resets streaks", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        p:applyLocalResult("9", "SAFE")
        expect(p:get("9")).toEqual({
            totalPoints = 5,
            pointsAtStake = 9,
            currentStreak = 0,
            stakingStreak = 0,
            bestStreak = 4,
        })
    end)

    test("local LOSS forfeits pot, resets streaks", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        p:applyLocalResult("9", "LOSS")
        expect(p:get("9")).toEqual({
            totalPoints = 5,
            pointsAtStake = 0,
            currentStreak = 0,
            stakingStreak = 0,
            bestStreak = 4,
        })
    end)

    test("bestStreak rises with a new local high; unknown user is a no-op", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer(
            "9",
            { totalPoints = 0, pointsAtStake = 0, currentStreak = 4, stakingStreak = 4, bestStreak = 4 }
        )
        p:applyLocalResult("9", "WIN")
        expect(p:get("9").bestStreak).toBe(5)
        p:applyLocalResult("ghost", "WIN") -- must not error
        expect(p:get("ghost")).toBeNil()
    end)
end)
