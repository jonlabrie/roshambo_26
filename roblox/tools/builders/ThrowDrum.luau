--!strict
-- Mawari-dōrō revolving lantern crowning the shōrō (replaces the horizontal hex drum).
-- A squat 12-facet inner drum rotates on a VERTICAL axis behind a fixed 4-window outer
-- shade. Facets carry R,P,S ×4, so all four windows (90° apart) show the same symbol and a
-- 30° step advances all four. Glyphs are attached at runtime by DrumController (Glyphs.render
-- on a SurfaceGui, LightInfluence 0). The interior Lamp makes it glow at night; the opaque
-- cypress goes dark so only the always-bright glyph reads (day gold-on-cypress, night lit).
-- The DrumController spins the invisible `Drum` hub about its LOCAL Y.
local Spec = require("./Spec")

local ThrowDrum = {}

-- face index → glyph; k % 3 picks R/P/S. Exposed for tests + the controller.
ThrowDrum.SYMBOL_FOR_FACE = {} :: { [number]: string }
do
    local sym = { [0] = "R", [1] = "P", [2] = "S" }
    for k = 0, 11 do
        ThrowDrum.SYMBOL_FOR_FACE[k] = sym[k % 3]
    end
end

function ThrowDrum.build(palette: { [string]: { number } }, L: any): Spec.PartSpec
    local d = L.throwDrum
    local px, py, pz = d.pos[1], d.pos[2], d.pos[3]
    local r, h, faces = d.radius, d.height, d.faces
    local cyp = palette.cypressWeathered
    local slate = palette.slateTile
    local gold = palette.gold
    local ink = palette.ink

    local step = (2 * math.pi) / faces -- 30°
    local apothem = r * math.cos(math.pi / faces) -- centre→facet midpoint
    local side = 2 * r * math.sin(math.pi / faces) -- facet chord
    local faceW = side * 1.02 -- slight overlap so facets meet at the vertices

    local top: { Spec.PartSpec } = {}

    -- Invisible vertical-axis hub: its LOCAL Y is the spin axis the controller turns.
    table.insert(
        top,
        Spec.part("Drum", {
            Size = { 2 * r, h, 2 * r },
            CFrame = Spec.cframe({ px, py, pz }),
            Transparency = 1,
            CanCollide = false,
            Color = ink,
        })
    )

    -- 12 cypress facet panels around +Y. Face 0 faces the FRONT (-Z) window; face k is
    -- yawed k*30° about +Y. Slab Front (-Z) points radially outward (the showing side,
    -- where DrumController puts the glyph SurfaceGui).
    for k = 0, faces - 1 do
        local adeg = k * (360 / faces)
        local a = math.rad(adeg)
        local fx = px - apothem * math.sin(a)
        local fz = pz - apothem * math.cos(a)
        table.insert(
            top,
            Spec.part(`Face{k}`, {
                Size = { faceW, h, 0.5 },
                CFrame = Spec.cframe({ fx, py, fz }, Spec.yaw(adeg)),
                Color = cyp,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end

    -- Fixed outer shade: 4 corner posts at the 45° diagonals (between the N/E/S/W windows),
    -- standing just outside the facet ring. The gaps between posts ARE the four windows.
    local postR = r + 1.2
    local postH = h + 2
    for i = 1, 4 do
        local a = math.rad(45 + (i - 1) * 90)
        table.insert(
            top,
            Spec.part(`Post{i}`, {
                Size = { 1.4, postH, 1.4 },
                CFrame = Spec.cframe({ px + postR * math.sin(a), py, pz + postR * math.cos(a) }),
                Color = cyp,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end

    -- Base ring the lantern seats on (bronze-banded cypress collar just under the facets).
    table.insert(
        top,
        Spec.part("Base", {
            Size = { 2 * (r + 1.6), 1.4, 2 * (r + 1.6) },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ px, py - h / 2 - 0.7, pz }, Spec.ROT.CYL_VERTICAL),
            Color = cyp,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )

    -- Kasa cap (FIRST PASS — a wide low kawara disc; live-tuned into a miniature hip roof
    -- later, see the live gate). Sits on the post tops, overhanging the windows for shade.
    local capY = py + postH / 2 + 0.8
    table.insert(
        top,
        Spec.part("RoofCap", {
            Size = { 2 * (postR + 2.5), 1.6, 2 * (postR + 2.5) },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ px, capY, pz }, Spec.ROT.CYL_VERTICAL),
            Color = slate,
            Material = "Slate",
            MaterialVariant = "SlateTile",
        })
    )

    -- Gilt hōju finial on the cap (a gold ball). Plain gold Metal — NOT the dark IronDark
    -- variant (which would kill the gilt read); there is no gold MaterialVariant in the palette.
    table.insert(
        top,
        Spec.part("Finial", {
            Size = { 2.2, 2.2, 2.2 },
            Shape = "Ball",
            CFrame = Spec.cframe({ px, capY + 1.8, pz }),
            Color = gold,
            Material = "Metal",
        })
    )

    -- Interior lamp: warm point light for the night bloom; hosted on a tiny invisible part
    -- at the hub centre (the controller does not spin it — symmetric, invisible).
    table.insert(
        top,
        Spec.part("Lamp", {
            Size = { 0.6, 0.6, 0.6 },
            CFrame = Spec.cframe({ px, py, pz }),
            Transparency = 1,
            CanCollide = false,
            Color = gold,
            children = {
                {
                    name = "LampLight",
                    className = "PointLight",
                    -- Color is a {r,g,b} ARRAY (not Color3.new) — matches how every builder
                    -- emits light children (see StoneLantern "Glow"); keeps the builder Lune-safe.
                    properties = { Color = gold, Brightness = 2, Range = 18 },
                },
            },
        })
    )

    return Spec.model("ThrowDrum", top)
end

return ThrowDrum
