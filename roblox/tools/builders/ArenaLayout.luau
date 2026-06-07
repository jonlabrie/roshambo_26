--!strict
-- Single source of truth for every world coordinate in the ZenDojo arena.
-- Y=0 is the basin waterline. South (−Z) is the entrance.
local ArenaLayout = {
    bowlRadius = 110,
    basinRadius = 16,
    apronRadius = 42, -- karesansui gravel: basinRadius..apronRadius
    tiers = {
        { radius = 58, height = 3 },
        { radius = 76, height = 8 },
        { radius = 94, height = 14 },
    },
    pavilion = { pos = { 0, 0, 0 }, postSpacing = 14, roofHeight = 18 },
    bell = { pos = { 0, 7.5, 0 }, height = 9, radius = 3.4 }, -- bottom lip ~3 studs over water
    shuMoku = { restPos = { 0, 6.2, 9.5 }, length = 7, radius = 0.8, drawStuds = 6 }, -- draws toward +Z
    flume = {
        poolPos = { 48, 9, -36 }, -- pool on tier 2 (SE, radial 60); base sits on the tier-8 surface
        poolSize = { 10, 2, 8 },
        wheelPos = { 12, 4, 9 }, -- NE of the pavilion, outside the posts
        wheelRadius = 4,
        -- flume runs pool → over the apron → drops onto wheel top
    },
    promontories = {
        { name = "Record", pos = { 0, 8, 64 } }, -- north (opposite entrance)
        { name = "Streak", pos = { -60, 8, 18 } }, -- west
        { name = "LocalHero", pos = { 60, 8, 18 } }, -- east
    },
    teahouses = {
        { pos = { -52, 8, -46 }, facing = 45 }, -- SW, porch faces center
        { pos = { 52, 8, -46 }, facing = -45 }, -- SE
        { pos = { -64, 14, 30 }, facing = 115 }, -- NW upper
    },
    -- Entrance: gate plaza ON the rim (surface y≈14); the sandō descends
    -- through carved tier walls down to the apron (arrive high, walk down).
    torii = { pos = { 0, 14, -100 } },
    sando = { fromZ = -96, toZ = -44, width = 6, fromY = 14, toY = 2 }, -- rim plaza → apron edge
    stele = { pos = { -10, 14, -92 } },
    koiPond = { pos = { -70, 0, -62 }, radius = 14 },
    jumbotron = { pos = { 0, 26, 0 }, size = { 28, 9, 1 } },
    heroTile = { pos = { 0, 18, 0 }, size = { 5, 6.5, 0.8 } },
    spawn = { pos = { 0, 15, -92 } }, -- on the rim plaza, facing the bell
}
return ArenaLayout
