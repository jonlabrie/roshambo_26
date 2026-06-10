--!strict
-- Single source of truth for every world coordinate in the ZenDojo arena.
-- Y=0 is the basin waterline. The entrance (torii/spawn) is at −Z, which is
-- NORTH in Roblox's compass; +Z is South, +X is East, −X is West.
-- 2026-06-07 gate feedback: full 2x scale; tanada (rice-paddy) terraces with
-- flooded outer strips; the monument stays avatar-scale at center.
local Spec = require("./Spec")

-- The whole water drive train (creek → wheels → log → bell) runs down ONE straight
-- line from the entrance-side (NW) rim to the bell. driveYaw rotates that line: 225
-- is the dead NW corner, but that ran the log through the NW pavilion post, so it's
-- nudged a few degrees (toward −X / west) to thread past it. Points are placed in a
-- local frame — +Z = downhill toward the bell (radius → 0) — then rotated by driveYaw.
local driveYaw = 237
local function onLine(radius: number, y: number, cross: number?): { number }
    return Spec.rotY({ cross or 0, y, radius }, driveYaw)
end

-- The shōrō pavilion (and the throw drum atop it) are yawed a few degrees off
-- square so the SW corner post clears the bonshō gantry's west rail + chain,
-- which the drive line (driveYaw) otherwise threads straight through. Negative =
-- the corner swings away from the rail. Both Shoro and ThrowDrum sit at x=z=0, so
-- a rotation about the world-Y origin spins each about its own vertical axis.
local pavilionYaw = -13

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
    pavilion = { pos = { 0, 0, 0 }, postSpacing = 18, roofHeight = 22, yaw = pavilionYaw }, -- grown to clear the +50% bell; yawed to clear the gantry
    -- bell +50% (2026-06-08 gate): diameter ~10 matches the waterwheel; raised so
    -- the body keeps ~1.8 studs of clearance over the basin pool (raised to y1.2).
    bell = { pos = { 0, 9.75, 0 }, height = 13.5, radius = 5.1 },
    shuMoku = {
        restPos = { 0, 6.2, 9.5 },
        length = 7,
        radius = 0.8,
        drawStuds = 6,
        yaw = driveYaw, -- rotate the proven +Z geometry onto the drive line
        -- gantry the log hangs from (rails along Z at x = ±railX, height railY)
        railX = 3,
        railY = 15,
        railZ = { 5, 20 }, -- gantry post Z positions (straddle the log's draw range)
        -- 4 chain attach points: fixed tops on the rails, rest bottoms on the log
        chainTops = { { 3, 15, 7.5 }, { 3, 15, 11.5 }, { -3, 15, 7.5 }, { -3, 15, 11.5 } },
        chainBottomsRest = { { 0.8, 6.6, 7.5 }, { 0.8, 6.6, 11.5 }, { -0.8, 6.6, 7.5 }, { -0.8, 6.6, 11.5 } },
        ropeBottomRest = { 0, 6.2, 13 }, -- the log's back end (rest); the rope's log end
    }, -- draws toward +Z
    -- Natural creek down the SW-ish drive line (replaced the kakehi flume).
    creek = {
        entry = onLine(189.5, 28), -- on the rim (tier-3 height)
        mouth = onLine(17, 0), -- meets the basin water at the SW edge
        width = 5.6, -- channel width (studs); 30% narrower than the original 8
        fastReachRadius = 46, -- inside this radius the channel flattens for the wheels
        -- Sinuous lateral wiggle so the creek reads found, not surveyed. Lateral
        -- offset along the run t∈[0,1] = amp*sin(t*waves*2π), applied perpendicular
        -- to the drive line. Shared by Creek.luau (stones) and buildTerrain (water).
        meander = { amp = 6, waves = 2.5 },
    },
    -- A SINGLE Asakura scoop wheel sitting IN the creek: its raked rim buckets both
    -- catch the current (drive) and lift water, which a launder pours into the sōzu.
    -- One wheel does every job — driving the striker and feeding the sōzu — so the
    -- space stays simple. radius 5 → bottom y−1 dips ~2 studs into the flat (y≈1)
    -- apron current; support posts reach the carved creek bed (bedY).
    waterwheel = {
        radius = 7.5, -- +50% (was 5) so it reads at the bell/drum scale, not dwarfed
        yaw = driveYaw - 180, -- disc axle perpendicular to the current
        driveYaw = driveYaw, -- the line direction (RatchetDrum offsets toward the bell along it)
        bedY = -4, -- creek floor the support posts stand on
        centers = { onLine(25.5, 6.5) }, -- raised with the radius so the bottom keeps its ~2-stud dip
        driver = 1,
        ropeAnchor = onLine(20.6, 6.5), -- on the driver toward the log; DriveRope leaves here
        launderTo = onLine(19, 6, -6), -- the sōzu mouth the lifted water is poured toward
    },
    -- Streamside sozu (shishi-odoshi) that meters the round and kicks the drum.
    sozu = {
        pivot = onLine(20, 4, -6), -- beside the driving wheel, on the left bank
        troughLen = 5,
        cordTop = { -6.82, 31, -1.58 }, -- drum W axle end (throwDrum {0,31,0} len 14, yawed by pavilionYaw)
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
    -- Garden tiers (bottom two terraces). Single source of truth for teahouse
    -- rings AND the water garden in front of them. Radii sit on each tier's
    -- plateau: channel is centre-ward of the hut ring, path centre-ward of the
    -- channel, so a bridge crosses path -> channel -> engawa toward the centre.
    gardenTiers = {
        {
            tier = 1,
            height = 6,
            houseR = 129,
            houseCount = 7,
            housePhase = 0.0,
            channelR = 122,
            channelWidth = 6,
            pathR = 118,
        },
        {
            tier = 2,
            height = 16,
            houseR = 164,
            houseCount = 9,
            housePhase = 0.21,
            channelR = 157,
            channelWidth = 6,
            pathR = 153,
        },
    },
    -- Tier 3 is DRY garden: huts + lanterns + foliage, no channel.
    topTier = { tier = 3, height = 28, houseR = 192, houseCount = 15, housePhase = 0.13 },
    poolRadius = 6, -- still reflecting-pool widenings between hut clusters
    -- the creek bleeds a little water into each tier channel where it crosses
    -- that channel's radius (small stone-lined weirs). onLine() = the drive line.
    branchWeirs = { onLine(157, 16), onLine(122, 6) },
    foliage = {
        heroCherry = { -22, 28, -180 }, -- weeping cherry by the torii/stele on the rim
    },
    firefly = { heroLightCount = 18 }, -- real-PointLight motes near the water (Phase 2)
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
    throwDrum = { pos = { 0, 31, 0 }, length = 14, radius = 7, faces = 6, yaw = pavilionYaw }, -- rides the raised roof; yawed with the pavilion
    spawn = { pos = { 0, 29, -188 } }, -- on the rim plaza, facing the bell
}
return ArenaLayout
