--!strict
-- Creek dressing: river stones along the channel banks + cascade rocks. The water
-- ribbon itself is carved into terrain (tools/studio/buildTerrain.luau); this is the
-- stone garniture sampled along creek.entry -> creek.mouth. Heading + bank
-- perpendicular are derived from the line, so it follows any creek angle.
local Spec = require("./Spec")

local Creek = {}

local function ss(e0: number, e1: number, x: number): number
    local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
end

-- Mirrors tools/studio/buildTerrain.luau tierSurface: the ground height at radius
-- r, stepping up each terrace wall. The dressing rides this, NOT the straight
-- entry->mouth slope — the terrain steps down in tiers, so a linear slope left the
-- stones hanging ~10 studs over the lower terraces.
local WALL_RUN = 7 -- horizontal run of each paddy wall (keep in sync with buildTerrain)
local function tierSurface(r: number, L: any): number
    if r < L.apronRadius then
        return 2
    end
    local tiers = L.tiers
    if r < tiers[1].radius then
        return 2 + (tiers[1].height - 2) * ss(tiers[1].radius - WALL_RUN, tiers[1].radius, r)
    end
    for i = 1, #tiers - 1 do
        local a, b = tiers[i], tiers[i + 1]
        if r < b.radius then
            return a.height + (b.height - a.height) * ss(b.radius - WALL_RUN, b.radius, r)
        end
    end
    return tiers[#tiers].height
end

function Creek.build(palette: { [string]: { number } }, L: any)
    local e, m = L.creek.entry, L.creek.mouth
    local dx, dz = m[1] - e[1], m[3] - e[3]
    local flatLen = math.sqrt(dx * dx + dz * dz)
    local heading = math.deg(math.atan2(dx, dz)) -- creek facing (for Spec.yaw)
    local perpX, perpZ = -dz / flatLen, dx / flatLen -- unit perpendicular (left bank)
    local children = {}
    local N = 9
    for i = 0, N do
        local t = i / N
        local x = e[1] + dx * t
        local z = e[3] + dz * t
        local side = (i % 2 == 0) and 1 or -1
        local d = side * (L.creek.width / 2 + 0.6)
        -- bank stone rests on the LOCAL terrace surface at the stone's own radius
        local sx, sz = x + perpX * d, z + perpZ * d
        local bankSurf = tierSurface(math.sqrt(sx * sx + sz * sz), L)
        table.insert(
            children,
            Spec.part(`Stone{i}`, {
                Size = { 2 + (i % 3) * 0.6, 1.4 + (i % 2) * 0.5, 2.2 - (i % 2) * 0.4 },
                CFrame = Spec.cframe({ sx, bankSurf + 0.3, sz }, Spec.yaw(20 * i)),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
        -- a cascade rock midstream every third sample, poking through the water
        -- surface (the carved creek is brimful at the local terrace grade).
        if i % 3 == 1 then
            local waterTop = tierSurface(math.sqrt(x * x + z * z), L)
            table.insert(
                children,
                Spec.part(`Cascade{i}`, {
                    Size = { L.creek.width * 0.7, 1.0, 1.2 },
                    CFrame = Spec.cframe({ x, waterTop, z }, Spec.yaw(heading)),
                    Color = palette.gravel,
                    Material = "Rock",
                })
            )
        end
    end
    return Spec.model("Creek", children)
end

return Creek
