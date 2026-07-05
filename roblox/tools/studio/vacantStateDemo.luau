--!strict
-- Vacant-state visual gate: materialize a VACANT (dormant, shut-up) structure beside a
-- CLAIMED (owner-loadout, lit) one, to confirm the occupancy signal reads. Run via MCP
-- execute_luau (datamodel Edit) or the Studio command bar.
--
-- MCP Studio scripts cannot `require` repo modules, so VacantState.resolve + A's recolor
-- + the dormant applier are INLINED here (a deliberate mirror, like A/B demos). The pure
-- logic is Lune-tested in src/shared (VacantState / StructureCatalog scheme.dormant).
--
-- The dormant (lit=false) applier does the full "shut up" look: dark scheme.dormant recolor
-- + Shoji set OPAQUE (transparency 0, closed) + ShojiGlow off + ChochinSwing removed (no
-- lantern hung — the owner hangs their own on claiming). Claimed (lit=true) keeps the glow
-- and the chochin. resolve() itself only returns {loadout, lit}; these deltas are applier-side.

local SS = game:GetService("ServerStorage")

-- palettes (mirror StructureCatalog: scheme.dormant + scheme.vermilion)
local DORMANT = { timber = { 32, 30, 28 }, wall = { 40, 38, 36 }, roof = { 28, 29, 33 }, cap = { 30, 31, 36 } }
local VERMILION = { timber = { 120, 45, 35 }, wall = { 232, 216, 190 }, roof = { 40, 42, 48 }, cap = { 40, 42, 48 } }

local function recolor(m: Model, pal)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			for _, role in { "timber", "wall", "roof", "cap" } do
				if p:HasTag("Role_" .. role) then
					p.Color = Color3.fromRGB(pal[role][1], pal[role][2], pal[role][3])
				end
			end
		end
	end
end

local function applyClaimed(m: Model)
	recolor(m, VERMILION)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "ShojiGlow" then
			p.Transparency = 0.6 -- lit
		end
	end
end

local function applyVacant(m: Model)
	recolor(m, DORMANT)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "ShojiGlow" then
				p.Transparency = 1 -- glow off
			elseif p.Name == "Shoji" then
				p.Transparency = 0 -- closed opaque panels (incl. the doorway bay)
			end
		end
	end
	local cs = m:FindFirstChild("ChochinSwing", true)
	if cs then
		cs:Destroy() -- no lantern hung on a vacant pad
	end
end

local function run()
	local demo = workspace:FindFirstChild("VacantStateDemo")
	if demo then
		demo:Destroy()
	end
	demo = Instance.new("Folder")
	demo.Name = "VacantStateDemo"
	demo.Parent = workspace

	local function place(apply, x: number)
		local m = SS.StructurePrefabs["teahouse-1story"]:Clone()
		m.Parent = demo
		apply(m)
		m:PivotTo(CFrame.new(x, 300, 120)) -- open sky, clear of terrain
	end
	place(applyVacant, 120)
	place(applyClaimed, 180)
	return "materialized vacant (dormant/shut) + claimed (lit)"
end

return run()
