### Task 5: KaresansuiController (tag-driven ring assembly)

**Files:**
- Create: `roblox/src/client/KaresansuiController.client.luau`

**Interfaces:**
- Consumes: `RakingMesh` (Task 4), CollectionService tag `KaresansuiIsland` (place-only rocks), `workspace.RoshamboStage.Karesansui` (Task 2 asset — used only as the parent for spawned rings).

- [ ] **Step 1: Implement**

```lua
--!strict
-- Builds the karesansui ripple rings around every KaresansuiIsland-tagged rock at
-- boot (EditableMesh doesn't replicate and Rojo JSON can't carry mesh geometry —
-- the CamMesh pattern). Move/add/remove a tagged boulder in Studio and the rings
-- follow on the next Play; no code edits. Rings are VISUAL ONLY (spec).
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local RakingMesh = require(shared:WaitForChild("RakingMesh"))

local stage = workspace:WaitForChild("RoshamboStage")
local garden = stage:WaitForChild("Karesansui")

local SEGMENTS = 48
local PITCH = 0.8 -- matches the field texture's groove pitch
local AMPLITUDE = 0.15
local RIDGE_W = 0.5
local RING_BAND = 3.2 -- ripple field extends this far beyond the island footprint

local SAND = Color3.new(0.87, 0.85, 0.79) -- matches the Field slabs

local function buildRings(island: BasePart)
    local footprintR = math.max(island.Size.X, island.Size.Z) / 2
    local g = {
        footprintR = footprintR,
        maxR = footprintR + RING_BAND,
        pitch = PITCH,
        amplitude = AMPLITUDE,
        ridgeW = RIDGE_W,
    }
    local ok, err = pcall(function()
        local m = RakingMesh.build(g, SEGMENTS)
        local em = AssetService:CreateEditableMesh()
        local vids, nids = table.create(#m.verts), table.create(#m.normals)
        for i, v in m.verts do
            vids[i] = em:AddVertex(Vector3.new(v[1], v[2], v[3]))
            nids[i] = em:AddNormal(Vector3.new(m.normals[i][1], m.normals[i][2], m.normals[i][3]))
        end
        for _, t in m.tris do
            local f = em:AddTriangle(vids[t[1]], vids[t[2]], vids[t[3]])
            em:SetFaceNormals(f, { nids[t[1]], nids[t[2]], nids[t[3]] })
        end
        local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
        part.Name = "RakingRings"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Sand
        part.Color = SAND
        -- rings lie flat on the field, proud like the flags (island pos, field top Y)
        local fieldTopY = 112.15 -- floorY + slabProud; MIRRORS ArenaLayout.karesansui
        part.CFrame = CFrame.new(island.Position.X, fieldTopY, island.Position.Z)
        part.Parent = garden
    end)
    if not ok then
        warn(`[KARESANSUI] rings skipped for {island:GetFullName()}: {err}`)
    end
end

for _, island in CollectionService:GetTagged("KaresansuiIsland") do
    if island:IsA("BasePart") then
        buildRings(island)
    end
end
CollectionService:GetInstanceAddedSignal("KaresansuiIsland"):Connect(function(inst)
    if inst:IsA("BasePart") then
        buildRings(inst)
    end
end)
```

- [ ] **Step 2: Verify + commit**

`lune run tests/run && stylua --check src tests tools && selene src tools` (controller has no Lune coverage by convention). Commit:

```bash
git add roblox/src/client/KaresansuiController.client.luau
git commit -m "feat(roblox): KaresansuiController — client-built ripple rings around tagged islands"
```

---

