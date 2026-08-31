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

-- ⚠ SEAT BY THE FEET, WHICH ARE THE RENDERED BOX BOTTOM, NOT THE PIVOT. Both halves are placed by
-- `PivotOffset.Position` first -- that is what keeps the body and the wings locked to each other,
-- and it is exact -- and then the pair is dropped together so the bird's lowest point rests on
-- `base`. Only the pair's height changes; their relationship does not.
--
-- ⚠ THE PIVOT'S *ROTATION* STAYS IGNORED. It carries the FBX axis conversion (90, 0, -180), so
-- `PivotTo` reintroduces the nose-up attitude. Position from the pivot, rotation from `base`.
function BirdRig.seat(body: BasePart, wings: BasePart?, base: CFrame)
    body.CFrame = base * CFrame.new(-body.PivotOffset.Position)
    if wings then
        wings.CFrame = base * CFrame.new(-wings.PivotOffset.Position)
    end
    local drop = BirdFlight.footOffset(body.Position.Y, body.Size.Y, base.Position.Y)
    if drop ~= 0 then
        local fix = Vector3.new(0, drop, 0)
        body.CFrame = body.CFrame - fix
        if wings then
            wings.CFrame = wings.CFrame - fix
        end
    end
end

return BirdRig
