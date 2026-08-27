### Task 2: RollingNumber scales with the distance, and turns its easing over

**Files:**
- Modify: `roblox/src/shared/RollingNumber.luau`
- Test: `roblox/tests/RollingNumber.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Task 3:
  - `RollingNumber.MIN_DURATION`, `RollingNumber.MAX_DURATION`, `RollingNumber.SCALE_CAP`
  - `RollingNumber.durationFor(delta: number): number`
  - `RollingNumber.valueAt(from, to, t)` — signature unchanged, **easing changed**
- Deleted: `RollingNumber.DURATION`. Task 3 must stop reading it.

**Context:** Banking 2000 points transferred almost instantly because the duration is a flat 0.5s regardless of amount, and the quadratic ease-out puts three quarters of the count in the first half. Both change here; the third defect (10Hz repaint) is Task 3.

- [ ] **Step 1: Write the failing tests**

In `roblox/tests/RollingNumber.spec.luau`, replace the `describe("RollingNumber.DURATION", ...)` block entirely with:

```lua
describe("RollingNumber.durationFor — a big bank should feel like a payoff", function()
    test("the flat DURATION is gone", function()
        -- One constant for every amount is what made 2000 points transfer in the same half
        -- second as 1. Every caller derives its own now; leaving the old one behind would let
        -- two counters that must finish together run on different curves.
        expect((RollingNumber :: any).DURATION).toBe(nil)
    end)

    test("a zero move still returns a usable, positive duration", function()
        -- Callers divide by this. A zero would be a divide-by-zero on the one path where
        -- nothing actually moves.
        expect(RollingNumber.durationFor(0)).toBe(RollingNumber.MIN_DURATION)
        expect(RollingNumber.durationFor(0) > 0).toBe(true)
    end)

    test("direction does not matter — only distance", function()
        -- The bank button drains while the balance fills. They are one event and must finish
        -- together, so the count DOWN has to take exactly as long as the count up.
        for _, d in { 1, 7, 250, 3000, 99999 } do
            expect(RollingNumber.durationFor(-d)).toBe(RollingNumber.durationFor(d))
        end
    end)

    test("it never leaves [MIN_DURATION, MAX_DURATION]", function()
        for _, d in { 0, 1, 5, 60, 400, 3000, 10000, 250000 } do
            local v = RollingNumber.durationFor(d)
            expect(v >= RollingNumber.MIN_DURATION).toBe(true)
            expect(v <= RollingNumber.MAX_DURATION).toBe(true)
        end
    end)

    test("it is monotonic in distance", function()
        local prev = -1
        for i = 0, 200 do
            local v = RollingNumber.durationFor(i * 60)
            expect(v >= prev).toBe(true)
            prev = v
        end
    end)

    test("beyond the cap it is exactly MAX_DURATION — no pot runs away with the screen", function()
        expect(RollingNumber.durationFor(RollingNumber.SCALE_CAP)).toBe(RollingNumber.MAX_DURATION)
        expect(RollingNumber.durationFor(RollingNumber.SCALE_CAP * 100)).toBe(RollingNumber.MAX_DURATION)
    end)

    test("the curve's shape: a big bank takes seconds, a small one does not", function()
        -- Pins the FEEL the owner asked for without over-pinning the exact function. A linear
        -- ramp would put 30 points at ~0.4s and 3000 at ~1.0s and fail both bounds.
        expect(RollingNumber.durationFor(30) > 0.9).toBe(true)
        expect(RollingNumber.durationFor(30) < 1.5).toBe(true)
        expect(RollingNumber.durationFor(3000) > 2.0).toBe(true)
        expect(RollingNumber.durationFor(3000) < 2.45).toBe(true)
        expect(RollingNumber.durationFor(3000) > RollingNumber.durationFor(30) + 0.8).toBe(true)
    end)
end)

describe("RollingNumber.valueAt — the easing is a payoff, not a decay", function()
    test("the midpoint is the midpoint", function()
        -- THE test that pins the change. Smoothstep is symmetric: half the time, half the
        -- points. The quadratic ease-out this replaces returned 75 here — three quarters of a
        -- 2-second count landing in the first second and the rest crawling.
        expect(RollingNumber.valueAt(0, 100, 0.5)).toBe(50)
    end)

    test("it winds up rather than bolting", function()
        -- A quarter of the way through, well under a quarter of the way there. The old
        -- ease-out was at 44 by this point.
        expect(RollingNumber.valueAt(0, 100, 0.25) < 25).toBe(true)
        expect(RollingNumber.valueAt(0, 100, 0.25) > 5).toBe(true)
    end)

    test("and settles rather than stopping dead", function()
        -- Symmetric with the wind-up: the last quarter of the time covers well under a quarter
        -- of the distance.
        expect(RollingNumber.valueAt(0, 100, 0.75) > 75).toBe(true)
        expect(RollingNumber.valueAt(0, 100, 0.75) < 95).toBe(true)
    end)
end)
```

Every other test in the file — endpoints, clamping, monotonicity, integer results, the constant case — stays exactly as it is. Smoothstep satisfies all of them, and they are what stops this change from introducing an overshoot.

- [ ] **Step 2: Run the tests and watch them fail**

Run from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`: `lune run tests/run`
Expected: FAIL — `durationFor` does not exist, `DURATION` still does, and `valueAt(0, 100, 0.5)` returns 75.

- [ ] **Step 3: Implement**

In `roblox/src/shared/RollingNumber.luau`, replace the `RollingNumber.DURATION` declaration with:

```lua
-- HOW LONG A COUNT TAKES IS A FUNCTION OF HOW FAR IT GOES (spec §3a). A flat duration meant
-- banking 2000 points took the same half second as banking 1, and the owner's word for it was
-- that it "transferred" rather than paid out.
--
-- LOGARITHMIC, so it flattens on its own: no pot however large can run away with the screen,
-- and the ceiling is reached rather than approached. Values it produces:
--   1 -> 0.56s   30 -> 1.18s   300 -> 1.70s   3000 -> 2.23s   10000+ -> 2.50s
RollingNumber.MIN_DURATION = 0.4
RollingNumber.MAX_DURATION = 2.5
RollingNumber.SCALE_CAP = 10000

-- `delta` is signed; only its MAGNITUDE matters. The bank button drains to zero while the
-- balance fills, and those are one event — a count down that finished before the count up would
-- show the points arriving from nowhere.
function RollingNumber.durationFor(delta: number): number
    local magnitude = math.min(math.abs(delta), RollingNumber.SCALE_CAP)
    local span = RollingNumber.MAX_DURATION - RollingNumber.MIN_DURATION
    local fraction = math.log(1 + magnitude) / math.log(1 + RollingNumber.SCALE_CAP)
    return RollingNumber.MIN_DURATION + span * fraction
end
```

Replace the `easeOut` function with:

```lua
-- SMOOTHSTEP, not the quadratic ease-out this replaces. A payoff winds up, races, then settles;
-- ease-out did the opposite — fastest at the start, so three quarters of a two-second count
-- landed in the first second and the last quarter crawled. Smoothstep keeps every guarantee the
-- tests below assert: monotonic on [0,1], bounded to exactly [0,1], and exact at both endpoints
-- (0 -> 0, 1 -> 1*(3-2) = 1), so the interpolated value still cannot overshoot `to`.
local function smoothstep(t: number): number
    return t * t * (3 - 2 * t)
end
```

and update `valueAt`'s single call site from `easeOut(clamped)` to `smoothstep(clamped)`. Update `valueAt`'s own comment if it names the old easing.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS. `HudController.client.luau` still reads `RollingNumber.DURATION` at this point — that is expected, invisible to the harness, and Task 3 repairs it. **Do not patch HudController here.**

- [ ] **Step 5: Verify the two new invariants are not vacuous**

No gate can see a counter animate, so prove these tests bite:

1. Change `smoothstep` back to `1 - (1 - t) * (1 - t)` and re-run. Expected: the three easing tests fail. Restore.
2. Change `durationFor` to `return RollingNumber.MIN_DURATION` and re-run. Expected: the curve-shape and cap tests fail. Restore.
3. Change `math.abs(delta)` to `delta` and re-run. Expected: the direction test fails. Restore.

Quote the actual failure output in your report. **If any mutation does not cause a failure, that is a finding** — say so rather than moving on.

- [ ] **Step 6: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RollingNumber.luau roblox/tests/RollingNumber.spec.luau
git commit -m "feat(roblox): a count's length is how far it travels, and it pays out rather than decays"
```

---

