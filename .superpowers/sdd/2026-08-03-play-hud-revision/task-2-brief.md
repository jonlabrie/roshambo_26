### Task 2: `HudModel` — view, escalation, and the lockout send

Finishes the model: the view loses the fate slot and the confirm affordance, escalation keys
off `chosen`, and `autoCommit` becomes `sendAtLockout`.

**Files:**
- Modify: `roblox/src/shared/HudModel.luau`
- Test: `roblox/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: Task 1's `Inputs` fields.
- Produces:
  - `HudModel.sendAtLockout(inputs: Inputs): string?`
  - `View = { plate: { streak: number, points: number }, throwsEnabled: boolean, bankVisible: boolean, pot: number, potPulses: boolean, escalate: boolean, secondsLeft: number, chosen: string?, switchPrompt: string? }`
  - `Inputs` loses `fateBound`, `pickedThisRound`, `confirmThrows`, `selectedThrow`.

- [ ] **Step 1: Write the failing tests**

In `roblox/tests/HudModel.spec.luau`, delete the `fateBound`, `pickedThisRound`,
`confirmThrows` and `selectedThrow` entries from the `inputs` helper's base table. Delete the
describe blocks `HudModel.view — the slot above the throw row`,
`HudModel.autoCommit — a missed second tap must never cost a round`,
`HudModel.view — the confirm affordance` and `HudModel — pickedThisRound after a release`.
Add:

```luau
describe("HudModel.view — plate, bank and pot", function()
    test("the plate carries streak and points, and NEVER the pot", function()
        local v = HudModel.view(inputs({ currentStreak = 3, pointsAtStake = 27, totalPoints = 1240 }), session(0))
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
            expect(HudModel.view(inputs({ phase = p, pointsAtStake = 27 }), session(0)).bankVisible).toBe(true)
        end
    end)

    test("the pot pulses only while the win is unacknowledged", function()
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = true }), session(0)).potPulses).toBe(true)
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = false }), session(0)).potPulses).toBe(false)
        expect(HudModel.view(inputs({ pointsAtStake = 0, unresolvedWin = true }), session(0)).potPulses).toBe(false)
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
        local v = HudModel.view(inputs({ secondsLeft = 4, chosen = nil, declinedThisRound = true }), session(0))
        expect(v.escalate).toBe(false)
    end)

    test("still silent after three misses, and still off when the preference is off", function()
        expect(HudModel.view(inputs({ secondsLeft = 4 }), session(3)).escalate).toBe(false)
        expect(HudModel.view(inputs({ secondsLeft = 4, escalationPrompts = false }), session(0)).escalate).toBe(false)
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `lune run tests/run`
Expected: FAIL — `sendAtLockout` is nil, `view` has no `bankVisible`, and `plate.pot` is set.

- [ ] **Step 3: Rewrite `view` and replace `autoCommit`**

In `roblox/src/shared/HudModel.luau`, delete `fateBound`, `pickedThisRound`, `confirmThrows`
and `selectedThrow` from `Inputs`. Replace the `View` type, `HudModel.autoCommit` and
`HudModel.view` with:

```luau
export type View = {
    plate: { streak: number, points: number },
    throwsEnabled: boolean,
    -- The pot's own control. It is a button, not a readout: the figure belongs IN the thing
    -- that acts on it, which is why the plate no longer carries a pot at all.
    bankVisible: boolean,
    pot: number,
    potPulses: boolean,
    escalate: boolean,
    secondsLeft: number,
    chosen: string?,
    switchPrompt: string?,
}

-- The chosen glyph, if this is the moment it has to go over the wire, or nil.
--
-- ONE TRIP PER ROUND. The pick is held client-side until here because ThrowBuffer is
-- upsert-only — there is no removal in the buffer, in the delta, or in POST /api/v1/throws —
-- so sending on the first tap would make backing out a lie. `secondsLeft` is
-- secondsToLockout, so zero IS the lockout; half a second is the slack for the
-- client -> SubmitPick -> ThrowBuffer trip that the buffer's own lockout flush then carries.
local SEND_AT = 0.5

function HudModel.sendAtLockout(inputs: Inputs): string?
    local chosen = inputs.chosen
    if chosen == nil or inputs.sent then
        return nil
    end
    if inputs.phase ~= "ACTIVE" then
        return chosen
    end
    if inputs.secondsLeft > SEND_AT then
        return nil
    end
    return chosen
end

function HudModel.view(inputs: Inputs, session: Session): View
    local throwsEnabled = throwsEnabledFor(inputs)

    -- A round only nags someone who has not answered it. `chosen` is the answer; a deliberate
    -- back-out (`declinedThisRound`) is ALSO an answer, and re-nagging the player who just
    -- withdrew is exactly wrong — they are demonstrably paying attention.
    local armed = inputs.escalationPrompts
        and not inputs.declinedThisRound
        and inputs.phase == "ACTIVE"
        and inputs.chosen == nil
        and session.consecutiveMisses < BACKOFF_MISSES

    return {
        plate = { streak = inputs.currentStreak, points = inputs.totalPoints },
        throwsEnabled = throwsEnabled,
        -- Not gated on phase: an unbanked pot outlives the round, the session and a week away.
        bankVisible = inputs.pointsAtStake > 0,
        pot = inputs.pointsAtStake,
        -- unresolvedWin's only job: "the last scored round was a WIN and the player has not
        -- banked since". It drives the pulse and nothing else.
        potPulses = inputs.pointsAtStake > 0 and inputs.unresolvedWin,
        escalate = armed and inputs.secondsLeft > 0 and inputs.secondsLeft <= ESCALATE_AT,
        secondsLeft = inputs.secondsLeft,
        -- The choice OUTLIVES the round: after the lockout it is what was thrown, and the tile
        -- stays lit through TALLY/REVEAL saying so. main.client clears it when ACTIVE reopens.
        chosen = inputs.chosen,
        -- The prompt does not. A question about a round that has closed cannot be answered.
        switchPrompt = if throwsEnabled then inputs.switchPrompt else nil,
    }
end
```

Also delete the now-unreferenced `AUTO_COMMIT_AT` constant and update the module's header
comment: the escalation paragraph's "not fate-bound" clause goes, and the backoff paragraph
gains the back-out rule.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lune run tests/run`
Expected: PASS, all files.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
git commit -m "feat(roblox): the pot gets its own button, and backing out quiets the nag"
```

---

