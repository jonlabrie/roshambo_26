--!strict
-- Overshot waterwheel + ratchet drum: the machine that draws the shu-moku.
local Spec = require("./Spec")

local Waterwheel = {}

function Waterwheel.build(palette: { [string]: { number } }, L: any)
    local w = L.flume.wheelPos
    local R = L.flume.wheelRadius
    local timber = palette.timber
    local children = {
        Spec.part("Wheel", {
            Size = { 1.2, 2 * R, 2 * R },
            Shape = "Cylinder",
            CFrame = Spec.cframe(w),
            Color = timber,
            Material = "Wood",
        }),
        Spec.part("Axle", {
            Size = { 4.5, 0.8, 0.8 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(w),
            Color = palette.ink,
            Material = "Metal",
        }),
        Spec.part("RatchetDrum", {
            Size = { 1.6, 1.6, 1.6 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ w[1] + 2.4, w[2], w[3] }),
            Color = palette.ink,
            Material = "Metal",
        }),
        Spec.part("DrawRope", {
            Size = { 0.25, 0.25, 11 },
            CFrame = Spec.cframe({
                (w[1] + L.shuMoku.restPos[1]) / 2 + 1.2,
                (w[2] + L.shuMoku.restPos[2]) / 2,
                (w[3] + L.shuMoku.restPos[3]) / 2,
            }),
            Color = { 0.55, 0.48, 0.35 },
            Material = "Fabric",
        }),
    }
    for i = 1, 8 do
        local a = (i - 1) * math.pi / 4
        table.insert(
            children,
            Spec.part(`Paddle{i}`, {
                Size = { 1.4, 1.8, 0.4 },
                CFrame = Spec.cframe({ w[1], w[2] + (R - 0.6) * math.cos(a), w[3] + (R - 0.6) * math.sin(a) }),
                Color = timber,
                Material = "WoodPlanks",
            })
        )
    end
    for i, dx in { -1.6, 1.6 } do
        table.insert(
            children,
            Spec.part(`Support{i}`, {
                Size = { 0.9, w[2] + R * 0.4, 0.9 },
                CFrame = Spec.cframe({ w[1] + dx, (w[2] + R * 0.4) / 2, w[3] }),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    return Spec.model("Waterwheel", children)
end

return Waterwheel
