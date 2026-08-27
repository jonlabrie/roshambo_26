### Task 2: `HudModel` — one threshold, a shorter fuse, and dismissal

**Files:** Modify `roblox/src/shared/HudModel.luau`, `roblox/tests/HudModel.spec.luau`.

**Interfaces:**
- Produces: `HudModel.ESCALATE_AT` (was a file-local, now exported — the ring reads it);
  `SWITCH_PROMPT_SECONDS` = 1.
- `declinedThisRound` gains a second meaning; no new field.

- [ ] **Step 1: Write the failing tests**

```luau
describe("HudModel.ESCALATE_AT is shared, not copied", function()
    test("it is exported so the ring can read the same threshold", function()
        -- The ring and the prompt must turn urgent at the SAME moment (spec §5). A second
        -- literal anywhere would be two alarms about one fact.
        expect(type(HudModel.ESCALATE_AT)).toBe("number")
    end)

    test("escalate fires exactly at the exported threshold and not above", function()
        local at = HudModel.ESCALATE_AT
        expect(HudModel.view(inputs({ secondsLeft = at }), session(0)).escalate).toBe(true)
        expect(HudModel.view(inputs({ secondsLeft = at + 0.01 }), session(0)).escalate).toBe(false)
    end)
end)

describe("HudModel.SWITCH_PROMPT_SECONDS — a one-second fuse", function()
    test("it is one second", function()
        expect(HudModel.SWITCH_PROMPT_SECONDS).toBe(1)
    end)

    test("the prompt survives just under and expires at the second", function()
        local t = 100
        expect(HudModel.switchPromptExpired(t, t + 0.99)).toBe(false)
        expect(HudModel.switchPromptExpired(t, t + 1)).toBe(true)
    end)
end)

describe("HudModel — dismissing the nag is not declining the round", function()
    test("a dismissal silences escalation for the round", function()
        local v = HudModel.view(inputs({ secondsLeft = 2, declinedThisRound = true }), session(0))
        expect(v.escalate).toBe(false)
    end)

    test("but it does NOT stop the player throwing", function()
        -- Dismissing means "stop shouting", not "I'm out". The buttons stay live.
        local v = HudModel.view(inputs({ secondsLeft = 2, declinedThisRound = true }), session(0))
        expect(v.throwsEnabled).toBe(true)
    end)

    test("and a throw after a dismissal still counts as played", function()
        local st = HudModel.applyTap({ chosen = nil, switchPrompt = nil }, "choose", "R")
        expect(st.chosen).toBe("R")
        expect(HudModel.sendAtLockout(inputs({ chosen = "R", secondsLeft = 0.2, declinedThisRound = true }))).toBe("R")
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Expect FAIL — `HudModel.ESCALATE_AT` is nil and `SWITCH_PROMPT_SECONDS` is 4.

- [ ] **Step 3: Implement**

Change `local ESCALATE_AT = 5` to `HudModel.ESCALATE_AT = 5` and update its two uses in `view`.
Change `HudModel.SWITCH_PROMPT_SECONDS = 4` to `1`, and rewrite its comment:

```luau
-- ONE SECOND. Four was chosen when a prompt was the only thing on screen and in practice it
-- lingered. Both outcomes of expiry are safe — expiring restores exactly the state before the
-- stray tap, and answering only ever unlocks — so a short fuse costs nothing and a long one
-- leaves a question hanging over a live button.
HudModel.SWITCH_PROMPT_SECONDS = 1
```

Extend `declinedThisRound`'s comment in `Inputs`:

```luau
    -- Set by a back-out OR by dismissing the escalation prompt, cleared when ACTIVE reopens.
    -- One field, two gestures, because they mean the same thing to this rule: the player has
    -- answered the question the prompt asks. It silences the prompt and NOTHING else — throws
    -- stay live, and a throw after a dismissal is an ordinary throw.
    declinedThisRound: boolean,
```

- [ ] **Step 4: Verify pass, then verify the threshold is genuinely shared**

Run `lune run tests/run` — expect PASS. Then change `HudModel.ESCALATE_AT` to 9, re-run, and
confirm the escalate-boundary test FAILS. Revert. **Report the count.**

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
git commit -m "feat(roblox): one urgency threshold, and a prompt that does not linger"
```

---

