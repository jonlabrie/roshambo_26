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

