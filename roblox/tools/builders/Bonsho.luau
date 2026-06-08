--!strict
-- Bronze bonshō (Chion-in form): lathed sections, dome, lotus boss, crown
-- lugs; the shu-moku log on chains. Part names Bonsho and ShuMoku are the
-- HammerController contract — do not rename without retargeting it.
local Spec = require("./Spec")

local Bonsho = {}

function Bonsho.build(palette: { [string]: { number } }, L: any)
    local bronze = { 0.36, 0.30, 0.22 }
    local bx, by, bz = L.bell.pos[1], L.bell.pos[2], L.bell.pos[3]
    local h, r = L.bell.height, L.bell.radius
    local profile = { 1.0, 0.93, 0.88, 0.86, 0.78 }
    local sectionH = h / #profile
    local children = {}
    for i, f in profile do
        local d = 2 * r * f
        table.insert(
            children,
            Spec.part(`BellSection{i}`, {
                Size = { sectionH, d, d },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ bx, by - h / 2 + sectionH * (i - 0.5), bz }, Spec.ROT.CYL_VERTICAL),
                Color = bronze,
                Material = "Metal",
            })
        )
    end
    table.insert(
        children,
        Spec.part("BellDome", {
            Size = { 2 * r * 0.7, 1.6, 2 * r * 0.7 },
            Shape = "Ball",
            CFrame = Spec.cframe({ bx, by + h / 2, bz }),
            Color = bronze,
            Material = "Metal",
        })
    )
    table.insert(
        children,
        Spec.part("CrownLug", {
            Size = { 1.2, 1.4, 1.2 },
            CFrame = Spec.cframe({ bx, by + h / 2 + 1.2, bz }),
            Color = bronze,
            Material = "Metal",
        })
    )
    table.insert(
        children,
        Spec.part("LotusBoss", {
            Size = { 0.6, 1.8, 1.8 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ bx, by - h * 0.1, bz + r + 0.2 }, Spec.ROT.CYL_ALONG_Z),
            Color = palette.gold,
            Material = "Metal",
        })
    )
    table.insert(
        children,
        Spec.part("Bonsho", {
            Size = { h, 2 * r, 2 * r },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ bx, by, bz }, Spec.ROT.CYL_VERTICAL),
            Color = bronze,
            Transparency = 1,
            CanCollide = false,
        })
    )
    local sp = L.shuMoku.restPos
    table.insert(
        children,
        Spec.part("ShuMoku", {
            Size = { L.shuMoku.length, 2 * L.shuMoku.radius, 2 * L.shuMoku.radius },
            Shape = "Cylinder",
            CFrame = Spec.cframe(sp, Spec.ROT.CYL_ALONG_Z),
            Color = palette.timber,
            Material = "Wood",
        })
    )
    for i, off in { -2.2, 2.2 } do
        table.insert(
            children,
            Spec.part(`Chain{i}`, {
                Size = { 7, 0.25, 0.25 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ sp[1], sp[2] + 3.8, sp[3] + off }, Spec.ROT.CYL_VERTICAL),
                Color = { 0.25, 0.25, 0.28 },
                Material = "Metal",
            })
        )
    end
    return Spec.model("BonshoRig", children)
end

return Bonsho
