--!strict
-- ZenDojo CHANNEL RIBBON — runtime UV-scroll on a PUBLISHED mesh (CLIENT / LocalScript).
-- Path B (persistent) + motion. Install under StarterPlayer.StarterPlayerScripts.
--
-- The channel ribbon is a real, persistent, replicated mesh asset (the "static" part lives
-- in the place and survives save/play). This script does NOT rebuild geometry from math —
-- it LOADS that published asset as an editable copy (CreateEditableMeshAsync), renders the
-- copy, hides the static part locally, and UV-scrolls the copy each frame for flow.
--
-- Why a client copy at all: in this build you can't get a live-editable handle to a normal
-- MeshPart (MeshContent is write-locked; CreateEditableMeshFromPartAsync doesn't exist), so
-- UV animation needs an editable mesh you own. We source its geometry from the asset, not
-- from a path rebuild. See [[roblox-editablemesh-gotchas]].

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MESH = "rbxassetid://101344850099792" -- ZenChannelRibbon v2 (lowered ends, lifted center)
local FLOW_TILES_PER_SEC = 0.30 -- +20% from 0.25
local STATIC_PATH = { "CanyonWorld", "Water", "W03_OutfallRun", "ChannelRibbon" }

-- WaitForChild, not FindFirstChild: this is a client script and the stage geometry
-- replicates from the server asynchronously. FindFirstChild returns nil if the script
-- wins the race against replication, so the script would bail and never animate
-- (intermittent "no flow"). Waiting blocks until each node has replicated.
local function resolve(path: { string }): Instance?
    local node: Instance = Workspace
    for _, name in path do
        local nxt = node:WaitForChild(name, 30)
        if not nxt then
            return nil -- genuinely absent after 30s
        end
        node = nxt
    end
    return node
end

local static = resolve(STATIC_PATH)
if not (static and static:IsA("BasePart")) then
    warn("[ChannelFlowAnim] static channel ribbon never replicated; not animating")
    return
end

-- load the published mesh as an editable copy (geometry from the asset, not rebuilt)
local em = AssetService:CreateEditableMeshAsync(Content.fromUri(MESH))
local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
    CollisionFidelity = Enum.CollisionFidelity.Box, -- NB: there is no CollisionFidelity.None
})
part.Name = "ChannelRibbonAnim"
part.Anchored = true
part.CanCollide = false
part.Material = static.Material
part.Color = static.Color
part.Transparency = static.Transparency
part.Reflectance = static.Reflectance
part.Parent = Workspace
part:PivotTo(static:GetPivot()) -- match the (lowered) static placement exactly

-- clone the SurfaceAppearance (runtime can't WRITE ColorMap/NormalMap, but cloning is fine)
local srcSA = static:FindFirstChildOfClass("SurfaceAppearance")
if srcSA then
    srcSA:Clone().Parent = part
end

-- hide the static persistent part locally so only the animated copy shows
static.LocalTransparencyModifier = 1

-- snapshot base UVs, then scroll V each frame (wrap at 1.0 = texture period → invisible reset)
local base = {}
for _, id in em:GetUVs() do
    base[#base + 1] = { id = id, uv = em:GetUV(id) }
end
local scroll = 0
RunService.RenderStepped:Connect(function(dt)
    scroll = (scroll + FLOW_TILES_PER_SEC * dt) % 1
    for _, rec in base do
        em:SetUV(rec.id, Vector2.new(rec.uv.X, rec.uv.Y - scroll))
    end
end)
