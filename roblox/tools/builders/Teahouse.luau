--!strict
-- Teahouse village: small enclosed huts for private conversation (≈5 standing).
-- Rings of huts on the middle terrace (6) and the top terrace (12); none on the
-- lowest. Each faces the arena centre (door + porch inward) so sightlines to the
-- World Throw stay open. Placement skips the creek channel, the koi pond, and the
-- sandō entrance gap. One enclosed hut is the ONLY place tea seating appears —
-- the open-air terrace tables/cushions were removed (see TerraceDressing.luau).
local Spec = require("./Spec")

local Teahouse = {}

local CK_DIRX, CK_DIRZ = -0.8387, -0.5446 -- creek drive line (driveYaw 237°)
local GROUND_LIFT = 2 -- terrain renders ~2 studs proud (matches TerraceDressing)

-- where a hut must NOT sit: in the sandō gap, across the creek, or in the koi pond.
local function blockedTea(x: number, z: number, a: number, L: any): boolean
    if math.abs(a - 1.5 * math.pi) < 0.32 then -- sandō/entrance gap at −Z
        return true
    end
    if math.abs(x * CK_DIRZ - z * CK_DIRX) < 11 then -- creek channel (wide margin for the hut)
        return true
    end
    local k = L.koiPond.pos
    if math.sqrt((x - k[1]) ^ 2 + (z - k[3]) ^ 2) < L.koiPond.radius + 9 then
        return true
    end
    return false
end

-- one hut, 8×8 footprint: timber back wall, a front wall split around a door,
-- shoji side panels, a flat overhanging roof + cap, a porch and noren toward the
-- centre, and a low central table. Built in a local frame (door faces local +Z),
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
    local kids = {}
    local function place(lx: number, ly: number, lz: number): { number }
        local o = Spec.rotY({ lx, 0, lz }, deg)
        return Spec.cframe({ cx + o[1], gy + ly, cz + o[3] }, Spec.yaw(deg))
    end
    local function part(pn, size, lx, ly, lz, color, mat, extra)
        local props: { [string]: any } =
            { Size = size, CFrame = place(lx, ly, lz), Color = color, Material = mat }
        if extra then
            for k, v in extra do
                props[k] = v
            end
        end
        table.insert(kids, Spec.part(pn, props))
    end
    part("Floor", { 8, 0.4, 8 }, 0, 0.2, 0, palette.gravel, "Slate")
    part("BackWall", { 8, 6, 0.4 }, 0, 3.2, -4, timber, "Wood")
    part("ShojiL", { 0.4, 6, 8 }, -4, 3.2, 0, ivory, "SmoothPlastic", { Transparency = 0.45 })
    part("ShojiR", { 0.4, 6, 8 }, 4, 3.2, 0, ivory, "SmoothPlastic", { Transparency = 0.45 })
    part("FrontL", { 2.5, 6, 0.4 }, -2.75, 3.2, 4, timber, "Wood")
    part("FrontR", { 2.5, 6, 0.4 }, 2.75, 3.2, 4, timber, "Wood")
    part("Roof", { 9.8, 0.6, 9.8 }, 0, 6.5, 0, ink, "Slate")
    part("Cap", { 4.5, 1.4, 4.5 }, 0, 7.4, 0, ink, "Slate")
    part("Porch", { 4, 0.4, 2.6 }, 0, 0.2, 5.3, timber, "WoodPlanks")
    part("Noren", { 3, 2, 0.15 }, 0, 4.6, 4, ink, "Fabric", { CanCollide = false })
    part("Table", { 2.4, 1.5, 2.4 }, 0, 0.95, 0, timber, "Wood")
    return Spec.model(name, kids)
end

function Teahouse.build(palette: { [string]: { number } }, L: any)
    local children = {}
    -- ring radii sit on the OUTER part of each terrace's flat plateau, clear of the
    -- inner lantern ring; the top terrace was widened (r188→~210) to seat 12.
    local rings = {
        { ti = 2, count = 6, r = 174 },
        { ti = 3, count = 12, r = 202 },
    }
    for _, ring in rings do
        local gy = L.tiers[ring.ti].height + GROUND_LIFT
        -- collect valid angles around the ring, then pick `count` spread evenly
        -- through them so the huts dodge the creek/koi/gap yet stay roughly regular.
        local valid = {}
        local STEPS = 96
        for s = 0, STEPS - 1 do
            local a = s / STEPS * 2 * math.pi
            local x, z = ring.r * math.cos(a), ring.r * math.sin(a)
            if not blockedTea(x, z, a, L) then
                table.insert(valid, a)
            end
        end
        for k = 0, ring.count - 1 do
            local a = valid[math.floor(k * #valid / ring.count) + 1]
            local x, z = ring.r * math.cos(a), ring.r * math.sin(a)
            local deg = math.deg(math.atan2(-x, -z)) -- yaw so the door/porch face the centre
            table.insert(children, hut(palette, `Teahouse_{ring.ti}_{k + 1}`, x, z, gy, deg))
        end
    end
    return Spec.model("Teahouses", children)
end

return Teahouse
