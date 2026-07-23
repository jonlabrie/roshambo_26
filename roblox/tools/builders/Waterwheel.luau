--!strict
-- Waterwheel for the canyon clearing: a photo-referenced timber undershot mill wheel.
-- Construction (per the user's references): one ROUND bent-lamination hoop per face
-- (40 chord segments — reads as a true circle), heavy radial spokes landing exactly on
-- chord joints, paddle boards and tread "steps" TUCKED BETWEEN the hoops (never cutting
-- across a face), and every board/spoke fastened by visible through-DOWELS whose ends
-- protrude from the hoop faces. `Wheel{n}` itself is an INVISIBLE full-diameter proxy —
-- WheelController's spin anchor and spray-attachment host — while the visible timbers
-- are `Wheel{n}T_*` parts the controller captures by prefix and spins as one assembly.
-- Optionally OVERSHOT (waterwheel.overshot) with a headrace flume — unchanged from the
-- disc era. centers[driver] carries the RatchetDrum the runtime DriveRope
-- (HammerController) leaves from toward the shu-moku log. Support posts stand on
-- waterwheel.bedY (the riverbed).
local Spec = require("./Spec")

local Waterwheel = {}

-- Lattice vocabulary. RIM_SEGS is divisible by SPOKES and by (PADDLES+STEPS), so every
-- spoke, paddle, and step lands exactly on a chord joint (no mid-board intersections).
Waterwheel.RIM_SEGS = 40 -- hoop chords per face: fine enough to read round
Waterwheel.SPOKES = 8 -- radial spokes per face, every 5th joint
Waterwheel.PADDLES = 20 -- paddle boards, every 2nd joint
Waterwheel.STEPS = 10 -- tread boards on the odd joints midway between paddles
Waterwheel.RIM_INSET = 0.8 -- hoop outer edge sits this far inside W.radius (paddle tips just clear it)

-- Rotation about local X (the wheel's axle) by angle a, row-major. The disc lives in
-- the local Y-Z plane: local Y maps to the radial direction at angle a, local Z to
-- the tangent — so a box sized (axial, radial, tangential) lands cleanly on a station.
local function rotX(a: number): { number }
    local c, s = math.cos(a), math.sin(a)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Waterwheel.build(palette: { [string]: { number } }, L: any)
    local W = L.waterwheel
    local R = W.radius
    local width = W.width or 1.2 -- axial span of the wheel (hoop outer face to outer face)
    local timber = palette.timber
    local cypress = palette.cypressWeathered -- the whole wheel reads as the monument's aged hinoki
    local pegWood = { cypress[1] * 0.82, cypress[2] * 0.82, cypress[3] * 0.82 } -- dowel ends read darker
    local rot = Spec.yaw(W.yaw) -- axle (local X) swung onto the layout's drive line
    local children = {}

    local SEGS = Waterwheel.RIM_SEGS
    local STEP = 2 * math.pi / SEGS

    -- hoop cross-section and radial stations; the hoop outer edge sits RIM_INSET inside
    -- W.radius, and the paddle tips clear it by only an inch or two (per the reference)
    local HOOP_T = 0.3 -- axial thickness of each hoop lamination
    local HOOP_D = 0.9 -- radial depth of the lamination
    local HOOP_R = R - Waterwheel.RIM_INSET -- hoop vertex (outer-edge) radius

    for wi, c in W.centers do
        -- world-space placement of a lattice box at (axial, radius, angle) + extras
        local function station(
            name: string,
            axialX: number,
            r: number,
            theta: number,
            size: { number },
            extra: { [string]: any }?
        )
            local off = Spec.rotY({ axialX, r * math.cos(theta), r * math.sin(theta) }, W.yaw)
            local props: { [string]: any } = {
                Size = size,
                CFrame = Spec.cframe(
                    { c[1] + off[1], c[2] + off[2], c[3] + off[3] },
                    Spec.matMul(rot, rotX(theta))
                ),
                Color = cypress,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            }
            if extra then
                for k, v in extra do
                    props[k] = v
                end
            end
            table.insert(children, Spec.part(name, props))
        end

        -- Invisible full-diameter proxy: the controller's spin anchor + spray host, and
        -- the stable Wheel{n} contract name. Visible timbers ride it by prefix capture.
        table.insert(
            children,
            Spec.part(`Wheel{wi}`, {
                Size = { width, 2 * R, 2 * R },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = timber,
                Material = "Wood",
                Transparency = 1,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
            })
        )

        local FACE = width / 2 - HOOP_T / 2 -- hoop centre planes (outer faces at ±width/2)
        local INNER = FACE - HOOP_T / 2 -- hoop inner faces: boards tuck between these
        local pegN = 0
        -- a through-dowel at disc-plane point (py,pz) piercing the hoop on face f into the
        -- board behind it (axial cylinder; its ends protrude past the hoop outer face)
        local function peg(py: number, pz: number, f: number)
            pegN += 1
            local off = Spec.rotY({ f * FACE + f * 0.075, py, pz }, W.yaw)
            table.insert(
                children,
                Spec.part(`Wheel{wi}T_PG{pegN}`, {
                    Size = { 0.75, 0.18, 0.18 },
                    Shape = "Cylinder",
                    CFrame = Spec.cframe({ c[1] + off[1], c[2] + off[2], c[3] + off[3] }, rot),
                    Color = pegWood,
                    Material = "Wood",
                    MaterialVariant = "CypressWeathered",
                })
            )
        end

        -- round hoops, one per face: chord joints at every multiple of STEP
        for fi, f in { -1, 1 } do
            for i = 1, SEGS do
                local mid = (i - 0.5) * STEP
                local chord = 2 * HOOP_R * math.sin(math.pi / SEGS) + 0.08
                station(
                    `Wheel{wi}T_HP{fi}_{i}`,
                    f * FACE,
                    HOOP_R * math.cos(math.pi / SEGS) - HOOP_D / 2,
                    mid,
                    { HOOP_T, HOOP_D, chord }
                )
            end
        end
        -- radial spokes: every 5th joint, tucked against the hoop inner faces, pegged there
        local SPOKE_T = 0.3
        for fi, f in { -1, 1 } do
            for s = 1, Waterwheel.SPOKES do
                local a = (s - 1) * (SEGS / Waterwheel.SPOKES) * STEP
                local r0, r1 = 1.2, HOOP_R - HOOP_D - 0.05
                station(
                    `Wheel{wi}T_SP{fi}_{s}`,
                    f * (INNER - SPOKE_T / 2),
                    (r0 + r1) / 2,
                    a,
                    { SPOKE_T, r1 - r0, 0.85 }
                )
                peg((r1 - 0.35) * math.cos(a), (r1 - 0.35) * math.sin(a), f)
            end
            -- reinforcing ring: an octagon of lighter timbers chorded spoke-to-spoke
            -- (vertices ON the spoke centerlines, ends tucked into the spoke width)
            local RING_R = 4.8
            for s = 1, Waterwheel.SPOKES do
                local a0 = (s - 1) * (SEGS / Waterwheel.SPOKES) * STEP
                local half = math.pi / Waterwheel.SPOKES
                local chord = 2 * RING_R * math.sin(half) + 0.35
                station(
                    `Wheel{wi}T_RR{fi}_{s}`,
                    f * (INNER - SPOKE_T / 2),
                    RING_R * math.cos(half) - 0.275,
                    a0 + half,
                    { SPOKE_T, 0.55, chord }
                )
            end
        end
        -- paddle boards: every 2nd joint, tucked between the hoops, RAKED well off the
        -- radial (the reference's water-catching tilt) by pivoting about the board root at
        -- the hoop's inner edge; the tip clears the hoop outer edge by only ~an inch or two.
        -- Two through-dowels per side pin the root where it crosses the hoop lamination.
        local RAKE = 0.42
        local boardAxial = 2 * INNER - 0.05
        local r0 = HOOP_R - HOOP_D - 0.2 -- board root radius (just inside the hoop)
        local rTip = HOOP_R + 0.15 -- tip barely proud of the rim
        -- board length from the root/rake geometry: |root + Lu|² = rTip²
        local halfB = r0 * math.cos(RAKE)
        local LEN = math.sqrt(halfB * halfB + rTip * rTip - r0 * r0) - halfB
        for i = 1, Waterwheel.PADDLES do
            local a = (i - 1) * (SEGS / Waterwheel.PADDLES) * STEP
            local uy, uz = math.cos(a + RAKE), math.sin(a + RAKE) -- board long axis, raked
            local ry, rz = r0 * math.cos(a), r0 * math.sin(a) -- root point on the disc plane
            local cy, cz = ry + (LEN / 2) * uy, rz + (LEN / 2) * uz
            local off = Spec.rotY({ 0, cy, cz }, W.yaw)
            table.insert(
                children,
                Spec.part(`Paddle{wi}_{i}`, {
                    Size = { boardAxial, LEN, 0.22 },
                    CFrame = Spec.cframe(
                        { c[1] + off[1], c[2] + off[2], c[3] + off[3] },
                        Spec.matMul(rot, rotX(a + RAKE))
                    ),
                    Color = palette.paddleWet,
                    Material = "Wood",
                    MaterialVariant = "MossyPaddle",
                })
            )
            for _, f in { -1, 1 } do
                peg(ry + 0.45 * uy, rz + 0.45 * uz, f)
                peg(ry + 1.0 * uy, rz + 1.0 * uz, f)
            end
        end
        -- tread "steps" on the odd joints midway between paddles, one dowel per side
        for i = 1, Waterwheel.STEPS do
            local a = ((i - 1) * (SEGS / Waterwheel.STEPS) + 1) * STEP
            local r = HOOP_R - HOOP_D / 2
            station(`Wheel{wi}T_ST{i}`, 0, r, a, { boardAxial, 0.22, 1.0 })
            peg(r * math.cos(a), r * math.sin(a), -1)
            peg(r * math.cos(a), r * math.sin(a), 1)
        end
        -- hub boss the spokes radiate from (kept slim axially so the turning octagonal
        -- shaft shows between the hub and each bearing)
        station(`Wheel{wi}T_HUB{1}`, 0, 0, 0, { 2 * INNER - 0.6, 3.2, 3.2 }, { Shape = "Cylinder" })

        -- squat mossy-concrete piers (no concrete MaterialVariant exists in the place
        -- yet) topping out just above the bearing, each carrying an IronDark BEARING
        -- ring the main shaft turns in; the shaft runs through both bearings with a
        -- stub proud of each. Pier offset DERIVES from width so widening the wheel
        -- can't pinch them again.
        local POST_W = 1.35
        local postOut = width / 2 + POST_W / 2 + 0.2 -- hoop outer face + pier half + clearance
        -- pier top sits right beneath the bearing's base PLATE: bearing bottom (shaft
        -- height − OD/2) minus the plate thickness
        local PLATE_T = 0.2
        local postTop = c[2] - 1.55 / 2 - PLATE_T
        local axleLen = 2 * (postOut + POST_W / 2 + 0.65) -- through both bearings, a real stub proud of each
        -- Axle{n} is now an INVISIBLE static proxy: the controller reads the axle
        -- direction off it and hangs the (fixed) water-VFX attachments on it. The
        -- VISIBLE shaft is the octagonal cypress prism below, which spins.
        table.insert(
            children,
            Spec.part(`Axle{wi}`, {
                Size = { axleLen, 0.8, 0.8 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = palette.ink,
                Material = "Metal",
                Transparency = 1,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
            })
        )
        -- the turning shaft: a TRUE octagonal cypress prism from 4 boxes 45° apart
        -- (each supplies two opposite flats), faces aligned with the 8 spokes so the
        -- rotation reads plainly. Captured into the spin set by the T_ prefix.
        local SHAFT_F = 1.0 -- across-flats (still clears the 1.3 bearing bore at the corners)
        local SHAFT_A = 0.42 -- flat width (F·tan 22.5°)
        for k = 1, 4 do
            station(`Wheel{wi}T_SH{k}`, 0, 0, (k - 1) * math.pi / 4, { axleLen, SHAFT_F, SHAFT_A })
        end
        for si, d in { -postOut, postOut } do
            local off = Spec.rotY({ d, 0, 0 }, W.yaw)
            table.insert(
                children,
                Spec.part(`Support{wi}_{si}`, {
                    Size = { POST_W, postTop - W.bedY, POST_W },
                    CFrame = Spec.cframe({ c[1] + off[1], (postTop + W.bedY) / 2, c[3] + off[3] }),
                    Color = { 0.52, 0.56, 0.47 },
                    Material = "Concrete",
                })
            )
            -- pillow block: a static IronDark BEARING ring (circular in/out) enclosing a
            -- SPINNING iron collar on the shaft. The collar (octagonal bore in spirit —
            -- it turns with the octagon) is slightly WIDER than the bearing, so its rims
            -- stick out a touch on either side. Bearing underside sinks into the pier top.
            table.insert(
                children,
                Spec.part(`Bearing{wi}_{si}`, {
                    Size = { 0.5, 1.55, 1.55 },
                    Shape = "Cylinder",
                    CFrame = Spec.cframe({ c[1] + off[1], c[2], c[3] + off[3] }, rot),
                    Color = palette.ink,
                    Material = "Metal",
                    MaterialVariant = "IronDark",
                })
            )
            station(`Wheel{wi}T_CL{si}`, d, 0, 0, { 0.72, 1.24, 1.24 }, {
                Shape = "Cylinder",
                Color = palette.ink,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
            -- square base plate "welded" under the bearing, spanning the pier top
            table.insert(
                children,
                Spec.part(`BearingPlate{wi}_{si}`, {
                    Size = { POST_W, PLATE_T, POST_W },
                    CFrame = Spec.cframe({ c[1] + off[1], postTop + PLATE_T / 2, c[3] + off[3] }),
                    Color = palette.ink,
                    Material = "Metal",
                    MaterialVariant = "IronDark",
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
            MaterialVariant = "IronDark",
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
