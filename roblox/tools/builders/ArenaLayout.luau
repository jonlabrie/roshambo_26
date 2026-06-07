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
        poolPos = { 34, 9, -26 }, -- on tier 2 (SE); height 9 keeps pool strictly above wheel top (4+4=8)
        poolSize = { 10, 2, 8 },
        wheelPos = { 7, 4, 5 }, -- beside the pavilion, NE of bell
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
    torii = { pos = { 0, 0, -100 } },
    sando = { fromZ = -98, toZ = -44, width = 6 }, -- gate to apron edge
    stele = { pos = { -10, 0, -92 } },
    koiPond = { pos = { -70, 0, -62 }, radius = 14 },
    jumbotron = { pos = { 0, 26, 0 }, size = { 28, 9, 1 } },
    heroTile = { pos = { 0, 19, 0 }, size = { 5, 6.5, 0.8 } },
    spawn = { pos = { 0, 1, -52 } }, -- on the sandō, facing the bell
}
return ArenaLayout
