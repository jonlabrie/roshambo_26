--!strict
-- ⚠ SEATING A BIRD MEANS PUTTING ITS PIVOT ON THE PERCH, AND THAT WAS RIGHT BEFORE ANY OF THIS.
--
-- Measured against the owner's eye, all three species on one flat plank at the kasagi's height,
-- as clearance relative to a bounds-seated placement:
--
--   bird     pivot - boxBottom    pivot-seating gives    owner chose    error
--   Karasu        0.000                 0.000              0.000        0.000
--   Uguisu       +0.021                -0.021             ~-0.023      -0.002
--   Mejiro       -0.0325               +0.0325            +0.0489      +0.0164
--
-- Exact on the karasu, 0.002 on the uguisu. Only the RESIZED bird misses: the mejiro is the
-- uguisu's MeshPart scaled to 0.773 in Studio, which does not rescale the pivot data, and the
-- skinned mesh does not draw where `Size` says it does.
--
-- ⚠ TWO MODELS WERE FITTED TO THE MEJIRO ALONE AND EACH BROKE A SPECIES THAT HAD BEEN CORRECT.
-- First the mesh BOUNDS: measured right to 0.004 studs and read as a bird sunk into the rail.
-- Then a "toe droop" clearance scaled by body length, which predicted the LARGER uguisu wanted
-- MORE lift than the mejiro; the owner put them side by side and the uguisu wanted none. Both had
-- passing tests and mutation-proven constants. Neither had a mechanism anyone had verified.
--
-- ⚠ SO THE RESIDUAL IS A MEASURED NUMBER PER BIRD, NOT A THIRD FORMULA. Nothing readable off the
-- part predicts it, and the real fix is upstream: export the mejiro at its own size and its nudge
-- joins the others at zero.
local harness = require("./harness")
local BirdSpecies = require("../src/shared/BirdSpecies")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BirdSpecies.seatNudgeOf", function()
    test("is zero for every bird exported at its own size", function()
        expect(BirdSpecies.seatNudgeOf("Karasu")).toBe(0)
    end)

    test("gives the mejiro the uguisu's number, because it IS the uguisu at 0.773", function()
        -- ⚠ THE POINT OF THE RE-EXPORT. While the mejiro was a MeshPart resized inside Studio it
        -- needed 0.0164 that no other bird needed -- a hack covering an asset defect. Exported from
        -- Blender at its own 0.640, the pivot scales with the mesh and the two birds agree.
        expect(BirdSpecies.seatNudgeOf("Mejiro")).toBe(BirdSpecies.seatNudgeOf("Uguisu"))
    end)

    test("keeps every bird's correction small enough to be a nudge", function()
        -- -0.002 is below what the eye resolved reliably; a value this size must never grow into a
        -- model. If it ever needs to, that is a measurement, not a tweak.
        expect(math.abs(BirdSpecies.seatNudgeOf("Uguisu")) < 0.005).toBe(true)
        expect(math.abs(BirdSpecies.seatNudgeOf("Mejiro")) < 0.005).toBe(true)
    end)

    test("no bird needs a correction big enough to be hiding an asset defect", function()
        -- ⚠ THE GUARD THAT WOULD HAVE CAUGHT THE MEJIRO. A nudge is a hair of eye-measured
        -- residual; anything approaching a tenth of a small bird's height is a broken asset wearing
        -- a constant. 0.0164 -- what the resized mejiro needed -- fails this.
        for name in { "Uguisu", "Mejiro", "Karasu" } do
            expect(math.abs(BirdSpecies.seatNudgeOf(name)) < 0.01).toBe(true)
        end
    end)

    test("returns zero rather than erroring for a bird that has no record yet", function()
        -- The hiyodori graduated to a real record on 2026-09-02; the yamagara is still
        -- just a proportion-set line in warbler_proportions.py, so it is the example now.
        expect(BirdSpecies.seatNudgeOf("Yamagara")).toBe(0)
    end)

    test("the hiyodori wears the warbler seat", function()
        expect(BirdSpecies.seatNudgeOf("Hiyodori")).toBe(-0.002)
    end)
end)
