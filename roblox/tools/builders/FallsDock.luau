--!strict
-- Small posted timber dock on the NE shore of pool 2, west canyon
-- (spec 2026-07-28-canyon-destinations-falls-dock-design).
-- Runs WSW toward the TopToOutfall falls: you walk out along it toward the water.
-- A smaller, simpler sibling of SwitchbackDeck — NO RAILING (the spec forbids it: a
-- 1.5-stud step into shallow water is not a drop edge, and a railing would clutter the
-- silhouette this dock is composed for, seen from the teahouse pads above).
-- The chōchin at the water end is placed separately in Studio (tools/studio/buildDockChochin).
-- Pure & deterministic; seat and post feet are baked from an in-Studio survey.
local Spec = require("./Spec")

local FallsDock = {}

-- ===== baked placement (user-dragged FallsDockMarker, 2026-07-28) =====
-- The user placed the marker at the SHORE end of the slab; the centre below is that
-- point advanced half the deck depth along the aim. Yaw aims the model's LookVector at
-- the TopToOutfall base (-370, 187, -6), 30.4 studs away — so in the deck's own frame,
-- LOCAL -Z IS THE WATER/FALLS END and +Z is the shore.
local DOCK_CX = -345.37
local DOCK_CZ = -15.45
local DOCK_YAW_DEG = 110.99

-- ===== dimensions (spec + build recipes §2) =====
-- User units: 1 stud = 1 foot, 1 inch = 1/12 stud.
local IN = 1 / 12
local DECK_W, DECK_D = 6, 8 -- X across, Z along (long axis aimed at the falls)
local DECK_TOP = 190.2 -- ~1.5 studs above the pool 2 surface (y ≈ 188.7)

-- The deck is BUILT, not moulded: a 2x6 box frame on the outside with 2x4 boards laid
-- across it, an inch of daylight between them. From above you read boards and gaps;
-- from the water you read the frame. A single slab looked like finished flooring.
local FRAME_T, FRAME_H = 2 * IN, 6 * IN -- 2x6 on edge
local BOARD_T, BOARD_W = 2 * IN, 4 * IN -- 2x4 laid flat
local BOARD_GAP = 1 * IN -- target; the real gap is the span remainder spread evenly
local SLAB_BOTTOM = DECK_TOP - FRAME_H -- frame underside; girders and posts meet here

local POST_W = 1.125
local GIRDER_H, GIRDER_W = 1.2, 0.825
local GIRDER_TOP = SLAB_BOTTOM
local MIN_POST_H = 0.75 -- shore posts bury into the bank rather than vanish

local TIMBER = { 0.42, 0.31, 0.20 }

local X0, X1 = -DECK_W / 2, DECK_W / 2
local Z0, Z1 = -DECK_D / 2, DECK_D / 2

-- inset so a post's OUTER face is flush with the slab edge
local function flush(v: number, lo: number, hi: number): number
    if math.abs(v - lo) < 0.01 then
        return v + POST_W / 2
    elseif math.abs(v - hi) < 0.01 then
        return v - POST_W / 2
    end
    return v
end

-- Post feet baked from the in-Studio terrain survey (2026-07-28), taken at each post's
-- WORLD position after the yaw. The water end stands in ~3.5 studs of pool; the shore
-- end meets the bank, which is why a single pool-bed constant will not do.
--   { local x, local z, surveyed bed y }
local POSTS = {
    { X0, Z0, 185.18 }, -- water end, deepest
    { X1, Z0, 185.97 }, -- water end
    { X0, 0, 187.16 }, -- mid
    { X1, 0, 187.41 }, -- mid
    { X0, Z1, 188.74 }, -- shore end, at the waterline
    { X1, Z1, 189.60 }, -- shore end, up the bank (deck meets grade here)
}

function FallsDock.build(_palette: any, _layout: any): any
    local children = {}

    -- ----- 2x6 box frame, outer faces flush with the 6 x 8 footprint -----
    local frameY = DECK_TOP - FRAME_H / 2
    local innerW = DECK_W - 2 * FRAME_T -- the end members butt between the side ones
    for _, f in
        {
            { "FrameWest", -(DECK_W / 2 - FRAME_T / 2), 0, FRAME_T, DECK_D },
            { "FrameEast", DECK_W / 2 - FRAME_T / 2, 0, FRAME_T, DECK_D },
            { "FrameShore", 0, DECK_D / 2 - FRAME_T / 2, innerW, FRAME_T },
            { "FrameWater", 0, -(DECK_D / 2 - FRAME_T / 2), innerW, FRAME_T },
        }
    do
        table.insert(
            children,
            Spec.part(f[1] :: string, {
                Size = { f[4], FRAME_H, f[5] },
                CFrame = Spec.cframe({ f[2], frameY, f[3] }),
                Material = "Wood",
                Color = TIMBER,
            })
        )
    end

    -- ----- 2x4 decking, laid across the short axis, tops flush with the frame -----
    -- A whole number of boards rarely divides the span at exactly one inch, so the
    -- board width is held exact and the remainder is spread evenly across the gaps.
    local innerD = DECK_D - 2 * FRAME_T
    local nBoards = math.floor((innerD + BOARD_GAP) / (BOARD_W + BOARD_GAP))
    local pitch = innerD / nBoards
    local z0 = -innerD / 2 + pitch / 2
    for i = 1, nBoards do
        table.insert(
            children,
            Spec.part(`Board_{i}`, {
                Size = { innerW, BOARD_T, BOARD_W },
                CFrame = Spec.cframe({ 0, DECK_TOP - BOARD_T / 2, z0 + (i - 1) * pitch }),
                Material = "Wood",
                Color = TIMBER,
            })
        )
    end

    for i, p in POSTS do
        local px, pz = flush(p[1], X0, X1), flush(p[2], Z0, Z1)
        local h = math.max(SLAB_BOTTOM - p[3], MIN_POST_H)
        table.insert(
            children,
            Spec.part(`Post_{i}`, {
                Size = { POST_W, h, POST_W },
                CFrame = Spec.cframe({ px, SLAB_BOTTOM - h / 2, pz }),
                Material = "Wood",
                Color = TIMBER,
            })
        )
    end

    -- girders: two along the long edges, one cross at mid-span; tops flush under the slab
    local gy = GIRDER_TOP - GIRDER_H / 2
    table.insert(
        children,
        Spec.part("GirderLongA", {
            Size = { GIRDER_W, GIRDER_H, DECK_D },
            CFrame = Spec.cframe({ flush(X0, X0, X1), gy, 0 }),
            Material = "Wood",
            Color = TIMBER,
        })
    )
    table.insert(
        children,
        Spec.part("GirderLongB", {
            Size = { GIRDER_W, GIRDER_H, DECK_D },
            CFrame = Spec.cframe({ flush(X1, X0, X1), gy, 0 }),
            Material = "Wood",
            Color = TIMBER,
        })
    )
    table.insert(
        children,
        Spec.part("GirderCross", {
            Size = { DECK_W, GIRDER_H, GIRDER_W },
            CFrame = Spec.cframe({ 0, gy, 0 }),
            Material = "Wood",
            Color = TIMBER,
        })
    )

    -- seat and rotate: parts are authored about the deck origin, placed into the world here
    local rot = Spec.rotYMat(DOCK_YAW_DEG)
    for _, c in children do
        local cf = c.properties.CFrame
        local p = Spec.rotY({ cf[1], cf[2], cf[3] }, DOCK_YAW_DEG)
        c.properties.CFrame = {
            p[1] + DOCK_CX,
            p[2],
            p[3] + DOCK_CZ,
            rot[1],
            rot[2],
            rot[3],
            rot[4],
            rot[5],
            rot[6],
            rot[7],
            rot[8],
            rot[9],
        }
    end

    return Spec.model("FallsDock", children)
end

return FallsDock
