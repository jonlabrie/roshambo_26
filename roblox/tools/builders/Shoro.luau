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
        -- stone plinth footing (unchanged: dressed slate)
        table.insert(
            children,
            Spec.part(`Plinth{i}`, {
                Size = { 2.4, 1.2, 2.4 },
                CFrame = place({ c[1], 0.6, c[2] }),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
        -- heavy round cypress log (reference: thick round pillars), long axis vertical
        table.insert(
            children,
            Spec.part(`Post{i}`, {
                Size = { roofY - 1.2, 2.4, 2.4 },
                Shape = "Cylinder",
                CFrame = place({ c[1], 1.2 + (roofY - 1.2) / 2, c[2] }, Spec.ROT.CYL_VERTICAL),
                Color = cypress,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    for i, z in { s, -s } do
        table.insert(
            children,
            timberPart(`RingBeamX{i}`, { 2 * s + 2.4, 1.2, 1.4 }, place({ 0, roofY - 0.6, z }))
        )
    end
    for i, x in { s, -s } do
        table.insert(
            children,
            timberPart(`RingBeamZ{i}`, { 1.4, 1.2, 2 * s + 2.4 }, place({ x, roofY - 0.6, 0 }))
        )
    end
    -- BellBeam rests ATOP the two ring beams (it carries the bell's weight): its
    -- underside sits on the ring-beam tops (local y = roofY), so centre = roofY + 0.9.
    table.insert(children, timberPart("BellBeam", { 2.2, 1.8, 2 * s + 2.4 }, place({ 0, roofY + 0.9, 0 })))

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
    local eaveWY = base[2] + roofY - 0.5 -- eave seats on the tokyō brackets atop the posts (world y)
    local RErf = 19.5 -- eave half-side
    local apexRise = 6.5
    local apexWY = eaveWY + apexRise
    local roofT = 0.5 -- face thickness
    local faceLift = 1.0 -- faces sit this far above the timber frame

    -- little vector helpers (plain tables; math.sqrt is arch-portable, unlike trig-hash)
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
    -- world point from a pavilion-local (x, y, z): rotate x/z by the pavilion yaw
    local function lw(x: number, y: number, z: number): { number }
        local p = Spec.rotY({ x, 0, z }, yaw)
        return { cx + p[1], y, cz + p[3] }
    end
    -- row-major CFrame rotation from local axes (columns X,Y,Z)
    local function rotAxes(vx, vy, vz): { number }
        return { vx[1], vy[1], vz[1], vx[2], vy[2], vz[2], vx[3], vy[3], vz[3] }
    end

    -- eave corners + apex of the visible face pyramid
    local corners, fcorners = {}, {}
    for _, q in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
        corners[#corners + 1] = lw(q[1] * RErf, eaveWY, q[2] * RErf)
        fcorners[#fcorners + 1] = lw(q[1] * RErf, eaveWY - faceLift, q[2] * RErf) -- frame corner (below)
    end
    local apex = { cx, apexWY, cz }
    local fApex = { cx, apexWY - faceLift, cz }

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
        table.insert(children, {
            name = `{name}_1`,
            className = "WedgePart",
            properties = {
                Anchored = true,
                Size = { roofT, height, math.abs(vdot(ab, back)) },
                CFrame = Spec.cframe(vmid(a, b), rotAxes(right, up, back)),
                Color = palette.slateTile,
                Material = "Slate",
                MaterialVariant = "SlateTile",
            },
        })
        table.insert(children, {
            name = `{name}_2`,
            className = "WedgePart",
            properties = {
                Anchored = true,
                Size = { roofT, height, math.abs(vdot(ac, back)) },
                CFrame = Spec.cframe(vmid(a, c), rotAxes(nr, up, nb)),
                Color = palette.slateTile,
                Material = "Slate",
                MaterialVariant = "SlateTile",
            },
        })
    end
    for i = 1, 4 do
        triFace(`RoofFace{i}`, apex, corners[i], corners[i % 4 + 1])
    end

    -- hip stringers: frame apex → each frame corner, outer end trimmed 1
    for i, fc in fcorners do
        local dir = vunit(vsub(fc, fApex))
        local trimmed = { fc[1] - dir[1], fc[2] - dir[2], fc[3] - dir[3] }
        local sp, slen, srot = Spec.segment(fApex, trimmed)
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
            local zt = math.abs(x)
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
