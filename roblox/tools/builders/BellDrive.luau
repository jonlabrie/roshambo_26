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
    -- gear-down: discs in the X-Y plane (axle along Z), centres a pitch-radius apart
    for _, g in { { "DriverGear", d.driverGear, d.driverR }, { "CamGear", d.camGear, d.camR } } do
        table.insert(
            children,
            Spec.part(g[1] :: string, {
                Size = { 0.8, (g[3] :: number) * 2, (g[3] :: number) * 2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(g[2], Spec.ROT.CYL_ALONG_Z),
                Color = timber,
                Material = "WoodPlanks",
            })
        )
    end
    -- cam shaft + cam (the wiper that draws the shu-moku tail)
    local cp, clen, crot = Spec.segment(d.camShaftFrom, d.camShaftTo)
    table.insert(
        children,
        Spec.part("CamShaft", {
            Size = { clen, 0.7, 0.7 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(cp, crot),
            Color = iron,
            Material = "Metal",
        })
    )
    table.insert(
        children,
        Spec.part("Cam", {
            Size = { 1.2, d.camLobe, d.camLobe },
            CFrame = Spec.cframe(d.cam, Spec.ROT.CYL_ALONG_Z),
            Color = timber,
            Material = "Wood",
        })
    )
    -- vertical drum shaft + the paddle the dowel kicks
    local vp, vlen = Spec.segment(d.vertBase, d.vertTop)
    table.insert(
        children,
        Spec.part("VertShaft", {
            Size = { d.vertR * 2, vlen, d.vertR * 2 },
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
    -- two yoke arms straddling the drum axle, above the roof
    for i, dx in { -d.yokeSpan / 2, d.yokeSpan / 2 } do
        table.insert(
            children,
            Spec.part(`DrumYoke{i}`, {
                Size = { 0.8, 5, 0.8 },
                CFrame = Spec.cframe({ d.yoke[1] + dx, d.yoke[2] + 2.5, d.yoke[3] }),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    return Spec.model("BellDrive", children)
end

return BellDrive
