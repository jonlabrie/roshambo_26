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
    -- Header cistern on stilts: two short posts from the ground up to the pool
    -- bottom. The pool now floats on the central axis above the wheel.
    local poolBottom = L.flume.poolPos[2] - L.flume.poolSize[2] / 2
    local stiltY2 = 2 -- post foot rests on the apron gravel band
    local stiltHeight = poolBottom - stiltY2
    for i, dx in { -3, 3 } do
        table.insert(
            children,
            Spec.part(`PoolStilt{i}`, {
                Size = { 0.9, stiltHeight, 0.9 },
                CFrame = Spec.cframe({
                    L.flume.poolPos[1] + dx,
                    stiltY2 + stiltHeight / 2,
                    L.flume.poolPos[3],
                }),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    local dx = (to[1] - from[1]) / SEGMENTS
    local dy = (to[2] - from[2]) / SEGMENTS
    local dz = (to[3] - from[3]) / SEGMENTS
    local segLen = math.sqrt(dx * dx + dz * dz) + 0.6
    -- yaw the trough so its local Z (length) points along the pool→wheel run.
    -- Spec.yaw maps local Z → (sin θ, 0, cos θ); θ = atan2(dx, dz) = the heading.
    local rot = Spec.yaw(math.deg(math.atan2(dx, dz)))
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
