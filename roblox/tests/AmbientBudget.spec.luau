--!strict
local harness = require("./harness")
local AmbientBudget = require("../src/shared/AmbientBudget")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("AmbientBudget.inRange", function()
    test("at the camera is in range", function()
        expect(AmbientBudget.inRange(0)).toBe(true)
    end)

    test("exactly at the radius is still in range", function()
        local r = AmbientBudget.DEFAULT.radius
        expect(AmbientBudget.inRange(r * r)).toBe(true)
    end)

    test("just beyond the radius is out", function()
        local r = AmbientBudget.DEFAULT.radius
        expect(AmbientBudget.inRange(r * r + 1)).toBe(false)
    end)

    test("a custom radius is respected", function()
        local cfg = { radius = 10, behindDot = -0.15, interval = 1 / 30 }
        expect(AmbientBudget.inRange(100, cfg)).toBe(true)
        expect(AmbientBudget.inRange(101, cfg)).toBe(false)
    end)
end)

describe("AmbientBudget.inView", function()
    test("dead ahead is in view", function()
        expect(AmbientBudget.inView(1)).toBe(true)
    end)

    test("directly behind is not", function()
        expect(AmbientBudget.inView(-1)).toBe(false)
    end)

    test("exactly at the margin is still in view", function()
        expect(AmbientBudget.inView(AmbientBudget.DEFAULT.behindDot)).toBe(true)
    end)

    test("the margin keeps a little slack behind square", function()
        -- a prop level with the camera plane must survive a fast turn
        expect(AmbientBudget.inView(0)).toBe(true)
        expect(AmbientBudget.DEFAULT.behindDot < 0).toBe(true)
    end)

    -- All five callers pass an explicit cfg, and until now every inView case above exercised only
    -- the `cfg or DEFAULT` fallback -- mirrors the custom-config case inRange already has above.
    test("a custom config is respected", function()
        local cfg = { radius = 10, behindDot = 0.5, interval = 1 / 30 }
        expect(AmbientBudget.inView(0.6, cfg)).toBe(true)
        expect(AmbientBudget.inView(0.4, cfg)).toBe(false)
    end)
end)

describe("AmbientBudget.step", function()
    test("does not fire before the interval elapses", function()
        local fire, acc = AmbientBudget.step(0, 0.01, 1 / 30)
        expect(fire).toBe(false)
        expect(math.abs(acc - 0.01) < 1e-9).toBe(true)
    end)

    test("fires once the interval is reached", function()
        local fire = AmbientBudget.step(0.02, 0.02, 1 / 30)
        expect(fire).toBe(true)
    end)

    test("carries the remainder rather than zeroing", function()
        -- 0.05s against a 0.03s interval leaves 0.02s owed to the next tick;
        -- zeroing here is what silently drags a nominal 30Hz down to the frame rate
        local _, acc = AmbientBudget.step(0, 0.05, 0.03)
        expect(math.abs(acc - 0.02) < 1e-9).toBe(true)
    end)

    test("a long stall does not bank unbounded catch-up", function()
        local fire, acc = AmbientBudget.step(0, 5, 1 / 30)
        expect(fire).toBe(true)
        expect(acc < 1 / 30).toBe(true)
    end)

    test("a zero interval fires every call without dividing by zero", function()
        local fire, acc = AmbientBudget.step(0, 0.001, 0)
        expect(fire).toBe(true)
        expect(acc).toBe(0)
    end)

    test("a negative interval lands in the same safe branch as zero", function()
        local fire, acc = AmbientBudget.step(0, 0.001, -1)
        expect(fire).toBe(true)
        expect(acc).toBe(0)
    end)

    -- `step` above is only ever called once per test, so the property the whole design rests on --
    -- that a 60fps stream against a 1/30s interval fires every other frame and does not drift over
    -- hundreds of frames -- was inferred, never demonstrated. Run it for real.
    test("a 60fps stream against a 1/30s interval fires every other frame over hundreds of frames", function()
        local acc = 0
        local fires = 0
        for _ = 1, 600 do
            local fire, nextAcc = AmbientBudget.step(acc, 1 / 60, 1 / 30)
            acc = nextAcc
            if fire then
                fires += 1
            end
        end
        expect(math.abs(fires - 300) <= 1).toBe(true)
    end)
end)
