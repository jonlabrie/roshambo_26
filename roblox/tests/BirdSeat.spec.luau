--!strict
-- ⚠ `PivotOffset` IS NOT THE FEET, AND STOPS BEING CLOSE THE MOMENT A MESH IS RESIZED.
--
-- Both seating paths -- BirdController's perch and watchWingbeat's -- put the part's PIVOT on the
-- target, on the stated grounds that the pivot "is the offset from the part centre to the origin
-- both halves were exported around, which is the feet. Verified: feet land within 0.021 of the
-- target." That 0.021 was the uguisu's own residual, small enough to accept and then forget.
--
-- Measured in Studio with each pivot placed at y = 100, reading the RENDERED box bottom:
--
--   KarasuBody  centre 100.449  size 0.897  ->  bottom 100.000   pivot IS the feet
--   UguisuBody  centre 100.215  size 0.472  ->  bottom  99.979   0.021 low, the accepted residual
--   MejiroBody  centre 100.215  size 0.365  ->  bottom 100.033   0.033 HIGH
--
-- ⚠ THE MEJIRO IS THE UGUISU MESH SCALED TO 0.773 IN STUDIO, AND RESIZING A MESHPART DOES NOT
-- RESIZE ITS PivotOffset. The two share a mesh, a rig and a byte-identical PivotOffset of -0.215,
-- and their feet land 0.054 studs apart -- 15% of the mejiro's whole height. Every future bird
-- scaled from a shared mesh inherits the same error, growing with the scale factor.
--
-- So seat by the RENDERED BOTTOM, which is the toes on a perching bird and is what the karasu's
-- exact 0.000 confirms the export intended.
local harness = require("./harness")
local BirdFlight = require("../src/shared/BirdFlight")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- ⚠ 1e-3 BECAUSE THE INPUTS ARE THREE-DECIMAL PRINTOUTS. The karasu's true offset is 0.0005 --
-- centre 100.449 minus half of 0.897 -- and agreement finer than the measurement's own resolution
-- would be asserting precision that was never read off the rig.
local function near(a: number, b: number): boolean
    return math.abs(a - b) < 1e-3
end

describe("BirdFlight.footOffset", function()
    test("is zero on the karasu, whose pivot the export put exactly at the feet", function()
        expect(near(BirdFlight.footOffset(100.449, 0.897, 100), 0)).toBe(true)
    end)

    test("recovers the uguisu's known 0.021 residual, below the pivot", function()
        expect(near(BirdFlight.footOffset(100.215, 0.472, 100), -0.021)).toBe(true)
    end)

    test("recovers the mejiro's 0.033, ABOVE the pivot -- the opposite direction", function()
        expect(near(BirdFlight.footOffset(100.215, 0.365, 100), 0.0325)).toBe(true)
    end)

    test("separates two birds that share a mesh and a byte-identical PivotOffset", function()
        -- ⚠ THE WHOLE POINT. Same pivot, same rig, same mesh, one of them scaled: if seating reads
        -- the pivot it cannot tell these apart, and one of the two is always wrong.
        local uguisu = BirdFlight.footOffset(100.215, 0.472, 100)
        local mejiro = BirdFlight.footOffset(100.215, 0.365, 100)
        expect(near(mejiro - uguisu, 0.0535)).toBe(true)
    end)

    test("moves with the part, so a bird seated anywhere lands the same way", function()
        expect(near(BirdFlight.footOffset(3.215, 0.365, 3), BirdFlight.footOffset(100.215, 0.365, 100))).toBe(
            true
        )
    end)
end)
