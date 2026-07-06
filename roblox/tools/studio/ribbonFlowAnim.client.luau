--!strict
-- Generic UV-scroll flow for ANY ribbon tagged "FlowRibbon" (CLIENT / LocalScript).
-- Install under StarterPlayer.StarterPlayerScripts.
--
-- Replaces the per-reach channelFlowAnim.client.luau approach: instead of hardcoding one
-- asset id + path, each persistent ribbon part carries its own metadata:
--   CollectionService tag "FlowRibbon"
--   attribute  FlowAsset  = "rbxassetid://..."  (the published ribbon mesh)
--   attribute  FlowSpeed  = tiles/sec (optional, default 0.3)
--
-- For each tagged part it loads the published mesh as an editable copy
-- (CreateEditableMeshAsync), renders the copy, clones the static part's SurfaceAppearance,
-- hides the static via LocalTransparencyModifier, and UV-scrolls V each frame.
--
-- Replication timing is handled for free: GetInstanceAddedSignal fires when a tagged part
-- replicates to the client, so no FindFirstChild race (see [[roblox-client-replication-race]]).
-- See [[procedural-river-pipeline]], [[roblox-editablemesh-gotchas]].

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local TAG = "FlowRibbon"

local function animate(static: Instance)
    if not static:IsA("BasePart") then
        return
    end
    if static:GetAttribute("__flowing") then
        return
    end
    local asset = static:GetAttribute("FlowAsset")
    if not asset then
        return
    end
    static:SetAttribute("__flowing", true)
    local speed = static:GetAttribute("FlowSpeed") or 0.3
    local ok, em = pcall(function()
        return AssetService:CreateEditableMeshAsync(Content.fromUri(asset))
    end)
    if not ok or not em then
        warn("[RibbonFlowAnim] load failed", static:GetFullName(), em)
        return
    end
    local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
        CollisionFidelity = Enum.CollisionFidelity.Box,
    })
    part.Name = static.Name .. "_Anim"
    part.Anchored = true
    part.CanCollide = false
    part.Material = static.Material
    part.Color = static.Color
    part.Transparency = static.Transparency
    part.Reflectance = static.Reflectance
    part.Parent = Workspace
    part:PivotTo(static:GetPivot())
    local sa = static:FindFirstChildOfClass("SurfaceAppearance")
    if sa then
        sa:Clone().Parent = part
    end
    static.LocalTransparencyModifier = 1
    local base = {}
    for _, id in em:GetUVs() do
        base[#base + 1] = { id = id, uv = em:GetUV(id) }
    end
    local scroll = 0
    RunService.RenderStepped:Connect(function(dt)
        scroll = (scroll + speed * dt) % 1
        for _, rec in base do
            em:SetUV(rec.id, Vector2.new(rec.uv.X, rec.uv.Y - scroll))
        end
    end)
end

for _, inst in CollectionService:GetTagged(TAG) do
    task.spawn(animate, inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
    task.spawn(animate, inst)
end)
