--!strict
-- Exposed bell-engine drive train, water-mill style: the wheel's axle extended into
-- the house as the MAIN SHAFT; a FaceWheelMain whose through-cogs comb a vertical
-- LANTERN PINION (flanges + staves on the octagonal arbor), whose staves are combed
-- in turn by the big CamFaceWheel on the raised E-W cam shaft (12/24 cogs = the 2:1
-- reduction; the stave count cancels); the smooth mesh Cam that draws/trips the
-- shu-moku; and the VertShaft/VertPaddle kick chain. Part names are the
-- HammerController/DrumController contract — do not rename without retargeting them.
local Spec = require("./Spec")

local BellDrive = {}

function BellDrive.build(palette: { [string]: { number } }, L: any)
    local d = L.bellDrive
    local iron = palette.ink
    local children = {}

    -- main shaft (the wheel's Z-axle into the house). The named MainShaft is an
    -- INVISIBLE spin proxy (contract name; HammerController turns it) — the visible
    -- shaft is an octagonal cypress prism (4 boxes, 8 flats, matching the wheel's
    -- Wheel1T_SH profile) so the shaft's rotation actually reads.
    local sp, slen, srot = Spec.segment(d.shaftFrom, d.shaftTo)
    table.insert(
        children,
        Spec.part("MainShaft", {
            Size = { slen, d.shaftR * 2, d.shaftR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(sp, srot),
            Color = iron,
            Material = "Metal",
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )
    local function rotXm(a: number): { number }
        local co, si = math.cos(a), math.sin(a)
        return { 1, 0, 0, 0, co, -si, 0, si, co }
    end
    for k = 1, 4 do
        table.insert(
            children,
            Spec.part(`MainShaftF{k}`, {
                Size = { slen, 1.0, 0.42 },
                CFrame = Spec.cframe(sp, Spec.matMul(srot, rotXm((k - 1) * math.pi / 4))),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    local AXIS_ROT: { [string]: { number } } = {
        X = Spec.ROT.IDENTITY,
        Y = Spec.ROT.CYL_VERTICAL,
        Z = Spec.ROT.CYL_ALONG_Z,
    }
    -- Face-cog wheel (water-mill reference): a cypress disc whose rectangular cogs
    -- are mortised THROUGH the rim — bodies protrude toward the lantern cage,
    -- tails proud on the back face (individually replaceable; slight deterministic
    -- length jitter for the hand-hammered read). axis = rotation axis; towards =
    -- ±1 along it, the side the cogs work.
    local cogSeed = 4241
    local function cogJig(spread: number): number
        cogSeed = (1103515245 * cogSeed + 12345) % 2147483648
        return (cogSeed / 2147483648 - 0.5) * 2 * spread
    end
    local function faceCogWheel(
        name: string,
        pos: { number },
        r: number,
        nCogs: number,
        axis: string,
        towards: number,
        phaseDeg: number
    )
        table.insert(
            children,
            Spec.part(name, {
                Size = { 0.4, r * 2, r * 2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, AXIS_ROT[axis]),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
        for k = 1, nCogs do
            local a = math.rad(phaseDeg) + (k - 1) * 2 * math.pi / nCogs
            local ringR = r - 0.25
            local u, v = math.cos(a) * ringR, math.sin(a) * ringR
            local len = 1.0 + cogJig(0.06) -- gate-shaved ~2in: protrude 0.4, tails still 0.2 proud
            local bias = towards * (len / 2 - 0.4) -- protrude ~0.6 toward the cage, tail ~0.2 behind
            local off
            if axis == "Z" then
                off = { u, v, bias }
            else -- "X"
                off = { bias, u, v }
            end
            table.insert(
                children,
                Spec.part(`{name}_C{k}`, {
                    Size = { len, 0.35, 0.35 },
                    Shape = "Cylinder", -- ROUND pegs (gate: squared cogs read wrong)
                    CFrame = Spec.cframe(
                        { pos[1] + off[1], pos[2] + off[2], pos[3] + off[3] },
                        AXIS_ROT[axis]
                    ),
                    Color = palette.cypressWeathered,
                    Material = "Wood",
                    MaterialVariant = "CypressWeathered",
                })
            )
        end
    end
    faceCogWheel(
        "FaceWheelMain",
        d.faceWheelMain,
        d.faceWheelMainR,
        d.faceWheelMainCogs,
        "Z",
        1,
        d.faceWheelMainPhaseDeg
    )
    faceCogWheel("CamFaceWheel", d.camFaceWheel, d.camFaceWheelR, d.camFaceWheelCogs, "X", -1, 0)
    -- CamFaceWheel dressing: three through-spokes proud of the EAST face (gate: on
    -- the west they swept through the lantern's top flange — tolerances are tight)
    for s = 1, 3 do
        local a = (s - 1) * math.pi / 3 + math.pi / 6
        table.insert(
            children,
            Spec.part(`CamFaceWheelSpoke{s}`, {
                Size = { 0.25, 0.5, d.camFaceWheelR * 2 - 0.6 },
                CFrame = Spec.cframe(
                    { d.camFaceWheel[1] + 0.3, d.camFaceWheel[2], d.camFaceWheel[3] },
                    rotXm(a)
                ),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    table.insert(
        children,
        Spec.part("CamFaceWheelHub", {
            Size = { 0.6, 1.8, 1.8 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.camFaceWheel),
            Color = iron,
            Material = "Metal",
            MaterialVariant = "IronDark",
        })
    )
    -- Vertical octagonal LANTERN ARBOR (spun about Y by HammerController's jack group).
    local jk = d.jack
    local jlen = jk.yTop - jk.yBottom
    for k = 1, 4 do
        table.insert(
            children,
            Spec.part(`JackShaftF{k}`, {
                Size = { jlen, 0.7, 0.29 },
                CFrame = Spec.cframe(
                    { jk.x, (jk.yBottom + jk.yTop) / 2, jk.z },
                    Spec.matMul(Spec.ROT.CYL_VERTICAL, rotXm((k - 1) * math.pi / 4))
                ),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    -- LANTERN PINION: two flange discs + a cage of staves both face wheels comb.
    local lt = d.lantern
    for i, fy in { lt.yBottom, lt.yTop } do
        table.insert(
            children,
            Spec.part(`JackLanternFlange{i}`, {
                Size = { 0.35, lt.flangeR * 2, lt.flangeR * 2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ lt.x, fy, lt.z }, Spec.ROT.CYL_VERTICAL),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    local staveLen = lt.yTop - lt.yBottom - 0.35
    for s = 1, lt.staves do
        local a = (s - 0.5) * 2 * math.pi / lt.staves -- half-pitch offset off the mesh azimuths
        table.insert(
            children,
            Spec.part(`JackLanternStave{s}`, {
                Size = { staveLen, 0.28, 0.28 },
                CFrame = Spec.cframe({
                    lt.x + math.cos(a) * lt.staveRingR,
                    (lt.yBottom + lt.yTop) / 2,
                    lt.z + math.sin(a) * lt.staveRingR,
                }, Spec.ROT.CYL_VERTICAL),
                Shape = "Cylinder",
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    -- The lantern HANGS from a short arm off the corner pillow post (bearings[5],
    -- which also carries the cam shaft's gear-end bearing on top — one member,
    -- two jobs). Iron band clamps the arbor's top stub under the arm.
    table.insert(
        children,
        Spec.part("JackHangerArm", {
            Size = { 2.55, 0.5, 0.7 }, -- runs EAST along the cam-shaft line, pillow post → arbor
            CFrame = Spec.cframe({ -15.875, 119.1, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    table.insert(
        children,
        Spec.part("JackBand1", {
            Size = { 0.4, 1.2, 1.2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ jk.x, 118.9, jk.z }, Spec.ROT.CYL_VERTICAL),
            Color = iron,
            Material = "Metal",
            MaterialVariant = "IronDark",
        })
    )
    -- Lower support (gate): a foot arm off the pillow post under the cage, carrying
    -- an iron STEP cup the arbor bottom rides in — the lantern's bottom bearing.
    table.insert(
        children,
        Spec.part("JackFootArm", {
            Size = { 2.55, 0.5, 0.7 },
            CFrame = Spec.cframe({ -15.875, 115.725, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    table.insert(
        children,
        Spec.part("JackStep", {
            Size = { 0.55, 0.9, 0.9 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ jk.x, 116.0, jk.z }, Spec.ROT.CYL_VERTICAL),
            Color = iron,
            Material = "Metal",
            MaterialVariant = "IronDark",
        })
    )
    -- CAM SHAFT: invisible contract proxy + visible octagonal prism (^Cam names →
    -- HammerController's cam group spins them with the cam).
    local cs = d.camShaft
    local csLen = cs.toX - cs.fromX
    local csMid = { (cs.fromX + cs.toX) / 2, cs.y, cs.z }
    table.insert(
        children,
        Spec.part("CamShaft", {
            Size = { csLen, cs.r * 2, cs.r * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(csMid),
            Color = iron,
            Material = "Metal",
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )
    for k = 1, 4 do
        table.insert(
            children,
            Spec.part(`CamShaftF{k}`, {
                Size = { csLen, 0.85, 0.36 },
                CFrame = Spec.cframe(csMid, rotXm((k - 1) * math.pi / 4)),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    -- SNAIL CAM: the smooth flank ships as a CLIENT-BUILT EditableMesh (CamMesh via
    -- HammerController — EditableMesh parts don't replicate and Rojo JSON can't carry
    -- mesh geometry). The builder emits only the visible HUB disc, which doubles as
    -- the ^Cam contract part the controller spins and the Edit-time position reference.
    table.insert(
        children,
        Spec.part("Cam", {
            -- PROUD of the mesh flank (±0.125 per side): the mesh is solid to its core,
            -- so a hub at the same width would be face-coplanar with it and z-fight
            Size = { d.camWidth + 0.25, d.camHubR * 2, d.camHubR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.cam),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    -- vertical drum shaft + the paddle the dowel kicks
    local vp, vlen = Spec.segment(d.vertBase, d.vertTop)
    table.insert(
        children,
        Spec.part("VertShaft", {
            Size = { vlen, d.vertR * 2, d.vertR * 2 }, -- length first (CYL_VERTICAL rotates local-X → up)
            Shape = "Cylinder",
            CFrame = Spec.cframe(vp, Spec.ROT.CYL_VERTICAL),
            Color = iron,
            Material = "Metal",
        })
    )
    table.insert(
        children,
        Spec.part("VertPaddle", {
            Size = { d.paddleLen, 1.4, 0.5 },
            CFrame = Spec.cframe(d.paddle),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    -- (The old pin-wheel gear cluster at the shaft top was REMOVED 2026-07-23:
    -- the mawari-dōrō sits at the crown and the upper mechanism is hidden by the
    -- roof, so the kick shaft now simply runs UP INTO the lantern's underside as
    -- its spindle — the honest mawari-dōrō read; the gears were unearned clutter.)
    -- Pillow blocks (generalized): cypress post → square plate → static IronDark ring
    -- → wider spinning collar. axis "Z" collars spin with the main shaft (^MainShaft
    -- names); the axis "X" collar spins with the cam (^Cam name). Per-entry y/baseY.
    for i, b in d.bearings do
        local PLATE_T = 0.2
        local pierTop = b.y - 1.55 / 2 - PLATE_T
        local bandRot = if b.axis == "Z" then Spec.ROT.CYL_ALONG_Z else Spec.ROT.IDENTITY
        -- dressed-slate plinth footing (the Shoro post read): proud of the post's
        -- faces, top 0.6 above grade, rooted below it to the bearing's baseY
        local plinthTop = d.bearingPlinthTop
        table.insert(
            children,
            Spec.part(`BearingPlinth{i}`, {
                Size = { 1.4, plinthTop - b.baseY, 1.4 },
                CFrame = Spec.cframe({ b.x, (plinthTop + b.baseY) / 2, b.z }),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
        table.insert(
            children,
            Spec.part(`BearingPost{i}`, {
                Size = { 0.9, pierTop - plinthTop, 0.9 },
                CFrame = Spec.cframe({ b.x, (pierTop + plinthTop) / 2, b.z }),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressVertical", -- rotated maps: grain runs UP flat vertical posts
            })
        )
        table.insert(
            children,
            Spec.part(`BearingPlate{i}`, {
                Size = { 0.9, PLATE_T, 0.9 },
                CFrame = Spec.cframe({ b.x, pierTop + PLATE_T / 2, b.z }),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
        table.insert(
            children,
            Spec.part(`BearingSaddle{i}`, {
                Size = { 0.5, 1.55, 1.55 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ b.x, b.y, b.z }, bandRot),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
        local collarName = if b.axis == "Z" then `MainShaftCollar{i}` else `CamCollar{i}`
        table.insert(
            children,
            Spec.part(collarName, {
                Size = { 0.72, 1.24, 1.24 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ b.x, b.y, b.z }, bandRot),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
    end
    return Spec.model("BellDrive", children)
end

return BellDrive
