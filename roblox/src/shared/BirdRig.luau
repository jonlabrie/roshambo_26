--!strict
-- ⚠ THE ROBLOX HALF OF POSING A BIRD'S HEAD. `BirdFlight` stays pure so Lune can test it, which
-- means it cannot touch CFrame; this module is where the rig's real axes are read and turned into
-- a Transform. It is required only by Roblox-runtime code, never by the test harness.
--
-- ⚠ IT EXISTS BECAUSE `CFrame.Angles(pitch, yaw, 0)` WAS A GUESS THAT HAPPENED TO LOOK ALIVE.
-- On the uguisu/mejiro armature the neck bone's slot X is body -Y and the head bone's slot X is
-- body -Z, so the pitch we wrote yawed one bone and rolled the other, and the yaw we wrote rolled
-- the neck against the head. The bird looked busy, so nothing flagged it, and the song's head-lift
-- -- the entire read on a bird 0.64 studs long -- never once fired.
local BirdFlight = require("./BirdFlight")

local BirdRig = {}

-- A bird pitches about its body's X (right) and yaws about its Y (up). Everything below is the
-- work of saying that in whatever frame the armature happens to use.
local BODY_PITCH = { 1, 0, 0 }
local BODY_YAW = { 0, 1, 0 }

export type Axes = { pitch: Vector3, yaw: Vector3 }

-- ⚠ RESOLVE ONCE, AT SPAWN. The bone's rest orientation and the body's own frame rotate together
-- as the bird flies, so the axes ARE constants of the rig -- re-deriving them per frame would cost
-- three vector conversions a bone for an answer that never changes.
function BirdRig.axesOf(bone: Bone, body: BasePart): Axes
    local rest, bodyCF = bone.WorldCFrame, body.CFrame
    local basis = {}
    for i, v in { rest.XVector, rest.YVector, rest.ZVector } do
        local l = bodyCF:VectorToObjectSpace(v)
        basis[i] = { l.X, l.Y, l.Z }
    end
    return {
        pitch = Vector3.new(BirdFlight.toBoneSpace(basis, BODY_PITCH)),
        yaw = Vector3.new(BirdFlight.toBoneSpace(basis, BODY_YAW)),
    }
end

-- ⚠ YAW FIRST, THEN PITCH IN THE TURNED FRAME. A bird that has looked left and then raises its
-- beak raises it along the direction it is facing, not along the body's. Composing the other way
-- round would lift toward wherever the body points and read as the head sliding off the neck.
function BirdRig.pose(axes: Axes, pitchDeg: number, yawDeg: number): CFrame
    return CFrame.fromAxisAngle(axes.yaw, math.rad(yawDeg))
        * CFrame.fromAxisAngle(axes.pitch, math.rad(pitchDeg))
end

-- ⚠ SEAT BY THE PIVOT -- the authored origin -- AND THAT WAS ALWAYS RIGHT. Measured against the
-- owner's eye on a flat plank at kasagi height, pivot-seating lands the karasu exactly and the
-- uguisu within 0.002 studs. Only the mejiro misses, and only because it is the uguisu's MeshPart
-- resized in Studio: the pivot data does not rescale and the skinned mesh does not draw where
-- `Size` says it does.
--
-- ⚠ TWO MODELS WERE FITTED TO THE MEJIRO ALONE AND BOTH BROKE THE OTHER TWO SPECIES. Seating the
-- mesh BOUNDS was correct to 0.004 studs and read as a sunk bird; a "toe droop" clearance scaled by
-- body length then predicted the LARGER bird needed more lift, and it needed none. The residual is
-- carried per species in `BirdSpecies.seatNudge`, measured, because nothing readable off the part
-- predicts it.
--
-- ⚠ ITS *ROTATION* STAYS IGNORED. PivotOffset carries the FBX axis conversion (90, 0, -180), so
-- `PivotTo` reintroduces the nose-up attitude. Position from the pivot, rotation from `base`.
function BirdRig.seat(body: BasePart, wings: BasePart?, base: CFrame, nudge: number?)
    body.CFrame = base * CFrame.new(-body.PivotOffset.Position)
    if wings then
        wings.CFrame = base * CFrame.new(-wings.PivotOffset.Position)
    end
    local lift = nudge or 0
    if lift ~= 0 then
        local v = Vector3.new(0, lift, 0)
        body.CFrame = body.CFrame + v
        if wings then
            wings.CFrame = wings.CFrame + v
        end
    end
end

return BirdRig
