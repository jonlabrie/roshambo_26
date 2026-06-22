-- MCP/Edit: draggable control-point markers for the UP-CANYON RIVER ribbon.
-- Drag them in Studio onto the route you want: X/Z sets the path, Y sets the WATER
-- SURFACE ELEVATION at that point (drag a marker down so it kisses the pool surface).
-- To add a point on a missed pool: duplicate a marker and bump its number. To remove
-- one: delete it. Keep numbers ascending — the ribbon is built in name order.
-- When happy, re-run upcanyonRiverPOC.luau: it reads workspace.RiverDraft if present
-- and rebuilds the ribbon + flow beams from these exact marker positions.
-- Idempotent: rebuilds workspace.RiverDraft each run (so re-running RESETS your edits).

local old = workspace:FindFirstChild("RiverDraft")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "RiverDraft"
folder.Parent = workspace

-- Seed = the current POC path (the same 9 points the ribbon was built from). World
-- coords; drag from here. These are the idealized bed centerline — most sit a bit
-- high, so expect to pull several DOWN onto the actual pool surfaces.
-- User's hand-dragged path (baked from workspace.RiverDraft, 2026-06-21).
local SEED = {
	Vector3.new(-168.0, 150.0, -8.0),
	Vector3.new(-158.0, 151.1, -12.0),
	Vector3.new(-150.0, 148.6, -6.0),
	Vector3.new(-141.0, 148.0, -3.0),
	Vector3.new(-132.0, 146.1, -3.0),
	Vector3.new(-126.0, 140.8, -4.7),
	Vector3.new(-110.0, 137.2, -18.0),
	Vector3.new(-95.0, 134.7, -9.8),
	Vector3.new(-86.0, 131.1, -9.0),
}

for i, p in SEED do
	local m = Instance.new("Part")
	m.Name = ("River_%02d"):format(i)
	m.Shape = Enum.PartType.Ball
	m.Size = Vector3.new(4, 4, 4)
	m.Anchored = true
	m.CanCollide = false
	m.Material = Enum.Material.Neon
	m.Color = Color3.fromRGB(90, 220, 255)
	m.Transparency = 0.15
	m.Position = p
	m.Parent = folder
	-- floating index label so the build order is readable while dragging
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromScale(2, 2)
	bg.AlwaysOnTop = true
	bg.Parent = m
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Text = tostring(i)
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Parent = bg
end

return ("RiverDraft: %d markers spawned — drag (X/Z = route, Y = water height); re-run upcanyonRiverPOC.luau to rebuild"):format(#SEED)
