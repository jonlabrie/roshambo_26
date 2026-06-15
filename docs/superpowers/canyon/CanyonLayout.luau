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
        rim = 205, wallRun = 30,
    },
    -- river spline down the gorge: each point { x, floorY, innerHalf } (floor descends)
    river = {
        { -260, 122, 26 },
        { -215, 100, 30 },
        { -165, 78, 11 },
        { -120, 62, 34 },
        { -78, 48, 38 },
        { -42, 40, 13 },
        { 0, 30, 50 },
        { 55, 27, 40 },
        { 90, 24, 30 },
    },
    clearing = { centre = { 0, 30, 0 }, xRange = { -50, 50 }, outcropHalf = 44, poolHalf = 16 },
    falls = {
        hero = { x = -260, topY = 205, botY = 122 },      -- tallest, at the head
        boundary = { x = 90, topY = 24, botY = -5 },   -- view-only edge (no further)
        cascadeX = { -215, -165, -120, -78, -42 },     -- intermediate drops between pools
    },
    bridges = {
        { kind = "suspension", x = -165 }, -- pinch 1, above the middle falls
        { kind = "suspension", x = -42 },  -- pinch 2, just above the clearing
    },
    -- ~18 organic cliff-perch teahouses (stilted kake-zukuri). Y PROVISIONAL (snap to terrain).
    perches = {
        { name = "Perch01", pos = { -225.0, 163.0, -33.1 }, wall = "L", facingCenter = true },
        { name = "Perch02", pos = { -175.0, 113.4, 21.5 }, wall = "R", facingCenter = true },
        { name = "Perch03", pos = { -110.5, 178.5, -44.7 }, wall = "L", facingCenter = true },
        { name = "Perch04", pos = { -118.3, 167.2, 40.8 }, wall = "R", facingCenter = true },
        { name = "Perch05", pos = { -85.1, 165.6, -45.9 }, wall = "L", facingCenter = true },
        { name = "Perch06", pos = { -72.7, 143.8, 40.3 }, wall = "R", facingCenter = true },
        { name = "Perch07", pos = { -36.4, 150.7, -27.8 }, wall = "L", facingCenter = true },
        { name = "Perch08", pos = { -46.6, 144.6, 23.6 }, wall = "R", facingCenter = true },
        { name = "Perch09", pos = { -35.8, 121.1, -26.1 }, wall = "L", facingCenter = true },
        { name = "Perch10", pos = { -14.5, 73.6, 46.0 }, wall = "R", facingCenter = true },
        { name = "Perch11", pos = { -4.0, 143.8, -52.3 }, wall = "L", facingCenter = true },
        { name = "Perch12", pos = { 5.8, 162.4, 58.2 }, wall = "R", facingCenter = true },
        { name = "Perch13", pos = { 42.8, 184.4, -47.2 }, wall = "L", facingCenter = true },
        { name = "Perch14", pos = { 44.2, 167.5, 46.4 }, wall = "R", facingCenter = true },
        { name = "Perch15", pos = { 41.7, 105.5, -48.6 }, wall = "L", facingCenter = true },
        { name = "Perch16", pos = { -63.2, 164.8, 35.3 }, wall = "R", facingCenter = true },
        { name = "Perch17", pos = { -133.6, 99.6, -35.5 }, wall = "L", facingCenter = true },
        { name = "Perch18", pos = { -20.1, 124.1, 38.5 }, wall = "R", facingCenter = true },
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
