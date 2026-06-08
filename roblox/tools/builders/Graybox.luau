--!strict
-- Massing shells: validate scale & sightlines before any beauty work.
local Spec = require("./Spec")

local Graybox = {}
local GRAY = { 0.55, 0.55, 0.58 }

function Graybox.build(L)
    local children = {
        Spec.part("ToriiShell", {
            Size = { 14, 12, 2 },
            CFrame = Spec.cframe({ L.torii.pos[1], L.torii.pos[2] + 6, L.torii.pos[3] }),
            Color = GRAY,
        }),
        Spec.part("FlumeShell", {
            Size = {
                2,
                1.5,
                math.sqrt(
                    (L.flume.poolPos[1] - L.flume.wheelPos[1]) ^ 2
                        + (L.flume.poolPos[3] - L.flume.wheelPos[3]) ^ 2
                ),
            },
            CFrame = Spec.cframe(
                {
                    (L.flume.poolPos[1] + L.flume.wheelPos[1]) / 2,
                    (L.flume.poolPos[2] + L.flume.wheelPos[2] + L.flume.wheelRadius) / 2 + 1,
                    (L.flume.poolPos[3] + L.flume.wheelPos[3]) / 2,
                },
                Spec.yaw(
                    math.deg(
                        math.atan2(
                            L.flume.poolPos[1] - L.flume.wheelPos[1],
                            L.flume.poolPos[3] - L.flume.wheelPos[3]
                        )
                    )
                )
            ),
            Color = GRAY,
        }),
        Spec.part("PoolShell", {
            Size = L.flume.poolSize,
            CFrame = Spec.cframe(L.flume.poolPos),
            Color = { 0.3, 0.45, 0.55 },
        }),
        Spec.part("SteleShell", {
            Size = { 4, 7, 1.2 },
            CFrame = Spec.cframe({ L.stele.pos[1], L.stele.pos[2] + 3.5, L.stele.pos[3] }),
            Color = GRAY,
        }),
    }
    for i, t in L.teahouses do
        table.insert(
            children,
            Spec.part(`TeahouseShell{i}`, {
                Size = { 16, 9, 12 },
                CFrame = Spec.cframe({ t.pos[1], t.pos[2] + 4.5, t.pos[3] }, Spec.yaw(t.facing)),
                Color = { 0.55, 0.42, 0.28 }, -- legible timber brown (gate feedback)
            })
        )
    end
    for _, p in L.promontories do
        table.insert(
            children,
            Spec.part(`Promontory_{p.name}`, {
                Size = { 8, 1.5, 8 },
                CFrame = Spec.cframe({ p.pos[1], p.pos[2] + 0.75, p.pos[3] }),
                Color = { 0.45, 0.48, 0.52 },
            })
        )
    end
    return Spec.model("Graybox", children)
end

return Graybox
