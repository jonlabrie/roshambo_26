# ZenDojo Path Retaining Walls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add fitted dry-stone (ishigaki) retaining walls to the path stretches whose downhill edge floats above grade — selectively, tuned for a tight fitted look (fixing the earlier gappy prototype).

**Architecture:** Ad-hoc Studio geometry (like the paths themselves), built via `mcp__Roblox_Studio__execute_luau`. A `SpanFinder` pass lists the contiguous floating spans per path; an `IshigakiFace` generator builds one battered Voronoi face mesh per span and publishes it into `Workspace.RetainingWalls`. One prototype span is built and visually approved before batching the rest.

**Tech Stack:** Roblox Studio, Luau via execute_luau, EditableMesh, `AssetService:CreateAssetAsync`.

## Global Constraints

- **Source spec:** `docs/superpowers/specs/2026-06-27-zendojo-retaining-walls-design.md`.
- **Selective:** walls only on contiguous spans where the downhill-edge float **> 2.5** studs; taper height to ~0 at each span's ends.
- **Fitted-stone params (the fix):** inset **0.03**, dome **0.15**, min-sep **0.7** with size var **×0.6–1.4**, 1-pass Chaikin, smooth center-out normals (center − N·0.75), colour **116/121/111 ±6**, Material **Rock**, DoubleSided.
- **Battered geometry:** top edge at **±3.2** from path centerline (downhill side), base flared to **±3.7** and down to **terrain raycast − 0.4**; wall **top Y = timber.Position.Y + 0.6** (= grade − 0.2; analytic — never raycast a Box-collision mesh for height); back-extruded ~0.6.
- **Downhill side** is whichever cross-edge (`±RightVector·3.2`) has the lower terrain.
- **Paths & prefixes:** `PathSteps`/`Timber_`, `PathExtension`/`ExtTimber_`, `DescentPath`/`DescTimber_`; half-width **3.2**.
- **Lives** in `Workspace.RetainingWalls` (Model), published meshes, ad-hoc (NOT the Rojo pipeline). Record asset IDs in the spec's as-built. Terrain raycasts are fine; Box-collision mesh raycasts are not (return the bbox lid).
- **No lune tests** — these are Studio procedures; "verification" = inspecting the script's printed output + user visual review. **One attempt per visual change, then stop** (`stop-and-ask-after-each-attempt`).

---

### Task 1: SpanFinder — list the floating spans

**Files:** none (Studio query via execute_luau).

**Interfaces:**
- Produces (printed, for the implementer to read): per path, the ordered floating spans — each a contiguous run of timber indices with downhill-edge float > 2.5 and the downhill side sign (−1 = `−RightVector` side, +1 = `+RightVector`).

- [ ] **Step 1: Run the span finder** (execute_luau, datamodel Edit)

```lua
local ws = workspace
local function terr(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { ws.Terrain }
	local r = ws:Raycast(Vector3.new(x, 360, z), Vector3.new(0, -460, 0), rp)
	return r and r.Position.Y or nil
end
local HW, THRESH = 3.2, 2.5
local function spansFor(modelName, prefix)
	local m = ws:FindFirstChild(modelName)
	if not m then return modelName .. ": missing" end
	local ts = {}
	for _, c in m:GetChildren() do
		local i = tonumber((c.Name :: string):match("^" .. prefix .. "_(%d+)$"))
		if i then table.insert(ts, { i = i, part = c }) end
	end
	table.sort(ts, function(a, b) return a.i < b.i end)
	local spans, cur = {}, nil
	for _, t in ts do
		local p, r = t.part.Position, t.part.CFrame.RightVector
		r = Vector3.new(r.X, 0, r.Z).Unit
		local yPlus, yMinus = terr(p.X + r.X * HW, p.Z + r.Z * HW), terr(p.X - r.X * HW, p.Z - r.Z * HW)
		local fPlus = yPlus and (p.Y - yPlus) or 0
		local fMinus = yMinus and (p.Y - yMinus) or 0
		local sign = (fMinus >= fPlus) and -1 or 1 -- downhill side
		local float = math.max(fPlus, fMinus)
		if float > THRESH then
			if cur and cur.sign == sign and t.i == cur.last + 1 then
				cur.last = t.i
			else
				cur = { first = t.i, last = t.i, sign = sign }
				table.insert(spans, cur)
			end
		else
			cur = nil
		end
	end
	local out = {}
	for _, s in spans do out[#out + 1] = string.format("[%d..%d side=%d]", s.first, s.last, s.sign) end
	return string.format("%s (%s): %d spans %s", modelName, prefix, #spans, table.concat(out, " "))
end
return table.concat({
	spansFor("PathSteps", "Timber"),
	spansFor("PathExtension", "ExtTimber"),
	spansFor("DescentPath", "DescTimber"),
}, "\n")
```

Expected: a per-path list of spans, e.g. `PathSteps (Timber): N spans [a..b side=-1] ...`.

- [ ] **Step 2: Record the spans** — note the printed span list; it's the work-list for Tasks 2–3. Pick one mid-length upper-run span as the **prototype** (Task 2).

---

### Task 2: IshigakiFace generator + prototype one span

**Files:** none (Studio mesh build + publish via execute_luau); creates `Workspace.RetainingWalls`.

**Interfaces:**
- Consumes: a span `{model, prefix, first, last, sign}` from Task 1.
- Produces: `Workspace.RetainingWalls.Wall_<model>_<first>_<last>` — a published MeshPart (battered fitted-stone face); the generator function reused verbatim in Task 3.

- [ ] **Step 1: Build + publish the prototype span** (execute_luau, Edit). Set `SPAN` to the chosen prototype.

```lua
local ws = workspace
local AssetService = game:GetService("AssetService")
local SPAN = { model = "PathSteps", prefix = "Timber", first = 2, last = 6, sign = -1 } -- set to a real span from Task 1

local HW_TOP, HW_BASE, BACK = 3.2, 3.7, 0.6
local INSET, DOME, MINSEP = 0.03, 0.15, 0.7
local TOPDROP, BASEEMBED = 0.2, 0.4 -- wall top = timberY+0.6 (grade-0.2); base = terrain-0.4
local COL = Color3.fromRGB(116, 121, 111)
local rng = Random.new(SPAN.first * 1000 + SPAN.last)

local function terr(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { ws.Terrain }
	local r = ws:Raycast(Vector3.new(x, 360, z), Vector3.new(0, -460, 0), rp)
	return r and r.Position.Y or nil
end

-- ordered timbers in the span -> nodes (top edge, base edge, outward normal, arclength)
local m = ws[SPAN.model]
local nodes, u, prevTop = {}, 0, nil
for i = SPAN.first, SPAN.last do
	local t = m:FindFirstChild(SPAN.prefix .. "_" .. i)
	local p, r = t.Position, t.CFrame.RightVector
	r = Vector3.new(r.X, 0, r.Z).Unit
	local outward = (r * SPAN.sign) -- downhill side
	local topY = p.Y + 0.6 -- grade - 0.2
	local topP = Vector3.new(p.X + outward.X * HW_TOP, topY, p.Z + outward.Z * HW_TOP)
	local bx, bz = p.X + outward.X * HW_BASE, p.Z + outward.Z * HW_BASE
	local baseP = Vector3.new(bx, (terr(bx, bz) or (topY - 4)) - BASEEMBED, bz)
	if prevTop then u = u + (Vector3.new(topP.X, 0, topP.Z) - Vector3.new(prevTop.X, 0, prevTop.Z)).Magnitude end
	prevTop = topP
	table.insert(nodes, { top = topP, base = baseP, N = Vector3.new(outward.X, 0, outward.Z).Unit, u = u })
end
local L = nodes[#nodes].u
-- taper height to ~0 over the first/last TAPER studs
local TAPER = 3.0
local function sample(uu)
	uu = math.clamp(uu, 0, L)
	for k = 1, #nodes - 1 do
		local a, b = nodes[k], nodes[k + 1]
		if uu <= b.u or k == #nodes - 1 then
			local f = (b.u > a.u) and (uu - a.u) / (b.u - a.u) or 0
			local top = a.top:Lerp(b.top, f)
			local base = a.base:Lerp(b.base, f)
			local N = a.N:Lerp(b.N, f).Unit
			-- taper: raise base toward top near the ends (zero height at the very ends)
			local edge = math.min(uu, L - uu)
			local hk = math.clamp(edge / TAPER, 0, 1)
			base = base:Lerp(top, 1 - hk)
			return top, base, N
		end
	end
end
local Hsum = 0
for _, nd in nodes do Hsum = Hsum + (nd.top - nd.base).Magnitude end
local Hrep = math.max(Hsum / #nodes, 0.5)

-- Voronoi seeds in (u, v=height studs)
local PAD = 1.0
local seeds = {}
local tries = math.ceil((L + 2 * PAD) * (Hrep + 2 * PAD) / (MINSEP * MINSEP) * 1.5)
for _ = 1, tries do
	local su, sv = rng:NextNumber(-PAD, L + PAD), rng:NextNumber(-PAD, Hrep + PAD)
	local ok = true
	for _, s in seeds do if (s.u - su) ^ 2 + (s.v - sv) ^ 2 < MINSEP * MINSEP then ok = false break end end
	if ok then table.insert(seeds, { u = su, v = sv }) end
end
local function clip(poly, S, O)
	local dx, dv = S.u - O.u, S.v - O.v
	local mx, mv = (S.u + O.u) / 2, (S.v + O.v) / 2
	local function inside(p) return (p.u - mx) * dx + (p.v - mv) * dv >= 0 end
	local function isect(a, b)
		local da = (a.u - mx) * dx + (a.v - mv) * dv
		local db = (b.u - mx) * dx + (b.v - mv) * dv
		local t = da / (da - db)
		return { u = a.u + (b.u - a.u) * t, v = a.v + (b.v - a.v) * t }
	end
	local out = {}
	for i = 1, #poly do
		local a, b = poly[i], poly[(i % #poly) + 1]
		local ina, inb = inside(a), inside(b)
		if ina then table.insert(out, a) end
		if ina ~= inb then table.insert(out, isect(a, b)) end
	end
	return out
end
local function centroid(poly)
	local cu, cv = 0, 0
	for _, p in poly do cu = cu + p.u; cv = cv + p.v end
	return { u = cu / #poly, v = cv / #poly }
end

local em = AssetService:CreateEditableMesh()
local function face3(uu, vv, push)
	local top, base, N = sample(uu)
	local H = (top - base).Magnitude
	local w = H > 0 and math.clamp(vv / H, 0, 1) or 0
	local fp = base:Lerp(top, w)
	return fp + N * push, N, fp
end
local R0 = { { u = -PAD, v = -PAD }, { u = L + PAD, v = -PAD }, { u = L + PAD, v = Hrep + PAD }, { u = -PAD, v = Hrep + PAD } }
local built = 0
for _, S in seeds do
	local poly = R0
	for _, O in seeds do
		if O ~= S and (S.u - O.u) ^ 2 + (S.v - O.v) ^ 2 < (3 * MINSEP) ^ 2 then poly = clip(poly, S, O) end
		if #poly < 3 then break end
	end
	local c = #poly >= 3 and centroid(poly) or nil
	if c and c.u >= 0 and c.u <= L and c.v >= 0 and c.v <= Hrep then
		local ins = {}
		for _, p in poly do
			local du, dv = c.u - p.u, c.v - p.v
			local mlen = math.sqrt(du * du + dv * dv)
			if mlen > 1e-4 then table.insert(ins, { u = p.u + du / mlen * INSET, v = p.v + dv / mlen * INSET }) end
		end
		if #ins >= 3 then
			local ck = {}
			for i = 1, #ins do
				local a, b = ins[i], ins[(i % #ins) + 1]
				table.insert(ck, { u = 0.75 * a.u + 0.25 * b.u, v = 0.75 * a.v + 0.25 * b.v })
				table.insert(ck, { u = 0.25 * a.u + 0.75 * b.u, v = 0.25 * a.v + 0.75 * b.v })
			end
			if #ck >= 3 then
				local domeH = DOME * rng:NextNumber(0.6, 1.4)
				local _, Nc, faceCtr = face3(c.u, c.v, 0)
				local sphereC = faceCtr - Nc * 0.75
				local col = Color3.new(
					math.clamp(COL.R + (rng:NextNumber() - 0.5) * 12 / 255, 0, 1),
					math.clamp(COL.G + (rng:NextNumber() - 0.5) * 12 / 255, 0, 1),
					math.clamp(COL.B + (rng:NextNumber() - 0.5) * 12 / 255, 0, 1)
				)
				local cid = em:AddColor(col, 1)
				local function ring(scale, push)
					local ids = {}
					for _, p in ck do
						local pos = select(1, face3(c.u + (p.u - c.u) * scale, c.v + (p.v - c.v) * scale, push))
						ids[#ids + 1] = { id = em:AddVertex(pos), pos = pos }
					end
					return ids
				end
				local outer = ring(1.0, 0.0)
				local mid = ring(0.55, domeH * 0.8)
				local apexPos = select(1, face3(c.u, c.v, domeH))
				local apex = em:AddVertex(apexPos)
				local function nrm(pos) return (pos - sphereC).Unit end
				local function addTri(a, b, d)
					local f = em:AddTriangle(a.id, b.id, d.id)
					em:SetFaceNormals(f, { em:AddNormal(nrm(a.pos)), em:AddNormal(nrm(b.pos)), em:AddNormal(nrm(d.pos)) })
					em:SetFaceColors(f, { cid, cid, cid })
				end
				local apexN = { id = apex, pos = apexPos }
				local n = #outer
				for i = 1, n do
					local j = (i % n) + 1
					addTri(outer[i], outer[j], mid[j]); addTri(outer[i], mid[j], mid[i]); addTri(mid[i], mid[j], apexN)
				end
				built += 1
			end
		end
	end
end

local res, assetId = AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = "ZenIshigaki", Description = "path retaining wall" })
if res ~= Enum.CreateAssetResult.Success then return "PUBLISH FAILED: " .. tostring(res) end
local parent = ws:FindFirstChild("RetainingWalls") or Instance.new("Model")
parent.Name = "RetainingWalls"; parent.Parent = ws
local mp = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. assetId))
mp.Name = string.format("Wall_%s_%d_%d", SPAN.model, SPAN.first, SPAN.last)
mp.Material = Enum.Material.Rock; mp.Color = Color3.new(1, 1, 1); mp.DoubleSided = true
mp.Anchored = true; mp.CanCollide = false; mp.CollisionFidelity = Enum.CollisionFidelity.Box
mp.CFrame = CFrame.new()
mp:SetAttribute("PublishedAsset", "rbxassetid://" .. assetId)
mp.Parent = parent
return string.format("%s: %d stones, L=%.1f Hrep=%.1f, published rbxassetid://%d", mp.Name, built, L, Hrep, assetId)
```

- [ ] **Step 2: VISUAL REVIEW (stop for user)** — does the face read as **fitted dry-stone** (tight joints, low relief), batter sitting against the floating edge, tapering into the slope at the ends? Tune `INSET` / `DOME` / `MINSEP` and re-run on the same span until approved. **Lock the approved params** for batching. Stop until approved.

---

### Task 3: Batch the remaining spans

**Files:** none (Studio); adds published MeshParts to `Workspace.RetainingWalls`.

**Interfaces:**
- Consumes: the Task 1 span list (minus the prototype) + the Task 2 generator with the **approved** params.

- [ ] **Step 1: Build + publish each remaining span** — run the Task 2 generator (with the locked params) once per remaining span, setting `SPAN` to each entry from Task 1. (Wrap the generator in a loop over a `SPANS` list, or run per-span; one published `Wall_<model>_<first>_<last>` MeshPart each.) After each, glance that it placed; if a span errors (e.g., no terrain hit), log and skip it.

- [ ] **Step 2: VISUAL REVIEW (stop for user)** — walk all walled stretches: consistent fitted look across spans, each tapering cleanly, no gaps where a wall should be, none floating proud of the path edge. Iterate any span that reads off.

---

### Task 4: Record as-built + commit

**Files:**
- Modify: `docs/superpowers/specs/2026-06-27-zendojo-retaining-walls-design.md`

- [ ] **Step 1: Record** — append an "As-built" section: the final params (inset/dome/min-sep), the span list actually walled per path, and each published `Wall_*` asset id, plus `Workspace.RetainingWalls`. Update the `zendojo-fw11-switchback-deck` memory's deferred list (retaining walls now done).

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-06-27-zendojo-retaining-walls-design.md
git commit -m "docs(roblox): retaining walls — record as-built (RetainingWalls + asset ids)"
```

- [ ] **Step 3: Remind** the user to **save the place** (the `RetainingWalls` geometry is ad-hoc, persists via the saved place + published assets).

---

## Self-Review

**1. Spec coverage:**
- Selective spans >2.5, tapered ends → Task 1 (find) + Task 2 taper. ✓
- Fitted-stone fix (inset 0.03 / dome 0.15 / size var) → Task 2 Global Constraints + generator. ✓
- Battered geometry (±3.2→±3.7, top = timberY+0.6, base = terrain−0.4, back-extrude) → Task 2 generator. ✓
- Downhill-side detection → Task 1 sign + Task 2 outward. ✓
- Prototype-first then batch → Tasks 2 → 3. ✓
- Lives in `Workspace.RetainingWalls`, published, ad-hoc; record asset ids → Task 2 parent + Task 4. ✓
- Out of scope (bridges, capstones, pipelining) → not planned. ✓

**2. Placeholder scan:** `SPAN`/`SPANS` are real inputs filled from Task 1's output (not placeholders); all code steps carry complete, runnable code. No TBDs.

**3. Type consistency:** span shape `{model, prefix, first, last, sign}` consistent across Tasks 1–3. `sign` = ±1 downhill side used identically in finder and generator. `CreateAssetAsync` returns `(Enum.CreateAssetResult, assetId)` — matches the cobble-publish experience. Wall naming `Wall_<model>_<first>_<last>` consistent (Task 2 + Task 4).

## Notes for the implementer

- **Prototype before batch** — the whole point is validating the fitted-stone look on one span; do not batch until the params are approved.
- The generator builds verts in **world space** with the MeshPart at `CFrame.new()` (origin) — consistent with the cobble meshes.
- If a span's base terrain raycast misses, the node falls back to `topY − 4`; watch for that on any span that looks wrong and re-survey.
- Keep params **identical** across spans so the walls tone/scale-match each other and the existing stonework.
