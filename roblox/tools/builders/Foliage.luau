--!strict
-- Mature planting as simple part-trees (trunk + canopy blobs). Scattered
-- deterministically (sin-hash) along each tier's rear foliage bank and the top
-- tier, plus a hero weeping cherry by the torii. Species vary by colour/shape.
-- Graybox fidelity: blobs, not meshes. Trees stay off the channel water and out of
-- the sandō gap. Colours come from the ZenDojo palette (moss/timber) plus a couple
-- of local accents kept here so the theme palette stays small.
local Spec = require("./Spec")

local Foliage = {}

local GROUND_LIFT = 2
local SANDO = 1.5 * math.pi

local MAPLE = { 0.55, 0.28, 0.20 } -- autumn red-bronze canopy
local PINE = { 0.20, 0.34, 0.24 } -- dark green
local CHERRY = { 0.80, 0.72, 0.74 } -- pale blossom

local function rand(seed: number): number
    local v = math.sin(seed * 12.9898) * 43758.5453
    return v - math.floor(v)
end

-- a tree = trunk + 1-3 canopy blobs. Returns a Model named `name`.
local function tree(
    name: string,
    x: number,
    y: number,
    z: number,
    h: number,
    canopy: { number },
    blobs: number
)
    local kids = {
        Spec.part("Trunk", {
            Size = { 0.8, h, 0.8 },
            CFrame = Spec.cframe({ x, y + h / 2, z }),
            Color = { 0.35, 0.26, 0.18 },
            Material = "Wood",
        }),
    }
    for b = 1, blobs do
        local s = 3 + rand(x * 7 + z * 13 + b) * 2.5
        local ox = (rand(x + b) - 0.5) * 2.5
        local oz = (rand(z + b * 3) - 0.5) * 2.5
        table.insert(
            kids,
            Spec.part(`Canopy{b}`, {
                Size = { s, s * 0.8, s },
                CFrame = Spec.cframe({ x + ox, y + h + s * 0.3, z + oz }),
                Color = canopy,
                Material = "Grass",
                Shape = "Ball",
            })
        )
    end
    return Spec.model(name, kids)
end

function Foliage.build(_palette: { [string]: { number } }, L: any)
    local children = {}

    -- hero weeping cherry on the rim by the torii/stele
    local c = L.foliage.heroCherry
    table.insert(children, tree("Cherry", c[1], c[2], c[3], 6, CHERRY, 3))

    -- rear foliage bank on each tier (just outside the hut ring) + top tier ring.
    local rings = {}
    for _, g in L.gardenTiers do
        table.insert(rings, { tier = g.tier, height = g.height, r = g.houseR + 8, species = "bank" })
    end
    table.insert(
        rings,
        { tier = L.topTier.tier, height = L.topTier.height, r = L.topTier.houseR + 10, species = "pine" }
    )

    for _, ring in rings do
        local gy = ring.height + GROUND_LIFT
        local n = 10
        for k = 0, n - 1 do
            local a = (k / n) * 2 * math.pi + rand(ring.tier * 53 + k) * 0.2
            if math.abs(((a - SANDO + math.pi) % (2 * math.pi)) - math.pi) < 0.22 then
                continue
            end
            local r = ring.r + (rand(ring.tier * 17 + k) - 0.5) * 5
            local x, z = r * math.cos(a), r * math.sin(a)
            local pick = rand(ring.tier * 91 + k)
            if ring.species == "pine" or pick < 0.34 then
                table.insert(children, tree(`Pine{ring.tier}_{k}`, x, gy, z, 7, PINE, 2))
            elseif pick < 0.7 then
                table.insert(children, tree(`Maple{ring.tier}_{k}`, x, gy, z, 5, MAPLE, 3))
            else
                -- bamboo: a tight stand of thin tall stalks
                local kids = {}
                for si = 1, 5 do
                    local ox, oz = (rand(k + si) - 0.5) * 2, (rand(k * 2 + si) - 0.5) * 2
                    table.insert(
                        kids,
                        Spec.part(`Stalk{si}`, {
                            Size = { 0.3, 9, 0.3 },
                            CFrame = Spec.cframe({ x + ox, gy + 4.5, z + oz }),
                            Color = { 0.45, 0.5, 0.3 },
                            Material = "Wood",
                        })
                    )
                end
                -- a Trunk alias so the off-water test can read this stand's position
                kids[1].name = "Trunk"
                table.insert(children, Spec.model(`Bamboo{ring.tier}_{k}`, kids))
            end
        end
    end

    -- a hero maple leaning over one still pool per wet tier
    for _, g in L.gardenTiers do
        local a = g.housePhase + 0.4
        local r = g.channelR - g.channelWidth / 2 - 4 -- bankside, off the water
        table.insert(
            children,
            tree(`MaplePool{g.tier}`, r * math.cos(a), g.height + GROUND_LIFT, r * math.sin(a), 6, MAPLE, 3)
        )
    end
    return Spec.model("Foliage", children)
end

return Foliage
