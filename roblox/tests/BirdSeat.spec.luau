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
local function near(a: number, b: number, tol: number?): boolean
    return math.abs(a - b) < (tol or 1e-3)
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

describe("BirdFlight.perchClearance", function()
    -- ⚠ THE LOWEST TOE IS NOT WHERE THE BIRD STANDS. Seating the lowest geometry exactly on the
    -- rail is what the measurements said to do -- toes landed 0.004 studs above the kasagi, five
    -- thousandths -- and the owner looked at it and said the bird was too low. Twice.
    --
    -- The toes are modelled curled for gripping, so their tips hang below the foot pad the bird
    -- actually stands on. The gap is real geometry and no measurement of the mesh bounds can find
    -- it: the bounds are the tips.
    --
    -- ⚠ SO THIS NUMBER IS THE OWNER'S EYE, NOT A DERIVATION, and it is labelled that way on
    -- purpose. Three identical mejiros were placed along the torii rail at +0.00, +0.05 and +0.10
    -- studs above the toes-on-surface seat; the owner picked +0.05 on a bird 0.640 long.
    -- 0.05 / 0.640 = 0.078.
    --
    -- ⚠ A FRACTION OF BODY LENGTH, NOT A CONSTANT, because the mejiro IS the uguisu's mesh scaled
    -- to 0.773 -- the same toes, uniformly smaller, so their droop scales with the bird. That much
    -- is certain for those two. The karasu is a different mesh with its own feet and inherits this
    -- only as a default; it has not been judged.
    test("reproduces the owner's pick on the bird it was judged on", function()
        expect(near(BirdFlight.perchClearance(0.640), 0.050, 1e-3)).toBe(true)
    end)

    test("scales with the bird, so the uguisu and its scaled sibling agree", function()
        -- the mejiro is the uguisu at 0.773; the clearance must be too, or one of them is wrong
        local ratio = BirdFlight.perchClearance(0.640) / BirdFlight.perchClearance(0.828)
        expect(near(ratio, 0.640 / 0.828, 1e-6)).toBe(true)
    end)

    test("lifts the mejiro off the seat that read too low", function()
        -- pivot-seated: box bottom +0.0325 from the pivot. Applying the drop RAISES it by 0.0175.
        local drop = BirdFlight.perchDrop(100.215, 0.365, 100, 0.640)
        expect(near(drop, 0.0325 - 0.050, 1e-3)).toBe(true)
        expect(drop < 0).toBe(true)
    end)
end)
