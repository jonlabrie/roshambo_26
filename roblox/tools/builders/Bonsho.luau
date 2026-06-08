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
    -- Gantry: two side rails (along Z at x = ±railX, y = railY) on four posts.
    local sm = L.shuMoku
    local railX, railY = sm.railX, sm.railY
    local railZ1, railZ2 = sm.railZ[1], sm.railZ[2]
    local railLen = railZ2 - railZ1 + 1
    local railMidZ = (railZ1 + railZ2) / 2
    local y2 = 2 -- gantry posts rise from the apron gravel
    for i, rx in { railX, -railX } do
        table.insert(
            children,
            Spec.part(`Rail{i}`, {
                Size = { 0.8, 0.8, railLen },
                CFrame = Spec.cframe({ rx, railY, railMidZ }),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    local postSpots = { { railX, railZ1 }, { -railX, railZ1 }, { railX, railZ2 }, { -railX, railZ2 } }
    for i, spot in postSpots do
        table.insert(
            children,
            Spec.part(`GantryPost{i}`, {
                Size = { 0.8, railY - y2, 0.8 },
                CFrame = Spec.cframe({ spot[1], (railY + y2) / 2, spot[2] }),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    -- 4 angled chains: fixed rail tops down to the log's rest attach points.
    for i = 1, 4 do
        local pos, len, rot = Spec.segment(sm.chainTops[i], sm.chainBottomsRest[i])
        table.insert(
            children,
            Spec.part(`Chain{i}`, {
                Size = { len, 0.25, 0.25 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, rot),
                Color = { 0.25, 0.25, 0.28 },
                Material = "Metal",
            })
        )
    end
    return Spec.model("BonshoRig", children)
end

return Bonsho
