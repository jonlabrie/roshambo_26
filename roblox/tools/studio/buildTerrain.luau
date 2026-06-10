-- ZenDojo terrain v4: run via MCP execute_luau in EDIT mode (idempotent).
-- Numbers from tools/builders/ArenaLayout.luau — re-paste on layout change.
-- WriteVoxels heightfield (NOT stamps): every voxel column is evaluated from a
-- single continuous surface function, so terraces flow organically with no seams
-- and each tier's outer paddy strip is one connected waterline. v3's overlapping
-- FillCylinder stamps left janky terraces and pooled (disconnected) water; this
-- replaces the whole build per column.
-- Tanada look (2026-06-07 refs, Maruyama Senmaida): domain-warped contour rings,
-- flooded paddy strips hugging each wall base, rolling backdrop hills in every
-- direction so the true horizon never shows from the rim (eye ~y31).
-- Build region x,z in [-432,432], y in [-24,100], 96-stud tiles at resolution 4.
-- Monument zone r<40 stays exact (machinery sits there): no warp/noise, flat
-- gravel apron, basin water a clean circle, placeholder parts never buried.
local Terrain = workspace.Terrain
local RES = 4
local AIR, GROUND, GRASS, WATER =
    Enum.Material.Air, Enum.Material.Ground, Enum.Material.LeafyGrass, Enum.Material.Water

-- ---- pure helpers ----
local function ss(e0, e1, x) -- smoothstep
    if e1 == e0 then
        return x < e0 and 0 or 1
    end
    local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
end
local function fbm(x, z, oct, freq, lac, gain) -- deterministic Perlin octaves
    local s, a, f = 0, 1, freq
    for _ = 1, oct do
        s = s + math.noise(x * f, z * f, 0) * a
        a = a * gain
        f = f * lac
    end
    return s
end

-- ---- layout (mirror of ArenaLayout.luau) ----
local BASIN_R, APRON_R = 16, 84
local TIERS = { { r = 116, h = 6 }, { r = 152, h = 16 }, { r = 188, h = 28 } }
local WALL_RUN = 7 -- horizontal run of each paddy wall (steep, not a cliff)
-- content pads: {x, z, surfaceY}. Warp suppressed and surface flattened nearby
-- so promontories / teahouses / flume pool / rim plaza sit flat on their tier.
local PADS = {
    { 0, 134, 16 }, -- promontory Record (N)
    { -128, 38, 16 }, -- promontory Streak (W)
    { 128, 38, 16 }, -- promontory LocalHero (E)
    { -98, -88, 16 }, -- teahouse SW
    { 98, -88, 16 }, -- teahouse SE
    { -145, 68, 28 }, -- teahouse NW (upper)
    { 107, -80, 16 }, -- flume pool
    { 0, -196, 28 }, -- torii
    { -14, -186, 28 }, -- stele
    { 0, -188, 28 }, -- spawn plaza
}
local PAD_SUPP = 14 -- pad flatten / warp-suppression radius
local KOI = { x = -130, z = -115, r = 14 } -- koi pond; level derived from local tier (see KOI_LEVEL)

local function padDist(x, z)
    local md, mp = 1e9, nil
    for _, p in PADS do
        local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)
        if d < md then
            md, mp = d, p
        end
    end
    return md, mp
end

-- Creek: a water channel down the drive line (heading driveYaw = 237° in
-- ArenaLayout — re-paste the unit dir on layout change). `along` = projection
-- onto the line from the origin; `off` = perpendicular distance to it. The bed is
-- carved DEPTH studs into whatever the local terrain surface is (passed in), so it
-- always reads as a recessed channel that steps down the tiers rather than a fixed
-- slope that floats above the lower mid-section. The water top sits 1 stud below
-- the local surface, so the columns just outside halfW (full terrain) contain it.
-- The water fills the channel to the LOCAL GRADE (brimful), not a stud below: a
-- sunken surface left the sloped trench walls, the submerged wheel parts and the
-- apron tiles showing through a thin ribbon. depth 5 keeps the water span (floor→
-- wt) wider than the RES-4 voxel pitch so the ribbon never breaks between voxels.
local CREEK = { halfW = 4.2, mouthAlong = 12, rimAlong = 190, depth = 5, lip = 0.8 }
local CK_DIRX, CK_DIRZ = -0.8387, -0.5446 -- (sin, cos) of driveYaw 237°
local function creekColumn(x, z, surfaceTop)
    local along = x * CK_DIRX + z * CK_DIRZ
    if along < CREEK.mouthAlong or along > CREEK.rimAlong then
        return nil
    end
    local off = math.abs(x * CK_DIRZ - z * CK_DIRX)
    if off > CREEK.halfW then
        return nil
    end
    -- flat-bottomed cut: floor DEPTH below local surface, water filled to just
    -- shy of grade (CREEK.lip below) — full to the brim read a touch high, sunk a
    -- whole stud read too low; the fractional surface lands it in between.
    -- Both g and wb are the floor (no air gap under the water).
    local floor = surfaceTop - CREEK.depth
    return { g = floor, wb = floor, wt = surfaceTop - CREEK.lip }
end

-- domain-warped radial offset: 0 inside r<55 and within ~PAD_SUPP of any pad
local function warpAmt(x, z, r, pd)
    if r < 55 then
        return 0
    end
    local supp = ss(55, 78, r) * ss(PAD_SUPP, PAD_SUPP + 18, pd)
    return fbm(x + 1000, z + 1000, 3, 0.013, 2.0, 0.5) * 12 * supp
end

-- continuous tier surface for a (warped) radius, smoothstep walls between plateaus
local function tierSurface(rw)
    if rw < APRON_R then
        return 2
    end
    if rw < TIERS[1].r then
        return 2 + (TIERS[1].h - 2) * ss(TIERS[1].r - WALL_RUN, TIERS[1].r, rw)
    end
    for i = 1, #TIERS - 1 do
        local a, b = TIERS[i], TIERS[i + 1]
        if rw < b.r then
            return a.h + (b.h - a.h) * ss(b.r - WALL_RUN, b.r, rw)
        end
    end
    return TIERS[#TIERS].h
end

-- the koi pond's flat water level = the tier surface at the pond's center radius
-- (≈16, tier 2). A single level keeps the pond flat; the tier-3 wall rising past
-- its NW rim simply nestles the pond against the slope rather than tilting it.
local KOI_LEVEL = tierSurface(math.sqrt(KOI.x ^ 2 + KOI.z ^ 2))

-- rolling backdrop hills (2026-06-07 gate tune: less steep, more organic).
-- Long gentle climb out of the bowl (88-stud run, not a berm wall), an
-- undulating ridge line so the rim horizon isn't a constant ring, low-octave
-- rolling swells farther out, and a soft mid-scale undulation layer.
-- onset pushed out 196→210 so tier 3's flat shelf is ~22 studs deep (r188→210),
-- wide enough to seat the upper teahouse village; hills then climb to the backdrop.
local function hills(x, z, r)
    local rise = ss(210, 290, r)
    if rise <= 0 then
        return 0
    end
    local ridge = 40 + fbm(x + 3000, z + 3000, 2, 0.004, 2.0, 0.5) * 5 -- 35..45 ridge line
    local swell = fbm(x, z, 3, 0.0035, 2.2, 0.45) -- long rolling swells
    local detail = fbm(x + 7000, z + 7000, 2, 0.012, 2.0, 0.5) * 6 * ss(234, 274, r)
    local big = ss(254, 354, r) * ((swell + 1) * 0.5 * 46)
    return ((ridge - 28) + detail + big) * rise
end

-- per-column descriptor: g = ground surface Y; optional wb/wt = water bottom/top.
local function evalColumn(x, z)
    local r = math.sqrt(x * x + z * z)
    -- first compute the BASE terrain (no creek): basin / apron / tiers + paddy + koi.
    local res
    if r < BASIN_R then
        -- basin pool under the bell: surface at 1.2 (flush with the creek mouth so
        -- they read as one body; was 0, which sat too low), deep floor at -6.
        res = { g = -6, wb = -6, wt = 1.2 }
    elseif r < APRON_R then
        -- gravel apron, flat surface 2 (monument zone, exact)
        res = { g = 2, grav = true }
    else
        local pd, pp = padDist(x, z)
        local rw = r + warpAmt(x, z, r, pd)
        local surf = tierSurface(rw)
        -- flatten onto pad height near a content pad
        if pd < PAD_SUPP then
            local t = ss(PAD_SUPP - 5, PAD_SUPP, pd)
            surf = pp[3] * (1 - t) + surf * t
        end
        surf = math.min(surf + hills(x, z, r), 96) -- stay under the build ceiling (y 100)
        -- which tier plateau (by warped radius), for the paddy band
        local ti
        if rw >= TIERS[1].r and rw < TIERS[2].r then
            ti = 1
        elseif rw >= TIERS[2].r and rw < TIERS[3].r then
            ti = 2
        elseif rw >= TIERS[3].r and rw < TIERS[3].r + 30 then
            ti = 3
        end
        res = { g = surf }
        -- paddy: outer band of tiers 1 & 2, hugging the wall of the tier above.
        -- band [tierAbove.r-12, tierAbove.r-2]; floor recessed, top WATER at h-2.
        if ti and ti < #TIERS and pd >= PAD_SUPP then
            local tr = TIERS[ti + 1].r
            local bandIn, bandOut = tr - 12, tr - 2
            if rw >= bandIn and rw <= bandOut then
                local th = TIERS[ti].h
                res.g, res.wb, res.wt = th - 4, th - 4, th - 2
            end
        end
        -- koi pond recessed into its local tier (flat KOI_LEVEL, not a fixed height)
        local kd = math.sqrt((x - KOI.x) ^ 2 + (z - KOI.z) ^ 2)
        if kd < KOI.r then
            local fl = KOI_LEVEL - 4
            res.g, res.wb, res.wt = fl, fl, KOI_LEVEL - 1
        end
    end
    -- creek carves LAST, into the local surface top (water-or-ground), so it reads
    -- as a recessed channel that steps down the tiers and notches the basin's edge.
    local creek = creekColumn(x, z, res.wt or res.g)
    if creek then
        return creek
    end
    return res
end

-- channels override everything (applied last per column): a forced ground floor
-- at ramp height with air above (no water). sandō descends rim→apron at x≈0 S;
-- E/W ramps climb apron→rim at z≈0.
local function channel(x, z)
    if x >= -5 and x <= 5 and z <= -86 and z >= -192 then
        local t = (z - -192) / (-86 - -192)
        return 28 + (2 - 28) * t
    end
    if z >= -5 and z <= 5 then
        local ax = math.abs(x)
        if ax >= 84 and ax <= 194 then
            local t = (ax - 84) / (194 - 84)
            return 2 + (28 - 2) * t
        end
    end
    return nil
end

-- fractional occupancy for the voxel straddling the surface → smooth tops
local function occFor(wy, surf)
    local d = surf - (wy - RES / 2)
    if d >= RES then
        return 1
    elseif d <= 0 then
        return 0
    else
        return d / RES
    end
end

-- ---- tiled WriteVoxels driver ----
local X0, X1 = -432, 432
local Y0, Y1 = -24, 100
local TILE = 96
local function buildTile(tx, tz)
    local region = Region3.new(Vector3.new(tx, Y0, tz), Vector3.new(tx + TILE, Y1, tz + TILE))
        :ExpandToGrid(RES)
    local size = region.Size
    local nx, ny, nz = math.floor(size.X / RES), math.floor(size.Y / RES), math.floor(size.Z / RES)
    local base = region.CFrame.Position - size / 2
    local mats, occ = {}, {}
    for ix = 1, nx do
        mats[ix], occ[ix] = {}, {}
        local wx = base.X + (ix - 0.5) * RES
        for iy = 1, ny do
            mats[ix][iy], occ[ix][iy] = {}, {}
        end
        for iz = 1, nz do
            local wz = base.Z + (iz - 0.5) * RES
            local c = evalColumn(wx, wz)
            local ch = channel(wx, wz)
            for iy = 1, ny do
                local wy = base.Y + (iy - 0.5) * RES
                local m, o = AIR, 0
                if ch then
                    local of = occFor(wy, ch)
                    if of > 0 then
                        m, o = GROUND, of
                    end
                elseif c.wt and wy > c.wb and wy - RES / 2 < c.wt then
                    -- fractional occupancy at the surface (like the ground skin) so
                    -- the waterline can sit between the 4-stud voxel rows, not just
                    -- snap to them — lets the creek level be tuned in sub-voxel steps.
                    m, o = WATER, occFor(wy, c.wt)
                elseif wy - RES / 2 < c.g then
                    local of = occFor(wy, c.g)
                    if of > 0 then
                        -- grass skin on the top 4 studs unless this column is gravel
                        if not c.grav and wy > c.g - 4 then
                            m = GRASS
                        else
                            m = GROUND
                        end
                        o = of
                    end
                end
                mats[ix][iy][iz] = m
                occ[ix][iy][iz] = o
            end
        end
    end
    Terrain:WriteVoxels(region, RES, mats, occ)
end

-- wipe the whole old build first (old stamps + old dome hills), then tile-fill.
Terrain:FillRegion(
    Region3.new(Vector3.new(-440, -60, -440), Vector3.new(440, 120, 440)):ExpandToGrid(RES),
    RES,
    AIR
)
local n = 0
for tx = X0, X1 - TILE, TILE do
    for tz = X0, X1 - TILE, TILE do
        buildTile(tx, tz)
        n += 1
    end
end
return "terrain v4 built (" .. n .. " tiles)"
