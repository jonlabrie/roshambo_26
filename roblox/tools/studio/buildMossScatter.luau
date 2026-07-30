-- MCP/Edit: build ServerStorage.MossLibrary from the imported Moss Kit, then scatter
-- it along the water margin inside the care gradient (spec sub-project 2, phase 1).
--
-- WHY MOSS AND NOT THE IRIS WE BOUGHT FOR THIS. The Iris ensata costs 11,827 tris at
-- its SMALLEST variant -- every blade is solid-modelled, a median 152 faces where a
-- leaf card needs 2 -- so it is deferred until prep_foliage.py gains leaf-carding. The
-- moss kit's sporophyte tufts cost 122-207 tris. That is ~70x cheaper per instance, so
-- the margin gets its accent NOW instead of after a re-mesh, and the user spotted it.
--
-- ⚠️ THE MESHES MUST BE THE PREPPED FBX. Raw kit geometry is single-sided and Roblox
-- backface-culls, so half of every card vanishes as you walk past. tools/blender/
-- prep_foliage.py doubles the shells; a prepped Moss_B_A has 200 faces and 100 flipped
-- twin pairs. If the moss looks half-there, that is the cause.
--
-- ⚠️ SurfaceAppearance IS PLAY-ONLY. In Edit these render as flat opaque cards no
-- matter how correct they are. Judge the scatter in PLAY.
--
-- SCALE: 20x, and TWO factors compound to make that number. The kit models real moss
-- at real size (2-19 cm), and Roblox imports the FBX at 1 unit = 1 METRE -- so at
-- 1 stud = 1 foot the raw import is already ~3.3x undersized before any artistic
-- choice, landing at 0.03-0.19 studs. Invisible. (A first pass at 7.5x produced
-- 0.26-1.42 studs, still far too small; the mistake was computing from centimetres
-- while ignoring the import's unit convention.)
--
-- 20x puts mats at 0.5-3.8 studs and sporophyte tufts at ~2.2 tall -- larger than
-- life, but what reads at avatar scale, and right against the 2.8-4.5 stud trail
-- stones. A single factor (not per-family targets) deliberately PRESERVES the kit's
-- own size variation, which is most of what makes a scatter look unplanned.
--
-- ⚠️ THE CARE GRADIENT DOES NOT GOVERN MOSS. The first pass restricted the scatter to
-- GARDEN and TENDED, citing the spec's "ground cover only has to exist inside `reach`".
-- That line is a BUDGET argument about not solving canyon-wide ground cover, and
-- treating it as an ecological rule was a category error (user caught it):
--
--   The gradient governs what PEOPLE DO -- clearing understory, planting iris, pulling
--   weeds. Moss is the least cultivated plant imaginable. It grows where nobody tends:
--   wet rock, shade, undisturbed ground. The weed rule is "the same mass reads as wild
--   where untended and as neglect where tended"; moss is the inverse, reading as damp
--   and age everywhere, and the PRESERVE is where it most belongs. Excluding it there
--   left out 863 of the 1426 water-margin cells -- more than garden and tended
--   combined, at a median 38 studs from any tread.
--
-- So density is keyed to WATER (already required) and to TRAMPLING: feet wear moss off
-- a tread's immediate edge, which is a reason for less moss right against a path, not
-- none in the wild. That falls out of one uniform spacing plus a trample rule, and it
-- gives a pleasing non-monotonic result for free -- dense in the garden (Japanese
-- gardens genuinely cultivate moss), dense in the preserve (nobody disturbs it), thinner
-- on the trodden verges between.

local CONFIG = {
    importName = "Moss_ScatterElements_prepped", -- the model the user's FBX import made
    libraryName = "MossLibrary",
    outFolder = "MossScatter",
    scale = 20.0,
    -- The UPRIGHT families get a boost on top of the shared factor (user-gated). At
    -- 20x a Moss_B sporophyte tuft stands 2.23 studs -- knee-high on an avatar and
    -- easy to miss among a thousand mats -- and its whole value is being an accent you
    -- notice. 30x puts it near 3.3. This deliberately breaks the "one factor preserves
    -- the kit's natural variation" rule, so it is scoped to the two upright families
    -- only; the mats that do the ground-cover work keep the shared 20x.
    familyScale = { Moss_B = 1.5, Moss_E = 1.35 },
    maps = {
        -- TONED to match the terrain's existing moss (user: "a little brighter/
        -- lime-greener than a lot of the existing assets"). Measured, not eyeballed:
        -- the kit's opaque average was 171,174,100 at hue 62 deg (yellow-green) while
        -- the terrain's Moss004 sits at 123,152,85 at hue 86 deg (true green) and 13%
        -- darker. A per-channel LINEAR factor of 0.491/0.743/0.718 -- derived by
        -- dividing the two measured averages, so no hand-tuned tint -- lands the kit
        -- at 124,152,85 against the target's 124,152,86. Cutout alpha untouched.
        -- Untoned original: rbxassetid://82048465547389
        ColorMap = "rbxassetid://101486813346396", -- RGBA, 70% cutout alpha, toned
        NormalMap = "rbxassetid://118508585188229",
        RoughnessMap = "rbxassetid://117526121500161",
    },
    -- family weights. Moss_B is the sporophyte ("flowering") form and reads as an
    -- accent, so it stays a minority; the flat mats do the ground-cover work.
    -- Moss_B DOUBLED (15 -> 38 of the total, so ~15% -> ~31%) because the user still
    -- struggled to spot it even after the burial bugs were fixed. It is the accent the
    -- whole species choice rests on; if it is not findable it is not doing its job.
    mix = { Moss_A = 34, Moos_C = 20, Moss_D = 22, Moss_E = 9, Moss_B = 38 },
    -- Density is GRADED BY WATER DISTANCE, not a binary in-band gate: moss answers to
    -- damp, so it packs at the waterline and loosens away from it (user: "plenty more
    -- moss, especially close to the waterlines").
    spacingNear = 2.0, -- at the water's edge
    spacingFar = 4.0, -- at waterProximity
    trampleRadius = 3.0, -- within this of a tread, feet keep it down
    trampleSpacing = 5.5, -- so it thins out there rather than vanishing
    waterProximity = 14, -- only within this far of water: it is a WATER margin
    scanStep = 4,
    bounds = { x0 = -440, x1 = 230, z0 = -95, z1 = 95 },
    -- ABSOLUTE studs bedded into the ground, NOT a fraction of height. It was a
    -- fraction, which is right for a flat mat (Size.Y ~0.8, so 0.1-0.3 studs) but
    -- badly wrong for an upright tuft: at Size.Y 2.23 the same rule buried up to 0.78
    -- studs -- a third of it, and exactly the base the stalks spring from. Combined
    -- with normalFollow tilting it downslope, the sporophytes ended up shorter and
    -- flatter than designed, which is why the user could not find them. A cushion beds
    -- in by a small fixed amount whatever its height.
    sink = { 0.10, 0.30 },
    -- How far a clump leans toward the GROUND NORMAL rather than world up. Not a
    -- fixed angle cap: a cushion on a bank genuinely follows the bank, so the range
    -- is "mostly follow the ground, with variation".
    normalFollow = { 0.55, 1.0 },
    seed = 20260802,
    dryRun = true,
}

local SS = game:GetService("ServerStorage")
local Terrain = workspace.Terrain

--------------------------------------------------------------------------------
-- MIRROR of tools/builders/CanyonKeepOuts.luau (Lune-tested; Studio cannot require
-- repo modules). Keep in sync -- and fix bugs THERE first.
--
-- The untouchable places. Materials are exact and self-maintaining; volumes are for
-- ground whose material is ordinary but whose CONTENT is not. 90 clumps had landed on
-- the Square's raked sand and 30 inside the karesansui before this existed.
--------------------------------------------------------------------------------
local KEEPOUT_MATERIALS = { [Enum.Material.Sand] = true }
local KEEPOUT_ZONES = {
    { name = "Karesansui", x0 = -25, x1 = 38, z0 = -16, z1 = 22 },
}
local function keptOut(x, z, material)
    if material and KEEPOUT_MATERIALS[material] then
        return true, "Sand"
    end
    for _, zn in ipairs(KEEPOUT_ZONES) do
        if x >= zn.x0 and x <= zn.x1 and z >= zn.z0 and z <= zn.z1 then
            return true, zn.name
        end
    end
    return false, nil
end

local function lcg(s)
    local n = (s * 16807) % 2147483647
    return n, (n - 1) / 2147483646
end

--------------------------------------------------------------------------------
-- library: normalise scale, attach one SurfaceAppearance per mesh
--------------------------------------------------------------------------------
local function buildLibrary()
    local src = workspace:FindFirstChild(CONFIG.importName) or SS:FindFirstChild(CONFIG.importName)
    local existing = SS:FindFirstChild(CONFIG.libraryName)
    if existing then
        return existing, ("library already present (%d meshes)"):format(#existing:GetChildren())
    end
    if not src then
        return nil,
            ("no %s in Workspace or ServerStorage -- import the PREPPED fbx first"):format(CONFIG.importName)
    end
    local lib = Instance.new("Folder")
    lib.Name = CONFIG.libraryName
    lib.Parent = SS
    local n = 0
    for _, m in ipairs(src:GetDescendants()) do
        if m:IsA("MeshPart") then
            local c = m:Clone()
            c.Size = m.Size * CONFIG.scale
            c.Anchored = true
            c.CanCollide = false
            c.CanQuery = false
            c.CanTouch = false
            c.CastShadow = false -- hundreds of tiny clumps; shadows are not worth it
            c.RenderFidelity = Enum.RenderFidelity.Automatic
            c.TextureID = "" -- a baked texture overrides the variant and washes out
            c.Material = Enum.Material.Grass
            for _, old in ipairs(c:GetChildren()) do
                if old:IsA("SurfaceAppearance") then
                    old:Destroy()
                end
            end
            local sa = Instance.new("SurfaceAppearance")
            sa.ColorMap = CONFIG.maps.ColorMap
            sa.NormalMap = CONFIG.maps.NormalMap
            sa.RoughnessMap = CONFIG.maps.RoughnessMap
            sa.AlphaMode = Enum.AlphaMode.Transparency -- cutout; without this: rectangles
            sa.Parent = c
            c.CFrame = CFrame.new(0, -500, 0)
            c.Parent = lib
            n += 1
        end
    end
    return lib, ("built library: %d meshes at %.1fx"):format(n, CONFIG.scale)
end

local lib, libMsg = buildLibrary()
if not lib then
    return libMsg
end

-- bucket the library by family prefix (note the kit's own typo: "Moos_C")
local families = {}
for _, m in ipairs(lib:GetChildren()) do
    local fam = m.Name:match("^(Mo[os]+_[A-E])")
    if fam then
        families[fam] = families[fam] or {}
        table.insert(families[fam], m)
    end
end

--------------------------------------------------------------------------------
-- care gradient, from real path anchors
--------------------------------------------------------------------------------
local CELL = 16
local grid, anchors = {}, 0
for _, m in ipairs(workspace.CanyonWorld.Paths:GetChildren()) do
    if m:IsA("Model") then
        for _, c in ipairs(m:GetChildren()) do
            if c:IsA("BasePart") and (c.Name:match("^Step_") or c.Name:match("^Riser_")) then
                local k = math.floor(c.Position.X / CELL) .. "," .. math.floor(c.Position.Z / CELL)
                grid[k] = grid[k] or {}
                table.insert(grid[k], c.Position)
                anchors += 1
            end
        end
    end
end
local function nearestPath(x, z)
    local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
    local best = 1e9
    for dx = -2, 2 do
        for dz = -2, 2 do
            local b = grid[(cx + dx) .. "," .. (cz + dz)]
            if b then
                for _, p in ipairs(b) do
                    local d = (p.X - x) ^ 2 + (p.Z - z) ^ 2
                    if d < best then
                        best = d
                    end
                end
            end
        end
    end
    return math.sqrt(best)
end
local STAGED = { { -345.4, -15.4, 15 }, { 6.5, 3.0, 30 }, { 72.8, 18.8, 22 } }
local function careLevel(x, z)
    for _, s in ipairs(STAGED) do
        if math.sqrt((x - s[1]) ^ 2 + (z - s[2]) ^ 2) <= s[3] then
            return "GARDEN"
        end
    end
    local reach = math.clamp(8 + 20 * (x + 430) / 470, 8, 28)
    local d = nearestPath(x, z)
    if d <= reach * 0.35 then
        return "GARDEN"
    elseif d <= reach then
        return "TENDED"
    end
    return "PRESERVE"
end

--------------------------------------------------------------------------------
-- candidates: near water, on ground, inside the gradient
--------------------------------------------------------------------------------
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { Terrain }
local function ground(x, z)
    local h = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), rp)
    if not h then
        return nil
    end
    return h.Position.Y, h.Material, h.Normal
end

local B = CONFIG.bounds
local cands = {}
local refused = {}
local state = (CONFIG.seed % 2147483646) + 1
local r
for x = B.x0, B.x1, CONFIG.scanStep do
    for z = B.z0, B.z1, CONFIG.scanStep do
        local gy, mat, nrm = ground(x, z)
        if gy and mat ~= Enum.Material.Water then
            local level = careLevel(x, z)
            do
                -- is water within reach? sample a ring rather than a full disc
                -- nearest water, not merely "is there water": the distance drives density
                local wetDist = nil
                for d = 2, CONFIG.waterProximity, 2 do
                    for a = 0, 315, 45 do
                        local ra = math.rad(a)
                        local _, m2 = ground(x + math.cos(ra) * d, z + math.sin(ra) * d)
                        if m2 == Enum.Material.Water then
                            wetDist = d
                            break
                        end
                    end
                    if wetDist then
                        break
                    end
                end
                local wet = wetDist ~= nil
                if wet then
                    state, r = lcg(state)
                    local jx = (r * 2 - 1) * CONFIG.scanStep * 0.45
                    state, r = lcg(state)
                    local jz = (r * 2 - 1) * CONFIG.scanStep * 0.45
                    state, r = lcg(state)
                    -- ⚠️ RE-SAMPLE THE GROUND AT THE JITTERED POINT. Jittering the
                    -- position while keeping the height sampled at the grid centre
                    -- buries clumps on the downhill side and floats them on the
                    -- uphill: a 1.8-stud lateral move changes ground height by a stud
                    -- or more on a bank. Measured before the fix, Moss_A averaged
                    -- 0.01 studs above ground with outliers at 13.9 -- simultaneously
                    -- buried and floating. Same species of error as the foliage
                    -- footing defect: reason about a point, then move it.
                    local jy, jmat, jn = ground(x + jx, z + jz)
                    local blocked, byWhat = keptOut(x + jx, z + jz, jmat)
                    if blocked then
                        refused[byWhat] = (refused[byWhat] or 0) + 1
                    end
                    if jy and jmat ~= Enum.Material.Water and not blocked then
                        table.insert(cands, {
                            x = x + jx,
                            z = z + jz,
                            y = jy,
                            n = jn or nrm,
                            level = level,
                            wetDist = wetDist,
                            trampled = nearestPath(x + jx, z + jz) <= CONFIG.trampleRadius,
                            key = r,
                        })
                    end
                end
            end
        end
    end
end

-- Poisson-ish: shuffle by key, keep only what clears minSpacing for its level
table.sort(cands, function(a, b)
    return a.key < b.key
end)
local placedPts = {}
local chosen = {}
for _, c in ipairs(cands) do
    local t = math.clamp((c.wetDist or CONFIG.waterProximity) / CONFIG.waterProximity, 0, 1)
    local S = CONFIG.spacingNear + (CONFIG.spacingFar - CONFIG.spacingNear) * t
    if c.trampled then
        S = math.max(S, CONFIG.trampleSpacing)
    end
    local ok = true
    for _, p in ipairs(placedPts) do
        if (p.x - c.x) ^ 2 + (p.z - c.z) ^ 2 < S * S then
            ok = false
            break
        end
    end
    if ok then
        table.insert(placedPts, c)
        table.insert(chosen, c)
    end
end

local counts = { GARDEN = 0, TENDED = 0, PRESERVE = 0 }
local trampled = 0
for _, c in ipairs(chosen) do
    counts[c.level] += 1
    if c.trampled then
        trampled += 1
    end
end

local report = ("%s\npath anchors %d; candidates %d -> chosen %d (GARDEN %d, TENDED %d, PRESERVE %d; %d on trodden verges)"):format(
    libMsg,
    anchors,
    #cands,
    #chosen,
    counts.GARDEN,
    counts.TENDED,
    counts.PRESERVE,
    trampled
)

local rl = {}
for k, v in pairs(refused) do
    table.insert(rl, ("%s x%d"):format(k, v))
end
table.sort(rl)
if #rl > 0 then
    report = report .. ("\nkeep-outs refused: %s"):format(table.concat(rl, ", "))
end

if CONFIG.dryRun then
    return report .. "\ndryRun -- nothing placed. Set dryRun = false to scatter."
end

--------------------------------------------------------------------------------
-- place
--------------------------------------------------------------------------------
local parent = workspace.CanyonWorld.Foliage:FindFirstChild(CONFIG.outFolder)
if parent then
    parent:Destroy()
end
parent = Instance.new("Folder")
parent.Name = CONFIG.outFolder
parent.Parent = workspace.CanyonWorld.Foliage

-- weighted family pick
local bag = {}
for fam, w in pairs(CONFIG.mix) do
    if families[fam] then
        for _ = 1, w do
            table.insert(bag, fam)
        end
    end
end
table.sort(bag)

local placed, byFam = 0, {}
for i, c in ipairs(chosen) do
    state, r = lcg(state)
    local fam = bag[math.floor(r * #bag) + 1]
    local pool = families[fam]
    state, r = lcg(state)
    local src = pool[math.floor(r * #pool) + 1]
    local m = src:Clone()
    m.Name = ("Moss_%d"):format(i)
    local boost = CONFIG.familyScale[fam]
    if boost then
        m.Size = m.Size * boost
    end
    state, r = lcg(state)
    local sink = CONFIG.sink[1] + (CONFIG.sink[2] - CONFIG.sink[1]) * r
    state, r = lcg(state)
    local yaw = r * math.pi * 2
    -- seat it on the slope it is actually on
    local up = c.n or Vector3.new(0, 1, 0)
    state, r = lcg(state)
    local f = CONFIG.normalFollow[1] + (CONFIG.normalFollow[2] - CONFIG.normalFollow[1]) * r
    local blended = Vector3.new(0, 1, 0) * (1 - f) + up * f
    blended = blended.Magnitude > 1e-4 and blended.Unit or Vector3.new(0, 1, 0)
    local right = blended:Cross(Vector3.new(0, 0, 1))
    if right.Magnitude < 1e-3 then
        right = blended:Cross(Vector3.new(1, 0, 0))
    end
    -- ⚠️ SEAT THE BOTTOM OF THE BOX, NOT ITS CENTRE. Placing the centre at ground
    -- level buries the whole lower half of every clump -- measured, a 2.96-stud
    -- Moss_B tuft showed only 0.89 studs, which is why the upright families looked
    -- absent. `sink` is now what its name says: ABSOLUTE studs bedded in, applied to
    -- the base. (It also used to be multiplied by Size.Y, so tall tufts were bedded
    -- 3x deeper than mats -- the opposite of what an upright plant wants.)
    m.CFrame = CFrame.fromMatrix(Vector3.new(c.x, c.y + m.Size.Y / 2 - sink, c.z), right.Unit, blended)
        * CFrame.Angles(0, yaw, 0)
    m.Parent = parent
    placed += 1
    byFam[fam] = (byFam[fam] or 0) + 1
end

local fl = {}
for k, v in pairs(byFam) do
    table.insert(fl, ("%s x%d"):format(k, v))
end
table.sort(fl)
return ("%s\n\nplaced %d clumps into CanyonWorld.Foliage.%s\n  %s"):format(
    report,
    placed,
    CONFIG.outFolder,
    table.concat(fl, ", ")
)
