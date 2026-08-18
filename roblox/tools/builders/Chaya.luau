--!strict
-- The riverside chaya and its dock — item 4's last shell (design spec
-- 2026-08-15-machiya-row-design §3, sited by the owner 2026-08-17).
--
-- NOT A MACHIYA, AND DELIBERATELY NOT BUILT LIKE ONE. The row's four shells are dressed
-- town-houses: stucco, kōshi, kawara tile. This vendor is rougher and open to the air
-- (owner, 2026-08-17), so it is a pavilion — round timber posts, a thatched gable on
-- exposed rafters, a plank counter, and no walls of any kind. Forcing it through
-- Machiya.luau's archetype would have given it the one thing it must not have: a front.
--
-- THE ARRANGEMENT (owner, 2026-08-17): "the dock out over the water, and the chaya butted
-- up against the dock's south edge, facing North. Basically you should be able to step onto
-- the dock and turn left to look at the Chaya counter, or turn right and a couple of steps
-- out onto the dock over the water." You arrive along the beach from the east; the counter
-- is to the south, the river to the north. Both structures are 11 wide on the same x span,
-- so from out on the water they read as one object.
--
-- THIS SUPERSEDES BOTH MASSING MARKS. `Machiya_2` sat 20 studs up the bank across an
-- 11.20-stud fall with three shore boulders under its low corner; `DockDeck` sat 24 studs
-- offshore with no way onto it. The pair below is the owner's description put on the
-- flattest ground either mark touched. The blocks stay in ServerStorage as history.
--
-- Pure and deterministic — no Roblox globals, and the post feet are baked from an in-Studio
-- survey rather than probed at build time (the emitted .model.json is CI drift-checked).
local Spec = require("./Spec")
local Chochin = require("./Chochin")

local Chaya = {}

-- ===== the site, surveyed 2026-08-17 (Studio MCP, Edit datamodel) =====
-- Terrain-filtered raycasts from y=180 straight down, at every post's own (x, z). The
-- river surface reads 109.92 and its bed 101.7–102.0 under the two northern rows; the
-- beach behind climbs from 111.8 to 113.6. There is a channel off the west corner — at
-- (−54, 5) the bed drops to 102 with only 8 studs of water above it — which is why the
-- footprint starts at x −52 and the chaya's own north edge holds back to z 7.
local X0, X1 = -52.0, -41.0 -- the chaya, 11 wide
-- THE DOCK RUNS 4 STUDS FURTHER EAST THAN THE CHAYA (owner, 2026-08-17): "the dock should
-- extend 4 studs further to the east, which should provide a kind of step up from the sand
-- onto it." It does, and the ground does the work: the beach at x -37 probes 112.45 to
-- 113.00 against a deck top of 112.6, so the east edge meets the sand within half a stud
-- and you walk on rather than climb on. That is also why only the dock widens -- the chaya
-- stays 11 so the pair still reads as one object from the water.
local DOCK_X1 = -37.0
local DOCK_Z0, DOCK_Z1 = -3.0, 7.0 -- 10 deep, out over the river
local CHAYA_Z0, CHAYA_Z1 = 7.0, 17.0 -- 10 deep, on the beach
Chaya.DECK_TOP = 112.6 -- 2.68 clear of the water: a landing, not a jetty
Chaya.FLOOR = 114.6 -- two 1.0 risers up from the dock

-- ===== timber, in user units (1 stud = 1 foot, 1 inch = 1/12) =====
local IN = 1 / 12
local FRAME_T, FRAME_H = 2 * IN, 6 * IN -- 2x6 box frame, on edge
local BOARD_T, BOARD_W = 2 * IN, 5 * IN -- 2x5 decking, laid flat
-- A WIDER GAP THAN THE FALLS DOCK'S INCH. This is the rough end of the canyon's joinery:
-- daylight between the boards is the whole difference between "laid" and "milled".
local BOARD_GAP = 1.6 * IN
local GIRDER_H, GIRDER_W = 0.9, 0.6

-- ROUND POSTS, NOT SQUARE (owner, 2026-08-17). Every post that carries the dock or the
-- chaya floor is a stood-up cylinder — Roblox's cylinder runs along its local X, so each
-- one takes Spec.ROT.CYL_VERTICAL to aim that at world Y and its Size reads
-- { height, diameter, diameter }. Left at identity a cylinder lies down and reads as a log.
local POST_D_DOCK = 0.9 -- ten studs of it stands in the river; a slim one would look wrong
local POST_D_CHAYA = 0.66
local MIN_POST = 0.75 -- a shallow foot still buries rather than perching

-- ===== the roof: thatch, and the eave reaches out over the dock =====
local ROOF_Z0, ROOF_Z1 = 4.4, 18.0 -- north eave (out over the dock), south eave
Chaya.ROOF_Z0 = ROOF_Z0
Chaya.RIDGE_Z = (ROOF_Z0 + ROOF_Z1) / 2
local EAVE_Y = 121.2
local RIDGE_Y = 124.0
local ROOF_OVERHANG_X = 0.7
local THATCH_T = 0.7
local HALF_RUN = Chaya.RIDGE_Z - ROOF_Z0
local RISE = RIDGE_Y - EAVE_Y
local SLOPE = RISE / HALF_RUN
local SLOPE_LEN = math.sqrt(HALF_RUN * HALF_RUN + RISE * RISE)
local PITCH = math.atan(RISE / HALF_RUN)

-- The underside of the thatch at a world z. Exported because the keeper's headroom is a
-- test, and a test that hard-codes 121.2 stops checking the moment the roof is re-pitched.
function Chaya.roofUndersideAt(z: number): number
    local run = math.max(math.min(z - ROOF_Z0, ROOF_Z1 - z), 0)
    return EAVE_Y + SLOPE * run - THATCH_T / math.cos(PITCH)
end

-- ===== baked post feet — one terrain probe each, 2026-08-17 =====
-- { x, z, foot y }. The dock's are the BED (water ignored); its south row is already on
-- sand, which is what "the dock lands on the beach" means in numbers. The chaya's are the
-- beach surface. Do not re-derive these: they are the ground, not a formula.
local DOCK_POSTS = {
    { -51.55, -2.55, 101.97 }, -- Slate, 7.91 of water above it
    { -46.50, -2.55, 101.92 },
    { -41.45, -2.55, 101.89 },
    { -37.45, -2.55, 106.91 }, -- the east column, added with the 4-stud extension
    { -51.55, 2.00, 101.99 },
    { -46.50, 2.00, 101.76 },
    { -41.45, 2.00, 108.54 }, -- the bed shelves up sharply toward the east bank
    { -37.45, 2.00, 112.06 }, -- Grass: ashore already, half way along the extension
    { -51.55, 6.55, 111.09 }, -- Sand: the south row is ashore
    { -46.50, 6.55, 111.97 },
    { -41.45, 6.55, 112.33 },
    { -37.45, 6.55, 113.00 }, -- the sand here stands 0.40 ABOVE the deck: the step-on
}

Chaya.MIN_POST = MIN_POST
-- Exported so the tests can hold each emitted post against the ground it was probed on,
-- rather than against a second copy of these numbers.
Chaya.DOCK_POSTS = DOCK_POSTS

local CHAYA_POSTS = {
    { -51.67, 7.33, 111.81 },
    { -46.50, 7.33, 112.32 },
    { -41.33, 7.33, 112.64 },
    { -51.67, 16.67, 113.62 },
    { -46.50, 16.67, 113.10 },
    { -41.33, 16.67, 112.96 },
}

Chaya.CHAYA_POSTS = CHAYA_POSTS

-- ===== the fittings =====
-- TWO STUDS SOUTH of where it was first built (owner, 2026-08-17). It buys the customers'
-- side the room a bench and two cushions actually need, and it costs the keeper's side --
-- which is correct for a stand: the working strip behind a yatai counter is narrow, and the
-- gear that will not fit in it hangs off the rear posts instead.
local COUNTER_Z = 13.5
local COUNTER_D = 1.8
local COUNTER_TOP = Chaya.FLOOR + 3.0 -- sized to a keeper standing behind it, per 花火屋
local SLOT_Z0 = COUNTER_Z + COUNTER_D / 2 -- the slot starts at the counter's own back face
-- The clear strip between the counter's back face and the rear posts. Shoulder room is the
-- measurement that matters for somewhere to STAND -- an avatar is about a stud deep and two
-- wide -- so the slot keeps its 4 studs across and takes the depth that is left.
local SLOT_D = 1.9
local SLOT_H = 6.0
local RAIL_Y = Chaya.FLOOR + 4.2 -- the noren rail: head height across the front

local function rotX(deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    -- Row-major. A POSITIVE angle drops the local +Z end — the trap that has inverted a
    -- roof in this repo before, and the reason the two planes take opposite signs below.
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Chaya.build(palette: any, _layout: any): any
    local children = {}
    local timber = palette.timber
    -- Boards weather lighter than the frame they sit on; both are plain Wood, never the
    -- dressed CypressWeathered the shōrō and the falls dock wear. That variant is the
    -- canyon's resort joinery, and this is a tea stand on a beach.
    local board = { 0.55, 0.45, 0.33 }
    local straw = { 0.76, 0.66, 0.44 }
    local indigo = { 0.20, 0.26, 0.36 }

    local function part(name: string, props: { [string]: any })
        table.insert(children, Spec.part(name, props))
    end

    local function beam(name: string, size: { number }, pos: { number }, colour: { number })
        part(name, { Size = size, CFrame = Spec.cframe(pos), Material = "Wood", Color = colour })
    end

    -- One round post: foot on its surveyed ground, head at `top`.
    local function post(name: string, x: number, z: number, foot: number, top: number, dia: number)
        local h = math.max(top - foot, MIN_POST)
        part(name, {
            Shape = "Cylinder",
            Size = { h, dia, dia },
            CFrame = Spec.cframe({ x, top - h / 2, z }, Spec.ROT.CYL_VERTICAL),
            Material = "Wood",
            Color = timber,
        })
    end

    -- A framed plank deck: 2x6 box frame with its outer faces ON the footprint, 2x5 boards
    -- laid across it with daylight between, tops flush with the frame. The board width is
    -- held exact and the remainder spread evenly across the gaps, so a deck never ends on a
    -- ripped board.
    local function deck(prefix: string, x0: number, x1: number, z0: number, z1: number, top: number)
        local w, d = x1 - x0, z1 - z0
        local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        local frameY = top - FRAME_H / 2
        local innerW = w - 2 * FRAME_T
        for _, f in
            {
                { "West", x0 + FRAME_T / 2, cz, FRAME_T, d },
                { "East", x1 - FRAME_T / 2, cz, FRAME_T, d },
                { "North", cx, z0 + FRAME_T / 2, innerW, FRAME_T },
                { "South", cx, z1 - FRAME_T / 2, innerW, FRAME_T },
            }
        do
            beam(
                `{prefix}Frame{f[1]}`,
                { f[4] :: number, FRAME_H, f[5] :: number },
                { f[2] :: number, frameY, f[3] :: number },
                timber
            )
        end
        local innerD = d - 2 * FRAME_T
        local n = math.floor((innerD + BOARD_GAP) / (BOARD_W + BOARD_GAP))
        local pitch = innerD / n
        local first = z0 + FRAME_T + pitch / 2
        for i = 1, n do
            beam(
                `{prefix}Board_{i}`,
                { innerW, BOARD_T, BOARD_W },
                { cx, top - BOARD_T / 2, first + (i - 1) * pitch },
                board
            )
        end
    end

    -- ----- the dock, out over the river -----
    deck("Dock", X0, DOCK_X1, DOCK_Z0, DOCK_Z1, Chaya.DECK_TOP)
    local dockSlab = Chaya.DECK_TOP - FRAME_H
    for i, p in DOCK_POSTS do
        post(`PostDock_{i}`, p[1], p[2], p[3], dockSlab, POST_D_DOCK)
    end
    for i, z in { DOCK_POSTS[1][2], DOCK_POSTS[5][2], DOCK_POSTS[9][2] } do
        beam(
            `DockGirder_{i}`,
            { DOCK_X1 - X0, GIRDER_H, GIRDER_W },
            { (X0 + DOCK_X1) / 2, dockSlab - GIRDER_H / 2, z },
            timber
        )
    end

    -- ----- the chaya floor, on the beach -----
    deck("Chaya", X0, X1, CHAYA_Z0, CHAYA_Z1, Chaya.FLOOR)
    local floorSlab = Chaya.FLOOR - FRAME_H
    -- THE POSTS RUN THROUGH. A pavilion's posts carry the roof as well as the floor, so
    -- these are one stick from the sand to the eave plate rather than stubs under a deck
    -- with a second set standing on it — which is both how it is built and why it reads
    -- rougher than the row.
    for i, p in CHAYA_POSTS do
        post(`PostChaya_{i}`, p[1], p[2], p[3], EAVE_Y, POST_D_CHAYA)
    end
    for i, z in { CHAYA_POSTS[1][2], CHAYA_POSTS[4][2] } do
        beam(
            `ChayaGirder_{i}`,
            { X1 - X0, GIRDER_H, GIRDER_W },
            { (X0 + X1) / 2, floorSlab - GIRDER_H / 2, z },
            timber
        )
        -- the eave plate the rafters land on, at the same two post rows
        beam(`Plate_{i}`, { X1 - X0, 0.35, 0.45 }, { (X0 + X1) / 2, EAVE_Y - 0.175, z }, timber)
    end

    -- ----- the step between them: two 1.0 risers, mid-span where you arrive -----
    beam("Step_1", { 4.0, 1.0, 0.9 }, { -46.5, Chaya.DECK_TOP + 0.5, CHAYA_Z0 - 0.45 }, board)

    -- ----- the counter, splitting the floor -----
    beam("CounterTop", { 8.0, 0.35, COUNTER_D }, { -46.5, COUNTER_TOP - 0.175, COUNTER_Z }, board)
    beam(
        "CounterApron",
        { 8.0, 1.5, 0.25 },
        { -46.5, COUNTER_TOP - 1.1, COUNTER_Z - COUNTER_D / 2 + 0.125 },
        timber
    )
    for i, lx in { -49.8, -43.2 } do
        part(`CounterLeg_{i}`, {
            Shape = "Cylinder",
            Size = { COUNTER_TOP - 0.35 - Chaya.FLOOR, 0.35, 0.35 },
            CFrame = Spec.cframe(
                { lx, (Chaya.FLOOR + COUNTER_TOP - 0.35) / 2, COUNTER_Z },
                Spec.ROT.CYL_VERTICAL
            ),
            Material = "Wood",
            Color = timber,
        })
    end

    -- ----- the keeper's slot: a clear place to stand, and the gear within reach -----
    -- Named, invisible, and non-colliding. A future NPC binds to THIS, by name — never to
    -- a coordinate (the replication-races lesson: discover by name or tag, never by
    -- position). Until then the gear reads as "the keeper just stepped away".
    part("ChayaKeeperSlot", {
        Size = { 4.0, SLOT_H, SLOT_D },
        CFrame = Spec.cframe({ -46.5, Chaya.FLOOR + SLOT_H / 2, SLOT_Z0 + SLOT_D / 2 }),
        Transparency = 1,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
    })

    part("Brazier", {
        Shape = "Cylinder",
        Size = { 1.0, 1.4, 1.4 },
        CFrame = Spec.cframe({ -49.4, Chaya.FLOOR + 0.5, 14.9 }, Spec.ROT.CYL_VERTICAL),
        Material = "Metal",
        MaterialVariant = "IronDark",
        Color = palette.ironDark,
    })
    part("BrazierCoals", {
        Shape = "Cylinder",
        Size = { 0.12, 1.05, 1.05 },
        CFrame = Spec.cframe({ -49.4, Chaya.FLOOR + 0.92, 14.9 }, Spec.ROT.CYL_VERTICAL),
        Material = "Neon",
        Color = { 0.85, 0.42, 0.18 },
    })
    part("Kettle", {
        Shape = "Ball",
        Size = { 0.95, 0.95, 0.95 },
        CFrame = Spec.cframe({ -49.4, Chaya.FLOOR + 1.45, 14.9 }),
        Material = "Metal",
        MaterialVariant = "IronDark",
        Color = { 0.30, 0.29, 0.28 },
    })
    part("KettleSpout", {
        Shape = "Cylinder",
        Size = { 0.55, 0.22, 0.22 },
        CFrame = Spec.cframe({ -48.9, Chaya.FLOOR + 1.55, 14.9 }),
        Material = "Metal",
        MaterialVariant = "IronDark",
        Color = { 0.30, 0.29, 0.28 },
    })

    beam("CaddyShelf", { 5.0, 0.25, 0.4 }, { -46.5, Chaya.FLOOR + 4.0, 16.55 }, board)
    for i = 1, 4 do
        part(`Caddy_{i}`, {
            Shape = "Cylinder",
            Size = { 0.55, 0.4, 0.4 },
            CFrame = Spec.cframe({ -48.4 + (i - 1) * 1.1, Chaya.FLOOR + 4.4, 16.55 }, Spec.ROT.CYL_VERTICAL),
            Material = "Wood",
            Color = timber,
        })
    end
    for i, cx in { -44.2, -43.4 } do
        part(`CupStack_{i}`, {
            Shape = "Cylinder",
            Size = { 0.5, 0.5, 0.5 },
            CFrame = Spec.cframe({ cx, COUNTER_TOP + 0.25, 14.1 }, Spec.ROT.CYL_VERTICAL),
            Material = "Slate",
            Color = { 0.82, 0.80, 0.74 },
        })
    end

    -- ----- the customers' side: a bench and two cushions, facing the water -----
    beam("Bench", { 5.0, 0.3, 1.3 }, { -47.0, Chaya.FLOOR + 1.35, 8.8 }, board)
    for i, lx in { -49.2, -44.8 } do
        part(`BenchLeg_{i}`, {
            Shape = "Cylinder",
            Size = { 1.2, 0.3, 0.3 },
            CFrame = Spec.cframe({ lx, Chaya.FLOOR + 0.6, 8.8 }, Spec.ROT.CYL_VERTICAL),
            Material = "Wood",
            Color = timber,
        })
    end
    for i, cx in { -50.6, -43.0 } do
        part(`Cushion_{i}`, {
            Size = { 1.5, 0.18, 1.5 },
            CFrame = Spec.cframe({ cx, Chaya.FLOOR + 0.09, 9.6 }),
            Material = "Fabric",
            Color = indigo,
        })
    end

    -- ----- the roof: two thatch planes on exposed rafters -----
    local roofW = (X1 - X0) + 2 * ROOF_OVERHANG_X
    local cx = (X0 + X1) / 2
    for _, plane in
        {
            { "North", (ROOF_Z0 + Chaya.RIDGE_Z) / 2, -math.deg(PITCH) },
            { "South", (Chaya.RIDGE_Z + ROOF_Z1) / 2, math.deg(PITCH) },
        }
    do
        local zc, deg = plane[2] :: number, plane[3] :: number
        local rot = rotX(deg)
        part(`Thatch{plane[1]}`, {
            Size = { roofW, THATCH_T, SLOPE_LEN },
            CFrame = Spec.cframe({ cx, (EAVE_Y + RIDGE_Y) / 2, zc }, rot),
            Material = "Grass",
            Color = straw,
        })
        for i = 1, 5 do
            local rx = X0 + (X1 - X0) * (i - 1) / 4
            part(`Rafter{plane[1]}_{i}`, {
                Size = { 0.22, 0.22, SLOPE_LEN + 0.6 },
                CFrame = Spec.cframe({ rx, (EAVE_Y + RIDGE_Y) / 2 - THATCH_T / 2 - 0.11, zc }, rot),
                Material = "Wood",
                Color = timber,
            })
        end
    end
    part("RidgeBundle", {
        Shape = "Cylinder",
        Size = { roofW, 0.75, 0.75 },
        CFrame = Spec.cframe({ cx, RIDGE_Y + 0.2, Chaya.RIDGE_Z }),
        Material = "Grass",
        Color = { 0.68, 0.58, 0.38 },
    })

    -- ----- the front: a rail, a half-noren, a rolled blind and one chōchin -----
    beam("FrontRail", { X1 - X0, 0.3, 0.3 }, { cx, RAIL_Y, CHAYA_POSTS[1][2] }, timber)
    -- HALF-NOREN, and half is the point: it screens the counter without closing the front,
    -- which is what an open-air stand hangs. Plain cloth, no crest — the row's four shells
    -- carry the mon; this one is the vendor who never had one painted.
    for i = 1, 3 do
        local panelW = (X1 - X0) / 3 - 0.4
        part(`Noren_{i}`, {
            Size = { panelW, 1.8, 0.05 },
            CFrame = Spec.cframe({
                X0 + (X1 - X0) * ((i - 0.5) / 3),
                RAIL_Y - 1.05,
                CHAYA_POSTS[1][2] - 0.1,
            }),
            Material = "Fabric",
            MaterialVariant = "NorenCloth",
            Color = indigo,
            Transparency = 0.1,
        })
    end
    -- A sudare rolled up under the west eave: the weather side, and the only thing here
    -- that could ever be let down.
    part("Sudare", {
        Shape = "Cylinder",
        Size = { 5.4, 0.5, 0.5 },
        CFrame = Spec.cframe({ X0 + 0.35, EAVE_Y - 0.55, 11.4 }, Spec.ROT.CYL_ALONG_Z),
        Material = "Fabric",
        Color = { 0.72, 0.63, 0.44 },
    })
    -- ONE lantern, on the canonical recipe (Chochin.build) rather than a redrawn lookalike.
    -- Its paper takes a straw tint in keeping with the thatch; the tint clears
    -- Chochin.LEGIBILITY_FLOOR, which it must — every chōchin in the canyon carries the
    -- World Throw glyph, and a dark barrel would swallow it at night.
    -- Chochin.build prefixes the name itself ("Chaya" -> ChochinChaya), the same way the
    -- row's own lanterns read ChochinWest / ChochinEast in the place.
    table.insert(children, Chochin.build("Chaya", -42.2, 6.2, EAVE_Y - 0.6, { 214, 186, 140 }))

    return Spec.model("Chaya", children)
end

return Chaya
