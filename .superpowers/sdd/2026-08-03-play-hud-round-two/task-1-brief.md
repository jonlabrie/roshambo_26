### Task 1: `RingTimer` — the segmented sweep

**Files:** Create `roblox/src/shared/RingTimer.luau`, `roblox/tests/RingTimer.spec.luau`.

**Interfaces:**
- Produces: `RingTimer.SEGMENTS` (36), `RingTimer.lit(fraction, segments): number`,
  `RingTimer.angleAt(index, segments): number`, `RingTimer.isWarning(secondsLeft, escalateAt): boolean`,
  `RingTimer.segmentWidth(radius, segments): number`

- [ ] **Step 1: Write the failing tests**

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RingTimer = require("../src/shared/RingTimer")

local N = RingTimer.SEGMENTS

describe("RingTimer.lit — how much of the ring is still there", function()
    test("a full round lights every segment", function()
        expect(RingTimer.lit(1, N)).toBe(N)
    end)

    test("an empty round lights none — the ring is GONE, not one-segment-left", function()
        expect(RingTimer.lit(0, N)).toBe(0)
    end)

    test("any time remaining leaves at least one segment lit", function()
        -- A player with a sliver of a second must not see an empty ring: the round is still open
        -- and the throw buttons are still live.
        expect(RingTimer.lit(0.0001, N)).toBe(1)
    end)

    test("half a round lights half the ring", function()
        expect(RingTimer.lit(0.5, N)).toBe(N // 2)
    end)

    test("it is monotonic and never exceeds the count", function()
        local prev = -1
        for i = 0, 100 do
            local v = RingTimer.lit(i / 100, N)
            expect(v >= prev).toBe(true)
            expect(v <= N).toBe(true)
            expect(v >= 0).toBe(true)
            prev = v
        end
    end)

    test("a fraction outside [0,1] clamps rather than extrapolating", function()
        expect(RingTimer.lit(-3, N)).toBe(0)
        expect(RingTimer.lit(9, N)).toBe(N)
    end)
end)

describe("RingTimer.angleAt — segment 1 is at the top, sweeping clockwise", function()
    test("the first segment sits at 0 degrees", function()
        expect(RingTimer.angleAt(1, N)).toBe(0)
    end)

    test("segments are evenly spaced over a full turn", function()
        expect(RingTimer.angleAt(2, N)).toBe(360 / N)
        expect(RingTimer.angleAt(N, N)).toBe(360 - 360 / N)
    end)

    test("no segment reaches a full turn — that would overlap segment 1", function()
        for i = 1, N do
            expect(RingTimer.angleAt(i, N) < 360).toBe(true)
        end
    end)
end)

describe("RingTimer.isWarning", function()
    test("it warns at and below the threshold", function()
        expect(RingTimer.isWarning(5, 5)).toBe(true)
        expect(RingTimer.isWarning(1, 5)).toBe(true)
    end)

    test("it does not warn above the threshold", function()
        expect(RingTimer.isWarning(5.01, 5)).toBe(false)
        expect(RingTimer.isWarning(20, 5)).toBe(false)
    end)
end)

describe("RingTimer.segmentWidth — segments overlap so the ring reads solid", function()
    test("a segment is at least as wide as its share of the circumference", function()
        local pitch = 2 * math.pi * 23 / N
        expect(RingTimer.segmentWidth(23, N) >= pitch).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run from `roblox/`: `lune run tests/run` — expect FAIL, module missing.

- [ ] **Step 3: Implement**

```luau
--!strict
-- The round timer's ring, as arithmetic. Roblox has no SVG and no radial fill, so the PWA's
-- stroke-dash sweep (src/components/PieTimer.tsx) becomes a ring of discrete segments, lit from
-- the top clockwise. Which segments are lit is pure and lives here; HudController only paints
-- what it is told.
--
-- No Roblox globals — this runs under Lune like everything else in src/shared.
local RingTimer = {}

-- 36 segments = one every 10 degrees. Enough to read as a ring at 54px; few enough that the
-- controller builds 36 Frames once and only recolours them thereafter.
RingTimer.SEGMENTS = 36

-- How many segments are lit for `fraction` of the round remaining.
--
-- CEIL, not floor or round, and that matters at one end: any time at all leaves at least one
-- segment lit, because the round is still open and the throw buttons are still live. An empty
-- ring must mean the round is over, and nothing else.
function RingTimer.lit(fraction: number, segments: number): number
    local f = math.clamp(fraction, 0, 1)
    return math.clamp(math.ceil(f * segments), 0, segments)
end

-- Where segment `index` sits, in degrees clockwise from the top. Roblox's `Rotation` is already
-- clockwise-positive, so this feeds it directly.
function RingTimer.angleAt(index: number, segments: number): number
    return (index - 1) * (360 / segments)
end

-- Whether the ring should read as urgent. `escalateAt` is passed in rather than owned here so
-- the ring and the escalation prompt cannot drift apart — see HudModel.ESCALATE_AT.
--
-- Deliberately NOT gated on `secondsLeft > 0` the way HudModel's `escalate` is. That gate exists
-- because a prompt at zero would be pointless; a colour at zero is harmless, and at zero there
-- are no lit segments to colour anyway.
function RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean
    return secondsLeft <= escalateAt
end

-- A segment's width. Its share of the circumference would leave hairline gaps once each segment
-- is rotated about its own centre, so they are widened to overlap and the ring reads solid.
function RingTimer.segmentWidth(radius: number, segments: number): number
    return math.ceil(2 * math.pi * radius / segments) + 1
end

return RingTimer
```

- [ ] **Step 4: Run to verify pass, then verify the tests bite**

Run: `lune run tests/run` — expect PASS.

Then change `lit` to use `math.floor` instead of `math.ceil`, re-run, and confirm the
"any time remaining leaves at least one segment lit" test FAILS. Revert. **Report the count.**

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/RingTimer.luau roblox/tests/RingTimer.spec.luau
git commit -m "feat(roblox): the round's remaining time, as arithmetic"
```

---

