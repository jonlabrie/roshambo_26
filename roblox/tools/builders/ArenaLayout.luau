--!strict
-- Single source of truth for every world coordinate in the ZenDojo arena.
-- Y=0 is the basin waterline. South (−Z) is the entrance.
-- 2026-06-07 gate feedback: arena scaled +75% wide / +50% deep; the monument
-- (bell/pavilion/basin/jumbotron) stays avatar-scale at center.
local ArenaLayout = {
    bowlRadius = 192,
    basinRadius = 16,
    apronRadius = 74, -- karesansui gravel: basinRadius..apronRadius
    tiers = {
        { radius = 101, height = 4.5 },
        { radius = 133, height = 12 },
        { radius = 164, height = 21 },
    },
    pavilion = { pos = { 0, 0, 0 }, postSpacing = 14, roofHeight = 18 },
    bell = { pos = { 0, 7.5, 0 }, height = 9, radius = 3.4 }, -- bottom lip ~3 studs over water
    shuMoku = { restPos = { 0, 6.2, 9.5 }, length = 7, radius = 0.8, drawStuds = 6 }, -- draws toward +Z
    flume = {
        poolPos = { 94, 13, -70 }, -- pool on tier 2 (SE, radial ~117); base on the tier-12 surface
        poolSize = { 10, 2, 8 },
        wheelPos = { 12, 4, 9 }, -- NE of the pavilion, outside the posts
        wheelRadius = 4,
        -- flume runs pool → over the apron → drops onto wheel top
    },
    promontories = {
        { name = "Record", pos = { 0, 12, 117 } }, -- north (opposite entrance)
        { name = "Streak", pos = { -112, 12, 33 } }, -- west
        { name = "LocalHero", pos = { 112, 12, 33 } }, -- east
    },
    teahouses = {
        { pos = { -91, 12, -80 }, facing = 45 }, -- SW tier 2, porch faces center
        { pos = { 91, 12, -80 }, facing = -45 }, -- SE tier 2
        { pos = { -134, 21, 63 }, facing = 115 }, -- NW tier 3 (upper)
    },
    -- Entrance: gate plaza ON the rim (surface ~y21); the sandō descends
    -- through carved tier walls down to the apron (arrive high, walk down).
    torii = { pos = { 0, 21, -170 } },
    sando = { fromZ = -166, toZ = -76, width = 6, fromY = 21, toY = 2 }, -- rim plaza → apron edge
    stele = { pos = { -12, 21, -160 } },
    koiPond = { pos = { -122, 0, -108 }, radius = 14 },
    jumbotron = { pos = { 0, 26, 0 }, size = { 28, 9, 1 } },
    heroTile = { pos = { 0, 18, 0 }, size = { 5, 6.5, 0.8 } },
    spawn = { pos = { 0, 22, -162 } }, -- on the rim plaza, facing the bell
}
return ArenaLayout
