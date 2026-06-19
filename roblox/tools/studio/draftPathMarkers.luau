-- MCP/Edit: draggable first-pass waypoint markers for the canyon path network.
-- Drag/add/delete them in Studio onto the routes you want, then run
-- bakePathMarkers.luau to emit the ArenaLayout.paths table. Idempotent (rebuilds
-- workspace.PathDraft each run). Marker name = "<route>_<index>"; keep indices
-- contiguous per route (duplicate a marker and bump its number to add one).
local old = workspace:FindFirstChild("PathDraft")
if old then
    old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "PathDraft"
folder.Parent = workspace

-- First-pass routes as {x,z} (Y is snapped to terrain here, re-snapped at build).
-- Clearing ≈ origin (floor y≈112). Trunk up the near (+Z) wall, trunk up the far
-- (−Z) wall, a floor path along the river, an overlook spur. STARTING GUESSES — drag.
local ROUTES = {
    NearWall = { class = "trunk", xz = { { 30, 30 }, { 70, 45 }, { 110, 60 }, { 150, 70 } } },
    FarWall = { class = "trunk", xz = { { 30, -30 }, { 70, -45 }, { 110, -55 }, { 150, -65 } } },
    Floor = { class = "trunk", xz = { { 0, 0 }, { 60, 8 }, { 120, 0 }, { 180, -10 } } },
    Overlook = { class = "spur", xz = { { 60, 20 }, { 74, 28 } } },
}
local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }
for name, route in ROUTES do
    for i, p in route.xz do
        local hit = workspace:Raycast(Vector3.new(p[1], 500, p[2]), Vector3.new(0, -1000, 0), rc)
        local y = hit and hit.Position.Y + 1 or 120
        local m = Instance.new("Part")
        m.Name = ("%s_%02d"):format(name, i)
        m.Shape = Enum.PartType.Ball
        m.Size = Vector3.new(4, 4, 4)
        m.Anchored = true
        m.CanCollide = false
        m.Material = Enum.Material.Neon
        m.Color = route.class == "spur" and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(255, 210, 90)
        m.Position = Vector3.new(p[1], y, p[2])
        m.Parent = folder
    end
end
return "drafted markers under workspace.PathDraft — drag them onto the routes you want"
