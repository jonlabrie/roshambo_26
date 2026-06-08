--!strict
-- Single source of truth for every world coordinate in the ZenDojo arena.
-- Y=0 is the basin waterline. South (−Z) is the entrance.
-- 2026-06-07 gate feedback: full 2x scale; tanada (rice-paddy) terraces with
-- flooded outer strips; the monument stays avatar-scale at center.
local ArenaLayout = {
    bowlRadius = 220,
    basinRadius = 16,
    apronRadius = 84, -- karesansui gravel: basinRadius..apronRadius
    tiers = {
        { radius = 116, height = 6 },
        { radius = 152, height = 16 },
        { radius = 188, height = 28 },
    },
    -- flooded paddy strip: outer N studs of each tier surface, against the wall
    paddyStripWidth = 10,
    pavilion = { pos = { 0, 0, 0 }, postSpacing = 14, roofHeight = 18 },
    bell = { pos = { 0, 7.5, 0 }, height = 9, radius = 3.4 }, -- bottom lip ~3 studs over water
    shuMoku = {
        restPos = { 0, 6.2, 9.5 },
        length = 7,
        radius = 0.8,
        drawStuds = 6,
        -- gantry the log hangs from (rails along Z at x = ±railX, height railY)
        railX = 3,
        railY = 15,
        railZ = { 5, 20 }, -- gantry post Z positions (straddle the log's draw range)
        -- 4 chain attach points: fixed tops on the rails, rest bottoms on the log
        chainTops = { { 3, 15, 7.5 }, { 3, 15, 11.5 }, { -3, 15, 7.5 }, { -3, 15, 11.5 } },
        chainBottomsRest = { { 0.8, 6.6, 7.5 }, { 0.8, 6.6, 11.5 }, { -0.8, 6.6, 7.5 }, { -0.8, 6.6, 11.5 } },
        ropeBottomRest = { 0, 6.2, 13 }, -- the log's back end (rest); the rope's log end
    }, -- draws toward +Z
    flume = {
        poolPos = { 0, 26, 62 }, -- raised header cistern on the Z axis, north of the wheel
        poolSize = { 10, 2, 8 },
        wheelPos = { 0, 7, 26 }, -- directly north of the log, on the Z axis
        wheelRadius = 5,
        ropeWheelAnchor = { 0, 7, 25 }, -- fixed point on the wheel/drum the rope leaves from
        -- flume runs pool → descends → drops onto wheel top
    },
    promontories = {
        { name = "Record", pos = { 0, 16, 134 } }, -- north (opposite entrance)
        { name = "Streak", pos = { -128, 16, 38 } }, -- west
        { name = "LocalHero", pos = { 128, 16, 38 } }, -- east
    },
    teahouses = {
        { pos = { -98, 16, -88 }, facing = 45 }, -- SW tier 2, porch faces center
        { pos = { 98, 16, -88 }, facing = -45 }, -- SE tier 2
        { pos = { -145, 28, 68 }, facing = 115 }, -- NW tier 3 (upper)
    },
    -- Entrance: gate plaza ON the rim (surface ~y28); the sandō descends
    -- through carved tier walls down to the apron (arrive high, walk down).
    torii = { pos = { 0, 28, -196 } },
    sando = { fromZ = -192, toZ = -86, width = 6, fromY = 28, toY = 2 }, -- rim plaza → apron edge
    stele = { pos = { -14, 28, -186 } },
    koiPond = { pos = { -130, 0, -115 }, radius = 14 },
    jumbotron = { pos = { 0, 96, 0 }, size = { 168, 96, 1 } }, -- hung sports-arena high; tall rows for big legible tiles
    heroTile = { pos = { 0, 18, 0 }, size = { 5, 6.5, 0.8 } },
    -- Hexagonal World-Throw drum atop the shōrō (ridge ~y22; y24 clears the
    -- y28 top tier enough to read). Horizontal axis = world X (E/W).
    throwDrum = { pos = { 0, 29, 0 }, length = 14, radius = 7, faces = 6 },
    spawn = { pos = { 0, 29, -188 } }, -- on the rim plaza, facing the bell
}
return ArenaLayout
