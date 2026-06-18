--!strict
-- Tiered twin downcanyon overlooks off the clearing's EAST edge (spec 2026-06-17).
-- Two stepped kake-zukuri decks + bamboo rail + connecting stone stair + warm lanterns,
-- all aimed ESE down the gorge. Overlooks, not buildings. Part names are the placement /
-- prop-snap contract (UpperDeck/LowerDeck/Post*/Rail*/Step*/Chochin/Ishidoro*).
local Spec = require("./Spec")

local Overlook = {}

local BAMBOO = { 0.74, 0.68, 0.40 } -- tan bamboo (palette has no bamboo key)

-- a bamboo handrail run a→b (deck-edge endpoints, at deck-top height): a cap cylinder
-- raised railH above the deck + vertical balusters every ~2.5 studs up to the cap.
local function railRun(
    children: { any },
    name: string,
    a: { number },
    b: { number },
    deckTopY: number,
    railH: number
)
    local capA = { a[1], deckTopY + railH, a[2] }
    local capB = { b[1], deckTopY + railH, b[2] }
    local pos, len, rot = Spec.segment(capA, capB)
    table.insert(
        children,
        Spec.part(name, {
            Size = { len, 0.16, 0.16 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(pos, rot),
            Color = BAMBOO,
            Material = "Wood",
        })
    )
    local n = math.max(2, math.floor(len / 2.5))
    for i = 0, n do
        local t = i / n
        table.insert(
            children,
            Spec.part(`{name}B{i}`, {
                Size = { railH, 0.12, 0.12 }, -- length first (CYL_VERTICAL re-aims local-X → up)
                Shape = "Cylinder",
                CFrame = Spec.cframe(
                    { a[1] + (b[1] - a[1]) * t, deckTopY + railH / 2, a[2] + (b[2] - a[2]) * t },
                    Spec.ROT.CYL_VERTICAL
                ),
                Color = BAMBOO,
                Material = "Wood",
            })
        )
    end
end

-- slab + 4 kake-zukuri posts + bamboo rail on the 3 outboard edges (West/inboard is the
-- entry from the terrace, left open). Returns the deck's centre + size for lantern placement.
local function deck(
    children: { any },
    name: string,
    d: any,
    palette: { [string]: { number } },
    railH: number,
    postDrop: number
)
    local timber = palette.timber
    local px, py, pz = d.pos[1], d.pos[2], d.pos[3]
    local sx, sy, sz = d.size[1], d.size[2], d.size[3]
    table.insert(
        children,
        Spec.part(name, {
            Size = { sx, sy, sz },
            CFrame = Spec.cframe(d.pos),
            Color = timber,
            Material = "WoodPlanks",
        })
    )
    local hx, hz = sx / 2 - 0.6, sz / 2 - 0.6
    local i = 0
    for _, cx in { -hx, hx } do
        for _, cz in { -hz, hz } do
            i += 1
            table.insert(
                children,
                Spec.part(`Post{name}{i}`, {
                    Size = { 0.7, postDrop, 0.7 },
                    CFrame = Spec.cframe({ px + cx, py - sy / 2 - postDrop / 2, pz + cz }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end
    local topY = py + sy / 2
    local nw, ne = px - sx / 2, px + sx / 2
    local zn, zs = pz - sz / 2, pz + sz / 2
    railRun(children, `RailN{name}`, { nw, zn }, { ne, zn }, topY, railH) -- North edge
    railRun(children, `RailS{name}`, { nw, zs }, { ne, zs }, topY, railH) -- South edge
    railRun(children, `RailE{name}`, { ne, zn }, { ne, zs }, topY, railH) -- East edge (the drop)
    return px, py, pz, sx, sy, sz
end

function Overlook.build(palette: { [string]: { number } }, L: any)
    local o = L.overlooks
    local children = {}
    local upper = o.decks[1].tier == "upper" and o.decks[1] or o.decks[2]
    local lower = o.decks[1].tier == "lower" and o.decks[1] or o.decks[2]
    local ux, uy, uz, usx, _usy, usz = deck(children, "UpperDeck", upper, palette, o.railH, o.postDrop)
    deck(children, "LowerDeck", lower, palette, o.railH, o.postDrop)

    -- connecting stone stair between the tiers (a few steps; lantern-lined at the gate)
    local s = o.stair
    local steps = 4
    for k = 1, steps do
        local t = (k - 0.5) / steps
        table.insert(
            children,
            Spec.part(`Step{k}`, {
                Size = { s.width, 0.5, 1.6 },
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

    -- hero hanging chōchin at the upper deck's outboard corner (placeholder block; T8
    -- converts it to the SpecialMesh-sphere primitive + Neon + PointLight).
    table.insert(
        children,
        Spec.part("Chochin", {
            Size = { 1.45, 2.38, 1.45 },
            CFrame = Spec.cframe({ ux + usx / 2 - 0.6, uy + 2.0, uz - usz / 2 }),
            Color = palette.gold,
            Material = "Neon",
        })
    )
    -- standing ishidōrō along the upper rail line
    for k, cx in { -usx / 2 + 1.5, usx / 2 - 1.5 } do
        table.insert(
            children,
            Spec.part(`Ishidoro{k}`, {
                Size = { 0.8, 2.4, 0.8 },
                CFrame = Spec.cframe({ ux + cx, uy + 1.5, uz - usz / 2 + 0.4 }),
                Color = palette.ink,
                Material = "Slate",
            })
        )
    end
    return Spec.model("Overlook", children)
end

return Overlook
