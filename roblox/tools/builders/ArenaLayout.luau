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
    -- ===== Canyon clearing (focal heart) — supersedes the bowl monument zone =====
    -- World origin = clearing centre. Pool/in-fall upstream (−X); boundary fall
    -- downstream (+X); the machine is centred at the pool's downstream lip, Y on the
    -- leveled clearing floor. Starting values — tuned at the terrain/machine gates.
    clearing = {
        floorY = 112,
        poolCentre = { -34, 110, 0 },
        poolHalf = 28,
        poolSurfaceY = 110, -- recessed basin
        outcropCentre = { 40, 112, 0 },
        outcropHalf = { 48, 34 }, -- gathering shelf
        boundaryX = 124,
        boundaryLipY = 100, -- lowest fall
        inFallTopY = 150, -- in-fall crest
    },
    pavilion = { pos = { -2, 112, 0 }, postSpacing = 18, roofHeight = 22, yaw = 0 },
    -- bonshō bell: hangs centred above the clearing floor (radius/height unchanged).
    bell = { pos = { -2, 121, 0 }, height = 13.5, radius = 5.1 },
    -- shu-moku striker, re-staged on the clearing axis (yaw 0; draws toward +Z, swings
    -- into the bell's +Z face). Y values lifted to the clearing floor (~112+).
    shuMoku = {
        restPos = { -2, 118, 9 },
        length = 7,
        radius = 0.8,
        drawStuds = 6,
        yaw = 0,
        railX = 3,
        railY = 127,
        railZ = { 5, 20 },
        chainTops = { { 3, 127, 7.5 }, { 3, 127, 11.5 }, { -3, 127, 7.5 }, { -3, 127, 11.5 } },
        chainBottomsRest = {
            { 0.8, 118.6, 7.5 },
            { 0.8, 118.6, 11.5 },
            { -0.8, 118.6, 7.5 },
            { -0.8, 118.6, 11.5 },
        },
        ropeBottomRest = { -2, 118, 13 },
    },
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
    -- OVERSHOT waterwheel: sits ABOVE the plunge pool (bottom clears the water), fed
    -- on top by a headrace flume tapping the in-fall, draining into the pool below.
    -- hub y118, radius 6 → bottom 112 (= floor) clears the pool surface (110).
    waterwheel = {
        radius = 6,
        overshot = true,
        yaw = 90, -- disc axle across the clearing (X), wheel face along the current
        driveYaw = 0, -- drive line toward the bell (RatchetDrum offsets along it)
        bedY = 112, -- support posts stand on the clearing floor (not submerged)
        centers = { { -16, 118, -4 } },
        driver = 1,
        ropeAnchor = { -13, 118, -4 }, -- on the driver toward the bell; DriveRope leaves here
        headFrom = { -30, 132, -4 }, -- taps the in-fall
        headTo = { -16, 124, -4 }, -- pours onto the wheel top (hub 118 + radius 6)
        launderTo = { -8, 116, 8 }, -- small bleed trough to the sōzu mouth
    },
    -- sōzu (shishi-odoshi) beside the wheel; meters the round and kicks the drum.
    sozu = {
        pivot = { -8, 116, 8 },
        troughLen = 5,
        cordTop = { -2, 138, -2 }, -- the throw drum's axle end
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
    throwDrum = { pos = { -2, 138, 0 }, length = 14, radius = 7, faces = 6, yaw = 0 }, -- rides the shōrō above the bell, on the clearing axis
    spawn = { pos = { 0, 29, -188 } }, -- on the rim plaza, facing the bell
}
return ArenaLayout
