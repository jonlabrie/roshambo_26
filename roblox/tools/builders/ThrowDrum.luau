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

-- Orient a rim slab so its Roblox FRONT face (−Z) points radially OUTWARD at
-- hexagon angle a — i.e. the labelled "front" of the panel is the side that
-- shows (where the glyph SurfaceGui goes). = rotX(-a) then 180° about local Y;
-- this keeps the slab's vertical axis (∧ stays up) and only mirrors along the
-- drum axis, which is invisible for the symmetric ○ ─ ∧.
local function faceRot(a: number): { number }
    local c, s = math.cos(a), math.sin(a)
    return { -1, 0, 0, 0, c, -s, 0, -s, -c }
end

function ThrowDrum.build(palette: { [string]: { number } }, L: any): Spec.PartSpec
    local d = L.throwDrum
    local px, py, pz = d.pos[1], d.pos[2], d.pos[3]
    local length, r, faces = d.length, d.radius, d.faces
    local timber = palette.timber
    local ink = palette.ink
    -- The drum rides the bell-engine's vertical shaft (off-origin), so yaw it about
    -- its OWN centre (px,py,pz), not the world origin: yaw 90 swings the prism axis
    -- (local X) onto world Z so the showing faces present up/downriver (±X). The
    -- DrumController captures every spinning part as an offset from the hub, so this
    -- rotation is transparent to it.
    local yaw = d.yaw or 0
    local function place(pos: { number }, rot: { number }?): { number }
        local off = Spec.rotY({ pos[1] - px, pos[2] - py, pos[3] - pz }, yaw)
        return Spec.cframe(
            { px + off[1], py + off[2], pz + off[3] },
            Spec.matMul(Spec.rotYMat(yaw), rot or Spec.ROT.IDENTITY)
        )
    end

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
            CFrame = place({ px, py, pz }),
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
            CFrame = place({ px, py, pz }),
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
                    CFrame = place(sp, srot),
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
                -- faceRot(a): the slab's FRONT (−Z) faces radially outward, so the
                -- glyph SurfaceGui (on Front) is the showing side.
                CFrame = place({ px, fy, fz }, faceRot(a)),
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
