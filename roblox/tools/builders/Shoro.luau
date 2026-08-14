--!strict
-- Timber shōrō (bell pavilion) standing over the clearing. 2026-07-20 art pass:
-- weathered-cypress posts/beams (CypressWeathered variant), stepped tokyō bracket
-- stacks over each post head, a fan of exposed rafter tails under the eaves, and
-- projecting carved beam-noses (kibana) at the corners. The roof is still the four
-- flat wedges (now the SlateTile kawara variant) — Task 5 swaps it for a hip mesh
-- and sizes the tower to the bell.
local Spec = require("./Spec")

local Shoro = {}

function Shoro.build(palette: { [string]: { number } }, L: any)
    local s = L.pavilion.postSpacing / 2
    local pd = L.pavilion.postD -- post thickness; the karesansui kerb line is derived from it
    local plinthD = L.pavilion.plinthD -- WIDER than the post, so the kerb dies into it
    local plinthH = L.pavilion.plinthH -- TALLER than it was, to top out level with the kerb
    local POST_FOOT = 1.7 -- the log's own bottom; the plinth now rises past it and sockets it
    local roofY = L.pavilion.roofHeight
    local cypress = palette.cypressWeathered
    local children = {}
    local yaw = L.pavilion.yaw or 0
    local base = L.pavilion.pos
    local function place(pos: { number }, rot: { number }?): { number }
        local p = Spec.rotY(pos, yaw)
        return Spec.cframe(
            { base[1] + p[1], base[2] + p[2], base[3] + p[3] },
            Spec.matMul(Spec.rotYMat(yaw), rot or Spec.ROT.IDENTITY)
        )
    end
    -- a weathered-cypress timber member (posts, beams, brackets, rafters, noses)
    local function timberPart(name: string, size: { number }, cf: { number }): Spec.PartSpec
        return Spec.part(name, {
            Size = size,
            CFrame = cf,
            Color = cypress,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    end

    local corners = { { s, s }, { s, -s }, { -s, s }, { -s, -s } }
    for i, c in corners do
        -- stone plinth footing (dressed slate)
        table.insert(
            children,
            Spec.part(`Plinth{i}`, {
                -- Tops out level with the karesansui kerb (owner's gate 2026-08-14). It was 1.7,
                -- which left the kerb running a quarter stud higher than the stone it dies into.
                -- The height comes from ArenaLayout because the kerb's does too — see plinthH.
                Size = { plinthD, plinthH, plinthD },
                CFrame = place({ c[1], plinthH / 2, c[2] }),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
        -- heavy round cypress log (reference: thick round pillars), long axis vertical
        table.insert(
            children,
            Spec.part(`Post{i}`, {
                -- The post's foot stays where it always was. The plinth grew UP past it, so the
                -- log is now SOCKETED into the stone rather than standing on its face — which is
                -- how a hinoki post meets a base stone anyway, and it means nothing above the
                -- plinth moved: the shaft still reaches roofY exactly as before.
                Size = { roofY - POST_FOOT, pd, pd },
                Shape = "Cylinder",
                CFrame = place({ c[1], POST_FOOT + (roofY - POST_FOOT) / 2, c[2] }, Spec.ROT.CYL_VERTICAL),
                Color = cypress,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    for i, z in { s, -s } do
        table.insert(
            children,
            timberPart(`RingBeamX{i}`, { 2 * s + pd, 1.2, 1.4 }, place({ 0, roofY - 0.6, z }))
        )
    end
    for i, x in { s, -s } do
        table.insert(
            children,
            timberPart(`RingBeamZ{i}`, { 1.4, 1.2, 2 * s + pd }, place({ x, roofY - 0.6, 0 }))
        )
    end
    -- BellBeam rests ATOP the two ring beams (it carries the bell's weight): its
    -- underside sits on the ring-beam tops (local y = roofY), so centre = roofY + 0.9.
    table.insert(children, timberPart("BellBeam", { 2.2, 1.8, 2 * s + pd }, place({ 0, roofY + 0.9, 0 })))

    -- Tokyō: a stepped block-stack over each post head, each course cantilevering wider
    -- toward the eave (the reference's bracket complex). Cheap primitives.
    for i, c in corners do
        for j = 1, 3 do
            local w = 1.6 + j * 0.5
            table.insert(
                children,
                timberPart(
                    `Bracket{i}_{j}`,
                    { w, 0.5, w },
                    place({ c[1], roofY - 0.35 + (j - 1) * 0.55, c[2] })
                )
            )
        end
    end

    -- Inner skirt ring beams: the truncated hip is OPEN at the top, so a second square of
    -- ring beams sits atop the Bracket_3 heads to carry the rafters' inner ends and the
    -- roof's upper (inner) edge — same section as the eave ring beams. (2026-07-22)
    local skirtBeamY = roofY + 1.6 -- atop the Bracket{i}_3 heads (top ≈ roofY + 1.0)
    for i, z in { s, -s } do
        table.insert(
            children,
            timberPart(`SkirtBeamX{i}`, { 2 * s + pd, 1.2, 1.4 }, place({ 0, skirtBeamY, z }))
        )
    end
    for i, x in { s, -s } do
        table.insert(
            children,
            timberPart(`SkirtBeamZ{i}`, { 1.4, 1.2, 2 * s + pd }, place({ x, skirtBeamY, 0 }))
        )
    end

    -- Projecting carved beam-noses (kibana) where the ring beams cross the corner posts.
    for i, c in corners do
        table.insert(
            children,
            timberPart(`BeamNose{i}`, { 1.0, 1.1, 1.6 }, place({ c[1], roofY - 0.6, c[2] }))
        )
    end

    -- ── Hip roof (procedural parts, teahouse-style — no mesh/.rbxm) ──────────────
    -- A square pyramid: 4 triangular faces (WedgeParts via the canonical triangle
    -- split), 4 hip stringers apex→corner, and a rafter fan per face. Dimensions match
    -- the hand-tuned build. Built in world coords about the pavilion centre.
    local cx, cz = base[1], base[3]
    local roofLift = 0.5 -- lift the roof + rafter/stringer frame ½ stud to seat it on the skirt beams (2026-07-22)
    local eaveWY = base[2] + roofY - 0.5 + roofLift -- eave seats on the tokyō brackets atop the posts (world y)
    -- 20% smaller roof so the crown lantern reads better from below (gate-tuned 2026-07-22).
    -- Faces, hip stringers and the rafter fan all derive from RErf/apexRise, so they scale too.
    local roofScale = 0.9
    local RErf = 19.5 * roofScale -- eave half-side
    local apexRise = 6.5 * roofScale
    local apexWY = eaveWY + apexRise
    local faceLift = 1.0 -- faces sit this far above the timber frame

    -- little vector helpers (plain tables; math.sqrt is arch-portable, unlike trig-hash)
    local function vsub(a, b): { number }
        return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
    end
    local function vdot(a, b): number
        return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
    end
    local function vunit(a): { number }
        local l = math.sqrt(vdot(a, a))
        return { a[1] / l, a[2] / l, a[3] / l }
    end
    -- world point from a pavilion-local (x, y, z): rotate x/z by the pavilion yaw
    local function lw(x: number, y: number, z: number): { number }
        local p = Spec.rotY({ x, 0, z }, yaw)
        return { cx + p[1], y, cz + p[3] }
    end

    -- eave corners + apex of the visible face pyramid
    -- selene: allow(shadowing)
    local corners, fcorners = {}, {}
    for _, q in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
        corners[#corners + 1] = lw(q[1] * RErf, eaveWY, q[2] * RErf)
        fcorners[#fcorners + 1] = lw(q[1] * RErf, eaveWY - faceLift, q[2] * RErf) -- frame corner (below)
    end
    local apex = { cx, apexWY, cz }
    local fApex = { cx, apexWY - faceLift, cz }

    -- Eave SKIRT (truncated hip): the roof is OPEN above the ring-beam line so the crown
    -- lantern rises through it. Inner corners sit `skirtT` of the way up each hip (0 = apex,
    -- 1 = eave corner); the pyramid cap above them is removed. Faces become trapezoids,
    -- hips + rafters stop at the inner edge. (2026-07-22)
    -- inner-edge radius: +0.5 past 0.55·RErf so the opening clears the lantern legs (2026-07-22)
    local RInner = 0.55 * RErf + 0.5
    local skirtT = RInner / RErf -- fraction up each hip (keeps the inner edge ON the slope)
    local inner, finner = {}, {}
    for i = 1, 4 do
        inner[i] = {
            apex[1] + skirtT * (corners[i][1] - apex[1]),
            apex[2] + skirtT * (corners[i][2] - apex[2]),
            apex[3] + skirtT * (corners[i][3] - apex[3]),
        }
        finner[i] = {
            fApex[1] + skirtT * (fcorners[i][1] - fApex[1]),
            fApex[2] + skirtT * (fcorners[i][2] - fApex[2]),
            fApex[3] + skirtT * (fcorners[i][3] - fApex[3]),
        }
    end

    -- Slate roof faces are now the committed mesh `assets/meshes/ShoroRoof.rbxm`
    -- (SurfaceAppearance + up-slope UVs, referenced under RoshamboStage): procedural
    -- WedgeParts/Parts tiled the kawara inconsistently across a hip, so the surface moved
    -- to a single mesh. The cypress frame below (hip stringers + rafters) stays procedural.
    -- The mesh corners derive from the same eaveWY/RErf/RInner/skirtT used here — if any of
    -- those change, rebuild the mesh via `tools/studio/buildShoroRoofMesh.luau`. (2026-07-22)

    -- hip stringers: inner frame corner → eave frame corner (the skirt hip), outer end trimmed 1
    for i, fc in fcorners do
        local dir = vunit(vsub(fc, finner[i]))
        local trimmed = { fc[1] - dir[1], fc[2] - dir[2], fc[3] - dir[3] }
        local sp, slen, srot = Spec.segment(finner[i], trimmed)
        table.insert(
            children,
            Spec.part(`HipStringer{i}`, {
                Size = { slen, 1, 1 },
                CFrame = Spec.cframe(sp, srot),
                Color = cypress,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end

    -- rafter fan: per face, parallel battens eave→hip on the frame pyramid
    local rafterRaise = 0.5 -- lift the rafter fan to tuck just under the faces (gate-tuned)
    local frameEaveY = eaveWY - faceLift + rafterRaise
    local frameApexY = apexWY - faceLift + rafterRaise
    local nR = 0
    for k = 0, 3 do
        local fyaw = yaw + 90 * k -- pavilion yaw + this face's quarter turn
        local x = -RErf + 1.5
        while x <= RErf - 1.5 do
            local zt = math.max(math.abs(x), RInner) -- stop at the skirt inner edge, not the removed apex
            local yHip = frameEaveY + (frameApexY - frameEaveY) * (RErf - zt) / RErf
            local pa = Spec.rotY({ x, 0, RErf }, fyaw) -- +Z-face eave point, rotated to face k
            local pb = Spec.rotY({ x, 0, zt }, fyaw) -- its up-slope (hip) end
            local A = { cx + pa[1], frameEaveY, cz + pa[3] }
            local B = { cx + pb[1], yHip, cz + pb[3] }
            local sp, slen, srot = Spec.segment(A, B)
            if slen > 1 then
                nR += 1
                table.insert(
                    children,
                    Spec.part(`Rafter{nR}`, {
                        Size = { slen, 0.3, 0.3 },
                        CFrame = Spec.cframe(sp, srot),
                        Color = cypress,
                        Material = "Wood",
                        MaterialVariant = "CypressWeathered",
                    })
                )
            end
            x += 2
        end
    end

    return Spec.model("Shoro", children)
end

return Shoro
