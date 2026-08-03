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
        escalationPrompts = true,
        chosen = nil,
        switchPrompt = nil,
        sent = false,
        declinedThisRound = false,
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

    test("the round stays open to taps for the whole of ACTIVE", function()
        -- No "you have committed, so the round is closed to you" state: that state is exactly
        -- what made backing out impossible, and backing out is now the point.
        expect(HudModel.view(inputs({ chosen = "R" }), session(0)).throwsEnabled).toBe(true)
    end)

    test("a win no longer blocks throwing — riding IS throwing again", function()
        local v = HudModel.view(inputs({ unresolvedWin = true, pointsAtStake = 27 }), session(0))
        expect(v.throwsEnabled).toBe(true)
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

describe("HudModel.view — plate, bank and pot", function()
    test("the plate carries streak and points, and NEVER the pot", function()
        local v =
            HudModel.view(inputs({ currentStreak = 3, pointsAtStake = 27, totalPoints = 1240 }), session(0))
        expect(v.plate.streak).toBe(3)
        expect(v.plate.points).toBe(1240)
        expect((v.plate :: any).pot).toBe(nil)
    end)

    test("the bank button appears only while a pot is riding", function()
        expect(HudModel.view(inputs({ pointsAtStake = 0 }), session(0)).bankVisible).toBe(false)
        expect(HudModel.view(inputs({ pointsAtStake = 27 }), session(0)).bankVisible).toBe(true)
        expect(HudModel.view(inputs({ pointsAtStake = 27 }), session(0)).pot).toBe(27)
    end)

    test("an unbanked pot outlives the round, the session and a week away", function()
        for _, p in { "TALLY", "REVEAL" } do
            expect(HudModel.view(inputs({ phase = p, pointsAtStake = 27 }), session(0)).bankVisible).toBe(
                true
            )
        end
    end)

    test("the pot pulses only while the win is unacknowledged", function()
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = true }), session(0)).potPulses).toBe(
            true
        )
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = false }), session(0)).potPulses).toBe(
            false
        )
        expect(HudModel.view(inputs({ pointsAtStake = 0, unresolvedWin = true }), session(0)).potPulses).toBe(
            false
        )
    end)

    test("a chosen glyph stays lit after the round closes — it is what was thrown", function()
        local v = HudModel.view(inputs({ phase = "REVEAL", chosen = "R" }), session(0))
        expect(v.chosen).toBe("R")
    end)

    test("a prompt never survives the round closing", function()
        local v = HudModel.view(inputs({ phase = "TALLY", chosen = "R", switchPrompt = "P" }), session(0))
        expect(v.switchPrompt).toBe(nil)
    end)
end)

describe("HudModel.view — escalation keys off the CHOICE", function()
    test("armed while nothing is chosen", function()
        expect(HudModel.view(inputs({ secondsLeft = 4 }), session(0)).escalate).toBe(true)
    end)

    test("silent once a glyph is chosen", function()
        expect(HudModel.view(inputs({ secondsLeft = 4, chosen = "R" }), session(0)).escalate).toBe(false)
    end)

    test("BACKING OUT SILENCES IT for the rest of the round", function()
        -- The player has answered the question CHOOSE A THROW is asking. Re-nagging is wrong.
        local v =
            HudModel.view(inputs({ secondsLeft = 4, chosen = nil, declinedThisRound = true }), session(0))
        expect(v.escalate).toBe(false)
    end)

    test("still silent after three misses, and still off when the preference is off", function()
        expect(HudModel.view(inputs({ secondsLeft = 4 }), session(3)).escalate).toBe(false)
        expect(HudModel.view(inputs({ secondsLeft = 4, escalationPrompts = false }), session(0)).escalate).toBe(
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

describe("HudModel.tapAction — the five-row table", function()
    test("a closed round ignores every tap", function()
        for _, over in { { phase = "TALLY" }, { phase = "REVEAL" }, { secondsLeft = 0 } } do
            for _, sym in { "R", "P", "S" } do
                expect(HudModel.tapAction(inputs(over), sym)).toBe("ignore")
            end
        end
    end)

    test("with nothing chosen, any tap chooses", function()
        for _, sym in { "R", "P", "S" } do
            expect(HudModel.tapAction(inputs({ chosen = nil }), sym)).toBe("choose")
        end
    end)

    test("tapping the chosen glyph does nothing", function()
        expect(HudModel.tapAction(inputs({ chosen = "R" }), "R")).toBe("ignore")
    end)

    test("tapping the chosen glyph does nothing even while a prompt is up", function()
        expect(HudModel.tapAction(inputs({ chosen = "R", switchPrompt = "P" }), "R")).toBe("ignore")
    end)

    test("tapping another glyph raises a prompt over it", function()
        expect(HudModel.tapAction(inputs({ chosen = "R" }), "P")).toBe("prompt")
        expect(HudModel.tapAction(inputs({ chosen = "R" }), "S")).toBe("prompt")
    end)

    test("tapping the prompted glyph clears", function()
        expect(HudModel.tapAction(inputs({ chosen = "R", switchPrompt = "P" }), "P")).toBe("clear")
    end)

    test("tapping the third glyph moves the prompt rather than clearing", function()
        expect(HudModel.tapAction(inputs({ chosen = "R", switchPrompt = "P" }), "S")).toBe("prompt")
    end)
end)

describe("HudModel.applyTap — the transition table", function()
    local function state(chosen: string?, prompt: string?): any
        return { chosen = chosen, switchPrompt = prompt }
    end

    test("choose sets the glyph and drops any prompt", function()
        local s = HudModel.applyTap(state(nil, nil), "choose", "R")
        expect(s.chosen).toBe("R")
        expect(s.switchPrompt).toBe(nil)
    end)

    test("prompt leaves the choice untouched", function()
        local s = HudModel.applyTap(state("R", nil), "prompt", "P")
        expect(s.chosen).toBe("R")
        expect(s.switchPrompt).toBe("P")
    end)

    test("prompt moves an existing prompt", function()
        local s = HudModel.applyTap(state("R", "P"), "prompt", "S")
        expect(s.chosen).toBe("R")
        expect(s.switchPrompt).toBe("S")
    end)

    test("CLEAR EMPTIES BOTH — this is the back-out", function()
        local s = HudModel.applyTap(state("R", "P"), "clear", "P")
        expect(s.chosen).toBe(nil)
        expect(s.switchPrompt).toBe(nil)
    end)

    test("ignore changes nothing", function()
        local s = HudModel.applyTap(state("R", "P"), "ignore", "R")
        expect(s.chosen).toBe("R")
        expect(s.switchPrompt).toBe("P")
    end)
end)

describe("HudModel — the invariant, over every reachable sequence", function()
    -- A prompt is always a question ABOUT an existing choice, raised over a DIFFERENT glyph.
    -- Walk every tap sequence up to depth 4 and assert it holds at every step.
    test("no reachable sequence yields a prompt without a choice, or a prompt on the choice", function()
        local SYMS = { "R", "P", "S" }
        local function walk(st: any, depth: number)
            expect(st.switchPrompt == nil or st.chosen ~= nil).toBe(true)
            expect(st.switchPrompt == nil or st.switchPrompt ~= st.chosen).toBe(true)
            if depth == 0 then
                return
            end
            for _, sym in SYMS do
                local i = inputs({ chosen = st.chosen, switchPrompt = st.switchPrompt })
                walk(HudModel.applyTap(st, HudModel.tapAction(i, sym), sym), depth - 1)
            end
        end
        walk({ chosen = nil, switchPrompt = nil }, 4)
    end)

    test("a back-out is always reachable in two taps from any choice", function()
        for _, chosen in { "R", "P", "S" } do
            local other = if chosen == "R" then "P" else "R"
            local st = { chosen = chosen, switchPrompt = nil }
            st = HudModel.applyTap(st, HudModel.tapAction(inputs(st), other), other)
            st = HudModel.applyTap(st, HudModel.tapAction(inputs(st), other), other)
            expect(st.chosen).toBe(nil)
        end
    end)
end)

describe("HudModel.switchPromptExpired", function()
    test("an absent prompt never expires", function()
        expect(HudModel.switchPromptExpired(nil, 1000)).toBe(false)
    end)

    test("it expires at exactly SWITCH_PROMPT_SECONDS, not before", function()
        local t = 100
        expect(HudModel.switchPromptExpired(t, t + HudModel.SWITCH_PROMPT_SECONDS - 0.01)).toBe(false)
        expect(HudModel.switchPromptExpired(t, t + HudModel.SWITCH_PROMPT_SECONDS)).toBe(true)
    end)
end)

describe("HudModel.sendAtLockout — the pick's ONE trip to the wire", function()
    test("nothing to send with nothing chosen", function()
        expect(HudModel.sendAtLockout(inputs({ chosen = nil, secondsLeft = 0.2 }))).toBe(nil)
    end)

    test("holds the pick while there is still time", function()
        expect(HudModel.sendAtLockout(inputs({ chosen = "R", secondsLeft = 5 }))).toBe(nil)
    end)

    test("sends at the half-second boundary", function()
        expect(HudModel.sendAtLockout(inputs({ chosen = "R", secondsLeft = 0.5 }))).toBe("R")
        expect(HudModel.sendAtLockout(inputs({ chosen = "R", secondsLeft = 0.1 }))).toBe("R")
    end)

    test("NEVER TWICE — once sent, it stays sent", function()
        expect(HudModel.sendAtLockout(inputs({ chosen = "R", secondsLeft = 0.1, sent = true }))).toBe(nil)
    end)

    test("a round that moved on with an unsent choice still tries", function()
        -- The unsynced-clock path never reaches the boundary above (its countdown is a
        -- constant). The server may answer PICKS_CLOSED and the whiff toast then says so
        -- honestly; trying and being told beats never trying.
        for _, p in { "TALLY", "REVEAL" } do
            expect(HudModel.sendAtLockout(inputs({ chosen = "R", phase = p }))).toBe("R")
        end
    end)

    test("a back-out leaves nothing to send at the lockout", function()
        local st = HudModel.applyTap({ chosen = "R", switchPrompt = "P" }, "clear", "P")
        expect(HudModel.sendAtLockout(inputs({ chosen = st.chosen, secondsLeft = 0.1 }))).toBe(nil)
    end)
end)

describe("HudModel.newSession", function()
    test("a fresh session is unmissed, and therefore armed", function()
        local s = HudModel.newSession()
        expect(s.consecutiveMisses).toBe(0)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)
end)
