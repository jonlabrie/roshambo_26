-- ZenDojo canyon CLEARING terrain: run via MCP execute_luau in EDIT mode.
-- Numbers mirror tools/builders/ArenaLayout.luau `clearing` block — re-paste on change.
--
-- Sculpts the focal clearing onto the imported (Gaea) canyon floor via a single
-- read-modify-write over a bounded region. It does NOT install a flat slab — the
-- gathering area is an ORGANIC OVAL gravel terrace, gently graded and nestled into
-- the floor (edges melt into the rock by a noise-perturbed influence field). The
-- water all lives on the −Z side: a rounded in-fall pool at the back drains into a
-- river that hugs the −Z cliff base and wraps the terrace, then spills over a single
-- fall face (left as bare rock — terrain water can't sheet down a drop; the Task-7
-- VFX water-sheet + mist pour over it) into a plunge pool that drains down-canyon.
--
-- IDEMPOTENCY: the terrace blends to the *natural* surface at its edges, so a re-run
-- must start from clean terrain. If a `ServerStorage.ClearingTerrainBackup` snapshot
-- exists (a CopyRegion of the pristine import), it is pasted first. Otherwise the op
-- assumes it is running on freshly-imported terrain. ALWAYS snapshot before editing.
--
-- World frame: clearing centre = origin; in-fall/back upstream (−X), boundary fall
-- downstream (+X); Z cross-canyon. Natural floor descends ~131(−X)→65(+X).
local Terrain = workspace.Terrain
local RES = 4
local AIR, BASALT, SAND, WATER =
    Enum.Material.Air, Enum.Material.Basalt, Enum.Material.Sand, Enum.Material.Water

-- ---- clearing constants (mirror ArenaLayout.clearing) ----
local CX, CZ = 4, 11 -- terrace oval centre (shifted downstream so it reaches further +X)
local A, B = 86, 48 -- terrace oval semi-axes (~172 × 96 footprint; extended down-canyon)
local FLAT_Y = 111 -- gathering grade (≈1 stud above the pool surface = a strand)
local SKIN = 3 -- gravel skin depth on the terrace top
local GRAVEL = Color3.fromRGB(150, 146, 138) -- fine-gravel tint for the Sand material
-- water (all on the −Z / North side)
local POOL_C = { -57, -20 } -- rounded in-fall basin centre (back −Z corner)
local POOL_R = 28 -- basin radius (noise-perturbed)
local POOL_SURF = 110 -- pool/upper-river water surface
local POOL_FLOOR = 102 -- basin floor
local RIV_X0 = -71 -- river starts at the pool's back
local FALL_X = 70 -- the lip: river ends here, the fall begins

-- ---- pure helpers ----
local function ss(e0, e1, x)
    if e1 == e0 then
        return x < e0 and 0 or 1
    end
    local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
end
local function n2(x, z, f) -- deterministic Perlin in [-~1,1]
    return math.noise(x * f, z * f, 0.7)
end
local function occFor(wy, surf) -- fractional occupancy → smooth ground tops
    local d = surf - (wy - RES / 2)
    if d >= RES then
        return 1
    elseif d <= 0 then
        return 0
    else
        return d / RES
    end
end

-- terrace influence ∈ [0,1]: 1 over a generous flat-ish core, ramping to 0 at a tight
-- noise-perturbed edge so the gravel dissolves organically into the rock.
local function influence(x, z)
    local dx, dz = (x - CX) / A, (z - CZ) / B
    local d = math.sqrt(dx * dx + dz * dz)
    local w = n2(x, z, 0.03) * 0.12
    return 1 - ss(0.56 + w, 1.05 + w, d)
end

-- per-column target. {g, [wb,wt], skin}. nil = leave imported terrain untouched.
-- `eh` = the column's existing surface height (for the organic terrace blend).
local function clearingColumn(x, z, eh)
    -- rounded in-fall basin at the back −Z corner (organic edge)
    local pr = math.sqrt((x - POOL_C[1]) ^ 2 + (z - POOL_C[2]) ^ 2)
    if pr < POOL_R + n2(x, z, 0.06) * 3.5 then
        return { g = POOL_FLOOR, wb = POOL_FLOOR, wt = POOL_SURF, skin = true }
    end
    local bank = -17 + n2(x, 0, 0.035) * 7 -- meandering +Z waterline (terrace / river edge)
    if z <= bank then
        -- −Z water side: river → lip → fall face → plunge, all within an 18-stud band
        if x > RIV_X0 and z > bank - 18 then
            if x <= FALL_X then -- river hugging the cliff, descending to the lip
                local rsurf = POOL_SURF + (107 - POOL_SURF) * ss(POOL_C[1], FALL_X, x)
                return { g = rsurf - 6, wb = rsurf - 6, wt = rsurf, skin = true }
            elseif x <= FALL_X + 14 then -- single fall face: bare rock (Task-7 VFX sheet pours here)
                local g = 105 + (90 - 105) * ss(FALL_X, FALL_X + 14, x)
                return { g = g, skin = false }
            elseif x <= FALL_X + 48 then -- plunge pool + outflow draining down-canyon
                local w = 90 + (85 - 90) * ss(FALL_X + 14, FALL_X + 48, x)
                return { g = w - 5, wb = w - 5, wt = w, skin = true }
            end
        end
        return nil
    else
        -- +Z gathering terrace: blend the grade into the natural floor by influence
        local infl = influence(x, z)
        if infl > 0.04 then
            return { g = eh * (1 - infl) + FLAT_Y * infl, skin = true }
        end
        return nil
    end
end

-- ---- restore-from-snapshot (idempotent re-runs), then single read-modify-write ----
local snap = game:GetService("ServerStorage"):FindFirstChild("ClearingTerrainBackup")
if snap then
    Terrain:PasteRegion(
        snap,
        Vector3int16.new(
            snap:GetAttribute("minCellX") or -20,
            snap:GetAttribute("minCellY") or 8,
            snap:GetAttribute("minCellZ") or -11
        ),
        false
    )
end

local region = Region3.new(Vector3.new(-98, 56, -46), Vector3.new(120, 164, 62)):ExpandToGrid(RES)
local size = region.Size
local nx, ny, nz = math.floor(size.X / RES), math.floor(size.Y / RES), math.floor(size.Z / RES)
local base = region.CFrame.Position - size / 2
local mats, occ = Terrain:ReadVoxels(region, RES)

local n = 0
for ix = 1, nx do
    local wx = base.X + (ix - 0.5) * RES
    for iz = 1, nz do
        local wz = base.Z + (iz - 0.5) * RES
        local eh = base.Y
        for iy = ny, 1, -1 do
            if mats[ix][iy][iz] ~= AIR and occ[ix][iy][iz] > 0.5 then
                eh = base.Y + (iy - 0.5) * RES
                break
            end
        end
        local c = clearingColumn(wx, wz, eh)
        if c then
            n += 1
            for iy = 1, ny do
                local wy = base.Y + (iy - 0.5) * RES
                local m, o = AIR, 0
                -- water voxels are FULL occupancy (WriteVoxels drops fractional waterline voxels)
                if c.wt and wy < c.wt and wy >= c.wb then
                    m, o = WATER, 1
                elseif wy - RES / 2 < c.g then
                    o = occFor(wy, c.g)
                    if o > 0 then
                        m = (c.skin and wy > c.g - SKIN) and SAND or BASALT
                    end
                end
                mats[ix][iy][iz] = m
                occ[ix][iy][iz] = o
            end
        end
    end
end

Terrain:WriteVoxels(region, RES, mats, occ)
Terrain:SetMaterialColor(SAND, GRAVEL) -- neutral fine-gravel grey (this place uses Sand only here)
return string.format("clearing built (%d columns): terrace + in-fall pool + cliff river + fall", n)
