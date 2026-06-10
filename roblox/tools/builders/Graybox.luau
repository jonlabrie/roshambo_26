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
        Spec.part("SteleShell", {
            Size = { 4, 7, 1.2 },
            CFrame = Spec.cframe({ L.stele.pos[1], L.stele.pos[2] + 3.5, L.stele.pos[3] }),
            Color = GRAY,
        }),
    }
    -- (TeahouseShell massing removed — real huts now ship via Teahouse.luau.)
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
