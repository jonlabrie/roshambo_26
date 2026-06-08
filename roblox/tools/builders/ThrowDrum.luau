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

    -- Top-level children: hub + shaft + 12 spokes + 6 rim faces, plus Housing.
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

    -- central shaft = the bearing/axle along local X; protrudes 1 stud past each
    -- end face to read as the bearing the housing holds. (Round + symmetric, so
    -- the controller leaves it static — spinning it is invisible.)
    table.insert(
        top,
        Spec.part("Shaft", {
            Size = { length + 2, 1.2, 1.2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ px, py, pz }),
            Color = ink,
            Material = "Metal",
        })
    )

    -- 6 spokes per end (12 total) radiating from the shaft to the hexagon's
    -- corners — the open internal structure that supports the rim faces.
    local spoke = 0
    for _, ex in { -length / 2 + 0.3, length / 2 - 0.3 } do
        for k = 0, faces - 1 do
            local v = (k + 0.5) * step -- vertex angle (between two faces)
            local vy = py + r * math.sin(v)
            local vz = pz + r * math.cos(v)
            local sp, slen, srot = Spec.segment({ px + ex, py, pz }, { px + ex, vy, vz })
            spoke += 1
            table.insert(
                top,
                Spec.part(`Spoke{spoke}`, {
                    Size = { slen, 0.4, 0.4 },
                    CFrame = Spec.cframe(sp, srot),
                    Color = ink,
                    Material = "WoodPlanks",
                })
            )
        end
    end

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
                -- rotX(-a): the slab's outward normal (local +Z) must point along
                -- the radial (0, sin a, cos a). rotX(+a) reflected it, so 4 of 6
                -- faces were mis-oriented; only a=0/180 (faces 0,3) were correct.
                CFrame = Spec.cframe({ px, fy, fz }, rotX(-a)),
                Color = timber,
                Material = "Wood",
            })
        )
    end

    -- No housing: the open hex prism reads clearly on its own. A roof matching
    -- the kōsatsu signboards may be added over it later (T23 design pass).

    return Spec.model("ThrowDrum", top)
end

return ThrowDrum
