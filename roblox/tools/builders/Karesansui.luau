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
    local kerbH = 1.2 -- rooted below grade; top = floorY + kerbProud
    local kerbTopY = K.floorY + K.kerbProud
    local slabTopY = K.floorY + K.slabProud

    local function panel(name: string, r: { number })
        local x1, z1, x2, z2 = r[1], r[2], r[3], r[4]
        local w = K.kerbW
        -- kerb: N/S beams span the full width; E/W beams inset between them (mitre-read)
        local beams = {
            N = { (x1 + x2) / 2, z1 + w / 2, x2 - x1, w },
            S = { (x1 + x2) / 2, z2 - w / 2, x2 - x1, w },
            W = { x1 + w / 2, (z1 + z2) / 2, w, z2 - z1 - 2 * w },
            E = { x2 - w / 2, (z1 + z2) / 2, w, z2 - z1 - 2 * w },
        }
        for side, b in beams do
            table.insert(
                children,
                Spec.part(`Kerb{name}{side}`, {
                    Size = { b[3], kerbH, b[4] },
                    CFrame = Spec.cframe({ b[1], kerbTopY - kerbH / 2, b[2] }),
                    Color = palette.gravel,
                    Material = "Slate",
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

    panel("East", K.panels.east)
    panel("South", K.panels.south)
    return Spec.model("Karesansui", children)
end

return Karesansui
