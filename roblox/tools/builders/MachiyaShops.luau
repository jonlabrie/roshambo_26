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
        chochin = true,
        -- Blank timber kanban above the kamoi — the glyph-pipeline texture is a gate
        -- follow-up with the owner, not this task.
        board = true,
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
            -- counter's front face. The rack group registers to the table.
            local counterZ = env.z1 - 4.4
            local tableZ = ((env.z0 + 1.2) + (counterZ - 1.0)) / 2

            -- ----- two kimono racks flanking the fold table on a diagonal -----
            -- MOVED OFF THE FRONTAGE at the round-2 gate: standing in the open bays they
            -- crowded the entrance. One rack either side of the table, splayed 35° and
            -- mirror-imaged about the table's centre line — each rack's OUTER end swings
            -- toward the frontage, so the pair opens toward the door and the group reads
            -- as one display mid-floor, doorways left clear. TWO cloths per rack (the
            -- owner's round-2 call: three thin ones read banner-ish, not garment-ish),
            -- width still derived from the rack's own span. Rail and cloth stay
            -- non-colliding; the posts collide, furniture you walk around. Rotation goes
            -- through Spec.rotY/rotYMat only — the arch-stable helpers.
            local POST = 0.3
            local POST_H = 5.5
            local RACK_SPAN = 4.4 -- post centre to centre: two ~1.95-wide cloths' worth
            local CLOTH_W = (RACK_SPAN - 0.5) / 2 -- 0.1 between cloths, 0.05 to each post
            local RACK_DX = 4.5 -- table centre to rack centre; ends clear the walls AND the table
            local RACK_YAW = 35 -- first attempt, for the owner to judge
            for _, rk in { { "KimonoRackWest", -1 }, { "KimonoRackEast", 1 } } do
                local rackName, side = rk[1] :: string, rk[2] :: number
                local rcx = env.cx + side * RACK_DX
                local yaw = side * RACK_YAW -- west −35 / east +35: outer ends swing north
                local rot = Spec.rotYMat(yaw)
                -- world position of a point dx along the rack's own long axis
                local function at(dx: number, y: number): { number }
                    local o = Spec.rotY({ dx, 0, 0 }, yaw)
                    return { rcx + o[1], y, tableZ + o[3] }
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
                local cOff = if side == 1 then 1 else 0 -- mirror the colour order too
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
                table.insert(out, Spec.model(rackName, kids))
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

-- Machiya_4 -> ACCESSORIES. pivot(24.34,119.59,42.96) size(16.63,14.92,13.24)
-- yawDeg 0.00. Footing ring (Sand on the front/sides, Slate on the back):
--   NW(16.02,36.34) 112.03  NE(32.65,36.34) 113.14  N_mid(24.34,36.34) 113.21
--   SW(16.02,49.59) 111.59  SE(32.65,49.59) 114.99  S_mid(24.34,49.59) 120.24
--   W_mid(16.02,42.96) 112.29  E_mid(32.65,42.96) 113.94
-- Front spread 1.18 studs -- under the 1.5 flag threshold but the widest of the
-- three shells; recorded, not smoothed. floorY = the front's highest hit, 113.21.
-- Back spread 8.65 (111.59 to 120.24), again reading as the cut, not the floor.
MachiyaShops.accessories = {
    name = "MachiyaAccessories",
    envelope = { x0 = 16.02, x1 = 32.65, z0 = 36.34, z1 = 49.58, floorY = 113.21 },
    yaw = 0,
    frontage = "open",
    interior = "shallow",
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
