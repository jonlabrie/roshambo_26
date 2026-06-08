--!strict
-- Kakehi: raised timber flume flying the terrace pool's water over the
-- unbroken karesansui to the overshot wheel.
local Spec = require("./Spec")

local Kakehi = {}

local SEGMENTS = 4

function Kakehi.build(palette: { [string]: { number } }, L: any)
    local from = { L.flume.poolPos[1], L.flume.poolPos[2] + 0.8, L.flume.poolPos[3] }
    local to = { L.flume.wheelPos[1], L.flume.wheelPos[2] + L.flume.wheelRadius + 1.2, L.flume.wheelPos[3] }
    local children = {
        Spec.part("Pool", {
            Size = L.flume.poolSize,
            CFrame = Spec.cframe(L.flume.poolPos),
            Color = palette.water,
            Material = "Glass",
            Transparency = 0.25,
        }),
        Spec.part("WaterfallAnchor", {
            Size = { 1, 1, 1 },
            CFrame = Spec.cframe(to),
            Transparency = 1,
            CanCollide = false,
        }),
    }
    local dx = (to[1] - from[1]) / SEGMENTS
    local dy = (to[2] - from[2]) / SEGMENTS
    local dz = (to[3] - from[3]) / SEGMENTS
    local segLen = math.sqrt(dx * dx + dz * dz) + 0.6
    local yaw = math.atan2(dx, dz)
    local cy, sy = math.cos(yaw), math.sin(yaw)
    local rot = { sy, 0, cy, 0, 1, 0, cy, 0, -sy }
    for i = 1, SEGMENTS do
        local cxp = from[1] + dx * (i - 0.5)
        local cyp = from[2] + dy * (i - 0.5)
        local czp = from[3] + dz * (i - 0.5)
        table.insert(
            children,
            Spec.part(`Trough{i}`, {
                Size = { 2.2, 1.1, segLen },
                CFrame = Spec.cframe({ cxp, cyp, czp }, rot),
                Color = palette.timber,
                Material = "WoodPlanks",
            })
        )
        table.insert(
            children,
            Spec.part(`Water{i}`, {
                Size = { 1.5, 0.25, segLen },
                CFrame = Spec.cframe({ cxp, cyp + 0.55, czp }, rot),
                Color = palette.water,
                Material = "Glass",
                Transparency = 0.3,
                CanCollide = false,
            })
        )
        table.insert(
            children,
            Spec.part(`FlumePost{i}`, {
                Size = { 0.8, cyp - 0.55, 0.8 },
                CFrame = Spec.cframe({ cxp, (cyp - 0.55) / 2, czp }),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    return Spec.model("Kakehi", children)
end

return Kakehi
