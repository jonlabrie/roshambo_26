--!strict
-- Creek dressing: river stones along the channel banks + cascade rocks. The water
-- ribbon itself is carved into terrain (tools/studio/buildTerrain.luau); this is the
-- stone garniture sampled along creek.entry -> creek.mouth. Heading + bank
-- perpendicular are derived from the line, so it follows any creek angle.
local Spec = require("./Spec")

local Creek = {}

function Creek.build(palette: { [string]: { number } }, L: any)
    local e, m = L.creek.entry, L.creek.mouth
    local dx, dy, dz = m[1] - e[1], m[2] - e[2], m[3] - e[3]
    local flatLen = math.sqrt(dx * dx + dz * dz)
    local heading = math.deg(math.atan2(dx, dz)) -- creek facing (for Spec.yaw)
    local perpX, perpZ = -dz / flatLen, dx / flatLen -- unit perpendicular (left bank)
    local children = {}
    local N = 9
    for i = 0, N do
        local t = i / N
        local x = e[1] + dx * t
        local y = e[2] + dy * t
        local z = e[3] + dz * t
        local side = (i % 2 == 0) and 1 or -1
        local d = side * (L.creek.width / 2 + 0.6)
        table.insert(
            children,
            Spec.part(`Stone{i}`, {
                Size = { 2 + (i % 3) * 0.6, 1.4 + (i % 2) * 0.5, 2.2 - (i % 2) * 0.4 },
                CFrame = Spec.cframe({ x + perpX * d, y + 0.3, z + perpZ * d }, Spec.yaw(20 * i)),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
        -- a cascade rock midstream every third sample (a step-down)
        if i % 3 == 1 then
            table.insert(
                children,
                Spec.part(`Cascade{i}`, {
                    Size = { L.creek.width * 0.7, 1.0, 1.2 },
                    CFrame = Spec.cframe({ x, y - 0.2, z }, Spec.yaw(heading)),
                    Color = palette.gravel,
                    Material = "Rock",
                })
            )
        end
    end
    return Spec.model("Creek", children)
end

return Creek
