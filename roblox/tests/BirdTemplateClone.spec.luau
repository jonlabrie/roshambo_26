--!strict
-- ⚠ WHAT A FAMILIAR CLONE IS ALLOWED TO THROW AWAY.
--
-- `BirdController` clones a template out of `RoshamboBirds` and strips children it does not want:
-- the 3D importer leaves an `AnimationController` and an `InitialPoses` folder on every mesh, and
-- we drive `Bone.Transform` directly, so both are dead weight on every bird.
--
-- ⚠ IT WAS WRITTEN AS AN ALLOWLIST -- `if not c:IsA("Bone") then c:Destroy()` -- and that shape is
-- the defect. It was correct only while the bird's appearance lived on `TextureID`, which is a
-- PROPERTY and survives a clone. The karasu now carries a `SurfaceAppearance` (ColorMap + Normal +
-- Roughness + Metalness), which is a CHILD INSTANCE, so the allowlist deleted the bird's entire
-- appearance and every familiar rendered in the MeshPart's default grey.
--
-- ⚠ AND IT ONLY SHOWED IN PLAY. The template still had its SurfaceAppearance, so the bird looked
-- correct in Edit and wrong in the game -- owner, 2026-08-29: "the bird is black in edit and grey
-- in play", which is the observation that located it after two wrong guesses at the asset itself.
--
-- The asymmetry decides the shape: over-keeping costs a few dead instances, over-deleting costs an
-- invisible appearance bug that only appears at runtime. So this must be a DENYLIST -- name what
-- is dead, keep everything else.
local fs = require("@lune/fs")
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

local CONTROLLER = "src/client/BirdController.client.luau"

describe("familiar template clones", function()
    test("strip by DENYLIST, never by `not IsA(Bone)`", function()
        local src = harness.stripComments(fs.readFile(CONTROLLER))
        -- the exact allowlist that deleted the SurfaceAppearance
        expect(string.find(src, 'not c:IsA("Bone")', 1, true)).toBe(nil)
        -- and the dead weight it exists to remove must still be named
        expect(string.find(src, "AnimationController", 1, true) ~= nil).toBe(true)
    end)

    test("the strip names only classes that are genuinely dead weight", function()
        -- ⚠ ASSERT THE CONDITION, NOT THE VOCABULARY. A first version of this test demanded the
        -- word "SurfaceAppearance" appear somewhere in the file, which a correct denylist has no
        -- reason to contain -- it failed on working code. What matters is WHAT THE STRIP DELETES.
        local src = harness.stripComments(fs.readFile(CONTROLLER))
        local body = string.match(src, "local function stripImporterJunk.-\nend")
        expect(body ~= nil).toBe(true)
        body = body :: string
        -- the importer leftovers it exists to remove
        expect(string.find(body, "AnimationController", 1, true) ~= nil).toBe(true)
        -- ⚠ anything that CARRIES APPEARANCE must never appear in a destroy condition. The next
        -- such feature to arrive as a child instance would be eaten by the identical mistake.
        for _, appearance in { "SurfaceAppearance", "MaterialVariant", "Decal", "Texture", "Highlight" } do
            expect(string.find(body, appearance, 1, true)).toBe(nil)
        end
    end)
end)
