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
        -- THE KERB RUNS DIE INTO THE PLINTHS; THE GUARDS DO NOT. Two different spans, and they are
        -- different for a reason.
        --
        -- The visible beams used to cross the full panel, so at every corner one ran over the
        -- plinth's top and the post read as standing ON the kerb (owner, with a photograph). Each
        -- run now stops at the plinth's INNER face — tucked a little past it, because a joint that
        -- merely touches shows a seam. All four runs are the same length, and no run meets another:
        -- the plinths separate them, which is what the reference photograph shows.
        --
        -- The GUARD is the invisible barrier and must still close the corners. Shortening it to
        -- match would leave a plinth-wide gap at each one, and a plinth stands only 0.6 above the
        -- floor — a step-over, not an obstacle. So the guard keeps the full span.
        local P = L.pavilion
        local KERB_TUCK = 0.06
        local run = P.postSpacing - P.plinthD + 2 * KERB_TUCK
        local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
        local beams = {
            N = { cx, z1 + w / 2, run, w },
            S = { cx, z2 - w / 2, run, w },
            W = { x1 + w / 2, cz, w, run },
            E = { x2 - w / 2, cz, w, run },
        }
        local guards = {
            N = { cx, z1 + w / 2, x2 - x1, w },
            S = { cx, z2 - w / 2, x2 - x1, w },
            W = { x1 + w / 2, cz, w, z2 - z1 - 2 * w },
            E = { x2 - w / 2, cz, w, z2 - z1 - 2 * w },
        }
        -- CYPRESS, MATCHING THE POSTS IT NOW RUNS BETWEEN (owner's gate 2026-08-14). Dressed slate
        -- was right while this was a garden the tower stood in; now the kerb is the tower's own
        -- edging and belongs to the same timber.
        --
        -- ONE BEAM CANNOT GET BOTH ITS FACES RIGHT, which is why the E/W beams are capped.
        -- The cypress maps project from WORLD axes, not per-part UVs, so turning a beam cannot
        -- turn its grain — only the variant can, and there are two of them: CypressWeathered and
        -- the same maps a quarter turn round (CypressVertical). Established at the gate by
        -- looking, in two passes:
        --
        --   N/S beam (long in X)   top -> grain along X  RIGHT    sides -> along X  RIGHT
        --   E/W beam (long in Z)   top -> grain along X  WRONG    sides -> along Z  RIGHT
        --
        -- Rotating the maps only swaps which of the two is wrong: CypressVertical fixed the E/W
        -- tops and banded their sides instead. So the E/W beams keep the unrotated maps for their
        -- SIDES — the tall visible face — and a thin capping board takes the rotated maps for the
        -- TOP. N/S beams need no cap; both their faces already agree.
        --
        -- The cap is also just what a timber kerb has. It overhangs a little so its edges never
        -- land coplanar with the beam's, and the beam is shortened by exactly its thickness so all
        -- four kerbs still top out on the same line.
        local CAP_T = 0.08
        local CAP_OVERHANG = 0.05
        for side, b in beams do
            local runsInX = b[3] > b[4]
            local capped = not runsInX
            local h = if capped then K.kerbH - CAP_T else K.kerbH
            local topY = if capped then kerbTopY - CAP_T else kerbTopY
            table.insert(
                children,
                Spec.part(`Kerb{name}{side}`, {
                    Size = { b[3], h, b[4] },
                    CFrame = Spec.cframe({ b[1], topY - h / 2, b[2] }),
                    Color = palette.cypressWeathered,
                    Material = "Wood",
                    MaterialVariant = "CypressWeathered",
                })
            )
            if capped then
                table.insert(
                    children,
                    Spec.part(`KerbCap{name}{side}`, {
                        Size = { b[3] + 2 * CAP_OVERHANG, CAP_T, b[4] },
                        CFrame = Spec.cframe({ b[1], kerbTopY - CAP_T / 2, b[2] }),
                        Color = palette.cypressWeathered,
                        Material = "Wood",
                        MaterialVariant = "CypressVertical",
                    })
                )
            end
            -- from `guards`, not `b`: the barrier keeps the FULL span so the corners stay closed
            local gb = guards[side]
            table.insert(
                children,
                Spec.part(`Guard{name}{side}`, {
                    Size = { gb[3], K.guardH, gb[4] },
                    CFrame = Spec.cframe({ gb[1], kerbTopY + K.guardH / 2, gb[2] }),
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
