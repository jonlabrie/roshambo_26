### Task 6: `HudModel` — the minimal view model and the escalation rule

The most consequential pure module in the plan. The escalation arm/disarm rule is the thing most
likely to be got subtly wrong and the most annoying to a player if it is.

**Owner ruling, 2026-08-02:** the backoff is **uniform**. The three "arm reasons" — new arrival,
threw last round, pot riding — only ever described who *starts* armed; they are not ongoing
conditions. Anyone armed stays armed for **three consecutive ignored rounds**, then goes silent,
and re-arms the instant they throw again. So the rule collapses to the miss counter alone, and
`Session` collapses with it to a single field.

The first draft carried all three as live OR-conditions and produced a bug: a player who threw,
lost (pot 0) and then missed one round had `threwLastRound = false`, `pointsAtStake = 0` and
`hasThrownThisSession = true`, so the OR clause went false and the prompt died after **one** miss
instead of three. The most common case got the least grace. That is the behaviour this task must
not reproduce, and there is a named regression test for it.

**Files:**
- Create: `roblox/src/shared/HudModel.luau`
- Test: `roblox/tests/HudModel.spec.luau` (check whether it exists; extend if so)

**Interfaces:**
- Produces:
  - `HudModel.newSession(): Session` where `Session = { consecutiveMisses: number }`
  - `HudModel.view(inputs: Inputs, session: Session): View`
  - `HudModel.onRoundEnded(session: Session, outcome: { couldThrow: boolean, picked: boolean }): Session` — pure, returns a new table
  - `Inputs = { phase: string, secondsLeft: number, pointsAtStake: number, currentStreak: number, totalPoints: number, unresolvedWin: boolean, fateBound: boolean, pickedThisRound: boolean, escalationPrompts: boolean }`
  - `View = { plate: { streak: number, pot: number, points: number }, throwsEnabled: boolean, choiceUp: boolean, escalate: boolean, secondsLeft: number }`

- [ ] **Step 1: Write the failing test**

```luau
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

local function session(misses: number): any
    return { consecutiveMisses = misses }
end

describe("HudModel.view — plate and throws", function()
    test("the plate always shows streak, pot and points", function()
        local v = HudModel.view(inputs({ currentStreak = 3, pointsAtStake = 27, totalPoints = 1240 }), session(0))
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

    test("fate-bound and win-bound both disable throws", function()
        expect(HudModel.view(inputs({ fateBound = true }), session(0)).throwsEnabled).toBe(false)
        expect(HudModel.view(inputs({ unresolvedWin = true }), session(0)).throwsEnabled).toBe(false)
    end)
end)

describe("HudModel.view — the choice overlay", function()
    test("the overlay is up exactly when the player is win-bound", function()
        expect(HudModel.view(inputs({ unresolvedWin = true, pointsAtStake = 27 }), session(0)).choiceUp).toBe(true)
        expect(HudModel.view(inputs({ unresolvedWin = false }), session(0)).choiceUp).toBe(false)
    end)

    test("the overlay persists through every phase — it does not expire with the round", function()
        -- the owner's rule: no default and no expiry. They have a choice to make.
        for _, p in { "ACTIVE", "TALLY", "REVEAL" } do
            local v = HudModel.view(inputs({ phase = p, unresolvedWin = true, pointsAtStake = 27 }), session(0))
            expect(v.choiceUp).toBe(true)
        end
    end)

    test("being fate-bound does not raise the win choice", function()
        expect(HudModel.view(inputs({ fateBound = true }), session(0)).choiceUp).toBe(false)
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
        expect(HudModel.view(inputs({ secondsLeft = 2, pickedThisRound = true }), session(0)).escalate).toBe(false)
    end)

    test("it never fires at a player who cannot throw", function()
        -- "CHOOSE A THROW" is noise at someone the server will refuse
        expect(HudModel.view(inputs({ secondsLeft = 2, fateBound = true }), session(0)).escalate).toBe(false)
        expect(HudModel.view(inputs({ secondsLeft = 2, unresolvedWin = true }), session(0)).escalate).toBe(false)
    end)

    test("the preference switch silences it outright", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, escalationPrompts = false }), session(0)).escalate).toBe(false)
    end)

    test("three consecutive misses disarm it, even with a pot riding", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 27 }), session(3)).escalate).toBe(false)
    end)

    test("two misses is still armed — the backoff is at three", function()
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 27 }), session(2)).escalate).toBe(true)
    end)

    test("the backoff is UNIFORM — a pot riding buys no extra grace", function()
        -- the arm reasons describe who STARTS armed; they are not ongoing conditions
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 0 }), session(2)).escalate).toBe(true)
        expect(HudModel.view(inputs({ secondsLeft = 2, pointsAtStake = 99 }), session(3)).escalate).toBe(false)
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
        expect(HudModel.onRoundEnded(session(2), { couldThrow = true, picked = true }).consecutiveMisses).toBe(0)
    end)

    test("an ignored round is a miss", function()
        expect(HudModel.onRoundEnded(session(0), { couldThrow = true, picked = false }).consecutiveMisses).toBe(1)
    end)

    test("a round the player COULD NOT throw in is not a miss", function()
        -- being win-bound or fate-bound is being prevented, not ignoring it; counting these
        -- would disarm the prompt for a player who was stuck deciding
        expect(HudModel.onRoundEnded(session(0), { couldThrow = false, picked = false }).consecutiveMisses).toBe(0)
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

describe("HudModel.newSession", function()
    test("a fresh session is unmissed, and therefore armed", function()
        local s = HudModel.newSession()
        expect(s.consecutiveMisses).toBe(0)
        expect(HudModel.view(inputs({ secondsLeft = 3 }), s).escalate).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run from `roblox/`: `lune run tests/run`
Expected: FAIL — `HudModel` does not exist (or, if you are amending an existing module, the
uniform-backoff and one-miss-regression cases fail).

- [ ] **Step 3: Write the module**

```luau
--!strict
-- Minimal-HUD view model. Pure: no Roblox globals, no I/O, so it runs under Lune.
--
-- The escalation rule is the delicate part. Roshambo is an ambient game — most people in the
-- canyon at any moment are not playing, they are hanging out. An ungated "CHOOSE A THROW" alarm
-- would fire at them every single round, forever, and turn the calmest part of the game into an
-- alarm clock.
--
-- The rule is a UNIFORM backoff: anyone stays armed for three consecutive ignored rounds, then
-- goes silent, and re-arms the instant they throw again. "New arrival", "threw last round" and
-- "pot riding" describe who STARTS armed — a fresh session has zero misses — but they are not
-- ongoing conditions, so they do not appear here. An earlier draft carried them as live OR-terms
-- and a player who threw, won nothing and missed once fell out of the OR: the prompt died after
-- ONE miss instead of three, giving the most common case the least grace.
--
-- A round only counts as ignored if the player COULD have thrown. Rounds spent win-bound or
-- fate-bound are not misses — the player was prevented, not inattentive. Counting them would
-- disarm the prompt for exactly the player who was stuck on a decision.
local HudModel = {}

local ESCALATE_AT = 5 -- seconds remaining
local BACKOFF_MISSES = 3

export type Session = { consecutiveMisses: number }

export type Inputs = {
    phase: string,
    secondsLeft: number,
    pointsAtStake: number,
    currentStreak: number,
    totalPoints: number,
    unresolvedWin: boolean,
    fateBound: boolean,
    pickedThisRound: boolean,
    escalationPrompts: boolean,
}

export type View = {
    plate: { streak: number, pot: number, points: number },
    throwsEnabled: boolean,
    choiceUp: boolean,
    escalate: boolean,
    secondsLeft: number,
}

function HudModel.newSession(): Session
    return { consecutiveMisses = 0 }
end

function HudModel.view(inputs: Inputs, session: Session): View
    -- Win-bound and fate-bound are both server-enforced; this only mirrors them so the UI can
    -- dim. The server is what actually refuses the pick.
    local bound = inputs.unresolvedWin or inputs.fateBound
    local throwsEnabled = inputs.phase == "ACTIVE"
        and inputs.secondsLeft > 0
        and not bound
        and not inputs.pickedThisRound

    -- The choice has no expiry: it survives the round, the session, and a week away. It is NOT
    -- gated on phase for that reason.
    local choiceUp = inputs.unresolvedWin

    local armed = inputs.escalationPrompts
        and not bound
        and inputs.phase == "ACTIVE"
        and not inputs.pickedThisRound
        and session.consecutiveMisses < BACKOFF_MISSES

    return {
        plate = {
            streak = inputs.currentStreak,
            pot = inputs.pointsAtStake,
            points = inputs.totalPoints,
        },
        throwsEnabled = throwsEnabled,
        choiceUp = choiceUp,
        escalate = armed and inputs.secondsLeft > 0 and inputs.secondsLeft <= ESCALATE_AT,
        secondsLeft = inputs.secondsLeft,
    }
end

function HudModel.onRoundEnded(session: Session, outcome: { couldThrow: boolean, picked: boolean }): Session
    if outcome.picked then
        return { consecutiveMisses = 0 }
    end
    if not outcome.couldThrow then
        -- prevented, not inattentive — carry the count forward untouched
        return { consecutiveMisses = session.consecutiveMisses }
    end
    return { consecutiveMisses = session.consecutiveMisses + 1 }
end

return HudModel
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lune run tests/run` → PASS.

- [ ] **Step 5: Run the format and lint gates**

Run: `stylua --check src tests tools && selene src tools` → clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
git commit -m "feat(roblox): HudModel — minimal view model with a uniform escalation backoff"
```

---

