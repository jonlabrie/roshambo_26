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
local CAP_DARK = { 0.118, 0.102, 0.078 } -- dark/black top rail (matches the arch bridge cap)
-- Hanji result-lantern recipe (matches the Overlook). The body MUST be named "*Lantern"
-- so the runtime LanternController finds it and paints the World-Throw result SurfaceGui.
local LANTERN_BODY = { 0.588, 0.5, 0.421 } -- chōchin paper tone, dimmed ×0.75 (core dimmed to match → stays blended)
local LANTERN_LIGHT = { 1.0, 0.659, 0.376 } -- warm PointLight (matches the chōchin)

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
local WALL_H = 15 -- invisible fall-wall height — clears rail-cap (~3.2) + jump (~7.2) so you can't double-jump off the cap

-- ===== deck->path stair (Overlook-style, off the West-south edge) =====
local STAIR_Z = -61.6 -- centerline; nudged ~0.4 south so the stair's S rail lands on the deck corner Newel_1
local STAIR_W = 5.0 -- tread width (across, along Z)
local STAIR_STEPS = 7
local STAIR_TOP = { X0 + RAIL_INSET, DECK_TOP, STAIR_Z } -- head; +RAIL_INSET east so the S rail meets Newel_1 (x0r)
local STAIR_FOOT = { 136.7 + RAIL_INSET, 129.65, STAIR_Z } -- foot shifted the same +X to keep the rake a clean translate
SwitchbackDeck.STAIR_FOOT = STAIR_FOOT -- exposed: the descent's first route marker

-- Extend the stair handrail PAST the last step, down the same rake onto the path flagstone, so the
-- deck-style railing reaches DescentPath's top (plugging the style/coverage gap). The foot newels
-- relocate here. RAIL_FOOT_X is just shy of DescentPath's top edge (~134.9).
local RAIL_FOOT_X = 135.0
local STAIR_SLOPE = (STAIR_FOOT[2] - STAIR_TOP[2]) / (STAIR_FOOT[1] - STAIR_TOP[1])
local RAIL_FOOT = { RAIL_FOOT_X, STAIR_FOOT[2] + STAIR_SLOPE * (RAIL_FOOT_X - STAIR_FOOT[1]) }

-- axis-aligned timber beam between XZ points p0,p1 at height y, cross-section ch(height) x cw(width)
local function barSeg(
    kids: { Spec.PartSpec },
    name: string,
    p0: { number },
    p1: { number },
    y: number,
    ch: number,
    cw: number,
    color: { number }?
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
            Color = color or TIMBER,
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
    barSeg(kids, `Rail{tag}Cap`, a, b, DECK_TOP + RAIL_H, 0.3, 0.6, CAP_DARK)
    barSeg(kids, `Rail{tag}Mid`, a, b, DECK_TOP + RAIL_H - 1.1, 0.2, 0.3)
    -- invisible CanCollide fall-wall along the run (fills the baluster gaps on this open edge)
    local wsize = if math.abs(b[1] - a[1]) >= math.abs(b[2] - a[2])
        then { math.abs(b[1] - a[1]) + 0.4, WALL_H, 0.4 }
        else { 0.4, WALL_H, math.abs(b[2] - a[2]) + 0.4 }
    table.insert(
        kids,
        Spec.part(`Rail{tag}Wall`, {
            Size = wsize,
            CFrame = Spec.cframe({ (a[1] + b[1]) / 2, DECK_TOP + WALL_H / 2, (a[2] + b[2]) / 2 }),
            Transparency = 1,
            CanCollide = true,
            CastShadow = false,
            Material = "SmoothPlastic",
        })
    )
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

-- raked KORAN stair railing along one side (constant z): raked cap + mid-rail + plumb balusters
-- + foot newel. The top newel is optional — the South side reuses the deck's corner Newel_1
-- (the stairway has been aligned so its S rail head lands exactly on it).
local function stairRail(
    kids: { Spec.PartSpec },
    tag: string,
    railZ: number,
    topNewel: boolean,
    barrier: boolean
)
    local ax, ay = STAIR_TOP[1], STAIR_TOP[2] -- head, at the walking surface
    local fx, fy = RAIL_FOOT[1], RAIL_FOOT[2] -- extended foot, out on the flagstone
    -- continuous raked cap (0.3 x 0.6) + mid-rail (0.2 x 0.3) from the head down past the last step
    local cpos, clen, crot = Spec.segment({ ax, ay + RAIL_H, railZ }, { fx, fy + RAIL_H, railZ })
    table.insert(
        kids,
        Spec.part(`StairCap{tag}`, {
            Size = { clen, 0.3, 0.6 },
            CFrame = Spec.cframe(cpos, crot),
            Color = CAP_DARK,
            Material = "Wood",
        })
    )
    local mpos, mlen, mrot = Spec.segment({ ax, ay + RAIL_H - 1.1, railZ }, { fx, fy + RAIL_H - 1.1, railZ })
    table.insert(
        kids,
        Spec.part(
            `StairMid{tag}`,
            { Size = { mlen, 0.2, 0.3 }, CFrame = Spec.cframe(mpos, mrot), Color = TIMBER, Material = "Wood" }
        )
    )
    -- ONE plumb baluster per step, seated on its tread near the front (downhill) edge, rising to the cap
    for k = 1, STAIR_STEPS do
        local t = (k - 0.5) / STAIR_STEPS
        local stepCx = STAIR_TOP[1] + (STAIR_FOOT[1] - STAIR_TOP[1]) * t - 0.33 -- step centre X (matches the step loop)
        local treadTop = STAIR_TOP[2] + (STAIR_FOOT[2] - STAIR_TOP[2]) * t - 0.25 -- tread top (centre −0.5 + half 0.25)
        local bx = stepCx - 0.7 -- near the front nosing
        local capY = STAIR_TOP[2] + STAIR_SLOPE * (bx - STAIR_TOP[1]) + RAIL_H
        table.insert(
            kids,
            Spec.part(`StairBal{tag}_{k}`, {
                Size = { BAL_W, capY - treadTop, BAL_W },
                CFrame = Spec.cframe({ bx, (treadTop + capY) / 2, railZ }),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end
    -- foot newel out on the flagstone
    table.insert(
        kids,
        Spec.part(`StairNewel{tag}Foot`, {
            Size = { NEWEL_W, NEWEL_H, NEWEL_W },
            CFrame = Spec.cframe({ fx, fy + NEWEL_H / 2, railZ }),
            Color = TIMBER,
            Material = "Wood",
        })
    )
    if topNewel then
        table.insert(
            kids,
            Spec.part(`StairNewel{tag}Top`, {
                Size = { NEWEL_W, NEWEL_H, NEWEL_W },
                CFrame = Spec.cframe({ ax, ay + NEWEL_H / 2, railZ }),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end
    if barrier then
        -- invisible CanCollide fall-wall, raked along the WHOLE run (head → extended foot), sized so its
        -- VERTICAL height is WALL_H (jump-proof). cos(rake) = |dx|/runLen → perp height = WALL_H/cos.
        local dx, dy = fx - ax, fy - ay
        local runLen = math.sqrt(dx * dx + dy * dy)
        local hb = WALL_H / (math.abs(dx) / runLen)
        local qpos, qlen, qrot = Spec.segment({ ax, ay + WALL_H / 2, railZ }, { fx, fy + WALL_H / 2, railZ })
        table.insert(
            kids,
            Spec.part(`StairWall{tag}`, {
                Size = { qlen, hb, 0.4 },
                CFrame = Spec.cframe(qpos, qrot),
                Transparency = 1,
                CanCollide = true,
                CastShadow = false,
                Material = "SmoothPlastic",
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

    -- deck-style railings down BOTH sides of the stairway (raked KORAN). The South rail is aligned
    -- to the deck's corner Newel_1 (reused as its head post); the North side gets its own head newel.
    stairRail(kids, "S", STAIR_Z + STAIR_W / 2 - RAIL_INSET, false, true) -- = zRail (Newel_1 line); +fall-wall
    stairRail(kids, "N", STAIR_Z - STAIR_W / 2 + RAIL_INSET, true, false)

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
            Transparency = 0.42, -- translucent paper so the inner glow reads through (chōchin recipe)
        },
        children = {
            {
                name = "DeckLanternLight",
                className = "PointLight",
                properties = { Color = LANTERN_LIGHT, Brightness = 0.3, Range = 5 },
            },
        },
    })
    -- the "lit-from-within" glow is a soft radial sprite added at runtime by LanternController
    -- (a Neon ball read as a hard sphere on this small box); the builder ships only the paper + cap.
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
                    STAIR_TOP[1] + (STAIR_FOOT[1] - STAIR_TOP[1]) * t - 0.33, -- ~4in forward (downhill, -X) off the stringers
                    STAIR_TOP[2] + (STAIR_FOOT[2] - STAIR_TOP[2]) * t - 0.5, -- seat treads ~6in below the stringer line
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

    return Spec.model("SwitchbackDeck", kids)
end

return SwitchbackDeck
