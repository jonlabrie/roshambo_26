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
        poolSurfaceY = 111, -- raised ~3 studs (was 108 in terrain) so the wheel sits in the current; just below the y112 banks
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
        railX = 4, -- wider arm spacing so the dowels clear the gantry legs through the swing (was 3)
        railY = 124.5, -- gantry post height (raised 20% from 122.5 so the chains hang cleaner); top frame braced
        railZ = { 6, 13 }, -- shortened to the shu-moku's actual cam-driven draw (was {5,20})
        -- chain attach points, centred on the shu-moku centreline (x=-2): rail tops at
        -- x=-2±4 = {2,-6} (match railX), y=railY; log attach points at x=-2±0.8 = {-1.2,-2.8}.
        chainTops = { { 2, 124.5, 7.5 }, { 2, 124.5, 11.5 }, { -6, 124.5, 7.5 }, { -6, 124.5, 11.5 } },
        chainBottomsRest = {
            { -1.2, 118.6, 7.5 },
            { -1.2, 118.6, 11.5 },
            { -2.8, 118.6, 7.5 },
            { -2.8, 118.6, 11.5 },
        },
        ropeBottomRest = { -2, 118, 13 },
        -- DRAW dowel: a SHORT horizontal peg out the log's tail (z≈11) reaching West to
        -- the BellDrive cam (x=-4); short enough to clear the west gantry leg (x=-6).
        drawDowel = { from = { -1.5, 118, 11 }, to = { -4, 118, 11 } },
        -- KICK dowel: a SHORT east-flank peg (to x=1) that kicks the vertical-shaft
        -- paddle; short enough to clear the east gantry leg (x=2).
        kickDowel = { from = { -1.5, 118, 6 }, to = { 0.75, 118, 6 } }, -- tip pulled back to clear the vertical drive shaft (x=1)
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
    -- IN-RIVER waterwheel: rests in the river North (−Z) of the tower, shifted UPRIVER
    -- (West, −X) so the drive train clears the bell + tower posts. Bigger + raised so
    -- its Z-axle (the main shaft) sits well above the clearing floor. Turned by the +X
    -- current; lower paddles dip into the water (undershot); supports on the riverbed.
    waterwheel = {
        radius = 9, -- bigger: lifts the axle/main shaft above ground while paddles stay in the water
        width = 2.4, -- twice as thick (was 1.2) — a beefier mill wheel
        overshot = false,
        yaw = 90, -- axle along Z; disc faces the +Z gathering, paddles catch the +X current
        driveYaw = 0, -- drive line toward the bell (RatchetDrum offsets along it)
        bedY = 104, -- support posts stand on the riverbed (river floor ~104)
        centers = { { -15, 116, -23 } }, -- farther North, out into the river channel (off the gravel bank)
        driver = 1,
        ropeAnchor = { -15, 116, -15 },
    },
    -- (sōzu removed — the throw-lockout beat moves to sound/UI; see the bell-engine spec.)
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
    -- southSpokeR: the +Z (south) end spokes extend to this radius so they hang down as
    -- PINS near the roof (148 - 12 = y136) for the drive paddles to flick.
    throwDrum = { pos = { -2, 148, 0 }, length = 11, radius = 7, faces = 6, yaw = 90, southSpokeR = 11.5 }, -- centred over the roof; faces up/downriver (±X)
    -- ===== Bell engine drive train (exposed on the open frame) =====
    -- One water input → two outputs. The wheel's Z-axle is the MAIN SHAFT; it runs
    -- South down the WEST (upriver) side of the bell+tower (clearing both), then a
    -- right-angle BEVEL turns the drive onto an E–W CAM SHAFT pointed East at the
    -- shu-moku. A cam on that E–W shaft (sweeping the N–S vertical plane) catches the
    -- shu-moku's horizontal draw dowel, drawing the log back over the round then
    -- releasing it (gong). The swing's east-flank dowel kicks the vertical-shaft
    -- paddle → spins the drum. Starting coords; tuned at the staging gate.
    bellDrive = {
        -- MAIN SHAFT: along Z (N–S), West of the bell+posts, raised to the wheel axle.
        shaftFrom = { -15, 116, -23 }, -- = wheel centre (moved out into the river)
        shaftTo = { -15, 116, 11 },
        shaftR = 0.6,
        -- BEVEL gear-down at the SW corner: small DriverGear (axle Z) on the main shaft
        -- meshes the big slow CamGear (axle X) on the cam shaft → the once-per-round
        -- reduction, turned through 90°.
        driverGear = { -15, 116, 9.4 },
        driverR = 1.6,
        camGear = { -13.4, 116, 11 },
        camR = 3.0, -- shrunk so the rim clears the ground (was 3.6)
        -- E–W CAM SHAFT: along X at the shu-moku tail (z=11, between the tower posts at
        -- z=9 and the gantry at z=13; South of the bell), pointed East at the log.
        camShaftFrom = { -15, 116, 11 },
        camShaftTo = { -3.5, 116, 11 }, -- extended East ~0.5 so the cam reaches into the draw dowel's plane
        camShaftR = 0.6,
        -- snail draw cam on the X cam shaft (turns about X at `cam` once per round).
        -- ~30% smaller; the draw is faked in the controller, so cam size is visual —
        -- contact with the dowel is tuned at the gate. Sits within the dowel span (x[-4..-1.5]).
        cam = { -3.5, 116, 11 },
        camHubR = 1.4, -- cam body (hub / base-circle) radius
        camLobeR = 3.85, -- snail peak reaches this far from the axle — the draw throw
        -- KICK shaft + paddle (drum kick), just East/South of the shu-moku, by the kick
        -- dowel's tip (x=1, z=6) and clear of the bell (z>5.1) and posts. Capped UNDER
        -- the roof — it no longer runs up through the drum (drum is centred elsewhere);
        -- how it drives the centred drum is the next staging question.
        vertBase = { 1, 112, 6 },
        vertTop = { 1, 137.6, 6 }, -- reaches up into DriveGearA (y137.5) so the shaft meets the gear
        vertR = 0.23, -- slim drive rod (~1/3 the old diameter)
        paddle = { 1, 118, 6 },
        paddleLen = 2.4, -- kicked by the shu-moku's east-flank dowel
        -- Drum drive (pin-wheel): a flat gear caps the kick shaft (DriveGearA, spins
        -- about Y); it meshes an EQUAL-radius flat gear (DriveGearB) — equal so A's
        -- ½-turn = B's ½-turn. B carries two paddles sticking OUTWARD (horizontal, on its
        -- E/W sides); a kick sweeps them across the drum's hanging south spoke → spin.
        -- Starting coords — the mesh + paddle reach are tuned at the gate.
        driveGearA = { 1, 137.5, 6 },
        driveGearAR = 1.2,
        driveGearB = { -1.18, 137.5, 7 }, -- 2.4 from A → 1:1 mesh at radius 1.2
        driveGearBR = 1.2,
        paddleReach = 1.6, -- horizontal paddle-arm length out past B's rim (±X)
        -- shaft bearings (trestle post + saddle): two on the main-shaft run (wheel→bevel),
        -- one at the bevel corner, one just behind the cam on the E-W shaft. {x, z} on
        -- the shaft line at shaft height; posts drop to bearingBaseY.
        bearings = { { -15, -6 }, { -15, 2 }, { -15, 11 }, { -5.5, 11 } },
        bearingBaseY = 110,
        -- The drum's bearing yoke (A-frames) is built from throwDrum.pos + the pavilion
        -- roof, so the support follows the drum wherever it's centred.
    },
    spawn = { pos = { 0, 29, -188 } }, -- on the rim plaza, facing the bell
}
return ArenaLayout
