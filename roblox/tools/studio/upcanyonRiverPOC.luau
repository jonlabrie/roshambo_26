--!strict
-- ZenDojo UP-CANYON RIVER — PATH B PROOF OF CONCEPT (MCP execute_luau, EDIT mode).
-- Goal: evaluate whether a PROCEDURAL swept ribbon mesh (built in-engine via EditableMesh,
-- no Blender/FBX/import round-trip) reads as a believable rushing-rapids surface — so we can
-- decide between Path A (Blender hero mesh, user-authored) and Path B (procedural, mine).
--
-- One contained reach only: the lower braided run from the Step150 pool lip down to the
-- ClearingInfall head (x-168..-83, y151->133, ~90 studs, ~11 deg with a steeper LowerStep
-- sub-drop). Coordinates lifted from upcanyonFalls.luau's FALLS table so the ribbon sits in
-- the real bed.
--
-- WHAT THIS POC INCLUDES (all the SCRIPTED parts of the pipeline — "mine"):
--   1. EditableMesh ribbon  : continuous water body swept along the bed centerline, gentle
--                             vertical ripple, double-sided, Glass + tint. (Blender-free.)
--   2. Along-flow beams      : thin faint Beams threaded down the centerline, native
--                             TextureSpeed scroll = surface current (no per-frame script).
--   3. Whitewater drop beam  : the proven dual-beam fall recipe over the LowerStep sub-drop.
--   4. Placeholder boulders  : Part spheres (Rock) IN the channel so water has something to
--                             break around. *** These stand in for USER-SUPPLIED rock MESH
--                             assets — that is the one piece Path B still needs from you. ***
--   5. Foam emitters         : reused FOAM particle at each boulder's downstream base.
--
-- ASSET SLOTS still owned by the user (left as TODO, POC runs without them):
--   - SurfaceAppearance on the ribbon (PBR water diffuse+normal) for real reflections/depth.
--   - Rock MESH assets to replace the placeholder boulder spheres.
--   - Looped rushing-water audio for Sound emitters (Step 4 "Sound Emitters").
--
-- Re-runnable: destroys workspace.RoshamboStage.UpcanyonRiverPOC first. Non-destructive to
-- terrain and to the existing UpcanyonVFX falls.

local AssetService = game:GetService("AssetService")
local stage = workspace:WaitForChild("RoshamboStage")

local WTEX = "rbxassetid://16808804567" -- water/cascade texture (proven in upcanyonFalls)
local FOAM = "rbxassetid://16808075391" -- foam mist texture (proven in upcanyonFalls)
local WHITE = Color3.new(1, 1, 1)
local WATER_TINT = Color3.fromRGB(150, 196, 205)
local FOAM_COLOR = Color3.fromRGB(225, 232, 236)

-- ---- reset --------------------------------------------------------------
local old = stage:FindFirstChild("UpcanyonRiverPOC")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "UpcanyonRiverPOC"
root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
root.Parent = stage

-- ---- reach centerline (world coords, from the real bed) ------------------
-- If the user has hand-placed markers under workspace.RiverDraft (via
-- riverDraftMarkers.luau), the path + per-point elevation come from THOSE marker
-- positions (sorted by name: River_01, River_02, ...). Otherwise fall back to the
-- hardcoded seed below. This is how hand-editing the route/heights flows back in.
-- User's hand-dragged path (baked from workspace.RiverDraft, 2026-06-21).
local FALLBACK_CTRL = {
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

local CTRL: { Vector3 }
local CTRL_SOURCE: string
local draft = workspace:FindFirstChild("RiverDraft")
if draft and #draft:GetChildren() >= 2 then
	local markers = {}
	for _, m in draft:GetChildren() do
		if m:IsA("BasePart") then
			markers[#markers + 1] = m
		end
	end
	table.sort(markers, function(a, b)
		return a.Name < b.Name
	end)
	CTRL = {}
	for _, m in markers do
		CTRL[#CTRL + 1] = m.Position
	end
	CTRL_SOURCE = ("RiverDraft (%d markers)"):format(#CTRL)
else
	CTRL = FALLBACK_CTRL
	CTRL_SOURCE = "hardcoded fallback"
end

-- Catmull-Rom subdivision for a smooth, dense centerline
local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return (p1 * 2)
		+ (p2 - p0) * t
		+ (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2
		+ (p1 * 3 - p2 * 3 + p3 - p0) * t3 * 1
end
local PATH: { Vector3 } = {}
local SUBDIV = 6
for i = 1, #CTRL - 1 do
	local p0 = CTRL[math.max(i - 1, 1)]
	local p1, p2 = CTRL[i], CTRL[i + 1]
	local p3 = CTRL[math.min(i + 2, #CTRL)]
	local last = (i == #CTRL - 1) and SUBDIV or SUBDIV - 1
	for s = 0, last do
		PATH[#PATH + 1] = catmull(p0, p1, p2, p3, s / SUBDIV) * 0.5
	end
end

local HALF_W = 4.5 -- ribbon half-width (~9 stud channel)
local RIPPLE_AMP = 0.6
local RIDE = 0.3 -- GLOBAL lift of the whole ribbon (studs). Per-point height = marker Y
-- (drag markers in RiverDraft for local control); RIDE just nudges off z-fighting.
local UP = Vector3.new(0, 1, 0)

-- ---- build the ribbon via EditableMesh ----------------------------------
-- TWO non-obvious EditableMesh requirements learned the hard way (see git history):
--   1. Faces WITHOUT normals do not render at all — every face needs SetFaceNormals.
--   2. CreateMeshPartAsync does NOT recenter geometry onto the part origin in this build.
--      So build verts in LOCAL space (subtract the centroid), then PivotTo(centroid).
--      Building at world coords + PivotTo(centroid) double-offsets the mesh off-screen.
local okMesh, meshResult = pcall(function()
	-- centroid of the reach FIRST, so verts can be built in local space
	local mn, mx = PATH[1], PATH[1]
	for _, c in PATH do
		mn = Vector3.new(math.min(mn.X, c.X), math.min(mn.Y, c.Y), math.min(mn.Z, c.Z))
		mx = Vector3.new(math.max(mx.X, c.X), math.max(mx.Y, c.Y), math.max(mx.Z, c.Z))
	end
	local center = (mn + mx) * 0.5

	local em = AssetService:CreateEditableMesh()

	-- cross-sections: 2 verts (L,R) per path point, with along-length ripple
	local rows = {} -- rows[i] = {vL, vR} vertex ids
	local uvRows = {} -- uvRows[i] = {uvL, uvR}
	local nrmRows = {} -- nrmRows[i] = normalId (surface normal at this section)
	local runLen = 0
	for i, c in PATH do
		if i > 1 then
			runLen += (c - PATH[i - 1]).Magnitude
		end
		local fwd
		if i < #PATH then
			fwd = (PATH[i + 1] - c)
		else
			fwd = (c - PATH[i - 1])
		end
		fwd = (fwd.Magnitude > 1e-4) and fwd.Unit or Vector3.new(1, 0, 0)
		local right = fwd:Cross(UP)
		right = (right.Magnitude > 1e-4) and right.Unit or Vector3.new(0, 0, 1)
		local ripple = math.sin(runLen * 0.5) * RIPPLE_AMP
		local cc = (c - center) + UP * ripple -- LOCAL space (see note above)
		local pL = cc - right * HALF_W
		local pR = cc + right * HALF_W
		rows[i] = { em:AddVertex(pL), em:AddVertex(pR) }
		local v = runLen / 12 -- tile every ~12 studs down-length
		uvRows[i] = { em:AddUV(Vector2.new(0, v)), em:AddUV(Vector2.new(1, v)) }
		-- surface normal: perpendicular to the strip, forced to point up
		local nrm = right:Cross(fwd)
		if nrm.Y < 0 then
			nrm = -nrm
		end
		nrmRows[i] = em:AddNormal(nrm.Unit)
	end

	for i = 1, #PATH - 1 do
		local a, b = rows[i], rows[i + 1]
		local ua, ub = uvRows[i], uvRows[i + 1]
		local na, nb = nrmRows[i], nrmRows[i + 1]
		-- tri 1: aL, aR, bR  /  tri 2: aL, bR, bL  (wound for upward normal)
		-- NOTE: EditableMesh faces WITHOUT normals do not render — normals are required.
		local f1 = em:AddTriangle(a[1], a[2], b[2])
		em:SetFaceUVs(f1, { ua[1], ua[2], ub[2] })
		em:SetFaceNormals(f1, { na, na, nb })
		local f2 = em:AddTriangle(a[1], b[2], b[1])
		em:SetFaceUVs(f2, { ua[1], ub[2], ub[1] })
		em:SetFaceNormals(f2, { na, nb, nb })
	end

	local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
	})
	mp.Name = "RiverRibbon"
	mp.Anchored = true
	mp.CanCollide = false
	mp.DoubleSided = true
	mp.Material = Enum.Material.Glass
	mp.Color = WATER_TINT
	mp.Transparency = 0.25
	mp.Reflectance = 0.14
	mp.Parent = root
	mp:PivotTo(CFrame.new(center + Vector3.new(0, RIDE, 0)))
	-- TODO(user): drop a SurfaceAppearance here (PBR water diffuse+normal) for real depth.
	return mp
end)

-- ---- along-flow current beams (native TextureSpeed scroll) ---------------
-- A Beam's WIDTH extends along its attachment's UP vector (and FaceCamera=false keeps
-- that orientation fixed). So to make a beam lie FLAT on the water, the attachment's up
-- must point HORIZONTALLY cross-stream — NOT world +Y (that makes the beam stand up as a
-- vertical fin perpendicular to the flow). Build the frame with Right=flow, Up=cross.
local function attAt(p: Vector3, nm: string, flowDir: Vector3?): Attachment
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.Transparency = true, false, 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	if flowDir and flowDir.Magnitude > 1e-4 then
		local lengthDir = flowDir.Unit
		local cross = lengthDir:Cross(UP)
		cross = (cross.Magnitude > 1e-3) and cross.Unit or Vector3.new(0, 0, 1)
		part.CFrame = CFrame.fromMatrix(p, lengthDir, cross) -- Right=flow, Up=cross => flat
	else
		part.CFrame = CFrame.new(p)
	end
	part.Name = nm
	part.Parent = root
	local a = Instance.new("Attachment")
	a.Parent = part
	return a
end

local FLOW_TR = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(0.5, 0.35),
	NumberSequenceKeypoint.new(1, 0.55),
})
local prevAtt: Attachment? = nil
for i, c in CTRL do
	local fwd = (i < #CTRL) and (CTRL[i + 1] - c) or (c - CTRL[i - 1])
	local a = attAt(c + UP * 0.4, "Flow" .. i, fwd)
	if prevAtt then
		local b = Instance.new("Beam")
		b.Name = "FlowBeam" .. i
		b.Attachment0, b.Attachment1 = prevAtt, a
		b.Texture, b.TextureMode = WTEX, Enum.TextureMode.Wrap
		b.TextureLength, b.TextureSpeed = 8, 0.6
		b.Width0, b.Width1 = HALF_W * 1.3, HALF_W * 1.3
		b.Segments, b.FaceCamera = 6, false
		b.Color, b.LightEmission, b.LightInfluence = ColorSequence.new(WHITE), 0.15, 0.2
		b.Transparency = FLOW_TR
		b.Parent = prevAtt.Parent
	end
	prevAtt = a
end

-- ---- whitewater drop beam over the LowerStep sub-drop (proven recipe) ----
do
	local a0 = attAt(Vector3.new(-132, 148, -3), "DropTop")
	local a1 = attAt(Vector3.new(-126, 143, -3), "DropBot")
	local function dbeam(nm: string, len: number, spd: number, w0: number, w1: number, tr: number)
		local b = Instance.new("Beam")
		b.Name, b.Attachment0, b.Attachment1 = nm, a0, a1
		b.Texture, b.TextureMode, b.TextureLength, b.TextureSpeed = WTEX, Enum.TextureMode.Stretch, len, spd
		b.Width0, b.Width1, b.CurveSize0, b.CurveSize1 = w0, w1, 1, -0.5
		b.Segments, b.FaceCamera = 10, true
		b.Color, b.LightEmission, b.LightInfluence = ColorSequence.new(WHITE), 0.2, 0
		b.Transparency = NumberSequence.new(tr)
		b.Parent = a0.Parent
	end
	dbeam("Cascade", 1, 0.55, 5, 7, 0.1)
	dbeam("CascadeSlow", 2, 0.35, 7, 9.8, 0.4)
end

-- ---- placeholder boulders + foam (USER replaces spheres w/ rock meshes) --
-- {x,y,z, radius}
local BOULDERS = {
	{ -149, 149.5, -4.5, 3.5 },
	{ -128, 145, -1.5, 4.0 },
	{ -104, 140, -6, 3.0 },
}
for i, bd in BOULDERS do
	local x, y, z, r = bd[1], bd[2], bd[3], bd[4]
	local b = Instance.new("Part")
	b.Name = "BoulderPH" .. i -- PH = placeholder (swap for rock MeshPart)
	b.Shape = Enum.PartType.Ball
	b.Anchored, b.CanCollide = true, true
	b.Size = Vector3.new(r * 2, r * 2, r * 2)
	b.Position = Vector3.new(x, y, z)
	b.Material = Enum.Material.Rock
	b.Color = Color3.fromRGB(78, 82, 80)
	b.Parent = root

	-- foam at the downstream (toward ClearingInfall, ~ +x/-z) base of the boulder
	local mp = Instance.new("Part")
	mp.Name = "BoulderFoam" .. i
	mp.Anchored, mp.CanCollide, mp.Transparency = true, false, 1
	mp.Size = Vector3.new(1, 1, 1)
	mp.CFrame = CFrame.new(x + r * 0.8, y - r * 0.4, z - r * 0.4)
	mp.Parent = root
	local ma = Instance.new("Attachment")
	ma.Parent = mp
	local e = Instance.new("ParticleEmitter")
	e.Color, e.Texture = ColorSequence.new(FOAM_COLOR), FOAM
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size, e.Lifetime, e.Rate = NumberSequence.new(r * 1.4), NumberRange.new(1.6, 3.2), 14
	e.Speed, e.SpreadAngle, e.Acceleration = NumberRange.new(1, 3), Vector2.new(45, 45), Vector3.new(0, 1.5, 0)
	e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-10, 10)
	e.Parent = ma
end

-- TODO(user): looped rushing-water Sound emitters along the reach (need audio asset id).

if not okMesh then
	return "POC PARTIAL: beams+boulders+foam built, but EditableMesh ribbon FAILED -> "
		.. tostring(meshResult)
end
return ("UpcanyonRiverPOC [path=%s]: ribbon(%s) + %d flow beams + drop beam + %d boulders/foam built")
	:format(CTRL_SOURCE, tostring(meshResult), #CTRL - 1, #BOULDERS)
