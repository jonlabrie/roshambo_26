--!strict
-- Bronze bonshō (Chion-in form): lathed sections, dome, lotus boss, crown
-- lugs; the shu-moku log on chains. Part names Bonsho and ShuMoku are the
-- HammerController contract — do not rename without retargeting it.
local Spec = require("./Spec")

local Bonsho = {}

-- The visible cast-bronze meshes ship as assets/meshes/BonshoBell.rbxmx
-- (→ RoshamboStage.BonshoBell) because Rojo cannot load mesh geometry from a MeshId
-- set in JSON — a JSON MeshPart renders at native (unscaled) size. Asset ids for the
-- record: BellBody=124216263682136, Ryuzu=93544424620557, LotusBoss=128610662938981.
-- This builder emits only the primitives + the mechanism-contract parts.
function Bonsho.build(palette: { [string]: { number } }, L: any)
    local bronze = palette.bronzePatina
    local bx, by, bz = L.bell.pos[1], L.bell.pos[2], L.bell.pos[3]
    local h, r = L.bell.height, L.bell.radius
    local children = {}
    -- Two raised obi band-rings around the lower body: thin discs ~0.05 proud of the
    -- skirt (a shoulder band was dropped at the gate — it sat on the taper and read proud).
    for i, dy in { -1, -4.5 } do
        table.insert(
            children,
            Spec.part(`Band{i}`, {
                Size = { 0.3, 2 * r + 0.1, 2 * r + 0.1 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ bx, by + dy, bz }, Spec.ROT.CYL_VERTICAL),
                Color = bronze,
                Material = "Metal",
                MaterialVariant = "BronzePatina",
            })
        )
    end
    -- BellHanger: an iron strap from the crown lug up to the shōrō BellBeam underside,
    -- so the bell visibly HANGS from the crossbeam. beamBottomY mirrors Shoro.BellBeam,
    -- which now rests ATOP the ring beams (centre roofHeight+0.9, height 1.8 →
    -- underside = base + roofHeight).
    local crownTopY = by + h / 2 + 1.9
    local beamBottomY = L.pavilion.pos[2] + L.pavilion.roofHeight
    table.insert(
        children,
        Spec.part("BellHanger", {
            Size = { 0.5, (beamBottomY - crownTopY) + 1.0, 0.5 }, -- overlaps 0.5 into the lug + the beam
            CFrame = Spec.cframe({ bx, (crownTopY + beamBottomY) / 2, bz }),
            Color = { 0.22, 0.22, 0.25 },
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
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
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
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
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
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    -- Tower-hung suspension: a cypress hanger beam spans the two +Z pavilion posts,
    -- two spreader arms bridge the chain planes (post plane z=+9 sits between them),
    -- and iron eyes take the four hemp-rope drops. The freestanding gantry is gone.
    local sm = L.shuMoku
    local yaw = sm.yaw
    local px = L.pavilion.postSpacing / 2
    local hemp = { 0.76, 0.66, 0.47 }
    local beamP = Spec.rotY({ L.pavilion.pos[1], sm.hangerY, L.pavilion.pos[3] + px }, yaw)
    table.insert(
        children,
        Spec.part("HangerBeam", {
            Size = { 2 * px + 2.4, 1.2, 1.4 },
            CFrame = Spec.cframe(beamP, Spec.rotYMat(yaw)),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    local spreadZ = (sm.chainTops[1][3] + sm.chainTops[2][3]) / 2 -- chain-plane midpoint
    local spreadLen = sm.chainTops[2][3] - sm.chainTops[1][3] + 2 -- spans both planes + overhang
    for i, sx in { sm.chainTops[1][1], sm.chainTops[3][1] } do
        local p = Spec.rotY({ sx, sm.hangerY - 1.1, spreadZ }, yaw)
        table.insert(
            children,
            Spec.part(`Spreader{i}`, {
                Size = { 1.0, 1.0, spreadLen },
                CFrame = Spec.cframe(p, Spec.rotYMat(yaw)),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    for i = 1, 4 do
        -- eyes mount just below the spreader underside; ropes lead off from them
        local e = Spec.rotY({ sm.chainTops[i][1], sm.chainTops[i][2] + 0.1, sm.chainTops[i][3] }, yaw)
        table.insert(
            children,
            Spec.part(`RopeEye{i}`, {
                Size = { 0.5, 0.55, 0.55 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(e),
                Color = palette.ink,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
    end
    -- 4 hemp-rope hangers: fixed spreader eyes down to the log's rest attach points.
    for i = 1, 4 do
        local top = Spec.rotY(sm.chainTops[i], yaw)
        local bot = Spec.rotY(sm.chainBottomsRest[i], yaw)
        local pos, len, rot = Spec.segment(top, bot)
        table.insert(
            children,
            Spec.part(`Chain{i}`, {
                Size = { len, 0.22, 0.22 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, rot),
                Color = hemp,
                Material = "Fabric",
                MaterialVariant = "HempRope",
            })
        )
    end
    -- Full-dress fittings, rigid to the log (HammerController re-applies the log's
    -- delta each frame): domed bronze nose at the striking (-Z) end, iron bands,
    -- hemp whipping at the rope stations, iron tail ring where the draw leads off.
    local cx2, cy2 = sm.restPos[1], sm.restPos[2]
    local function logRing(name: string, z: number, od: number, w: number, variant: string, color: { number })
        local p = Spec.rotY({ cx2, cy2, z }, yaw)
        table.insert(
            children,
            Spec.part(name, {
                Size = { w, od, od },
                Shape = "Cylinder",
                CFrame = Spec.cframe(p, logRot),
                Color = color,
                Material = if variant == "HempRope" or variant == "HempRopeFine" then "Fabric" else "Metal",
                MaterialVariant = variant,
            })
        )
    end
    local noseP = Spec.rotY({ cx2, cy2, sm.restPos[3] - sm.length / 2 + 0.15 }, yaw)
    table.insert(
        children,
        Spec.part("ShuMokuD_Nose", {
            Size = { 1.7, 1.7, 1.7 },
            Shape = "Ball",
            CFrame = Spec.cframe(noseP),
            Color = palette.bronzePatina,
            Material = "Metal",
            MaterialVariant = "BronzePatina",
        })
    )
    logRing("ShuMokuD_Band1", sm.restPos[3] - 0.6, 1.75, 0.35, "IronDark", palette.ink)
    logRing("ShuMokuD_Band2", sm.restPos[3] + 1.4, 1.75, 0.35, "IronDark", palette.ink)
    -- whipping = WOUND CORD: three thin stacked rings with visible gaps per station
    -- (geometry sells the wrap; one fat textured collar reads flat). HempRopeFine is
    -- the same Rope001 maps at a small StudsPerTile so the weave suits little parts.
    for wi, wz in { sm.chainBottomsRest[1][3], sm.chainBottomsRest[2][3] } do
        logRing(`ShuMokuD_Whip{wi}`, wz, 1.8, 0.2, "HempRopeFine", hemp)
        logRing(`ShuMokuD_Whip{wi}b`, wz - 0.22, 1.78, 0.2, "HempRopeFine", hemp)
        logRing(`ShuMokuD_Whip{wi}c`, wz + 0.22, 1.76, 0.2, "HempRopeFine", hemp)
    end
    -- tail ring overhangs the log butt by 0.1 (a ferrule cap): the butt plane sits
    -- INSIDE the solid ring, so no coincident faces to z-fight
    logRing("ShuMokuD_TailRing", sm.restPos[3] + sm.length / 2 - 0.05, 1.95, 0.3, "IronDark", palette.ink)
    return Spec.model("BonshoRig", children)
end

return Bonsho
