-- MCP/Edit: draggable draft markers for the STATS CAVERN (the room and tunnel to be
-- bored into the hill behind MachiyaStats' rear doorway). Paste/run in Studio (Edit
-- datamodel); requires nothing.
--
-- THE OWNER DRAGS THESE, THEN THE BORE IS A LATER ITEM. Nothing here carves terrain.
--   * StatsRoute_01..05 — the tunnel's centreline, rear doorway -> the chamber. XZ
--     handles: the bore ignores their Y and ramps the floor from the doorway's own
--     113.30, so only where they sit in plan matters. They are raycast onto the
--     TERRAIN SURFACE so they stay visible and grabbable (a marker at tunnel-floor
--     depth is buried inside rock — invisible and ungrabbable).
--   * StatsRoom_NW/NE/SW/SE — four corner handles for the chamber at the end, same
--     surface placement. NW/NE face the doorway (north, -Z); SW/SE are the far wall.
--
-- Parented Workspace.PathDraft.StatsCavern — place-only, like the other draft-marker
-- sets (PathDraft is NOT under RoshamboStage; Rojo owns exactly what the project file
-- names). Tagged DevMarker so hideDevMarkers.client.luau hides them in Play.
--
-- GUARD (destructive-bake discipline, the buildHanabiyaChochin pattern): if the
-- output folder already exists it may hold OWNER-DRAGGED positions, which this file
-- cannot restore. Default is to REFUSE. Flip REBUILD only to discard them on purpose.
local REBUILD = false

-- Seed literals, MIRRORED from tools/builders/MachiyaShops.luau (stats envelope:
-- x[-33.92,-23.92] z[35.23,43.23], floor 113.30) and Machiya.luau's stucco box
-- (setback 0.30): the rear wall's outer face is z 42.93, the doorway is 6.0 clear
-- centred on x -28.92. Studio-pasted, so no require() — keep in sync by eye.
local DOOR_X = -28.92
local WALL_OUTER_Z = 42.93

-- Route: doorway mouth, then south (+Z) into the hill, easing slightly east where
-- the slope is gentler (the west columns run 4+ studs higher). STARTING GUESSES — drag.
local ROUTE = {
    { DOOR_X, WALL_OUTER_Z + 2.0 }, -- just behind the rear wall
    { DOOR_X, 48.0 },
    { -28.4, 52.0 },
    { -28.0, 56.0 },
    { -28.0, 60.0 },
}
-- Chamber at the end: ~14 x 12, its near (north) edge 2 studs past the last route
-- marker. Corner names are compass-true for this canyon (-Z = North).
local ROOM = {
    NW = { -35.0, 62.0 },
    NE = { -21.0, 62.0 },
    SW = { -35.0, 74.0 },
    SE = { -21.0, 74.0 },
}

local CollectionService = game:GetService("CollectionService")

local draft = workspace:FindFirstChild("PathDraft")
if not draft then
    draft = Instance.new("Folder")
    draft.Name = "PathDraft"
    draft.Parent = workspace
end
local existing = draft:FindFirstChild("StatsCavern")
if existing and not REBUILD then
    return (
        "Workspace.PathDraft.StatsCavern already exists (%d markers) — refusing to rebuild over"
        .. " what may be owner-dragged positions. Set REBUILD = true if you mean to discard them."
    ):format(#existing:GetChildren())
end
if existing then
    existing:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "StatsCavern"
folder.Parent = draft

local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }

local placed = {}
local function marker(name: string, x: number, z: number, color: Color3)
    local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), rc)
    -- ON the surface (+1 so the ball's lower half sits proud); the bore ignores Y anyway
    local y = hit and hit.Position.Y + 1 or 120
    local m = Instance.new("Part")
    m.Name = name
    m.Shape = Enum.PartType.Ball
    m.Size = Vector3.new(4, 4, 4)
    m.Anchored = true
    m.CanCollide = false
    m.CanQuery = false
    m.Material = Enum.Material.Neon
    m.Color = color
    m.Position = Vector3.new(x, y, z)
    m.Parent = folder
    CollectionService:AddTag(m, "DevMarker")
    table.insert(placed, ("%s (%.1f, %.1f, %.1f)"):format(name, x, y, z))
end

for i, p in ipairs(ROUTE) do
    marker(("StatsRoute_%02d"):format(i), p[1], p[2], Color3.fromRGB(255, 120, 200))
end
for _, corner in { "NW", "NE", "SW", "SE" } do
    local p = ROOM[corner]
    marker("StatsRoom_" .. corner, p[1], p[2], Color3.fromRGB(255, 140, 60))
end

return (
    "drafted %d markers under Workspace.PathDraft.StatsCavern — drag the pink route onto the"
    .. " tunnel line and the orange corners onto the chamber:\n%s"
):format(#placed, table.concat(placed, "\n"))
