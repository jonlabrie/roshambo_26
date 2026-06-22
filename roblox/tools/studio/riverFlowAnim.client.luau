--!strict
-- ZenDojo UP-CANYON RIVER — runtime UV-scroll flow (CLIENT / LocalScript). POC.
-- Install under StarterPlayer.StarterPlayerScripts. On Play it: builds the river ribbon
-- from workspace.RiverDraft markers (the editing aid) if present, else a baked fallback
-- path; applies the ZenRiverWater SurfaceAppearance; and scrolls the mesh UVs every frame
-- so the WATER SURFACE ITSELF flows downstream. It hides the static baked RiverRibbon and
-- the draft markers locally so there's no overlap.
--
-- WHY client-side: live EditableMesh edits (per-frame UV scroll) run locally and never need
--   to replicate — each client animates its own copy cheaply.
-- WHY SurfaceAppearance, not the MaterialVariant: materials tile in WORLD space and ignore
--   UVs, so UV scroll can't move them. SurfaceAppearance samples by UV. Same maps as the
--   generated ZenRiverWater variant (ColorMap + NormalMap), so the look matches.
-- See [[roblox-editablemesh-gotchas]] for the normals + local-space build requirements.

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HALF_W = 4.5
local RIPPLE_AMP = 0.6
local RIDE = 0.3
local TILE = 12 -- studs per texture tile down-length (UV V = distance / TILE)
local FLOW_TILES_PER_SEC = 0.25 -- scroll speed (tiles/sec); negative would flow upstream
local UP = Vector3.yAxis

-- Safety net if the RiverDraft markers aren't in the place — the user's hand-dragged path
-- (baked from workspace.RiverDraft, 2026-06-21).
local FALLBACK_CTRL: { Vector3 } = {
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

local function getCTRL(): { Vector3 }
	local draft = Workspace:FindFirstChild("RiverDraft")
	if draft then
		local ms = {}
		for _, m in draft:GetChildren() do
			if m:IsA("BasePart") then
				table.insert(ms, m)
			end
		end
		if #ms >= 2 then
			table.sort(ms, function(a, b)
				return a.Name < b.Name
			end)
			local c = {}
			for _, m in ms do
				table.insert(c, m.Position)
				m.LocalTransparencyModifier = 1 -- hide the marker locally
				for _, g in m:GetChildren() do
					if g:IsA("BillboardGui") then
						g.Enabled = false
					end
				end
			end
			return c
		end
	end
	return FALLBACK_CTRL
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return (p1 * 2) + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p2 * 3 + p3 - p0) * t3
end

local function buildPath(CTRL: { Vector3 }): { Vector3 }
	local PATH, SUBDIV = {}, 6
	for i = 1, #CTRL - 1 do
		local p0 = CTRL[math.max(i - 1, 1)]
		local p1, p2 = CTRL[i], CTRL[i + 1]
		local p3 = CTRL[math.min(i + 2, #CTRL)]
		local last = (i == #CTRL - 1) and SUBDIV or SUBDIV - 1
		for s = 0, last do
			PATH[#PATH + 1] = catmull(p0, p1, p2, p3, s / SUBDIV) * 0.5
		end
	end
	return PATH
end

local CTRL = getCTRL()
local PATH = buildPath(CTRL)

-- centroid first (build verts in LOCAL space — CreateMeshPartAsync doesn't recenter)
local mn, mx = PATH[1], PATH[1]
for _, c in PATH do
	mn = Vector3.new(math.min(mn.X, c.X), math.min(mn.Y, c.Y), math.min(mn.Z, c.Z))
	mx = Vector3.new(math.max(mx.X, c.X), math.max(mx.Y, c.Y), math.max(mx.Z, c.Z))
end
local center = (mn + mx) * 0.5

local em = AssetService:CreateEditableMesh()
local rows, uvRecs, nrmRows, runLen = {}, {}, {}, 0
for i, c in PATH do
	if i > 1 then
		runLen += (c - PATH[i - 1]).Magnitude
	end
	local fwd = (i < #PATH) and (PATH[i + 1] - c) or (c - PATH[i - 1])
	fwd = (fwd.Magnitude > 1e-4) and fwd.Unit or Vector3.new(1, 0, 0)
	local right = fwd:Cross(UP)
	right = (right.Magnitude > 1e-4) and right.Unit or Vector3.new(0, 0, 1)
	local cc = (c - center) + UP * (math.sin(runLen * 0.5) * RIPPLE_AMP)
	rows[i] = { em:AddVertex(cc - right * HALF_W), em:AddVertex(cc + right * HALF_W) }
	local v = runLen / TILE
	local idL, idR = em:AddUV(Vector2.new(0, v)), em:AddUV(Vector2.new(1, v))
	rows[i].uvL, rows[i].uvR = idL, idR
	uvRecs[#uvRecs + 1] = { id = idL, u = 0, v = v }
	uvRecs[#uvRecs + 1] = { id = idR, u = 1, v = v }
	local nrm = right:Cross(fwd)
	if nrm.Y < 0 then
		nrm = -nrm
	end
	nrmRows[i] = em:AddNormal(nrm.Unit)
end
for i = 1, #PATH - 1 do
	local a, b = rows[i], rows[i + 1]
	local na, nb = nrmRows[i], nrmRows[i + 1]
	local f1 = em:AddTriangle(a[1], a[2], b[2])
	em:SetFaceUVs(f1, { a.uvL, a.uvR, b.uvR })
	em:SetFaceNormals(f1, { na, na, nb })
	local f2 = em:AddTriangle(a[1], b[2], b[1])
	em:SetFaceUVs(f2, { a.uvL, b.uvR, b.uvL })
	em:SetFaceNormals(f2, { na, nb, nb })
end

local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
	CollisionFidelity = Enum.CollisionFidelity.Box,
})
mp.Name = "RiverRibbonAnim"
mp.Anchored = true
mp.CanCollide = false
-- NOTE: DoubleSided can't be written from a runtime script ("lacking capability Plugin"),
-- so it's omitted here; the ribbon's normals face up, which is the player-facing side.
mp.Material = Enum.Material.SmoothPlastic
mp.Color = Color3.fromRGB(235, 245, 248)
mp.Transparency = 0.12
mp.Parent = Workspace
mp:PivotTo(CFrame.new(center + Vector3.new(0, RIDE, 0)))

-- Appearance: runtime scripts CANNOT write SurfaceAppearance.ColorMap/NormalMap ("lacking
-- capability Plugin"), but they CAN clone an instance that already has them. So we author
-- the SurfaceAppearance in Edit on the baked RiverRibbon and clone it here.
local stage = Workspace:FindFirstChild("RoshamboStage")
local pocModel = stage and stage:FindFirstChild("UpcanyonRiverPOC")
local baked = pocModel and pocModel:FindFirstChild("RiverRibbon")
local srcSA = baked and baked:FindFirstChildOfClass("SurfaceAppearance")
if srcSA then
	local sa = srcSA:Clone()
	sa.Parent = mp
end

-- hide the static baked ribbon locally so the animated one isn't doubled
if baked and baked:IsA("BasePart") then
	baked.LocalTransparencyModifier = 1
end

-- scroll the UVs every frame. scroll wraps at 1.0 (the texture period in UV) so the jump is
-- invisible, and relative V spacing between verts is preserved (all shift by the same amount).
local scroll = 0
RunService.RenderStepped:Connect(function(dt)
	scroll = (scroll + FLOW_TILES_PER_SEC * dt) % 1
	for _, rec in uvRecs do
		em:SetUV(rec.id, Vector2.new(rec.u, rec.v - scroll))
	end
end)
