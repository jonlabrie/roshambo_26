-- MCP/Edit: draggable waypoint markers for the RIVER PATH (Square -> upper pools).
-- Idempotent: rebuilds Workspace.PathDraft.River each run.
--
-- Seeded from the surveyed corridor profile in tools/builders/RiverPathChapters.luau
-- (MIRROR -- keep in sync). Drag them onto the line you want, then run
-- bakeRiverPathMarkers.luau and paste the result back into that module.
--
-- The legacy draftPathMarkers.luau seeds a DIFFERENT, superseded 2026-06 network and
-- rebuilds Workspace.PathDraft wholesale -- do not run it, it would destroy these.
local SEED = {
    { 60.0, 108.7, -8.0 },
    { 0.0, 109.9, -8.0 },
    { -80.0, 109.9, -8.0 },
    { -100.0, 134.4, -8.0 },
    { -160.0, 152.2, -8.0 },
    { -200.0, 159.4, -8.0 },
    { -240.0, 174.8, -8.0 },
    { -280.0, 174.8, -8.0 },
    { -300.0, 177.2, -8.0 },
    { -340.0, 186.9, -8.0 },
    { -360.0, 188.7, -8.0 },
    { -380.0, 199.5, -8.0 },
}

local CollectionService = game:GetService("CollectionService")

local draft = workspace:FindFirstChild("PathDraft")
if not draft then
    draft = Instance.new("Folder")
    draft.Name = "PathDraft"
    draft.Parent = workspace
end
local old = draft:FindFirstChild("River")
if old then
    old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "River"
folder.Parent = draft

local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }

for i, p in ipairs(SEED) do
    local hit = workspace:Raycast(Vector3.new(p[1], 500, p[3]), Vector3.new(0, -1000, 0), rc)
    local y = hit and hit.Position.Y + 1 or p[2]
    local m = Instance.new("Part")
    m.Name = ("River_%02d"):format(i)
    m.Shape = Enum.PartType.Ball
    m.Size = Vector3.new(4, 4, 4)
    m.Anchored = true
    m.CanCollide = false
    m.CanQuery = false
    m.Material = Enum.Material.Neon
    m.Color = Color3.fromRGB(120, 255, 170)
    m.Position = Vector3.new(p[1], y, p[3])
    m.Parent = folder
    CollectionService:AddTag(m, "DevMarker")
end

return ("drafted %d markers under Workspace.PathDraft.River"):format(#SEED)
