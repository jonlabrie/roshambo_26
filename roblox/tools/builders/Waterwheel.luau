--!strict
-- Asakura-style undershot waterwheel cluster sitting in the SW creek. Each wheel
-- is a timber disc whose axle lies along NW-SE (waterwheel.yaw) so it rolls with
-- the SW->NE current. centers[driver] carries the RatchetDrum that the runtime
-- DriveRope (HammerController) leaves from toward the shu-moku log.
local Spec = require("./Spec")

local Waterwheel = {}

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
        for i = 1, 8 do
            local a = (i - 1) * math.pi / 4
            local off = Spec.rotY({ 0, (R - 0.6) * math.cos(a), (R - 0.6) * math.sin(a) }, W.yaw)
            table.insert(
                children,
                Spec.part(`Paddle{wi}_{i}`, {
                    Size = { 1.4, 1.8, 0.4 },
                    CFrame = Spec.cframe({ c[1] + off[1], c[2] + off[2], c[3] + off[3] }, rot),
                    Color = timber,
                    Material = "WoodPlanks",
                })
            )
        end
        for si, d in { -1.6, 1.6 } do
            local off = Spec.rotY({ d, 0, 0 }, W.yaw)
            table.insert(
                children,
                Spec.part(`Support{wi}_{si}`, {
                    Size = { 0.9, c[2] + R * 0.4, 0.9 },
                    CFrame = Spec.cframe({ c[1] + off[1], (c[2] + R * 0.4) / 2, c[3] + off[3] }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end

    local dc = W.centers[W.driver]
    local toward = Spec.rotY({ 0, 0, -2.4 }, W.yaw)
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
    return Spec.model("Waterwheel", children)
end

return Waterwheel
