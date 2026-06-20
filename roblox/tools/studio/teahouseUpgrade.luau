-- ZenDojo TEAHOUSE UPGRADE — run via MCP execute_luau in EDIT mode.
-- Applies the locked teahouse design to a teahouse model (TeahousePrototype, a clone,
-- or any future instance). IDEMPOTENT: every change sets absolute values or rebuilds,
-- so re-running converges. This is the canonical recipe to port into the parameterized
-- Lune teahouse builder (canon village sub-project 2); until then it is the source of
-- truth for the teahouse design.
--
-- Locked design (all in the model's LOCAL frame, via GetPivot):
--   * engawa veranda 8 studs deep, wrapping front(-Z) + right(+X); corner filled
--   * koran (railing) flush to the engawa floor outer edge, newels on the corners
--   * interior PointLights contained + shadowed (no spill above the eaves)
--   * shoji paper glow dimmed 50%
--   * center front bay open as a walk-through doorway (skin + glow + 4 mullions)
--   * chochin lantern hung at the front-right eave corner on a cord up to the hip
--   * hip rafters under all four eave mitres (apex -> eave corner, ~+2 overhang)
--   * black (45,48,56) understructure: recolored deck frame + a 6-post perimeter frame
--     (4 corners + mid of each long side) under a full perimeter-beam rectangle + joists
local TARGET = "TeahousePrototype"

local BLACK = Color3.fromRGB(45, 48, 56)
local WOOD = Enum.Material.Wood

local function upgrade(th)
	local piv = th:GetPivot()
	local function Lp(p)
		return (piv:ToObjectSpace(p.CFrame)).Position
	end

	-- styles (read before any rebuild; fall back to known values)
	local railColor = Color3.fromRGB(74, 55, 38)
	local rafterColor = Color3.fromRGB(92, 68, 46)
	for _, p in th:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "RailCap" or p.Name == "Newel" then
				railColor = p.Color
			elseif p.Name == "RafterTail" then
				rafterColor = p.Color
			end
		end
	end

	-- 1) engawa: absolute geometry (8 deep, corner filled)
	for _, p in th:GetDescendants() do
		if p.Name == "EngawaF" and p:IsA("BasePart") then
			p.Size = Vector3.new(26.4, 0.4, 8.0)
			p.CFrame = piv * CFrame.new(3.8, 107.0, -9.7)
		elseif p.Name == "EngawaS" and p:IsA("BasePart") then
			p.Size = Vector3.new(8.0, 0.4, 16.0)
			p.CFrame = piv * CFrame.new(13.0, 107.0, -1.7)
		end
	end

	-- 2) interior lights: contained + shadowed
	for _, p in th:GetDescendants() do
		if p:IsA("PointLight") then
			local par = p.Parent.Name
			if par == "InteriorGlow" then
				p.Brightness, p.Range, p.Shadows = 1.1, 13, true
			elseif par == "Lantern" then
				p.Brightness, p.Range, p.Shadows = 0.9, 9, true
			end
		end
	end

	-- 3) shoji glow dimmed (absolute) + 4) open center front doorway
	for _, p in th:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "ShojiGlow" then
				p.Color = Color3.fromRGB(127, 103, 70)
			end
			local l = Lp(p)
			local centerFront = l.Z < -4.5 and math.abs(l.X) < 3.0
			if centerFront and (p.Name == "Shoji" or p.Name == "ShojiGlow") and p.Size.Z < p.Size.X then
				p.CanCollide, p.Transparency = false, 1
			elseif centerFront and p.Name == "Mull" then
				p.CanCollide, p.Transparency = false, 1
			end
		end
	end

	-- 5) koran: rebuild flush to engawa outer edge (newel outer corners on the corners)
	for _, p in th:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "RailCap" or p.Name == "RailMid" or p.Name == "Newel" or p.Name == "Baluster") then
			p:Destroy()
		end
	end
	local ko = th:FindFirstChild("Koran")
	if ko then
		ko:Destroy()
	end
	ko = Instance.new("Folder")
	ko.Name = "Koran"
	ko.Parent = th
	local function rail(name, size, lx, ly, lz)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CastShadow = name, true, false, false
		p.Size, p.Color, p.Material = size, railColor, WOOD
		p.CFrame = piv * CFrame.new(lx, ly, lz)
		p.Parent = ko
	end
	local capY, midY, newelY, balY = 109.8, 108.7, 109.0, 108.4
	local zR, xR, xLeft, zFar = -13.4, 16.7, -9.1, 6.0
	local lenF, lenR = xR - xLeft, zFar - zR
	rail("RailCap", Vector3.new(lenF, 0.3, 0.6), (xLeft + xR) / 2, capY, zR)
	rail("RailMid", Vector3.new(lenF, 0.2, 0.2), (xLeft + xR) / 2, midY, zR)
	rail("RailCap", Vector3.new(0.6, 0.3, lenR), xR, capY, (zR + zFar) / 2)
	rail("RailMid", Vector3.new(0.2, 0.2, lenR), xR, midY, (zR + zFar) / 2)
	rail("Newel", Vector3.new(0.6, 3.5, 0.6), xLeft, newelY, zR)
	rail("Newel", Vector3.new(0.6, 3.5, 0.6), xR, newelY, zR)
	rail("Newel", Vector3.new(0.6, 3.5, 0.6), xR, newelY, zFar)
	local function balRun(a, b, fixed, alongX)
		local sp = b - a
		local n = math.max(2, math.floor(sp / 3.6))
		for i = 1, n - 1 do
			local t = a + sp * i / n
			rail("Baluster", Vector3.new(0.2, 2.8, 0.2), alongX and t or fixed, balY, alongX and fixed or t)
		end
	end
	balRun(xLeft, xR, zR, true)
	balRun(zR, zFar, xR, false)

	-- 6) lantern -> front-right eave corner; cord up to the hip; hip rafters on 4 corners
	local lantern = th:FindFirstChild("Lantern", true)
	if lantern then
		local target = Vector3.new(10.8, 112, -7.7)
		local delta = piv:VectorToWorldSpace(target - Lp(lantern))
		for _, p in th:GetDescendants() do
			if p:IsA("BasePart") and (p.Name == "Lantern" or p.Name == "LanCap" or p.Name == "LanRib" or p.Name == "Cord") then
				p.CFrame = p.CFrame + delta
			end
		end
		local cord = th:FindFirstChild("Cord", true)
		if cord then
			local lanTop = 112 + lantern.Size.Y / 2
			cord.Size = Vector3.new(0.08, 115.0 - lanTop, 0.08)
			cord.CFrame = piv * CFrame.new(10.8, (lanTop + 115.0) / 2, -7.7)
		end
	end
	local hips = {
		{ n = "FR", O = Vector3.new(10.8, 115.0, -7.7), I = Vector3.new(0, 121.2, -0.3) },
		{ n = "FL", O = Vector3.new(-10.8, 115.0, -7.7), I = Vector3.new(0, 121.2, -0.3) },
		{ n = "BR", O = Vector3.new(10.8, 115.0, 8.3), I = Vector3.new(0, 121.2, 0.9) },
		{ n = "BL", O = Vector3.new(-10.8, 115.0, 8.3), I = Vector3.new(0, 121.2, 0.9) },
	}
	for _, c in hips do
		local iw = piv:PointToWorldSpace(c.I)
		local ow0 = piv:PointToWorldSpace(c.O)
		local ow = ow0 + (ow0 - iw).Unit * 2.0
		local hip = th:FindFirstChild("HipRafter_" .. c.n) or Instance.new("Part")
		hip.Name = "HipRafter_" .. c.n
		hip.Anchored, hip.CanCollide, hip.CastShadow = true, false, false
		hip.Material, hip.Color = WOOD, rafterColor
		hip.Size = Vector3.new(0.5, 0.5, (ow - iw).Magnitude)
		hip.CFrame = CFrame.lookAt((iw + ow) / 2, ow)
		hip.Parent = th
	end

	-- 7) black understructure: recolor deck frame, strip old support posts, 6-post frame
	for _, p in th:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Girder" or p.Name == "CrossBeam" then
				p.Color, p.Material = BLACK, WOOD
			elseif p.Name == "Post" then
				p:Destroy()
			end
		end
	end
	local sup = th:FindFirstChild("EngawaSupport")
	if sup then
		sup:Destroy()
	end
	sup = Instance.new("Folder")
	sup.Name = "EngawaSupport"
	sup.Parent = th
	local function beam(name, size, lx, ly, lz)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CastShadow = name, true, false, false
		p.Size, p.Color, p.Material = size, BLACK, WOOD
		p.CFrame = piv * CFrame.new(lx, ly, lz)
		p.Parent = sup
	end
	local BY = 106.0
	beam("PerimF", Vector3.new(22.4, 1.6, 1.0), 1.8, BY, -9.7)
	beam("PerimB", Vector3.new(22.4, 1.6, 1.0), 1.8, BY, 6.3)
	beam("PerimL", Vector3.new(1.0, 1.6, 16.0), -9.4, BY, -1.7)
	beam("PerimR", Vector3.new(1.0, 1.6, 16.0), 13.0, BY, -1.7)
	for _, x in { -8, -4, 0, 4, 8, 12 } do
		beam("JoistF", Vector3.new(1.0, 1.6, 5.5), x, BY - 0.05, -6.95)
	end
	for _, z in { -9, -5, -1, 3, 6 } do
		beam("JoistR", Vector3.new(4.0, 1.6, 1.0), 11.0, BY - 0.05, z)
	end
	-- 6 posts: yaw-aligned, outer corners flush to perimeter-beam outer corners, to terrain
	local rc = RaycastParams.new()
	rc.FilterType = Enum.RaycastFilterType.Include
	rc.FilterDescendantsInstances = { workspace.Terrain }
	local posts = { { -9.3, -9.6 }, { 12.9, -9.6 }, { -9.3, 6.2 }, { 12.9, 6.2 }, { 1.8, -9.6 }, { 1.8, 6.2 } }
	for _, c in posts do
		local topW = piv:PointToWorldSpace(Vector3.new(c[1], BY - 0.8, c[2]))
		local h = workspace:Raycast(Vector3.new(topW.X, topW.Y + 4, topW.Z), Vector3.new(0, -600, 0), rc)
		local g = h and (h.Position.Y - 1) or (topW.Y - 20)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CastShadow = "EngawaPost", true, false, false
		p.Size, p.Color, p.Material = Vector3.new(1.2, topW.Y - g, 1.2), BLACK, WOOD
		p.CFrame = CFrame.new(Vector3.new(topW.X, (topW.Y + g) / 2, topW.Z)) * piv.Rotation
		p.Parent = sup
	end
end

local th = workspace:FindFirstChild(TARGET)
assert(th, "no model named " .. TARGET .. " in workspace")
upgrade(th)
return "teahouse upgrade applied to " .. TARGET
