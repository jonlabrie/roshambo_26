--!strict
-- Per-shop spec tables for the Machiya archetype (design spec
-- docs/superpowers/specs/2026-08-15-machiya-row-design.md). EVERY envelope here is
-- the OWNER'S, measured from a holdout/massing block in Studio and read back as
-- literals. Do not re-derive them from anything.
local Spec = require("./Spec")

local MachiyaShops = {}

export type Shop = {
    name: string,
    envelope: { x0: number, x1: number, z0: number, z1: number, floorY: number },
    yaw: number,
    frontage: "open" | "koshi",
    interior: "full" | "shallow" | "none",
    storeys: { ground: number, upper: number }?,
    identity: { [string]: any }?,
}

-- 花火屋 — measured from the holdout the owner placed 2026-08-05; front deepened
-- z44 -> z36 at the owner's direction 2026-08-13. See Machiya.luau's history notes.
MachiyaShops.hanabiya = {
    name = "Hanabiya",
    envelope = { x0 = -1.67, x1 = 16.26, z0 = 36.00, z1 = 52.00, floorY = 113.10 },
    yaw = 0,
    frontage = "open",
    interior = "full",
} :: Shop

-- ===== 2026-08-15 survey — merchant row =====
-- Read live from game.ServerStorage.Sandbox_PARKED.MerchantMassing (Studio MCP,
-- datamodel Edit). Envelope x0/x1/z0/z1 = pivot +/- GetExtentsSize()/2 in the
-- LOCAL frame (yaw applied separately by shop.yaw, per Machiya.luau's final rotation
-- pass — Task 3). floorY probes: 8-point footing ring (4 corners + 4 edge
-- midpoints), raycast from pivotY+40 straight down 80 studs, RaycastParams
-- Include-filtered to workspace.Terrain only. North (-Z, lower world Z) is the
-- FRONTAGE/promenade side in every south-row shell, matching 花火屋's Z0; south
-- (+Z) runs into the terrain cut, same as 花火屋's "back is fixed" note — so
-- floorY is taken from the FRONT probes only (NW/NE/N_mid), the highest of the
-- three, which is what keeps a raised slab from dipping below its own street
-- edge. Back-probe scatter is real canyon grade into the cut, not a floor
-- disagreement, and is NOT averaged into floorY.
--
-- ENVELOPE DEPTH TENSION (flagged, not resolved here): every one of these massing
-- blocks is 13.24 studs deep in z, the same depth 花火屋's own holdout sibling
-- was before the owner deepened its envelope to 16 (z44->z36, 2026-08-13, "the
-- shop held about three people"). The archetype wants frontage clearance +
-- COUNTER_STANDOFF (4.4) + working room behind the counter; at 13.24 these three
-- envelopes read just as tight as 花火屋's pre-gate one did. Recorded here as the
-- owner's literal measurement, not re-derived — the owner corrects it at the gate
-- if it should deepen the same way.

-- Machiya_1 -> APPAREL. pivot(-10.06,120.91,41.85) size(24.72,17.92,13.24) yawDeg
-- 0.00. Footing ring (Terrain-filtered raycast, all hit Sand):
--   NW(-22.42,35.23) 113.30  NE(2.30,35.23) 112.53  N_mid(-10.06,35.23) 112.97
--   SW(-22.42,48.48) 121.08  SE(2.30,48.48) 111.82  S_mid(-10.06,48.48) 115.46
--   W_mid(-22.42,41.85) 115.22  E_mid(2.30,41.85) 112.31
-- Front spread (NW/NE/N_mid) 0.77 studs -- consistent, no concern. floorY = the
-- front's highest hit, 113.30 -- reads on the same promenade grade as 花火屋's
-- 113.10. Back spread is 9.26 (111.82 to 121.08): the south edge climbs into the
-- terrain cut, unevenly -- matches the pattern, not treated as a floor problem.
-- AS-BUILT OVERRIDES — the owner hand-rotated and moved BOTH kimono racks into
-- the corners in Studio on 2026-08-15 ("the racks were sort of in the way so
-- I've rotated them and moved them into the corners"): the round-2 splayed pair
-- blocked the floor. These are READ-BACK numbers from the live place (Edit
-- datamodel), not proposals — do not re-derive them, and do NOT symmetrize
-- them: the two yaws are not mirror images because this is free-hand placement.
-- Same pattern as the path builders' terminusRock/steps.ranges: data a builder
-- cannot re-derive is stored, everything else stays derived. `rel` is the
-- RAIL-CENTRE offset from the ENVELOPE CENTRE (cx, cz), so an envelope nudge
-- carries the racks with it; the rack internals (posts at ±span/2 along the
-- rail, cloths spaced between them, all sizes) are still derived and were
-- verified to land on the owner's per-part reads within 0.001.
local APPAREL_RACK_OVERRIDES = {
    { name = "KimonoRackWest", rel = { -6.786, -2.407 }, yaw = -105.86 },
    { name = "KimonoRackEast", rel = { 6.451, -3.394 }, yaw = 129.97 },
}

-- EAST EDGE RE-REGISTERED AT THE ROUND-1 GATE: the massing block's surveyed
-- x1 = 2.30 was STALE against the built neighbour — it ran ~3.97 studs into
-- 花火屋 (west face x = -1.67). The block predates the built shop, and the
-- standing rule is to register to the BUILT edge, not the survey
-- (derive-from-what-it-touches): x1 = -1.67 - 1.5 = -3.17, a 1.5-stud roji —
-- the narrow alley between row houses — which also keeps the two shells' side
-- walls off a shared plane (coplanar-face flicker). x0/z/floorY stay surveyed.
MachiyaShops.apparel = {
    name = "MachiyaApparel",
    envelope = { x0 = -22.42, x1 = -3.17, z0 = 35.23, z1 = 48.48, floorY = 113.30 },
    yaw = 0,
    frontage = "open",
    interior = "shallow",
    identity = {
        -- Deep indigo, the traditional apparel-shop noren. NOT from ZenDojo.palette: its only
        -- blue is `water` { 0.20, 0.35, 0.43 }, a mid teal, not a deep blue — so this is the
        -- design brief's fallback literal, held here for the owner to retune at the gate.
        noren = { color = { 0.16, 0.18, 0.32 }, segments = 5 },
        -- Pale indigo chōchin — RHYMES with the noren above rather than matching it: the noren
        -- is deep so it reads as cloth, but the paper barrel must stay light or the RoundLantern
        -- glyph (the World Throw) loses contrast against it at night, which is the lantern's
        -- actual job. 0-255 units, same as the Studio tool's own PAPER literal — see
        -- Chochin.build's paperRGB255 doc comment. Chochin.spec.luau's legibility guard holds
        -- this (and every other shop tint) to a 0.55 luminance floor.
        chochin = { paper = { 170, 178, 200 } },
        -- 袖看板 (owner's signage pass, 2026-08-15): the blade sign standing
        -- perpendicular to the facade at the WEST end of the frontage — the row's
        -- approach side, and the far corner from 花火屋's roji — lettered 呉服屋
        -- (gofukuya, the draper) top-to-bottom on both faces. Panel and ink are
        -- the classic high-end gofukuya pairing and deliberately the row's
        -- inversion: BLACK LACQUER carrying GOLD, where 花火屋 is sumi on cream
        -- plaster — light-on-dark against dark-on-light, so the two signs can
        -- never read as copies. Gold is the palette's own { 0.83, 0.69, 0.40 };
        -- the lacquer is a literal (no palette black is this deep) on
        -- SmoothPlastic, which is as close to urushi gloss as base materials get.
        board = {
            kind = "blade",
            text = "呉服屋",
            vertical = true,
            side = "west",
            panel = { color = { 0.09, 0.08, 0.08 }, material = "SmoothPlastic" },
            ink = { color = { 0.83, 0.69, 0.40 } },
        },
        glow = { color = { 1.0, 0.85, 0.6 }, brightness = 1.2 },
        dress = function(ctx: any): { any }
            local env, palette = ctx.env, ctx.palette
            local FLOOR = env.floorY
            local out: { any } = {}

            -- WallBack's INNER face: STUCCO_SETBACK 0.30 + WALL_T 0.5 off z1, the
            -- archetype's own planes — the shelf registers to the BUILT wall, not to the
            -- envelope (docs/wiki/practice/roblox-walls-register-to-structure).
            local wallInnerZ = env.z1 - 0.8
            -- The customer floor's shared lines: counter centre at 花火屋's 4.4 standoff
            -- (COUNTER_STANDOFF, measured to the CENTRE, exactly as Machiya.luau does it),
            -- table midway between the frontage clearance line (z0 + 1.2) and the
            -- counter's front face.
            local counterZ = env.z1 - 4.4
            local tableZ = ((env.z0 + 1.2) + (counterZ - 1.0)) / 2

            -- ----- the kimono racks: AS-BUILT, the owner's hand placement -----
            -- Emitted at APPAREL_RACK_OVERRIDES' rail centres and yaws (see that table's
            -- comment: read-back 2026-08-15, do not re-derive). Only the placement is
            -- owner data — the members are still derived from the rack's own span: posts
            -- at ±span/2 along the rail, two ~1.95 cloths between them (0.1 apart, 0.05
            -- to each post). Rail and cloth stay non-colliding; the posts collide,
            -- furniture you walk around. Rotation goes through Spec.rotY/rotYMat only —
            -- the arch-stable helpers.
            local POST = 0.3
            local POST_H = 5.5
            local RACK_SPAN = 4.4 -- post centre to centre: two ~1.95-wide cloths' worth
            local CLOTH_W = (RACK_SPAN - 0.5) / 2 -- 0.1 between cloths, 0.05 to each post
            for ri, rk in APPAREL_RACK_OVERRIDES do
                local rcx = env.cx + rk.rel[1]
                local rcz = env.cz + rk.rel[2]
                local rot = Spec.rotYMat(rk.yaw)
                -- world position of a point dx along the rack's own long axis
                local function at(dx: number, y: number): { number }
                    local o = Spec.rotY({ dx, 0, 0 }, rk.yaw)
                    return { rcx + o[1], y, rcz + o[3] }
                end
                local kids: { any } = {}
                for _, pside in { { "W", -1 }, { "E", 1 } } do
                    table.insert(
                        kids,
                        Spec.part(`RackPost{pside[1]}`, {
                            Size = { POST, POST_H, POST },
                            CFrame = Spec.cframe(
                                at((pside[2] :: number) * RACK_SPAN / 2, FLOOR + POST_H / 2),
                                rot
                            ),
                            Color = palette.timber,
                            Material = "Wood",
                        })
                    )
                end
                -- rail ends flush with the post OUTER faces; top flush with the post tops
                table.insert(
                    kids,
                    Spec.part("RackRail", {
                        Size = { RACK_SPAN + POST, 0.2, 0.2 },
                        CFrame = Spec.cframe(at(0, FLOOR + POST_H - 0.1), rot),
                        Color = palette.timber,
                        Material = "Wood",
                        CanCollide = false, -- at 5.4 it would clothesline a 6-stud avatar
                        CanQuery = false,
                        CanTouch = false,
                    })
                )
                local cOff = ri - 1 -- mirror the colour order between the two racks
                for i = 1, 2 do
                    -- hem 1.5 off the floor: hung cloth, not a curtain wall
                    table.insert(
                        kids,
                        Spec.part(`RackCloth_{i}`, {
                            Size = { CLOTH_W, 3.8, 0.15 },
                            CFrame = Spec.cframe(at((i - 1.5) * (CLOTH_W + 0.1), FLOOR + 3.4), rot),
                            Color = if (i + cOff) % 2 == 1 then palette.vermilion else palette.water,
                            Material = "Fabric",
                            CanCollide = false,
                            CanQuery = false,
                            CanTouch = false,
                        })
                    )
                end
                table.insert(out, Spec.model(rk.name, kids))
            end

            -- ----- the counter: 花火屋's rule, 花火屋's number -----
            -- COUNTER_H from the archetype's consts; 2.0 deep; 60% of the envelope width.
            local counterW = env.w * 0.6
            table.insert(
                out,
                Spec.part("Counter", {
                    Size = { counterW, ctx.consts.COUNTER_H, 2.0 },
                    CFrame = Spec.cframe({ env.cx, FLOOR + ctx.consts.COUNTER_H / 2, counterZ }),
                    Color = palette.timber,
                    Material = "Wood",
                })
            )

            -- ----- the fold table, mid-floor -----
            -- Mid-CUSTOMER-floor at the hoisted tableZ, not the envelope's cz (which
            -- sits 1.2 off the counter — a table there pokes into it).
            local TOP_T = 0.2
            local tKids: { any } = {}
            table.insert(
                tKids,
                Spec.part("TableTop", {
                    Size = { 4.0, TOP_T, 2.6 },
                    CFrame = Spec.cframe({ env.cx, FLOOR + 2.5 - TOP_T / 2, tableZ }),
                    Color = palette.timber,
                    Material = "Wood",
                })
            )
            local LEG = 0.25
            local legH = 2.5 - TOP_T
            for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
                -- leg outer faces flush with the top's edges (flush-outside-edges)
                table.insert(
                    tKids,
                    Spec.part(`TableLeg_{corner[1]}_{corner[2]}`, {
                        Size = { LEG, legH, LEG },
                        CFrame = Spec.cframe({
                            env.cx + corner[1] * (2.0 - LEG / 2),
                            FLOOR + legH / 2,
                            tableZ + corner[2] * (1.3 - LEG / 2),
                        }),
                        Color = palette.timber,
                        Material = "Wood",
                    })
                )
            end
            for i, st in { { -1.35, 0.45 }, { 0.0, -0.35 }, { 1.35, 0.25 } } do
                table.insert(
                    tKids,
                    Spec.part(`FoldedCloth_{i}`, {
                        Size = { 0.9, 0.5, 0.6 },
                        CFrame = Spec.cframe({ env.cx + st[1], FLOOR + 2.5 + 0.25, tableZ + st[2] }),
                        Color = if i % 2 == 1 then palette.vermilion else palette.water,
                        Material = "Fabric",
                    })
                )
            end
            table.insert(out, Spec.model("FoldTable", tKids))

            -- ----- the rear shelf, full counter width, back face ON the wall's inner face -----
            local SHELF_D = 1.2
            local shelfZ = wallInnerZ - SHELF_D / 2
            local sKids: { any } = {}
            table.insert(
                sKids,
                Spec.part("ShelfBoard", {
                    Size = { counterW, 0.4, SHELF_D },
                    CFrame = Spec.cframe({ env.cx, FLOOR + 5.5, shelfZ }),
                    Color = palette.timber,
                    Material = "Wood",
                })
            )
            -- two brackets under it, against the wall — a board 5.5 up with nothing holding
            -- it reads as a floater
            for _, side in { -1, 1 } do
                table.insert(
                    sKids,
                    Spec.part(`ShelfBracket_{side}`, {
                        Size = { 0.3, 0.3, 1.0 },
                        CFrame = Spec.cframe({
                            env.cx + side * (counterW / 2 - 0.7),
                            FLOOR + 5.5 - 0.2 - 0.15,
                            wallInnerZ - 0.5,
                        }),
                        Color = palette.timber,
                        Material = "Wood",
                    })
                )
            end
            for i = 1, 5 do
                table.insert(
                    sKids,
                    Spec.part(`ClothBolt_{i}`, {
                        Size = { 0.8, 0.8, 0.8 },
                        CFrame = Spec.cframe({
                            env.cx + (i - 3) * (counterW - 1.0) / 5,
                            FLOOR + 5.5 + 0.2 + 0.4,
                            shelfZ,
                        }),
                        Color = if i == 3
                            then palette.gold
                            elseif i % 2 == 1 then palette.vermilion
                            else palette.water,
                        Material = "Fabric",
                    })
                )
            end
            table.insert(out, Spec.model("RearShelf", sKids))

            return out
        end,
    },
} :: Shop

-- ===== RESERVED CHOCHIN PALETTE for the shops not yet built (Tasks 5-7) =====
-- The owner's rule: paths and canyon-wide lanterns stay uniform (they're the wayfinding
-- system, gate-tuned) — the merchant row varies, because shops advertising themselves is what a
-- merchant street is. Every tint is `identity.chochin = { paper = {r, g, b} }`, 0-255 units
-- (Chochin.build's paperRGB255 doc comment), and must clear Chochin.LEGIBILITY_FLOOR (0.55
-- luminance) so the RoundLantern glyph — the World Throw — still reads at night. Recorded here
-- so Tasks 5-7 don't each invent a palette independently:
--   accessories -> a light moss/green-grey (not yet chosen; pick something that reads as
--     "accessories" without drifting toward apparel's indigo or chaya's russet)
--   chaya (the tea stand, Task 7) -> warm persimmon/russet, keeping the tea-house register warm
--   花火屋 (Hanabiya) -> stays canonical cream (Chochin.PAPER, no override) — it's the anchor
--     the rest of the row is read against, not one more variant
-- True red (赤提灯, akachōchin) is deliberately NOT used anywhere on this row: it conventionally
-- signals an izakaya, and none of these shops are one.

-- Machiya_4 -> ACCESSORIES. pivot(24.34,119.59,42.96) size(16.63,14.92,13.24)
-- yawDeg 0.00. Footing ring (Sand on the front/sides, Slate on the back):
--   NW(16.02,36.34) 112.03  NE(32.65,36.34) 113.14  N_mid(24.34,36.34) 113.21
--   SW(16.02,49.59) 111.59  SE(32.65,49.59) 114.99  S_mid(24.34,49.59) 120.24
--   W_mid(16.02,42.96) 112.29  E_mid(32.65,42.96) 113.94
-- Front spread 1.18 studs -- under the 1.5 flag threshold but the widest of the
-- three shells; recorded, not smoothed. floorY = the front's highest hit, 113.21.
-- Back spread 8.65 (111.59 to 120.24), again reading as the cut, not the floor.
--
-- WEST EDGE RE-REGISTERED (same stale-massing class the apparel gate caught,
-- mirrored): the massing block's surveyed x0 = 16.02 was STALE against the built
-- neighbour — it ran 0.24 studs into 花火屋 (east face x = 16.26). The block
-- predates the built shop, and the standing rule is to register to the BUILT
-- edge, not the survey (derive-from-what-it-touches): x0 = 16.26 + 1.5 = 17.76,
-- the same 1.5-stud roji as apparel's west side — which also keeps the two
-- shells' side walls off a shared plane (coplanar-face flicker). x1/z/floorY
-- stay surveyed.
MachiyaShops.accessories = {
    name = "MachiyaAccessories",
    envelope = { x0 = 17.76, x1 = 32.65, z0 = 36.34, z1 = 49.58, floorY = 113.21 },
    yaw = 0,
    frontage = "open",
    interior = "shallow",
    identity = {
        -- Prussian navy (owner's round-1 gate correction: dark blue, two wide panels
        -- per door). Chosen AGAINST the neighbour: apparel's indigo {0.16, 0.18, 0.32}
        -- leans violet because its red sits nearly at its green — this keeps the blue
        -- channel at apparel's 0.32 but halves the red (0.16 -> 0.07), which kills the
        -- violet lean, and drops luminance 0.186 -> 0.145 so it reads deeper at a
        -- glance. Side-by-side same-family risk is the owner's in-situ judgement call.
        -- perBay = 2: two wider panels per doorway (the archetype's default is 3);
        -- segments is the vertical drape chain, a different axis, unchanged at 4.
        noren = { color = { 0.07, 0.15, 0.32 }, segments = 4, perBay = 2 },
        -- Light moss / green-grey paper — the tint reserved for accessories in the
        -- palette note above. Rec. 709 luminance 0.688 (0.2126*168 + 0.7152*180 +
        -- 0.0722*152, /255), the same level as canonical cream's 0.684 and well clear
        -- of Chochin.LEGIBILITY_FLOOR (0.55); Chochin.spec's guard walks this table.
        chochin = { paper = { 168, 180, 152 } },
        -- 掛看板 (owner's signage pass, 2026-08-15): a plaque hung under the eave
        -- on visible hooks, lettered 小間物屋 (komamonoya, the sundries/notions
        -- shop). BARE CEDAR carrying SUMI — the palette's cypressWeathered over
        -- the same CypressWeathered maps the bridge decking wears (the unrotated
        -- variant: this is a horizontal board, and CypressVertical's rotated
        -- grain would run across it), with the palette's own ink. Third
        -- silhouette, third ground: cream plaster (花火屋), black lacquer
        -- (apparel), bare timber (here) — the owner's "all the same background"
        -- complaint answered with materials, not tints.
        board = {
            kind = "hanging",
            text = "小間物屋",
            panel = { color = { 0.85, 0.84, 0.81 }, material = "Wood", variant = "CypressWeathered" },
            ink = { color = { 0.18, 0.19, 0.22 } },
        },
        glow = { color = { 1.0, 0.85, 0.6 }, brightness = 1.2 },
        -- THE MINIATURES ARE THE POINT OF THIS SHOP: shelf-scale previews of the
        -- Piece B decoration catalog, built from primitives following the real
        -- builders' silhouettes (StoneLantern.luau's base/post/firebox/cap stack,
        -- scaled ~1.6/4.95). Everything derives from ctx.env — no world literals.
        dress = function(ctx: any): { any }
            local env, palette = ctx.env, ctx.palette
            local FLOOR = env.floorY
            local out: { any } = {}

            -- The archetype's own planes (walls-register-to-structure): a wall's
            -- INNER face sits STUCCO_SETBACK 0.30 + WALL_T 0.5 inside the envelope.
            local wallInnerW = env.x0 + 0.8
            local wallInnerE = env.x1 - 0.8
            local wallInnerBackZ = env.z1 - 0.8
            -- counter centre at 花火屋's 4.4 standoff (COUNTER_STANDOFF, measured to
            -- the CENTRE, exactly as Machiya.luau does it)
            local counterZ = env.z1 - 4.4

            -- ----- miniature builders: the Piece B catalog, in primitives -----
            -- Ishidōrō form per StoneLantern.luau (base disc / shaft / firebox cube /
            -- cap disc, cap wider than base), as stacked cylinders + one cube. `s`
            -- carries the four member dims; shelf minis are non-colliding merchandise
            -- (54 shelf parts would be waste physics), the plinth hero collides.
            local function miniLantern(
                name: string,
                x: number,
                y: number,
                z: number,
                s: any,
                solid: boolean?
            ): any
                local phys = if solid
                    then {}
                    else { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
                local function cyl(nm: string, d: number, h: number, cy: number, color: { number })
                    local p: { [string]: any } = {
                        Shape = "Cylinder",
                        Size = { h, d, d },
                        CFrame = Spec.cframe({ x, cy, z }, Spec.ROT.CYL_VERTICAL),
                        Color = color,
                        Material = "Slate",
                    }
                    for k, v in phys do
                        p[k] = v
                    end
                    return Spec.part(nm, p)
                end
                local baseTop = y + s.base[2]
                local shaftTop = baseTop + s.shaft[2]
                local boxTop = shaftTop + s.box
                local boxProps: { [string]: any } = {
                    Size = { s.box, s.box, s.box },
                    CFrame = Spec.cframe({ x, shaftTop + s.box / 2, z }),
                    Color = palette.gold,
                    Material = "Neon",
                    Transparency = 0.2,
                    children = if solid
                        then {
                            {
                                name = "Glow",
                                className = "PointLight",
                                properties = {
                                    Brightness = 0.6,
                                    Range = 10,
                                    Color = { 0.9, 0.75, 0.45 },
                                    Shadows = false,
                                },
                            },
                        }
                        else nil,
                }
                for k, v in phys do
                    boxProps[k] = v
                end
                return Spec.model(name, {
                    cyl("Base", s.base[1], s.base[2], y + s.base[2] / 2, palette.gravel),
                    cyl("Shaft", s.shaft[1], s.shaft[2], baseTop + s.shaft[2] / 2, palette.gravel),
                    Spec.part("Firebox", boxProps),
                    cyl("Cap", s.cap[1], s.cap[2], boxTop + s.cap[2] / 2, palette.gravel),
                })
            end
            -- shelf mini, 1.6 tall (brief dims); `squat` trims the shaft to 1.5 total
            -- where the next board up leaves only 1.6 clear (thin it, never push through)
            local function lanternDims(squat: boolean)
                return {
                    base = { 0.9, 0.25 },
                    shaft = { 0.3, if squat then 0.5 else 0.6 },
                    box = 0.55,
                    cap = { 1.0, 0.2 },
                }
            end

            -- ----- the two shelf walls: three boards each on the side walls -----
            -- Boards register to the BUILT side walls (back face ON the inner face) and
            -- run the CUSTOMER floor only: clear of the frontage's parked door leaves
            -- (deepest frontage timber lives inside z0 + 1.3) and stopping shy of the
            -- counter's front face — running past it would pinch the staff channel
            -- around the counter's end from 2.18 to under 1 stud.
            local SHELF_D = 1.2
            local BOARD_T = 0.4
            local shelfZ0 = env.z0 + 1.45
            local shelfZ1 = counterZ - 1.05
            local shelfLen = shelfZ1 - shelfZ0
            local shelfCZ = (shelfZ0 + shelfZ1) / 2
            local half = shelfLen / 2
            local TIER_STEP = 2.0 -- board centres 2.2 / 4.2 / 6.2 above the floor
            -- The unit's support: two vertical FRONT standards per wall (floor to the
            -- top board's top), front faces flush with the board fronts
            -- (flush-outside-edges); the wall itself carries the back edge. Boards run
            -- THROUGH the standards at their ends — the mortise read, same intentional
            -- joinery class as apparel's rail-through-post. Nothing hangs below a
            -- board, so the tier headroom is the honest 1.6.
            local STD = 0.3
            local STD_H = 6.2 + BOARD_T / 2 -- top board's top
            -- per-shelf stock line, offsets from the shelf's z-centre (mirrored on
            -- alternating tiers so the two walls don't read as copy-paste):
            -- lantern A / three rolled flags / lantern B / folding-screen pair.
            -- stockLimit keeps everything 0.05 clear of the standards' inner faces;
            -- the line is packed (~0.05 gaps) — a stocked shelf, not a sparse one.
            local stockLimit = half - STD - 0.05
            local T_LANT_A = -(stockLimit - 0.55) -- 0.5 cap radius + 0.05 end margin
            local T_FLAGS = { T_LANT_A + 0.70, T_LANT_A + 1.04, T_LANT_A + 1.38 }
            local T_LANT_B = T_LANT_A + 2.08
            local T_HINGE = T_LANT_A + 3.81 -- pair spans hinge ± ~1.18

            for wi, wall in { { "West", wallInnerW, 1 }, { "East", wallInnerE, -1 } } do
                local wname, innerX, dxSign = wall[1] :: string, wall[2] :: number, wall[3] :: number
                local boardX = innerX + dxSign * SHELF_D / 2
                local kids: { any } = {}
                for _, sside in { -1, 1 } do
                    table.insert(
                        kids,
                        Spec.part(`ShelfStandard_{sside}`, {
                            Size = { STD, STD_H, STD },
                            CFrame = Spec.cframe({
                                boardX + dxSign * (SHELF_D / 2 - STD / 2),
                                FLOOR + STD_H / 2,
                                shelfCZ + sside * (half - STD / 2),
                            }),
                            Color = palette.timber,
                            Material = "Wood",
                        })
                    )
                end
                for tier = 1, 3 do
                    local boardY = FLOOR + 2.2 + (tier - 1) * TIER_STEP
                    local surface = boardY + BOARD_T / 2
                    -- headroom to the next board up bounds this tier's stock; the top
                    -- tier is open to the storey and carries the full-height pieces
                    local budget = if tier < 3 then TIER_STEP - BOARD_T - 0.1 else 1.8
                    table.insert(
                        kids,
                        Spec.part(`ShelfBoard_{tier}`, {
                            Size = { SHELF_D, BOARD_T, shelfLen },
                            CFrame = Spec.cframe({ boardX, boardY, shelfCZ }),
                            Color = palette.timber,
                            Material = "Wood",
                        })
                    )
                    -- mirror the stock line on alternating tiers/walls
                    local m = if (tier + wi) % 2 == 0 then 1 else -1
                    local squat = budget < 1.6
                    for li, lt in { { "A", T_LANT_A }, { "B", T_LANT_B } } do
                        table.insert(
                            kids,
                            miniLantern(
                                `MiniLantern_{tier}_{li}`,
                                boardX,
                                surface,
                                shelfCZ + m * (lt[2] :: number),
                                lanternDims(squat)
                            )
                        )
                    end
                    for fi, ft in T_FLAGS do
                        table.insert(
                            kids,
                            Spec.part(`RolledFlag_{tier}_{fi}`, {
                                Shape = "Cylinder",
                                Size = { 1.4, 0.3, 0.3 },
                                CFrame = Spec.cframe({
                                    boardX + ({ -0.2, 0.0, 0.2 })[fi],
                                    surface + 0.7,
                                    shelfCZ + m * ft,
                                }, Spec.ROT.CYL_VERTICAL),
                                Color = ({ palette.vermilion, palette.gold, palette.water })[(fi + tier) % 3 + 1],
                                Material = "Fabric",
                                CanCollide = false,
                                CanQuery = false,
                                CanTouch = false,
                                CastShadow = false,
                            })
                        )
                    end
                    -- the folding screen: two slabs standing in a 15-degree V, hinge
                    -- edge toward the wall, opening toward the shopper — the way a
                    -- two-panel byoubu actually stands. Offsets route through
                    -- Spec.rotY/rotYMat only (arch-stable trig). The leaves' mid-plane
                    -- edge lines COINCIDE at the fold, so the two 0.08 thicknesses
                    -- interpenetrate <=0.04 there — the hinge knuckle, intentional
                    -- joinery (apparel's rail-through-post class).
                    local scrH = math.min(1.8, budget)
                    local hingeX = boardX - dxSign * 0.25
                    local hingeZ = shelfCZ + m * T_HINGE
                    for si, sl in { { -1, "1" }, { 1, "2" } } do
                        local zEnd = sl[1] :: number
                        local yawDeg = 90 - 15 * zEnd * dxSign
                        local off = Spec.rotY({ -zEnd * 0.6, 0, 0 }, yawDeg)
                        table.insert(
                            kids,
                            Spec.part(`ScreenSlab_{tier}_{si}`, {
                                Size = { 1.2, scrH, 0.08 },
                                CFrame = Spec.cframe({
                                    hingeX + off[1],
                                    surface + scrH / 2,
                                    hingeZ + off[3],
                                }, Spec.rotYMat(yawDeg)),
                                Color = palette.ivory,
                                Material = "Fabric",
                                CanCollide = false,
                                CanQuery = false,
                                CanTouch = false,
                                CastShadow = false,
                            })
                        )
                    end
                end
                table.insert(out, Spec.model(`ShelfWall{wname}`, kids))
            end

            -- ----- the display plinth, centre-floor: the catalog's hero piece -----
            -- Midway between the frontage clearance line (z0 + 1.2) and the counter's
            -- front face — the same customer-floor midline apparel's table sits on.
            local plinthZ = ((env.z0 + 1.2) + (counterZ - 1.0)) / 2
            local PLINTH = 1.8
            table.insert(
                out,
                Spec.model("DisplayPlinth", {
                    Spec.part("Plinth", {
                        Size = { PLINTH, PLINTH, PLINTH },
                        CFrame = Spec.cframe({ env.cx, FLOOR + PLINTH / 2, plinthZ }),
                        Color = palette.timber,
                        Material = "Wood",
                    }),
                    miniLantern("HeroLantern", env.cx, FLOOR + PLINTH, plinthZ, {
                        base = { 1.25, 0.35 },
                        shaft = { 0.4, 0.8 },
                        box = 0.75,
                        cap = { 1.4, 0.3 },
                    }, true),
                })
            )

            -- ----- the counter: 花火屋's rule, 花火屋's number (as apparel) -----
            local counterW = env.w * 0.6
            table.insert(
                out,
                Spec.part("Counter", {
                    Size = { counterW, ctx.consts.COUNTER_H, 2.0 },
                    CFrame = Spec.cframe({ env.cx, FLOOR + ctx.consts.COUNTER_H / 2, counterZ }),
                    Color = palette.timber,
                    Material = "Wood",
                })
            )

            -- ----- the rear shelf, full counter width, back face ON the wall's inner face -----
            local shelfZ = wallInnerBackZ - SHELF_D / 2
            local sKids: { any } = {}
            table.insert(
                sKids,
                Spec.part("ShelfBoard", {
                    Size = { counterW, 0.4, SHELF_D },
                    CFrame = Spec.cframe({ env.cx, FLOOR + 5.5, shelfZ }),
                    Color = palette.timber,
                    Material = "Wood",
                })
            )
            for _, side in { -1, 1 } do
                table.insert(
                    sKids,
                    Spec.part(`ShelfBracket_{side}`, {
                        Size = { 0.3, 0.3, 1.0 },
                        CFrame = Spec.cframe({
                            env.cx + side * (counterW / 2 - 0.7),
                            FLOOR + 5.5 - 0.2 - 0.15,
                            wallInnerBackZ - 0.5,
                        }),
                        Color = palette.timber,
                        Material = "Wood",
                    })
                )
            end
            -- boxed stock on top — apparel's five-bolt rhythm, in this shop's goods
            for i = 1, 5 do
                table.insert(
                    sKids,
                    Spec.part(`StockBox_{i}`, {
                        Size = { 0.8, 0.8, 0.8 },
                        CFrame = Spec.cframe({
                            env.cx + (i - 3) * (counterW - 1.0) / 5,
                            FLOOR + 5.5 + 0.2 + 0.4,
                            shelfZ,
                        }),
                        Color = if i == 3
                            then palette.gold
                            elseif i % 2 == 1 then palette.timber
                            else palette.moss,
                        Material = "Wood",
                    })
                )
            end
            table.insert(out, Spec.model("RearShelf", sKids))

            return out
        end,
    },
} :: Shop

-- Machiya_East -> SPORTS BOOK FRONTAGE. pivot(74.27,119.42,47.58)
-- size(21.40,15.92,13.24) yawDeg -0.20 (within the +/-1 deg tolerance, treated as
-- 0 -- Machiya.luau's local frame is already the world frame here). Footing ring
-- (front is a Sand/Slate mix, no longer a clean grade):
--   NW(63.59,40.92) 109.74  NE(84.99,40.99) 103.41  N_mid(74.29,40.96) 106.63
--   SW(63.55,54.16) 119.73  SE(84.95,54.24) 109.21  S_mid(74.25,54.20) 114.08
--   W_mid(63.57,47.54) 115.16  E_mid(84.97,47.62) 106.03
-- *** CONCERN: front spread (NW/NE/N_mid) is 6.32 studs (103.41 to 109.74) --
-- well past the 1.5-stud flag threshold. This is not the flat promenade grade
-- the other two shells sit on; the ground under this footprint is genuinely
-- uneven, west-to-east as well as north-to-south (W_mid 115.16 vs E_mid 106.03).
-- floorY is set to the front's highest hit, 109.74, by the same rule as the other
-- two shells, but this site's terrain needs the owner's eye before a shell is
-- built here -- NOT resolved with invented terracing. ***
-- *** CONCERN: the envelope's AABB (x[63.57,84.97] y[111.46,127.38] z[40.96,54.20])
-- intersects 18 existing Overlook parts (UpperDeck, GirderUpperDeckX3, and 16
-- railing/barrier pieces) -- workspace:GetPartBoundsInBox around the envelope,
-- Include-filtered to workspace.RoshamboStage.Overlook. The design spec calls for
-- this shell's future interior to bore under the western Overlook, so SOME
-- proximity is intended, but a literal collision with the Overlook's built upper
-- deck is a siting problem for the shell itself, not just its future cavern. The
-- nearest Overlook part strictly outside (west of) the envelope's x0 is
-- RailNUpperDeckB3, east face x=62.27, a 1.30-stud gap. ***
MachiyaShops.sportsbook = {
    name = "MachiyaEast",
    envelope = { x0 = 63.57, x1 = 84.97, z0 = 40.96, z1 = 54.20, floorY = 109.74 },
    yaw = 0,
    frontage = "koshi",
    interior = "none",
    -- The BLANK wall board, and nothing else (owner's signage pass, 2026-08-15):
    -- `board = true` is the kit's original blank contract — framed panel, no
    -- SurfaceGui, no copy. The sports book carries no signage copy (the
    -- wager-language ruling) and its naming style is deliberately out of scope.
    -- NOT emitted by genmodels: this shell only exists when a task builds it.
    identity = { board = true },
} :: Shop

-- ===== chayaSurvey — record for Task 7 (Chaya.luau), not a Shop table =====
-- Machiya_2 -> RIVERSIDE CHAYA. pivot(-57.37,118.44,14.92) size(14.40,14.92,13.24)
-- yawDeg -97.00 -- FAR past the +/-1 deg tolerance. Task 7 must use the LOCAL
-- frame (envelope measured around the pivot in the block's own rotated axes) and
-- set shop.yaw = -97.00; Machiya.luau's yaw pass (Task 3) applies it, the same
-- way it will for any other rotated shell. World-frame AABB, for reference only
-- (NOT the envelope to build from): x[-64.57,-50.17] z[8.30,21.54].
-- Footing ring (world-frame corners/edges of the AABB, Sand/Grass/Slate mixed):
--   NW(-49.92,8.58) 112.59  NE(-51.67,22.87) 118.99  SW(-63.06,6.97) 115.56
--   SE(-64.82,21.26) 124.66  N_mid(-50.79,15.73) 113.45  S_mid(-63.94,14.11) 120.28
--   W_mid(-56.49,7.77) 112.87  E_mid(-58.24,22.07) 117.86
-- Spread across all 8 is 12.07 studs (112.59 to 124.66) -- unsurprising for an AABB
-- ring probed against a block that's actually rotated 97 deg; Task 7 should re-probe
-- in the block's own local frame rather than trust these axis-aligned points.
--
-- DockDeck -> chaya's companion deck. pivot(-44.00,112.20,-12.00)
-- size(14.00,0.80,10.00) yawDeg 0.00. Footing ring: all 8 points hit
-- Enum.Material.Water at Y 109.92, flat (spread 0.00) -- the deck sits over the
-- river, as its name and the design spec both say; there is no dry terrain under
-- its footprint to found on, only the water surface. Envelope (world frame, yaw
-- 0): x0=-51.00, x1=-37.00, z0=-17.00, z1=-7.00.
return MachiyaShops
