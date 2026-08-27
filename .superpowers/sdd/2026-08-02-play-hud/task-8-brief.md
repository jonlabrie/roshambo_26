### Task 8: `OnboardingBeats` — the beat machine

Four beats, each fired by the event it explains, each shown once.

**Files:**
- Create: `roblox/src/shared/OnboardingBeats.luau`
- Test: `roblox/tests/OnboardingBeats.spec.luau`

**Interfaces:**
- Produces: `OnboardingBeats.BEATS: { Beat }` where `Beat = { id: string, event: string, copy: string, anchor: string }`
- Produces: `OnboardingBeats.next(seen: { string }, event: string): Beat?`

- [ ] **Step 1: Write the failing test**

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Beats = require("../src/shared/OnboardingBeats")

describe("OnboardingBeats", function()
    test("there are exactly four beats, in order, with distinct ids", function()
        expect(#Beats.BEATS).toBe(4)
        local ids = {}
        for _, b in Beats.BEATS do
            expect(ids[b.id]).toBe(nil)
            ids[b.id] = true
            expect(#b.copy > 0).toBe(true)
            expect(#b.anchor > 0).toBe(true)
        end
    end)

    test("no beat teaches movement — that is deliberate", function()
        -- the design de-emphasises movement and the owner narrates in person
        for _, b in Beats.BEATS do
            expect(b.id ~= "move").toBe(true)
        end
    end)

    test("an event returns its beat when unseen", function()
        local b = Beats.next({}, "join")
        expect(b ~= nil).toBe(true)
        expect(b.event).toBe("join")
    end)

    test("a seen beat never returns again", function()
        local b = Beats.next({}, "join")
        expect(Beats.next({ b.id }, "join")).toBe(nil)
    end)

    test("an unknown event returns nothing", function()
        expect(Beats.next({}, "sneezed")).toBe(nil)
    end)

    test("beats are independent — seeing one does not consume another", function()
        local first = Beats.next({}, "join")
        local second = Beats.next({ first.id }, "win")
        expect(second ~= nil).toBe(true)
        expect(second.event).toBe("win")
    end)

    test("events may arrive out of order", function()
        -- a player can win before anyone has explained the drum; the win beat still fires
        local b = Beats.next({}, "win")
        expect(b ~= nil).toBe(true)
        expect(b.event).toBe("win")
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run` → FAIL, module missing.

- [ ] **Step 3: Write the module**

```luau
--!strict
-- Onboarding beats. Each is fired by the event it explains rather than queued at join, so a
-- first-timer never reads ahead of themselves — the win beat appears at their first win, not
-- before they know what a win is. Bones, not a tutorial: the owner is narrating in person.
--
-- There is deliberately NO beat about movement or exploration. The HUD is designed to
-- de-emphasise movement, and a beat pointing at the thumbstick would undo that.
local OnboardingBeats = {}

export type Beat = { id: string, event: string, copy: string, anchor: string }

OnboardingBeats.BEATS = {
    { id = "drum", event = "join", copy = "The drum throws every minute. Beat it.", anchor = "drum" },
    { id = "throw", event = "throwsUnlocked", copy = "Tap a throw.", anchor = "throwArea" },
    {
        id = "win",
        event = "win",
        copy = "You won. Take it, or ride it — a win triples your pot.",
        anchor = "choiceOverlay",
    },
    { id = "bank", event = "bank", copy = "Banked. That's yours to keep.", anchor = "plate" },
} :: { Beat }

function OnboardingBeats.next(seen: { string }, event: string): Beat?
    local seenSet: { [string]: boolean } = {}
    for _, id in seen do
        seenSet[id] = true
    end
    for _, beat in OnboardingBeats.BEATS do
        if beat.event == event and not seenSet[beat.id] then
            return beat
        end
    end
    return nil
end

return OnboardingBeats
```

- [ ] **Step 4: Run the tests, gates, and commit**

```bash
lune run tests/run
stylua --check src tests tools && selene src tools
git add roblox/src/shared/OnboardingBeats.luau roblox/tests/OnboardingBeats.spec.luau
git commit -m "feat(roblox): OnboardingBeats — four event-triggered first-run beats"
```

---

