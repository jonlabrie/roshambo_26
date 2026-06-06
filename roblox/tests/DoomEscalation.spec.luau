--!strict
local harness = require("./harness")
local Doom = require("../src/shared/DoomEscalation")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("DoomEscalation", function()
    test("stage grows every 5 seconds", function()
        expect(Doom.stageAt(0)).toBe(1)
        expect(Doom.stageAt(4.9)).toBe(1)
        expect(Doom.stageAt(5)).toBe(2)
        expect(Doom.stageAt(23)).toBe(5)
    end)

    test("spawn interval shrinks per stage but floors at the minimum", function()
        local s1 = Doom.spawnInterval("fateBoulder", 1)
        local s3 = Doom.spawnInterval("fateBoulder", 3)
        expect(s1).toBe(2.5)
        expect(s3 < s1).toBe(true)
        expect(Doom.spawnInterval("fateBoulder", 50)).toBe(0.6) -- floor
    end)

    test("entity cap rises with stage and plateaus", function()
        expect(Doom.entityCap("fatePaper", 1)).toBe(2)
        expect(Doom.entityCap("fatePaper", 10)).toBe(20)
        expect(Doom.entityCap("fatePaper", 100)).toBe(40) -- plateau (spec: ~40 sheets)
        expect(Doom.entityCap("fateBoulder", 100)).toBe(6)
        expect(Doom.entityCap("fateShears", 100)).toBe(8)
    end)

    test("homing step moves toward the target at speed*dt and never overshoots", function()
        local p = Doom.homingStep({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, 5, 1)
        expect(p.x).toBe(5)
        local q = Doom.homingStep({ x = 9, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, 5, 1)
        expect(q.x).toBe(10) -- clamped at target
    end)

    test("zero-distance homing is a no-op (no NaN)", function()
        local p = Doom.homingStep({ x = 1, y = 2, z = 3 }, { x = 1, y = 2, z = 3 }, 5, 1)
        expect(p).toEqual({ x = 1, y = 2, z = 3 })
    end)

    test("standing still triggers fast catch after 4s; moving does not", function()
        expect(Doom.shouldFastCatch(0.5, 4.5)).toBe(true)
        expect(Doom.shouldFastCatch(0.5, 3)).toBe(false)
        expect(Doom.shouldFastCatch(12, 30)).toBe(false)
    end)
end)
