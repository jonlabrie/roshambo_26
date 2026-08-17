--!strict
-- Builds the Stats room's board parts, in the bored cavern, from StatsRoomLayout.
-- PASTE INTO THE STUDIO COMMAND BAR. Idempotent: re-running replaces the folder wholesale.
--
-- Place-only geometry (Workspace.CanyonWorld.Structures.StatsBoards) — Rojo manages only what
-- default.project.json names, and this is not in it. Ship by SAVING/PUBLISHING THE PLACE, never
-- by `rojo build`, which would drop every part this creates.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("StatsRoomLayout"))

local MAX_ADJUST = 2.5

local ok, failures = Layout.check()
if not ok then
    for _, f in failures do
        warn(`[statsBoards] LAYOUT FAILURE: {f}`)
    end
    error("[statsBoards] layout invariants failed — nothing built")
end

local world = workspace:FindFirstChild("CanyonWorld") or error("Workspace.CanyonWorld missing")
local structures = world:FindFirstChild("Structures") or error("CanyonWorld.Structures missing")
local existing = structures:FindFirstChild("StatsBoards")
if existing then
    existing:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "StatsBoards"
folder.Parent = structures

local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }

local report: { string } = {}
for _, b in Layout.BOARDS do
    local inward = Layout.inwardFor(b.wall)
    local horizontal = b.wall == "north" or b.wall == "south"
    local nominal = if horizontal then b.z else b.x
    -- Cast from CAST_BACK studs OUTSIDE the nominal plane, straight along the inward normal.
    local axis = if horizontal then Vector3.new(0, 0, inward) else Vector3.new(inward, 0, 0)
    local start = Vector3.new(b.x, b.y, b.z) - axis * Layout.CAST_BACK
    local hit = workspace:Raycast(start, axis * (Layout.CAST_BACK + MAX_ADJUST + 2), rc)
    local seated = Layout.seat(nominal, hit and hit.Distance or nil, inward, MAX_ADJUST)

    local part = Instance.new("Part")
    part.Name = b.id
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.Material = Enum.Material.WoodPlanks
    part.Color = Color3.fromRGB(74, 58, 40) -- dark timber frame; the flap cells supply the ivory
    part.Size = Vector3.new(b.w, b.h, Layout.THICKNESS)
    local px = if horizontal then b.x else seated
    local pz = if horizontal then seated else b.z
    part.CFrame = CFrame.new(px, b.y, pz) * CFrame.Angles(0, math.rad(Layout.yawFor(b.wall)), 0)
    part:SetAttribute("BoardId", b.id)
    part:SetAttribute("Rows", b.rows)
    part:SetAttribute("Cols", b.cols)
    part:SetAttribute("Shuttered", b.shuttered == true)
    CollectionService:AddTag(part, Layout.TAG)
    part.Parent = folder

    if b.shuttered then
        -- Section 8: a closed board, not a dark one. Two leaves meeting at the centre.
        for i, sign in { -1, 1 } do
            local leaf = Instance.new("Part")
            leaf.Name = `Shutter{i}`
            leaf.Anchored = true
            leaf.CanCollide = false
            leaf.CastShadow = false
            leaf.Material = Enum.Material.WoodPlanks
            leaf.Color = Color3.fromRGB(96, 78, 56)
            leaf.Size = Vector3.new(b.w / 2 - 0.05, b.h - 0.1, 0.25)
            leaf.CFrame = part.CFrame * CFrame.new(sign * b.w / 4, 0, -(Layout.THICKNESS / 2 + 0.13))
            leaf.Parent = part
        end
    end

    table.insert(
        report,
        `{b.id}: {b.wall} seated {string.format("%.2f", seated)} (nominal {nominal}) hit={hit ~= nil}`
    )
end

print("[statsBoards] built " .. #Layout.BOARDS .. " boards")
for _, line in report do
    print("  " .. line)
end
print("[statsBoards] SAVE/PUBLISH THE PLACE — these parts are place-only and rojo build drops them.")
