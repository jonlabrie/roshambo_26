--!strict
-- Places the river-trail yamadoro from BAKED as-built coordinates.
--
-- Run in Studio (Edit) with the command bar. Idempotent: refuses if the folder already exists,
-- so a re-run cannot double-place. Delete CanyonWorld.Paths.PathLanterns.Yamadoro_RiverTrail
-- to rebuild.
--
-- WHY BAKED, NOT DERIVED: these positions are the USER'S, hand-adjusted in Studio after an
-- algorithmic first pass, and they are better than anything the algorithm produced. There is no
-- rule that regenerates them. `buildBridge` once read PathDraft markers and broke the moment
-- they were deleted — surveyed coordinates get baked, like SwitchbackDeck's placement and the
-- terminus rock's CFrame.
--
-- THE SITING LAW (decided 2026-07-30):
--   * Yamadoro are the RUSTIC trail lantern — stone, set once, left. Not chochin, which are
--     paper, maintained, and belong to the formal higher/teahouse paths.
--   * WEST LIMIT x -291, the pool's west end. Past there the route crosses the rustic bridge
--     onto a 1.5-wide game trail, where a set stone lantern stops being plausible. (The
--     westernmost sits at -292.7, marginally past, because that is where it looked right.)
--   * SPARSE AND IRREGULAR — sited at features (bends, steepenings, the closest approach to
--     the pool), never at an interval. Spacing runs 35 / 23 / 21 / 34 / 56 studs.
--
-- ⚠️ Names record the ORIGINAL siting intent, not the final position: FallsSteps_6 was moved off
-- the falls steps to the traverse's end, and PoolShore_5 sits near step 2. Treat them as ids.
--
-- Source model: ServerStorage.YamadoroLibrary (5 MeshParts + FireboxCore, 3.000 studs, 4557
-- tris, one shared SurfaceAppearance). The firebox is lit by YamadoroDayNight.client.luau via
-- the "YamadoroFirebox" tag — cloning carries the tag, so placed lanterns light themselves.
local ServerStorage = game:GetService("ServerStorage")

local PLACEMENTS = {
    { name = "Yamadoro_Traverse_14", pos = { -124.437, 145.731, 13.976 }, yaw = 167.65 },
    { name = "Yamadoro_Traverse_27", pos = { -159.353, 155.064, 3.872 }, yaw = -167.84 },
    { name = "Yamadoro_Traverse_35", pos = { -182.195, 158.990, 16.398 }, yaw = 42.00 },
    { name = "Yamadoro_FallsSteps_6", pos = { -203.085, 163.739, 38.762 }, yaw = 164.55 },
    { name = "Yamadoro_PoolShore_5", pos = { -236.694, 176.348, 33.313 }, yaw = -171.94 },
    { name = "Yamadoro_PoolShore_21", pos = { -292.731, 179.321, 13.977 }, yaw = 178.86 },
}

local FOLDER = "Yamadoro_RiverTrail"

local lanterns = workspace.CanyonWorld.Paths.PathLanterns
if lanterns:FindFirstChild(FOLDER) then
    return string.format("REFUSED: %s already exists — delete it to rebuild", FOLDER)
end
local src = ServerStorage:FindFirstChild("YamadoroLibrary")
if not src then
    return "REFUSED: ServerStorage.YamadoroLibrary is missing"
end

local folder = Instance.new("Folder")
folder.Name = FOLDER
folder.Parent = lanterns

local report = {}
for _, p in ipairs(PLACEMENTS) do
    local clone = src:Clone()
    clone.Name = p.name
    clone.Parent = folder
    -- the model's WorldPivot is at its BASE centre, so this seats the bottom, not the middle
    clone:PivotTo(CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * CFrame.Angles(0, math.rad(p.yaw), 0))
    local bb, size = clone:GetBoundingBox()
    table.insert(report, string.format("  %-24s base %.2f", p.name, bb.Position.Y - size.Y / 2))
end

return string.format("placed %d yamadoro in %s\n%s", #PLACEMENTS, FOLDER, table.concat(report, "\n"))
