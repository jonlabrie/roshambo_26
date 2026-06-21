--!strict
-- ZenDojo UP-CANYON WATERCOURSE — terrain sculpt/carve + water fill (MCP Edit-mode).
-- Run via Roblox Studio MCP execute_luau (datamodel=Edit); this file is the committed
-- source of truth, executed by pasting its contents into execute_luau. It CANNOT require
-- repo modules (everything is inlined) and is NOT Lune/Vitest-testable (it mutates live
-- workspace.Terrain). Verification per task is a FRESH raycast probe pass (separate
-- execution — probes in the SAME script as a FillBlock read STALE) + a user visual gate.
--
-- World frame: East=+X (downstream, built), WEST=-X (head, this work), North=-Z, South=+Z.
-- RES-4 voxels. StreamingEnabled=true. Spec/plan:
--   docs/superpowers/specs/2026-06-20-zendojo-upcanyon-watercourse-design.md
--   docs/superpowers/plans/2026-06-20-zendojo-upcanyon-watercourse.md
--
-- Target surfaces: Upper Basin y195 (x~-370), Mid pool y172 (x~-280), Lower pool y150
-- (x~-180), braided stream y150->y144 into the existing clearing in-fall (x-120, y144).
--
-- LIVE-TERRAIN NOTE (probed 2026-06-20): the back wall is ALREADY tall (centerline
-- y247@x-440, y290@x-455), taller than the plan's assumed ~243 — so the "raise a y240
-- crest" step is mostly a no-op (FillBlock Rock only adds where terrain is missing). It is
-- KEPT because it plugs a void found at (-455,-70). The infall notch is carved through the
-- full cap (up to ~y292) so it opens as a clean chute, not a roofed alcove.

local ServerStorage = game:GetService("ServerStorage")
local Terrain = workspace.Terrain

-- CopyRegion backup of the AABB of a (possibly rotated) box, keyed by name. Guarded:
-- only backs up once per name so re-runs never capture already-carved terrain.
local function backup(name: string, cf: CFrame, size: Vector3)
	if ServerStorage:FindFirstChild(name) then
		return
	end
	local hs = size / 2
	local mn, mx
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local c = cf * Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z)
				mn = mn and Vector3.new(math.min(mn.X, c.X), math.min(mn.Y, c.Y), math.min(mn.Z, c.Z)) or c
				mx = mx and Vector3.new(math.max(mx.X, c.X), math.max(mx.Y, c.Y), math.max(mx.Z, c.Z)) or c
			end
		end
	end
	local region = Region3.new(mn, mx):ExpandToGrid(4)
	local base = region.CFrame.Position - region.Size / 2
	local cx, cy, cz = base.X / 4, base.Y / 4, base.Z / 4
	local nx, ny, nz = region.Size.X / 4, region.Size.Y / 4, region.Size.Z / 4
	local bk = Terrain:CopyRegion(
		Region3int16.new(Vector3int16.new(cx, cy, cz), Vector3int16.new(cx + nx, cy + ny, cz + nz))
	)
	bk.Name = name
	bk.Parent = ServerStorage
end

-- carve away terrain (Air) inside an axis-aligned box from floorY up to topY
local function carveDownTo(centerXZ: Vector2, sizeXZ: Vector2, floorY: number, topY: number)
	local h = topY - floorY
	Terrain:FillBlock(
		CFrame.new(centerXZ.X, (floorY + topY) / 2, centerXZ.Y),
		Vector3.new(sizeXZ.X, h, sizeXZ.Y),
		Enum.Material.Air
	)
end

-- add rock (build terrain up) inside an axis-aligned box from baseY to topY
local function fillRock(centerXZ: Vector2, sizeXZ: Vector2, baseY: number, topY: number)
	local h = topY - baseY
	Terrain:FillBlock(
		CFrame.new(centerXZ.X, (baseY + topY) / 2, centerXZ.Y),
		Vector3.new(sizeXZ.X, h, sizeXZ.Y),
		Enum.Material.Rock
	)
end

-- fill water inside a box (basin/stream)
local function fillWater(centerXZ: Vector2, sizeXZ: Vector2, botY: number, surfY: number)
	local h = surfY - botY
	Terrain:FillBlock(
		CFrame.new(centerXZ.X, (botY + surfY) / 2, centerXZ.Y),
		Vector3.new(sizeXZ.X, h, sizeXZ.Y),
		Enum.Material.Water
	)
end

-- ========================================================================
-- TASK 1 — Western headwall: SCULPTED BY HAND IN STUDIO (user, 2026-06-20)
-- ========================================================================
-- The first scripted attempt (fillRock crest+wings + carved infall chute) was REVERTED
-- at the user's request — the already-tall natural back wall made the built-up approach
-- read wrong. The user is hand-sculpting the containing cliff / infall face directly in
-- Studio instead. The scripted builder resumes at Task 2 (basin carve), working from the
-- hand-sculpted headwall. (Backup of the pre-attempt head region: ServerStorage.UpHeadBackup.)

-- (suppress unused-warnings for helpers consumed by the Task 2+ blocks below)
local _ = { backup, carveDownTo, fillRock, fillWater }

return "buildUpcanyon: Task 1 headwall is hand-sculpted; run Task 2+ blocks as added"
