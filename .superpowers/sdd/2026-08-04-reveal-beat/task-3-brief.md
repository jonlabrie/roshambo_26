### Task 3: RevealBeat — the beat's timings, in one place

**Files:**
- Create: `roblox/src/shared/RevealBeat.luau`
- Create: `roblox/tests/RevealBeat.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Tasks 4 and 5:
  - `RevealBeat.HOLD_SECONDS` — how long the glyph sits before it starts to go
  - `RevealBeat.FADE_SECONDS` — how long it takes to go
  - `RevealBeat.TAPE_DELAY_SECONDS` — when the tape tile lands, measured from `drumRest`
  - `RevealBeat.RUNWAY_SECONDS` — the measured budget, for the headroom test

**Context:** Two files must agree about this beat: `main.client.luau` schedules it, `HudController` animates the fade. A duration hand-copied into both is the drift this module exists to prevent. Small, pure, Lune-testable.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/RevealBeat.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RevealBeat = require("../src/shared/RevealBeat")

describe("RevealBeat — the sequence after the drum stops", function()
    test("the glyph gets a real beat, not a flash", function()
        -- The owner asked for "a few seconds". Before this, the glyph lived on leftover time and
        -- measured 3.03s, 1.81s and 4.15s across three consecutive rounds — the variance is what
        -- made it read as absent.
        expect(RevealBeat.HOLD_SECONDS >= 1.5).toBe(true)
        expect(RevealBeat.FADE_SECONDS > 0).toBe(true)
    end)

    test("the tape lands AFTER the glyph has fully gone", function()
        -- THE ORDERING THE WHOLE BEAT EXISTS FOR. The tape tile arriving with the glyph is what
        -- made the glyph invisible: three things in one frame and the smallest loses.
        expect(RevealBeat.TAPE_DELAY_SECONDS).toBe(RevealBeat.HOLD_SECONDS + RevealBeat.FADE_SECONDS)
    end)

    test("the whole beat fits the runway, with headroom", function()
        -- RUNWAY_SECONDS is measured, not guessed: the drum rests ~3.2s into the gap between
        -- rounds, and Task 2 made that gap TALLY(2) + REVEAL(5) = 7s.
        expect(RevealBeat.TAPE_DELAY_SECONDS < RevealBeat.RUNWAY_SECONDS).toBe(true)
        -- Not merely fitting: the tape must be readable before the next round opens.
        expect(RevealBeat.RUNWAY_SECONDS - RevealBeat.TAPE_DELAY_SECONDS >= 1).toBe(true)
    end)

    test("it holds no Roblox globals — numbers only", function()
        for key, value in RevealBeat do
            expect(typeof(key)).toBe("string")
            expect(typeof(value)).toBe("number")
        end
    end)
end)
```

- [ ] **Step 2: Run and watch it fail**

`cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox && lune run tests/run`
Expected: FAIL — the module does not exist.

- [ ] **Step 3: Create the module**

```lua
--!strict
-- THE REVEAL BEAT. What happens after the drum comes fully to rest, and when.
--
-- THE RULE THIS SERVES (owner, 2026-08-04): the drum is authoritative, and must always be fully at
-- rest before the world throw is reflected anywhere else. Everything here is measured from
-- `drumRest` — nothing in this module may ever be used to show something earlier.
--
-- WHY A BEAT AT ALL. The glyph in the ring and the new tape tile used to appear in the same frame,
-- so three things arrived at one instant and the smallest lost — which is why the glyph read as
-- missing even while it was rendering. And its lifetime was leftover time, not a designed span:
-- 3.03s, 1.81s and 4.15s across three consecutive measured rounds, ending abruptly with no fade
-- whenever the next round happened to open.
--
-- TWO FILES MUST AGREE about these numbers — main.client.luau schedules the beat, HudController
-- animates the fade — so they live here rather than as a literal in each. No Roblox globals; this
-- runs under Lune like everything else in src/shared.
local RevealBeat = {}

-- How long the glyph sits before it begins to go. The owner asked for "a few seconds"; this is the
-- first thing to tune at a Studio gate, which is why it is named rather than inline.
RevealBeat.HOLD_SECONDS = 2

-- A real fade, not a Visible toggle. A toggle is what it did before, and part of why it read as a
-- flicker rather than a reveal.
RevealBeat.FADE_SECONDS = 0.4

-- When the tape tile lands, measured from drumRest. AFTER the glyph is fully gone — the tape is the
-- round's RECORD, and a record arriving with the announcement is what buried the announcement.
RevealBeat.TAPE_DELAY_SECONDS = RevealBeat.HOLD_SECONDS + RevealBeat.FADE_SECONDS

-- How much time actually exists after the drum stops, MEASURED (Studio, 2026-08-04) rather than
-- derived: the drum rests ~3.2s into the gap between rounds, and that gap is TALLY(2) + REVEAL(5)
-- = 7s once the server change lands. Held here only so the spec test can assert the beat fits with
-- room to read the tape afterwards. If the server's phase durations change, this changes with them.
RevealBeat.RUNWAY_SECONDS = 3.8

return RevealBeat
```

- [ ] **Step 4: Run, then verify the ordering test is not vacuous**

`lune run tests/run` — expected: PASS.

Then set `TAPE_DELAY_SECONDS = RevealBeat.HOLD_SECONDS` (i.e. the tape landing mid-fade) and re-run. Expected: the ordering test fails. Restore. Quote the output in your report — that test is the entire point of the module and nothing else can catch it.

- [ ] **Step 5: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RevealBeat.luau roblox/tests/RevealBeat.spec.luau
git commit -m "feat(roblox): the reveal beat's timings, where both files can see them"
```

---

