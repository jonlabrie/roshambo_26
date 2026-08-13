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
-- DEEPENED 2026-08-13, front edge only: z44 -> z36. The shop held about three people, because a
-- counter 4.6 studs in left barely three studs of floor to stand on. The back is fixed — it is the
-- terrain cut — so the depth had to come off the front, and it does so at the owner's direction:
-- the karesansui is to be reduced to the shōrō's own footprint, which gives the promenade back
-- more than this takes. Until that lands the street is narrower here; the eave's encroachment is
-- still aerial and still clears an avatar, which the tests hold.
local Z0, Z1 = 36.00, 52.00 -- frontage (north, onto the promenade), back (south, into the cut)
local FLOOR = 113.10 -- finished floor, = the karesansui datum

-- THE HOLDOUT'S TOP IS RETIRED (owner: "approximate, and can be safely ignored"). The height now
-- comes from the storeys, and the REAL constraint is the one that always mattered: the shop must
-- stay clearly subordinate to the bell tower. TOP is derived at the bottom of this block and
-- checked against these two numbers, so growing a storey can never quietly close the gap.
--
-- THE TOWER IS A STACK, AND THIS NUMBER USED TO NAME ITS MIDDLE. It was 136.5 — the top of the
-- Shoro model — but the tower is seven models and the drum storey stands ON the shōrō's roof:
--
--   Shoro 112.00..136.20   ShoroRoof 133.55..136.47   ThrowDrum 135.23..153.54
--   RanmaCarvings 140.37..147.63   BellDrive 110.00..141.60   BonshoRig 116.95..134.50
--
-- Measured in Studio 2026-08-13 across every RoshamboStage model sharing the tower's footprint.
-- The error was 17 studs and it ran the wrong way: it made the shop look like it was crowding a
-- tower it clears by 22. Re-measure the same way if the tower is redesigned — one model's
-- bounding box is not a building.
local SHORO_TOP = 153.54
-- The OWNER'S number, from the spec: the shop tops "9 studs subordinate to the bell tower, which
-- is the relationship the square depends on." This used to be 5.0 — a floor I invented when the
-- holdout's top was retired, and then quoted back as though it were a gate they had set.
local MIN_SHORO_GAP = 9.0

local W = X1 - X0
local D = Z1 - Z0
local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2

-- ===== storey heights, derived from the envelope so they cannot drift out of it =====
local SLAB_T = 0.6 -- the raised timber floor, recipe §2's deck slab
local STOREY_H = 9.0 -- ground storey (owner's gate: +3; the shop read squat under its own upper floor)
-- 5.0, up a stud at the owner's gate: at 4.0 a player climbing the stair put their head through
-- the roof, and in first person you could see sky through the ceiling. The attic was simply
-- shorter than a person and nothing measured it. The stud comes from HERE rather than from a
-- lower attic floor because lowering the floor means shortening the ground storey (dropping it
-- alone drops the eave with it and gains nothing) — and at STOREY_H 8.0 the shopfront's shoji
-- transom collapses to zero height, the kamoi being fixed at 6.8 for avatar clearance.
local UPPER_H = 5.0 -- the closed lattice storey
local EAVE_Y = FLOOR + STOREY_H + UPPER_H -- where the roof springs
local ROOF_T = 0.25 -- roof and eave both halved at the owner's gate: a kawara edge, not a slab
local EAVE_T = 0.25
-- Less the slab thickness. A tilted slab meeting at the ridge puts its upper CORNER above the
-- ridge line by roughly cos(pitch) * thickness/2, so a rise of exactly TOP - EAVE_Y overshoots the
-- owner's top by ~0.1 studs. Trivial against the 9-stud gap to the shōrō, but TOP should mean the
-- top — otherwise the envelope test has to tolerate a fudge, and a tolerated fudge grows.
local ROOF_RISE = 4.01 -- the pitch, now an input rather than whatever was left under a fixed top
local TOP = EAVE_Y + ROOF_RISE + ROOF_T -- derived; the slab's corner at the ridge is the true top
-- NOT A CLEARANCE — the two buildings stand 15.9 studs apart in z and nothing overhangs anything.
-- This is about the SKYLINE: the bell tower is meant to read as the tallest thing in the square.
-- At 131.36 against the tower's 153.54 the shop clears it by 22.18, comfortably past the owner's
-- 9. There is no tension here, and the old message said "crowds", which read as a collision and
-- sent me chasing a conflict that does not exist.
assert(
    TOP <= SHORO_TOP - MIN_SHORO_GAP,
    `machiya top {TOP} reads too tall beside the bell tower's {SHORO_TOP}`
)

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
local STUCCO_SETBACK = 0.30

-- THE STUCCO BOX. Every render plane is a face of ONE inset box, derived here, because deriving
-- them separately is how the building came apart: the side walls were moved in by the setback
-- while the front, the back and the gables still spanned the full envelope, so each panel was
-- inset on its own axis and oversized on the others. A wall's IN-PLANE dimensions have to shrink
-- with the box too, not just its own offset.
--   SX0/SX1 — the render's west/east faces      SZ1 — its back face
--   SZ0     — the upper storey's street face (the ground storey opens instead)
local SX0, SX1 = X0 + STUCCO_SETBACK, X1 - STUCCO_SETBACK
local SZ0, SZ1 = Z0 + STUCCO_SETBACK, Z1 - STUCCO_SETBACK
local SW = SX1 - SX0 -- the box's width; NOT W
-- Side walls run BETWEEN the box's front and back faces. Running them to Z0 put their front
-- edge exactly on the corner post's front face — proud on one axis and flush on the other reads
-- as flush.
local SD = SZ1 - SZ0

-- The posts wear CypressVertical and came out darker; the beams they carry were plain Wood and did
-- not match. One variant for every piece of exterior frame.
local FRAME_VAR = "CypressVertical"
local KOSHI_T = 0.18
local COUNTER_H = 3.0 -- ~3 ft. 1.1 was 13 inches: a step, not a counter
local COUNTER_D = 2.0
-- Back wall to the counter's CENTRE. Pulled a stud forward at the owner's gate so a shopkeeper
-- can stand behind it: 1.6 studs of clearance is a shelf, 2.6 is a place to work.
local COUNTER_STANDOFF = 4.4
local COUNTER_Z = Z1 - COUNTER_STANDOFF
local COUNTER_BACK_Z = COUNTER_Z + COUNTER_D / 2

-- ===== the stair to the upper storey =====
-- Along the EAST wall, climbing NORTH from the counter's back edge (the owner set its foot there,
-- so it is derived from the counter and moves with it rather than being a second magic number).
-- Deliberately steep and narrow — a machiya's stair is nearer a ladder than a staircase, and one
-- body wide is the honest width for a shop this size.
local UPPER_SURFACE = FLOOR + STOREY_H + SLAB_T -- what you stand on upstairs
local STAIR_TREADS = 11
-- The last riser is the upper floor itself, so TREADS+1 risers span the storey. Asserted rather
-- than trusted: a rise that does not divide leaves a final step of the wrong height, which reads
-- as a stumble in Play and as nothing at all in the explorer.
local STAIR_RISE = (UPPER_SURFACE - FLOOR) / (STAIR_TREADS + 1)
assert(math.abs(STAIR_RISE - 0.8) < 1e-9, `stair rise {STAIR_RISE} is not the intended 0.8`)
local STAIR_RUN = 0.72 -- 48° — steep, which is the point
local STAIR_W = 3.2 -- OUTER to outer, stringers included
local STRINGER_T = 0.45
local STRINGER_H = 0.60
-- How deep a tread is let into its stringer. The treads used to run the full width, so their ends
-- finished flush with the stringers' outer faces and the joint read as a butt rather than a
-- housing. Now the stringer stands proud of the tread end by (STRINGER_T - TREAD_HOUSING) and you
-- can see the tread go into it.
local TREAD_HOUSING = 0.30
assert(TREAD_HOUSING < STRINGER_T, "a tread housed the full thickness of its stringer cuts it in two")
local TREAD_W = STAIR_W - 2 * (STRINGER_T - TREAD_HOUSING)
local TREAD_T = 0.28
-- NOT the frame's CypressVertical. That variant's maps are ROTATED 90° and it exists for flat
-- VERTICAL members — on a tread, which is a horizontal board, the grain ran across the plank
-- instead of along it. CypressWeathered is the unrotated timber the bridge decking wears.
local STAIR_VAR = "CypressWeathered"

-- The stairwell. Its south edge is set by HEADROOM, not by taste: a climber on tread k has their
-- feet at FLOOR + k*RISE and wants a working avatar's 6 studs above that, against an underside at
-- FLOOR + STOREY_H. Treads 1 and 2 pass under it comfortably; the third would clear by about half
-- a stud, which is no clearance at all once a body has depth, so the cut opens at the third.
local STAIR_HEAD_CLEAR = 2 -- treads that stay under the upper floor
-- The invariant is that no COVERED tread traps a climber. Opening a tread earlier than strictly
-- required is a margin and is fine; opening one later is a low beam you cannot see in the
-- explorer. Strict headroom would allow three covered treads (the third clears by 0.6) — the
-- third is given away on purpose, because 0.6 studs is not clearance once a body has depth.
assert(
    FLOOR + STAIR_HEAD_CLEAR * STAIR_RISE + 6.0 <= FLOOR + STOREY_H,
    "the stairwell opens too late — a climber meets the upper floor before the cut"
)
local WELL_Z1 = COUNTER_BACK_Z - STAIR_HEAD_CLEAR * STAIR_RUN
local WELL_Z0 = COUNTER_BACK_Z - STAIR_TREADS * STAIR_RUN
-- Hard against the east wall's inner face, and the well is cut a little wider than the stair so a
-- climber's shoulders are not clipping the floor edge on the way up.
local STAIR_X1 = SX1 - WALL_T
local STAIR_X0 = STAIR_X1 - STAIR_W
local WELL_X0 = STAIR_X0 - 0.2

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
    -- "Wood" + the frame variant, matching the upper floor. WoodPlanks with no variant is the
    -- pale timber the building has been moving away from — and a variant set on a WoodPlanks part
    -- would be silently dropped anyway, which is how the upper floor stayed pale twice.
    add("FloorSlab", { W, SLAB_T, D }, { CX, FLOOR - SLAB_T / 2, CZ }, timber, "Wood", nil, FRAME_VAR)

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
    -- BEHIND the closed bays' panels (which sit at STUCCO_SETBACK + 0.18, 0.36 thick), so a
    -- screen slid aside is genuinely occluded by the wall rather than poking through it.
    local DOOR_Z = Z0 + STUCCO_SETBACK + 0.62
    -- Timber front faces sit EXACTLY on the frontage plane: half the member's depth, no more. At
    -- 0.16 against a 0.34-deep member they poked 0.01 studs into the reserved promenade, which the
    -- clearance test correctly refused — a hair over the line is still over it.
    local FRAME_D2 = 0.34
    local FRAME_Z = Z0 + FRAME_D2 / 2
    local LAT_D = 0.2
    local LAT_Z = Z0 + LAT_D / 2 -- inboard of the posts, so the noren still hangs in front

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
            -- THE SCREEN IS FULL BAY WIDTH AND SLID TWO-THIRDS AWAY, so the opening is 2/3 clear
            -- and the hidden third-and-a-bit sits BEHIND the closed bay next to it. That is how a
            -- sliding screen actually works — it does not shrink, it goes somewhere. It parks
            -- toward whichever neighbouring bay is closed, which is what gives it somewhere to go.
            local leafW = bayW
            local openW = bayW
            local parkWest = CLOSED[i - 1] == true
            local leafC = if parkWest then (a + POST_W / 2 - openW / 6) else (b - POST_W / 2 + openW / 6)
            -- The screen RUNS IN A TRACK and closes with a rail top and bottom. Its stiles used
            -- to end at floor level with no bottom member, so the frame terminated into the floor
            -- instead of closing against it — which reads as buried, because nothing caps it.
            local RAIL_T = 0.16
            local leafY0 = FLOOR + 0.1 -- the track it slides in
            local leafH = HEAD_Y - leafY0
            local leafCY = leafY0 + leafH / 2
            -- The paper is INSET inside its own frame. At full leaf size its edges landed exactly on
            -- the stiles', so the sheet was visible edge-on — a pane the same size as its sash.
            -- Real shoji paper is glued behind the frame and stops short of it on every side.
            add(
                `DoorLeaf{i}`,
                { leafW - 2 * 0.16, leafH - 2 * RAIL_T, 0.05 },
                { leafC, leafCY, DOOR_Z },
                paper,
                "Fabric"
            )
            -- stiles, rails and a proper kumiko grid, all in the frame's dark wood
            for k, sx in { leafC - leafW / 2 + 0.07, leafC + leafW / 2 - 0.07 } do
                add(
                    `DoorStile{i}_{k}`,
                    { 0.14, leafH, 0.15 },
                    { sx, leafCY, DOOR_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
            end
            for k, ry in { leafY0 + RAIL_T / 2, HEAD_Y - RAIL_T / 2 } do
                add(
                    `DoorRail{i}_{k}`,
                    { leafW, RAIL_T, 0.15 },
                    { leafC, ry, DOOR_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
            end
            local LAT_N_V, LAT_N_H = 5, 7
            for k = 1, LAT_N_V do
                add(
                    `DoorLatV{i}_{k}`,
                    { 0.075, leafH, 0.13 },
                    { leafC - leafW / 2 + leafW * (k / (LAT_N_V + 1)), leafCY, DOOR_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
            end
            for k = 1, LAT_N_H do
                add(
                    `DoorLatH{i}_{k}`,
                    { leafW, 0.075, 0.13 },
                    { leafC, leafY0 + leafH * (k / (LAT_N_H + 1)), DOOR_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
            end
        end
    end

    -- ----- side and back walls (ground storey) -----
    add(
        "WallWest",
        { WALL_T, STOREY_H, SD },
        { SX0 + WALL_T / 2, FLOOR + STOREY_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "WallEast",
        { WALL_T, STOREY_H, SD },
        { SX1 - WALL_T / 2, FLOOR + STOREY_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "WallBack",
        -- BETWEEN the side walls, not across them. At the full SW its end faces landed on exactly
        -- the same planes as the side walls' outer faces, which is the same coplanar-face defect
        -- the stairwell flickered from — found on the back corners while checking that fix. The
        -- side walls run the full depth, so they close the corner and nothing opens up.
        { SW - 2 * WALL_T, STOREY_H, WALL_T },
        { CX, FLOOR + STOREY_H / 2, SZ1 - WALL_T / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )

    -- ----- THE FRAME ON THE FLANKS -----
    -- From the side the building read as one plane of render with no structure in it — the posts
    -- and beams only ever existed on the street elevation. A machiya's flank shows its frame:
    -- corner posts, an intermediate one, and a nageshi band at the storey division. All stand
    -- proud of the wall behind them, which is the whole point.
    -- STUCCO FILLS, TIMBER DIVIDES. The reference's flank is mostly render, gridded by dark
    -- posts and horizontal bands, with a boarded skirt at the bottom where the street reaches it.
    -- The previous pass clad the whole flank in timber, which inverted the relationship: the frame
    -- is supposed to be the minority.
    -- THE BAY MODULE IS WHAT IS FIXED, not the bay count. The owner's gate here was against an
    -- IRREGULAR rhythm — four posts once gave bays of 2.2 / 2.6 / 1.9, which read as a mistake
    -- rather than as a frame — and three posts over an 8-deep flank happened to give two equal
    -- 4-stud bays. Doubling the depth with that count would have stretched them to 8 studs and
    -- coarsened the whole elevation, so the module holds at 4 and the count follows the depth.
    -- The bays are equal BY CONSTRUCTION, which is the property that was actually gated.
    --
    -- The GROUND storey shares its front corner with the street elevation (FrontPost1/5 stand
    -- there, and a SidePost at the same z would put a second post in the same cubic space). The
    -- UPPER storey does not — FrontPost stops at the upper floor — so upstairs the front corner
    -- had no post at all. Two lists, because the two storeys genuinely differ.
    local FLANK_BAYS = math.max(2, math.round(D / 4.0))
    local SIDE_POST_Z, UPPER_POST_Z = {}, {}
    for k = 0, FLANK_BAYS do
        -- End posts inset half a post so they sit inside the envelope; the span between those
        -- insets is what divides, which is why the middle post lands exactly on CZ.
        local pz = Z0 + POST_W / 2 + (k / FLANK_BAYS) * (D - POST_W)
        table.insert(UPPER_POST_Z, pz)
        if k > 0 then
            table.insert(SIDE_POST_Z, pz)
        end
    end
    local BAND_T = 0.3
    local SKIRT_H = 1.3
    for _, side in { { "West", X0 + POST_W / 2 }, { "East", X1 - POST_W / 2 } } do
        local nm, px = side[1] :: string, side[2] :: number
        -- vertical posts, ground storey AND upper, so the grid runs the full elevation
        for k, pz in SIDE_POST_Z do
            add(
                `SidePost{nm}{k}`,
                { POST_W, STOREY_H, POST_W },
                { px, FLOOR + STOREY_H / 2, pz },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
        -- The upper storey's own posts, including the front corner. No mid rail and no skirt —
        -- "similar but simpler": the grid carries up so the elevation reads as one frame, while
        -- the storey above stays quieter than the one at street level.
        for k, pz in UPPER_POST_Z do
            -- THE CENTRE POST IS A KING POST: it carries on past the eave line to the ridge,
            -- which is what the gable is hung on. The others stop at the eave, because that is
            -- where the wall stops.
            local isKing = math.abs(pz - CZ) < 0.001
            local topY = if isKing then TOP else EAVE_Y
            local h = topY - (FLOOR + STOREY_H)
            add(
                `SideUpperPost{nm}{k}`,
                { POST_W * 0.8, h, POST_W * 0.8 },
                { px, FLOOR + STOREY_H + h / 2, pz },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
        -- the beam at the eave line, where the roof edge meets the flank
        -- out to the ROOF EDGES, not the wall line: the beam at the eave belongs to the roof's
        -- span, and stopping it at the wall left the overhang unsupported to the eye.
        add(
            `SideEaveBeam{nm}`,
            { POST_W * 0.85, BAND_T, D + 2 * ROOF_EAVE },
            { px, EAVE_Y - BAND_T / 2, CZ },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        -- horizontal bands: the skirt head, a mid rail, and the nageshi at the storey division
        for k, by in { FLOOR + SKIRT_H, FLOOR + STOREY_H * 0.55, FLOOR + STOREY_H - BAND_T / 2 } do
            add(
                `SideBand{nm}{k}`,
                { POST_W * 0.85, BAND_T, D },
                { px, by, CZ },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
        -- the boarded skirt (shitami-ita) along the bottom
        add(
            `SideSkirt{nm}`,
            { POST_W * 0.7, SKIRT_H, D },
            { px, FLOOR + SKIRT_H / 2, CZ },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
    end

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
        "Wood",
        nil,
        FRAME_VAR
    )
    -- "Wood", not "WoodPlanks". A MaterialVariant is SILENTLY IGNORED unless the part's Material
    -- equals the variant's BaseMaterial, and CypressVertical is base Wood — so this floor was set
    -- to the dark variant twice and stayed pale both times, with nothing anywhere to say why.
    --
    -- FOUR PIECES, NOT ONE, because the stair has to come through it. A rectangular well is cut in
    -- the east side and the floor is laid around it: the main span west of the well, the two ends
    -- north and south of it, and a strip along the east wall that keeps the wall standing on
    -- floor rather than on air. The floor NORTH of the well is the landing the stair arrives on.
    local uy = FLOOR + STOREY_H + SLAB_T / 2
    add(
        "UpperFloor",
        { WELL_X0 - X0, SLAB_T, D },
        { (X0 + WELL_X0) / 2, uy, CZ },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )
    add(
        "UpperFloorNorth",
        { X1 - WELL_X0, SLAB_T, WELL_Z0 - Z0 },
        { (WELL_X0 + X1) / 2, uy, (Z0 + WELL_Z0) / 2 },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )
    add(
        "UpperFloorSouth",
        { X1 - WELL_X0, SLAB_T, Z1 - WELL_Z1 },
        { (WELL_X0 + X1) / 2, uy, (WELL_Z1 + Z1) / 2 },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )
    -- TUCKED INTO THE WALL, not flush with it. The east wall's inner face and this strip's west
    -- face both sat on x = STAIR_X1, both looking west into the stairwell — two coplanar faces
    -- claiming one plane, which flickered exactly at attic-floor level as you climbed the stairs
    -- and read as a horizontal beam laid against the wall. Starting the strip inside the wall
    -- hides its face entirely; the wall itself fills the sliver, so nothing opens up.
    local EDGE_TUCK = 0.08
    add(
        "UpperFloorEdge",
        { X1 - STAIR_X1 - EDGE_TUCK, SLAB_T, WELL_Z1 - WELL_Z0 },
        { (STAIR_X1 + EDGE_TUCK + X1) / 2, uy, (WELL_Z0 + WELL_Z1) / 2 },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )
    assert(
        EDGE_TUCK < WALL_T,
        "the floor strip is tucked deeper than the wall is thick — it would leave a slot at the well"
    )

    -- ----- the stair -----
    -- Treads are edge to edge in plan (run == tread depth), so there is no gap to drop through
    -- even though the risers are open. Two stringers carry them, pitched at the same angle the
    -- treads climb. The stair's low end is at +Z, and by the sign convention above a POSITIVE
    -- angle lowers the +Z end — the same trap that inverted the roof.
    local stairDeg = math.deg(math.atan2(STAIR_RISE, STAIR_RUN))
    local stairCX = (STAIR_X0 + STAIR_X1) / 2
    for k = 1, STAIR_TREADS do
        add(
            `StairTread{k}`,
            { TREAD_W, TREAD_T, STAIR_RUN },
            { stairCX, FLOOR + k * STAIR_RISE - TREAD_T / 2, COUNTER_BACK_Z - (k - 0.5) * STAIR_RUN },
            timber,
            "Wood",
            nil,
            STAIR_VAR
        )
    end

    -- THE NOSE LINE runs through the back-top corner of every tread, and the stair is laid out so
    -- that it arrives at the upper floor's WALKING SURFACE exactly at the well's north edge. The
    -- stringers follow that line, so they land on the floor rather than stopping a step short of
    -- it — which is what they did, because they were built from the top TREAD instead.
    local NOSE_Y0 = FLOOR + STAIR_RISE -- the line's height at z = COUNTER_BACK_Z
    local noseRun = COUNTER_BACK_Z - WELL_Z0
    assert(
        math.abs((NOSE_Y0 + noseRun * (STAIR_RISE / STAIR_RUN)) - UPPER_SURFACE) < 1e-9,
        "the stair does not land flush on the upper floor — the nose line misses the well's edge"
    )
    local rad = math.rad(stairDeg)
    -- Dropped so the stringer's TOP FACE lies on the nose line. Measured vertically, a
    -- perpendicular half-thickness is t/2 over cos(pitch) — at 48° that is half again as much
    -- as t/2, and using t/2 directly buries the treads.
    local stringerCY = (NOSE_Y0 + UPPER_SURFACE) / 2 - (STRINGER_H / 2) / math.cos(rad)
    -- AND THEN EXTENDED, because the end is cut SQUARE to the run. A stringer whose top face
    -- reaches the floor still stops short of it in the flesh: the square cut leaves the top corner
    -- (H/2)*sin(pitch) back down the slope, a gap you can see from the landing and cannot see in
    -- any number. Lengthening by (H/2)*tan(pitch), all of it at the top, walks that corner onto
    -- the floor edge; the rest of the end face tucks up under the landing, which is where a real
    -- stringer dies into its trimmer.
    local topExtra = (STRINGER_H / 2) * math.tan(rad)
    -- AND THE SAME ARITHMETIC AT THE FOOT, which was left undone: the square cut put the low end's
    -- bottom corner at 113.25 against a floor of 113.10, so both stringers HOVERED an eighth of a
    -- stud above the boards they were supposed to stand on. Bury the corner instead of touching
    -- it — a joint that merely touches shows a seam the moment anything moves.
    local STRINGER_BURY = 0.25
    local footY = NOSE_Y0 - (STRINGER_H / 2) / math.cos(rad) - (STRINGER_H / 2) * math.cos(rad)
    local bottomExtra = math.max(0, (footY - (FLOOR - STRINGER_BURY)) / math.sin(rad))
    local stairLen = math.sqrt(noseRun * noseRun + (UPPER_SURFACE - NOSE_Y0) ^ 2) + topExtra + bottomExtra
    -- Each extension grows the part by its full length but moves the centre by only half, and they
    -- pull in opposite directions along the slope — so the net shift is their difference, halved.
    local shift = (topExtra - bottomExtra) / 2
    for _, s in { { "West", STAIR_X0 + STRINGER_T / 2 }, { "East", STAIR_X1 - STRINGER_T / 2 } } do
        add(`StairStringer{s[1]}`, { STRINGER_T, STRINGER_H, stairLen }, {
            s[2] :: number,
            stringerCY + math.sin(rad) * shift,
            (COUNTER_BACK_Z + WELL_Z0) / 2 - math.cos(rad) * shift,
        }, timber, "Wood", rotX(stairDeg), STAIR_VAR)
    end

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
    local UF_Z = SZ0 + WALL_T / 2 -- the box's street face; the kōshi and the sign stand proud of it

    local belowH = WIN_Y0 - UPPER_Y0
    local aboveH = (UPPER_Y0 + UPPER_H) - (WIN_Y0 + WIN_H)
    add(
        "UpperWallFrontLow",
        { SW, belowH, WALL_T },
        { CX, UPPER_Y0 + belowH / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallFrontHigh",
        { SW, aboveH, WALL_T },
        { CX, WIN_Y0 + WIN_H + aboveH / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    local jambW = WIN_X0 - SX0
    add(
        "UpperWallFrontWest",
        { jambW, WIN_H, WALL_T },
        { SX0 + jambW / 2, WIN_Y0 + WIN_H / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallFrontEast",
        { jambW, WIN_H, WALL_T },
        { SX1 - jambW / 2, WIN_Y0 + WIN_H / 2, UF_Z },
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
            -- IN the opening, centred in the wall's thickness. At Z0 + KOSHI_T/2 they stood a
            -- third of a stud proud of the render — a lattice floating in front of its own window.
            { WIN_X0 + (WIN_X1 - WIN_X0) * t, WIN_Y0 + WIN_H / 2, UF_Z },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
    end

    add(
        "UpperWallWest",
        { WALL_T, UPPER_H, SZ1 - SZ0 },
        { SX0 + WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallEast",
        { WALL_T, UPPER_H, SZ1 - SZ0 },
        { SX1 - WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallBack",
        { SW - 2 * WALL_T, UPPER_H, WALL_T }, -- between the side walls; see WallBack
        { CX, FLOOR + STOREY_H + UPPER_H / 2, SZ1 - WALL_T / 2 },
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
    -- on the BOX faces, so the triangles sit over the walls they close rather than 0.3 outboard
    for _, end_ in { { "West", SX0 + GABLE_T / 2 }, { "East", SX1 - GABLE_T / 2 } } do
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

    -- ----- the attic tie beams -----
    -- The flank already carries a beam at the eave line OUTSIDE (SideEaveBeam); from within the
    -- attic the same walls were bare render up to the gable. One beam along each, at the height
    -- the roof springs, running the whole way between the roof edges — the hari of a small
    -- koyagumi, and the one member that makes an attic read as framed rather than as a void.
    --
    -- Ends buried in the upper front and back walls, so the beam reads as spanning wall to wall
    -- and shows no cut end. CypressWeathered, not the frame's CypressVertical: this is a
    -- horizontal member, which is the distinction the stair timber turned on.
    --
    -- STOPPING AN INCH SHORT OF SZ0/SZ1. At the full span the end faces landed exactly on the
    -- upper walls' OUTER faces — coplanar and same-facing, so they flickered on the street
    -- elevation. Buried is the intent; flush is a z-fight. The ends still sit a third of a stud
    -- inside each wall, so nothing opens up.
    local TIE_TUCK = 1 / 12 -- one inch
    local TIE_T, TIE_H = 0.55, 0.70
    assert(TIE_TUCK < WALL_T, "the attic tie stops short of the wall it is meant to be buried in")
    for _, side in { { "West", SX0 + WALL_T + TIE_T / 2 }, { "East", SX1 - WALL_T - TIE_T / 2 } } do
        add(
            `AtticTie{side[1]}`,
            { TIE_T, TIE_H, (SZ1 - SZ0) - 2 * TIE_TUCK },
            { side[2] :: number, EAVE_Y - TIE_H / 2, (SZ0 + SZ1) / 2 },
            timber,
            "Wood",
            nil,
            STAIR_VAR
        )
    end

    -- ----- noren: three equal panels PER OPEN BAY -----
    -- They were three panels spread across BOTH bays, so they straddled the middle post and came
    -- out uneven — one wide, one narrow. A noren belongs to its own doorway: each opening gets its
    -- own set of three, sized to that bay, so the panels are identical and the post between them
    -- reads as a post rather than as a seam.
    local NOREN_TOP = HEAD_Y
    local NOREN_H = 2.6
    local NOREN_PER_BAY = 3
    for i = 1, FRONT_POSTS - 1 do
        if not CLOSED[i] then
            local a, b = postX[i], postX[i + 1]
            local openW = (b - a) - POST_W
            local panelW = openW / NOREN_PER_BAY - 0.16
            for k = 1, NOREN_PER_BAY do
                local t = (k - 0.5) / NOREN_PER_BAY
                table.insert(
                    children,
                    Spec.part(`Noren{i}_{k}`, {
                        Size = { panelW, NOREN_H, 0.08 },
                        CFrame = Spec.cframe({
                            a + POST_W / 2 + openW * t,
                            NOREN_TOP - NOREN_H / 2,
                            Z0 + 0.06,
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
        end
    end

    -- ----- the counter -----
    add(
        "Counter",
        -- Spans only the OPEN bays now that the outer two are closed, and stands at the BACK of
        -- the shop so the goods are behind it rather than on the street.
        --
        -- MEASURED FROM Z1, NOT Z0. It used to sit at Z0 + 4.6, which was the same place while the
        -- shop was 8 deep and became a counter marooned in the middle of the street the moment the
        -- frontage moved north. The counter belongs to the back wall; the customers get the rest.
        { postX[FRONT_POSTS - 1] - postX[2] - POST_W, COUNTER_H, COUNTER_D },
        { (postX[2] + postX[FRONT_POSTS - 1]) / 2, FLOOR + COUNTER_H / 2, COUNTER_Z },
        timber,
        "Wood",
        nil,
        FRAME_VAR
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
    local SIGN_Z = Z0 - 0.65 -- owner's gate: half a stud further out, so it reads off the facade
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
            Size = { SIGN_W, SIGN_H, 0.11 }, -- owner's gate: half the first pass
            CFrame = Spec.cframe({ CX, SIGN_Y, SIGN_Z }, ST),
            -- A WHITE BOARD IN A DARK FRAME, as the reference shows. "The darker wood" meant the
            -- SURROUND; I applied it to the backing as well and lost the sign. The board is
            -- plaster and the letters are ink; only the frame is timber.
            Color = paper,
            Material = STUCCO_MAT,
            MaterialVariant = STUCCO_VAR,
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
                                TextColor3 = ink, -- dark characters on the white board
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
            ST,
            FRAME_VAR
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
