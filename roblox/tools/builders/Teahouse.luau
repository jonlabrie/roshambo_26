--!strict
-- Teahouse village: enclosed huts for private conversation (≈5 standing). Rings on
-- all three terraces (none on the lowest shrine level): 7 on tier 1, 9 on tier 2,
-- 15 on the widened tier 3. Each is rectangular with its LONG side (the door wall)
-- facing the arena centre, so sightlines to the World Throw stay open. Positions
-- carry a little deterministic jitter (forward/back + closer/nearer) and no hut is
-- stacked directly above/below one on an adjacent tier. Placement skips the creek,
-- koi pond, promontory pads, and the sandō entrance gap. These enclosed huts are
-- the ONLY tea seating — the open-air terrace seating was removed (TerraceDressing).
local Spec = require("./Spec")

local Teahouse = {}

local CK_DIRX, CK_DIRZ = -0.8387, -0.5446 -- creek drive line (driveYaw 237°)
local GROUND_LIFT = 2 -- terrain renders ~2 studs proud (matches TerraceDressing)
local W, D, WALL = 16, 8, 9 -- footprint width (faces centre) × depth, wall height

-- rotations about local X / Z (row-major), for tilting the roof planes before yaw.
local function rotX(t: number): { number }
    local c, s = math.cos(t), math.sin(t)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotZ(t: number): { number }
    local c, s = math.cos(t), math.sin(t)
    return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

-- deterministic pseudo-random in [0,1): keeps genmodels output stable (no math.random,
-- which would fail the CI drift check) while giving each hut a repeatable wobble.
local function rand(seed: number): number
    local v = math.sin(seed * 12.9898) * 43758.5453
    return v - math.floor(v)
end

local function blockedTea(x: number, z: number, a: number, L: any): boolean
    if math.abs(a - 1.5 * math.pi) < 0.3 then -- sandō/entrance gap at −Z
        return true
    end
    if math.abs(x * CK_DIRZ - z * CK_DIRX) < 12 then -- creek channel
        return true
    end
    local k = L.koiPond.pos
    if math.sqrt((x - k[1]) ^ 2 + (z - k[3]) ^ 2) < L.koiPond.radius + 10 then
        return true
    end
    for _, p in L.promontories do -- champion pedestals on tier 1
        if math.sqrt((x - p.pos[1]) ^ 2 + (z - p.pos[3]) ^ 2) < 14 then
            return true
        end
    end
    return false
end

-- one hut, W×D footprint, WALL tall: timber posts + back wall, shoji sides, a front
-- wall split around a door with a noren, porch toward the centre, and a deep-eaved
-- GABLED roof (ridge along the long X axis, so the wide front presents a low
-- overhanging eave over the door). Built in a local frame (door faces local +Z),
-- then yawed to `deg` and dropped at (cx, gy, cz).
local function hut(
    palette: { [string]: { number } },
    name: string,
    cx: number,
    cz: number,
    gy: number,
    deg: number
)
    local timber, ink, ivory = palette.timber, palette.ink, palette.ivory
    local hw, hd, wy = W / 2, D / 2, 0.4 + WALL / 2
    local kids = {}
    local yawM = Spec.yaw(deg)
    local function place(lx: number, ly: number, lz: number, lrot: { number }?): { number }
        local o = Spec.rotY({ lx, 0, lz }, deg)
        local rot = if lrot then Spec.matMul(yawM, lrot) else yawM
        return Spec.cframe({ cx + o[1], gy + ly, cz + o[3] }, rot)
    end
    local function part(pn, size, lx, ly, lz, color, mat, lrot, extra)
        local props: { [string]: any } =
            { Size = size, CFrame = place(lx, ly, lz, lrot), Color = color, Material = mat }
        if extra then
            for k, v in extra do
                props[k] = v
            end
        end
        table.insert(kids, Spec.part(pn, props))
    end
    part("Floor", { W, 0.4, D }, 0, 0.2, 0, palette.gravel, "Slate")
    part("BackWall", { W, WALL, 0.4 }, 0, wy, -hd, timber, "Wood")
    part("ShojiL", { 0.4, WALL, D }, -hw, wy, 0, ivory, "SmoothPlastic", nil, { Transparency = 0.45 })
    part("ShojiR", { 0.4, WALL, D }, hw, wy, 0, ivory, "SmoothPlastic", nil, { Transparency = 0.45 })
    part("FrontL", { hw - 2, WALL, 0.4 }, -(hw + 2) / 2, wy, hd, timber, "Wood")
    part("FrontR", { hw - 2, WALL, 0.4 }, (hw + 2) / 2, wy, hd, timber, "Wood")
    -- corner posts carry the deep eaves (the engawa-frame look from the reference)
    for i, sx in { -1, 1 } do
        for j, sz in { -1, 1 } do
            part(
                `Post{i}{j}`,
                { 0.6, WALL + 0.6, 0.6 },
                sx * hw,
                (0.4 + WALL + 0.6) / 2,
                sz * hd,
                timber,
                "Wood"
            )
        end
    end
    -- ── roof: upper gable + closed gable ends + a lower eave skirt (irimoya read) ──
    local function wedge(pn, size, lx, ly, lz, lrot, color, mat)
        table.insert(kids, {
            name = pn,
            className = "WedgePart",
            properties = {
                Anchored = true,
                Size = size,
                CFrame = place(lx, ly, lz, lrot),
                Color = color,
                Material = mat,
            },
        })
    end
    local TY = 0.4 + WALL -- wall top
    local ovX, ovZ = 1.5, 2.5 -- overhang past the walls: gable-end (length) / eave (width)
    local EY, RY = TY + 0.3, TY + 4.5 -- eave height, ridge height
    local ZE = hd + ovZ -- front/back eave reach (z)
    local theta = math.atan2(RY - EY, ZE)
    local SL = math.sqrt(ZE * ZE + (RY - EY) ^ 2) -- slope length
    part("RoofFront", { W + 2 * ovX, 0.5, SL }, 0, (RY + EY) / 2, ZE / 2, ink, "Slate", rotX(theta))
    part("RoofBack", { W + 2 * ovX, 0.5, SL }, 0, (RY + EY) / 2, -ZE / 2, ink, "Slate", rotX(-theta))
    part("Ridge", { W + 1, 0.7, 1.2 }, 0, RY, 0, ink, "Slate")
    -- gable infill. The opening is only as wide as the wall (between the corner
    -- posts), so a triangle from the wall top to the ridge would be STEEPER than the
    -- shallow roof and leave a gap. Instead the plaster triangle spans only from
    -- where the roof underside meets the wall edge (gBaseY) up to the ridge — so its
    -- slope equals the roof's — and a short rectangular band fills below it.
    -- WedgePart is full-height at +Z, so the +z half is flipped to peak at centre.
    local FLIP = { -1, 0, 0, 0, 1, 0, 0, 0, -1 }
    local gBaseY = RY - (RY - EY) * hd / ZE -- roof underside height at the wall edge
    local GH = RY - gBaseY -- triangle height → slope (RY-EY)/ZE matches the roof
    for gi, sx in { -hw, hw } do
        part(`GableBand{gi}`, { 0.4, gBaseY - TY, 2 * hd }, sx, (TY + gBaseY) / 2, 0, ivory, "Plaster")
        wedge(`GableA{gi}`, { 0.4, GH, hd }, sx, gBaseY + GH / 2, hd / 2, FLIP, ivory, "Plaster")
        wedge(`GableB{gi}`, { 0.4, GH, hd }, sx, gBaseY + GH / 2, -hd / 2, nil, ivory, "Plaster")
    end
    -- lower eave skirt: a true hipped band. Each side is a TRAPEZOID (short base =
    -- the wall it sits on, long base = the wider eave) = a central rect plus two
    -- coplanar triangular wedge ends whose 45° hypotenuses are the hip lines, so
    -- adjacent panels meet cleanly at the corners with no overlap. Front/back use
    -- width W, the sides use D; each panel is the same shape turned by 0/90/180/270.
    local sOv, sDr = 4, 2 -- skirt overhang, drop
    local sT = math.atan2(sDr, sOv)
    local sSL = math.sqrt(sOv * sOv + sDr * sDr)
    local syc = TY - sDr / 2
    local function trapPanel(wid: number, dIn: number, pYaw: number, tag: string)
        local eyM = Spec.yaw(deg + pYaw) -- this panel's frame = hut yaw + panel turn
        local function placeE(lx, ly, lz, lrot)
            local o = Spec.rotY({ lx, 0, lz }, deg + pYaw)
            return Spec.cframe({ cx + o[1], gy + ly, cz + o[3] }, Spec.matMul(eyM, lrot))
        end
        table.insert(
            kids,
            Spec.part(`Skirt{tag}`, {
                Size = { wid, 0.35, sSL },
                CFrame = placeE(0, syc, dIn + sOv / 2, rotX(sT)),
                Color = ink,
                Material = "Slate",
            })
        )
        for _, e in { { wid / 2 + sOv / 2, -math.pi / 2, "R" }, { -(wid / 2 + sOv / 2), math.pi / 2, "L" } } do
            table.insert(kids, {
                name = `Skirt{tag}{e[3]}`,
                className = "WedgePart",
                properties = {
                    Anchored = true,
                    Size = { 0.35, sOv, sSL },
                    CFrame = placeE(e[1], syc, dIn + sOv / 2, Spec.matMul(rotX(sT), rotZ(e[2]))),
                    Color = ink,
                    Material = "Slate",
                },
            })
        end
    end
    trapPanel(W, hd, 0, "F")
    trapPanel(W, hd, 180, "B")
    trapPanel(D, hw, 270, "R")
    trapPanel(D, hw, 90, "L")
    part("Porch", { 7, 0.4, 3 }, 0, 0.2, hd + 1.5, timber, "WoodPlanks")
    part("Noren", { 4, 3, 0.15 }, 0, WALL - 2, hd, ink, "Fabric", nil, { CanCollide = false })
    part("Table", { 3.5, 1.8, 3.5 }, 0, 1.1, 0, timber, "Wood")
    return Spec.model(name, kids)
end

function Teahouse.build(palette: { [string]: { number } }, L: any)
    local children = {}
    -- ring radii sit on the OUTER part of each terrace plateau, clear of the inner
    -- lantern ring; the top terrace was widened (r188→~210) to seat 15.
    -- pushed ~10 studs toward the centre from the rear edge (lanterns took the rear).
    local rings = {
        { ti = 1, count = 7, r = 129, phase = 0.0 },
        { ti = 2, count = 9, r = 164, phase = 0.21 },
        { ti = 3, count = 15, r = 192, phase = 0.13 },
    }
    local placed = {} -- {ti, a} of every hut, to keep adjacent tiers from stacking
    local function stacked(a: number, ti: number): boolean
        for _, h in placed do
            if math.abs(h.ti - ti) == 1 then
                local d = math.abs((a - h.a + math.pi) % (2 * math.pi) - math.pi)
                if d < 0.13 then -- within ~7.5° of a hut one tier away → directly above/below
                    return true
                end
            end
        end
        return false
    end
    for _, ring in rings do
        local gy = L.tiers[ring.ti].height + GROUND_LIFT
        local step = 2 * math.pi / ring.count
        for k = 0, ring.count - 1 do
            local seed = ring.ti * 97 + k
            local a = ring.phase + k * step + (rand(seed) - 0.5) * 0.12 -- closer/nearer jitter
            local r = ring.r + (rand(seed + 0.5) - 0.5) * 5 -- forward/back jitter
            -- nudge around the ring out of the creek/koi/pad/gap and off any stack
            local tries = 0
            while
                (blockedTea(r * math.cos(a), r * math.sin(a), a, L) or stacked(a, ring.ti)) and tries < 60
            do
                a += 0.045
                tries += 1
            end
            local x, z = r * math.cos(a), r * math.sin(a)
            local deg = math.deg(math.atan2(-x, -z)) -- yaw so the long door wall faces the centre
            table.insert(children, hut(palette, `Teahouse_{ring.ti}_{k + 1}`, x, z, gy, deg))
            table.insert(placed, { ti = ring.ti, a = a })
        end
    end
    return Spec.model("Teahouses", children)
end

return Teahouse
