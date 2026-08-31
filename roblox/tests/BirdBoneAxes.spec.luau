--!strict
-- ⚠ `CFrame.Angles(pitch, yaw, 0)` ASSUMES THE BONE'S LOCAL AXES ARE THE BODY'S. On this rig they
-- are not, and the assumption cost the song its entire point.
--
-- Measured in Studio on MejiroBody, each bone-local axis expressed in body space (body X = right,
-- Y = up, Z = length):
--
--   joint3 (neck):  localX -> -bodyY     localY -> -bodyZ     localZ -> +bodyX
--   joint4 (head):  localX -> -bodyZ     localY -> +bodyY     localZ -> +bodyX
--
-- So the pitch we were writing into slot X was turning the head sideways on the neck and rolling
-- it on the head, and the yaw in slot Y was rolling the neck. PITCH, the one thing the song
-- needed, was in slot Z on both bones and we never wrote it. The owner's report was exact: the
-- head "rotates (yaw) and tilts side to side (roll) but does NOT lift up its beak (pitch) at all."
--
-- ⚠ AND THE TWO NECK BONES YAWED AGAINST EACH OTHER: joint3's slot X is -bodyY while joint4's
-- slot Y is +bodyY, so the neck turned one way while the head turned the other. That counter-turn
-- is the "side to side head wobble" -- it was never damping, it was an S-bend.
--
-- ⚠ SO THE AXES ARE READ FROM THE RIG, NOT ASSUMED. More birds are coming and nothing guarantees
-- the next armature is oriented like this one; a hardcoded slot permutation would be a second
-- silent failure wearing the first one's clothes.
local harness = require("./harness")
local BirdFlight = require("../src/shared/BirdFlight")
local describe, test, expect = harness.describe, harness.test, harness.expect

local BODY_PITCH = { 1, 0, 0 } -- body +X, the axis a head pitches about
local BODY_YAW = { 0, 1, 0 } -- body +Y

-- the two rigs as measured, bone-local X/Y/Z each written in body space
local JOINT3 = { { 0, -1, 0 }, { 0, 0, -1 }, { 1, 0, 0 } }
local JOINT4 = { { 0, 0, -1 }, { 0, 1, 0 }, { 1, 0, 0 } }

local function near(a: number, b: number): boolean
    return math.abs(a - b) < 1e-6
end

describe("BirdFlight.toBoneSpace", function()
    test("finds pitch on the bone's local Z for both neck bones, not slot X", function()
        local x, y, z = BirdFlight.toBoneSpace(JOINT3, BODY_PITCH)
        expect(near(x, 0) and near(y, 0) and near(z, 1)).toBe(true)
        x, y, z = BirdFlight.toBoneSpace(JOINT4, BODY_PITCH)
        expect(near(x, 0) and near(y, 0) and near(z, 1)).toBe(true)
    end)

    test("finds the neck's yaw INVERTED on local X and the head's upright on local Y", function()
        local x, y, z = BirdFlight.toBoneSpace(JOINT3, BODY_YAW)
        expect(near(x, -1) and near(y, 0) and near(z, 0)).toBe(true)
        x, y, z = BirdFlight.toBoneSpace(JOINT4, BODY_YAW)
        expect(near(x, 0) and near(y, 1) and near(z, 0)).toBe(true)
    end)

    test("an identity rig maps every body axis straight through", function()
        local I = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
        local x, y, z = BirdFlight.toBoneSpace(I, BODY_PITCH)
        expect(near(x, 1) and near(y, 0) and near(z, 0)).toBe(true)
        x, y, z = BirdFlight.toBoneSpace(I, BODY_YAW)
        expect(near(x, 0) and near(y, 1) and near(z, 0)).toBe(true)
    end)

    test("a 45 degree bone splits one body axis across two local ones, keeping unit length", function()
        local s = math.sqrt(0.5)
        local R = { { s, s, 0 }, { -s, s, 0 }, { 0, 0, 1 } }
        local x, y, z = BirdFlight.toBoneSpace(R, BODY_PITCH)
        expect(near(x, s) and near(y, -s) and near(z, 0)).toBe(true)
        expect(near(math.sqrt(x * x + y * y + z * z), 1)).toBe(true)
    end)
end)
