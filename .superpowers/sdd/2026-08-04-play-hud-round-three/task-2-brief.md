### Task 2: RingTimer stops counting segments and starts measuring a sweep

**Files:**
- Modify: `roblox/src/shared/RingTimer.luau` (near-total rewrite)
- Test: `roblox/tests/RingTimer.spec.luau` (near-total rewrite)

**Interfaces:**
- Consumes: nothing.
- Produces, for Task 3:
  - `RingTimer.MIN_SWEEP_DEGREES: number`
  - `RingTimer.sweepDegrees(fraction: number): number`
  - `RingTimer.sweep(fraction: number): { rotationA: number, rotationB: number, bLit: boolean }`
  - `RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean` — unchanged
- Deleted, and Task 3 must stop calling them: `RingTimer.SEGMENTS`, `RingTimer.lit`, `RingTimer.angleAt`, `RingTimer.segmentWidth`.

**Context:** The ring is currently 36 `Frame`s, each rotated about its own centre and widened to overlap its neighbours. It draws a polygon, and the facets are visible — worse at 76px than 44px because they scale with the radius. The replacement draws a real pie from a track circle plus two half-discs, where a half-disc is a circular `Frame` whose `UIGradient.Transparency` steps hard at offset 0.5 and whose `UIGradient.Rotation` sweeps the cut. **This module owns only the angles; Task 3 owns the instances.**

The geometry, derived once so nobody has to re-derive it: a half-disc's visible half is the clockwise arc `[a, a + 180]` measured from the top. The gradient's visible side is the one *before* the step, and `Rotation = 0` points the gradient axis to the right, which is 90° clockwise from the top. Therefore **`UIGradient.Rotation = a + 180`**.

To light the clockwise arc `[0, θ]`:
- **θ ≤ 180** — half A lit at `a = 0` (covers 0–180); half B in the **track** colour at `a = θ` (covers θ–θ+180), painting back over the excess. Net lit: 0–θ.
- **θ > 180** — half A lit at `a = 0`; half B **also lit** at `a = θ - 180` (covers θ−180–θ). Union: 0–θ.

- [ ] **Step 1: Write the failing tests**

Replace the whole of `roblox/tests/RingTimer.spec.luau` with:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RingTimer = require("../src/shared/RingTimer")

describe("RingTimer.sweepDegrees — how much of the circle is still there", function()
    test("a full round sweeps the whole circle", function()
        expect(RingTimer.sweepDegrees(1)).toBe(360)
    end)

    test("an empty round sweeps nothing — the ring is GONE", function()
        expect(RingTimer.sweepDegrees(0)).toBe(0)
    end)

    test("half a round sweeps half the circle", function()
        expect(RingTimer.sweepDegrees(0.5)).toBe(180)
    end)

    test("ANY time remaining sweeps at least MIN_SWEEP_DEGREES", function()
        -- The invariant the old segment count carried with math.ceil, restated for a continuous
        -- ring. A player with a sliver of a second must not see an EMPTY ring: the round is
        -- still open and the throw buttons are still live. 0.2s of a 20s round is 3.6 degrees,
        -- which at 44px is sub-pixel and renders as nothing at all.
        expect(RingTimer.sweepDegrees(0.0001)).toBe(RingTimer.MIN_SWEEP_DEGREES)
        expect(RingTimer.sweepDegrees(0.0001) > 0).toBe(true)
    end)

    test("the floor is big enough to actually see", function()
        -- A floor of, say, 0.5 degrees would satisfy "> 0" and still render as nothing. At 6
        -- degrees the arc is ~2px along a 38px-diameter phone ring: visible.
        expect(RingTimer.MIN_SWEEP_DEGREES >= 4).toBe(true)
    end)

    test("it is monotonic and never leaves the circle", function()
        local prev = -1
        for i = 0, 100 do
            local v = RingTimer.sweepDegrees(i / 100)
            expect(v >= prev).toBe(true)
            expect(v <= 360).toBe(true)
            expect(v >= 0).toBe(true)
            prev = v
        end
    end)

    test("a fraction outside [0,1] clamps rather than extrapolating", function()
        expect(RingTimer.sweepDegrees(-3)).toBe(0)
        expect(RingTimer.sweepDegrees(9)).toBe(360)
    end)
end)

describe("RingTimer.sweep — the two gradient rotations that draw that arc", function()
    test("half A never moves", function()
        -- It is the fixed half; only B moves and changes colour. Returned rather than exported
        -- as a bare constant so the pair that has to agree is produced in one place.
        for _, f in { 0, 0.1, 0.5, 0.7, 1 } do
            expect(RingTimer.sweep(f).rotationA).toBe(180)
        end
    end)

    test("under half a turn, B is the TRACK colour and paints back the excess", function()
        local s = RingTimer.sweep(0.25) -- 90 degrees
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(270) -- 90 + 180
    end)

    test("over half a turn, B is LIT and extends the arc", function()
        local s = RingTimer.sweep(0.75) -- 270 degrees
        expect(s.bLit).toBe(true)
        expect(s.rotationB).toBe(270)
    end)

    test("exactly half a turn is still the track branch", function()
        local s = RingTimer.sweep(0.5)
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(360)
    end)

    test("a full round lights the whole circle", function()
        local s = RingTimer.sweep(1)
        expect(s.bLit).toBe(true)
        expect(s.rotationB).toBe(360)
    end)

    test("an empty round lights nothing", function()
        local s = RingTimer.sweep(0)
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(180) -- B in track, exactly over A: nothing survives
    end)
end)

describe("RingTimer.sweep — what the two halves actually cover", function()
    -- The strongest test in this file: it reconstructs the painted arc from the rotations the
    -- way the renderer does, and checks it against sweepDegrees. A sign error, an off-by-180 or
    -- a flipped branch all fail here and nowhere else.
    local function litDegrees(fraction: number): number
        local s = RingTimer.sweep(fraction)
        -- A half-disc at UIGradient.Rotation R shows the clockwise arc [R - 180, R] from the top.
        local aStart = (s.rotationA - 180) % 360
        local bStart = (s.rotationB - 180) % 360
        local function covers(start: number, deg: number): boolean
            local d = (deg - start) % 360
            return d < 180
        end
        local count = 0
        for deg = 0, 359 do
            local inA = covers(aStart, deg + 0.5)
            local inB = covers(bStart, deg + 0.5)
            local lit
            if s.bLit then
                lit = inA or inB
            else
                lit = inA and not inB
            end
            if lit then
                count += 1
            end
        end
        return count
    end

    test("the painted arc matches the requested sweep, all the way round", function()
        for i = 0, 40 do
            local f = i / 40
            local want = RingTimer.sweepDegrees(f)
            local got = litDegrees(f)
            -- One degree of slack: the reconstruction samples whole degrees.
            expect(math.abs(got - want) <= 1).toBe(true)
        end
    end)

    test("the arc always starts at the top and runs clockwise", function()
        -- Degree 0 (the top) is lit for any live round and dark for a dead one.
        expect(litDegrees(0)).toBe(0)
        expect(litDegrees(0.02) > 0).toBe(true)
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

describe("RingTimer — the segmented ring is gone", function()
    test("nothing counts segments any more", function()
        -- The ring is drawn as a pie now (spec §4). These four were the segment API; leaving a
        -- stale one behind invites a caller that draws a polygon beside a circle.
        expect((RingTimer :: any).SEGMENTS).toBe(nil)
        expect((RingTimer :: any).lit).toBe(nil)
        expect((RingTimer :: any).angleAt).toBe(nil)
        expect((RingTimer :: any).segmentWidth).toBe(nil)
    end)
end)
```

- [ ] **Step 2: Run the tests and watch them fail**

Run from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`: `lune run tests/run`
Expected: FAIL — `sweepDegrees` and `sweep` do not exist, and the four deleted names still do.

- [ ] **Step 3: Rewrite RingTimer**

Replace the whole of `roblox/src/shared/RingTimer.luau` with:

```lua
--!strict
-- The round timer's ring, as arithmetic. Roblox has no SVG, no arc primitive and no radial
-- fill, so the PWA's stroke-dash sweep (src/components/PieTimer.tsx) is rebuilt from a track
-- circle and two half-discs. A half-disc is a circular Frame whose UIGradient.Transparency
-- steps hard at offset 0.5; UIGradient.Rotation sweeps the cut. No clipping (Roblox's
-- ClipsDescendants carries a documented caveat about rotated descendants) and no image asset.
--
-- This module owns the ANGLES. HudController owns the instances and paints what it is told.
--
-- THE GEOMETRY, derived once so nobody re-derives it:
-- a half-disc's visible half is the clockwise arc [a, a + 180] measured from the top. The
-- gradient's visible side is the one BEFORE the step, and Rotation = 0 points the gradient axis
-- to the right — 90 degrees clockwise from the top. Hence:
--
--     UIGradient.Rotation = a + 180
--
-- To light the clockwise arc [0, theta]:
--   theta <= 180 : half A lit at a = 0 (covers 0-180); half B in TRACK at a = theta
--                  (covers theta..theta+180), painting back over the excess. Net: 0-theta.
--   theta >  180 : half A lit at a = 0; half B ALSO LIT at a = theta - 180. Union: 0-theta.
--
-- No Roblox globals — this runs under Lune like everything else in src/shared.
local RingTimer = {}

-- The smallest arc a live round may draw.
--
-- This is the old segment count's `math.ceil` restated for a continuous ring, and it is
-- load-bearing: an empty ring must mean the round is over and nothing else. A raw
-- fraction * 360 breaks that silently, because 0.2s of a 20s round is 3.6 degrees — sub-pixel
-- at 44px, and it renders as nothing while the throw buttons are still live. 6 degrees is
-- roughly 2px along a 38px-diameter phone ring: small, but visibly not gone.
RingTimer.MIN_SWEEP_DEGREES = 6

export type Sweep = { rotationA: number, rotationB: number, bLit: boolean }

-- Degrees of the clockwise sweep for `fraction` of the round remaining.
function RingTimer.sweepDegrees(fraction: number): number
    local f = math.clamp(fraction, 0, 1)
    if f <= 0 then
        return 0
    end
    return math.max(f * 360, RingTimer.MIN_SWEEP_DEGREES)
end

-- The two gradient rotations that draw that sweep, and whether half B is lit or track.
--
-- `rotationA` is always 180 and is RETURNED rather than exported as a bare constant, so the
-- pair that must agree is produced in one place and a renderer cannot pick up one without the
-- other.
function RingTimer.sweep(fraction: number): Sweep
    local theta = RingTimer.sweepDegrees(fraction)
    if theta <= 180 then
        return { rotationA = 180, rotationB = theta + 180, bLit = false }
    end
    return { rotationA = 180, rotationB = theta, bLit = true }
end

-- Whether the ring should read as urgent. `escalateAt` is passed in rather than owned here so
-- the ring and the escalation prompt cannot drift apart — see HudModel.ESCALATE_AT.
--
-- Deliberately NOT gated on `secondsLeft > 0` the way HudModel's `escalate` is. That gate exists
-- because a prompt at zero would be pointless; a colour at zero is harmless, and at zero there
-- is no arc to colour anyway.
function RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean
    return secondsLeft <= escalateAt
end

return RingTimer
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS. `HudController.client.luau` still calls `RingTimer.lit` and `RingTimer.SEGMENTS` at this point — that is fine and invisible to the harness, and Task 3 repairs it. **Do not partially patch `HudController` here**; the two live in separate commits on purpose.

- [ ] **Step 5: Verify the floor is real, by breaking it**

Temporarily change `MIN_SWEEP_DEGREES` to `0` and re-run. Expected: the "ANY time remaining" test and "the floor is big enough" test both fail. Then temporarily flip `sweep`'s branch to `theta < 180` and re-run: expected, "exactly half a turn is still the track branch" fails. Restore both. This is the only way to know the two tests that matter are not vacuous — no gate can see the ring itself.

- [ ] **Step 6: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RingTimer.luau roblox/tests/RingTimer.spec.luau
git commit -m "feat(roblox): the ring is a swept arc, not a count of segments"
```

---

