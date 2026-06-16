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
    -- The tsuki-za strike boss sits at the LOG's height, not a fraction of the
    -- bell — so it stays aligned with the shu-moku through any bell resize.
    -- strike boss on the bell's SW face, aligned with the rotated shu-moku log
    -- (bell is centered at x=0,z=0, so rotate about world-Y through the origin).
    local strikeY = L.shuMoku.restPos[2]
    local bossPos = Spec.rotY({ bx, strikeY, bz + r + 0.2 }, L.shuMoku.yaw)
    local bossRot = Spec.matMul(Spec.rotYMat(L.shuMoku.yaw), Spec.ROT.CYL_ALONG_Z)
    table.insert(
        children,
        Spec.part("LotusBoss", {
            Size = { 0.6, 1.8, 1.8 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(bossPos, bossRot),
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
    local sp = Spec.rotY(L.shuMoku.restPos, L.shuMoku.yaw)
    local logRot = Spec.matMul(Spec.rotYMat(L.shuMoku.yaw), Spec.ROT.CYL_ALONG_Z)
    table.insert(
        children,
        Spec.part("ShuMoku", {
            Size = { L.shuMoku.length, 2 * L.shuMoku.radius, 2 * L.shuMoku.radius },
            Shape = "Cylinder",
            CFrame = Spec.cframe(sp, logRot),
            Color = palette.timber,
            Material = "Wood",
        })
    )
    -- dowel peg on the shu-moku flank: sweeps with the swing and kicks the BellDrive paddle
    local dw = L.shuMoku.dowel
    local dpos, dlen, drot = Spec.segment(dw.from, { dw.from[1], dw.from[2], dw.from[3] + dw.length })
    table.insert(
        children,
        Spec.part("ShuMokuDowel", {
            Size = { dlen, 0.5, 0.5 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(dpos, drot),
            Color = palette.timber,
            Material = "Wood",
        })
    )
    -- Gantry: two side rails (along the yaw-rotated Z axis at ±railX, y = railY) on four posts.
    local sm = L.shuMoku
    local yaw = sm.yaw
    local railLen = sm.railZ[2] - sm.railZ[1] + 1
    local railMidZ = (sm.railZ[1] + sm.railZ[2]) / 2
    local railRot = Spec.matMul(Spec.rotYMat(yaw), Spec.ROT.IDENTITY)
    local y2 = L.clearing.floorY -- gantry posts rise from the clearing floor
    for i, rx in { sm.railX, -sm.railX } do
        local p = Spec.rotY({ rx, sm.railY, railMidZ }, yaw)
        table.insert(
            children,
            Spec.part(`Rail{i}`, {
                Size = { 0.8, 0.8, railLen },
                CFrame = Spec.cframe(p, railRot),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    local postSpots = {
        { sm.railX, sm.railZ[1] },
        { -sm.railX, sm.railZ[1] },
        { sm.railX, sm.railZ[2] },
        { -sm.railX, sm.railZ[2] },
    }
    for i, spot in postSpots do
        local p = Spec.rotY({ spot[1], (sm.railY + y2) / 2, spot[2] }, yaw)
        table.insert(
            children,
            Spec.part(`GantryPost{i}`, {
                Size = { 0.8, sm.railY - y2, 0.8 },
                CFrame = Spec.cframe(p),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    -- 4 angled chains: fixed rail tops down to the log's rest attach points (rotated).
    for i = 1, 4 do
        local top = Spec.rotY(sm.chainTops[i], yaw)
        local bot = Spec.rotY(sm.chainBottomsRest[i], yaw)
        local pos, len, rot = Spec.segment(top, bot)
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
