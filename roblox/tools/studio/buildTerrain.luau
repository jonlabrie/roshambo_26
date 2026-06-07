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
local KOI = { x = -130, z = -115, r = 14, surf = 28 } -- koi pond carved into tier 3

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

-- rolling backdrop hills (2026-06-07 gate tune: less steep, more organic).
-- Long gentle climb out of the bowl (88-stud run, not a berm wall), an
-- undulating ridge line so the rim horizon isn't a constant ring, low-octave
-- rolling swells farther out, and a soft mid-scale undulation layer.
local function hills(x, z, r)
    local rise = ss(196, 280, r)
    if rise <= 0 then
        return 0
    end
    local ridge = 40 + fbm(x + 3000, z + 3000, 2, 0.004, 2.0, 0.5) * 5 -- 35..45 ridge line
    local swell = fbm(x, z, 3, 0.0035, 2.2, 0.45) -- long rolling swells
    local detail = fbm(x + 7000, z + 7000, 2, 0.012, 2.0, 0.5) * 6 * ss(220, 260, r)
    local big = ss(240, 340, r) * ((swell + 1) * 0.5 * 46)
    return ((ridge - 28) + detail + big) * rise
end

-- per-column descriptor: g = ground surface Y; optional wb/wt = water bottom/top.
local function evalColumn(x, z)
    local r = math.sqrt(x * x + z * z)
    -- basin: water 0 down to -6 over ground (monument zone, exact)
    if r < BASIN_R then
        return { g = -6, wb = -6, wt = 0 }
    end
    -- gravel apron, flat surface 2 (monument zone, exact)
    if r < APRON_R then
        return { g = 2, grav = true }
    end
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
    local res = { g = surf }
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
    -- koi pond carved into tier 3
    local kd = math.sqrt((x - KOI.x) ^ 2 + (z - KOI.z) ^ 2)
    if kd < KOI.r then
        local fl = KOI.surf - 7
        res.g, res.wb, res.wt = fl, fl, KOI.surf - 3
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
                elseif c.wt and wy <= c.wt and wy > c.wb then
                    m, o = WATER, 1
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
