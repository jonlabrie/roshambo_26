--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local HudModel = require("../src/shared/HudModel")

local function inputs(over: any): any
    local base = {
        phase = "ACTIVE",
        secondsLeft = 20,
        pointsAtStake = 0,
        currentStreak = 0,
        totalPoints = 100,
        unresolvedWin = false,
        fateBound = false,
        pickedThisRound = false,
        escalationPrompts = true,
    }
    for k, v in over or {} do
        base[k] = v
    end
    return base
end

-- a session belonging to someone who has settled in: thrown before, but not last round
local function settled(): any
    return { hasThrownThisSession = true, threwLastRound = false, consecutiveMisses = 0 }
end

describe("HudModel.view — plate and throws", function()
    test("the plate always shows streak, pot and points", function()
        local v =
            HudModel.view(inputs({ currentStreak = 3, pointsAtStake = 27, totalPoints = 1240 }), settled())
        expect(v.plate.streak).toBe(3)
        expect(v.plate.pot).toBe(27)
        expect(v.plate.points).toBe(1240)
    end)

    test("throws are enabled in ACTIVE when unbound and unpicked", function()
        expect(HudModel.view(inputs({}), settled()).throwsEnabled).toBe(true)
    end)

    test("throws are disabled outside ACTIVE", function()
        for _, p in { "TALLY", "REVEAL" } do
            expect(HudModel.view(inputs({ phase = p }), settled()).throwsEnabled).toBe(false)
        end
    end)

    test("throws are disabled once the lockout has passed", function()
        expect(HudModel.view(inputs({ secondsLeft = 0 }), settled()).throwsEnabled).toBe(false)
    end)

    test("fate-bound and win-bound both disable throws", function()
        expect(HudModel.view(inputs({ fateBound = true }), settled()).throwsEnabled).toBe(false)
        expect(HudModel.view(inputs({ unresolvedWin = true }), settled()).throwsEnabled).toBe(false)
    end)
end)

describe("HudModel.view — the choice overlay", function()
    test("the overlay is up exactly when the player is win-bound", function()
        expect(HudModel.view(inputs({ unresolvedWin = true, pointsAtStake = 27 }), settled()).choiceUp).toBe(
            true
        )
        expect(HudModel.view(inputs({ unresolvedWin = false }), settled()).choiceUp).toBe(false)
    end)

    test("the overlay persists through every phase — it does not expire with the round", function()
        -- the owner's rule: no default and no expiry. They have a choice to make.
        for _, p in { "ACTIVE", "TALLY", "REVEAL" } do
            local v =
                HudModel.view(inputs({ phase = p, unresolvedWin = true, pointsAtStake = 27 }), settled())
            expect(v.choiceUp).toBe(true)
        end
    end)

    test("being fate-bound does not raise the win choice", function()
        expect(HudModel.view(inputs({ fateBound = true }), settled()).choiceUp).toBe(false)
    end)
end)

describe("HudModel.view — escalation arming", function()
    local NEW = { hasThrownThisSession = false, threwLastRound = false, consecutiveMisses = 0 }

    test("a brand-new arrival is armed", function()
        expect(HudModel.view(inputs({ secondsLeft = 4 }), NEW).escalate).toBe(true)
    end)

    test("someone who threw last round is armed", function()
        local s = { hasThrownThisSession = true, threwLastRound = true, consecutiveMisses = 0 }
        expect(HudModel.view(inputs({ secondsLeft = 4 }), s).escalate).toBe(true)
    end)

    test("a pot riding arms even after a quiet spell", function()
        expect(HudModel.view(inputs({ secondsLeft = 4, pointsAtStake = 27 }), settled()).escalate).toBe(true)
    end)

    test("a settled hanger-out with no pot is NOT armed", function()
        -- the whole point of the gate: never nag someone who is just here to hang out
        expect(HudModel.view(inputs({ secondsLeft = 4 }), settled()).escalate).toBe(false)
    end)

    test("it only fires inside the last 5 seconds", function()
        expect(HudModel.view(inputs({ secondsLeft = 6 }), NEW).escalate).toBe(false)
        expect(HudModel.view(inputs({ secondsLeft = 5 }), NEW).escalate).toBe(true)
    end)

    test("it never fires once a pick is in", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, pickedThisRound = true }), NEW).escalate).toBe(false)
    end)

    test("it never fires at a player who cannot throw", function()
        -- 'CHOOSE A THROW' is noise at someone the server will refuse
        expect(HudModel.view(inputs({ secondsLeft = 2, fateBound = true }), NEW).escalate).toBe(false)
        expect(HudModel.view(inputs({ secondsLeft = 2, unresolvedWin = true }), NEW).escalate).toBe(false)
    end)

    test("the preference switch silences it outright", function()
        local s = { hasThrownThisSession = true, threwLastRound = true, consecutiveMisses = 0 }
        expect(HudModel.view(inputs({ secondsLeft = 2, escalationPrompts = false }), s).escalate).toBe(false)
    end)

    test("three consecutive misses disarm it, even with a pot riding", function()
        local s = { hasThrownThisSession = true, threwLastRound = false, consecutiveMisses = 3 }
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 27 }), s).escalate).toBe(false)
    end)

    test("two misses is still armed — the backoff is at three", function()
        local s = { hasThrownThisSession = true, threwLastRound = false, consecutiveMisses = 2 }
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 27 }), s).escalate).toBe(true)
    end)
end)

describe("HudModel.onRoundEnded", function()
    test("a pick clears the misses and marks the session thrown", function()
        local s = HudModel.onRoundEnded(
            { hasThrownThisSession = false, threwLastRound = false, consecutiveMisses = 2 },
            { couldThrow = true, picked = true }
        )
        expect(s.hasThrownThisSession).toBe(true)
        expect(s.threwLastRound).toBe(true)
        expect(s.consecutiveMisses).toBe(0)
    end)

    test("an ignored round is a miss", function()
        local s = HudModel.onRoundEnded(settled(), { couldThrow = true, picked = false })
        expect(s.consecutiveMisses).toBe(1)
        expect(s.threwLastRound).toBe(false)
    end)

    test("a round the player COULD NOT throw in is not a miss", function()
        -- being win-bound or fate-bound is being prevented, not ignoring it; counting these
        -- would disarm the prompt for a player who was stuck deciding
        local before = { hasThrownThisSession = true, threwLastRound = true, consecutiveMisses = 0 }
        local s = HudModel.onRoundEnded(before, { couldThrow = false, picked = false })
        expect(s.consecutiveMisses).toBe(0)
        expect(s.threwLastRound).toBe(true)
    end)

    test("many bound rounds then a throw leaves the player armed", function()
        local s = { hasThrownThisSession = true, threwLastRound = true, consecutiveMisses = 0 }
        for _ = 1, 10 do
            s = HudModel.onRoundEnded(s, { couldThrow = false, picked = false })
        end
        expect(s.consecutiveMisses).toBe(0)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)

    test("misses accumulate then re-arm on the next throw", function()
        local s = settled()
        for _ = 1, 4 do
            s = HudModel.onRoundEnded(s, { couldThrow = true, picked = false })
        end
        expect(s.consecutiveMisses).toBe(4)
        s = HudModel.onRoundEnded(s, { couldThrow = true, picked = true })
        expect(s.consecutiveMisses).toBe(0)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)

    test("it does not mutate the session it is given", function()
        local before = settled()
        HudModel.onRoundEnded(before, { couldThrow = true, picked = false })
        expect(before.consecutiveMisses).toBe(0)
    end)
end)

describe("HudModel.newSession", function()
    test("a fresh session is a new arrival, and a new arrival is armed", function()
        local s = HudModel.newSession()
        expect(s.hasThrownThisSession).toBe(false)
        expect(s.consecutiveMisses).toBe(0)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)
end)
