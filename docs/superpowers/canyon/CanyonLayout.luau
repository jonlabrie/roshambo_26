--!strict
-- ZenDojo CANYON coordinate contract (Phase 0, 2026-06-15). DRAFT — not wired into
-- genmodels yet. Units: 1 = 1 stud, Y up. Origin (0,0,0) = CLEARING CENTRE.
-- X = down-canyon axis (head at -X, boundary at +X). Z = cross-canyon (centre 0).
-- Terrain is authored EXTERNALLY (Gaea/Blender) to this same frame; prop Y values
-- below are PROVISIONAL (from the greybox model) and get re-snapped onto the
-- imported terrain by a raycast pass before building. See README.md.
local CanyonLayout = {
    meta = {
        units = "stud", origin = "clearing-centre",
        heightmapRegion = { size = 440, centre = { -85, 0 } }, -- square, studs (X,Z)
        heightRange = { 0, 260 }, -- heightmap 0..65535 maps world Y 0..260
        rim = 205, wallRun = 46,
    },
    -- river spline down the gorge: each point { x, floorY, innerHalf } (floor descends)
    river = {
        { -260, 122, 34 },
        { -210, 100, 40 },
        { -165, 78, 28 },
        { -120, 62, 48 },
        { -75, 48, 52 },
        { -35, 38, 50 },
        { 0, 30, 72 },
        { 55, 27, 64 },
        { 90, 24, 55 },
    },
    clearing = { centre = { 0, 30, 0 }, xRange = { -72, 60 }, outcropHalf = 58, poolHalf = 20 },
    falls = {
        hero = { x = -260, topY = 205, botY = 122 },      -- tallest, at the head
        boundary = { x = 90, topY = 24, botY = -5 },   -- view-only edge (no further)
        cascadeX = { -210, -165, -120, -75, -35 },     -- intermediate drops between pools
    },
    bridges = {
        { kind = "suspension", x = -165 }, -- at the pinch, above the middle falls
    },
    -- ~18 organic cliff-perch teahouses (stilted kake-zukuri). Y PROVISIONAL (snap to terrain).
    perches = {
        { name = "Perch01", pos = { -225.0, 163.7, -42.2 }, wall = "L", facingCenter = true },
        { name = "Perch02", pos = { -175.0, 113.7, 37.4 }, wall = "R", facingCenter = true },
        { name = "Perch03", pos = { -110.5, 178.5, -58.7 }, wall = "L", facingCenter = true },
        { name = "Perch04", pos = { -118.3, 167.2, 54.8 }, wall = "R", facingCenter = true },
        { name = "Perch05", pos = { -85.1, 165.8, -59.7 }, wall = "L", facingCenter = true },
        { name = "Perch06", pos = { -72.7, 144.1, 57.9 }, wall = "R", facingCenter = true },
        { name = "Perch07", pos = { -36.4, 150.6, -60.0 }, wall = "L", facingCenter = true },
        { name = "Perch08", pos = { -46.6, 144.6, 58.0 }, wall = "R", facingCenter = true },
        { name = "Perch09", pos = { -35.8, 121.0, -57.6 }, wall = "L", facingCenter = true },
        { name = "Perch10", pos = { -14.5, 73.5, 71.7 }, wall = "R", facingCenter = true },
        { name = "Perch11", pos = { -4.0, 143.8, -75.3 }, wall = "L", facingCenter = true },
        { name = "Perch12", pos = { 5.8, 162.4, 80.4 }, wall = "R", facingCenter = true },
        { name = "Perch13", pos = { 42.8, 184.4, -70.8 }, wall = "L", facingCenter = true },
        { name = "Perch14", pos = { 44.2, 167.5, 70.0 }, wall = "R", facingCenter = true },
        { name = "Perch15", pos = { 41.7, 105.5, -72.1 }, wall = "L", facingCenter = true },
        { name = "Perch16", pos = { -63.2, 164.9, 59.0 }, wall = "R", facingCenter = true },
        { name = "Perch17", pos = { -133.6, 99.6, -50.4 }, wall = "L", facingCenter = true },
        { name = "Perch18", pos = { -20.1, 124.0, 65.6 }, wall = "R", facingCenter = true },
    },
    -- machinery near the clearing, fed by the fall spilling in just above it (short flume)
    machinery = {
        shrine = { pos = { 14, 30, 18 }, facingCenter = true },
        bell   = { pos = { 14, 44, 18 } },
        wheel  = { pos = { -18, 31, 2 }, note = "undershot, in the in-spilling fall" },
        flume  = { from = { -34, 34, -2 }, to = { -18, 32, 2 } }, -- short run
        sozu   = { pos = { -6, 30, -10 } },
    },
}
return CanyonLayout
