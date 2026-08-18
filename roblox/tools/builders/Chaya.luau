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
-- POST -> GIRDER -> JOIST -> BOARD, and each tier crosses the one below it. The first cut
-- of this builder skipped the joists and laid the girders PARALLEL to the boards, which
-- carried nothing: an 11-stud board spanned frame to frame on faith. The owner called the
-- engineering suspect on sight (2026-08-17) and was right. Joists run north-south, boards
-- east-west across them, and no board spans more than JOIST_PITCH between supports.
local JOIST_W, JOIST_H = 0.3, 0.33
local JOIST_PITCH = 2.5

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
-- The roof's own two heights, exported: they are the slab's MID-PLANE at each end, which is
-- where the edge rolls' centrelines belong (see the roll block in build).
Chaya.EAVE_Y = EAVE_Y
Chaya.RIDGE_Y = RIDGE_Y
local ROOF_OVERHANG_X = 0.7
local THATCH_T = 0.7
local RAFTER_EXTRA = 0.6 -- how far a rafter runs past the thatch it carries: the tail
local RAFTER_T = 0.22
-- How far a rafter's centre sits below the thatch's. Named because the lantern hangs off a
-- rafter TAIL and has to find it: derived from the plane's centre without this, the hang
-- point lands half a stud high, up on the thatch line where there is no timber at all.
local RAFTER_DROP = THATCH_T / 2 + RAFTER_T / 2
local HALF_RUN = Chaya.RIDGE_Z - ROOF_Z0
local RISE = RIDGE_Y - EAVE_Y
local SLOPE = RISE / HALF_RUN
local SLOPE_LEN = math.sqrt(HALF_RUN * HALF_RUN + RISE * RISE)
local PITCH = math.atan(RISE / HALF_RUN)

-- The underside of the thatch at a world z. Exported because the keeper's headroom is a
-- test, and a test that hard-codes 121.2 stops checking the moment the roof is re-pitched.
-- HALF the thickness, measured vertically. EAVE_Y and RIDGE_Y are the slab's CENTRELINE, so
-- its faces are half a thickness either side of it -- and the perpendicular half-thickness
-- becomes THATCH_T/2/cos(pitch) when read straight up. This subtracted a WHOLE thickness
-- until 2026-08-17: harmless where it was used (a headroom check that was simply stricter
-- than it needed to be), and wrong the moment `roofTopAt` was derived from it, which put the
-- roof's top face exactly on its own centreline and hid a real lip from the test meant to
-- catch one.
function Chaya.roofUndersideAt(z: number): number
    local run = math.max(math.min(z - ROOF_Z0, ROOF_Z1 - z), 0)
    return EAVE_Y + SLOPE * run - THATCH_T / 2 / math.cos(PITCH)
end

-- The upper face at a world z. The edge rolls must not stand proud of this: a roll that does
-- reads as a lip running round the roof rather than as the roof's own edge (owner, 2026-08-17).
function Chaya.roofTopAt(z: number): number
    return Chaya.roofUndersideAt(z) + THATCH_T / math.cos(PITCH)
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
-- THE LANTERN IS RED (owner, 2026-08-17): "Yes, I know red means alcohol and we're serving
-- tea, but red is punchy." That overrides the row's own 2026-08-15 rule excluding true red
-- as izakaya signalling — the owner's call, and recorded as one.
--
-- IT DOES NOT OVERRIDE THE LEGIBILITY FLOOR, which is not a colour nicety: every chōchin in
-- the canyon carries the World Throw glyph on an untinted plate in front of the paper, and
-- PaperLanternDayNight dims the whole lantern toward night. Below Chochin.LEGIBILITY_FLOOR
-- (0.55 relative luminance) the glyph loses its ground and the lantern stops doing its job.
-- This is the reddest paper that clears it: full red, green at half, luminance 0.584. A
-- deeper crimson would measure ~0.32 and swallow the glyph after dark.
Chaya.LANTERN_PAPER = { 255, 124, 84 }
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
-- ONE STUD SOUTH of where it was first built. It went two at the owner's first look and
-- came back one at the second (2026-08-17): "I had you move the counter too far south -- no
-- room for an NPC back there." At 12.5 the customers' side keeps the room the bench needs
-- and the keeper's strip is 2.8 clear between the counter's back face and the rear posts,
-- which is a place a character can stand rather than a slot they are wedged into.
local COUNTER_Z = 12.5
local COUNTER_D = 1.8
local COUNTER_TOP = Chaya.FLOOR + 3.0 -- sized to a keeper standing behind it, per 花火屋
local SLOT_Z0 = COUNTER_Z + COUNTER_D / 2 -- the slot starts at the counter's own back face
-- The clear strip between the counter's back face and the rear posts, less a hair so the
-- slot never touches a post. Four studs across is shoulder room; the depth is whatever the
-- counter leaves, and at 2.8 a keeper can turn around in it.
local SLOT_D = 2.8
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
    -- NEAR-NEUTRAL, because part.Color MULTIPLIES the variant's ColorMap and the scan
    -- already carries thatch's colour. The 0.76/0.66/0.44 this was before is what you paint
    -- when there is no map underneath; over one it would darken the straw to mud.
    local straw = { 0.94, 0.90, 0.82 }
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

        -- Joists first: they are what the boards land on. Spaced no wider than JOIST_PITCH
        -- and stepped evenly across the span, so the two outermost sit hard against the
        -- frame and the edge boards are carried like every other one.
        local nJ = math.max(2, math.ceil(w / JOIST_PITCH) + 1)
        local jy = top - BOARD_T - JOIST_H / 2
        for i = 1, nJ do
            local jx = x0 + JOIST_W / 2 + (w - JOIST_W) * (i - 1) / (nJ - 1)
            beam(`{prefix}Joist_{i}`, { JOIST_W, JOIST_H, innerD }, { jx, jy, cz }, timber)
        end

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
    -- The girders hang under the joists, and the posts stop under the girders — so the load
    -- path is one straight line from a board to the riverbed rather than three tiers sharing
    -- a level and meeting nothing.
    local dockGirderTop = Chaya.DECK_TOP - BOARD_T - JOIST_H
    for i, p in DOCK_POSTS do
        post(`PostDock_{i}`, p[1], p[2], p[3], dockGirderTop - GIRDER_H, POST_D_DOCK)
    end
    for i, z in { DOCK_POSTS[1][2], DOCK_POSTS[5][2], DOCK_POSTS[9][2] } do
        beam(
            `DockGirder_{i}`,
            { DOCK_X1 - X0, GIRDER_H, GIRDER_W },
            { (X0 + DOCK_X1) / 2, dockGirderTop - GIRDER_H / 2, z },
            timber
        )
    end

    -- ----- the chaya floor, on the beach -----
    deck("Chaya", X0, X1, CHAYA_Z0, CHAYA_Z1, Chaya.FLOOR)
    local chayaGirderTop = Chaya.FLOOR - BOARD_T - JOIST_H
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
            { (X0 + X1) / 2, chayaGirderTop - GIRDER_H / 2, z },
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
        CFrame = Spec.cframe({ -49.4, Chaya.FLOOR + 0.5, 14.2 }, Spec.ROT.CYL_VERTICAL),
        Material = "Metal",
        MaterialVariant = "IronDark",
        Color = palette.ironDark,
    })
    part("BrazierCoals", {
        Shape = "Cylinder",
        Size = { 0.12, 1.05, 1.05 },
        CFrame = Spec.cframe({ -49.4, Chaya.FLOOR + 0.92, 14.2 }, Spec.ROT.CYL_VERTICAL),
        Material = "Neon",
        Color = { 0.85, 0.42, 0.18 },
    })
    part("Kettle", {
        Shape = "Ball",
        Size = { 0.95, 0.95, 0.95 },
        CFrame = Spec.cframe({ -49.4, Chaya.FLOOR + 1.45, 14.2 }),
        Material = "Metal",
        MaterialVariant = "IronDark",
        Color = { 0.30, 0.29, 0.28 },
    })
    part("KettleSpout", {
        Shape = "Cylinder",
        Size = { 0.55, 0.22, 0.22 },
        CFrame = Spec.cframe({ -48.9, Chaya.FLOOR + 1.55, 14.2 }),
        Material = "Metal",
        MaterialVariant = "IronDark",
        Color = { 0.30, 0.29, 0.28 },
    })

    -- Spans post to post. At 5.0 it crossed the middle post and hung off nothing at either
    -- end, which is the same fault as the blind.
    beam(
        "CaddyShelf",
        { CHAYA_POSTS[3][1] - CHAYA_POSTS[1][1] + 0.7, 0.25, 0.4 },
        { -46.5, Chaya.FLOOR + 4.0, 16.55 },
        board
    )
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
            CFrame = Spec.cframe({ cx, COUNTER_TOP + 0.25, 13.0 }, Spec.ROT.CYL_VERTICAL),
            Material = "Slate",
            Color = { 0.82, 0.80, 0.74 },
        })
    end

    -- ----- the customers' side: a bench and two cushions, facing the water -----
    -- TWO KINDS OF SEAT, because they do different jobs (owner, 2026-08-17: "could someone
    -- actually sit and be served in that spot?" -- they could not).
    --
    -- The ENDAI bench is for sitting with your cup: 18 inches of seat, out at the front rail,
    -- facing the river. Pulling it in to the counter, as the last pass did, put a sitter's
    -- back six inches from a 36-inch counter with the keeper serving over their head. It sits
    -- at 8.7 rather than hard against the rail because the middle north post is at 7.0-7.66
    -- and the bench used to run straight through it.
    beam("Bench", { 5.0, 0.3, 1.3 }, { -47.0, Chaya.FLOOR + 1.35, 8.7 }, board)
    for i, lx in { -49.2, -44.8 } do
        part(`BenchLeg_{i}`, {
            Shape = "Cylinder",
            Size = { 1.2, 0.3, 0.3 },
            CFrame = Spec.cframe({ lx, Chaya.FLOOR + 0.6, 8.7 }, Spec.ROT.CYL_VERTICAL),
            Material = "Wood",
            Color = timber,
        })
    end
    -- The STOOLS are for being served at: log rounds, 24 inches of seat against a 36-inch
    -- counter, pulled up close enough to set a cup down without standing. Three of them, in
    -- the bays between the posts. Rough sawn rounds rather than joinery -- this is the vendor
    -- who never had a crest painted.
    local STOOL_H, STOOL_D = 2.0, 1.2
    for i, sx in { -48.6, -46.5, -44.4 } do
        part(`Stool_{i}`, {
            Shape = "Cylinder",
            Size = { STOOL_H, STOOL_D, STOOL_D },
            CFrame = Spec.cframe({ sx, Chaya.FLOOR + STOOL_H / 2, 10.6 }, Spec.ROT.CYL_VERTICAL),
            Material = "Wood",
            Color = board,
        })
    end
    -- Cushions to the ends, out of the strip people walk and sit in. In the middle they were
    -- furniture nobody could reach without stepping over something.
    for i, cx in { -50.8, -42.2 } do
        part(`Cushion_{i}`, {
            Size = { 1.5, 0.18, 1.5 },
            CFrame = Spec.cframe({ cx, Chaya.FLOOR + 0.09, 9.5 }),
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
            MaterialVariant = "Thatch",
            Color = straw,
        })
        for i = 1, 5 do
            local rx = X0 + (X1 - X0) * (i - 1) / 4
            part(`Rafter{plane[1]}_{i}`, {
                Size = { RAFTER_T, RAFTER_T, SLOPE_LEN + RAFTER_EXTRA },
                CFrame = Spec.cframe({ rx, (EAVE_Y + RIDGE_Y) / 2 - THATCH_T / 2 - 0.11, zc }, rot),
                Material = "Wood",
                Color = timber,
            })
        end
    end
    -- THE ROOF FRAME, which the first cut simply did not have: the two thatch planes met at
    -- a ridge line with nothing along it and nothing under it. A tie beam spans plate to
    -- plate over each post column, a king post stands on each one, and the ridge purlin runs
    -- the length of the building on their heads — so the thatch has something to sit on and
    -- the eye can follow the load down a post into the sand.
    -- The tie is wider than the king post that stands on it: a post whose foot overhangs
    -- its own beam is exactly the kind of detail that reads as suspect.
    local TIE_W, TIE_H = 0.45, 0.4
    local PURLIN_H = 0.4
    local tieTop = EAVE_Y + TIE_H
    local purlinBottom = RIDGE_Y - 0.35 - PURLIN_H
    for i, p in CHAYA_POSTS do
        if i <= 3 then -- one per column; the rows share it
            local zc = (CHAYA_POSTS[1][2] + CHAYA_POSTS[4][2]) / 2
            local zd = CHAYA_POSTS[4][2] - CHAYA_POSTS[1][2] + 0.7
            beam(`TieBeam_{i}`, { TIE_W, TIE_H, zd }, { p[1], EAVE_Y + TIE_H / 2, zc }, timber)
            part(`KingPost_{i}`, {
                Shape = "Cylinder",
                Size = { purlinBottom - tieTop, 0.34, 0.34 },
                CFrame = Spec.cframe(
                    { p[1], (tieTop + purlinBottom) / 2, Chaya.RIDGE_Z },
                    Spec.ROT.CYL_VERTICAL
                ),
                Material = "Wood",
                Color = timber,
            })
        end
    end
    beam(
        "RidgePurlin",
        { X1 - X0, PURLIN_H, 0.4 },
        { cx, purlinBottom + PURLIN_H / 2, Chaya.RIDGE_Z },
        timber
    )
    -- Knee braces at the four corner posts. A pavilion with no walls has nothing else
    -- resisting a sideways push, and they are the detail that makes an open frame read as
    -- built rather than assembled.
    for i, c in { { -51.67, 7.33, 1 }, { -41.33, 7.33, -1 }, { -51.67, 16.67, 1 }, { -41.33, 16.67, -1 } } do
        local px, pz, dir = c[1], c[2], c[3]
        local pos, len, rot = Spec.segment(
            { px + dir * 0.3, EAVE_Y - 1.6, pz },
            { px + dir * 1.7, EAVE_Y - 0.25, pz }
        )
        part(`KneeBrace_{i}`, {
            Shape = "Cylinder",
            Size = { len, 0.3, 0.3 },
            CFrame = Spec.cframe(pos, rot),
            Material = "Wood",
            Color = timber,
        })
    end

    -- ROLLED EDGES (owner, 2026-08-17): "it would be nice if we could round the edges
    -- somehow, right now it reads as a block of thatch." A Roblox part is a box and there is
    -- no bevel, so the roll is real geometry -- a bundle along each eave and each verge,
    -- which is how a thatcher finishes an edge anyway. It is the silhouette that was reading
    -- as a slab, so this is where the fix has to land.
    local ROLL_R = 0.42
    -- TWO INCHES BELOW THE MID-PLANE (owner, 2026-08-17): "the rolls need to drop a couple of
    -- inches to eliminate the 'lip' above the roof they're showing now." A roll of this radius
    -- centred on the slab's centreline stands proud of the top face, which reads as a rim
    -- running round the building. Dropped, it tucks under the top and bulges below instead --
    -- also the right way round for a rolled eave, where the bundle's weight hangs beneath the
    -- course it finishes.
    local ROLL_DROP = 2 * IN
    -- ON THE SLAB'S EDGE, NOT UNDER IT (owner, 2026-08-17: "their centerlines appear to
    -- be aligned with the bottom edges"). They were: placed at EAVE_Y - THATCH_T/2, each roll
    -- hung off the underside like a pipe rather than wrapping the edge of the thatch. EAVE_Y
    -- and RIDGE_Y ARE the slab's centreline heights by construction, so the roll simply takes
    -- them and swallows the edge from both faces.
    --
    -- AND THEY OVERSHOOT EACH OTHER AT THE CORNERS by a full radius, so an eave run ends on
    -- the verge roll's OUTSIDE face and vice versa. Ending on each other's centrelines left a
    -- quarter-round notch at all four corners -- exactly where the eye reads the silhouette.
    for i, ez in { ROOF_Z0, ROOF_Z1 } do
        part(`EaveRoll_{i}`, {
            Shape = "Cylinder",
            Size = { roofW + 2 * ROLL_R, ROLL_R * 2, ROLL_R * 2 },
            CFrame = Spec.cframe({ cx, EAVE_Y - ROLL_DROP, ez }),
            Material = "Grass",
            MaterialVariant = "Thatch",
            Color = straw,
        })
    end
    -- The verges: one roll up each slope at each gable end, run as a segment between the
    -- eave corner and the ridge so it lies on the pitch whatever the pitch becomes. The eave
    -- end starts a radius PAST the eave line, for the same corner reason.
    -- EACH VERGE DIES INTO THE EAVE ROLL rather than running past it. Overshooting put a
    -- tilted cap out beyond the eave roll's own surface at all four corners, which is the
    -- wonk the owner saw; ending the centreline ON the eave roll's axis buries that cap
    -- inside it completely, since the two rolls share a radius. The eave course then runs
    -- unbroken through the corner and the verge tucks into it, which is how the edge gets
    -- finished in straw as well as in geometry.
    local verges = {
        { X0 - ROOF_OVERHANG_X, ROOF_Z0 },
        { X1 + ROOF_OVERHANG_X, ROOF_Z0 },
        { X0 - ROOF_OVERHANG_X, ROOF_Z1 },
        { X1 + ROOF_OVERHANG_X, ROOF_Z1 },
    }
    for i, v in verges do
        local pos, len, rot = Spec.segment(
            { v[1], EAVE_Y - ROLL_DROP, v[2] },
            { v[1], RIDGE_Y - ROLL_DROP, Chaya.RIDGE_Z }
        )
        part(`VergeRoll_{i}`, {
            Shape = "Cylinder",
            Size = { len, ROLL_R * 2, ROLL_R * 2 },
            CFrame = Spec.cframe(pos, rot),
            Material = "Grass",
            MaterialVariant = "Thatch",
            Color = straw,
        })
    end

    part("RidgeBundle", {
        Shape = "Cylinder",
        Size = { roofW, 0.75, 0.75 },
        CFrame = Spec.cframe({ cx, RIDGE_Y + 0.2, Chaya.RIDGE_Z }),
        Material = "Grass",
        MaterialVariant = "Thatch",
        Color = { 0.86, 0.80, 0.68 }, -- the ridge bundle is fresher straw than the field
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
    -- A sudare rolled up on the west side: the weather side, and the only thing here that
    -- could ever be let down. IT NEEDS SOMETHING TO HANG FROM — the first cut left 5.4 of
    -- blind floating in the middle of a 9.3 bay, reaching neither post, and the owner saw it
    -- from across the room. Now a beam spans the two west posts and the roll is slung under
    -- it, lashed at each end.
    local bayZ0, bayZ1 = CHAYA_POSTS[1][2], CHAYA_POSTS[4][2]
    local bayLen = bayZ1 - bayZ0
    local blindX = X0 + 0.45
    local beamY = EAVE_Y - 1.1
    beam("SudareBeam", { 0.3, 0.3, bayLen }, { blindX, beamY, (bayZ0 + bayZ1) / 2 }, timber)
    part("Sudare", {
        Shape = "Cylinder",
        Size = { bayLen, 0.55, 0.55 },
        CFrame = Spec.cframe({ blindX, beamY - 0.15 - 0.275, (bayZ0 + bayZ1) / 2 }, Spec.ROT.CYL_ALONG_Z),
        Material = "Fabric",
        Color = { 0.72, 0.63, 0.44 },
    })
    for i, lz in { bayZ0 + 0.6, bayZ1 - 0.6 } do
        part(`SudareTie_{i}`, {
            Size = { 0.12, 0.9, 0.12 },
            CFrame = Spec.cframe({ blindX, beamY - 0.3, lz }),
            Material = "Fabric",
            MaterialVariant = "HempRope",
            Color = { 0.68, 0.60, 0.44 },
        })
    end
    -- ONE lantern, on the canonical recipe (Chochin.build) rather than a redrawn lookalike,
    -- HUNG OFF A RAFTER TAIL (owner, 2026-08-17) — the easternmost one, which is the corner
    -- you walk in at from the sand. The hang point is DERIVED from the rafter's own geometry
    -- rather than eyeballed: the tail is the low end of the north plane, so it is the plane's
    -- centre walked back along the slope by half a rafter. Re-pitch the roof and the lantern
    -- follows it down.
    -- Chochin.build prefixes the name itself ("Chaya" -> ChochinChaya), the same way the
    -- row's own lanterns read ChochinWest / ChochinEast in the place.
    local half = (SLOPE_LEN + RAFTER_EXTRA) / 2
    local tailY = (EAVE_Y + RIDGE_Y) / 2 - RAFTER_DROP - half * math.sin(PITCH)
    local tailZ = (ROOF_Z0 + Chaya.RIDGE_Z) / 2 - half * math.cos(PITCH)
    table.insert(children, Chochin.build("Chaya", X1, tailZ, tailY - 0.12, Chaya.LANTERN_PAPER))

    return Spec.model("Chaya", children)
end

return Chaya
