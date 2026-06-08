--!strict
-- Hexagonal World-Throw drum on a HORIZONTAL axis (world X = E/W) atop the
-- shōrō. 6 flat timber faces carry gold R/P/S/R/P/S so opposite faces (k and
-- k+3) match → the front (−Z) and back (+Z) windows always read the same
-- symbol. A miya-style housing hides the other 4 faces. The DrumController
-- spins the invisible `Drum` hub (its local X is the spin axis) and attaches
-- the symbol SurfaceGuis to the faces at runtime (the face frame rotates with
-- the drum, so orientation is a runtime concern — see DrumController).
local Spec = require("./Spec")

local ThrowDrum = {}

-- face index → glyph; index%3 picks the symbol (0=R ○, 1=P ─, 2=S ∧) and
-- k, k+3 share it. Exposed for tests (k and k+3 must match).
ThrowDrum.SYMBOL_FOR_FACE = { [0] = "○", [1] = "─", [2] = "∧", [3] = "○", [4] = "─", [5] = "∧" }

-- rotation matrix (3x3, row-major) for "rotate a part about world X by angle a".
local function rotX(a: number): { number }
    local c, s = math.cos(a), math.sin(a)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function ThrowDrum.build(palette: { [string]: { number } }, L: any): Spec.PartSpec
    local d = L.throwDrum
    local px, py, pz = d.pos[1], d.pos[2], d.pos[3]
    local length, r, faces = d.length, d.radius, d.faces
    local timber = palette.timber
    local ink = palette.ink

    local step = (2 * math.pi) / faces -- 60° per face
    local apothem = r * math.cos(math.pi / faces) -- center→edge-midpoint (face sits here)
    local side = 2 * r * math.sin(math.pi / faces) -- hexagon edge length (= r for a hexagon)
    local faceW = side * 1.04 -- slight overlap so faces meet cleanly at the vertices

    -- Top-level model children: the hub + solid core + 6 faces, plus Housing.
    local top: { Spec.PartSpec } = {}

    -- invisible rotation hub: its local X is the spin axis the controller turns
    table.insert(
        top,
        Spec.part("Drum", {
            Size = { length, 2 * r, 2 * r },
            CFrame = Spec.cframe({ px, py, pz }),
            Transparency = 1,
            CanCollide = false,
            Color = ink,
        })
    )

    -- solid round core (round axis = local X = the spin axis) so the drum reads
    -- as one solid body, not 6 floating panels. Static — a round cylinder looks
    -- identical spun, so the controller only needs to rotate the lettered faces.
    table.insert(
        top,
        Spec.part("Core", {
            Size = { length, 2 * (apothem - 0.2), 2 * (apothem - 0.2) },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ px, py, pz }),
            Color = timber,
            Material = "Wood",
        })
    )

    -- 6 timber faces tiling a closed hexagon at the apothem. Face k is at angle
    -- k*60° from +Z (so face 0 faces +Z/back, face 3 faces −Z/front at θ=0).
    for k = 0, faces - 1 do
        local a = k * step
        local fy = py + apothem * math.sin(a)
        local fz = pz + apothem * math.cos(a)
        table.insert(
            top,
            Spec.part(`Face{k}`, {
                Size = { length, faceW, 0.5 },
                CFrame = Spec.cframe({ px, fy, fz }, rotX(a)),
                Color = timber,
                Material = "Wood",
            })
        )
    end

    -- Miya housing: a timber box around the drum with a front (−Z) and back (+Z)
    -- aperture each ~one face wide, so only the front/back faces show. Rough; the
    -- art pass refines.
    local housing: { Spec.PartSpec } = {}
    local boxLen = length + 2
    local wallT = 0.5
    local apertureW = faceW + 1 -- one-face-wide window, a touch of slack
    local sideZ = r + 0.4 -- inner Z faces of the housing

    -- left/right end caps (X extremes) hide the inside faces from the ends
    for i, ex in { -(boxLen / 2 + wallT / 2), boxLen / 2 + wallT / 2 } do
        table.insert(
            housing,
            Spec.part(`HousingEnd{i}`, {
                Size = { wallT, 2 * r + 1, 2 * sideZ + wallT },
                CFrame = Spec.cframe({ px + ex, py, pz }),
                Color = timber,
                Material = "Wood",
            })
        )
    end

    -- front (−Z) and back (+Z) panels: two posts framing the central aperture,
    -- plus a lintel above it, so a single face peeks through each window.
    local sideRun = (boxLen - apertureW) / 2 -- width of each framing post per side
    for _, zdir in { -1, 1 } do
        local label = if zdir < 0 then "Front" else "Back"
        local zw = pz + zdir * (sideZ + wallT / 2)
        for j, sx in { -(apertureW / 2 + sideRun / 2), apertureW / 2 + sideRun / 2 } do
            table.insert(
                housing,
                Spec.part(`Housing{label}{j}`, {
                    Size = { sideRun, 2 * r + 1, wallT },
                    CFrame = Spec.cframe({ px + sx, py, zw }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
        table.insert(
            housing,
            Spec.part(`Housing{label}Lintel`, {
                Size = { apertureW, r, wallT },
                CFrame = Spec.cframe({ px, py + r / 2 + 0.5, zw }),
                Color = timber,
                Material = "Wood",
            })
        )
    end

    -- simple hipped roof: two wedges meeting at a ridge running along X
    local roofHalf = sideZ + wallT + 1.5
    local pitch = 3
    local roofY = py + r + 1 + pitch / 2
    local wedges = {
        { rot = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, pos = { px, roofY, pz + roofHalf / 2 } },
        { rot = { -1, 0, 0, 0, 1, 0, 0, 0, -1 }, pos = { px, roofY, pz - roofHalf / 2 } },
    }
    for i, w in wedges do
        table.insert(
            housing,
            {
                name = `HousingRoof{i}`,
                className = "WedgePart",
                properties = {
                    Anchored = true,
                    Size = { boxLen + 2 * wallT, pitch, roofHalf },
                    CFrame = Spec.cframe(w.pos, w.rot),
                    Color = ink,
                    Material = "Slate",
                },
            } :: Spec.PartSpec
        )
    end

    table.insert(top, Spec.model("Housing", housing))

    return Spec.model("ThrowDrum", top)
end

return ThrowDrum
