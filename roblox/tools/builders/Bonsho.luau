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
    -- BellHanger: an iron strap from the crown lug up to the shōrō BellBeam underside,
    -- so the bell visibly HANGS from the crossbeam. beamBottomY mirrors Shoro.BellBeam
    -- (placed at roofHeight-1.8, height 1.8 → underside = base + roofHeight - 2.7).
    local crownTopY = by + h / 2 + 1.9
    local beamBottomY = L.pavilion.pos[2] + L.pavilion.roofHeight - 2.7
    table.insert(
        children,
        Spec.part("BellHanger", {
            Size = { 0.5, (beamBottomY - crownTopY) + 1.0, 0.5 }, -- overlaps 0.5 into the lug + the beam
            CFrame = Spec.cframe({ bx, (crownTopY + beamBottomY) / 2, bz }),
            Color = { 0.22, 0.22, 0.25 },
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
    -- DRAW dowel: a horizontal peg through the log's tail that the BellDrive cam
    -- catches to draw the log back over the round (reaches West to the cam).
    local draw = L.shuMoku.drawDowel
    local drp, drl, drr = Spec.segment(draw.from, draw.to)
    table.insert(
        children,
        Spec.part("ShuMokuDrawDowel", {
            Size = { drl, 0.5, 0.5 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(drp, drr),
            Color = palette.timber,
            Material = "Wood",
        })
    )
    -- KICK dowel: an east-flank peg; the forward swing kicks the BellDrive
    -- vertical-shaft paddle to spin the throw drum.
    local kick = L.shuMoku.kickDowel
    local kdp, kdl, kdr = Spec.segment(kick.from, kick.to)
    table.insert(
        children,
        Spec.part("ShuMokuDowel", {
            Size = { kdl, 0.5, 0.5 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(kdp, kdr),
            Color = palette.timber,
            Material = "Wood",
        })
    )
    -- Gantry: two side rails (along the yaw-rotated Z axis at ±railX, y = railY) on four
    -- posts. railX/railZ are half-widths about the shu-moku's CENTRELINE (cx), so the
    -- gantry straddles the log instead of the world origin.
    local sm = L.shuMoku
    local cx = sm.restPos[1] -- shu-moku centreline X (gantry + chains centre here)
    local yaw = sm.yaw
    local railLen = sm.railZ[2] - sm.railZ[1] + 1
    local railMidZ = (sm.railZ[1] + sm.railZ[2]) / 2
    local railRot = Spec.matMul(Spec.rotYMat(yaw), Spec.ROT.IDENTITY)
    local y2 = L.clearing.floorY -- gantry posts rise from the clearing floor
    for i, rx in { sm.railX, -sm.railX } do
        local p = Spec.rotY({ cx + rx, sm.railY, railMidZ }, yaw)
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
        { cx + sm.railX, sm.railZ[1] },
        { cx - sm.railX, sm.railZ[1] },
        { cx + sm.railX, sm.railZ[2] },
        { cx - sm.railX, sm.railZ[2] },
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
    -- Cross-braces (along X) tying the two rails together at the top of each post pair,
    -- so the gantry reads as a rigid frame.
    -- selene: allow(shadowing)
    for i, bz in { sm.railZ[1], sm.railZ[2] } do
        local p = Spec.rotY({ cx, sm.railY, bz }, yaw)
        table.insert(
            children,
            Spec.part(`GantryBrace{i}`, {
                Size = { 2 * sm.railX, 0.8, 0.8 },
                CFrame = Spec.cframe(p, railRot),
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
