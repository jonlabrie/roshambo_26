--!strict
-- ⚠ THE KARASU'S EYE IS PAINTED, NOT BUILT, and this guards the direction rather than a mechanism.
--
-- It was modelled for two days: a `KarasuEyes` MeshPart, a lofted lid collar, `eye_R`/`eye_L`
-- bones, a rigid per-frame follow. Four defects came out of it in play -- a rest pose seated
-- against the wrong reference, a one-frame ordering lag, a skinned mesh shipped with its bones
-- deleted, and a leaked part on the second teardown path -- and then a fifth that no amount of
-- care would have fixed: a rigid eyeball cannot track a SMOOTH-SKINNED socket. Measured, at a 30
-- degree head yaw parts of the socket rim end up 0.57 of an eyeball radius away from where a
-- rigid follow puts them, so the ball escapes on whichever side lags.
--
-- ⚠ AND THE PREMISE IT WAS ALL BUILT ON WAS FALSE. "A painted eye cannot read" came from three
-- bakes, all of them OUR OWN procedural output. The vendor's hand-painted eye -- iris, pupil,
-- catchlight, lid line -- was never in that sample. It was in the file the whole time. What ships
-- now is the vendor's art graded to the corvid palette, with a derived roughness map so the eye
-- can stay wet while the feathers stay matte.
--
-- `BirdController` is a Roblox-runtime file Lune cannot execute, so reading its source is the only
-- reach a test has -- the same argument as BirdScaleConvention.
local fs = require("@lune/fs")
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

local CONTROLLER = "src/client/BirdController.client.luau"
local SPECIES = "src/shared/BirdSpecies.luau"

describe("the karasu's eye is painted, not built", function()
    test("the controller builds no eye geometry of any kind", function()
        local src = harness.stripComments(fs.readFile(CONTROLLER))
        -- ⚠ EACH OF THESE WAS SHIPPED AT SOME POINT. A `Part` ball parked on a bone; then a
        -- MeshPart clone CFramed off the head. Both put an eye on the bird and both were wrong
        -- for reasons no runtime signal reported.
        for _, banned in { "Enum.PartType.Ball", "eye_R", "eye_L", "makeEye", "eyeOffset", "EYE_TEMPLATE" } do
            expect(string.find(src, banned, 1, true)).toBe(nil)
        end
    end)

    test("no species carries an eye appearance record", function()
        -- The eye's colour, material and reflectance described a Roblox part. There is no part;
        -- the eye is texels, and how it looks is decided in the ColorMap and the roughness map.
        local src = harness.stripComments(fs.readFile(SPECIES))
        expect(string.find(src, "eyeOf", 1, true)).toBe(nil)
        expect(string.find(src, "reflectance", 1, true)).toBe(nil)
    end)

    test("the eyes mesh is not declared to Rojo", function()
        -- ⚠ A LEFTOVER `$path` POINTING AT A DELETED FILE BREAKS THE WHOLE SYNC, not just the
        -- bird -- Rojo refuses the project rather than skipping the entry.
        local proj = fs.readFile("default.project.json")
        expect(string.find(proj, "KarasuEyes", 1, true)).toBe(nil)
    end)
end)
