--!strict
-- Exposed bell-engine drive train: the wheel's axle extended into the house as the
-- MAIN SHAFT, a visible gear-down (small DriverGear meshing a big slow CamGear), the
-- CamShaft + Cam that draws/trips the shu-moku, and the VertShaft (with VertPaddle the
-- shu-moku's dowel kicks) carrying the drum on a two-arm DrumYoke. Part names are the
-- HammerController/DrumController contract — do not rename without retargeting them.
local Spec = require("./Spec")

local BellDrive = {}

function BellDrive.build(palette: { [string]: { number } }, L: any)
    local d = L.bellDrive
    local timber, iron = palette.timber, palette.ink
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
    -- Toothed bevel gear helper: a disc plus peg teeth around the rim, axis-aligned.
    -- axis: "X" | "Y" | "Z" (the gear's rotation axis). Teeth are cylinders whose long
    -- axis matches the gear axis, so they read as bevel pegs from every side.
    local AXIS_ROT: { [string]: { number } } = {
        X = Spec.ROT.IDENTITY,
        Y = Spec.ROT.CYL_VERTICAL,
        Z = Spec.ROT.CYL_ALONG_Z,
    }
    local function bevelGear(name: string, pos: { number }, r: number, teeth: number, axis: string)
        table.insert(
            children,
            Spec.part(name, {
                Size = { 0.5, r * 2, r * 2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, AXIS_ROT[axis]),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
        for t = 1, teeth do
            local a = (t - 1) * 2 * math.pi / teeth
            local u, v = math.cos(a) * (r + 0.1), math.sin(a) * (r + 0.1)
            local off = if axis == "Z" then { u, v, 0 } elseif axis == "Y" then { u, 0, v } else { 0, u, v }
            table.insert(
                children,
                Spec.part(`{name}_T{t}`, {
                    Size = { 0.7, 0.3, 0.3 },
                    Shape = "Cylinder",
                    CFrame = Spec.cframe(
                        { pos[1] + off[1], pos[2] + off[2], pos[3] + off[3] },
                        AXIS_ROT[axis]
                    ),
                    Color = iron,
                    Material = "Metal",
                    MaterialVariant = "IronDark",
                })
            )
        end
    end
    bevelGear("BevelMainA", d.bevelMainA, d.bevelR1, 10, "Z")
    bevelGear("BevelJackA", d.bevelJackA, d.bevelR1, 10, "Y")
    bevelGear("BevelJackB", d.bevelJackB, d.bevelR1, 10, "Y")
    bevelGear("BevelCamB", d.bevelCamB, d.bevelR2, 20, "X")
    -- Vertical octagonal JACK SHAFT (spun about Y by HammerController's jack group).
    local jk = d.jack
    local jlen = jk.yTop - jk.yBottom + 0.4
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
    -- Jack corner frame: a cypress post west of the shaft with an arm + static bands.
    table.insert(
        children,
        Spec.part("JackFramePost", {
            Size = { 0.9, 9.9, 0.9 },
            CFrame = Spec.cframe({ -16.4, 115.0, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    table.insert(
        children,
        Spec.part("JackFrameArm", {
            Size = { 1.9, 0.5, 0.9 },
            CFrame = Spec.cframe({ -15.65, 119.9, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    for i, by in { 117.0, 119.9 } do
        table.insert(
            children,
            Spec.part(`JackBand{i}`, {
                Size = { 0.4, 1.2, 1.2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ jk.x, by, jk.z }, Spec.ROT.CYL_VERTICAL),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
    end
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
            Size = { d.camWidth, d.camHubR * 2, d.camHubR * 2 },
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
            Color = timber,
            Material = "Wood",
        })
    )
    -- (The old horizontal-drum bearing yoke + drum bearings were removed with the
    -- mawari-dōrō redesign — the vertical lantern carries itself on its own corner posts,
    -- so BellDrive no longer references L.throwDrum at all.)

    -- DRUM DRIVE (pin-wheel): a flat gear caps the kick shaft (DriveGearA, spins about
    -- Y) and meshes a flat 2-paddle gear (DriveGearB). On a kick the paddles sweep
    -- horizontally and flick the drum's hanging south spoke (the controller animates it).
    table.insert(
        children,
        Spec.part("DriveGearA", {
            Size = { 0.5, d.driveGearAR * 2, d.driveGearAR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.driveGearA, Spec.ROT.CYL_VERTICAL),
            Color = iron,
            Material = "Metal",
        })
    )
    table.insert(
        children,
        Spec.part("DriveGearB", {
            Size = { 0.5, d.driveGearBR * 2, d.driveGearBR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.driveGearB, Spec.ROT.CYL_VERTICAL),
            Color = iron,
            Material = "Metal",
        })
    )
    -- short stub axle UNDER gear B, down to the roof, so the gear has visible support
    -- (gear A is carried by the kick shaft; B needs its own bearing).
    table.insert(
        children,
        Spec.part("DriveGearBShaft", {
            Size = { 3, 0.5, 0.5 }, -- vertical stub (CYL_VERTICAL); from the roof up to the gear
            Shape = "Cylinder",
            CFrame = Spec.cframe(
                { d.driveGearB[1], d.driveGearB[2] - 1.5, d.driveGearB[3] },
                Spec.ROT.CYL_VERTICAL
            ),
            Color = iron,
            Material = "Metal",
        })
    )
    -- A single paddle BEAM laid ON TOP of B (resting on the gear, so its two ends sweep
    -- just clear above gear A). The ends are the paddles that flick the drum's hanging
    -- south spoke as B turns. Length spans both rims + the reach.
    local beamLen = (d.driveGearBR + d.paddleReach) * 2
    table.insert(
        children,
        Spec.part("DrivePaddle", {
            Size = { beamLen, 0.5, 0.5 }, -- along X, centred on B, seated on the gear top
            CFrame = Spec.cframe({ d.driveGearB[1], d.driveGearB[2] + 0.5, d.driveGearB[3] }),
            Color = timber,
            Material = "Wood",
        })
    )
    -- Pillow blocks (generalized): cypress post → square plate → static IronDark ring
    -- → wider spinning collar. axis "Z" collars spin with the main shaft (^MainShaft
    -- names); the axis "X" collar spins with the cam (^Cam name). Per-entry y/baseY.
    for i, b in d.bearings do
        local PLATE_T = 0.2
        local pierTop = b.y - 1.55 / 2 - PLATE_T
        local bandRot = if b.axis == "Z" then Spec.ROT.CYL_ALONG_Z else Spec.ROT.IDENTITY
        table.insert(
            children,
            Spec.part(`BearingPost{i}`, {
                Size = { 0.9, pierTop - b.baseY, 0.9 },
                CFrame = Spec.cframe({ b.x, (pierTop + b.baseY) / 2, b.z }),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
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
