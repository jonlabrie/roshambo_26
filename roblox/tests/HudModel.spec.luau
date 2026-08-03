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
        confirmThrows = true,
        selectedThrow = nil,
    }
    for k, v in over or {} do
        base[k] = v
    end
    return base
end

local function session(misses: number): any
    return { consecutiveMisses = misses }
end

describe("HudModel.view — plate and throws", function()
    test("the plate always shows streak, pot and points", function()
        local v =
            HudModel.view(inputs({ currentStreak = 3, pointsAtStake = 27, totalPoints = 1240 }), session(0))
        expect(v.plate.streak).toBe(3)
        expect(v.plate.pot).toBe(27)
        expect(v.plate.points).toBe(1240)
    end)

    test("throws are enabled in ACTIVE when unbound and unpicked", function()
        expect(HudModel.view(inputs({}), session(0)).throwsEnabled).toBe(true)
    end)

    test("throws are disabled outside ACTIVE", function()
        for _, p in { "TALLY", "REVEAL" } do
            expect(HudModel.view(inputs({ phase = p }), session(0)).throwsEnabled).toBe(false)
        end
    end)

    test("throws are disabled once the lockout has passed", function()
        expect(HudModel.view(inputs({ secondsLeft = 0 }), session(0)).throwsEnabled).toBe(false)
    end)

    test("throws are disabled once a pick is in", function()
        expect(HudModel.view(inputs({ pickedThisRound = true }), session(0)).throwsEnabled).toBe(false)
    end)

    test("a win no longer blocks throwing — riding IS throwing again", function()
        local v = HudModel.view(inputs({ unresolvedWin = true, pointsAtStake = 27 }), session(0))
        expect(v.throwsEnabled).toBe(true)
    end)

    test("a fate still blocks throwing", function()
        expect(HudModel.view(inputs({ fateBound = true }), session(0)).throwsEnabled).toBe(false)
    end)
end)

describe("HudModel.view — the slot above the throw row", function()
    test("the slot holds the pot whenever points are unbanked", function()
        local v = HudModel.view(inputs({ pointsAtStake = 27 }), session(0))
        expect(v.slot).toBe("pot")
    end)

    test("the slot holds the fate prompt when fate-bound", function()
        expect(HudModel.view(inputs({ fateBound = true }), session(0)).slot).toBe("fate")
    end)

    test("the slot is empty with no pot and no fate", function()
        expect(HudModel.view(inputs({}), session(0)).slot).toBe("none")
    end)

    test("fate wins the slot if both are somehow set", function()
        -- a LOSS forfeits the pot, so this should be unreachable; assert the defensive order
        -- rather than trusting it, because the wrong tenant here hides the only way out of a fate
        local v = HudModel.view(inputs({ fateBound = true, pointsAtStake = 27 }), session(0))
        expect(v.slot).toBe("fate")
    end)

    test("the pot survives every phase — an unbanked pot does not expire with the round", function()
        for _, p in { "ACTIVE", "TALLY", "REVEAL" } do
            expect(HudModel.view(inputs({ phase = p, pointsAtStake = 27 }), session(0)).slot).toBe("pot")
        end
    end)

    test("the pot pulses only while the win is unacknowledged", function()
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = true }), session(0)).potPulses).toBe(
            true
        )
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = false }), session(0)).potPulses).toBe(
            false
        )
    end)

    test("nothing pulses when there is no pot", function()
        expect(HudModel.view(inputs({ pointsAtStake = 0, unresolvedWin = true }), session(0)).potPulses).toBe(
            false
        )
    end)
end)

describe("HudModel.view — escalation", function()
    test("a player with no misses is armed", function()
        expect(HudModel.view(inputs({ secondsLeft = 4 }), session(0)).escalate).toBe(true)
    end)

    test("it only fires inside the last 5 seconds", function()
        expect(HudModel.view(inputs({ secondsLeft = 6 }), session(0)).escalate).toBe(false)
        expect(HudModel.view(inputs({ secondsLeft = 5 }), session(0)).escalate).toBe(true)
    end)

    test("it never fires once a pick is in", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, pickedThisRound = true }), session(0)).escalate).toBe(
            false
        )
    end)

    test("it never fires at a player who cannot throw", function()
        -- "CHOOSE A THROW" is noise at someone the server will refuse
        expect(HudModel.view(inputs({ secondsLeft = 2, fateBound = true }), session(0)).escalate).toBe(false)
    end)

    test("an unacknowledged win does not silence the escalation", function()
        -- it used to: unresolvedWin was part of `bound`, and bound players were never armed
        expect(
            HudModel.view(inputs({ secondsLeft = 3, unresolvedWin = true, pointsAtStake = 9 }), session(0)).escalate
        ).toBe(true)
    end)

    test("the preference switch silences it outright", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, escalationPrompts = false }), session(0)).escalate).toBe(
            false
        )
    end)

    test("three consecutive misses disarm it, even with a pot riding", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 27 }), session(3)).escalate).toBe(
            false
        )
    end)

    test("two misses is still armed — the backoff is at three", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 27 }), session(2)).escalate).toBe(true)
    end)

    test("the backoff is UNIFORM — a pot riding buys no extra grace", function()
        -- the arm reasons describe who STARTS armed; they are not ongoing conditions
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 0 }), session(2)).escalate).toBe(true)
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 99 }), session(3)).escalate).toBe(
            false
        )
    end)
end)

describe("HudModel — the one-miss regression", function()
    test("a player who threw, won nothing, and missed ONE round is still armed", function()
        -- The first draft armed on (new arrival OR threw-last-round OR pot riding), so this
        -- player — pot 0, has thrown before, did not throw last round — fell out of the OR and
        -- went silent after a SINGLE miss. The most common case got the least grace. The
        -- backoff must be what silences the prompt, not an arm condition evaporating.
        local s = HudModel.onRoundEnded(HudModel.newSession(), { couldThrow = true, picked = true })
        s = HudModel.onRoundEnded(s, { couldThrow = true, picked = false })
        expect(s.consecutiveMisses).toBe(1)
        expect(HudModel.view(inputs({ secondsLeft = 3, pointsAtStake = 0 }), s).escalate).toBe(true)
    end)

    test("that same player is still armed after a SECOND miss, and silent after the third", function()
        local s = HudModel.onRoundEnded(HudModel.newSession(), { couldThrow = true, picked = true })
        for _ = 1, 2 do
            s = HudModel.onRoundEnded(s, { couldThrow = true, picked = false })
        end
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
        s = HudModel.onRoundEnded(s, { couldThrow = true, picked = false })
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(false)
    end)
end)

describe("HudModel.onRoundEnded", function()
    test("a pick clears the misses", function()
        expect(HudModel.onRoundEnded(session(2), { couldThrow = true, picked = true }).consecutiveMisses).toBe(
            0
        )
    end)

    test("an ignored round is a miss", function()
        expect(HudModel.onRoundEnded(session(0), { couldThrow = true, picked = false }).consecutiveMisses).toBe(
            1
        )
    end)

    test("a round the player COULD NOT throw in is not a miss", function()
        -- being fate-bound is being prevented, not ignoring it; counting these would disarm the
        -- prompt for a player who was held out of the round
        expect(HudModel.onRoundEnded(session(0), { couldThrow = false, picked = false }).consecutiveMisses).toBe(
            0
        )
    end)

    test("many bound rounds then a throw leaves the player armed", function()
        local s = session(0)
        for _ = 1, 10 do
            s = HudModel.onRoundEnded(s, { couldThrow = false, picked = false })
        end
        expect(s.consecutiveMisses).toBe(0)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)

    test("misses accumulate past the cap, then one throw re-arms", function()
        local s = session(0)
        for _ = 1, 5 do
            s = HudModel.onRoundEnded(s, { couldThrow = true, picked = false })
        end
        expect(s.consecutiveMisses).toBe(5)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(false)
        s = HudModel.onRoundEnded(s, { couldThrow = true, picked = true })
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)

    test("it does not mutate the session it is given", function()
        local before = session(0)
        HudModel.onRoundEnded(before, { couldThrow = true, picked = false })
        expect(before.consecutiveMisses).toBe(0)
    end)
end)

-- ===== Confirming a throw when points are riding =====
-- The rule, in the owner's words: "especially if there's points riding on the throw, it makes sense
-- to ask players to confirm a throw choice". Read as: the confirmation exists ONLY when there is a
-- pot. With nothing at stake one tap throws and the ambient case stays calm — an arena where every
-- casual throw costs two taps would be a worse hangout, and the mis-tap it guards against only costs
-- something when there is something to lose.
describe("HudModel.tapAction — one tap, or two", function()
    test("no pot: one tap throws", function()
        expect(HudModel.tapAction(inputs({ pointsAtStake = 0 }), "R")).toBe("commit")
    end)

    test("a pot riding: the first tap only selects", function()
        expect(HudModel.tapAction(inputs({ pointsAtStake = 27 }), "R")).toBe("select")
    end)

    test("a second tap on the SAME glyph commits", function()
        expect(HudModel.tapAction(inputs({ pointsAtStake = 27, selectedThrow = "R" }), "R")).toBe("commit")
    end)

    test("a tap on a DIFFERENT glyph moves the selection, it does not commit", function()
        expect(HudModel.tapAction(inputs({ pointsAtStake = 27, selectedThrow = "R" }), "P")).toBe("select")
    end)

    test("the preference off: one tap throws however big the pot is", function()
        local i = inputs({ pointsAtStake = 243, confirmThrows = false })
        expect(HudModel.tapAction(i, "R")).toBe("commit")
    end)

    test("a tap that could never be thrown is ignored, not selected", function()
        -- leaving a selection lit on a round the player is locked out of would be a lie about what
        -- is about to happen
        for _, over in
            {
                { phase = "TALLY" },
                { secondsLeft = 0 },
                { fateBound = true },
                { pickedThisRound = true },
            }
        do
            local i = inputs(over)
            i.pointsAtStake = 27
            expect(HudModel.tapAction(i, "R")).toBe("ignore")
        end
    end)
end)

describe("HudModel.autoCommit — a missed second tap must never cost a round", function()
    test("nothing selected, nothing to commit", function()
        expect(HudModel.autoCommit(inputs({ pointsAtStake = 27, secondsLeft = 0 }))).toBe(nil)
    end)

    test("it holds while there is still time to tap again", function()
        expect(HudModel.autoCommit(inputs({ pointsAtStake = 27, selectedThrow = "S", secondsLeft = 3 }))).toBe(
            nil
        )
    end)

    test("the boundary: it fires as the lockout arrives, not after it", function()
        -- committing AT zero is too late — the pick has to reach the server before the lockout, so
        -- the model hands it over with a sliver of the countdown still to run
        local justBefore = inputs({ pointsAtStake = 27, selectedThrow = "S", secondsLeft = 0.6 })
        expect(HudModel.autoCommit(justBefore)).toBe(nil)
        local atLockout = inputs({ pointsAtStake = 27, selectedThrow = "S", secondsLeft = 0.5 })
        expect(HudModel.autoCommit(atLockout)).toBe("S")
    end)

    test("a round that ended without a countdown still commits the selection", function()
        -- the unsynced-clock path reports a constant nominal countdown that never reaches the
        -- boundary above; the phase leaving ACTIVE is the last chance to throw what was tapped
        local i = inputs({ pointsAtStake = 27, selectedThrow = "P", phase = "TALLY", secondsLeft = 30 })
        expect(HudModel.autoCommit(i)).toBe("P")
    end)

    test("a pick already in is never re-committed", function()
        local i = inputs({
            pointsAtStake = 27,
            selectedThrow = "P",
            pickedThisRound = true,
            secondsLeft = 0.2,
        })
        expect(HudModel.autoCommit(i)).toBe(nil)
    end)

    test("a fate arriving mid-round drops the selection rather than throwing it", function()
        local i = inputs({ pointsAtStake = 27, selectedThrow = "P", fateBound = true, secondsLeft = 0.2 })
        expect(HudModel.autoCommit(i)).toBe(nil)
    end)

    test("banking mid-round does not strand the selection", function()
        -- the pot is gone, so confirmation is no longer REQUIRED — but a glyph the player tapped is
        -- still a glyph they meant to throw, and dropping it silently would cost them the round
        local i = inputs({ pointsAtStake = 0, selectedThrow = "R", secondsLeft = 0.2 })
        expect(HudModel.autoCommit(i)).toBe("R")
    end)
end)

describe("HudModel.view — the confirm affordance", function()
    test("a pending selection is lit and asks for its second tap", function()
        local v = HudModel.view(inputs({ pointsAtStake = 27, selectedThrow = "P" }), session(0))
        expect(v.selected).toBe("P")
        expect(v.confirmPending).toBe(true)
    end)

    test("with no pot there is nothing pending to show", function()
        local v = HudModel.view(inputs({ pointsAtStake = 0 }), session(0))
        expect(v.selected).toBe(nil)
        expect(v.confirmPending).toBe(false)
    end)

    test("banking mid-selection keeps the tile lit but drops the prompt", function()
        local v = HudModel.view(inputs({ pointsAtStake = 0, selectedThrow = "R" }), session(0))
        expect(v.selected).toBe("R")
        expect(v.confirmPending).toBe(false)
    end)

    test("the preference off never prompts", function()
        local v = HudModel.view(inputs({ pointsAtStake = 27, confirmThrows = false }), session(0))
        expect(v.confirmPending).toBe(false)
    end)

    test("a selection does not survive the round closing", function()
        local v =
            HudModel.view(inputs({ pointsAtStake = 27, selectedThrow = "P", phase = "REVEAL" }), session(0))
        expect(v.selected).toBe(nil)
        expect(v.confirmPending).toBe(false)
    end)
end)

describe("HudModel.newSession", function()
    test("a fresh session is unmissed, and therefore armed", function()
        local s = HudModel.newSession()
        expect(s.consecutiveMisses).toBe(0)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)
end)
