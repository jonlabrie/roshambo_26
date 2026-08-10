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
local ROOF_RISE = TOP - EAVE_Y -- 4.26

-- The eave overhangs the frontage by this much. THIS IS THE ONE DELIBERATE ENCROACHMENT on the
-- reserved promenade, and it is aerial: its underside sits a full storey up, so nothing at
-- ground level enters the corridor. Without it the building has no shopfront shadow and reads
-- as a shed.
local EAVE_OVERHANG = 2.5
local EAVE_T = 0.5
local ROOF_RIDGE_Z = (Z0 - EAVE_OVERHANG + Z1) / 2 -- ridge centred on the ROOF span, not the walls

local POST_W = 1.125 -- recipe §2: 25% lighter than the Overlook's 1.5
local GIRDER_H, GIRDER_W = 1.2, 0.825
local WALL_T = 0.5
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
local function rotX(deg: number): { number }
    local r = math.rad(deg)
    local c, s = math.cos(r), math.sin(r)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Machiya.build(palette: any, _layout: any): any
    local children = {}
    local timber = palette.timber
    local cypress = palette.cypressWeathered
    local tile = palette.slateTile
    local ink = palette.ink

    local function add(
        name: string,
        size: { number },
        pos: { number },
        colour: { number },
        material: string,
        rot: { number }?
    )
        table.insert(
            children,
            Spec.part(name, {
                Size = size,
                CFrame = Spec.cframe(pos, rot),
                Color = colour,
                Material = material,
                CanCollide = true,
                CastShadow = false,
            })
        )
    end

    -- ----- the raised timber floor -----
    add("FloorSlab", { W, SLAB_T, D }, { CX, FLOOR - SLAB_T / 2, CZ }, timber, "WoodPlanks")

    -- ----- the OPEN frontage: six posts, no wall -----
    local FRONT_POSTS = 6
    for i = 1, FRONT_POSTS do
        local t = (i - 1) / (FRONT_POSTS - 1)
        local x = flushX(X0 + (X1 - X0) * t)
        add(
            `FrontPost{i}`,
            { POST_W, STOREY_H, POST_W },
            { x, FLOOR + STOREY_H / 2, Z0 + POST_W / 2 },
            timber,
            "Wood"
        )
    end

    -- ----- side and back walls (ground storey) -----
    add(
        "WallWest",
        { WALL_T, STOREY_H, D },
        { X0 + WALL_T / 2, FLOOR + STOREY_H / 2, CZ },
        cypress,
        "WoodPlanks"
    )
    add(
        "WallEast",
        { WALL_T, STOREY_H, D },
        { X1 - WALL_T / 2, FLOOR + STOREY_H / 2, CZ },
        cypress,
        "WoodPlanks"
    )
    add(
        "WallBack",
        { W, STOREY_H, WALL_T },
        { CX, FLOOR + STOREY_H / 2, Z1 - WALL_T / 2 },
        cypress,
        "WoodPlanks"
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
        cypress,
        "WoodPlanks"
    )
    add(
        "UpperWallEast",
        { WALL_T, UPPER_H, D },
        { X1 - WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, CZ },
        cypress,
        "WoodPlanks"
    )
    add(
        "UpperWallBack",
        { W, UPPER_H, WALL_T },
        { CX, FLOOR + STOREY_H + UPPER_H / 2, Z1 - WALL_T / 2 },
        cypress,
        "WoodPlanks"
    )

    -- ----- the eave over the shopfront: aerial, a full storey up -----
    local eaveD = (Z0 - (Z0 - EAVE_OVERHANG))
    add(
        "Eave",
        { W + 1.0, EAVE_T, eaveD },
        { CX, FLOOR + STOREY_H + EAVE_T / 2, Z0 - EAVE_OVERHANG / 2 },
        tile,
        "Slate"
    )

    -- ----- the roof: a gabled kirizuma, ridge running east-west along the street -----
    -- Machiya are hirairi — you enter on the long side, under the eave, with the gables at the
    -- ends. Two slopes, symmetric about a ridge centred on the ROOF span (which reaches further
    -- north than the walls because of the overhang).
    local frontRun = ROOF_RIDGE_Z - (Z0 - EAVE_OVERHANG)
    local backRun = Z1 - ROOF_RIDGE_Z
    local frontLen = math.sqrt(frontRun * frontRun + ROOF_RISE * ROOF_RISE)
    local backLen = math.sqrt(backRun * backRun + ROOF_RISE * ROOF_RISE)
    local frontDeg = math.deg(math.atan2(ROOF_RISE, frontRun))
    local backDeg = math.deg(math.atan2(ROOF_RISE, backRun))
    local ROOF_T = 0.5

    add(
        "RoofNorth",
        { W + 1.0, ROOF_T, frontLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (Z0 - EAVE_OVERHANG + ROOF_RIDGE_Z) / 2 },
        tile,
        "Slate",
        rotX(frontDeg)
    )
    add(
        "RoofSouth",
        { W + 1.0, ROOF_T, backLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1) / 2 },
        tile,
        "Slate",
        rotX(-backDeg)
    )
    add("Ridge", { W + 1.2, 0.4, 0.6 }, { CX, TOP - 0.2, ROOF_RIDGE_Z }, ink, "Slate")

    -- Gable ends. Each is TWO right triangles back to back, which is what an isosceles gable is;
    -- a WedgePart's native slope descends toward +Z with its vertical face at -Z, so the north
    -- half is that wedge turned 180° about Y and the south half is it unturned.
    local GABLE_T = 0.4
    for _, end_ in { { "West", X0 + GABLE_T / 2 }, { "East", X1 - GABLE_T / 2 } } do
        local name, x = end_[1] :: string, end_[2] :: number
        table.insert(
            children,
            Spec.part(`Gable{name}North`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, frontRun },
                CFrame = Spec.cframe(
                    { x, EAVE_Y + ROOF_RISE / 2, (Z0 - EAVE_OVERHANG + ROOF_RIDGE_Z) / 2 },
                    { -1, 0, 0, 0, 1, 0, 0, 0, -1 }
                ),
                Color = cypress,
                Material = "WoodPlanks",
                CanCollide = true,
                CastShadow = false,
            })
        )
        table.insert(
            children,
            Spec.part(`Gable{name}South`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, backRun },
                CFrame = Spec.cframe({ x, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1) / 2 }),
                Color = cypress,
                Material = "WoodPlanks",
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

    -- ----- the kanban: the sign board, under the upper floor, facing the promenade -----
    -- A SurfaceGui, not a Decal: Roblox renders CJK from the built-in fonts, and the glyph
    -- pipeline next door is a stroked-path rasterizer with no font support — it draws R/P/S as
    -- line segments and could not produce a kanji without hand-authored stroke geometry.
    --
    -- PixelsPerStud is LOW on purpose. TextSize caps at 100 and TextScaled is inert, so the only
    -- way to get large lettering is a small canvas — 20 px/stud over a 2.6-stud board means 90px
    -- text fills it.
    --
    -- Mounted just inside the frontage line (not proud of it) — same ground-clearance reasoning
    -- as the noren above. KEEP Z0 + 0.2: a part proud of the frontage at this height hangs into
    -- the reserved promenade at avatar head height.
    table.insert(
        children,
        Spec.part("Kanban", {
            Size = { W * 0.55, 2.6, 0.25 },
            CFrame = Spec.cframe({ CX, FLOOR + STOREY_H - 1.6, Z0 + 0.2 }),
            Color = ink,
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
                        -- Front is -Z, which is north: onto the promenade.
                        Face = "Front",
                        PixelsPerStud = 20,
                        ZIndexBehavior = "Sibling",
                        AlwaysOnTop = false,
                    },
                    children = {
                        {
                            name = "Text",
                            className = "TextLabel",
                            properties = {
                                -- UDim2 in this pipeline's model.json is {UDim2 = {{XScale,
                                -- XOffset}, {YScale, YOffset}}} — verified against `rojo build`,
                                -- which rejects a flat 4-number array with "Expected UDim2, got
                                -- an array of four numbers".
                                Size = { UDim2 = { { 1, 0 }, { 1, 0 } } },
                                BackgroundTransparency = 1,
                                Text = "花火屋",
                                TextColor3 = palette.ivory,
                                TextSize = 90,
                                Font = "GothamBold",
                            },
                        },
                    },
                },
            },
        })
    )

    -- ----- the trigger volume -----
    -- Inset one stud from the frontage. See ShopThreshold.FRONT_INSET for why: flush with the
    -- frontage it would fire on everyone crossing the square.
    local tz0 = Z0 + 1
    table.insert(
        children,
        Spec.part("Threshold", {
            Size = { W, 4.9, Z1 - tz0 },
            CFrame = Spec.cframe({ CX, FLOOR + 4.9 / 2, (tz0 + Z1) / 2 }),
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
