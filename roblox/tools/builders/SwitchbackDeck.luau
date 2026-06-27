--!strict
-- Small posted timber viewing deck at the FarWall_11 hairpin (spec 2026-06-27).
-- A smaller/simpler sibling of Overlook: single slab on a post ring, KORAN railing on
-- the East+South edges, one hanji result-lantern on the SE corner, a threshold + timber
-- step-downs at the West exit.
-- Pure & deterministic; post feet are baked from the recorded terrain survey.
local Spec = require("./Spec")

local SwitchbackDeck = {}

-- ===== constants (see plan Global Constraints) =====
local DECK_TOP = 138.46
local SLAB_T = 0.6
-- Position baked from the user's in-Studio placement (2026-06-27): center (159.7, -66.6),
-- out on the higher promontory shelf east of FW11; reached by extending the upper path.
local CX, CZ = 159.7, -66.6 -- deck center (x, z)
local DECK_W, DECK_D = 18, 15 -- size: X width, Z depth
local X0, X1 = CX - DECK_W / 2, CX + DECK_W / 2 -- West, South edges
local Z0, Z1 = CZ - DECK_D / 2, CZ + DECK_D / 2 -- North, East edges
local TIMBER = { 0.42, 0.31, 0.20 }
-- Hanji result-lantern recipe (matches the Overlook). The body MUST be named "*Lantern"
-- so the runtime LanternController finds it and paints the World-Throw result SurfaceGui.
local LANTERN_BODY = { 0.635, 0.49, 0.28 } -- warm amber Neon
local LANTERN_LIGHT = { 1.0, 0.76, 0.46 } -- dim warm PointLight

local SLAB_BOTTOM = DECK_TOP - SLAB_T
local POST_W = 1.125 -- 25% lighter than the Overlook's 1.5
local GIRDER_TOP = SLAB_BOTTOM -- girder top flush under slab
local GIRDER_H, GIRDER_W = 1.2, 0.825 -- 25% lighter than 1.6 x 1.1

-- Post feet baked from the terrain survey (2026-06-27, after the user's lower+terrain tweak).
-- All vertical; North/cliff edge sits near grade (short stubs), far/drop edge grows toward SE.
local VERT_POSTS = {
    { X0, Z0, 137.0 }, -- NW (cliff + up-canyon)
    { CX, Z0, 137.2 }, -- N mid
    { X1, Z0, 137.0 }, -- NE (cliff + downcanyon)
    { X0, Z1, 135.9 }, -- SW (far edge, up-canyon)
    { CX, Z1, 134.3 }, -- S mid (far edge)
    { X1, Z1, 130.2 }, -- SE (far edge, downcanyon; tallest)
}

-- inset a coordinate so a post/beam's OUTER face sits flush with the deck edge
local function flushX(x: number): number
    if math.abs(x - X0) < 0.01 then
        return x + POST_W / 2
    elseif math.abs(x - X1) < 0.01 then
        return x - POST_W / 2
    end
    return x
end
local function flushZ(z: number): number
    if math.abs(z - Z0) < 0.01 then
        return z + POST_W / 2
    elseif math.abs(z - Z1) < 0.01 then
        return z - POST_W / 2
    end
    return z
end

-- ===== railing (KORAN: cap + mid-rail + balusters + newels) =====
local RAIL_H = 3.2
local NEWEL_W, NEWEL_H = 0.62, 3.7
local BAL_W, BAL_STEP = 0.34, 2.0
local RAIL_INSET = 0.35 -- sit the rail line just inboard of the deck edge

-- ===== deck->path stair (Overlook-style, off the West-south edge) =====
local STAIR_Z = -62 -- centerline on the West edge, south end
local STAIR_W = 5.0 -- tread width (across, along Z)
local STAIR_STEPS = 6
local STAIR_TOP = { X0, DECK_TOP, STAIR_Z } -- head of flight at the deck edge
local STAIR_FOOT = { 138.7, 130.91, STAIR_Z } -- user-placed target: ~7.5 drop over 12 studs -X
SwitchbackDeck.STAIR_FOOT = STAIR_FOOT -- exposed: the descent's first route marker

-- axis-aligned timber beam between XZ points p0,p1 at height y, cross-section ch(height) x cw(width)
local function barSeg(
    kids: { Spec.PartSpec },
    name: string,
    p0: { number },
    p1: { number },
    y: number,
    ch: number,
    cw: number
)
    local dx, dz = p1[1] - p0[1], p1[2] - p0[2]
    local size = if math.abs(dx) >= math.abs(dz)
        then { math.abs(dx) + cw, ch, cw }
        else { cw, ch, math.abs(dz) + cw }
    table.insert(
        kids,
        Spec.part(name, {
            Size = size,
            CFrame = Spec.cframe({ (p0[1] + p1[1]) / 2, y, (p0[2] + p1[2]) / 2 }),
            Color = TIMBER,
            Material = "Wood",
        })
    )
end

-- railing run a->b ({x,z}): flat top cap + mid-rail + square balusters
local function railRun(
    kids: { Spec.PartSpec },
    tag: string,
    a: { number },
    b: { number },
    balC: { v: number }
)
    barSeg(kids, `Rail{tag}Cap`, a, b, DECK_TOP + RAIL_H, 0.3, 0.6)
    barSeg(kids, `Rail{tag}Mid`, a, b, DECK_TOP + RAIL_H - 1.1, 0.2, 0.3)
    local dx, dz = b[1] - a[1], b[2] - a[2]
    local len = math.sqrt(dx * dx + dz * dz)
    local n = math.max(2, math.floor(len / BAL_STEP))
    for i = 0, n do
        local t = i / n
        balC.v += 1
        table.insert(
            kids,
            Spec.part(`Baluster_{balC.v}`, {
                Size = { BAL_W, RAIL_H, BAL_W }, -- up to the cap (no gap below the top rail)
                CFrame = Spec.cframe({ a[1] + dx * t, DECK_TOP + RAIL_H / 2, a[2] + dz * t }),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end
end

function SwitchbackDeck.build(palette: any, _layout: any): Spec.PartSpec
    local kids: { Spec.PartSpec } = {}

    -- deck slab
    table.insert(
        kids,
        Spec.part("DeckSlab", {
            Size = { DECK_W, SLAB_T, DECK_D },
            CFrame = Spec.cframe({ CX, DECK_TOP - SLAB_T / 2, CZ }),
            Color = TIMBER,
            Material = "WoodPlanks",
        })
    )

    -- under-slab girders: two long beams (along X) at the edges + one cross beam (along Z) mid-span
    local gy = GIRDER_TOP - GIRDER_H / 2
    table.insert(
        kids,
        Spec.part("GirderX_N", {
            Size = { DECK_W, GIRDER_H, GIRDER_W },
            CFrame = Spec.cframe({ CX, gy, Z0 + GIRDER_W / 2 }), -- flush with North edge
            Color = TIMBER,
            Material = "Wood",
        })
    )
    table.insert(
        kids,
        Spec.part("GirderX_Far", {
            Size = { DECK_W, GIRDER_H, GIRDER_W },
            CFrame = Spec.cframe({ CX, gy, Z1 - GIRDER_W / 2 }), -- flush with far edge
            Color = TIMBER,
            Material = "Wood",
        })
    )
    table.insert(
        kids,
        Spec.part("GirderZ_M", {
            Size = { GIRDER_W, GIRDER_H, DECK_D },
            CFrame = Spec.cframe({ CX, gy, CZ }),
            Color = TIMBER,
            Material = "Wood",
        })
    )

    -- vertical posts (foot on terrain up to slab underside), inset so outer faces sit flush with the deck edges
    for i, p in VERT_POSTS do
        local px, pz, foot = p[1], p[2], p[3]
        local h = math.max(SLAB_BOTTOM - foot, 0.8)
        table.insert(
            kids,
            Spec.part(`Post_{i}`, {
                Size = { POST_W, h, POST_W },
                CFrame = Spec.cframe({ flushX(px), foot + h / 2, flushZ(pz) }),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end

    -- railing on the two open-air edges: East = far/downcanyon (Z1), South = X1. Open on North (cliff) + West (path).
    local zRail = Z1 - RAIL_INSET
    local xRail = X1 - RAIL_INSET
    local x0r, x1r = X0 + RAIL_INSET, X1 - RAIL_INSET
    local z0r = Z0 + RAIL_INSET
    local balC = { v = 0 }
    railRun(kids, "East", { x0r, zRail }, { x1r, zRail }, balC) -- far/downcanyon edge
    railRun(kids, "South", { xRail, z0r }, { xRail, zRail }, balC) -- X1 edge
    -- newels at the L-run ends + the jutting corner
    for i, c in { { x0r, zRail }, { xRail, zRail }, { xRail, z0r } } do
        table.insert(
            kids,
            Spec.part(`Newel_{i}`, {
                Size = { NEWEL_W, NEWEL_H, NEWEL_W },
                CFrame = Spec.cframe({ c[1], DECK_TOP + NEWEL_H / 2, c[2] }),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end

    -- single hanji result-lantern atop the SE corner newel (the jutting view corner).
    -- Name ends in "Lantern" so the runtime LanternController paints the World-Throw result on it.
    local lanternBaseY = DECK_TOP + NEWEL_H
    local lh = 1.5
    table.insert(kids, {
        name = "DeckLantern",
        className = "Part",
        properties = {
            Anchored = true,
            Shape = "Block",
            Size = { 1.0, lh, 1.0 },
            CFrame = Spec.cframe({ xRail, lanternBaseY + lh / 2, zRail }),
            Color = LANTERN_BODY,
            Material = "Neon",
        },
        children = {
            {
                name = "DeckLanternLight",
                className = "PointLight",
                properties = { Color = LANTERN_LIGHT, Brightness = 0.68, Range = 9 },
            },
        },
    })
    table.insert(
        kids,
        Spec.part("DeckLanternCap", {
            Shape = "Block",
            Size = { 1.2, 0.18, 1.2 },
            CFrame = Spec.cframe({ xRail, lanternBaseY + lh + 0.09, zRail }),
            Color = palette.ink,
            Material = "Wood",
        })
    )

    -- deck->path stair: 3 Slate treads from the deck edge down to the foot
    for k = 1, STAIR_STEPS do
        local t = (k - 0.5) / STAIR_STEPS
        table.insert(
            kids,
            Spec.part(`Step{k}`, {
                Size = { 2.0, 0.5, STAIR_W }, -- 2 deep along travel (-X), STAIR_W wide across (Z)
                CFrame = Spec.cframe({
                    STAIR_TOP[1] + (STAIR_FOOT[1] - STAIR_TOP[1]) * t,
                    STAIR_TOP[2] + (STAIR_FOOT[2] - STAIR_TOP[2]) * t - 0.33, -- seat treads ~4in lower on the stringers
                    STAIR_Z,
                }),
                Color = palette.ink,
                Material = "Slate",
            })
        )
    end
    -- two sloped stringers under the tread edges
    for si, off in { -(STAIR_W / 2 - 0.3), STAIR_W / 2 - 0.3 } do
        local a = { STAIR_TOP[1], STAIR_TOP[2] - 0.7, STAIR_Z + off }
        local b = { STAIR_FOOT[1], STAIR_FOOT[2] - 0.7, STAIR_Z + off }
        local pos, len, rot = Spec.segment(a, b)
        table.insert(
            kids,
            Spec.part(`Stringer{si}`, {
                Size = { len, 0.9, 0.5 },
                CFrame = Spec.cframe(pos, rot),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end
    -- two newels framing the head of the flight (West edge is otherwise open)
    for i, zoff in { -(STAIR_W / 2), STAIR_W / 2 } do
        table.insert(
            kids,
            Spec.part(`StairNewel_{i}`, {
                Size = { NEWEL_W, NEWEL_H, NEWEL_W },
                CFrame = Spec.cframe({ X0 + NEWEL_W / 2, DECK_TOP + NEWEL_H / 2, STAIR_Z + zoff }),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end

    return Spec.model("SwitchbackDeck", kids)
end

return SwitchbackDeck
