# Play HUD Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the throw-confirmation system with choose-then-switch, move the player-state
plate out of the middle of the mobile view, make the transient messages readable, make the
teahouse panel dismissable, and park the fates system.

**Architecture:** The pure `HudModel` state machine changes shape first (Tasks 1–2); every
other task consumes it. `HudLayout` carries the shared geometry (Task 3). `main.client.luau`
owns pick state and the wire (Tasks 4–5), `HudController` owns the visuals (Tasks 6–9),
`OnboardingController` re-derives from the new skeleton (Task 10), a new `Takeover` module
serves both takeover panels (Tasks 11–12), and the last two tasks retire what the redesign
made dead (Tasks 13–14).

**Tech Stack:** Luau (Roblox client + Lune tests), TypeScript/Express/Vitest (server).

**Spec:** `docs/superpowers/specs/2026-08-03-play-hud-revision-design.md` — read §1 before
Task 1 and §3 before Task 9.

## Global Constraints

- **TDD.** Failing test first, then implementation. Never write implementation before the
  test that fails without it.
- **`roblox/src/shared` modules are pure**: no Roblox globals (no `game`, `workspace`,
  `task`, `Instance`, `TweenService`, `os.clock`), dependency-injected, and they never
  `require` each other. They must run under Lune.
- **`UIStroke` never goes on a `TextLabel`.** Contrast comes from an opaque backing. This is
  the defect Task 9 fixes; do not reintroduce it anywhere.
- **Non-interactive elements leave `Active = false`.** Every sinking pixel is a permanent
  hole in the camera-drag surface. Only `TextButton`/`ImageButton` may sink, and only where
  a button is intended.
- **`main.client.luau` contains no `Instance.new`.** It is wiring only; all UI lives in
  controllers.
- **`math.clamp` errors in Luau when min > max.** Guard every clamp whose bounds are derived.
- Luau gates: `lune run tests/run`, `stylua --check src tests tools`, `selene src tools`
  (run from `roblox/`). **selene fails on warnings** — unused locals and unused requires are
  failures, not notes.
- Server gate: `npm test` from `server/`.
- Server tests live **beside their subjects** (`server/src/routes/apiV1.test.ts`), never in a
  `__tests__/` directory.
- Commit after every task.

---

### Task 1: `HudModel` — the choose/switch state machine

Replaces `tapAction`/`applyTap`'s confirm semantics with the spec §1 table. `autoCommit` and
the old `Inputs` fields stay in place so the suite keeps building; Task 2 finishes the model.

**`view` is NOT untouched.** It calls `HudModel.confirmRequired`, which this task deletes, so
its two confirm fields must go in the same commit or `view` calls a nil. Step 3 covers it.

**Files:**
- Modify: `roblox/src/shared/HudModel.luau`
- Test: `roblox/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `HudModel.SWITCH_PROMPT_SECONDS: number` (= 4)
  - `HudModel.tapAction(inputs: Inputs, symbol: string): string` → `"choose" | "prompt" | "clear" | "ignore"`
  - `HudModel.applyTap(state: TapState, action: string, symbol: string): TapState`
  - `HudModel.switchPromptExpired(setAt: number?, now: number): boolean`
  - `export type TapState = { chosen: string?, switchPrompt: string? }`

- [ ] **Step 1: Write the failing tests**

Replace the four describe blocks named `HudModel.tapAction — one tap, or two`,
`HudModel.tapAction — releasing a confirmed throw`, `HudModel.applyTap — the transition table`
and `HudModel — the full transition table` in `roblox/tests/HudModel.spec.luau` with:

```luau
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
```

In the same file, extend the `inputs` helper's base table with the new fields (leave the old
ones in place — Task 2 removes them):

```luau
        chosen = nil,
        switchPrompt = nil,
        sent = false,
        declinedThisRound = false,
```

Also delete these three tests, whose assertions this task's `throwsEnabledFor` deliberately
reverses — the round now stays open to taps for the whole of ACTIVE, because a closed round is
what made backing out impossible:

- in `HudModel.view — plate and throws`: **`throws are disabled once a pick is in`** and
  **`a fate still blocks throwing`**
- the whole `HudModel.view — the confirm affordance` describe block, and the whole
  `HudModel — pickedThisRound after a release` describe block (both assert fields Step 3
  removes)

Replace the first two with:

```luau
    test("the round stays open to taps for the whole of ACTIVE", function()
        -- No "you have committed, so the round is closed to you" state: that state is exactly
        -- what made backing out impossible, and backing out is now the point.
        expect(HudModel.view(inputs({ chosen = "R" }), session(0)).throwsEnabled).toBe(true)
    end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `roblox/`: `lune run tests/run`
Expected: FAIL — `tapAction` returns `"commit"`/`"select"`/`"release"`, and
`switchPromptExpired` is nil.

- [ ] **Step 3: Rewrite the tap machinery**

In `roblox/src/shared/HudModel.luau`, add to `Inputs` (leave existing fields for now):

```luau
    -- The glyph the player has chosen this round, the glyph currently carrying a SWITCH?
    -- prompt, and whether the pick has gone over the wire. `chosen` is the player's
    -- commitment; `sent` is the wire's. They are separate because the pick is held locally
    -- until the lockout, which is the only thing that makes a back-out honest.
    chosen: string?,
    switchPrompt: string?,
    sent: boolean,
    declinedThisRound: boolean,
```

Replace `throwsEnabledFor`, `HudModel.confirmRequired`, `HudModel.tapAction`,
`HudModel.applyTap` and the `TapState` type with:

```luau
-- Four seconds. A prompt is a question, and an unanswered question must not sit on screen
-- indefinitely — but note the expiry is safe in BOTH directions: expiring restores exactly the
-- state before the stray tap, and answering only ever unlocks. Neither outcome throws anything.
HudModel.SWITCH_PROMPT_SECONDS = 4

-- The round takes taps for the whole of ACTIVE. There is deliberately no "you have committed,
-- so the round is closed to you" state: that state is what made backing out impossible, and
-- backing out is now the point.
local function throwsEnabledFor(inputs: Inputs): boolean
    return inputs.phase == "ACTIVE" and inputs.secondsLeft > 0
end

export type TapState = { chosen: string?, switchPrompt: string? }

-- What a tap on `symbol` does. Evaluated top to bottom; first match wins.
--
--   "choose" — light it; the throw is chosen (locally — see sendAtLockout)
--   "prompt" — raise SWITCH? over `symbol`, moving it if it was elsewhere
--   "clear"  — all three available again, NOTHING chosen. This is the back-out.
--   "ignore" — the round cannot take a throw, or the tap lands on the lit glyph
--
-- TAPPING THE LIT GLYPH DOES NOTHING (owner's ruling). The switch path is the only way out, so
-- there is exactly one gesture to learn. A lit glyph that also un-chose would give one button
-- two meanings depending on invisible state.
--
-- CONFIRMING A SWITCH UNLOCKS; IT DOES NOT SELECT. That is the whole reason a back-out exists:
-- a confirm-that-also-selects would leave no way to end a round having chosen nothing.
function HudModel.tapAction(inputs: Inputs, symbol: string): string
    if not throwsEnabledFor(inputs) then
        return "ignore"
    end
    if inputs.chosen == nil then
        return "choose"
    end
    if symbol == inputs.chosen then
        return "ignore"
    end
    if symbol == inputs.switchPrompt then
        return "clear"
    end
    return "prompt"
end

-- The state transition for a `tapAction` result. In here rather than inline in the controller
-- so the table is enforced in ONE place a future edit has to touch, and pinned by the
-- exhaustive test in HudModel.spec.luau.
--
-- Pure: the controller still owns the side effects (publishing, the wire) — this computes the
-- two fields and nothing else.
function HudModel.applyTap(state: TapState, action: string, symbol: string): TapState
    if action == "choose" then
        return { chosen = symbol, switchPrompt = nil }
    elseif action == "prompt" then
        return { chosen = state.chosen, switchPrompt = symbol }
    elseif action == "clear" then
        return { chosen = nil, switchPrompt = nil }
    end
    return { chosen = state.chosen, switchPrompt = state.switchPrompt }
end

-- Whether a standing prompt has aged out. A predicate rather than a timer so it is pure and
-- testable; main.client's existing 10Hz heartbeat is what calls it, which is ample resolution
-- for a four-second question.
function HudModel.switchPromptExpired(setAt: number?, now: number): boolean
    return setAt ~= nil and (now - setAt) >= HudModel.SWITCH_PROMPT_SECONDS
end
```

**Then unhook `view` from the deleted `confirmRequired`.** Delete `confirmPending` and
`releasable` from both the `View` type and `view`'s return table, and delete the `selected`
field's `throwsEnabled` gate so it reads `selected = inputs.selectedThrow`. Those three fields
are the confirm system's view surface and they cannot outlive it — `confirmPending` calls
`HudModel.confirmRequired` directly, so leaving it would make every `view` call error.

`HudModel.autoCommit` still compiles (it reads `selectedThrow` and `pickedThisRound`, which
survive until Task 2) and is left alone.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lune run tests/run`
Expected: the new blocks PASS. Older blocks that assert confirm behaviour may still pass
(they use the old fields); Task 2 deletes them.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
git commit -m "feat(roblox): one tap chooses, and a switch has to be confirmed"
```

---

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

### Task 3: `HudLayout` — the new skeleton

The confirm strip's reserved row goes; the cluster reorders; the plate gets right-margin
constants.

**Files:**
- Modify: `roblox/src/shared/HudLayout.luau`
- Test: `roblox/tests/HudLayout.spec.luau` (create if absent)

**Interfaces:**
- Produces: `HudLayout.PLATE_ROW_H`, `HudLayout.PLATE_W`, `HudLayout.PLATE_JUMP_GAP`,
  `HudLayout.BANK_H`; `CLUSTER_TOP_FROM_BOTTOM` / `_TOUCH` re-derived without the confirm
  strip. `PLATE_H`, `PLATE_BOTTOM`, `CONFIRM_H`, `CONFIRM_GAP`, `SLOT_H`, `SLOT_GAP` are
  removed.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/HudLayout.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local HudLayout = require("../src/shared/HudLayout")

describe("HudLayout — the cluster the onboarding band has to clear", function()
    test("the cluster is bank + throws + tape, and nothing else", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH).toBe(
            HudLayout.EDGE + HudLayout.AREA_H_TOUCH + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
    end)

    test("the touch cluster is shorter than the pointer one", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH < HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(true)
    end)

    test("the confirm strip is gone", function()
        expect((HudLayout :: any).CONFIRM_H).toBe(nil)
        expect((HudLayout :: any).CONFIRM_GAP).toBe(nil)
    end)

    test("the plate no longer reserves a band at the top", function()
        expect((HudLayout :: any).PLATE_BOTTOM).toBe(nil)
    end)

    test("the touch throw target clears the 44px floor", function()
        expect(HudLayout.BTN_H_TOUCH >= 44).toBe(true)
    end)
end)

describe("HudLayout.plateBottomOffset — where the plate sits above the jump button", function()
    test("with no jump button it falls back to the screen edge", function()
        expect(HudLayout.plateBottomOffset(400, nil)).toBe(HudLayout.EDGE)
    end)

    test("it clears a measured button by PLATE_JUMP_GAP", function()
        -- gui bottom at y=400, jump button's top edge at y=310 -> 90 up from the bottom, plus
        -- the gap.
        expect(HudLayout.plateBottomOffset(400, 310)).toBe(90 + HudLayout.PLATE_JUMP_GAP)
    end)

    test("a button measured below the screen edge cannot push the plate off-screen", function()
        -- Defensive: AbsolutePosition is read live and can be stale or nonsense for a frame.
        expect(HudLayout.plateBottomOffset(400, 500)).toBe(HudLayout.EDGE)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — `BANK_H` is nil and `CONFIRM_H` is still present.

- [ ] **Step 3: Edit the module**

In `roblox/src/shared/HudLayout.luau`: delete `PLATE_H`, `PLATE_BOTTOM`, `CONFIRM_H`,
`CONFIRM_GAP`, and rename `SLOT_H`/`SLOT_GAP` to `BANK_H`/`BANK_GAP`. Add:

```luau
-- ===== The player-state plate, now in the right margin =====
-- It moved out of top-centre because that band is the middle of a phone's view. It lives in
-- the strip Roblox claims for jump and camera drag — the one place a display with NO
-- interactive elements can safely go, since nothing in it is Active and every drag passes
-- straight through.
--
-- ABOVE the jump button, not below. Roblox's default TouchJump leaves roughly 20px between
-- that button's lower edge and the bottom of the screen on a phone, and on iOS that 20px is
-- the home indicator. Above it there is ~300px at every size.
--
-- These are the plate's own dimensions only. WHERE it sits vertically is not a constant:
-- HudController measures the real jump button and sits PLATE_JUMP_GAP above it, because the
-- numbers above are Roblox's current defaults rather than a contract.
HudLayout.PLATE_W = 92
HudLayout.PLATE_ROW_H = 22
HudLayout.PLATE_JUMP_GAP = 10

-- The one derivation in this module, rather than a bare constant, because it is the only
-- placement in the HUD that depends on something ROBLOX owns — and therefore the only one that
-- has to survive being wrong about it. Pure arithmetic, so the fallback and the clamp are
-- covered by the Lune suite; HudController does nothing but feed it two measurements.
--
--   guiBottomY : the HUD canvas's own bottom edge, in absolute screen Y
--   jumpTopY   : the jump button's top edge in the same space, or nil when there is no such
--                button (desktop), where the bottom-right corner is free anyway
function HudLayout.plateBottomOffset(guiBottomY: number, jumpTopY: number?): number
    if jumpTopY == nil then
        return HudLayout.EDGE
    end
    -- max, not a bare subtraction: AbsolutePosition is read live and can be stale for a frame
    -- after a viewport change, and a negative offset would put the plate off the bottom.
    return math.max(HudLayout.EDGE, guiBottomY - jumpTopY + HudLayout.PLATE_JUMP_GAP)
end

-- The bank button's row, directly above the throw cluster. Reserved whether or not a pot is
-- riding: an onboarding card clamped into a band that ignored it would land on the button the
-- moment a first win put one there.
HudLayout.BANK_H = 40
HudLayout.BANK_GAP = 8
```

Rewrite the cluster derivation. `AREA_H` is unchanged in value — the tape and buttons simply
swap order within it — but the comment must say so:

```luau
-- The tape+buttons cluster's own height, per tier. The TAPE IS BELOW THE BUTTONS now (owner's
-- ruling); the height is unchanged because the same two rows and one gap are in it either way.
HudLayout.AREA_H = HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.TILE
HudLayout.AREA_H_TOUCH = HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.TILE_TOUCH

-- Where the bank+throws+tape cluster's footprint begins, measured UP from the bottom edge.
-- The bank row counts whether or not its button is visible, exactly as the old slot did.
-- There is no PLATE_BOTTOM counterpart any more: the plate has left the top band entirely, so
-- the only thing an onboarding card has to clear up there is the toast (see
-- OnboardingController).
HudLayout.CLUSTER_TOP_FROM_BOTTOM = HudLayout.EDGE
    + HudLayout.AREA_H
    + HudLayout.ROW_GAP
    + HudLayout.BANK_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH = HudLayout.EDGE
    + HudLayout.AREA_H_TOUCH
    + HudLayout.ROW_GAP
    + HudLayout.BANK_H
```

Update the module header: the paragraph explaining why `AREA_H` is shared stays; the
`CONFIRM_H` paragraph goes. The closing line currently reads "No Roblox globals: **plain
numbers only**" — `plateBottomOffset` makes that false, so amend it to "No Roblox globals:
numbers, and pure arithmetic over them", and say why the one function is here (it is the only
placement that depends on something Roblox owns, so it is the one that has to be tested).

- [ ] **Step 4: Run to verify it passes**

Run: `lune run tests/run`
Expected: `HudLayout.spec` PASSES. `HudController` and `OnboardingController` are not compiled
by the Lune suite, so their stale references do not fail here — Tasks 6–10 fix them.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudLayout.luau roblox/tests/HudLayout.spec.luau
git commit -m "feat(roblox): the tape goes under the buttons and the confirm row goes away"
```

---

### Task 4: `main.client.luau` — pick state and the wire

**Files:**
- Modify: `roblox/src/client/main.client.luau`

**Interfaces:**
- Consumes: `HudModel.tapAction`, `applyTap`, `sendAtLockout`, `switchPromptExpired`,
  `SWITCH_PROMPT_SECONDS`.
- Produces: `EventBus.HudState:Fire(inputs, aux)` where `inputs` is the Task-2 `Inputs` and
  `aux` is `{ session, tape, timerKnown }` — **`aux.pick` is removed**; `view.chosen` carries
  it now.

- [ ] **Step 1: Replace the pick state**

Delete `local myPick: string? = nil` and `local selectedThrow: string? = nil`. Add:

```luau
-- THE ROUND'S PICK STATE. `chosen` is the player's commitment and `sent` is the wire's, and
-- they are separate on purpose: the pick is held here until the lockout (HudModel.sendAtLockout)
-- because ThrowBuffer is upsert-only, so sending on the first tap would make backing out a lie.
local chosen: string? = nil
local switchPrompt: string? = nil
local switchPromptAt: number? = nil
local sent = false
-- Set by a back-out, cleared when ACTIVE reopens. A player who withdrew has answered the
-- question the escalation asks, so it must not ask again this round.
local declinedThisRound = false
```

- [ ] **Step 2: Rewrite `buildInputs`**

```luau
local function buildInputs(): any
    return {
        phase = phase,
        secondsLeft = secondsLeft(),
        pointsAtStake = wallet.pointsAtStake,
        currentStreak = wallet.currentStreak,
        totalPoints = wallet.totalPoints,
        unresolvedWin = wallet.unresolvedWin,
        escalationPrompts = escalationPrompts,
        chosen = chosen,
        switchPrompt = switchPrompt,
        sent = sent,
        declinedThisRound = declinedThisRound,
    }
end
```

- [ ] **Step 3: Replace `commitPick` and the tap handler**

```luau
-- The one place a pick leaves this client, and it happens ONCE per round at the lockout.
-- `sent` is set before the fire, not after: a re-entrant heartbeat tick must not be able to
-- send the same pick twice.
local function sendPick(value: string)
    sent = true
    SubmitPick:FireServer(value)
    publish()
end
```

```luau
-- HudController fires this on every accepted tap; the MODEL decides what the tap means
-- (HudModel.tapAction) and what the state becomes (HudModel.applyTap). The controller
-- re-derives neither.
--
-- NOTHING HERE TALKS TO THE SERVER. Choosing, prompting and clearing are all local; the pick
-- goes over the wire in the heartbeat below, at the lockout.
EventBus.HudPick.Event:Connect(function(value: string)
    local action = HudModel.tapAction(buildInputs(), value)
    if action == "ignore" then
        return
    end
    local next = HudModel.applyTap({ chosen = chosen, switchPrompt = switchPrompt }, action, value)
    chosen = next.chosen
    switchPrompt = next.switchPrompt
    switchPromptAt = if switchPrompt then os.clock() else nil
    if action == "clear" then
        declinedThisRound = true
    end
    publish()
end)
```

- [ ] **Step 4: Rewrite the heartbeat**

```luau
task.spawn(function()
    while true do
        if phase == "ACTIVE" then
            roundCouldThrow = true
        end
        -- An unanswered SWITCH? ages out. Both outcomes of expiry are safe: it restores
        -- exactly the state before the stray tap.
        if HudModel.switchPromptExpired(switchPromptAt, os.clock()) then
            switchPrompt = nil
            switchPromptAt = nil
        end
        -- THE PICK'S ONE TRIP TO THE WIRE. The model decides when; this loop is simply the only
        -- thing watching the countdown, at 10Hz — close enough to the half-second boundary that
        -- the pick still makes the lockout.
        local send = HudModel.sendAtLockout(buildInputs())
        if send then
            sendPick(send)
        end
        publish()
        task.wait(TICK)
    end
end)
```

- [ ] **Step 5: Update `publish`, `roundEnded` and the round boundary**

In `publish`, drop `pick = myPick` from the `aux` table. In the `RoundUpdate` handler:

```luau
    if phase == "ACTIVE" and info.phase ~= "ACTIVE" then
        -- A STANDING CHOICE COUNTS AS PLAYED. The lockout normally sends it half a second
        -- before this fires; a choice made inside that last sliver must not be scored as an
        -- ignored round, because three of those start the escalation nagging someone who is
        -- demonstrably playing.
        roundEnded(roundCouldThrow, chosen ~= nil)
    end
    phase = info.phase
    if info.phase == "ACTIVE" then
        chosen = nil
        switchPrompt = nil
        switchPromptAt = nil
        sent = false
        declinedThisRound = false
        roundCouldThrow = true
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
        pendingReveal = nil
        drumAtRest = false
    else
        lockoutAt = nil
    end
```

In the `RevealTheater` whiff branch, replace the two clears with:

```luau
        -- and stop lighting the glyph: leaving it chosen would keep the tile illuminated
        -- through REVEAL as though it had counted, contradicting the toast.
        chosen = nil
        switchPrompt = nil
        switchPromptAt = nil
```

- [ ] **Step 6: Verify by inspection, then commit**

There is no Lune coverage for `.client.luau` files (they are Roblox-runtime). Verify by
reading: `myPick` and `selectedThrow` appear nowhere; `SubmitPick:FireServer` appears exactly
once, inside `sendPick`; `sendPick` is called only from the heartbeat.

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "myPick\|selectedThrow\|SubmitPick:FireServer" src/client/main.client.luau
git add roblox/src/client/main.client.luau
git commit -m "feat(roblox): hold the pick until the lockout so backing out is honest"
```

---

### Task 5: `main.client.luau` — park the fate branches

Separate from Task 4 so a reviewer can gate the state-machine change without the deletion
noise, and vice versa.

**Files:**
- Modify: `roblox/src/client/main.client.luau`

- [ ] **Step 1: Delete the fate wiring**

Remove, in order:
- `local FateResolvedEvt = remotes:WaitForChild("FateResolved") :: RemoteEvent`
- `local fateBound = false`
- `local pendingFate = false` and its comment block
- the `if pendingFate then … end` block inside `maybeShowReveal`
- the whole `FateResolvedEvt.OnClientEvent:Connect(…)` handler
- the `if mine and mine.result == "LOSS" then … end` block in the `RevealTheater` handler
  (the `pendingFate` set, the `maybeShowReveal()` call and the `REVEAL_SAFETY` delay). The
  whiff branch below it stays.

- [ ] **Step 2: Update the file header**

The header's bullet list mentions the fate. Replace the spoiler-gate bullet with:

```luau
--   • the DRUM-REST SPOILER GATE (see `visibleTape` / `maybeShowReveal`), which holds the tape
--     tile and the headline until the wheel stops turning,
```

and add a note under it:

```luau
--
-- FATES ARE PARKED (2026-08-03). The rock drop, the avatar grow and ACCEPT YOUR FATE are all
-- off; a LOSS now simply forfeits the pot and says so on the drum. The machinery they rode on
-- (ChoreographyMachine, EffectSelector, TheaterController) is intact and still drives the WIN,
-- SAFE and BANK effects — see the spec's §5 for where the seam is.
```

- [ ] **Step 3: Verify nothing dangles**

`REVEAL_SAFETY` must still be referenced (the `RevealResult` handler uses it). Confirm:

```bash
cd roblox && grep -n "fate\|Fate\|REVEAL_SAFETY" src/client/main.client.luau
```
Expected: only `REVEAL_SAFETY` (its definition and the `RevealResult` delay) and the header
note. No `fateBound`, no `pendingFate`, no `FateResolvedEvt`.

- [ ] **Step 4: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/client/main.client.luau
git commit -m "refactor(roblox): the client stops waiting for a fate that never comes"
```

---

### Task 6: `HudController` — the cluster reorders and the pot becomes a button

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`

**Interfaces:**
- Consumes: `HudLayout.BANK_H`, `BANK_GAP`, `AREA_H`; `view.bankVisible`, `view.pot`,
  `view.potPulses`.

- [ ] **Step 1: Swap the tape and the buttons**

The tape row moves to the bottom of `throwArea` and the buttons to the top:

```luau
-- Tape BELOW the buttons (owner's ruling): five square tiles, newest LEFT, ageing ivory ->
-- amber, with a corner dot for the personal WIN/SAFE/LOSS result. It is read, never touched,
-- so it takes the outermost edge and the buttons take the reachable one.
local tapeRow = Instance.new("Frame")
tapeRow.Name = "Tape"
tapeRow.AnchorPoint = Vector2.new(1, 1)
tapeRow.Position = UDim2.fromScale(1, 1)
```

and for each throw button and its halo, change the vertical anchor from bottom to top:

```luau
    halo.AnchorPoint = Vector2.new(0, 0)
    halo.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP) - HALO_BLEED, 0, -HALO_BLEED)
```
```luau
    b.AnchorPoint = Vector2.new(0, 0)
    b.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP), 0, 0)
```

- [ ] **Step 2: Replace the slot with one bank button**

Delete `potGroup`, `potDisc`, `potFigure`, `fateButton`, `setSlot`, and the `slotRow` frame.
Replace with:

```luau
-- ===== The bank button: directly above the throw row =====
-- ONE control, not a readout plus a button. The figure belongs IN the thing that acts on it —
-- a separate red disc saying "27" beside a generic BANK THESE made the player join two
-- elements to read one fact. Throwing again IS riding, so there is no counterpart button and
-- nothing to resolve.
local bankButton = Instance.new("TextButton")
bankButton.Name = "Bank"
bankButton.AnchorPoint = Vector2.new(1, 1)
bankButton.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP))
bankButton.Size = UDim2.fromOffset(BANK_W, BANK_H)
bankButton.BackgroundColor3 = POT_RED
bankButton.BackgroundTransparency = 0.15
bankButton.BorderSizePixel = 0
bankButton.AutoButtonColor = false
bankButton.TextColor3 = INK_CREAM
bankButton.TextSize = 15
bankButton.Font = Enum.Font.GothamBold
bankButton.Text = ""
bankButton.Visible = false
bankButton.Parent = gui
corner(bankButton, 8)
stroke(bankButton, GOLD, 1, 0.3)

bankButton.MouseButton1Click:Connect(function()
    EventBus.HudBank:Fire()
end)

-- The pulse says "this is unacknowledged", nothing more. Cancelled rather than left running,
-- and the transparency put back by hand, because Cancel leaves the property mid-tween.
local potPulse: Tween? = nil
local function setBank(visible: boolean, pot: number, pulses: boolean)
    bankButton.Visible = visible
    if visible then
        bankButton.Text = `BANK {pot} POINTS`
    end
    if potPulse then
        potPulse:Cancel()
        potPulse = nil
        bankButton.BackgroundTransparency = 0.15
    end
    if visible and pulses then
        potPulse = TweenService:Create(
            bankButton,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.6 }
        )
        (potPulse :: Tween):Play()
    end
end
```

Add `local BANK_W = 150` beside the other width constants, and `POT_RED` to the palette if
the deleted `potDisc` was the only user of that colour.

- [ ] **Step 3: Update `render`**

Replace the plate/slot lines at the top of `render` with:

```luau
    setBank(view.bankVisible, view.pot, view.potPulses)
```

(The plate lines move in Task 7; leave them for now, but delete `cellValue.pot.Text = …`
since `view.plate.pot` no longer exists.)

- [ ] **Step 4: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "potDisc\|fateButton\|setSlot\|view.slot" src/client/HudController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the pot says what banking it is worth, on the button that does it"
```

---

### Task 7: `HudController` — the plate moves to the right margin

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`

**Interfaces:**
- Consumes: `HudLayout.PLATE_W`, `PLATE_ROW_H`, `PLATE_JUMP_GAP`.

- [ ] **Step 1: Rebuild the plate**

Replace the whole `===== Plate: top-centre =====` section (the `plate` TextButton, its
three-cell loop, `cellValue`) with:

```luau
-- ===== Plate: the right margin, above the jump button =====
-- It left top-centre because that band is the middle of a phone's view. This is the strip
-- Roblox claims for jump and camera drag, and a display with NO interactive elements is the
-- one thing that can safely live in it: everything here is a Frame or a TextLabel at the
-- default Active = false, so every drag passes straight through to the camera.
--
-- The POT IS NOT HERE. It has its own button (see setBank). The streak is shown only when it
-- is non-zero — a "×0" is noise on a display whose whole job is to be ignorable.
local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(1, 1)
plate.Size = UDim2.fromOffset(PLATE_W, PLATE_ROW_H)
plate.BackgroundColor3 = WASHI
plate.BackgroundTransparency = 0.3
plate.BorderSizePixel = 0
plate.Parent = gui
corner(plate, 6)
stroke(plate, GOLD, 1, 0.35)

local streakLabel = Instance.new("TextLabel")
streakLabel.Name = "Streak"
streakLabel.Size = UDim2.new(1, 0, 0, PLATE_ROW_H)
streakLabel.Position = UDim2.fromOffset(0, 0)
streakLabel.BackgroundTransparency = 1
streakLabel.TextColor3 = GOLD
streakLabel.TextSize = 14
streakLabel.Font = Enum.Font.GothamBold
streakLabel.Text = ""
streakLabel.Visible = false
streakLabel.Parent = plate

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "Points"
pointsLabel.AnchorPoint = Vector2.new(0, 1)
pointsLabel.Position = UDim2.fromScale(0, 1)
pointsLabel.Size = UDim2.new(1, 0, 0, PLATE_ROW_H)
pointsLabel.BackgroundTransparency = 1
pointsLabel.TextColor3 = INK_CREAM
pointsLabel.TextSize = 15
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.Text = "0"
pointsLabel.Parent = plate
```

- [ ] **Step 2: Measure the jump button**

```luau
-- WHERE THE PLATE SITS IS MEASURED, NOT PREDICTED.
--
-- Roblox's default TouchJump sizes the jump button 70px on screens <=500px tall and 120px
-- above that, and positions it UDim2.new(1, -(size*1.5-10), 1, -size-20). Those are current
-- defaults, not a contract: they differ by screen size, they have changed before, and nothing
-- stops them changing again. So rather than encoding that arithmetic, the plate reads the real
-- button and sits PLATE_JUMP_GAP above its measured top edge.
--
-- The fallback is the bottom-right corner, which is where a desktop client — no TouchGui, no
-- jump button at all — should put it anyway.
local function jumpButton(): GuiObject?
    local touchGui = playerGui:FindFirstChild("TouchGui")
    local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
    return frame and frame:FindFirstChild("JumpButton") :: GuiObject?
end

-- This function MEASURES; HudLayout.plateBottomOffset decides. The arithmetic (the fallback,
-- and the clamp against a stale AbsolutePosition) lives there because it is pure and therefore
-- testable, and this file is not.
local function placePlate()
    local jump = jumpButton()
    local jumpTop: number? = if jump and jump.AbsoluteSize.Y > 0 then jump.AbsolutePosition.Y else nil
    local guiBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
    plate.Position = UDim2.new(1, -EDGE, 1, -HudLayout.plateBottomOffset(guiBottom, jumpTop))
end
```

- [ ] **Step 3: Keep it placed**

```luau
-- The jump button is not there at require time on every client, it resizes when the viewport
-- crosses the small-screen threshold, and it disappears entirely if the player docks a
-- keyboard. Watch all three rather than measuring once.
local jumpWatch: { RBXScriptConnection } = {}
local function rewatchJump()
    for _, c in jumpWatch do
        c:Disconnect()
    end
    table.clear(jumpWatch)
    local jump = jumpButton()
    if jump then
        table.insert(jumpWatch, jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(placePlate))
        table.insert(jumpWatch, jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlate))
    end
    placePlate()
end

rewatchJump()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rewatchJump)
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "TouchGui" then
        -- TouchControlFrame is built a frame or two after TouchGui itself.
        task.defer(rewatchJump)
    end
end)
playerGui.ChildRemoved:Connect(function(child)
    if child.Name == "TouchGui" then
        task.defer(rewatchJump)
    end
end)
```

Add `local playerGui = player:WaitForChild("PlayerGui")` near the top if the file does not
already resolve it. The file destructures `HudLayout`'s constants into locals (`EDGE`,
`AREA_H`, …); `plateBottomOffset` is a call, so `HudLayout` itself must also be in scope —
check the require line keeps the module bound, not just its fields.

- [ ] **Step 4: Render the plate**

In `render`, replace the three `cellValue` assignments with:

```luau
    -- A "×0" is noise on a display whose whole job is to be ignorable, so the streak row only
    -- exists when there is a streak — and the plate shrinks to one row when it goes.
    local hasStreak = view.plate.streak > 0
    streakLabel.Visible = hasStreak
    streakLabel.Text = if hasStreak then `×{view.plate.streak}` else ""
    pointsLabel.Text = tostring(view.plate.points)
    plate.Size = UDim2.fromOffset(PLATE_W, if hasStreak then PLATE_ROW_H * 2 else PLATE_ROW_H)
```

- [ ] **Step 5: Fix the day/night contrast pass**

`applyContrast` reads `plate.BackgroundTransparency`; the plate is now a `Frame` rather than a
`TextButton` but the property is the same, so that block needs no change. Confirm by reading
it, and confirm `PLATE_DAY_TRANSPARENCY` still refers to the plate that exists.

- [ ] **Step 6: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "cellValue\|PLATE_BOTTOM" src/client/HudController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the plate measures the jump button instead of guessing at it"
```

---

### Task 8: `HudController` — SWITCH?, the selection light, and the confirm strip's removal

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`

**Interfaces:**
- Consumes: `view.chosen`, `view.switchPrompt`, `view.throwsEnabled`.

- [ ] **Step 1: Delete the confirm strip**

Remove `confirmStrip`, `confirmHint`, `dontAsk`, `dontAskBox`, `dontAskLabel`, the
`CONFIRM_COPY` / `RELEASE_COPY` / `HINT_W` / `HINT_W_WIDE` / `CONFIRM_PAD` / `CONFIRM_BOX`
constants, the `dontAsk` click handler, and the `confirmStrip.Visible = …` block in `render`.

- [ ] **Step 2: Build the prompt pill**

```luau
-- ===== SWITCH?: the question raised over a glyph the player has just tapped =====
-- It sits ON the button rather than beside it, because the button is no longer offering an
-- option — it is asking a question, and covering the glyph is the clearest way to say so.
-- Answering it UNLOCKS all three; it does not select this one. That is what makes backing out
-- of a round possible at all.
--
-- No UIStroke on the label. Contrast comes from the opaque backing behind it (see the spec's
-- §3): an outline on 13px type fills the counters in and reads as a smear.
local switchPill = Instance.new("Frame")
switchPill.Name = "SwitchPrompt"
switchPill.AnchorPoint = Vector2.new(0.5, 0.5)
switchPill.Size = UDim2.fromOffset(BTN_W - 8, 24)
switchPill.BackgroundColor3 = WASHI
switchPill.BackgroundTransparency = 0
switchPill.BorderSizePixel = 0
switchPill.ZIndex = 4
switchPill.Visible = false
switchPill.Parent = throwArea
corner(switchPill, 6)
stroke(switchPill, SEL_BLUE, 2, 0)

local switchLabel = Instance.new("TextLabel")
switchLabel.Name = "Copy"
switchLabel.Size = UDim2.fromScale(1, 1)
switchLabel.BackgroundTransparency = 1
switchLabel.TextColor3 = INK_CREAM
switchLabel.TextSize = 13
switchLabel.Font = Enum.Font.GothamBold
switchLabel.Text = "SWITCH?"
switchLabel.ZIndex = 5
switchLabel.Parent = switchPill

local THROW_INDEX: { [string]: number } = {}
for i, sym in THROWS do
    THROW_INDEX[sym] = i
end

local function setSwitchPrompt(symbol: string?)
    switchPill.Visible = symbol ~= nil
    if symbol then
        local i = THROW_INDEX[symbol]
        switchPill.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP) + BTN_W / 2, 0, BTN_H / 2)
    end
end
```

- [ ] **Step 3: Give `paintThrows` the prompted state**

The prompted button must lift out of the dimmed treatment — it is the thing being asked
about, so it cannot look like a discarded option. Change the signature and the second branch:

```luau
local function paintThrows(pick: string?, enabled: boolean, prompted: string?)
```
```luau
        elseif sym == prompted then
            -- Lifted OUT of the dimmed state: this button is carrying a question, and a
            -- question on a greyed-out control reads as unanswerable.
            t.button.BackgroundColor3 = IVORY
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0.2)
            t.rim.Color = SEL_BLUE
            t.rim.Thickness = 2
            t.rim.Transparency = 0.2
            t.halo.Visible = false
        elseif pick then
```

Deepen the unchosen treatment — the owner asked for "almost disappear":

```luau
            t.button.BackgroundTransparency = 0.75
            fadeGlyph(t.glyph, 0.7)
```

Update the press handler's optimistic call to `paintThrows(sym, canThrow, nil)`.

- [ ] **Step 4: Pulse the chosen glyph**

```luau
-- The chosen glyph PULSES. A static light says "this is selected"; a pulse says "this is what
-- is going in", which is the thing the player is being asked to be sure about.
local chosenPulse: Tween? = nil
local pulsingSym: string? = nil
local function setChosenPulse(symbol: string?)
    if pulsingSym == symbol then
        return
    end
    pulsingSym = symbol
    if chosenPulse then
        chosenPulse:Cancel()
        chosenPulse = nil
    end
    for _, sym in THROWS do
        throwTiles[sym].halo.BackgroundTransparency = 0.55
    end
    if symbol then
        chosenPulse = TweenService:Create(
            throwTiles[symbol].halo,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.15 }
        )
        (chosenPulse :: Tween):Play()
    end
end
```

- [ ] **Step 5: Update `render`**

```luau
    -- The authoritative choice wins; until it has come back through main.client a press keeps
    -- its own tile lit (`pressedSym`), so a held finger does not flicker the light off on the
    -- next 10Hz repaint.
    if view.chosen then
        pressedSym = nil
    end
    local lit = view.chosen or pressedSym
    paintThrows(lit, view.throwsEnabled, view.switchPrompt)
    setChosenPulse(if view.throwsEnabled then lit else nil)
    setSwitchPrompt(view.switchPrompt)
```

- [ ] **Step 6: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "confirmStrip\|dontAsk\|aux.pick\|view.selected" src/client/HudController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): a tapped glyph asks SWITCH? instead of silently taking the round"
```

---

### Task 9: Contrast — strokes off text, and the toast

Read the spec's §3 before starting.

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`
- Modify: `roblox/src/client/OnboardingController.client.luau`

- [ ] **Step 1: Give the escalation overlay a backing**

The count and the prompt float over open canyon with no backing at all — the strokes were
standing in for one. Replace them with the real thing:

```luau
escalation.BackgroundColor3 = WASHI
escalation.BackgroundTransparency = 0.1
corner(escalation, 10)
```

and add a `UIPadding` of 12 on all four sides so the text does not touch the backing's edge.

- [ ] **Step 2: Remove every stroke on a TextLabel**

Delete these three lines:

```luau
stroke(escalationCount, WASHI, 3, 0.15)
stroke(escalationPrompt, WASHI, 2, 0.2)
```
(`HudController`, and note there is one `stroke(escalationPrompt, WASHI, 2, 0.2)` at :744)

and in `OnboardingController`, the whole `do … end` block that parents a `UIStroke` to
`copyLabel`, replacing it with a comment:

```luau
-- NO UIStroke ON THE COPY. A stroke parented to a TextLabel outlines every GLYPH: at 2px on
-- 17px type the outline approaches the stem width, the counters in a/e/o fill in, and adjacent
-- glyphs merge into a smear. That is what made these cards unreadable. The card's backing is
-- already opaque WASHI under near-white copy (~18:1) and needs no help.
```

- [ ] **Step 3: Fix the toast**

The plate has vacated top-centre, so the toast takes the band and stops being translucent:

```luau
toast.Position = UDim2.new(0.5, 0, 0, EDGE)
toast.BackgroundTransparency = 0.05
```

- [ ] **Step 4: Prove the rule holds file-wide**

```bash
cd roblox && grep -n "stroke(.*Label\|stroke(.*Count\|stroke(.*Prompt\|stroke(.*Hint\|stroke(.*Copy\|stroke(.*Text" src/client/*.luau
```
Expected: no matches. Then check for the raw form:

```bash
grep -n -B4 "UIStroke" src/client/OnboardingController.client.luau
```
Expected: the only `UIStroke` is the one parented to `card` (a TextButton acting as the
backing), never to `copyLabel` or `hintLabel`.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/client/HudController.client.luau roblox/src/client/OnboardingController.client.luau
git commit -m "fix(roblox): an outline on 17px type is a smear, not contrast"
```

---

### Task 10: `OnboardingController` — the safe band re-derives

**Files:**
- Modify: `roblox/src/client/OnboardingController.client.luau`
- Modify: `roblox/src/shared/OnboardingBeats.luau` (anchor rename only)
- Test: `roblox/tests/OnboardingBeats.spec.luau`

**Interfaces:**
- Consumes: `HudLayout.CLUSTER_TOP_FROM_BOTTOM(_TOUCH)`, `BANK_H`, `BANK_GAP`.
- Produces: `OnboardingBeats` anchor `plate` → `wallet` (it no longer points at a top-centre
  plate).

- [ ] **Step 1: Write the failing test**

In `roblox/tests/OnboardingBeats.spec.luau` add:

```luau
describe("OnboardingBeats — anchors match what the HUD actually builds", function()
    test("no beat anchors to a plate that has left the top band", function()
        for _, beat in OnboardingBeats.BEATS do
            expect(beat.anchor ~= "plate").toBe(true)
        end
    end)

    test("every anchor is one the controller knows", function()
        local known = { drum = true, throwArea = true, potIndicator = true, wallet = true }
        for _, beat in OnboardingBeats.BEATS do
            expect(known[beat.anchor] == true).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — a beat still anchors to `plate`.

- [ ] **Step 3: Rename the anchor**

In `roblox/src/shared/OnboardingBeats.luau`, change the `plate` anchor to `wallet` on whichever
beats use it, and update the module comment naming the four anchors.

- [ ] **Step 4: Re-derive the band and move the anchors**

In `OnboardingController`, replace the `PLATE_BOTTOM` constant and its use:

```luau
-- The band a card must stay inside. The plate has LEFT the top (it is in the right margin
-- now), so the only thing to clear up there is the toast, which sits at EDGE and grows
-- downward with AutomaticSize. TOAST_BAND is a reservation for it, not a measurement — a card
-- landing on a transient notice hides exactly the line that explains what just happened.
local TOAST_BAND = 64
```
```luau
    local minY = TOAST_BAND + SAFE_MARGIN + cardH
    local maxY = math.max(minY, canvas.Y - CLUSTER_TOP_FROM_BOTTOM - SAFE_MARGIN)
```

In `STATIC_ANCHORS`, replace the `plate` entry with a `wallet` entry pointing at the new
right-margin plate, and update the `throwArea` / `potIndicator` offsets for the new stack
(`SLOT_H`/`SLOT_GAP` are now `BANK_H`/`BANK_GAP`):

```luau
    -- Both sit ABOVE the whole cluster, so neither can ever cover a live button.
    throwArea = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP)),
        width = CARD_W,
    },
    potIndicator = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP)),
        width = CARD_W,
    },
    -- The wallet card points at the right-margin plate, so it is anchored to the right edge
    -- and clamped by the same band as everything else.
    wallet = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1, -EDGE, 1, -(EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP)),
        width = CARD_W,
    },
```

Update `STATIC_ANCHORS[beat.anchor] or STATIC_ANCHORS.plate` to fall back to
`STATIC_ANCHORS.throwArea`.

- [ ] **Step 5: Run and commit**

Run: `lune run tests/run` — expect PASS.

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "PLATE_BOTTOM\|SLOT_H\|SLOT_GAP\|STATIC_ANCHORS.plate" src/client/OnboardingController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/shared/OnboardingBeats.luau roblox/src/client/OnboardingController.client.luau roblox/tests/OnboardingBeats.spec.luau
git commit -m "fix(roblox): onboarding clears the toast, not a plate that has moved away"
```

---

### Task 11: Extract the takeover suspension

`LedgerController:74–150` is the only hardened movement-suspension in the codebase. The
teahouse needs it in Task 12, and a copy would duplicate the bug surface and let one panel
restore what the other suspended.

**Files:**
- Create: `roblox/src/client/Takeover.luau`
- Modify: `roblox/src/client/LedgerController.client.luau`

**Interfaces:**
- Produces: `Takeover.acquire()`, `Takeover.release()` — reference-counted; the freeze applies
  on 0→1 and lifts on 1→0.

- [ ] **Step 1: Create the module**

Move `LedgerController`'s `controls` resolution block, `suspendedVia`, `savedWalk`,
`currentHumanoid`, `setControlsEnabled`, `suspend` and `restore` verbatim into
`roblox/src/client/Takeover.luau`, changing the `[LEDGER]` log prefix to `[TAKEOVER]` and
wrapping them:

```luau
--!strict
-- Movement suspension for the takeover panels (the ledger and the teahouse).
--
-- WHY THIS IS A MODULE AND NOT A COPY IN EACH PANEL. What is below is hardened rather than
-- obvious: it prefers PlayerModule's control stack, falls back to WalkSpeed when that is
-- absent or refuses, and LATCHES which mechanism it used so a late-resolving PlayerModule
-- cannot restore a freeze the other path applied — which is what leaves someone at WalkSpeed 0
-- for good. A second copy would be a second place for that to go wrong, and with two panels
-- that hand off to each other it would also let one restore what the other suspended.
--
-- REFERENCE-COUNTED. The freeze applies on the first acquire and lifts on the last release, so
-- an ordering change (opening the teahouse before closing the ledger, rather than after) can
-- never thaw a player who is still inside a panel.
local Takeover = {}

local depth = 0

-- … moved code …

function Takeover.acquire()
    depth += 1
    if depth == 1 then
        suspend()
    end
end

function Takeover.release()
    if depth == 0 then
        return
    end
    depth -= 1
    if depth == 0 then
        restore()
    end
end

return Takeover
```

- [ ] **Step 2: Point the ledger at it**

In `LedgerController`, delete the moved code and add
`local Takeover = require(script.Parent:WaitForChild("Takeover"))` beside the `EventBus`
require. Replace the `suspend()` call in `open()` with `Takeover.acquire()` and the
`restore()` call in `close()` with `Takeover.release()`.

`close()` must stay idempotent — guard the release with the existing `isOpen` check so a
double close cannot drive the count negative (the module guards this too; both is deliberate).

- [ ] **Step 3: Confirm `default.project.json` needs no change**

`Takeover.luau` is a sibling of `EventBus.luau` inside the client folder, which the project
file maps as a directory. Verify:

```bash
grep -n "RoshamboClient" -A6 roblox/default.project.json
```
Expected: a `$path` pointing at `src/client`, so the new module is picked up with no edit.

- [ ] **Step 4: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "suspendedVia\|savedWalk\|setControlsEnabled" src/client/LedgerController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/Takeover.luau roblox/src/client/LedgerController.client.luau
git commit -m "refactor(roblox): one place knows how to give a player their legs back"
```

---

### Task 12: The teahouse becomes a takeover

**Files:**
- Modify: `roblox/src/client/TeahouseController.client.luau`

**Interfaces:**
- Consumes: `Takeover.acquire`/`release`.

- [ ] **Step 1: Make the panel viewport-relative**

The defect: `PANEL_W, PANEL_H = 340, 520` with the ✕ at
`viewportHeight − (PANEL_BOTTOM + PANEL_H) + CLOSE_INSET` = `viewportHeight − 572`. On a
landscape phone (~400px) that is ~170px above the top of the screen, unconditionally — there
is no clamp anywhere in that path. Replace the constants and the panel's geometry:

```luau
-- A TAKEOVER, on the ledger's pattern — which is the pattern that does not have the bug this
-- panel had. It was 520px tall at a fixed offset from the bottom, so on any viewport shorter
-- than 580px the ✕ sat ABOVE THE TOP OF THE SCREEN and the panel could not be dismissed at
-- all. Sizing against the viewport rather than in absolute pixels is what makes that
-- impossible rather than merely unlikely.
local PANEL_MARGIN = 12
local HEADER_H = 44
local CLOSE_W = 34
```
```luau
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -2 * PANEL_MARGIN, 1, -2 * PANEL_MARGIN)
```

Set the GUI's layer above the HUD:

```luau
gui.DisplayOrder = 20 -- a takeover, same layer as the ledger; only one is ever open
```

- [ ] **Step 2: Move the ✕ inside the panel**

```luau
-- INSIDE the panel's own header, positioned against the panel rather than against a fixed
-- offset from the viewport edge. That offset is what put it off-screen.
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -PANEL_MARGIN, 0, (HEADER_H - CLOSE_W) / 2)
closeButton.Size = UDim2.fromOffset(CLOSE_W, CLOSE_W)
closeButton.ZIndex = 3
closeButton.Parent = panel
```

Delete `PANEL_W`, `PANEL_H`, `PANEL_BOTTOM`, `CLOSE_INSET`, `CLOSE_SIZE` and every remaining
reference. Any child positioned relative to the old fixed panel size must be re-anchored in
scale or offset from the header — read the whole file and fix each one; a child laid out
against a 340×520 assumption will be wrong at every other size.

- [ ] **Step 3: Suspend movement**

```luau
local Takeover = require(script.Parent:WaitForChild("Takeover"))
```
```luau
local function setOpen(shouldOpen: boolean)
    if shouldOpen == isOpen then
        return -- idempotent: a double open must not double-acquire
    end
    isOpen = shouldOpen
    panel.Visible = shouldOpen
    closeButton.Visible = shouldOpen
    if shouldOpen then
        Takeover.acquire()
    else
        Takeover.release()
    end
end
```

Add `local isOpen = false` if the file does not already track it, and audit every existing
`setOpen(false)` call site — with the guard above, calling it while already closed is now a
no-op rather than a spurious release.

- [ ] **Step 4: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "PANEL_H\|PANEL_BOTTOM\|CLOSE_INSET\|CLOSE_SIZE" src/client/TeahouseController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/TeahouseController.client.luau
git commit -m "fix(roblox): the teahouse ✕ was 170px above the top of a phone screen"
```

---

### Task 13: Park the fates

**Files:**
- Modify: `roblox/src/shared/EffectRegistry.luau`
- Modify: `roblox/src/server/main.server.luau`
- Test: `roblox/tests/EffectSelector.spec.luau`

- [ ] **Step 1: Write the failing test**

In `roblox/tests/EffectSelector.spec.luau`, add a block that reads the REAL registry (the
existing tests use a fixture, and must keep doing so):

```luau
local EffectRegistry = require("../src/shared/EffectRegistry")

describe("EffectRegistry — fates are parked", function()
    test("LOSS selects to nothing, for every world throw", function()
        local selector = EffectSelector.new(EffectRegistry, { random = function()
            return 0
        end })
        for _, w in { "R", "P", "S" } do
            expect(selector:select("LOSS", { worldThrow = w })).toBe(nil)
        end
    end)

    test("the celebrations are untouched", function()
        local selector = EffectSelector.new(EffectRegistry, { random = function()
            return 0
        end })
        for _, slot in { "REVEAL", "WIN", "SAFE", "BANK" } do
            expect(selector:select(slot, {}) ~= nil).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — `LOSS` returns `fateBoulder`/`fatePaper`/`fateShears`.

- [ ] **Step 3: Park the registry**

```luau
    -- PARKED 2026-08-03. LOSS used to select fateBoulder/fatePaper/fateShears, which
    -- FateController turned into a rock chasing the player. The owner withdrew the idea; the
    -- machinery stays because celebration effects will be built on it.
    --
    -- THIS EMPTY POOL IS THE WHOLE PARK for the client visuals: EffectSelector returns nil for
    -- an empty pool, so no `fate*` effect ever reaches FateController's cue guard and that file
    -- needs no edit at all. Re-enabling fates means putting the byThrow table back — a
    -- deliberate act that breaks the test above rather than a silent one.
    LOSS = {},
```

- [ ] **Step 4: Stop the server driving it**

In `roblox/src/server/main.server.luau`, delete `applyGrow` and `growDelaySeconds` entirely,
and replace the per-player reveal branch with:

```luau
                if mine then
                    profiles:applyLocalResult(userId, mine.result)
                    pushStats(player)
                    fireProfile(player, "local")
                end
```

Delete the now-unused `local growIn = growDelaySeconds()` line above the loop, the
`fates:begin(userId)` call, and any `TweenService` / `DrumStep` require that has no other
user. **Check each before deleting** — selene fails on an unused require, and it fails just as
hard on a deleted one that was still needed:

```bash
cd roblox && grep -n "TweenService\|DrumStep\|fates:" src/server/main.server.luau
```

Keep `FateRegistry`, `local fates = FateRegistry.new()` and the `fates:isBound` gate in
`SubmitPick`, and mark the seam:

```luau
    -- PARKED, not removed. Nothing calls fates:begin any more (see the reveal handler), so this
    -- is always false — it is one table lookup and it is the seam anything like this re-enters
    -- through. FateRegistry and its tests are intact.
    if fates:isBound(tostring(player.UserId)) then
```

- [ ] **Step 5: Record the timing recipe before it is deleted**

`growDelaySeconds` held the reveal-timing lesson. Add it above the `onReveal` handler:

```luau
        -- WHEN CELEBRATIONS COME BACK, FIRE THEM ON THE DRUM, NOT ON THE WIRE. RevealTheater
        -- lands ~3s before the drum settles, so anything triggered on the remote is early. The
        -- recipe the deleted applyGrow used: delay by
        -- math.clamp(StrikeAtServerTime - workspace:GetServerTimeNow() + DrumStep.SETTLE_SECONDS,
        -- 0, DrumStep.SETTLE_SECONDS + TallySec) — clamped so it fails late, never early.
        --
        -- And it has to be SERVER-side: Humanoid scale replicates server->client only, so an
        -- avatar effect triggered on the client is visible to nobody but its owner.
        onReveal = function(reveal)
```

- [ ] **Step 6: Run and commit**

Run: `lune run tests/run` — expect PASS.

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/EffectRegistry.luau roblox/src/server/main.server.luau roblox/tests/EffectSelector.spec.luau
git commit -m "feat(roblox): park the fates at the one line that summons them"
```

---

### Task 14: Retire `confirmThrows`

**Files:**
- Modify: `roblox/src/client/LedgerController.client.luau`
- Modify: `roblox/src/client/main.client.luau`
- Modify: `server/src/routes/apiV1.ts`
- Test: `server/src/routes/apiV1.test.ts`

- [ ] **Step 1: Write the failing server test**

In `server/src/routes/apiV1.test.ts`, add:

```ts
describe('PUT /players/:id/preferences-hud — confirmThrows is retired', () => {
    it('ignores a confirmThrows key rather than persisting it', async () => {
        const res = await request(app)
            .put(`/api/v1/players/${robloxId}/preferences-hud`)
            .set('X-API-Key', API_KEY)
            .send({ confirmThrows: false, escalationPrompts: false });
        expect(res.status).toBe(200);
        expect(res.body).not.toHaveProperty('confirmThrows');
        expect(res.body.escalationPrompts).toBe(false);
    });

    it('does not ship confirmThrows in the profile payload', async () => {
        const res = await request(app)
            .get(`/api/v1/players/${robloxId}`)
            .set('X-API-Key', API_KEY);
        expect(res.body).not.toHaveProperty('confirmThrows');
    });
});
```

Match the existing file's setup helpers rather than the placeholder names above — read the
tests already in it and reuse their app/auth/fixture scaffolding.

- [ ] **Step 2: Run to verify it fails**

Run from `server/`: `npm test`
Expected: FAIL — `confirmThrows` is present in both payloads.

- [ ] **Step 3: Retire it server-side**

In `server/src/routes/apiV1.ts` delete line 26 (`confirmThrows: user.confirmThrows ?? true`),
the `if (typeof req.body?.confirmThrows === 'boolean')` block at :140–141, and
`confirmThrows: s.confirmThrows ?? true` at :158.

**Leave `server/src/models/User.ts` alone.** The Mongo field stays — dropping it needs a
migration and buys nothing, and a defaulted field nobody reads is inert.

- [ ] **Step 4: Retire it client-side**

In `LedgerController`: delete `confirmSwitch` and its construction, `local confirmThrows = true`,
the `paintOne(confirmSwitch, confirmThrows)` line, the `confirmSwitch` click handler, and the
`state.confirmThrows` branch in the `LedgerState` handler. The footer is now one switch —
check the two-column layout still reads with a single occupant and centre it if not.

In `main.client.luau`: delete `local confirmThrows = true`, the `body.confirmThrows` branch in
the `HudPreference` handler, the `p.confirmThrows` branch in `ProfileUpdate`, and
`confirmThrows = confirmThrows` from `publishLedger`.

- [ ] **Step 5: Run both suites and commit**

```bash
cd server && npm test
cd ../roblox && lune run tests/run && stylua src tests tools && selene src tools
grep -rn "confirmThrows" src/ ../server/src/routes/
```
Expected: no matches outside `server/src/models/User.ts`.

```bash
git add roblox/src/client/LedgerController.client.luau roblox/src/client/main.client.luau server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "refactor: retire the preference that guarded a confirmation that no longer exists"
```

---

## Final verification

Before the branch is done, from the repo root:

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools
cd ../server && npm test
cd .. && git status --porcelain
```

All four must be clean. Then push — the App Runner dev service auto-deploys the working
branch, so Studio picks up the server half a few minutes later.

## The owner's Studio gate

Nothing in this plan can verify:

1. whether the dimmed unchosen glyphs read as "almost disappeared" at 0.75/0.7
2. whether `SWITCH?` is legible at 13px on a 44px button
3. whether the plate clears the jump button on a real phone (it measures, but the measurement
   is only as good as `TouchControlFrame` being where we look for it)
4. whether one switch alone reads correctly in the preferences footer
