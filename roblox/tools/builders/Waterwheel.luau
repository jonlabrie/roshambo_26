--!strict
-- Waterwheel for the canyon clearing: a timber disc whose lower paddles ride the
-- river current (undershot). Optionally OVERSHOT (waterwheel.overshot) with a headrace
-- flume (headFrom→headTo) pouring on top + a launder bleed (launderTo) — both emitted
-- only when those fields are present. centers[driver] carries the RatchetDrum the
-- runtime DriveRope (HammerController) leaves from toward the shu-moku log. Support
-- posts stand on waterwheel.bedY (the riverbed for an in-water wheel).
local Spec = require("./Spec")

local Waterwheel = {}

-- Rotation about local X (the wheel's axle) by angle a, row-major. Used to tilt
-- each float so it radiates from the hub instead of all pointing the same way.
local function rotX(a: number): { number }
    local c, s = math.cos(a), math.sin(a)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Waterwheel.build(palette: { [string]: { number } }, L: any)
    local W = L.waterwheel
    local R = W.radius
    local width = W.width or 1.2 -- axial thickness of the wheel (disc + buckets)
    local timber = palette.timber
    local rot = Spec.yaw(W.yaw) -- axle (local X of the cylinder) swung to NW-SE
    local children = {}

    for wi, c in W.centers do
        table.insert(
            children,
            Spec.part(`Wheel{wi}`, {
                Size = { width, 2 * R, 2 * R },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = timber,
                Material = "Wood",
            })
        )
        table.insert(
            children,
            Spec.part(`Axle{wi}`, {
                Size = { 4.5, 0.8, 0.8 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = palette.ink,
                Material = "Metal",
            })
        )
        -- Scoop buckets ring the rim: raked ~26° off radial so they read as Asakura
        -- scoop tubes that both catch the current (drive) and cup water to lift it.
        -- (Kept the Paddle name so WheelController spins them unchanged.)
        local RAKE = 0.45
        for i = 1, 8 do
            local a = (i - 1) * math.pi / 4
            local off = Spec.rotY({ 0, (R - 0.6) * math.cos(a), (R - 0.6) * math.sin(a) }, W.yaw)
            local prot = Spec.matMul(rot, rotX(a + RAKE))
            table.insert(
                children,
                Spec.part(`Paddle{wi}_{i}`, {
                    Size = { width + 0.2, 1.6, 0.9 }, -- buckets span the wheel width; deeper than a flat blade → a cup
                    CFrame = Spec.cframe({ c[1] + off[1], c[2] + off[2], c[3] + off[3] }, prot),
                    Color = timber,
                    Material = "WoodPlanks",
                })
            )
        end
        -- bearing posts at the axle ends, standing on the carved creek bed (W.bedY)
        -- and rising just past the axle, so they don't float over the water trench.
        local postTop = c[2] + R * 0.4
        for si, d in { -1.6, 1.6 } do
            local off = Spec.rotY({ d, 0, 0 }, W.yaw)
            table.insert(
                children,
                Spec.part(`Support{wi}_{si}`, {
                    Size = { 0.9, postTop - W.bedY, 0.9 },
                    CFrame = Spec.cframe({ c[1] + off[1], (postTop + W.bedY) / 2, c[3] + off[3] }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end

    local dc = W.centers[W.driver]
    local toward = Spec.rotY({ 0, 0, -2.4 }, W.driveYaw) -- toward the bell along the drive line
    table.insert(
        children,
        Spec.part("RatchetDrum", {
            Size = { 1.6, 1.6, 1.6 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ dc[1] + toward[1], dc[2] + toward[2], dc[3] + toward[3] }, rot),
            Color = palette.ink,
            Material = "Metal",
        })
    )

    -- OVERSHOT headrace: an open flume taps the in-fall and pours onto the wheel TOP.
    if W.overshot and W.headFrom and W.headTo then
        local hpos, hlen, hrot = Spec.segment(W.headFrom, W.headTo)
        table.insert(
            children,
            Spec.part("Headrace", {
                Size = { hlen, 0.5, 1.6 },
                CFrame = Spec.cframe(hpos, hrot),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    -- small bleed trough from the wheel top to the sōzu mouth (overshot only).
    if W.launderTo then
        local ltop = { dc[1], dc[2] + R, dc[3] }
        local lpos, llen, lrot = Spec.segment(ltop, W.launderTo)
        table.insert(
            children,
            Spec.part("Launder", {
                Size = { llen, 0.4, 0.9 },
                CFrame = Spec.cframe(lpos, lrot),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    return Spec.model("Waterwheel", children)
end

return Waterwheel
