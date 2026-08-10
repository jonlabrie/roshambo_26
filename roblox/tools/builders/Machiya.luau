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
local TOP = 127.36 -- ridge. The shōrō tops at 136.5 and must stay above it.

local W = X1 - X0
local D = Z1 - Z0
local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2

-- ===== storey heights, derived from the envelope so they cannot drift out of it =====
local SLAB_T = 0.6 -- the raised timber floor, recipe §2's deck slab
local STOREY_H = 6.0 -- ground storey: clear height under the upper floor
local UPPER_H = 4.0 -- the closed lattice storey
local EAVE_Y = FLOOR + STOREY_H + UPPER_H -- 123.10, where the roof springs
local ROOF_T = 0.25 -- roof and eave both halved at the owner's gate: a kawara edge, not a slab
local EAVE_T = 0.25
-- Less the slab thickness. A tilted slab meeting at the ridge puts its upper CORNER above the
-- ridge line by roughly cos(pitch) * thickness/2, so a rise of exactly TOP - EAVE_Y overshoots the
-- owner's top by ~0.1 studs. Trivial against the 9-stud gap to the shōrō, but TOP should mean the
-- top — otherwise the envelope test has to tolerate a fudge, and a tolerated fudge grows.
local ROOF_RISE = TOP - EAVE_Y - ROOF_T

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
local POST_W = 0.7
local GIRDER_H, GIRDER_W = 1.2, 0.825
local WALL_T = 0.5
local STUCCO_MAT = "Sandstone"
local KOSHI_T = 0.18
local COUNTER_H = 1.1
local COUNTER_D = 1.4

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
    local FRONT_POSTS = 6
    local postX = {} -- kept so the sign boards register to the BAYS, not to the frontage
    for i = 1, FRONT_POSTS do
        local t = (i - 1) / (FRONT_POSTS - 1)
        local x = flushX(X0 + (X1 - X0) * t)
        postX[i] = x
        add(
            `FrontPost{i}`,
            { POST_W, STOREY_H, POST_W },
            { x, FLOOR + STOREY_H / 2, Z0 + POST_W / 2 },
            timber,
            "Wood"
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
    local HEAD_Y = FLOOR + 3.9 -- the kamoi: door head / transom sill
    local TRANSOM_TOP = FLOOR + STOREY_H - GIRDER_H
    local DOOR_Z = Z0 + 0.55 -- inboard of the posts, so the noren still hangs in front
    local LEAF_FRACTION = 0.36 -- how much of its bay a parked leaf covers

    add("HeadRail", { W - 2 * WALL_T, 0.3, 0.32 }, { CX, HEAD_Y + 0.15, DOOR_Z }, timber, "Wood")

    for i = 1, FRONT_POSTS - 1 do
        local a, b = postX[i], postX[i + 1]
        local bayW = (b - a) - POST_W
        local bayC = (a + b) / 2

        -- the fixed shoji transom (ranma) above the head rail
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

        -- the door leaf, parked against one jamb; alternate sides down the row
        local leafW = bayW * LEAF_FRACTION
        local parkWest = i % 2 == 1
        local leafC = if parkWest then (a + POST_W / 2 + leafW / 2) else (b - POST_W / 2 - leafW / 2)
        local leafH = HEAD_Y - FLOOR
        add(`DoorLeaf{i}`, { leafW, leafH, 0.08 }, { leafC, FLOOR + leafH / 2, DOOR_Z }, paper, "Fabric")
        -- its stile-and-rail frame, enough to read as joinery rather than a panel
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

    -- ----- side and back walls (ground storey) -----
    add(
        "WallWest",
        { WALL_T, STOREY_H, D },
        { X0 + WALL_T / 2, FLOOR + STOREY_H / 2, CZ },
        stucco,
        STUCCO_MAT
    )
    add(
        "WallEast",
        { WALL_T, STOREY_H, D },
        { X1 - WALL_T / 2, FLOOR + STOREY_H / 2, CZ },
        stucco,
        STUCCO_MAT
    )
    add(
        "WallBack",
        { W, STOREY_H, WALL_T },
        { CX, FLOOR + STOREY_H / 2, Z1 - WALL_T / 2 },
        stucco,
        STUCCO_MAT
    )

    -- ----- girders + the upper floor -----
    add(
        "GirderFront",
        { W, GIRDER_H, GIRDER_W },
        { CX, FLOOR + STOREY_H - GIRDER_H / 2, Z0 + GIRDER_W / 2 },
        timber,
        "Wood"
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
    local KOSHI_N = 14
    for i = 1, KOSHI_N do
        local t = (i - 0.5) / KOSHI_N
        add(
            `Koshi{i}`,
            { KOSHI_T, UPPER_H, KOSHI_T },
            { X0 + (X1 - X0) * t, FLOOR + STOREY_H + UPPER_H / 2, Z0 + KOSHI_T },
            ink,
            "Wood"
        )
    end
    add(
        "UpperWallWest",
        { WALL_T, UPPER_H, D },
        { X0 + WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, CZ },
        stucco,
        STUCCO_MAT
    )
    add(
        "UpperWallEast",
        { WALL_T, UPPER_H, D },
        { X1 - WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, CZ },
        stucco,
        STUCCO_MAT
    )
    add(
        "UpperWallBack",
        { W, UPPER_H, WALL_T },
        { CX, FLOOR + STOREY_H + UPPER_H / 2, Z1 - WALL_T / 2 },
        stucco,
        STUCCO_MAT
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
                CanCollide = true,
                CastShadow = false,
            })
        )
    end

    -- ----- noren: the split curtain under the eave, the sign that a shop is OPEN -----
    -- Four panels with gaps, hung from the eave line. Non-collidable: you walk through a noren.
    -- Hung at the frontage line itself (not out under the overhang) — the promenade corridor
    -- north of Z0 is reserved at ground level for everything but the (aerial) eave; a curtain
    -- that dipped to head height out there would violate that even though it can't be walked
    -- into.
    local NOREN_N = 4
    local norenSpan = W * 0.8
    local norenW = norenSpan / NOREN_N - 0.25
    for i = 1, NOREN_N do
        local t = (i - 0.5) / NOREN_N
        table.insert(
            children,
            Spec.part(`Noren{i}`, {
                Size = { norenW, 2.2, 0.08 },
                CFrame = Spec.cframe({
                    CX - norenSpan / 2 + norenSpan * t,
                    FLOOR + STOREY_H - 1.1,
                    Z0 + 0.4,
                }),
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
        { W - 2 * WALL_T - 1.0, COUNTER_H, COUNTER_D },
        { CX, FLOOR + COUNTER_H / 2, Z0 + 2.6 },
        timber,
        "WoodPlanks"
    )

    -- ----- the sign: ONE FRAMED BOARD -----
    -- Three separate boards were a workaround for a bug: the glyphs were tiny because SizingMode
    -- was ignoring PixelsPerStud, and splitting them was the only way to make each one big enough
    -- to read. With the canvas fixed they no longer need to be split, so the sign is one board
    -- again — dark ink on a light ground in a plain timber frame, which is what a kanban is.
    local SIGN_W = W * 0.62
    local SIGN_H = 2.6
    local SIGN_Y = FLOOR + STOREY_H + UPPER_H / 2
    local SIGN_Z = Z0 - 0.15 -- just proud of the kōshi lattice, not of the frontage
    local FRAME_W = 0.32 -- the surround's member width
    local FRAME_D = 0.34 -- deeper than the panel, so the frame stands proud of it

    table.insert(
        children,
        Spec.part("Kanban", {
            Size = { SIGN_W, SIGN_H, 0.22 },
            CFrame = Spec.cframe({ CX, SIGN_Y, SIGN_Z }),
            Color = paper,
            Material = "WoodPlanks",
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
            { CX + (m[4] :: number), SIGN_Y + (m[5] :: number), SIGN_Z },
            timber,
            "Wood"
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
