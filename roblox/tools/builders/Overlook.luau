--!strict
-- Tiered twin downcanyon overlooks off the clearing's EAST edge (spec 2026-06-17).
-- Two stepped kake-zukuri decks cantilevered over the gorge: heavy timber posts, an
-- under-slab girder frame, KŌRAN railings (flat cap + mid-rail + square balusters +
-- corner newels, matching the teahouse engawa), a connecting stair on stringers, and
-- warm lanterns. Part names are the placement/prop-snap contract.
local Spec = require("./Spec")

local Overlook = {}

-- ===== helpers =====
-- axis-aligned horizontal box beam from p0 to p1 (each {x,z}) at height y, cross-section
-- ch (height) × cw (width); auto-orients along whichever of X/Z varies more.
local function barSeg(
    children: { any },
    name: string,
    p0: { number },
    p1: { number },
    y: number,
    ch: number,
    cw: number,
    color: { number }
)
    local dx, dz = p1[1] - p0[1], p1[2] - p0[2]
    local size = if math.abs(dx) >= math.abs(dz) then { math.abs(dx), ch, cw } else { cw, ch, math.abs(dz) }
    table.insert(
        children,
        Spec.part(name, {
            Size = size,
            CFrame = Spec.cframe({ (p0[1] + p1[1]) / 2, y, (p0[2] + p1[2]) / 2 }),
            Color = color,
            Material = "Wood",
        })
    )
end

local function inGap(along: number, gapC: number?, gapH: number?): boolean
    return gapC ~= nil and gapH ~= nil and math.abs(along - gapC) < gapH
end

-- split a run a→b into the subsegments OUTSIDE the gap (for cap + mid-rail)
local function splitRun(a: { number }, b: { number }, vertical: boolean, gapC: number?, gapH: number?)
    if not (gapC and gapH) then
        return { { a, b } }
    end
    local axA = if vertical then a[2] else a[1]
    local axB = if vertical then b[2] else b[1]
    local function ptAt(ax: number): { number }
        local t = (ax - axA) / (axB - axA)
        return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t }
    end
    local mn, mx = math.min(axA, axB), math.max(axA, axB)
    local segs = {}
    if (gapC - gapH) > mn then
        table.insert(segs, { ptAt(mn), ptAt(gapC - gapH) })
    end
    if (gapC + gapH) < mx then
        table.insert(segs, { ptAt(gapC + gapH), ptAt(mx) })
    end
    return segs
end

-- KŌRAN railing run a→b: flat cap beam + mid-rail + square balusters. Optional gap
-- (gapC/gapH along the varying axis) leaves an opening for the stair.
local function railRun(
    children: { any },
    name: string,
    a: { number },
    b: { number },
    deckTopY: number,
    railH: number,
    timber: { number },
    gapC: number?,
    gapH: number?
)
    local vertical = math.abs(b[2] - a[2]) > math.abs(b[1] - a[1])
    local capY = deckTopY + railH
    local midY = deckTopY + railH - 1.1
    for si, seg in splitRun(a, b, vertical, gapC, gapH) do
        barSeg(children, `{name}Cap{si}`, seg[1], seg[2], capY, 0.3, 0.6, timber) -- flat top cap
        barSeg(children, `{name}Mid{si}`, seg[1], seg[2], midY, 0.25, 0.42, timber) -- mid rail
    end
    local _, len = Spec.segment({ a[1], capY, a[2] }, { b[1], capY, b[2] })
    local n = math.max(2, math.floor(len / 1.7)) -- denser pickets
    for i = 0, n do
        local t = i / n
        local px, pz = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
        local along = if vertical then pz else px
        if not inGap(along, gapC, gapH) then
            table.insert(
                children,
                Spec.part(`{name}B{i}`, {
                    -- square baluster, embedded into the deck and rising the full railH into
                    -- the cap. Shape MUST be set explicitly: these parts were Cylinders in an
                    -- earlier version and Rojo patches by name — omitting Shape leaves the old
                    -- Cylinder, which renders as a horizontal dowel at box Size.
                    Shape = "Block",
                    Size = { 0.34, railH + 0.4, 0.34 },
                    CFrame = Spec.cframe({ px, deckTopY + railH / 2 - 0.2, pz }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end
end

-- a square Hanji paper lantern (warm glowing box + dim PointLight) sitting at baseY.
-- The kumiko lattice + the live World-Throw glyph are drawn on the faces at runtime by
-- LanternController (SurfaceGui) — the builder only ships the glowing body + cap.
local function hanjiLantern(
    children: { any },
    name: string,
    x: number,
    z: number,
    baseY: number,
    palette: { [string]: { number } }
)
    local h = 1.5
    local cy = baseY + h / 2
    table.insert(
        children,
        Spec.part(`{name}Lantern`, {
            Shape = "Block",
            Size = { 1.0, h, 1.0 }, -- square paper lantern
            CFrame = Spec.cframe({ x, cy, z }),
            Color = { 0.588, 0.5, 0.421 }, -- chōchin paper tone, dimmed ×0.75 (core dimmed to match → stays blended)
            Material = "Neon",
            Transparency = 0.42, -- translucent paper so the inner glow reads through (chōchin recipe)
            children = {
                {
                    name = `{name}Light`,
                    className = "PointLight",
                    properties = { Color = { 1.0, 0.659, 0.376 }, Brightness = 0.3, Range = 5 },
                },
            },
        })
    )
    -- the "lit-from-within" glow is a soft radial sprite added at runtime by LanternController
    -- (a Neon ball read as a hard sphere on this small box); the builder ships only the paper + cap.
    table.insert(
        children,
        Spec.part(`{name}Cap`, {
            Shape = "Block",
            Size = { 1.2, 0.18, 1.2 }, -- dark timber cap on top
            CFrame = Spec.cframe({ x, baseY + h + 0.09, z }),
            Color = palette.ink,
            Material = "Wood",
        })
    )
end

-- a chunky corner/end newel post, capped with a Hanji lantern
local function newel(
    children: { any },
    name: string,
    x: number,
    z: number,
    topY: number,
    railH: number,
    palette: { [string]: { number } },
    noLantern: boolean?
)
    local h = railH + 0.9
    local newelTop = topY + h - 0.2
    table.insert(
        children,
        Spec.part(name, {
            Shape = "Block",
            Size = { 0.62, h, 0.62 },
            CFrame = Spec.cframe({ x, topY + h / 2 - 0.2, z }),
            Color = palette.timber,
            Material = "Wood",
        })
    )
    if not noLantern then -- some newels keep the post but drop the lantern (thinning the row)
        hanjiLantern(children, name, x, z, newelTop, palette)
    end
end

-- invisible, collidable safety wall along an edge run a→b: tall enough that a jump from
-- the cap rail can't clear it, so players can't launch off into the gorge.
local function barrierSeg(children: { any }, name: string, p0: { number }, p1: { number }, deckTopY: number)
    local H = 12
    local dx, dz = p1[1] - p0[1], p1[2] - p0[2]
    local size = if math.abs(dx) >= math.abs(dz) then { math.abs(dx), H, 0.4 } else { 0.4, H, math.abs(dz) }
    table.insert(
        children,
        Spec.part(name, {
            Shape = "Block",
            Size = size,
            CFrame = Spec.cframe({ (p0[1] + p1[1]) / 2, deckTopY + H / 2, (p0[2] + p1[2]) / 2 }),
            Transparency = 1,
            CanCollide = true,
            Color = { 0.5, 0.5, 0.5 },
            Material = "SmoothPlastic",
        })
    )
end

-- slab + heavy posts + under-slab girder frame + kōran rails. `rail.open` (N/S/E/W) is the
-- entry edge, left railless; `rail.gapEdge`+gapC/gapH cut a stair opening (framed by endposts).
-- Returns deck centre + size for lantern placement.
local function deck(
    children: { any },
    name: string,
    d: any,
    palette: { [string]: { number } },
    railH: number,
    postDrop: number,
    rail: { open: string?, gapEdge: string?, gapC: number?, gapH: number?, noBarrier: string? }?,
    skipLanterns: { [string]: boolean }? -- post names whose lantern is dropped (post kept)
)
    local timber, ink = palette.timber, palette.ink
    skipLanterns = skipLanterns or {}
    local px, py, pz = d.pos[1], d.pos[2], d.pos[3]
    local sx, sy, sz = d.size[1], d.size[2], d.size[3]
    local nw, ne = px - sx / 2, px + sx / 2
    local zn, zs = pz - sz / 2, pz + sz / 2
    local botY = py - sy / 2

    -- plank deck slab
    table.insert(
        children,
        Spec.part(name, {
            Size = { sx, sy, sz },
            CFrame = Spec.cframe(d.pos),
            Color = timber,
            Material = "WoodPlanks",
        })
    )

    -- UNDER-SLAB GIRDER FRAME: 3 heavy beams running the cantilever axis (X) + 2 rim
    -- beams across (Z). Reads as a built underframe carrying the deck out over the drop.
    local gh = 1.6 -- girder depth
    local gy = botY - gh / 2
    local inset = 1.3
    for gi, gz in { zn + inset, pz, zs - inset } do
        barSeg(children, `Girder{name}X{gi}`, { nw, gz }, { ne, gz }, gy, gh, 1.1, timber)
    end
    for gi, gx in { nw + inset, ne - inset } do
        barSeg(children, `Girder{name}Z{gi}`, { gx, zn }, { gx, zs }, gy - 0.2, gh, 1.0, ink)
    end

    -- HEAVY kake-zukuri posts under the girder ends
    local hx, hz = sx / 2 - inset, sz / 2 - inset
    local i = 0
    for _, cx in { -hx, hx } do
        for _, cz in { -hz, hz } do
            i += 1
            table.insert(
                children,
                Spec.part(`Post{name}{i}`, {
                    Size = { 1.5, postDrop, 1.5 },
                    CFrame = Spec.cframe({ px + cx, gy - gh / 2 - postDrop / 2, pz + cz }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end

    -- KŌRAN rails on every edge EXCEPT the entry (rail.open); a stair edge gets a gap
    -- framed by endposts. Edges run along X (N/S) or Z (E/W).
    local topY = py + sy / 2
    rail = rail or {}
    local function edge(e: string, a: { number }, b: { number })
        if rail.open == e then
            return -- entry side: no rail
        end
        local gc, ghalf = nil, nil
        if rail.gapEdge == e then
            gc, ghalf = rail.gapC, rail.gapH
        end
        railRun(children, `Rail{e}{name}`, a, b, topY, railH, timber, gc, ghalf)
        -- invisible safety barrier over the same span (split around the stair gap), unless
        -- this edge is the stair landing (rail.noBarrier) — a barrier there blocks the steps.
        if rail.noBarrier ~= e then
            local vertical = math.abs(b[2] - a[2]) > math.abs(b[1] - a[1])
            for si, seg in splitRun(a, b, vertical, gc, ghalf) do
                barrierSeg(children, `Barrier{e}{name}{si}`, seg[1], seg[2], topY)
            end
        end
        if gc and ghalf then -- frame the stair opening with endposts (gapped edges run along X)
            newel(
                children,
                `Rail{e}{name}EndA`,
                gc - ghalf,
                a[2],
                topY,
                railH,
                palette,
                skipLanterns[`Rail{e}{name}EndA`]
            )
            newel(
                children,
                `Rail{e}{name}EndB`,
                gc + ghalf,
                a[2],
                topY,
                railH,
                palette,
                skipLanterns[`Rail{e}{name}EndB`]
            )
        end
    end
    edge("N", { nw, zn }, { ne, zn })
    edge("S", { nw, zs }, { ne, zs })
    edge("E", { ne, zn }, { ne, zs })
    edge("W", { nw, zn }, { nw, zs })
    -- chunky newels at the four corners, each capped with a Hanji lantern
    for ci, c in { { nw, zn }, { ne, zn }, { ne, zs }, { nw, zs } } do
        newel(children, `Newel{name}{ci}`, c[1], c[2], topY, railH, palette, skipLanterns[`Newel{name}{ci}`])
    end
    return px, py, pz, sx, sy, sz
end

function Overlook.build(palette: { [string]: { number } }, L: any)
    local o = L.overlooks
    local children = {}
    local upper = o.decks[1].tier == "upper" and o.decks[1] or o.decks[2]
    local lower = o.decks[1].tier == "lower" and o.decks[1] or o.decks[2]
    -- Upper deck: entry from the West (clearing); the stair exits its North edge through a
    -- rail gap framed by endposts. Lower deck: entry from the South (off the stair) — that
    -- edge is simply open, no rail/cutout needed.
    local stairX = o.stair.from[1]
    local gapHalf = o.stair.width / 2 + 0.6
    local ux, uy, uz, usx, usy, usz = deck(
        children,
        "UpperDeck",
        upper,
        palette,
        o.railH,
        o.postDrop,
        { open = "W", gapEdge = "N", gapC = stairX, gapH = gapHalf },
        -- thin the row: drop the NW-corner lantern + the two stair-top (N-rail end) lanterns
        { NewelUpperDeck1 = true, RailNUpperDeckEndA = true, RailNUpperDeckEndB = true }
    )
    -- Lower deck: West edge is the open entry (no rail); South/N/E all railed, the South
    -- rail contiguous (it crosses the stair). No barrier on the South edge — that's the
    -- stair landing (inland-facing, not the gorge), and a barrier there blocks the steps.
    -- thin the row: drop the SE-corner lantern of the lower deck
    deck(
        children,
        "LowerDeck",
        lower,
        palette,
        o.railH,
        o.postDrop,
        { open = "W", noBarrier = "S" },
        { NewelLowerDeck3 = true }
    )

    -- single low threshold step onto the upper deck from the clearing (the open West edge),
    -- half the deck width, centred. Top ~1.2 below the deck; deepened to meet the terrace.
    local deckTop = uy + usy / 2
    local stepH = 2.1
    table.insert(
        children,
        Spec.part("UpperStep", {
            Shape = "Block",
            Size = { 4, stepH, usz * 0.5 },
            CFrame = Spec.cframe({ (ux - usx / 2) - 1, (deckTop - 1.2) - stepH / 2, uz }),
            Color = palette.timber,
            Material = "Wood",
        })
    )

    -- connecting stair between the tiers, carried on two sloped STRINGERS
    local s = o.stair
    local steps = 5
    for k = 1, steps do
        local t = (k - 0.5) / steps
        table.insert(
            children,
            Spec.part(`Step{k}`, {
                Size = { s.width, 0.5, 2.0 },
                CFrame = Spec.cframe({
                    s.from[1] + (s.to[1] - s.from[1]) * t,
                    s.from[2] + (s.to[2] - s.from[2]) * t,
                    s.from[3] + (s.to[3] - s.from[3]) * t,
                }),
                Color = palette.ink,
                Material = "Slate",
            })
        )
    end
    -- stringers: a beam under each side of the treads, top→bottom
    for si, off in { -(s.width / 2 - 0.3), s.width / 2 - 0.3 } do
        local a = { s.from[1] + off, s.from[2] - 0.7, s.from[3] }
        local b = { s.to[1] + off, s.to[2] - 0.7, s.to[3] }
        local pos, len, rot = Spec.segment(a, b)
        table.insert(
            children,
            Spec.part(`Stringer{si}`, {
                Size = { len, 0.9, 0.5 },
                CFrame = Spec.cframe(pos, rot),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end

    return Spec.model("Overlook", children)
end

return Overlook
