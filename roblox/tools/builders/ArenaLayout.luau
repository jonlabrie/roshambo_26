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
local _pavilionYaw = -13

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
    -- postD was a bare 2.4 repeated seven times inside Shoro.luau. It moved here on 2026-08-14
    -- because the karesansui kerb is now aligned to the posts' OUTER faces, so the garden panel
    -- and the tower have to agree on how thick a post is — and a number that two builders must
    -- agree on cannot live inside one of them.
    -- plinthD is WIDER THAN postD ON PURPOSE (owner's gate 2026-08-14). At the kerb's height the
    -- thing beside it is the plinth, not the post — the post starts 1.7 up — so a plinth of
    -- exactly postD put its outer face on the same plane as the kerb's, coplanar and same-facing,
    -- and the two z-fought at all four corners. The plinth stands proud so the kerb dies INTO it,
    -- which is also what a base stone does.
    pavilion = {
        pos = { -2, 112, 0 },
        postSpacing = 18,
        postD = 2.4,
        plinthD = 2.7,
        roofHeight = 22,
        yaw = 0,
    },
    -- bonshō bell: hangs centred above the clearing floor. Raised +2.7 (2026-07-20) so
    -- the BellBeam rests atop the ring beams and the bell clears the deck better; the
    -- shu-moku striker (y118) realignment to this height is the deferred drive-chain pass.
    bell = { pos = { -2, 123.7, 0 }, height = 13.5, radius = 5.1 },
    -- shu-moku striker, tower-hung (2026-07-23): strikes the tsuki-za boss at y120.7
    -- (bell raised +2.7 in T5; the old y118 hit ~1 stud above the mouth rim). Ropes
    -- drop from spreader arms on a hanger beam spanning the two +Z pavilion posts
    -- (z=+9 sits between the chain planes 7.5/11.5). The cam/draw realignment to this
    -- height is the NEXT task; the dowels simply rise with the log.
    shuMoku = {
        -- Log lengthened TAILWARD (nose stays at z≈5.5) so the draw dowel can sit near
        -- the tail — that pulls the cam south, away from the bell (sweep clearance).
        restPos = { -2, 120.7, 9.7 },
        length = 8.4,
        radius = 0.8,
        drawStuds = 3.0, -- MIRRORS HammerController DRAW_STUDS (the cam flank is generated from this)
        yaw = 0,
        hangerY = 132, -- hanger-beam centreline, just under the ring beams (~134)
        -- rope tops hang from the spreader UNDERSIDES (spreaders sit flush under the
        -- beam: centre 130.9, bottom 130.4), not from inside the beam
        chainTops = { { 2, 130.25, 7.5 }, { 2, 130.25, 11.5 }, { -6, 130.25, 7.5 }, { -6, 130.25, 11.5 } },
        chainBottomsRest = {
            { -1.2, 121.3, 7.5 },
            { -1.2, 121.3, 11.5 },
            { -2.8, 121.3, 7.5 },
            { -2.8, 121.3, 11.5 },
        },
        -- DRAW dowel: peg near the log's TAIL reaching West past the cam plane (the
        -- cam sits well outboard so the hanger ropes clear its sweep).
        drawDowel = { from = { -1.5, 120.7, 13.2 }, to = { -5.6, 120.7, 13.2 } },
        -- KICK dowel: short east-flank peg that kicks the vertical-shaft paddle.
        kickDowel = { from = { -1.5, 120.7, 6 }, to = { 0.58, 120.7, 6 } }, -- tip gate-shaved ~2in
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
        width = 2.88, -- face-to-face span (+20% over the 2.4 disc era — a beefier mill wheel)
        overshot = false,
        yaw = 90, -- axle along Z; disc faces the +Z gathering, paddles catch the +X current
        driveYaw = 0, -- drive line toward the bell (RatchetDrum offsets along it)
        bedY = 104, -- support posts stand on the riverbed (river floor ~104)
        centers = { { -15, 116, -19 } }, -- in the river channel, nudged ~4ft South toward the bank (was -23)
        driver = 1,
        ropeAnchor = { -15, 116, -15 },
    },
    -- ===== Karesansui garden (spec 2026-07-24): framed VIEWED garden, plaza-first =====
    -- SURVEYED rects {x1, z1, x2, z2} on the terrace floor (Studio survey 2026-07-24:
    -- Shoro eave envelope reaches x16/z18; Overlook west face x54; ArenaSpawn pad
    -- x26..34 z4..12 stays in open plaza; river bank lane north of z-6; floor spans
    -- to z~40 south). Never derive these from placed parts. Corridors are the
    -- square's MAIN STREETS (crowd-width, inviolable — no kerb/slab/guard may enter);
    -- the merchant row later builds against the SAME shopCorridor reservation.
    karesansui = {
        -- TRUE grade across the garden (probed 2026-07-24: 111.8..113.07 — a flat
        -- bed sits proud of its HIGHEST ground)
        floorY = { main = 113.1 },
        -- A 4x10 ON EDGE (owner's gate 2026-08-14), in inches: 4/12 wide, 10/12 showing. It was
        -- 0.8 x 1.0-proud, which is a 10x12 — near enough square that it read as a 6x6 sleeper
        -- rather than as an edging board. What is wanted is a plank standing on its edge.
        kerbW = 0.3333, -- 4"
        kerbProud = 0.8333, -- 10" — the SHOWING height; kerbH below is the rooted depth
        -- ROOTED DEPTH, and it is 1.5 rather than the inherited 2.5. The old comment said "rooted
        -- below grade through the dips at the taller stand", which was true of a 55x30 slate frame
        -- crossing uneven terrace and stopped being true when the panel became 20.4 square on the
        -- tower's own floor. At 2.5 the kerb's bottom sat 1.29 below the LOWEST ground it ever
        -- meets — two thirds of a "4x10" underground, making it really a 4x40.
        --
        -- WHAT CONSTRAINS THIS IS REACHING THE GROUND, nothing else. An earlier pass said "below
        -- the field slab it retains" — over-derived: the slab's underside is 112.85, which is
        -- BELOW real grade and therefore already buried.
        --
        -- Raycast along all four runs 2026-08-14 (80 samples each). Three quarters of the line is
        -- dead flat at 113.00; the only departure is the NORTHWEST CORNER, which hollows to 112.72
        -- over the first stud or so of both the N and W runs:
        --
        --   N  112.74 112.90 112.92 113.00 113.00 ... flat        S  113.00 flat
        --   W  112.72 112.98 113.00 113.00 113.00 ... flat        E  113.00 flat
        --
        -- So the timber has to be tall enough to bridge ONE soft corner. 1.25 puts its bottom at
        -- 112.683, under the worst of it. FILL THAT HOLLOW and this can drop to ~1.0, which would
        -- leave a twentieth of the board underground instead of a quarter — the arena floor is a
        -- known upcoming pass and that is the place to do it.
        --
        -- Note real grade is 113.00, a tenth BELOW the 113.10 datum kerbProud is measured from, so
        -- the board actually shows 0.933 rather than 0.833.
        kerbH = 1.25,
        -- The lowest ground under the kerb line, measured, not assumed. The test compares the
        -- kerb's bottom against this; re-measure it when the square is regraded.
        measuredGroundY = 112.72,
        slabProud = 0.15, -- raked field rides proud of the terrace like flags-of-bed
        guardH = 3.5, -- EngawaBarrier low guard: blocks walking, never traps jumpers
        -- THE GARDEN IS NOW THE TOWER'S OWN FLOOR (owner's gate 2026-08-14, from the Chion-in
        -- bell photograph in roshambo_reference/concept art). It was 55 x 30 and the tower sat in
        -- its corner — panel centre (6.5, 3) against a tower centre of (-2, 0), running 18 studs
        -- east of the tower and stopping short of it north and south. A garden the building
        -- happened to stand at one end of.
        --
        -- Now the kerb runs BETWEEN THE POSTS, and to their OUTER faces (owner's gate: "between
        -- the outer edges between the posts, not the inner edge"). The beams are laid inboard of
        -- the panel edge, so putting the panel on the outer faces is what makes the kerb's own
        -- outer face flush with the posts — the standing rule for anything meeting a built edge.
        --
        -- So the corners are pavilion.pos (-2, 0) ± (postSpacing/2 + postD/2) = ±10.2. Derived by
        -- hand because ArenaLayout is a flat survey table with no expressions in it; the test
        -- asserts the relationship against pavilion, so the two cannot drift apart silently.
        --
        -- WHAT THIS GAVE UP, deliberately: the bell-drive's main-run bearing plinths at x -15
        -- used to rise out of the raking, and now stand 4 studs west of the kerb on plain terrace.
        -- The machine is no longer IN the garden; the garden is the bell's floor and the machine
        -- stands beside it in the square. That relationship had its own assertion, and retiring it
        -- was a decision, not a casualty.
        panels = {
            main = { -12.2, -10.2, 8.2, 10.2 }, -- the post OUTER square, 20.4 x 20.4
        },
        corridors = {
            eastCorridor = { 34, -10, 54, 38 }, -- kerb face -> Overlook west face
            shopCorridor = { -20, 28, 34, 44 }, -- promenade; shops back onto the south upslope
        },
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
    -- Mawari-dōrō revolving lantern (vertical axis) crowning the shōrō. radius from the
    -- 12-facet glyph legibility ("Beacon", ~56% of the 39-stud roof); height is squat.
    -- `length` is a LEGACY compat field consumed ONLY by BellDrive's yoke sizing
    -- (BellDrive.luau:156) until the T8 drive reconnect — the new vertical builder ignores it.
    throwDrum = { pos = { -2, 144, 0 }, radius = 11, height = 7.25, faces = 12, windows = 4 },
    -- ===== Bell engine drive train (exposed on the open frame) =====
    -- One water input → two outputs. The wheel's Z-axle is the MAIN SHAFT; it runs
    -- South down the WEST (upriver) side of the bell+tower (clearing both), then a
    -- right-angle BEVEL turns the drive onto an E–W CAM SHAFT pointed East at the
    -- shu-moku. A cam on that E–W shaft (sweeping the N–S vertical plane) catches the
    -- shu-moku's horizontal draw dowel, drawing the log back over the round then
    -- releasing it (gong). The swing's east-flank dowel kicks the vertical-shaft
    -- paddle → spins the drum. Starting coords; tuned at the staging gate.
    bellDrive = {
        -- MAIN SHAFT: along Z (N–S) from the wheel, ending at the SW jack corner.
        shaftFrom = { -15, 116, -19 }, -- = wheel centre (nudged South toward the bank)
        shaftTo = { -15, 116, 9.8 }, -- ends BURIED in the main face wheel (gate: nothing proud of the gear face)
        shaftR = 0.6,
        -- Vertical LANTERN ARBOR (the "single vertical gear"): OFF the cam shaft's
        -- z=11 line and STARTING ABOVE the main shaft — the old jack intersected both.
        jack = { x = -15, z = 11, yBottom = 116.25, yTop = 119.35 }, -- ON the shafts' plan crossing, cage below the cam shaft
        -- Water-mill gearing (reference photo): two face-cog wheels comb one SHORT
        -- lantern (gate: the tall cage caught the cam wheel's upper quadrant too —
        -- the compact cage takes the cam wheel's LOWER arc, y≈117.9-119.2, only).
        -- lantern rate = main × cogsMain/staves; cam = lantern × staves/cogsCam →
        -- cam/main = 12/24 (staves cancel) = HammerController REDUCTION = 2.
        faceWheelMain = { -15, 116, 9.65 }, -- NORTH of the cage (gate: south read backwards); disc clear of the stave sweep
        faceWheelMainR = 1.6,
        faceWheelMainCogs = 12,
        faceWheelMainPhaseDeg = -7, -- cog-ring azimuth: retard so cogs comb the stave GAPS (gate-tuned live 2026-07-23)
        camFaceWheel = { -13.65, 120.7, 11 }, -- disc plane clear of the stave sweep (x ≥ -13.96)
        camFaceWheelR = 3.2,
        camFaceWheelCogs = 24, -- /faceWheelMainCogs MIRRORS HammerController REDUCTION = 2
        lantern = {
            x = -15,
            z = 11, -- in line with BOTH gears: at the shafts' plan crossing
            staves = 9,
            staveRingR = 0.9,
            flangeR = 1.05, -- slimmed with the second drop so the flanges clear the main wheel's face
            yBottom = 116.25, -- dropped 0.45 + 0.5 across two gate rounds
            yTop = 118.45,
        },
        -- E-W CAM SHAFT at dowel height (octagonal; spun with the cam via ^Cam names).
        -- Pokes a stub THROUGH the cam (a flush end would be face-coplanar with the
        -- mesh flank and z-fight); still well clear of the log (flank at x=-2.8).
        camShaft = { y = 120.7, z = 11, fromX = -17.3, toX = -4.2, r = 0.5 }, -- west stub through the corner pillow
        -- SNAIL CAM: axle at dowel height, 2.2 studs north of the tail dowel's rest
        -- plane; the smooth mesh flank is generated by CamProfile/CamMesh from the
        -- dowel's draw path, reparameterized to the METRONOME timeline (camStrikeP =
        -- (active+tally)/period; the flank tracks the dowel's ACTUAL draw at every
        -- angle — uniform hairline clearance, no empirical shave). Cam plane at x -5.3..-4.6: EAST FACE ≤ -4.55 so the west hanger
        -- ropes (tops x=-6 → log attach x=-2.8) clear the sweep at every draw phase
        -- (pinned by test). Sweep CLEARS THE BELL: lobe ≈ 4.5, nearest approach
        -- z ≈ 6.5 vs the bell face at 5.1 (pinned by test).
        cam = { -4.95, 120.7, 11 },
        camWidth = 0.7,
        camHubR = 1.5, -- visible hub disc; the mesh flank spans hub→contact radius
        camDropDeg = 12, -- the cliff (release face) width
        camDowelRise = 0.45, -- MIRRORS HammerController riseY = p²·0.45 (3-stud draw arc)
        camClearance = 0.03, -- MIRRORS the controller's CamMesh G.clearance (visual touch; gate-tuned from 0.1)
        camStrikeP = 22 / 25, -- (active+tally)/period; the controller derives its own from the live schedule
        -- KICK shaft + paddle (drum kick): the shaft is the mawari-dōrō's SPINDLE —
        -- it runs from the ground straight up INTO the lantern's underside (the upper
        -- run is hidden by the roof, so no gearing is modelled; the old pin-wheel gear
        -- cluster was removed 2026-07-23). Shifted 0.25 South so the kick dowel isn't
        -- coincident with the shaft at rest.
        vertBase = { 1, 112, 6.42 },
        vertTop = { 1, 141.6, 6.42 }, -- ~4 studs up into the lantern's base
        vertR = 0.23, -- slim drive rod (~1/3 the old diameter)
        paddle = { 1, 120.7, 6.42 }, -- at the kick dowel's height; z MIRRORED by DrumController (pivot + choreography)
        paddleLen = 2.4, -- kicked by the shu-moku's east-flank dowel
        -- shaft bearings (trestle post + saddle): two on the main-shaft run (wheel→bevel),
        -- one at the bevel corner, one just behind the cam on the E-W shaft. {x, z} on
        -- the shaft line at shaft height; posts drop to bearingBaseY.
        -- Pillow blocks, generalized: axis "Z" = main-run (shaft y116); axis "X" =
        -- the tall post under the raised cam shaft. baseY per entry (bank vs clearing).
        -- Shoro-style slate plinths under all bearing posts: probed grade is a uniform
        -- ~113.0 at the five stations, top rides 0.6 proud; blocks root down to baseY.
        bearingPlinthTop = 113.6,
        bearings = {
            { x = -15, z = -6, y = 116, axis = "Z", baseY = 110 },
            -- (the mid-run pillow at z=2 was CUT at the plinth gate 2026-07-23:
            -- two pillows carry the short main run fine and it read as clutter)
            { x = -15, z = 6.5, y = 116, axis = "Z", baseY = 110 }, -- out of the lantern cage
            { x = -6, z = 11, y = 120.7, axis = "X", baseY = 111.5 },
            -- corner pillow: at the cam shaft's GEAR end, west of the lantern; the
            -- hanger arm runs east along the shaft line to carry the lantern
            { x = -16.75, z = 11, y = 120.7, axis = "X", baseY = 111.5 },
        },
        -- The drum's bearing yoke (A-frames) is built from throwDrum.pos + the pavilion
        -- roof, so the support follows the drum wherever it's centred.
    },
    spawn = { pos = { 0, 29, -188 } }, -- on the rim plaza, facing the bell
    -- Downcanyon overlook: tiered twin decks off the clearing's EAST edge, aimed ESE
    -- down the gorge. Decks/stair/rail are built by Overlook.luau; the prow/swerve/
    -- perch anchors drive the live terrain carve + greening/lantern passes. Starting
    -- coords — tuned at the gate (Y always provisional → raycast-snapped).
    overlooks = {
        facing = { 1, 0, -0.35 }, -- ESE look direction (East + slightly North)
        railH = 2.8, -- bamboo handrail height
        decks = {
            -- upper: big cantilevered overlook — south edge tucked against the rising south
            -- terrain (~z46), long axis thrown East out over the gorge drop, hanging out
            { tier = "upper", pos = { 74, 113, 28 }, size = { 34, 0.6, 30 } },
            -- lower: second tier stepped ~7 down and North over the gorge; WEST end pulled in 4
            -- (East/gorge edge stays at x84) so it doesn't bury in the terrace
            { tier = "lower", pos = { 76, 106, 3 }, size = { 16, 0.6, 17 } },
        },
        stair = { from = { 72, 112, 13 }, to = { 72, 106, 5 }, width = 6 }, -- lantern-lined steps linking the two tiers
        postDrop = 12, -- kake-zukuri posts drop this far below a deck to seat in the terrace lip
        -- downcanyon set-piece anchors (terrain itself is carved live in Studio):
        prow = { 158, 92, 0 }, -- mossy buttress centre, mid-distance straight-ish East
        swerveTo = { 190, 70, -70 }, -- gorge bends North toward here, then fogs out
        lanternPerches = { { 120, 96, -30 }, { 150, 88, -48 }, { 175, 80, -70 } }, -- far warm-glow dots
    },
}
return ArenaLayout
