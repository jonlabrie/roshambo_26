--!strict
-- Myōjin torii standing on the Overlook deck's western edge — the threshold between the deck a
-- player spawns on and the arena square they walk out into.
--
-- MYŌJIN, not shinmei: curved kasagi over a straight shimaki, a nuki that passes THROUGH the
-- pillars and protrudes, and a gakuzuka strut between them. That is the form that is painted
-- shu-iro; shinmei is the plain unpainted one, and we have a red cypress now.
--
-- IT STANDS ON THE DECK, not on the ground. West of the deck the terrain falls away fast —
-- measured 2026-08-14 along the approach, the ground drops from 112.6 at x52 to 109.7 at x57, and
-- the two footings would differ by up to 1.7 studs across the gate line. The deck is a built
-- platform at a known 113.30, so the pillars stand on it and the problem disappears.
local Spec = require("./Spec")

local Torii = {}

function Torii.build(palette: any, L: any): Spec.PartSpec
    local T = L.toriiGate
    local children: { Spec.PartSpec } = {}
    local red = palette.cypressVermilion
    local ink = palette.ink
    local cx, floorY, cz = T.pos[1], T.pos[2], T.pos[3]
    local half = T.span / 2

    -- `round` is not optional decoration. Spec.ROT.CYL_VERTICAL only RE-AIMS a cylinder's long
    -- axis; it does not make a part a cylinder. Applying it without Shape leaves a box standing on
    -- end — which is what the pillars were until the owner said "the posts should be round".
    local function timber(
        name: string,
        size: { number },
        pos: { number },
        rot: { number }?,
        colour: { number }?,
        round: boolean?
    )
        local props: { [string]: any } = {
            Size = size,
            CFrame = Spec.cframe(pos, rot),
            Color = colour or red,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        }
        if round then
            props.Shape = "Cylinder"
        end
        table.insert(children, Spec.part(name, props))
    end

    -- ===== the heights, all derived downward from the top so the kasagi lands on T.height =====
    local topY = floorY + T.height
    local KASAGI_T, SHIMAKI_T = 0.8, 0.9
    local kasagiMidY = topY - KASAGI_T / 2
    local shimakiTopY = topY - KASAGI_T
    local shimakiMidY = shimakiTopY - SHIMAKI_T / 2
    local pillarTopY = shimakiTopY - SHIMAKI_T -- the pillars carry the shimaki
    local pillarH = pillarTopY - floorY

    -- ===== pillars =====
    -- Cylinders, so they keep CypressWeathered without argument: a round member's normals sweep
    -- through every direction and the world-space projections blend, which is why the pavilion's
    -- own logs never needed the rotated variant. The horizontal members below are the ones with
    -- a grain problem — see the note on the nuki.
    for _, p in { { "North", cz - half }, { "South", cz + half } } do
        local nm, pz = p[1] :: string, p[2] :: number
        timber(
            `Pillar{nm}`,
            { pillarH, T.pillarD, T.pillarD },
            { cx, floorY + pillarH / 2, pz },
            Spec.ROT.CYL_VERTICAL,
            nil,
            true
        )
        -- nemaki: the black wrapped base every vermilion torii has, and the joint that hides the
        -- pillar meeting the deck rather than letting two faces argue about it
        timber(
            `Nemaki{nm}`,
            { T.nemakiH, T.pillarD + 0.18, T.pillarD + 0.18 },
            { cx, floorY + T.nemakiH / 2, pz },
            Spec.ROT.CYL_VERTICAL,
            ink,
            true
        )
    end

    -- ===== nuki: the tie beam, passing through both pillars and protruding =====
    -- HUNG A FIXED GAP UNDER THE SHIMAKI, not at a fraction of the pillar height (owner: three
    -- studs below the upper beam). As a fraction, the gap the eye actually reads — the one the
    -- gakuzuka fills — moved whenever the gate's overall height changed.
    --
    -- Its SOFFIT is the one face here whose grain runs across rather than along: a Z-running
    -- horizontal member gets grain along Z on its sides and along X top and bottom, because the
    -- cypress maps project from world axes. Left plain until it has been looked at from
    -- underneath, rather than pre-emptively adding boards to fix what may not read at this height.
    -- ONE LENGTH FOR BOTH LINTELS (owner: match the nuki to the shimaki above it). Computed once
    -- and used twice, so they are the same number rather than two numbers that happen to agree.
    local lintelLen = T.span + 2 * T.shimakiOut
    local nukiTopY = pillarTopY - T.nukiGap
    local nukiY = nukiTopY - T.nukiH / 2
    timber("Nuki", { T.nukiW, T.nukiH, lintelLen }, { cx, nukiY, cz })
    -- kusabi: the wedges pinning the nuki where it emerges. Small, dark, and the reason the
    -- protrusion reads as joinery rather than as a beam sticking out.
    --
    -- POSITIONED FROM THE PILLAR FACE, NOT FROM THE BEAM'S LENGTH. They were a fraction of the
    -- overhang, so lengthening the nuki slid them outboard with it and left them stranded in the
    -- middle of the protrusion with nothing to pin. A wedge belongs to the JOINT; it does not care
    -- how far the beam runs past it. Tucked slightly INTO the pillar so it reads as driven home
    -- rather than resting against the face.
    local KUSABI_W, KUSABI_TUCK = 0.3, 0.06
    local kusabiOut = T.pillarD / 2 + KUSABI_W / 2 - KUSABI_TUCK
    for _, s in { { "North", cz - half - kusabiOut }, { "South", cz + half + kusabiOut } } do
        timber(
            `Kusabi{s[1]}`,
            { T.nukiW + 0.12, T.nukiH * 0.5, KUSABI_W },
            { cx, nukiY, s[2] :: number },
            nil,
            ink
        )
    end

    -- ===== the seichū bar =====
    -- 正中 — the gate's centre line — is the kami's path; visitors keep to the sides and pass
    -- through off-centre. This is that custom made literal: an invisible barrier closing the
    -- middle of the opening, so a player has to choose a side.
    --
    -- EngawaBarrier, not Default. That group is registered in the place and collides with players
    -- while passing Projectile — so it stops people and lets fireworks through, which matters
    -- with the Overlook right behind it. Verified against PhysicsService rather than assumed.
    --
    -- It runs the whole way INTO the nuki rather than stopping under it: a gap would let a player
    -- squeeze over the top, and stopping flush would leave them a ledge to stand on.
    local barLo, barHi = floorY, nukiTopY
    table.insert(
        children,
        Spec.part("SeichuBar", {
            Size = { T.beamW, barHi - barLo, T.seichuW },
            CFrame = Spec.cframe({ cx, (barLo + barHi) / 2, cz }),
            Transparency = 1,
            CanCollide = true,
            CollisionGroup = "EngawaBarrier",
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )

    -- ===== gakuzuka: the central strut between nuki and shimaki =====
    local gLo, gHi = nukiTopY, pillarTopY
    timber("Gakuzuka", { T.nukiW * 0.85, gHi - gLo, 1.0 }, { cx, (gLo + gHi) / 2, cz })

    -- ===== shimaki: straight, seated on the pillar heads =====
    timber("Shimaki", { T.beamW, SHIMAKI_T, lintelLen }, { cx, shimakiMidY, cz })

    -- ===== kasagi: the curved lintel, and its black cap =====
    -- The upturn is what makes it myōjin, and a box cannot bend — so the curve is sampled as a
    -- shallow parabola and emitted as straight segments between the samples.
    --
    -- THE CAP IS BLACK (owner, with Fushimi Inari): the top member of a vermilion torii is capped
    -- dark. It also happens to cover the one face of a Z-running beam whose grain runs across it,
    -- which is the kerb's capping board arriving by a different route. Emitted from the SAME
    -- curve rather than a second set of numbers, and made wider and longer than the kasagi so no
    -- edge of it lands coplanar with the timber underneath.
    local segs = T.kasagiSegments
    local kHalf = T.span / 2 + T.kasagiOut
    local function curve(
        prefix: string,
        thick: number,
        width: number,
        yOff: number,
        colour: { number },
        grow: number
    )
        local function at(tt: number): { number }
            return { cx, kasagiMidY + T.kasagiRise * tt * tt + yOff, cz + (kHalf + grow) * tt }
        end
        for i = 0, segs - 1 do
            local pos, len, rot = Spec.segment(at(-1 + 2 * (i / segs)), at(-1 + 2 * ((i + 1) / segs)))
            -- +0.02 of overlap per segment: butted end faces at these angles leave a visible seam,
            -- and the joint is 14 studs up where nobody can nudge it later.
            timber(`{prefix}{i + 1}`, { len + 0.02, thick, width }, pos, rot, colour)
        end
    end
    curve("Kasagi", KASAGI_T, T.beamW * 1.15, 0, red, 0)
    curve("KasagiCap", T.kasagiCapT, T.beamW * 1.15 + 0.22, (KASAGI_T + T.kasagiCapT) / 2, ink, 0.25)

    return Spec.model("Torii", children)
end

return Torii
