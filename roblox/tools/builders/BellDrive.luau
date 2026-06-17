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

    -- main shaft (the wheel's Z-axle into the house)
    local sp, slen, srot = Spec.segment(d.shaftFrom, d.shaftTo)
    table.insert(
        children,
        Spec.part("MainShaft", {
            Size = { slen, d.shaftR * 2, d.shaftR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(sp, srot),
            Color = iron,
            Material = "Metal",
        })
    )
    -- BEVEL gear-down: the small DriverGear sits on the Z main shaft (axle along Z);
    -- the big slow CamGear sits on the E-W cam shaft (axle along X = cylinder default).
    -- Modelled as discs at 90° — a placeholder bevel; the controller turns both.
    table.insert(
        children,
        Spec.part("DriverGear", {
            Size = { 0.8, d.driverR * 2, d.driverR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.driverGear, Spec.ROT.CYL_ALONG_Z),
            Color = timber,
            Material = "WoodPlanks",
        })
    )
    table.insert(
        children,
        Spec.part("CamGear", {
            Size = { 0.8, d.camR * 2, d.camR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.camGear), -- axle along X (cylinder's default long axis)
            Color = timber,
            Material = "WoodPlanks",
        })
    )
    -- E-W cam shaft (along X) + the cam lug that draws the shu-moku's draw dowel.
    local cp, clen, crot = Spec.segment(d.camShaftFrom, d.camShaftTo)
    table.insert(
        children,
        Spec.part("CamShaft", {
            Size = { clen, d.camShaftR * 2, d.camShaftR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(cp, crot),
            Color = iron,
            Material = "Metal",
        })
    )
    -- SNAIL draw cam, profile in the Y-Z plane on the X cam shaft. The rising FLANK is
    -- shaped to the shu-moku draw dowel's MEASURED path, so the dowel rides the edge up
    -- without intersecting; at the peak it reaches the SHARP DROP WALL and falls off, so the
    -- log free-falls into the bell. Local angle 0° = +Y = the peak/release. FLANK[] is the
    -- measured edge radius every 15° down the draw flank (0→225°); a dwell (base circle) fills
    -- 225→DROP0; the drop wall (DROP0→360°, base→peak) is the steep release face. Faceted
    -- radial planks, all named ^Cam so the controller spins them about the cam shaft.
    local thick = 0.6 -- axial thickness (along X)
    local baseR = d.camHubR
    local cx, cy, cz = d.cam[1], d.cam[2], d.cam[3]
    -- measured edge radius at local 0,15,…,225° (the draw flank; falls peak→near-base)
    local FLANK =
        { 3.99, 3.81, 3.63, 3.45, 3.28, 3.11, 2.94, 2.78, 2.62, 2.46, 2.31, 2.17, 2.04, 1.93, 1.84, 1.78 }
    local TIGHTEN = 0.25 -- shave half the dowel diameter off the edge all around (tighter fit)
    local PEAK = FLANK[1] - TIGHTEN
    local DROP0 = 345 -- the drop wall spans DROP0..360° (base → peak): the sharp free-fall face
    local function profileR(deg: number): number
        if deg <= 225 then -- gradual draw flank: interpolate the measured curve (shaved)
            local i = math.floor(deg / 15)
            local f = (deg - i * 15) / 15
            local a = FLANK[i + 1]
            local b = FLANK[math.min(i + 2, #FLANK)]
            return (a + (b - a) * f) - TIGHTEN
        elseif deg >= DROP0 then -- sharp drop wall (free-fall face)
            return baseR + (PEAK - baseR) * (deg - DROP0) / (360 - DROP0)
        else -- dwell at the base circle
            return baseR
        end
    end
    local function plankRot(theta: number): { number }
        local c, s = math.cos(theta), math.sin(theta)
        return { 0, 0, 1, c, -s, 0, s, c, 0 } -- columns: X=(0,c,s) Y=(0,-s,c) Z=(1,0,0)
    end
    table.insert(
        children,
        Spec.part("Cam", {
            Size = { thick, baseR * 2, baseR * 2 }, -- base circle (hub / dwell radius)
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.cam),
            Color = timber,
            Material = "Wood",
        })
    )
    local STEP = 3 -- degrees per facet
    local plankW = (2 * math.pi * PEAK * STEP / 360) + 0.25 -- chord at the rim + overlap
    local n = 0
    for deg = 0, 360 - STEP, STEP do
        local r = profileR(deg)
        if r > baseR + 0.03 then
            local theta = math.rad(deg)
            local midR = (baseR + r) / 2
            n += 1
            table.insert(
                children,
                Spec.part(`CamEdge{n}`, {
                    Size = { (r - baseR) + 0.2, plankW, thick }, -- radial length × angular width × axial
                    CFrame = Spec.cframe(
                        { cx, cy + math.cos(theta) * midR, cz + math.sin(theta) * midR },
                        plankRot(theta)
                    ),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end
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
    -- Bearing yoke: an A-frame at EACH end of the drum axle. Two beams rise from the
    -- roof eaves at ~45° to meet at the axle, carrying the centred drum above the roof.
    -- Built from the drum's own centre (L.throwDrum) + the pavilion roof, so the
    -- support follows the drum. A-frames sit just OUTBOARD of the drum ends so they
    -- never cross the drum body; the drum's axle bears at the two apexes.
    local axle = L.throwDrum.pos
    local halfLen = L.throwDrum.length / 2 + 1
    local roofY = L.pavilion.pos[2] + L.pavilion.roofHeight
    local roofHalf = L.pavilion.postSpacing / 2 + 3.5 -- feet just INSIDE the eave (roof edge is at +4) so they don't overhang
    local n = 0
    for _, ze in { axle[3] - halfLen, axle[3] + halfLen } do
        for _, fx in { L.pavilion.pos[1] - roofHalf, L.pavilion.pos[1] + roofHalf } do
            n += 1
            local p, len, rot = Spec.segment({ fx, roofY, ze }, { axle[1], axle[2], ze })
            table.insert(
                children,
                Spec.part(`DrumYoke{n}`, {
                    Size = { len, 0.9, 0.9 },
                    Shape = "Cylinder",
                    CFrame = Spec.cframe(p, rot),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end
    for i, ze in { axle[3] - halfLen, axle[3] + halfLen } do
        table.insert(
            children,
            Spec.part(`DrumBearing{i}`, {
                Size = { 1.6, 1.6, 1.6 },
                CFrame = Spec.cframe({ axle[1], axle[2], ze }),
                Color = iron,
                Material = "Metal",
            })
        )
    end

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
    -- Shaft bearings: a trestle post up to an iron saddle where the shaft rides — along
    -- the main-shaft run, at the bevel corner, and just behind the cam on the E-W shaft.
    local shaftY = d.shaftFrom[2]
    for i, b in d.bearings do
        local x, z = b[1], b[2]
        table.insert(
            children,
            Spec.part(`BearingPost{i}`, {
                Size = { 0.9, shaftY - d.bearingBaseY, 0.9 },
                CFrame = Spec.cframe({ x, (shaftY + d.bearingBaseY) / 2, z }),
                Color = timber,
                Material = "Wood",
            })
        )
        table.insert(
            children,
            Spec.part(`BearingSaddle{i}`, {
                Size = { 1.3, 0.8, 1.3 },
                CFrame = Spec.cframe({ x, shaftY, z }),
                Color = iron,
                Material = "Metal",
            })
        )
    end
    return Spec.model("BellDrive", children)
end

return BellDrive
