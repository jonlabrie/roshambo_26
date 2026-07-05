--!strict
-- A<->B integration visual gate: build a cliff pad (PadBuilder) at a surveyed site,
-- then stand a teahouse-1story STRUCTURE (StructureBuilder, sub-project A) on the pad's
-- returned mount. The structure's frame underside lands on the post tops at the datum.
-- Run via MCP execute_luau (datamodel Edit) or the Studio command bar.
--
-- MCP Studio scripts cannot `require` repo modules, so the real `ops` (raycast + post
-- build) and the PadPlanner/PadBuilder/StructureBuilder logic are INLINED here (a
-- deliberate mirror, like A's materializeStructureDemo.luau mirrors StructureBuilder).
-- The pure logic is Lune-tested in src/shared (PadPlanner / PadBuilder); this is the
-- visual proof only. PadSpec is the baked cliff_proof from tools/studio/padSites.luau.

local SS = game:GetService("ServerStorage")

local PADSPEC = {
	mountCF = { -60, 274, 105, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	hand = "right",
	footprint = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 },
}
local BLACK = Color3.fromRGB(45, 48, 56)

local function run()
	local demo = workspace:FindFirstChild("PadDemo")
	if demo then
		demo:Destroy()
	end
	demo = Instance.new("Folder")
	demo.Name = "PadDemo"
	demo.Parent = workspace

	local mountCF = CFrame.new(table.unpack(PADSPEC.mountCF)) -- Spec.cframe order == GetComponents order

	-- real ops (mirror of PadBuilder's adapter)
	local function raycastGround(x: number, z: number): number?
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(Vector3.new(x, mountCF.Position.Y + 4, z), Vector3.new(0, -600, 0), rp)
		return hit and hit.Position.Y or nil
	end
	local function buildPost(pos: { number }, height: number)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CastShadow = "PadPost", true, false, false
		p.Size, p.Color, p.Material = Vector3.new(1.2, height, 1.2), BLACK, Enum.Material.Wood
		p.CFrame = CFrame.new(pos[1], pos[2], pos[3])
		p.Parent = demo
	end

	-- mirror PadPlanner.planSupport + PadBuilder.build (see src/shared/*)
	local FP = PADSPEC.footprint
	local PH = 0.6
	local cx = (FP.minX + FP.maxX) / 2
	local layout = {
		{ FP.minX + PH, FP.minZ + PH }, { FP.maxX - PH, FP.minZ + PH },
		{ FP.minX + PH, FP.maxZ - PH }, { FP.maxX - PH, FP.maxZ - PH },
		{ cx, FP.minZ + PH }, { cx, FP.maxZ - PH },
	}
	local built, omitted = 0, 0
	for _, l in layout do
		local top = mountCF * CFrame.new(l[1], 0, l[2])
		local g = raycastGround(top.Position.X, top.Position.Z)
		if g == nil then
			omitted += 1
		else
			local foot = g - 1
			buildPost({ top.Position.X, (top.Position.Y + foot) / 2, top.Position.Z }, top.Position.Y - foot)
			built += 1
		end
	end

	-- mount a teahouse-1story on the pad's mount (right-hand base = no mirror)
	local structure = SS.StructurePrefabs["teahouse-1story"]:Clone()
	structure.Parent = demo
	structure:PivotTo(mountCF)

	return string.format("posts built=%d omitted=%d", built, omitted)
end

return run()
