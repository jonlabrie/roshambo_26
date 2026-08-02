--!strict
-- bakeEastBackdrop.luau — plant the ad-hoc terrain east of the canyon (x 205..470, curving
-- north). Run via MCP execute_luau (Edit). Writes ONLY to CanyonWorld.Foliage.EastBackdrop.
--
-- THIS GROUND IS SCENERY, NOT A PLACE. The easternmost path marker is x 149 and 72 of 74
-- sampled spots out here are more than 120 studs from any path — nobody walks it. But every
-- vantage sees it, including FallsLanding at 686 studs, which makes this mass the far end of
-- the longest sightline in the canyon. So it gets BACKDROP MASSING: skyline variants only,
-- silhouette over detail, no arrangements and no ground-layer fuss. 35 trees cost 73
-- MeshParts here; the same count of full-detail trees would cost roughly triple.
--
-- WHERE TREES GO IS DECIDED BY SLOPE, and the user read it off the terrain before I measured
-- it: "there are a lot of steep slopes where trees aren't suitable, but you can see from the
-- green/mossy areas that there are some spots that would support trees." The shader shows
-- moss on shelves and bare rock on steep faces, so green IS low slope. Measured: 618 of 719
-- ground samples exceed 32 degrees. Only 14% of this country is plantable.
--
-- SITES ARE DERIVED, THEN THE USER CHOOSES. The script finds shelves (4-point ring slope
-- <= 32 deg), keeps the ones visible from the two EASTERNMOST vantages — the south-side
-- camera at (125,192,94) and RoshamboStage.SwitchbackDeck on the north side — and clusters
-- them into numbered pockets. Those were staked with neon poles in-world and the user picked
-- which earned trees. CHOSEN is that answer; do not silently widen it.
--
-- Re-running reproduces the same pocket NUMBERS only while the terrain and the two vantages
-- are unchanged. If the terrain moves, re-stake and re-ask rather than trusting CHOSEN.

local ServerStorage = game:GetService("ServerStorage")

-- see [[roblox-destructive-bake-guard]]: this rebuilds its folder, which is safe only until
-- the user hand-tunes it. If the guard trips, STOP AND ASK — do not flip this to proceed.
local ALLOW_DESTROYING_HAND_WORK = false

local CHOSEN: { [number]: boolean } =
    { [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [9] = true, [12] = true }
local SOUTH_VANTAGE = Vector3.new(125, 192, 94)
local NORTH_VANTAGE = Vector3.new(159, 138, -66)
local X0, X1, Z0, Z1, STEP = 205, 470, -250, 140, 10
local MAX_SLOPE_DEG = 32
local FOOTING_MAX_DROP = 14 -- matches foliageZoneRecipes
local POCKET_RADIUS = 34
local MIN_SPACING, MIN_FROM_EXISTING = 9, 12
local SEED = 20260802

-- weights, not counts: skyline conifers carry the mass, maples are the only colour out here
local PALETTE: { { primary: string, fallback: string, weight: number } } = {
    { primary = "XfHinokiM_sky", fallback = "XfHinokiM", weight = 26 },
    { primary = "XfSpruceM_sky", fallback = "XfSpruceM", weight = 26 },
    { primary = "XfFirM_sky", fallback = "XfFirM", weight = 22 },
    { primary = "XfSugi40", fallback = "XfSugi40", weight = 12 },
    { primary = "XfMapleGold_sky", fallback = "XfMapleGold", weight = 7 },
    { primary = "XfMapleRed_sky", fallback = "XfMapleRed", weight = 7 },
}

local terrain = workspace.Terrain
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { terrain }

local function ground(x: number, z: number): (number?, boolean)
    local hit = workspace:Raycast(Vector3.new(x, 520, z), Vector3.new(0, -700, 0), rayParams)
    if not hit then
        return nil, false
    end
    return hit.Position.Y, hit.Material == Enum.Material.Water
end

local function ringSlopeDeg(x: number, z: number, y: number, radius: number): number?
    local drop = 0
    for a = 0, 3 do
        local th = a * math.pi / 2
        local gy = ground(x + math.cos(th) * radius, z + math.sin(th) * radius)
        if not gy then
            return nil
        end
        drop = math.max(drop, math.abs(gy - y))
    end
    return math.deg(math.atan(drop / radius))
end

local function seesCrown(eye: Vector3, spot: Vector3): boolean
    local target = spot + Vector3.new(0, 12, 0) -- aim at a crown, not the dirt
    local hit =
        workspace:Raycast(eye + Vector3.new(0, 4, 0), target - (eye + Vector3.new(0, 4, 0)), rayParams)
    return (not hit) or (hit.Position - target).Magnitude < 15
end

type Pocket = { pos: Vector3, n: number, pts: { Vector3 } }

local function findPockets(): { Pocket }
    local shelves: { Vector3 } = {}
    for x = X0, X1, STEP do
        for z = Z0, Z1, STEP do
            local y = ground(x, z)
            if y then
                local deg = ringSlopeDeg(x, z, y, 6)
                if deg and deg <= MAX_SLOPE_DEG then
                    table.insert(shelves, Vector3.new(x, y, z))
                end
            end
        end
    end
    local pockets: { Pocket } = {}
    for _, s in shelves do
        if seesCrown(SOUTH_VANTAGE, s) or seesCrown(NORTH_VANTAGE, s) then
            local hit: Pocket? = nil
            for _, c in pockets do
                if (c.pos - s).Magnitude < POCKET_RADIUS then
                    hit = c
                    break
                end
            end
            if hit then
                hit.n += 1
                hit.pos = hit.pos:Lerp(s, 1 / hit.n)
                table.insert(hit.pts, s)
            else
                table.insert(pockets, { pos = s, n = 1, pts = { s } })
            end
        end
    end
    -- descending shelf count IS the numbering the user saw on the staked poles
    table.sort(pockets, function(a, b)
        return a.n > b.n
    end)
    return pockets
end

local kit = ServerStorage:FindFirstChild("FoliageKit") :: Folder
assert(kit, "ServerStorage.FoliageKit missing")
local pool: { string } = {}
for _, entry in PALETTE do
    local name = (kit:FindFirstChild(entry.primary) and entry.primary)
        or (kit:FindFirstChild(entry.fallback) and entry.fallback)
        or nil
    if name then
        for _ = 1, entry.weight do
            table.insert(pool, name)
        end
    else
        warn(`[east] neither {entry.primary} nor {entry.fallback} in the kit`)
    end
end
assert(#pool > 0, "no backdrop species available")

local existing: { Vector3 } = {}
for _, name in { "Heroes", "Preserve", "ArrangementsDraft" } do
    local root = workspace.CanyonWorld.Foliage:FindFirstChild(name)
    if root then
        for _, m in root:GetDescendants() do
            if m:IsA("Model") and m:FindFirstChildWhichIsA("BasePart") then
                local q = m:GetPivot().Position
                if q.X > 180 then
                    table.insert(existing, q)
                end
            end
        end
    end
end

local function fingerprint(folder: Instance): string
    local rows = {}
    for _, g in folder:GetChildren() do
        if g:IsA("Model") then
            local q = g:GetPivot().Position
            table.insert(
                rows,
                ("%s@%d,%d,%d"):format(g.Name, math.round(q.X), math.round(q.Y), math.round(q.Z))
            )
        end
    end
    table.sort(rows)
    return table.concat(rows, "|")
end

local foliage = workspace.CanyonWorld.Foliage
local prior = foliage:FindFirstChild("EastBackdrop")
if prior then
    local wrote = prior:GetAttribute("BakeFingerprint")
    if typeof(wrote) == "string" and wrote ~= fingerprint(prior) and not ALLOW_DESTROYING_HAND_WORK then
        error(
            "[east] EastBackdrop has been hand-edited since the last bake — refusing to destroy it. Ask the user."
        )
    end
    prior:Destroy()
end
local root = Instance.new("Folder")
root.Name = "EastBackdrop"
root.Parent = foliage

local state = SEED
local function rnd(): number
    state = (1103515245 * state + 12345) % 2147483648
    return state / 2147483648
end

local newPts: { Vector3 } = {}
local function blocked(at: Vector3): boolean
    for _, e in existing do
        if (e - at).Magnitude < MIN_FROM_EXISTING then
            return true
        end
    end
    for _, e in newPts do
        if (e - at).Magnitude < MIN_SPACING then
            return true
        end
    end
    return false
end

local placed = 0
for index, pocket in findPockets() do
    if CHOSEN[index] then
        local group = Instance.new("Model")
        group.Name = ("EastPocket_%02d"):format(index)
        group:SetAttribute("Shelves", pocket.n)
        group.Parent = root
        local budget = math.clamp(math.floor(pocket.n * 1.5) + 1, 1, 12)
        local tries = 0
        while #group:GetChildren() < budget and tries < budget * 14 do
            tries += 1
            local base = pocket.pts[math.floor(rnd() * #pocket.pts) + 1]
            local ang, rad = rnd() * math.pi * 2, rnd() * 7
            local tx, tz = base.X + math.cos(ang) * rad, base.Z + math.sin(ang) * rad
            local gy, water = ground(tx, tz)
            if gy and not water then
                local lo, hi, okRing = math.huge, -math.huge, true
                for a = 0, 3 do
                    local th = a * math.pi / 2
                    local q = ground(tx + math.cos(th) * 5, tz + math.sin(th) * 5)
                    if not q then
                        okRing = false
                        break
                    end
                    lo, hi = math.min(lo, q), math.max(hi, q)
                end
                local at = Vector3.new(tx, gy, tz)
                if okRing and (hi - lo) <= FOOTING_MAX_DROP and not blocked(at) then
                    local species = pool[math.floor(rnd() * #pool) + 1]
                    local template = kit:FindFirstChild(species) :: Model
                    local clone = template:Clone()
                    -- ScaleTo is ABSOLUTE; a relative change must multiply GetScale()
                    clone:ScaleTo(clone:GetScale() * (0.85 + rnd() * 0.45))
                    local depth = tonumber(template:GetAttribute("PlantDepth")) or 0
                    clone:PivotTo(CFrame.new(tx, gy - depth, tz) * CFrame.Angles(0, rnd() * math.pi * 2, 0))
                    for _, d in clone:GetDescendants() do
                        if d:IsA("BasePart") then
                            d.Anchored = true
                            d.CastShadow = false
                            d.CanCollide = false
                            d.CanQuery = false
                            d.CanTouch = false
                            if d:IsA("MeshPart") then
                                d.RenderFidelity = Enum.RenderFidelity.Automatic
                            end
                        elseif d:IsA("BillboardGui") then
                            d:Destroy()
                        end
                    end
                    clone:SetAttribute("Species", species)
                    clone.Parent = group
                    table.insert(newPts, at)
                    placed += 1
                end
            end
        end
    end
end

root:SetAttribute("BakeFingerprint", fingerprint(root))
print(`[east] {placed} trees into CanyonWorld.Foliage.EastBackdrop across {#root:GetChildren()} pockets`)
