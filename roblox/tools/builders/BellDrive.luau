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
    -- SNAIL (scroll) draw cam, profile in the Y-Z plane on the X cam shaft. The radius
    -- climbs from baseR to peakR over one full turn (the gradual draw as the follower
    -- rides out), then drops sharply back to baseR (the trip). Built faceted: a base
    -- circle (Cam) + a fan of thin radial "shell" planks (CamSpiralN) whose outer tips
    -- trace the spiral, + a radial drop wall (CamDrop) at the step. All named ^Cam so
    -- the controller spins them together about the cam shaft. Stylized but in-pipeline.
    local thick = 0.6 -- axial thickness (along X) — half the previous
    local baseR, peakR = d.camHubR, d.camLobeR
    local cx, cy, cz = d.cam[1], d.cam[2], d.cam[3]
    local WIND = -1 -- spiral handedness: which way the radius climbs (flip to reverse the cam)
    -- a part whose LOCAL X points radially at angle θ (from +Y, toward +Z), local Z = axle
    local function plankRot(theta: number): { number }
        local c, s = math.cos(theta), math.sin(theta)
        return { 0, 0, 1, c, -s, 0, s, c, 0 } -- columns: X=(0,c,s) Y=(0,-s,c) Z=(1,0,0)
    end
    table.insert(
        children,
        Spec.part("Cam", {
            Size = { thick, baseR * 2, baseR * 2 }, -- base circle (the dwell / min radius)
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.cam),
            Color = timber,
            Material = "Wood",
        })
    )
    local N = 144 -- fine facets → the spiral reads smooth
    local plankW = (2 * math.pi * peakR / N) + 0.3 -- chord at the rim + overlap, so facets meet
    for i = 1, N do
        local frac = i / N
        local theta = 2 * math.pi * frac * WIND
        local rI = baseR + (peakR - baseR) * frac
        local len = rI - baseR
        if len > 0.1 then
            local midR = (baseR + rI) / 2
            table.insert(
                children,
                Spec.part(`CamSpiral{i}`, {
                    Size = { len + 0.25, plankW, thick }, -- radial length × angular width × axial
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
    -- the sharp drop wall (release face): a radial plank from baseR→peakR at the step
    table.insert(
        children,
        Spec.part("CamDrop", {
            Size = { peakR - baseR, 0.7, thick },
            CFrame = Spec.cframe({ cx, cy + (baseR + peakR) / 2, cz }, plankRot(0)),
            Color = timber,
            Material = "Wood",
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
    -- Bearing yoke: an A-frame at EACH end of the drum axle. Two beams rise from the
    -- roof eaves at ~45° to meet at the axle, carrying the centred drum above the roof.
    -- Built from the drum's own centre (L.throwDrum) + the pavilion roof, so the
    -- support follows the drum. A-frames sit just OUTBOARD of the drum ends so they
    -- never cross the drum body; the drum's axle bears at the two apexes.
    local axle = L.throwDrum.pos
    local halfLen = L.throwDrum.length / 2 + 1
    local roofY = L.pavilion.pos[2] + L.pavilion.roofHeight
    local roofHalf = L.pavilion.postSpacing / 2 + 4
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
