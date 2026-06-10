--!strict
-- One slightly-cambered timber footbridge spanning world points a -> b. A helper
-- (returns a flat list of PartSpecs to embed in a caller's model), not a genmodels
-- output. Deck rises a little at its midpoint; low side rails; an abutment post at
-- each end. tag namespaces the part names so a model can hold several bridges.
local Spec = require("./Spec")

local Bridge = {}

function Bridge.arch(
    palette: { [string]: { number } },
    a: { number },
    b: { number },
    width: number,
    tag: string
): { Spec.PartSpec }
    local timber = palette.timber
    local mid = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 + 0.9, (a[3] + b[3]) / 2 } -- camber up 0.9
    local parts: { Spec.PartSpec } = {}

    -- deck in two cambered segments a->mid, mid->b
    for i, seg in { { a, mid, "A" }, { mid, b, "B" } } do
        local p, len, rot = Spec.segment(seg[1], seg[2])
        table.insert(
            parts,
            Spec.part(`Deck{tag}{if i == 1 then "" else "2"}`, {
                Size = { len, 0.3, width },
                CFrame = Spec.cframe(p, rot),
                Color = timber,
                Material = "WoodPlanks",
            })
        )
    end
    parts[1].name = `Deck{tag}`

    -- side rails along the full span (flat, low)
    local dx, dz = b[1] - a[1], b[3] - a[3]
    local flat = math.sqrt(dx * dx + dz * dz)
    local px, pz = -dz / flat, dx / flat -- perpendicular unit
    for _, e in { { width / 2, "L" }, { -width / 2, "R" } } do
        local ra = { a[1] + px * e[1], a[2] + 1.0, a[3] + pz * e[1] }
        local rb = { b[1] + px * e[1], b[2] + 1.0, b[3] + pz * e[1] }
        local p, len, rot = Spec.segment(ra, rb)
        table.insert(
            parts,
            Spec.part(`Rail{tag}{e[2]}`, {
                Size = { len, 0.8, 0.25 },
                CFrame = Spec.cframe(p, rot),
                Color = timber,
                Material = "Wood",
            })
        )
    end

    -- abutment posts at each end, dropping 4 studs to the bank/bed
    for _, e in { { a, "A" }, { b, "B" } } do
        table.insert(
            parts,
            Spec.part(`Post{tag}{e[2]}`, {
                Size = { 0.6, 4, 0.6 },
                CFrame = Spec.cframe({ e[1][1], e[1][2] - 2, e[1][3] }),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    return parts
end

return Bridge
