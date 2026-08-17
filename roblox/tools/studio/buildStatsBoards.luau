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

-- STALE-CACHE GUARD. Studio's VM caches a ModuleScript's RESULT, so a session that required
-- StatsRoomLayout before a Rojo sync keeps handing back the old table no matter what the source
-- says (see docs/wiki/practice/misc-engine-traps.md). An old copy has no SITES, and this tool
-- would then fail deep in the build loop. Fail here instead, with the fix in the message.
if not (Layout.SITES and Layout.FLAPS and Layout.isHorizontal) then
    error(
        "[statsBoards] STALE MODULE: this Studio VM has an old StatsRoomLayout cached (no SITES). "
            .. "Restart Studio, then re-run. Nothing was changed."
    )
end

local ok, failures = Layout.check()
if not ok then
    for _, f in failures do
        warn(`[statsBoards] LAYOUT FAILURE: {f}`)
    end
    error("[statsBoards] layout invariants failed — nothing built")
end

local world = workspace:FindFirstChild("CanyonWorld") or error("Workspace.CanyonWorld missing")
local structures = world:FindFirstChild("Structures") or error("CanyonWorld.Structures missing")
-- ATOMIC SWAP: BUILD FIRST, DESTROY LAST.
--
-- This tool used to destroy the live folder and then build into its replacement, which meant any
-- failure in between left the room with NO BOARDS AT ALL -- and that is exactly what happened
-- 2026-08-17, when a stale cached module errored mid-loop and the owner's next look found an
-- empty cavern. The new parts are assembled into a detached folder and only swapped in once
-- every one of them exists, so a failure now costs nothing: the old boards are still standing.
local folder = Instance.new("Folder")
folder.Name = "StatsBoards"

local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }

local report: { string } = {}
for _, b in Layout.BOARDS do
    local site = Layout.SITES[b.site]
    local inward = Layout.inwardFor(b.wall)
    local horizontal = Layout.isHorizontal(b.wall)
    local nominal = if horizontal then b.z else b.x

    -- SEAT AGAINST TERRAIN ONLY. The cavern is bored voxels, hand-shaped afterwards, so its
    -- nominal planes are not where the rock is. The vestibule's walls are built geometry at
    -- exact coordinates -- raycasting there would move a board to whatever a ray happened to
    -- strike, which is strictly worse than the number we already know.
    local hit = nil
    if site.seat then
        local axis = if horizontal then Vector3.new(0, 0, inward) else Vector3.new(inward, 0, 0)
        local start = Vector3.new(b.x, b.y, b.z) - axis * Layout.CAST_BACK
        hit = workspace:Raycast(start, axis * (Layout.CAST_BACK + MAX_ADJUST + 2), rc)
    end
    local seated = Layout.seat(nominal, hit and hit.Distance or nil, inward, MAX_ADJUST)

    local part = Instance.new("Part")
    part.Name = b.id
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    -- The personal slip and its facing summary board are paper-and-wood against stone (spec
    -- section 6.2), so they read as a different instrument from the dark wall boards.
    local personal = b.flap == Layout.FLAPS.slip
    part.Material = if personal then Enum.Material.Wood else Enum.Material.WoodPlanks
    part.Color = if personal then Color3.fromRGB(168, 140, 104) else Color3.fromRGB(74, 58, 40)
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
        string.format(
            "%-12s %-10s %-6s %2dx%-3d %6.2fx%-5.2f seated %.2f (nominal %.2f) hit=%s",
            b.id,
            b.site,
            b.wall,
            b.rows,
            b.cols,
            b.w,
            b.h,
            seated,
            nominal,
            tostring(hit ~= nil)
        )
    )
end

-- Every part exists and nothing threw. NOW take down the old set.
local existing = structures:FindFirstChild("StatsBoards")
if existing then
    existing:Destroy()
end
folder.Parent = structures

print("[statsBoards] built " .. #Layout.BOARDS .. " boards")
for _, line in report do
    print("  " .. line)
end
print("[statsBoards] SAVE/PUBLISH THE PLACE — these parts are place-only and rojo build drops them.")
