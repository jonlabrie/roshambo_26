--!strict
-- Framed VIEWED karesansui garden (spec 2026-07-24): dressed-slate kerb, raked-sand
-- field slab, and a low invisible EngawaBarrier guard, per surveyed panel. Boulder
-- islands are PLACE-ONLY (tagged KaresansuiIsland); ripple rings are client-built
-- (RakingMesh) — this builder emits only the frame and field.
local Spec = require("./Spec")

local Karesansui = {}

function Karesansui.build(palette: any, L: any): Spec.PartSpec
    local K = L.karesansui
    local children: { Spec.PartSpec } = {}

    local function panel(name: string, r: { number }, floorY: number)
        local kerbTopY = floorY + K.kerbProud
        local slabTopY = floorY + K.slabProud
        local x1, z1, x2, z2 = r[1], r[2], r[3], r[4]
        local w = K.kerbW
        -- kerb: N/S beams span the full width; E/W beams inset between them (mitre-read)
        local beams = {
            N = { (x1 + x2) / 2, z1 + w / 2, x2 - x1, w },
            S = { (x1 + x2) / 2, z2 - w / 2, x2 - x1, w },
            W = { x1 + w / 2, (z1 + z2) / 2, w, z2 - z1 - 2 * w },
            E = { x2 - w / 2, (z1 + z2) / 2, w, z2 - z1 - 2 * w },
        }
        -- CYPRESS, MATCHING THE POSTS IT NOW RUNS BETWEEN (owner's gate 2026-08-14). Dressed slate
        -- was right while this was a garden the tower stood in; now the kerb is the tower's own
        -- edging and belongs to the same timber.
        --
        -- THE VARIANT IS PER SIDE, BECAUSE THE GRAIN IS IN WORLD SPACE. These maps are projected
        -- from world axes, not from each part's UVs — CypressWeathered runs the grain one way and
        -- CypressVertical is the SAME maps rotated 90°. So a single variant across all four beams
        -- would run the grain along two of them and across the other two. N/S beams are long in X
        -- and take the unrotated maps; W/E beams are long in Z and take the rotated ones. The
        -- variant's NAME says "vertical" because that is what it was cut for; what it actually
        -- means is "turned a quarter", which is what a beam running the other way needs.
        local grain =
            { N = "CypressWeathered", S = "CypressWeathered", W = "CypressVertical", E = "CypressVertical" }
        for side, b in beams do
            table.insert(
                children,
                Spec.part(`Kerb{name}{side}`, {
                    Size = { b[3], K.kerbH, b[4] },
                    CFrame = Spec.cframe({ b[1], kerbTopY - K.kerbH / 2, b[2] }),
                    Color = palette.cypressWeathered,
                    Material = "Wood",
                    MaterialVariant = grain[side],
                })
            )
            table.insert(
                children,
                Spec.part(`Guard{name}{side}`, {
                    Size = { b[3], K.guardH, b[4] },
                    CFrame = Spec.cframe({ b[1], kerbTopY + K.guardH / 2, b[2] }),
                    Transparency = 1,
                    CanCollide = true,
                    CollisionGroup = "EngawaBarrier",
                    CanQuery = false,
                    CanTouch = false,
                    CastShadow = false,
                })
            )
        end
        -- field slab inside the kerb, proud of the terrace
        local fw, fd = (x2 - x1) - 2 * w, (z2 - z1) - 2 * w
        local variant = if (z2 - z1) >= (x2 - x1) then "RakedSandNS" else "RakedSandEW"
        table.insert(
            children,
            Spec.part(`Field{name}`, {
                Size = { fw, 0.4, fd },
                CFrame = Spec.cframe({ (x1 + x2) / 2, slabTopY - 0.2, (z1 + z2) / 2 }),
                Color = { 0.87, 0.85, 0.79 }, -- pale zen sand under the variant
                Material = "Sand",
                MaterialVariant = variant,
            })
        )
    end

    panel("Main", K.panels.main, K.floorY.main)
    return Spec.model("Karesansui", children)
end

return Karesansui
