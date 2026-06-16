--!strict
-- Sozu (shishi-odoshi): a pivoting bamboo trough beside the driving wheel. Built
-- in its resting (empty, tipped-down-toward-fill) pose; SozuController tweens the
-- Lever between fill and dump and runs the cord to the drum. Part names Lever and
-- Pivot are the controller contract.
local Spec = require("./Spec")

local Sozu = {}

function Sozu.build(palette: { [string]: { number } }, L: any)
    local s = L.sozu
    local px, py, pz = s.pivot[1], s.pivot[2], s.pivot[3]
    local fy = L.clearing.floorY -- post/stone sit on the clearing floor, not world y0
    local bamboo = palette.timber
    local children = {
        Spec.part("Pivot", {
            Size = { 0.6, py + 1 - fy, 0.6 },
            CFrame = Spec.cframe({ px, (py + 1 + fy) / 2, pz }),
            Color = palette.ink,
            Material = "Wood",
        }),
        -- the trough lever: a bamboo tube, resting tilted toward its open (fill) end
        Spec.part("Lever", {
            Size = { 1.0, 1.0, s.troughLen },
            CFrame = Spec.cframe({ px, py, pz }, { 1, 0, 0, 0, 0.97, -0.26, 0, 0.26, 0.97 }),
            Color = bamboo,
            Material = "Wood",
        }),
        -- catch stone the lever clacks against
        Spec.part("CatchStone", {
            Size = { 1.6, 0.8, 1.2 },
            CFrame = Spec.cframe({ px, fy + 0.4, pz - s.troughLen / 2 }),
            Color = palette.gravel,
            Material = "Slate",
        }),
    }
    return Spec.model("Sozu", children)
end

return Sozu
