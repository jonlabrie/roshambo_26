### Task 1: The metronome knows what phase it is

**Files:**
- Modify: `roblox/src/shared/RoundMetronome.luau`
- Test: `roblox/tests/RoundMetronome.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Task 2: two new fields on `Reading` —
  - `phase: string` — `"ACTIVE"` | `"TALLY"` | `"REVEAL"`
  - `secondsLeft: number` — seconds until the next phase boundary
- Everything already on `Reading` (`drawP`, `camAngle`, `omega`, `periodSec`, `prevStrikeAt`, `nextStrikeAt`) is unchanged. `HammerController` must keep working untouched.

**Context:** `read()` already computes everything needed. It derives `roundStart` (the strike, less `activeSec + tallySec`, snapped into the current period) and `drawP` (position through the period, 0–1). The phase is that position measured against the three durations. This is arithmetic the module already does; it just doesn't report it.

The phase layout within a period, measured from `roundStart`:

```
[0, activeSec)                          ACTIVE
[activeSec, activeSec+tallySec)         TALLY
[activeSec+tallySec, periodSec)         REVEAL     <- the strike is at its first instant
```

- [ ] **Step 1: Write the failing tests**

Add to `roblox/tests/RoundMetronome.spec.luau`. Follow the file's existing style for constructing a metronome and setting a schedule.

```lua
describe("RoundMetronome — the phase, read off the same timeline as the cam", function()
    -- A 27s round: 20 active, 2 tally, 5 reveal, with the strike at the first
    -- instant of REVEAL (activeSec + tallySec into the period), which is how
    -- RoundCoordinator publishes it.
    local function m27()
        local m = RoundMetronome.new()
        m:setSchedule({
            roundId = "r1",
            strikeAt = 1000,
            periodSec = 27,
            activeSec = 20,
            tallySec = 2,
            revealSec = 5,
        }, 1000)
        return m
    end

    test("the strike instant is the first instant of REVEAL", function()
        -- This is the anchor the whole timeline hangs off. If it drifts, every
        -- phase boundary drifts with it.
        expect(m27():read(1000).phase).toBe("REVEAL")
    end)

    test("it walks the period in order", function()
        local m = m27()
        local roundStart = 1000 - 22 -- strike less (active + tally)
        expect(m:read(roundStart).phase).toBe("ACTIVE")
        expect(m:read(roundStart + 19.9).phase).toBe("ACTIVE")
        expect(m:read(roundStart + 20).phase).toBe("TALLY")
        expect(m:read(roundStart + 21.9).phase).toBe("TALLY")
        expect(m:read(roundStart + 22).phase).toBe("REVEAL")
        expect(m:read(roundStart + 26.9).phase).toBe("REVEAL")
    end)

    test("boundaries are half-open — a phase owns its start, not its end", function()
        -- Closed-closed would make one instant belong to two phases, and whichever
        -- the caller sampled first would win. That is the kind of ambiguity that
        -- shows up once an hour and is never reproducible.
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart + 20).phase).toBe("TALLY")
        expect(m:read(roundStart + 22).phase).toBe("REVEAL")
        expect(m:read(roundStart + 27).phase).toBe("ACTIVE") -- the next round
    end)

    test("it repeats every period, forwards and backwards", function()
        local m = m27()
        local roundStart = 1000 - 22
        for _, k in { -3, -1, 0, 1, 5 } do
            local base = roundStart + k * 27
            expect(m:read(base + 1).phase).toBe("ACTIVE")
            expect(m:read(base + 21).phase).toBe("TALLY")
            expect(m:read(base + 23).phase).toBe("REVEAL")
        end
    end)

    test("secondsLeft counts down to the NEXT boundary, not the round's end", function()
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart).secondsLeft).toBeCloseTo(20, 0.001)
        expect(m:read(roundStart + 19).secondsLeft).toBeCloseTo(1, 0.001)
        expect(m:read(roundStart + 20).secondsLeft).toBeCloseTo(2, 0.001) -- TALLY's whole length
        expect(m:read(roundStart + 22).secondsLeft).toBeCloseTo(5, 0.001) -- REVEAL's
    end)

    test("secondsLeft is never negative and never exceeds its phase", function()
        local m = m27()
        local roundStart = 1000 - 22
        for i = 0, 270 do
            local r = m:read(roundStart + i / 10)
            expect(r.secondsLeft >= 0).toBe(true)
            expect(r.secondsLeft <= 20).toBe(true)
        end
    end)

    test("no schedule, no phase", function()
        -- read() already returns nil before a schedule lands; the new fields must
        -- not tempt a caller into treating an unsynced client as being mid-round.
        expect(RoundMetronome.new():read(100)).toBeNil()
    end)
end)
```

- [ ] **Step 2: Run and watch them fail**

`cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox && lune run tests/run`
Expected: FAIL — `phase` and `secondsLeft` are nil.

- [ ] **Step 3: Implement**

In `read()`, after `roundStart` and `drawP` are computed, derive the phase from the elapsed position and return the two new fields. Add them to the `Reading` type.

```lua
    -- THE PHASE, off the same timeline as the cam above — not a second source of
    -- truth. `elapsed` is where `now` sits inside the round that contains it, so
    -- the phase is that position measured against the three durations.
    --
    -- HALF-OPEN boundaries: a phase owns its start instant and not its end. Closed
    -- intervals would make the boundary belong to two phases at once, and whichever
    -- a caller sampled first would win.
    local elapsed = now - roundStart
    local activeEnd = self._activeSec
    local tallyEnd = activeEnd + self._tallySec
    local phase, phaseEndsAt
    if elapsed < activeEnd then
        phase, phaseEndsAt = "ACTIVE", activeEnd
    elseif elapsed < tallyEnd then
        phase, phaseEndsAt = "TALLY", tallyEnd
    else
        phase, phaseEndsAt = "REVEAL", period
    end
```

and return `phase = phase, secondsLeft = math.max(0, phaseEndsAt - elapsed)`.

Read the existing locals before writing this — `roundStart`, `period` and the stored `_activeSec` / `_tallySec` are all already in scope in `read()`. Do not recompute them.

- [ ] **Step 4: Run, then prove the tests bite**

`lune run tests/run` — expected: PASS.

Then mutate and confirm failures, restoring after each:
1. change `elapsed < activeEnd` to `elapsed <= activeEnd` → the half-open test must fail
2. return `period - elapsed` for `secondsLeft` in every branch (the round's end rather than the phase's) → the countdown test must fail
3. swap the `ACTIVE` and `REVEAL` labels → the walk test must fail

Quote the real failure output. **If any mutation does not fail, that test is decoration — say so rather than moving on.**

- [ ] **Step 5: Confirm nothing regressed for the bell**

`HammerController` reads `drawP`, `camAngle`, `omega` and the strike instants. Confirm none of those computations changed and that every pre-existing test in the spec file still passes untouched.

- [ ] **Step 6: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RoundMetronome.luau roblox/tests/RoundMetronome.spec.luau
git commit -m "feat(roblox): the round's timeline can say what phase it is"
```

---

