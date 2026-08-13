--!strict
-- 花火屋 — the firework shop, and the merchant row's first machiya.
--
-- A MACHIYA IS NOT A TEAHOUSE. Every enclosed structure in this canyon so far is a dwelling; a
-- shop has to read differently at a glance. What does that here: an OPEN frontage (no wall on
-- the street side, just posts and a raised timber floor), a deep eave over it, and a closed
-- upper storey of kōshi lattice carrying the sign high enough to read from the bridge.
--
-- EVERY DIMENSION BELOW IS THE OWNER'S. A holdout block was placed in Studio at the proposed
-- footprint and they moved and resized it; these are its measured extents, read back
-- 2026-08-05. The study block survives at Workspace.Sandbox.HanabiyaStudy. Do not re-derive
-- them from anything — see docs/superpowers/specs/2026-08-05-hanabiya-shop-design.md §1.
local Spec = require("./Spec")

local Machiya = {}

-- ===== the owner's envelope =====
local X0, X1 = -1.67, 16.26 -- west, east
local Z0, Z1 = 44.00, 52.00 -- frontage (north, onto the promenade), back (south, into the cut)
local FLOOR = 113.10 -- finished floor, = the karesansui datum

-- THE HOLDOUT'S TOP IS RETIRED (owner: "approximate, and can be safely ignored"). The height now
-- comes from the storeys, and the REAL constraint is the one that always mattered: the shop must
-- stay clearly subordinate to the bell tower. TOP is derived at the bottom of this block and
-- checked against these two numbers, so growing a storey can never quietly close the gap.
local SHORO_TOP = 136.5
local MIN_SHORO_GAP = 5.0

local W = X1 - X0
local D = Z1 - Z0
local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2

-- ===== storey heights, derived from the envelope so they cannot drift out of it =====
local SLAB_T = 0.6 -- the raised timber floor, recipe §2's deck slab
local STOREY_H = 9.0 -- ground storey (owner's gate: +3; the shop read squat under its own upper floor)
local UPPER_H = 4.0 -- the closed lattice storey
local EAVE_Y = FLOOR + STOREY_H + UPPER_H -- 123.10, where the roof springs
local ROOF_T = 0.25 -- roof and eave both halved at the owner's gate: a kawara edge, not a slab
local EAVE_T = 0.25
-- Less the slab thickness. A tilted slab meeting at the ridge puts its upper CORNER above the
-- ridge line by roughly cos(pitch) * thickness/2, so a rise of exactly TOP - EAVE_Y overshoots the
-- owner's top by ~0.1 studs. Trivial against the 9-stud gap to the shōrō, but TOP should mean the
-- top — otherwise the envelope test has to tolerate a fudge, and a tolerated fudge grows.
local ROOF_RISE = 4.01 -- the pitch, now an input rather than whatever was left under a fixed top
local TOP = EAVE_Y + ROOF_RISE + ROOF_T -- derived; the slab's corner at the ridge is the true top
assert(TOP <= SHORO_TOP - MIN_SHORO_GAP, `machiya top {TOP} crowds the shōrō at {SHORO_TOP}`)

-- The eave overhangs the frontage by this much. THIS IS THE ONE DELIBERATE ENCROACHMENT on the
-- reserved promenade, and it is aerial: its underside sits a full storey up, so nothing at
-- ground level enters the corridor. Without it the building has no shopfront shadow and reads
-- as a shed.
local EAVE_OVERHANG = 2.5
-- THE MAIN ROOF COVERS THE UPPER STOREY ONLY (owner's gate). It used to spring from the hisashi's
-- outer edge, so one roof plane ran from the ridge all the way out over the shopfront — the
-- building read as a single shed rather than as a two-storey machiya with a shop under a separate
-- eave. Now it overhangs the WALLS by ROOF_EAVE and no further; the hisashi is its own roof.
local ROOF_EAVE = 0.8
local ROOF_RIDGE_Z = (Z0 + Z1) / 2

-- 0.7, not the recipe's 1.125. Deck posts carry a platform over a drop and are sized for it;
-- a shopfront post is a slender column standing on its own floor, and at 1.125 across a 19-stud
-- frontage the bays read as a fence rather than an opening. (Owner's gate: "too thick".)
local POST_W = 0.49 -- owner's gate: 70% of 0.7; six posts at deck weight read as a fence
local GIRDER_H, GIRDER_W = 1.2, 0.825
local WALL_T = 0.5
-- Concrete carrying MachiyaPlaster (a clone of the unused ZenMortar1 at 1.5 studs/tile). Bare
-- Sandstone renders at Roblox's own tile scale, which on a wall reads as boulders rather than
-- render. The variant is the shop's OWN, so retuning its pitch cannot disturb the cement paths.
local STUCCO_MAT = "Concrete"
local STUCCO_VAR = "MachiyaPlaster"

-- STUCCO SITS BACK; TIMBER STANDS PROUD. Everything was flush at the frontage plane, so the frame
-- and the render were coplanar and the timber simply disappeared into the wall. A timber-framed
-- building only reads if the frame is in front of the panel it holds.
local STUCCO_SETBACK = 0.22

-- The posts wear CypressVertical and came out darker; the beams they carry were plain Wood and did
-- not match. One variant for every piece of exterior frame.
local FRAME_VAR = "CypressVertical"
local KOSHI_T = 0.18
local COUNTER_H = 3.0 -- ~3 ft. 1.1 was 13 inches: a step, not a counter
local COUNTER_D = 2.0

-- inset a coordinate so a post's OUTER face sits flush with the slab edge (recipe standing rule)
local function flushX(x: number): number
    if math.abs(x - X0) < 0.01 then
        return x + POST_W / 2
    elseif math.abs(x - X1) < 0.01 then
        return x - POST_W / 2
    end
    return x
end

-- row-major rotation about X, for the roof slopes
-- Row-major rotation about X. SIGN CONVENTION, because getting it backwards builds a TROUGH
-- instead of a ridge and the tests cannot see it: row 1 is (0, c, -s), so a point at the slab's
-- +Z end maps to y' = -sin(deg) * L/2. POSITIVE deg therefore LOWERS the +Z end.
-- So: the slope whose +Z end is the RIDGE takes a NEGATIVE angle; the slope whose +Z end is the
-- EAVE takes a positive one. (Shipped inverted once, 2026-08-05 — caught by eye, not by test.)
local function rotX(deg: number): { number }
    local r = math.rad(deg)
    local c, s = math.cos(r), math.sin(r)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Machiya.build(palette: any, _layout: any): any
    local children = {}
    local timber = palette.timber
    -- STUCCO, not boards (owner's gate). Roblox has no plaster material; Sandstone over the
    -- palette's warm grey is the closest read, and quiet walls are what let the timber frame
    -- and the shoji do the talking.
    local stucco = palette.gravel
    local paper = palette.ivory
    local tile = palette.slateTile
    local ink = palette.ink

    local function add(
        name: string,
        size: { number },
        pos: { number },
        colour: { number },
        material: string,
        rot: { number }?,
        variant: string?
    )
        local props: { [string]: any } = {
            Size = size,
            CFrame = Spec.cframe(pos, rot),
            Color = colour,
            Material = material,
            CanCollide = true,
            CastShadow = false,
        }
        -- THE SHŌRŌ'S OWN ROOF TILE. Its RoofPanels are Material=Slate wearing the `SlateTile`
        -- variant (base Slate, the ambientCG kawara). Bare Slate reads as flat grey stone and made
        -- the shop look like a different building tradition standing in the same square.
        if variant then
            props.MaterialVariant = variant
        end
        table.insert(children, Spec.part(name, props))
    end

    -- ----- the raised timber floor -----
    add("FloorSlab", { W, SLAB_T, D }, { CX, FLOOR - SLAB_T / 2, CZ }, timber, "WoodPlanks")

    -- ----- the OPEN frontage: six posts, no wall -----
    local FRONT_POSTS = 5 -- owner's gate: 3 centre posts + 2 corners, down from 4 + 2
    local postX = {} -- kept so the sign boards register to the BAYS, not to the frontage
    for i = 1, FRONT_POSTS do
        local t = (i - 1) / (FRONT_POSTS - 1)
        local x = flushX(X0 + (X1 - X0) * t)
        postX[i] = x
        -- CypressVertical, not plain Wood. Roblox's Wood grain runs along the part's X axis, so on
        -- a tall thin post it bands ACROSS the timber like a stack of planks. The place already
        -- carries a vertical-grain variant for exactly this — 20 parts wear it.
        add(
            `FrontPost{i}`,
            { POST_W, STOREY_H, POST_W },
            { x, FLOOR + STOREY_H / 2, Z0 + POST_W / 2 },
            timber,
            "Wood",
            nil,
            "CypressVertical"
        )
    end

    -- ----- the shopfront: SLIDING DOORS, STANDING OPEN, UNDER SHOJI TRANSOMS -----
    -- A machiya's shopfront is not a hole — it is a run of sliding doors that have been pushed
    -- aside for the day. Rendering them open is what says "this shop is trading", and it reads far
    -- better than an empty gap: you can see what closes.
    --
    -- Each bay gets a fixed shoji transom above the head rail (kamoi) and one door leaf slid to
    -- the bay's west jamb, leaving roughly two-thirds of the opening clear. Leaves alternate which
    -- jamb they park against, because a whole row stacked the same way reads mechanical.
    -- THE KAMOI HAS TO CLEAR A PLAYER. The working avatar height is 6 studs (a bare R15 is ~5;
    -- hair adds a stud and players wear it), and this rail spans the whole frontage — at its old
    -- 3.9 you would have walked face-first into the doorway you were meant to enter.
    local HEAD_Y = FLOOR + 6.8
    local TRANSOM_TOP = FLOOR + STOREY_H - GIRDER_H
    local DOOR_Z = Z0 + STUCCO_SETBACK + 0.18 -- door plane sits behind the frame
    -- Timber front faces sit EXACTLY on the frontage plane: half the member's depth, no more. At
    -- 0.16 against a 0.34-deep member they poked 0.01 studs into the reserved promenade, which the
    -- clearance test correctly refused — a hair over the line is still over it.
    local FRAME_D2 = 0.34
    local FRAME_Z = Z0 + FRAME_D2 / 2
    local LAT_D = 0.2
    local LAT_Z = Z0 + LAT_D / 2 -- inboard of the posts, so the noren still hangs in front
    local LEAF_FRACTION = 0.36 -- how much of its bay a parked leaf covers

    -- spans the OPEN bays only; the closed ends carry their own head band
    add(
        "HeadRail",
        { postX[FRONT_POSTS - 1] - postX[2], 0.3, 0.32 },
        { (postX[2] + postX[FRONT_POSTS - 1]) / 2, HEAD_Y + 0.15, FRAME_Z },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )

    -- THE TWO OUTER BAYS ARE CLOSED (owner's gate, matching the reference). A machiya shopfront is
    -- not open end to end — the opening is the middle of the elevation with plastered wall either
    -- side. It also gives the counter something to sit against.
    local CLOSED = { [1] = true, [FRONT_POSTS - 1] = true }

    for i = 1, FRONT_POSTS - 1 do
        local a, b = postX[i], postX[i + 1]
        local bayW = (b - a) - POST_W
        local bayC = (a + b) / 2

        if CLOSED[i] then
            -- render set BACK, so the frame in front of it is what you see
            local panelH = TRANSOM_TOP - FLOOR
            add(
                `BayPanel{i}`,
                { bayW, panelH, 0.36 },
                { bayC, FLOOR + panelH / 2, Z0 + STUCCO_SETBACK + 0.18 },
                stucco,
                STUCCO_MAT,
                nil,
                STUCCO_VAR
            )
            -- the frame: sill, head and two jambs, all standing at the frontage plane
            local FR = 0.26
            add(
                `BaySill{i}`,
                { bayW + POST_W, FR, FRAME_D2 },
                { bayC, FLOOR + FR / 2, FRAME_Z },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
            add(
                `BayHead{i}`,
                { bayW + POST_W, FR, FRAME_D2 },
                { bayC, TRANSOM_TOP - FR / 2, FRAME_Z },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
            for k, jx in { bayC - bayW / 2, bayC + bayW / 2 } do
                add(
                    `BayJamb{i}_{k}`,
                    { FR, panelH, FRAME_D2 },
                    { jx, FLOOR + panelH / 2, FRAME_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
            end
            -- shoji-like lattice across the panel: a coarse grid, proud of the render
            local LAT = 0.1
            local latH = panelH - 2 * FR
            local latY = FLOOR + FR + latH / 2
            for k = 1, 4 do
                add(
                    `BayLatV{i}_{k}`,
                    { LAT, latH, LAT_D },
                    { bayC - bayW / 2 + bayW * (k / 5), latY, LAT_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
            end
            for k = 1, 3 do
                add(
                    `BayLatH{i}_{k}`,
                    { bayW, LAT, LAT_D },
                    { bayC, latY - latH / 2 + latH * (k / 4), LAT_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
            end
        else
            local tH = TRANSOM_TOP - HEAD_Y
            add(`Transom{i}`, { bayW, tH, 0.1 }, { bayC, HEAD_Y + tH / 2, DOOR_Z }, paper, "Fabric")
            for k = 1, 2 do
                add(
                    `TransomBar{i}_{k}`,
                    { 0.09, tH, 0.14 },
                    { bayC - bayW / 4 + (bayW / 2) * (k - 1), HEAD_Y + tH / 2, DOOR_Z },
                    ink,
                    "Wood"
                )
            end
            local leafW = bayW * LEAF_FRACTION
            local parkWest = i % 2 == 1
            local leafC = if parkWest then (a + POST_W / 2 + leafW / 2) else (b - POST_W / 2 - leafW / 2)
            local leafH = HEAD_Y - FLOOR
            add(`DoorLeaf{i}`, { leafW, leafH, 0.08 }, { leafC, FLOOR + leafH / 2, DOOR_Z }, paper, "Fabric")
            add(
                `DoorStileW{i}`,
                { 0.12, leafH, 0.13 },
                { leafC - leafW / 2 + 0.06, FLOOR + leafH / 2, DOOR_Z },
                timber,
                "Wood"
            )
            add(
                `DoorStileE{i}`,
                { 0.12, leafH, 0.13 },
                { leafC + leafW / 2 - 0.06, FLOOR + leafH / 2, DOOR_Z },
                timber,
                "Wood"
            )
            add(`DoorRail{i}`, { leafW, 0.14, 0.13 }, { leafC, FLOOR + leafH * 0.42, DOOR_Z }, timber, "Wood")
        end
    end

    -- ----- side and back walls (ground storey) -----
    add(
        "WallWest",
        { WALL_T, STOREY_H, D },
        { X0 + STUCCO_SETBACK + WALL_T / 2, FLOOR + STOREY_H / 2, CZ },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "WallEast",
        { WALL_T, STOREY_H, D },
        { X1 - STUCCO_SETBACK - WALL_T / 2, FLOOR + STOREY_H / 2, CZ },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "WallBack",
        { W, STOREY_H, WALL_T },
        { CX, FLOOR + STOREY_H / 2, Z1 - WALL_T / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )

    -- ----- girders + the upper floor -----
    add(
        "GirderFront",
        { W, GIRDER_H, GIRDER_W },
        { CX, FLOOR + STOREY_H - GIRDER_H / 2, Z0 + GIRDER_W / 2 },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )
    add(
        "GirderBack",
        { W, GIRDER_H, GIRDER_W },
        { CX, FLOOR + STOREY_H - GIRDER_H / 2, Z1 - GIRDER_W / 2 },
        timber,
        "Wood"
    )
    add("UpperFloor", { W, SLAB_T, D }, { CX, FLOOR + STOREY_H + SLAB_T / 2, CZ }, timber, "WoodPlanks")

    -- ----- the closed upper storey: kōshi lattice to the street, boards elsewhere -----
    -- THE UPPER STOREY HAD NO STREET WALL — just a row of lattice bars with the building's inside
    -- visible between them (owner's gate). A machiya's upper floor is a plastered wall with a
    -- mushiko-mado, an "insect-cage" window: mostly wall, one banded lattice opening. So the wall
    -- is built in four pieces AROUND the window, and the kōshi fills the opening rather than
    -- standing in for the wall.
    local UPPER_Y0 = FLOOR + STOREY_H
    local WIN_H = 2.0
    local WIN_Y0 = UPPER_Y0 + (UPPER_H - WIN_H) / 2
    local WIN_HALF = 6.0 -- the opening reaches WIN_HALF either side of centre
    local WIN_X0, WIN_X1 = CX - WIN_HALF, CX + WIN_HALF
    local UF_Z = Z0 + STUCCO_SETBACK + WALL_T / 2 -- set back; the kōshi and the sign stand proud of it

    local belowH = WIN_Y0 - UPPER_Y0
    local aboveH = (UPPER_Y0 + UPPER_H) - (WIN_Y0 + WIN_H)
    add(
        "UpperWallFrontLow",
        { W, belowH, WALL_T },
        { CX, UPPER_Y0 + belowH / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallFrontHigh",
        { W, aboveH, WALL_T },
        { CX, WIN_Y0 + WIN_H + aboveH / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    local jambW = WIN_X0 - X0
    add(
        "UpperWallFrontWest",
        { jambW, WIN_H, WALL_T },
        { X0 + jambW / 2, WIN_Y0 + WIN_H / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallFrontEast",
        { jambW, WIN_H, WALL_T },
        { X1 - jambW / 2, WIN_Y0 + WIN_H / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )

    -- the kōshi, now filling the window band only
    local KOSHI_N = 18
    for i = 1, KOSHI_N do
        local t = (i - 0.5) / KOSHI_N
        add(
            `Koshi{i}`,
            { KOSHI_T, WIN_H, KOSHI_T },
            { WIN_X0 + (WIN_X1 - WIN_X0) * t, WIN_Y0 + WIN_H / 2, Z0 + KOSHI_T },
            ink,
            "Wood"
        )
    end

    add(
        "UpperWallWest",
        { WALL_T, UPPER_H, D },
        { X0 + WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, CZ },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallEast",
        { WALL_T, UPPER_H, D },
        { X1 - WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, CZ },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallBack",
        { W, UPPER_H, WALL_T },
        { CX, FLOOR + STOREY_H + UPPER_H / 2, Z1 - WALL_T / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )

    -- ----- the eave over the shopfront: aerial, a full storey up -----
    -- It TILTS. A flat hisashi reads as a shelf; the whole point of the shopfront eave is that it
    -- sheds toward the street and throws the goods into shade. It springs from the upper-floor
    -- line and drops HISASHI_DROP over its projection — so its +Z end (at the building) is the
    -- high one, which by the sign convention above means a NEGATIVE angle.
    local HISASHI_DROP = 0.5
    local hisashiDeg = math.deg(math.atan2(HISASHI_DROP, EAVE_OVERHANG))
    local hisashiLen = math.sqrt(EAVE_OVERHANG * EAVE_OVERHANG + HISASHI_DROP * HISASHI_DROP)
    add(
        "Eave",
        { W + 1.0, EAVE_T, hisashiLen },
        { CX, FLOOR + STOREY_H - HISASHI_DROP / 2, Z0 - EAVE_OVERHANG / 2 },
        tile,
        "Slate",
        rotX(-hisashiDeg),
        "SlateTile"
    )

    -- ----- the roof: a gabled kirizuma, ridge running east-west along the street -----
    -- Machiya are hirairi — you enter on the long side, under the eave, with the gables at the
    -- ends. Two slopes, symmetric about a ridge centred on the ROOF span (which reaches further
    -- north than the walls because of the overhang).
    local frontRun = ROOF_RIDGE_Z - (Z0 - ROOF_EAVE)
    local backRun = (Z1 + ROOF_EAVE) - ROOF_RIDGE_Z
    local frontLen = math.sqrt(frontRun * frontRun + ROOF_RISE * ROOF_RISE)
    local backLen = math.sqrt(backRun * backRun + ROOF_RISE * ROOF_RISE)
    local frontDeg = math.deg(math.atan2(ROOF_RISE, frontRun))
    local backDeg = math.deg(math.atan2(ROOF_RISE, backRun))

    add(
        "RoofNorth",
        { W + 1.0, ROOF_T, frontLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (Z0 - ROOF_EAVE + ROOF_RIDGE_Z) / 2 },
        tile,
        "Slate",
        rotX(-frontDeg), -- +Z end is the RIDGE: negative angle raises it
        "SlateTile"
    )
    add(
        "RoofSouth",
        { W + 1.0, ROOF_T, backLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1 + ROOF_EAVE) / 2 },
        tile,
        "Slate",
        rotX(backDeg), -- +Z end is the back EAVE: positive angle drops it
        "SlateTile"
    )
    add("Ridge", { W + 1.2, 0.4, 0.6 }, { CX, TOP - 0.2, ROOF_RIDGE_Z }, ink, "Slate", nil, "SlateTile")

    -- Gable ends. Each is TWO right triangles back to back, which is what an isosceles gable is.
    --
    -- A WedgePart's TALL EDGE IS AT +Z, its thin edge at -Z. Established by building it the other
    -- way round first (2026-08-05): the gables came out as a notch — tall at both eaves, dipping
    -- at the ridge — the exact inverse of the roof. So the half whose +Z end is the RIDGE is the
    -- wedge unturned, and the half whose +Z end is the EAVE is turned 180° about Y.
    --
    -- North half spans front eave (low, -Z) -> ridge (high, +Z): unturned.
    -- South half spans ridge (high, -Z) -> back eave (low, +Z): turned.
    local GABLE_T = 0.4
    for _, end_ in { { "West", X0 + GABLE_T / 2 }, { "East", X1 - GABLE_T / 2 } } do
        local name, x = end_[1] :: string, end_[2] :: number
        table.insert(
            children,
            Spec.part(`Gable{name}North`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, frontRun },
                CFrame = Spec.cframe({ x, EAVE_Y + ROOF_RISE / 2, (Z0 - ROOF_EAVE + ROOF_RIDGE_Z) / 2 }),
                Color = stucco,
                Material = STUCCO_MAT,
                MaterialVariant = STUCCO_VAR,
                CanCollide = true,
                CastShadow = false,
            })
        )
        table.insert(
            children,
            Spec.part(`Gable{name}South`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, backRun },
                CFrame = Spec.cframe(
                    { x, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1 + ROOF_EAVE) / 2 },
                    { -1, 0, 0, 0, 1, 0, 0, 0, -1 }
                ),
                Color = stucco,
                Material = STUCCO_MAT,
                MaterialVariant = STUCCO_VAR,
                CanCollide = true,
                CastShadow = false,
            })
        )
    end

    -- ----- noren: the split curtain, over the OPENING only -----
    -- It hung at 7.9 studs, which on a 9-stud storey is nearly at the ceiling — a noren you cannot
    -- brush through is a valance. It now hangs from the door head down to 4.2, so you part it on
    -- the way in. And it covers the OPEN bays only: a curtain in front of a plastered wall is
    -- advertising a door that is not there.
    local NOREN_TOP = HEAD_Y
    local NOREN_H = 2.6
    local nSpanA, nSpanB = postX[2], postX[FRONT_POSTS - 1]
    local NOREN_N = 3
    local nSpan = nSpanB - nSpanA
    local norenW = nSpan / NOREN_N - 0.25
    for i = 1, NOREN_N do
        local t = (i - 0.5) / NOREN_N
        table.insert(
            children,
            Spec.part(`Noren{i}`, {
                Size = { norenW, NOREN_H, 0.08 },
                CFrame = Spec.cframe({ nSpanA + nSpan * t, NOREN_TOP - NOREN_H / 2, Z0 + 0.06 }),
                Color = palette.vermilion,
                Material = "Fabric",
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
            })
        )
    end

    -- ----- the counter -----
    add(
        "Counter",
        -- Spans only the OPEN bays now that the outer two are closed, and sits deep in the shop so
        -- the goods are behind it rather than on the street.
        { postX[FRONT_POSTS - 1] - postX[2] - POST_W, COUNTER_H, COUNTER_D },
        { (postX[2] + postX[FRONT_POSTS - 1]) / 2, FLOOR + COUNTER_H / 2, Z0 + 4.6 },
        timber,
        "WoodPlanks"
    )

    -- ----- the sign: ONE FRAMED BOARD -----
    -- Three separate boards were a workaround for a bug: the glyphs were tiny because SizingMode
    -- was ignoring PixelsPerStud, and splitting them was the only way to make each one big enough
    -- to read. With the canvas fixed they no longer need to be split, so the sign is one board
    -- again — dark ink on a light ground in a plain timber frame, which is what a kanban is.
    -- Sized to the CHARACTERS, not to the building. At 0.62 of the frontage the board was half
    -- empty and the name floated in the middle of it. Three glyphs on a 2.6-stud board want about
    -- 3:1 — the text then fills ~86% of the canvas instead of 60%.
    local SIGN_H = 2.6
    local SIGN_W = SIGN_H * 3.0
    local SIGN_Y = FLOOR + STOREY_H + UPPER_H / 2
    local SIGN_Z = Z0 - 0.15 -- just proud of the kōshi lattice, not of the frontage
    local FRAME_W = 0.32 -- the surround's member width
    local FRAME_D = 0.34 -- deeper than the panel, so the frame stands proud of it

    -- TILTED 15 DEGREES, TOP TOWARD THE PATH (owner's gate). A sign flat against the facade is
    -- read edge-on by anyone standing under it; leaning the top out turns its face toward the
    -- promenade below. By the rotX sign convention, tipping the TOP toward -Z (north, the street)
    -- is a NEGATIVE angle.
    local SIGN_TILT = -15
    local ST = rotX(SIGN_TILT)
    -- offsets in the board's own plane, rotated with it, so the frame stays on the board
    local function signPos(dx: number, dy: number): { number }
        return { CX + dx, SIGN_Y + ST[5] * dy, SIGN_Z + ST[8] * dy }
    end

    table.insert(
        children,
        Spec.part("Kanban", {
            Size = { SIGN_W, SIGN_H, 0.22 },
            CFrame = Spec.cframe({ CX, SIGN_Y, SIGN_Z }, ST),
            -- Stucco, matching the walls (owner's gate). A plastered board with the name cut into
            -- it belongs to the building; a pale timber panel read as a separate object hung on it.
            Color = stucco,
            Material = STUCCO_MAT,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
            children = {
                {
                    name = "Face",
                    className = "SurfaceGui",
                    properties = {
                        Face = "Front", -- -Z, which is north: onto the promenade
                        -- SIZINGMODE IS THE WHOLE TRICK. It defaults to FixedSize, under which the
                        -- canvas is CanvasSize (800x600) and PixelsPerStud is IGNORED — which is
                        -- why an 80px glyph once rendered as a speck. In PixelsPerStud mode the
                        -- canvas comes from the part, so the character fills its board.
                        SizingMode = "PixelsPerStud",
                        PixelsPerStud = 32,
                        AlwaysOnTop = false,
                        ZIndexBehavior = "Sibling",
                    },
                    children = {
                        {
                            name = "Text",
                            className = "TextLabel",
                            properties = {
                                Size = { UDim2 = { { 1, 0 }, { 1, 0 } } },
                                BackgroundTransparency = 1,
                                Text = "花火屋",
                                TextColor3 = ink, -- dark letters on the light ground
                                TextSize = 72,
                                Font = "GothamBold",
                            },
                        },
                    },
                },
            },
        })
    )

    -- The surround: four plain members, mitre-free, lapped at the corners the way a cheap shop
    -- sign is actually made.
    for _, m in
        {
            { "KanbanFrameTop", SIGN_W + 2 * FRAME_W, FRAME_W, 0, SIGN_H / 2 + FRAME_W / 2 },
            { "KanbanFrameBottom", SIGN_W + 2 * FRAME_W, FRAME_W, 0, -(SIGN_H / 2 + FRAME_W / 2) },
            { "KanbanFrameWest", FRAME_W, SIGN_H, -(SIGN_W / 2 + FRAME_W / 2), 0 },
            { "KanbanFrameEast", FRAME_W, SIGN_H, SIGN_W / 2 + FRAME_W / 2, 0 },
        }
    do
        add(
            m[1] :: string,
            { m[2] :: number, m[3] :: number, FRAME_D },
            signPos(m[4] :: number, m[5] :: number),
            timber,
            "Wood",
            ST
        )
    end

    -- ----- the trigger volume -----
    -- Inset one stud from the frontage. See ShopThreshold.FRONT_INSET for why: flush with the
    -- frontage it would fire on everyone crossing the square.
    local tz0 = Z0 + 1
    -- TALL ENOUGH THAT A JUMP CANNOT LEAVE IT. The test is against the HumanoidRootPart, which
    -- stands ~3 studs above the floor and rises ~7 more at the apex of a default jump — so a box
    -- only storey-high (it was 4.9) lets the panel blink off mid-air while the player never left
    -- the shop. 14 puts the ceiling ~4 studs clear of that apex. It costs nothing to be generous:
    -- this is a trigger volume, invisible and non-colliding, so its height is not geometry and
    -- rising past the eave line is not a visual fact anyone can see.
    local TH_H = 14
    table.insert(
        children,
        Spec.part("Threshold", {
            Size = { W, TH_H, Z1 - tz0 },
            CFrame = Spec.cframe({ CX, FLOOR + TH_H / 2, (tz0 + Z1) / 2 }),
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )

    return Spec.model("Hanabiya", children)
end

return Machiya
