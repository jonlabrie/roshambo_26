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

    -- ── Fixed outer shade ──────────────────────────────────────────────────────
    -- 8 solid cypress panels hug the drum curve — one tangent over each OFF-cardinal facet,
    -- following the 12-gon like the facet it covers. The 4 cardinal directions stay open as
    -- WINDOWS, each framing the single facet currently there → all four windows read the same
    -- symbol (the drum spins so a matching facet lands at each cardinal). Riding close to the
    -- facet ring keeps neighbours from peeking (no parallax gap). 4 slim corner posts stand
    -- proud at the diagonals for the andon read. Panels/posts are STATIC (only Faces spin).
    local shadeR = r + 0.8 -- panels ride just outside the spinning facet ring, following its curve
    local shadeH = h + 0.4
    local panelW = faceW * 1.08 -- ≈ a facet chord, overlapping neighbours so the wall is closed
    local shadeDirs = { 30, 60, 120, 150, 210, 240, 300, 330 } -- the 8 off-cardinal facet angles
    for i, adeg in shadeDirs do
        local a = math.rad(adeg)
        table.insert(
            top,
            Spec.part(`ShadePanel{i}`, {
                Size = { panelW, shadeH, 0.6 },
                CFrame = Spec.cframe(
                    { px - shadeR * math.sin(a), py, pz - shadeR * math.cos(a) },
                    Spec.yaw(adeg)
                ),
                Color = cyp,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    local postR = r + 2.0 -- corner posts stand proud of the panels, at the 4 diagonals
    local postH = h + 5 -- extended 2 studs downward so they reach the tower roof as legs
    local postCY = py - 1 -- top stays put (py + (h+3)/2); the extra 2 studs hang below
    for i = 1, 4 do
        local a = math.rad(45 + (i - 1) * 90)
        table.insert(
            top,
            Spec.part(`Post{i}`, {
                Size = { 1.2, postH, 1.2 },
                -- yaw 45° → diamond profile (a corner faces outward)
                CFrame = Spec.cframe(
                    { px - postR * math.sin(a), postCY, pz - postR * math.cos(a) },
                    Spec.yaw(45)
                ),
                Color = cyp,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end

    -- Base disc the lantern seats on (flat cypress collar just under the facets). For a
    -- Cylinder the AXIS is the first Size dim, so a flat disc is {thickness, dia, dia} laid
    -- flat by CYL_VERTICAL (axis→Y). (Getting this order wrong makes a tall vertical fin.)
    table.insert(
        top,
        Spec.part("Base", {
            Size = { 0.47, 2 * (r + 1.6), 2 * (r + 1.6) }, -- 1/3 the old thickness
            Shape = "Cylinder",
            CFrame = Spec.cframe({ px, py - h / 2 - 0.4, pz }, Spec.ROT.CYL_VERTICAL),
            Color = cyp,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )

    -- ── Miniature hip roof (Shoro's recipe, shrunk; 4 wedge faces + 4 hip stringers, NO
    -- rafter fan at this size). Square pyramid, axis-aligned so eave midpoints overhang the
    -- 4 windows and the hip corners sit over the 4 diagonal posts.
    local RErf = r + 3 -- eave half-side; overhangs the corner posts (r+2) so they tuck under
    local eaveWY = py + 4.8 -- eave meets the post tops (~py+5.1) at the post radius
    local apexRise = 4.5
    local apexWY = eaveWY + apexRise
    local roofT = 0.5
    local function vsub(a, b): { number }
        return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
    end
    local function vdot(a, b): number
        return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
    end
    local function vcross(a, b): { number }
        return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
    end
    local function vunit(a): { number }
        local l = math.sqrt(vdot(a, a))
        return { a[1] / l, a[2] / l, a[3] / l }
    end
    local function vmid(a, b): { number }
        return { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }
    end
    local function rotAxes(vx, vy, vz): { number }
        return { vx[1], vy[1], vz[1], vx[2], vy[2], vz[2], vx[3], vy[3], vz[3] }
    end
    local rcorners = {}
    for _, q in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
        rcorners[#rcorners + 1] = { px + q[1] * RErf, eaveWY, pz + q[2] * RErf }
    end
    local apex = { px, apexWY, pz }
    -- one triangular face → two WedgeParts (canonical right-angle split + handedness)
    local function triFace(name: string, a: { number }, b: { number }, c: { number })
        local ab, ac, bc = vsub(b, a), vsub(c, a), vsub(c, b)
        local abd, acd, bcd = vdot(ab, ab), vdot(ac, ac), vdot(bc, bc)
        if abd > acd and abd > bcd then
            a, c = c, a
        elseif acd > bcd and acd > abd then
            a, b = b, a
        end
        ab, ac, bc = vsub(b, a), vsub(c, a), vsub(c, b)
        local right = vunit(vcross(ac, ab))
        local up = vunit(vcross(bc, right))
        local back = vunit(bc)
        local height = math.abs(vdot(ab, up))
        local nb, nr = { -back[1], -back[2], -back[3] }, { -right[1], -right[2], -right[3] }
        table.insert(top, {
            name = `{name}_1`,
            className = "WedgePart",
            properties = {
                Anchored = true,
                Size = { roofT, height, math.abs(vdot(ab, back)) },
                CFrame = Spec.cframe(vmid(a, b), rotAxes(right, up, back)),
                Color = slate,
                Material = "Slate",
                MaterialVariant = "SlateTile",
            },
        })
        table.insert(top, {
            name = `{name}_2`,
            className = "WedgePart",
            properties = {
                Anchored = true,
                Size = { roofT, height, math.abs(vdot(ac, back)) },
                CFrame = Spec.cframe(vmid(a, c), rotAxes(nr, up, nb)),
                Color = slate,
                Material = "Slate",
                MaterialVariant = "SlateTile",
            },
        })
    end
    for i = 1, 4 do
        triFace(`RoofFace{i}`, apex, rcorners[i], rcorners[i % 4 + 1])
    end
    for i, fc in rcorners do
        local sp, slen, srot = Spec.segment(apex, fc)
        table.insert(
            top,
            Spec.part(`HipStringer{i}`, {
                Size = { slen, 0.7, 0.7 },
                CFrame = Spec.cframe(sp, srot),
                Color = cyp,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    local capY = apexWY -- the finial sits on the ridge apex

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
                    -- dim + short-range so the warm light doesn't spill onto the exterior in
                    -- daylight (a subtle interior night accent through the windows). Facets are
                    -- opaque cypress (no translucency) — the earlier warmth was this lamp spilling.
                    properties = { Color = gold, Brightness = 0.7, Range = 10 },
                },
            },
        })
    )

    return Spec.model("ThrowDrum", top)
end

return ThrowDrum
