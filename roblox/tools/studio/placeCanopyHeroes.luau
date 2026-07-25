--!strict
-- placeCanopyHeroes.luau — survey place/bake for the square-viewshed HERO trees
-- (spec 2026-07-25-square-canopy-foliage-design §2). Run via MCP execute_luau
-- (Edit). MODE="place" stamps draggable kit clones from CONFIG (raycast-grounded,
-- engine flags on); drag/swap/delete/duplicate in Studio, then MODE="bake" prints
-- the CONFIG literal back from the live folder — paste it over CONFIG below so
-- the composition is reproducible. Clones are PLACE-ONLY (CanyonWorld.Foliage).
-- Kit templates live in ServerStorage.FoliageKit (Task 2 curation; asset ids:
-- ConiferA=8205214267, ConiferB=10686647505, ConiferC=5681543956,
-- MapleRed/Gold/BroadleafMid=103166897511921 retints, BlushAccent=135403657885076;
-- PineNiwaki pending the TurboSquid 2017007 reduction — entries below stamp once
-- the template exists, and warn-skip until then).
local ServerStorage = game:GetService("ServerStorage")

local MODE = "place" -- "place" | "bake"

-- Draft composition (world x/z; y raycast; yawDeg optional — nil = deterministic
-- jitter). INITIAL DRAFT from the reference image; expect the user to drag.
-- Landmarks: falls pool upstream −X; shopCorridor {-20,28,34,44} (merchant row,
-- south flank); eastCorridor {34,-10,54,38}; garden {-21,-12,34,18}; stair slope
-- climbs the south-west wall.
local CONFIG: { { species: string, x: number, z: number, scale: number, yawDeg: number? } } = {
    -- red maples: over the merchant-row upslope + falls south bank (coords
    -- terrain-probed 2026-07-25: pool water owns x<-40 for z -34..-4; south
    -- bank starts z≈8; upslope plantable band z 44-50)
    { species = "MapleRed", x = -26, z = 48, scale = 1.1 },
    { species = "MapleRed", x = -6, z = 50, scale = 1.0 },
    { species = "MapleRed", x = 26, z = 54, scale = 1.2 },
    { species = "MapleRed", x = -66, z = 10, scale = 1.15 }, -- falls south bank
    { species = "MapleRed", x = -70, z = 16, scale = 1.0 },
    -- gold maples: pool south + west banks
    { species = "MapleGold", x = -52, z = 8, scale = 1.1 },
    { species = "MapleGold", x = -48, z = 12, scale = 0.95 },
    { species = "MapleGold", x = -68, z = 4, scale = 1.0 }, -- leans over west bank
    -- niwaki pines (TurboSquid 2017007 set, user-cast 2026-07-25): mediums at the
    -- corridor mouths, small at the garden's west corner, talls as distance reads
    { species = "PineNiwakiB", x = -20, z = 30, scale = 1.0 },
    { species = "PineNiwakiC", x = 36, z = 20, scale = 1.0 },
    { species = "PineNiwakiA", x = -26, z = 24, scale = 1.0 },
    { species = "PineNiwakiE", x = 10, z = -17, scale = 1.0 }, -- north bank, across the river
    { species = "PineNiwakiF", x = -52, z = 56, scale = 1.0 }, -- SW upslope, reads from the square
    -- blush accents: high on the SW stair slope (valley-palette seed)
    { species = "BlushAccent", x = -44, z = 66, scale = 1.0 },
    { species = "BlushAccent", x = -70, z = 48, scale = 0.9 },
}

local function flagParts(root: Instance)
    for _, d in root:GetDescendants() do
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
end

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function groundY(x: number, z: number): number?
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.Terrain }
    local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params)
    return hit and hit.Position.Y or nil
end

local function heroesFolder(): Folder
    local cw = workspace:WaitForChild("CanyonWorld")
    local fol = cw:FindFirstChild("Foliage") :: Folder?
    if not fol then
        local nf = Instance.new("Folder")
        nf.Name = "Foliage"
        nf.Parent = cw
        fol = nf
    end
    local heroes = (fol :: Folder):FindFirstChild("Heroes") :: Folder?
    if not heroes then
        local nh = Instance.new("Folder")
        nh.Name = "Heroes"
        nh.Parent = fol
        heroes = nh
    end
    return heroes :: Folder
end

local function place()
    local kit = ServerStorage:FindFirstChild("FoliageKit")
    assert(kit, "ServerStorage.FoliageKit missing — run Task 2 kit curation first")
    local heroes = heroesFolder()
    heroes:ClearAllChildren()
    local state = 77
    for i, h in CONFIG do
        local yawRoll
        state, yawRoll = lcg(state)
        local template = kit:FindFirstChild(h.species)
        if not template then
            warn(`[heroes] no kit template {h.species} — skipped`)
            continue
        end
        local y = groundY(h.x, h.z)
        if not y then
            warn(`[heroes] no ground at ({h.x}, {h.z}) — skipped {h.species}`)
            continue
        end
        local clone = template:Clone()
        clone.Name = `Hero_{i}_{h.species}`
        local yaw = if h.yawDeg then math.rad(h.yawDeg) else yawRoll * 2 * math.pi
        flagParts(clone)
        clone.Parent = heroes
        clone:PivotTo(CFrame.new(h.x, y, h.z) * CFrame.Angles(0, yaw, 0))
        if clone:IsA("Model") and h.scale ~= 1 then
            clone:ScaleTo(h.scale)
        end
        clone:SetAttribute("Species", h.species)
        clone:SetAttribute("BaseScale", h.scale)
    end
    print(`[heroes] placed {#heroes:GetChildren()} — drag/swap/delete, then MODE="bake"`)
end

local function bake()
    local heroes = heroesFolder()
    local lines = { "local CONFIG = {" }
    for _, clone in heroes:GetChildren() do
        local p = clone:GetPivot().Position
        local species = clone:GetAttribute("Species")
        local scale = clone:GetAttribute("BaseScale") or 1
        local _, yaw, _ = clone:GetPivot():ToEulerAnglesYXZ()
        table.insert(
            lines,
            `    \{ species = "{species}", x = {math.floor(p.X * 10 + 0.5) / 10}, z = {math.floor(
                p.Z * 10 + 0.5
            ) / 10}, scale = {scale}, yawDeg = {math.floor(math.deg(yaw) + 0.5)} },`
        )
    end
    table.insert(lines, "}")
    print(table.concat(lines, "\n"))
end

if MODE == "place" then
    place()
else
    bake()
end
