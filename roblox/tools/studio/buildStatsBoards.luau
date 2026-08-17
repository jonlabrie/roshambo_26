--!strict
-- Builds the Stats room's board parts, in the bored cavern, from StatsRoomLayout.
-- PASTE INTO THE STUDIO COMMAND BAR. Idempotent: re-running replaces the folder wholesale.
--
-- Place-only geometry (Workspace.CanyonWorld.Structures.StatsBoards) — Rojo manages only what
-- default.project.json names, and this is not in it. Ship by SAVING/PUBLISHING THE PLACE, never
-- by `rojo build`, which would drop every part this creates.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- REQUIRE A CLONE, NOT THE MODULE. Studio's VM caches a ModuleScript's RESULT forever, so a
-- session that required StatsRoomLayout before a Rojo sync keeps getting the OLD table however
-- current the source is. This bit twice on 2026-08-17: the second time, the tool's own source was
-- re-read (so new hardware appeared) while the flap size came from cache (so the boards kept
-- their old dimensions) -- a half-applied change, which is worse than none, because it looks like
-- the edit simply did not work.
--
-- A clone is a DIFFERENT instance, so require() cannot serve it from cache and the source is
-- evaluated fresh. It is parented alongside the original first so any relative require inside it
-- still resolves against its real siblings, then destroyed.
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Layout
do
    local clone = shared:WaitForChild("StatsRoomLayout"):Clone()
    clone.Name = "StatsRoomLayout_buildStatsBoards_tmp"
    clone.Parent = shared
    local ok, result = pcall(require, clone)
    clone:Destroy()
    if not ok then
        error("[statsBoards] StatsRoomLayout failed to load: " .. tostring(result))
    end
    Layout = result
end

local MAX_ADJUST = 2.5

-- Shape check on what the clone gave us. Not a cache guard any more -- the clone above makes
-- staleness impossible -- just a clear failure if the module is mid-edit or broken.
if not (Layout.SITES and Layout.FLAPS and Layout.isHorizontal and Layout.BOARDS) then
    error("[statsBoards] StatsRoomLayout is missing SITES/FLAPS/BOARDS. Nothing was changed.")
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
    -- EVERY board is framed in the same dark wood (owner, 2026-08-17). The pale frame briefly
    -- given to the vestibule pair was reaching for spec 6.2's "paper-and-wood against stone" in
    -- the wrong place: the PAPER is the ivory flap face, which every board already has, and the
    -- wood is what surrounds it. Two frame colours just made the room look like two rooms. The
    -- slips stay distinct by being a finer module, which is the honest difference.
    part.Material = Enum.Material.WoodPlanks
    part.Color = Color3.fromRGB(74, 58, 40)
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
        -- A CLOSED BOARD, NOT A DARK ONE (spec section 8). The first version was two bare leaves
        -- with a 0.05 gap, and the owner looked straight at it and asked what the blank board
        -- was -- which is the exact failure section 8 exists to prevent. It needs to read as
        -- SHUT from across the room, so: a real recessed seam, strap hinges on the outer stiles,
        -- and a hasp and padlock across the joint.
        --
        -- Every dimension is a proportion of the board. `skillFuture` is 8.0 x 4.32 today and
        -- will not stay that size once the rate ladders it is reserved for arrive.
        local SEAM = b.w * 0.018 -- recess between the leaves; shows the dark board 0.25 behind
        local BORDER = b.h * 0.04 -- dark frame left proud around the leaves
        local FACE = -(Layout.THICKNESS / 2 + 0.13) -- leaves stand this far off the board face
        local IRON = Color3.fromRGB(38, 34, 30)

        local function iron(name: string, size: Vector3, offset: Vector3): Part
            local q = Instance.new("Part")
            q.Name = name
            q.Anchored = true
            q.CanCollide = false
            q.CastShadow = false
            q.Material = Enum.Material.Metal
            q.Color = IRON
            q.Size = size
            q.CFrame = part.CFrame * CFrame.new(offset)
            q.Parent = part
            return q
        end

        local leafW = (b.w - SEAM) / 2 - BORDER
        for i, sign in { -1, 1 } do
            local leaf = Instance.new("Part")
            leaf.Name = `Shutter{i}`
            leaf.Anchored = true
            leaf.CanCollide = false
            leaf.CastShadow = false
            leaf.Material = Enum.Material.WoodPlanks
            leaf.Color = Color3.fromRGB(96, 78, 56)
            leaf.Size = Vector3.new(leafW, b.h - BORDER * 2, 0.25)
            leaf.CFrame = part.CFrame * CFrame.new(sign * (SEAM / 2 + leafW / 2), 0, FACE)
            leaf.Parent = part

            -- Strap hinges: two per leaf, on the OUTER stile, reaching in across the leaf so the
            -- eye reads a door that swings outward from the middle.
            for _, ty in { 0.30, -0.30 } do
                iron(
                    `Hinge{i}`,
                    Vector3.new(leafW * 0.42, b.h * 0.075, 0.06),
                    Vector3.new(sign * (b.w / 2 - BORDER - leafW * 0.21), b.h * ty, FACE - 0.155)
                )
            end
        end

        -- Hasp across the joint, with its staple and a padlock hanging below. This is the part
        -- that says SHUT rather than merely blank: a plate spanning the seam cannot be read as
        -- an empty surface.
        iron("Hasp", Vector3.new(b.w * 0.20, b.h * 0.075, 0.07), Vector3.new(0, 0, FACE - 0.16))
        iron("HaspStaple", Vector3.new(b.w * 0.045, b.h * 0.11, 0.09), Vector3.new(0, 0, FACE - 0.17))
        iron(
            "LockBody",
            Vector3.new(b.w * 0.055, b.h * 0.085, 0.10),
            Vector3.new(0, -b.h * 0.095, FACE - 0.18)
        )
        iron(
            "LockShackle",
            Vector3.new(b.w * 0.030, b.h * 0.060, 0.05),
            Vector3.new(0, -b.h * 0.038, FACE - 0.18)
        )
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

print(
    string.format(
        "[statsBoards] built %d boards | flaps wall %.3fx%.3f  slip %.3fx%.3f",
        #Layout.BOARDS,
        Layout.FLAPS.wall.w,
        Layout.FLAPS.wall.h,
        Layout.FLAPS.slip.w,
        Layout.FLAPS.slip.h
    )
)
for _, line in report do
    print("  " .. line)
end
print("[statsBoards] SAVE/PUBLISH THE PLACE — these parts are place-only and rojo build drops them.")
