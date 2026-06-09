--!strict
-- Asakura-style undershot waterwheel cluster sitting in the SW creek. Each wheel
-- is a timber disc whose axle lies along NW-SE (waterwheel.yaw) so it rolls with
-- the SW->NE current. centers[driver] carries the RatchetDrum that the runtime
-- DriveRope (HammerController) leaves from toward the shu-moku log.
local Spec = require("./Spec")

local Waterwheel = {}

-- Rotation about local X (the wheel's axle) by angle a, row-major. Used to tilt
-- each float so it radiates from the hub instead of all pointing the same way.
local function rotX(a: number): { number }
    local c, s = math.cos(a), math.sin(a)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Waterwheel.build(palette: { [string]: { number } }, L: any)
    local W = L.waterwheel
    local R = W.radius
    local timber = palette.timber
    local rot = Spec.yaw(W.yaw) -- axle (local X of the cylinder) swung to NW-SE
    local children = {}

    for wi, c in W.centers do
        table.insert(
            children,
            Spec.part(`Wheel{wi}`, {
                Size = { 1.2, 2 * R, 2 * R },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = timber,
                Material = "Wood",
            })
        )
        table.insert(
            children,
            Spec.part(`Axle{wi}`, {
                Size = { 4.5, 0.8, 0.8 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = palette.ink,
                Material = "Metal",
            })
        )
        -- Scoop buckets ring the rim: raked ~26° off radial so they read as Asakura
        -- scoop tubes that both catch the current (drive) and cup water to lift it.
        -- (Kept the Paddle name so WheelController spins them unchanged.)
        local RAKE = 0.45
        for i = 1, 8 do
            local a = (i - 1) * math.pi / 4
            local off = Spec.rotY({ 0, (R - 0.6) * math.cos(a), (R - 0.6) * math.sin(a) }, W.yaw)
            local prot = Spec.matMul(rot, rotX(a + RAKE))
            table.insert(
                children,
                Spec.part(`Paddle{wi}_{i}`, {
                    Size = { 1.4, 1.6, 0.9 }, -- deeper than a flat blade → reads as a cup
                    CFrame = Spec.cframe({ c[1] + off[1], c[2] + off[2], c[3] + off[3] }, prot),
                    Color = timber,
                    Material = "WoodPlanks",
                })
            )
        end
        -- bearing posts at the axle ends, standing on the carved creek bed (W.bedY)
        -- and rising just past the axle, so they don't float over the water trench.
        local postTop = c[2] + R * 0.4
        for si, d in { -1.6, 1.6 } do
            local off = Spec.rotY({ d, 0, 0 }, W.yaw)
            table.insert(
                children,
                Spec.part(`Support{wi}_{si}`, {
                    Size = { 0.9, postTop - W.bedY, 0.9 },
                    CFrame = Spec.cframe({ c[1] + off[1], (postTop + W.bedY) / 2, c[3] + off[3] }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end

    local dc = W.centers[W.driver]
    local toward = Spec.rotY({ 0, 0, -2.4 }, W.driveYaw) -- toward the bell along the drive line
    table.insert(
        children,
        Spec.part("RatchetDrum", {
            Size = { 1.6, 1.6, 1.6 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ dc[1] + toward[1], dc[2] + toward[2], dc[3] + toward[3] }, rot),
            Color = palette.ink,
            Material = "Metal",
        })
    )

    -- launder (open trough) carrying scoop-lifted water from the wheel top down to
    -- the sōzu mouth (waterwheel.launderTo). Static — it does not spin with the wheel.
    local ltop = { dc[1], dc[2] + R, dc[3] }
    local lpos, llen, lrot = Spec.segment(ltop, W.launderTo)
    table.insert(
        children,
        Spec.part("Launder", {
            Size = { llen, 0.5, 1.4 },
            CFrame = Spec.cframe(lpos, lrot),
            Color = timber,
            Material = "Wood",
        })
    )
    return Spec.model("Waterwheel", children)
end

return Waterwheel
