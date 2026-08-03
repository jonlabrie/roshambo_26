--!strict
local harness = require("./harness")
local GameRules = require("../src/shared/GameRules")
local PlayerProfiles = require("../src/shared/PlayerProfiles")
local describe, test, expect = harness.describe, harness.test, harness.expect

local SERVER_ROW = {
    totalPoints = 5,
    pointsAtStake = 9,
    currentStreak = 2,
    stakingStreak = 2,
    bestStreak = 4,
    unresolvedWin = false,
}

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
            unresolvedWin = true,
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
            unresolvedWin = false,
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
            unresolvedWin = false,
        })
    end)

    test("bestStreak rises with a new local high; unknown user is a no-op", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", {
            totalPoints = 0,
            pointsAtStake = 0,
            currentStreak = 4,
            stakingStreak = 4,
            bestStreak = 4,
            unresolvedWin = false,
        })
        p:applyLocalResult("9", "WIN")
        expect(p:get("9").bestStreak).toBe(5)
        p:applyLocalResult("ghost", "WIN") -- must not error
        expect(p:get("ghost")).toBeNil()
    end)
end)

describe("PlayerProfiles — the win gate", function()
    test("applyServer carries unresolvedWin", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("u1", {
            totalPoints = 100,
            pointsAtStake = 27,
            currentStreak = 3,
            stakingStreak = 3,
            bestStreak = 6,
            unresolvedWin = true,
        })
        expect(p:get("u1").unresolvedWin).toBe(true)
    end)

    test("a local WIN raises the gate optimistically", function()
        -- the theater reveals before the server reconciles; the overlay must appear with the win
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("u1", {
            totalPoints = 100,
            pointsAtStake = 9,
            currentStreak = 1,
            stakingStreak = 1,
            bestStreak = 1,
            unresolvedWin = false,
        })
        p:applyLocalResult("u1", "WIN")
        expect(p:get("u1").unresolvedWin).toBe(true)
    end)

    test("a local LOSS clears it — nothing left to decide", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("u1", {
            totalPoints = 100,
            pointsAtStake = 9,
            currentStreak = 1,
            stakingStreak = 1,
            bestStreak = 1,
            unresolvedWin = true,
        })
        p:applyLocalResult("u1", "LOSS")
        expect(p:get("u1").unresolvedWin).toBe(false)
    end)

    test("a missing field defaults to unbound", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer(
            "u1",
            {
                totalPoints = 0,
                pointsAtStake = 0,
                currentStreak = 0,
                stakingStreak = 0,
                bestStreak = 0,
            } :: any
        )
        expect(p:get("u1").unresolvedWin).toBe(false)
    end)
end)
