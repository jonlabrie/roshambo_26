# ZenDojo Path Railings & Hanging Chōchin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bamboo post-and-rail down the paths' downhill edge and hanging ribbed chōchin (showing the World-Throw result) on cross-arm poles up the cliff edge — with the shared lantern controller generalized to drive round lanterns.

**Architecture:** One code change (`LanternController` gains a `RoundLantern`-tag scan + billboard-glyph branch; block path untouched). Everything else is deterministic Parts placed from the path timbers, ad-hoc in `Workspace.PathRailings` / `Workspace.PathLanterns`. Build the controller + one prototype chōchin first, validate in Play (glows AND shows the result), iterate, then deploy.

**Tech Stack:** Roblox Studio, Luau via execute_luau, `CollectionService`, BillboardGui; the existing `LanternController.client.luau` telegraph.

## Global Constraints

- **Source spec:** `docs/superpowers/specs/2026-06-27-zendojo-path-railings-lanterns-design.md`.
- **Controller:** leave the existing block path (`*Lantern` name scan under RoshamboStage, 4-face SurfaceGui) **unchanged**. Add: discover `CollectionService` tag **`RoundLantern`** canyon-wide → a **BillboardGui** glyph per lantern, sharing the existing `glyphLabels`/telegraph. Glyph set `{R="○",P="─",S="∧"}`, ink `Color3.fromRGB(36,30,24)`.
- **Chōchin (Parts):** warm Neon barrel (cream ~`255/225/170`, slight transparency) + ~10–12 thin dark rib rings + dark top/bottom caps w/ accent rings + cord + interior warm `PointLight`. The **barrel body part is tagged `RoundLantern`** (billboard adornee).
- **Railing (Parts):** bamboo cylinders, tan ~`170/150/90`; posts ~0.45 dia × 3.4 every **~2 timbers** at the bed edge; **top rail ~2.9 + mid rail ~1.5**, open between. Downhill edge.
- **Poles (Parts):** bamboo upright ~0.35 dia × 5.5 on the **uphill edge** + cross-arm; chōchin hangs from the cross-arm end; **~every 6 timbers**.
- **Downhill side** = the `−RightVector` side (matches the walls/cobbles, sign −1 for these paths). Uphill = `+RightVector`.
- **Paths & prefixes:** `PathSteps`/`Timber_`, `PathExtension`/`ExtTimber_`, `DescentPath`/`DescTimber_`.
- **Lives:** controller in `src/` (Rojo, committed; lune suite stays green/untouched). Geometry ad-hoc in `Workspace.PathRailings` + `Workspace.PathLanterns`. **One visual attempt per change, then stop** (`stop-and-ask-after-each-attempt`).

---

### Task 1: LanternController — add round (tag-driven billboard) support

**Files:**
- Modify: `roblox/src/client/LanternController.client.luau`

**Interfaces:**
- Produces: round lanterns (CollectionService-tagged `RoundLantern`, anywhere in `workspace`) get a `LanternFace` **BillboardGui** with a `Glyph` TextLabel that joins `glyphLabels` and rides the existing telegraph. Block lanterns unchanged.

- [ ] **Step 1: Add the round branch.** After the `CollectionService` is required and the block `tryBuild`/scan block (around line 79–91), add a billboard builder + tag scan. Insert this code:

```lua
local CollectionService = game:GetService("CollectionService")

-- round lanterns (chōchin): a single billboard glyph instead of the 4-face SurfaceGui
local function buildBillboard(part: Instance)
	if not part:IsA("BasePart") or built[part] then
		return
	end
	built[part] = true
	local bb = Instance.new("BillboardGui")
	bb.Name = "LanternFace"
	bb.Adornee = part
	bb.Size = UDim2.fromOffset(150, 180) -- tuned in Play
	bb.LightInfluence = 0
	bb.MaxDistance = 220
	bb.Parent = part
	local g = Instance.new("TextLabel")
	g.Name = "Glyph"
	g.BackgroundTransparency = 1
	g.Size = UDim2.fromScale(1, 1)
	g.Font = Enum.Font.GothamBlack
	g.TextColor3 = INK
	g.TextScaled = true
	if current then
		g.Text = GLYPH[current] or ""
		g.TextTransparency = 0
	else
		g.Text = ""
		g.TextTransparency = 1
	end
	g.Parent = bb
	table.insert(glyphLabels, g)
end

for _, p in CollectionService:GetTagged("RoundLantern") do
	buildBillboard(p)
end
CollectionService:GetInstanceAddedSignal("RoundLantern"):Connect(buildBillboard)
```

(The existing `built`, `glyphLabels`, `current`, `GLYPH`, `INK` are reused. `buildBillboard` is defined after they are — keep this block below their declarations and below `buildFace`.)

- [ ] **Step 2: Format + lint + ensure tests untouched.**

Run: `cd roblox && stylua src && stylua --check src tests && selene src && lune run tests/run`
Expected: no lint errors; `... passed, 0 failed` (the suite is unchanged — this is a client script with no lune test).

- [ ] **Step 3: Commit.**

```bash
git add roblox/src/client/LanternController.client.luau
git commit -m "feat(roblox): LanternController — round lanterns via RoundLantern tag (billboard glyph)"
```

- [ ] **Step 4: Verify in Play (with Task 2's prototype).** Deferred to Task 2 Step 4 — needs a tagged round lantern in-world to confirm the glyph appears and telegraphs.

---

### Task 2: Chōchin + pole prototype

**Files:** none in git (Studio Parts via execute_luau); creates `Workspace.PathLanterns`.

**Interfaces:**
- Consumes: Task 1's `RoundLantern` tag support.
- Produces: a `buildChochinPole(cf)` recipe; one prototype `ChochinPole` model under `Workspace.PathLanterns`, its barrel part named `Chochin*Lantern`-free (round path is tag-driven, not name-driven) and **tagged `RoundLantern`**.

- [ ] **Step 1: Build one prototype chōchin-on-pole** (execute_luau, Edit). Place it at a test spot near the upper path (uphill side) so it's easy to view; tune positions in Play.

```lua
local ws = workspace
local CollectionService = game:GetService("CollectionService")
local parent = ws:FindFirstChild("PathLanterns") or Instance.new("Model")
parent.Name = "PathLanterns"; parent.Parent = ws
local old = parent:FindFirstChild("ChochinPole_PROTO"); if old then old:Destroy() end
local model = Instance.new("Model"); model.Name = "ChochinPole_PROTO"; model.Parent = parent

-- anchor at a visible spot just uphill of an upper-run timber
local t = ws.PathSteps.Timber_20
local up = t.CFrame.RightVector; up = Vector3.new(up.X,0,up.Z).Unit -- +Right = uphill
local base = t.Position + up * 4.5

local BAMBOO = Color3.fromRGB(170,150,90)
local INK = Color3.fromRGB(46,40,30)
local PAPER = Color3.fromRGB(255,225,170)
local ACCENT = Color3.fromRGB(150,60,40)
local function cyl(name, size, cf, color, mat, trans)
	local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Cylinder
	p.Size = size; p.CFrame = cf; p.Anchored = true; p.CanCollide = false
	p.Color = color; p.Material = mat or Enum.Material.Wood; p.Transparency = trans or 0
	p.Parent = model; return p
end
-- cylinder local axis is +X; vertical cylinder = rotate X->Y
local VERT = CFrame.Angles(0,0,math.rad(90))

-- pole upright (5.5 tall) + cross-arm near top reaching over the path (toward -up)
local poleH = 5.5
cyl("Pole", Vector3.new(poleH, 0.7, 0.7), CFrame.new(base + Vector3.new(0,poleH/2,0)) * VERT, BAMBOO)
local armY = base.Y + poleH - 0.4
local armLen = 2.6
local armEnd = base + (-up) * armLen + Vector3.new(0, poleH - 0.4, 0)
local armMid = base + (-up) * (armLen/2) + Vector3.new(0, poleH - 0.4, 0)
do -- horizontal cross-arm along -up
	local dir = (-up)
	local cf = CFrame.lookAt(armMid, armMid + dir) * CFrame.Angles(0, math.rad(90), 0) -- X along dir
	cyl("CrossArm", Vector3.new(armLen, 0.5, 0.5), cf, BAMBOO)
end

-- chōchin hanging under the arm end
local lanternTopY = armY - 0.5
local bodyH, bodyR = 1.8, 0.72
local centerY = lanternTopY - 0.2 - bodyH/2
local lc = Vector3.new(armEnd.X, centerY, armEnd.Z)
cyl("Cord", Vector3.new(0.6, 0.06, 0.06), CFrame.new((armEnd + Vector3.new(0, -0.3, 0))) * VERT, INK)
-- barrel body (slight bulge via 3 stacked cylinders)
local body = cyl("ChochinBody", Vector3.new(bodyH*0.5, bodyR*1.9, bodyR*1.9), CFrame.new(lc) * VERT, PAPER, Enum.Material.Neon, 0.12)
cyl("ChochinBodyTop", Vector3.new(bodyH*0.28, bodyR*1.55, bodyR*1.55), CFrame.new(lc + Vector3.new(0, bodyH*0.36, 0)) * VERT, PAPER, Enum.Material.Neon, 0.12)
cyl("ChochinBodyBot", Vector3.new(bodyH*0.28, bodyR*1.55, bodyR*1.55), CFrame.new(lc - Vector3.new(0, bodyH*0.36, 0)) * VERT, PAPER, Enum.Material.Neon, 0.12)
-- rib rings (thin dark discs slightly proud)
for i = 0, 10 do
	local y = lc.Y + (i/10 - 0.5) * bodyH
	local rr = bodyR * (1.9 - 0.55 * math.abs(i/10 - 0.5) * 2) + 0.06 -- follow the bulge
	cyl("Rib_"..i, Vector3.new(0.06, rr, rr), CFrame.new(Vector3.new(lc.X, y, lc.Z)) * VERT, INK, Enum.Material.Wood)
end
-- caps + accent rings
cyl("CapTop", Vector3.new(0.22, 0.95, 0.95), CFrame.new(lc + Vector3.new(0, bodyH/2 + 0.06, 0)) * VERT, INK)
cyl("CapBot", Vector3.new(0.22, 0.95, 0.95), CFrame.new(lc - Vector3.new(0, bodyH/2 + 0.06, 0)) * VERT, INK)
cyl("AccentTop", Vector3.new(0.08, 1.0, 1.0), CFrame.new(lc + Vector3.new(0, bodyH/2 - 0.12, 0)) * VERT, ACCENT)
cyl("AccentBot", Vector3.new(0.08, 1.0, 1.0), CFrame.new(lc - Vector3.new(0, bodyH/2 - 0.12, 0)) * VERT, ACCENT)
-- light + result tag (on the barrel body)
local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255,190,120); light.Brightness = 1.6; light.Range = 16; light.Parent = body
CollectionService:AddTag(body, "RoundLantern")
return string.format("prototype chochin-pole at (%.0f,%.0f,%.0f); body tagged RoundLantern", lc.X, lc.Y, lc.Z)
```

- [ ] **Step 2: VISUAL REVIEW in Edit (stop for user)** — does the lantern read as a ribbed chōchin (barrel + ribs + caps + cord, warm glow) hung from the cross-arm pole? Tune body proportions / rib count / colours / glow on the prototype until approved.

- [ ] **Step 3: VERIFY IN PLAY (stop for user)** — enter Play; confirm the chōchin **glows** and the `LanternController` paints the **World-Throw glyph** on it (billboard), fading per round in sync with the other lanterns. Tune `BillboardGui` size/offset (Task 1) if the glyph is mis-sized/placed. This validates Task 1 + Task 2 together.

- [ ] **Step 4: Lock the recipe** — once the chōchin + glyph are approved, freeze the `buildChochinPole` params for deployment.

---

### Task 3: Bamboo railing prototype

**Files:** none (Studio); creates `Workspace.PathRailings`.

**Interfaces:**
- Produces: a `buildRailing(model, prefix, fromIdx, toIdx)` recipe; one prototype railing run under `Workspace.PathRailings`.

- [ ] **Step 1: Build a prototype railing run** along part of the upper path (downhill edge). (execute_luau, Edit.)

```lua
local ws = workspace
local parent = ws:FindFirstChild("PathRailings") or Instance.new("Model")
parent.Name = "PathRailings"; parent.Parent = ws
for _, c in parent:GetChildren() do if c.Name:match("^Rail_PathSteps_PROTO") then c:Destroy() end end
local model = Instance.new("Model"); model.Name = "Rail_PathSteps_PROTO"; model.Parent = parent

local BAMBOO = Color3.fromRGB(170,150,90)
local HW, POSTH = 3.2, 3.4
local TOPY, MIDY = 2.9, 1.5
local VERT = CFrame.Angles(0,0,math.rad(90))
local function bamboo(name, size, cf)
	local p = Instance.new("Part"); p.Name=name; p.Shape=Enum.PartType.Cylinder; p.Size=size; p.CFrame=cf
	p.Anchored=true; p.CanCollide=false; p.Color=BAMBOO; p.Material=Enum.Material.Wood; p.Parent=model; return p
end
-- posts every 2 timbers on the downhill (-Right) edge; rails between consecutive posts
local m = ws.PathSteps
local posts = {}
for i = 20, 30, 2 do -- prototype stretch
	local t = m:FindFirstChild("Timber_"..i)
	if t then
		local r = t.CFrame.RightVector; r = Vector3.new(r.X,0,r.Z).Unit
		local edge = t.Position - r * HW -- downhill
		local pc = Vector3.new(edge.X, t.Position.Y + POSTH/2, edge.Z)
		bamboo("Post_"..i, Vector3.new(POSTH, 0.45, 0.45), CFrame.new(pc) * VERT)
		table.insert(posts, { x = edge.X, z = edge.Z, y = t.Position.Y })
	end
end
-- top + mid rails as cylinders between consecutive posts
for k = 1, #posts - 1 do
	local a, b = posts[k], posts[k+1]
	for _, ry in { TOPY, MIDY } do
		local p0 = Vector3.new(a.x, a.y + ry, a.z)
		local p1 = Vector3.new(b.x, b.y + ry, b.z)
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude
		local cf = CFrame.lookAt(mid, p1) * CFrame.Angles(0, math.rad(90), 0) -- X along the run
		bamboo("Rail", Vector3.new(len + 0.3, 0.3, 0.3), cf)
	end
end
return string.format("prototype railing: %d posts, rails between", #posts)
```

- [ ] **Step 2: VISUAL REVIEW (stop for user)** — bamboo posts + two rails reading right along the downhill edge (height, spacing, dia)? Tune `HW`/`POSTH`/`TOPY`/`MIDY`/spacing until approved, then lock.

---

### Task 4: Deploy railings + chōchin poles along all paths

**Files:** none (Studio).

**Interfaces:**
- Consumes: the locked `buildRailing` (Task 3) and `buildChochinPole` (Task 2) recipes.

- [ ] **Step 1: Railings — every path, full downhill edge.** Generalize Task 3's builder into `buildRailing(model, prefix)` that walks **all** the model's timbers (sorted), posts every 2, rails between, on the `−Right` edge; run for `PathSteps/Timber`, `PathExtension/ExtTimber`, `DescentPath/DescTimber`. Each path → a `Rail_<model>` model under `Workspace.PathRailings`. (Reuse the exact post/rail code from Task 3, looping over the full sorted timber index range instead of 20–30.)

- [ ] **Step 2: VISUAL REVIEW (stop for user)** — railing continuous along every downhill edge, following curves/grade.

- [ ] **Step 3: Chōchin poles — every path, ~every 6 timbers.** Run the locked `buildChochinPole` at every 6th timber (uphill `+Right` side), per path → `ChochinPole_<model>_<i>` under `Workspace.PathLanterns`, each barrel tagged `RoundLantern`.

- [ ] **Step 4: VERIFY (stop for user)** — in Edit: poles + lanterns spaced naturally up the cliff edge, not clipping terrain/walls. In Play: all chōchin glow and telegraph the result in sync. Re-space/adjust any that clip.

---

### Task 5: Record as-built + commit

**Files:**
- Modify: `docs/superpowers/specs/2026-06-27-zendojo-path-railings-lanterns-design.md`

- [ ] **Step 1: Record** — append an "As-built" section: final chōchin/pole/railing params, counts per path, `Workspace.PathRailings` + `Workspace.PathLanterns`, and the `RoundLantern` tag + `LanternController` change. Update the `zendojo-fw11-switchback-deck` memory (railings/lanterns done; note the controller now supports round lanterns via the tag).

- [ ] **Step 2: Commit.**

```bash
git add docs/superpowers/specs/2026-06-27-zendojo-path-railings-lanterns-design.md
git commit -m "docs(roblox): path railings + chochin — record as-built"
```

- [ ] **Step 3: Remind** the user to **save the place** (railings/lanterns are ad-hoc Parts; the `LanternController` change persists via Rojo).

---

## Self-Review

**1. Spec coverage:**
- §1 chōchin model → Task 2 (build + iterate). ✓
- §2 controller generalization (RoundLantern tag + billboard, block unchanged) → Task 1, validated Task 2 Step 3. ✓
- §3 bamboo railing → Tasks 3 (prototype) + 4 (deploy). ✓
- §4 poles & placement (uphill, ~every 6) → Tasks 2 + 4. ✓
- Where it lives (controller src/, geometry ad-hoc) → Tasks 1 vs 2–4. ✓
- Out of scope (box lanterns, teahouse swap, bridges) → not planned. ✓

**2. Placeholder scan:** Task 4 reuses Tasks 2/3 recipes by generalizing the loop range — the full code lives in those tasks (read in order); the deploy step states exactly how to generalize (walk all sorted timbers). No TBDs; all prototype code complete.

**3. Type consistency:** `RoundLantern` tag string consistent (Task 1 scan ↔ Task 2 `AddTag`). The barrel body part is the tagged adornee in both. `glyphLabels`/`built`/`current`/`GLYPH`/`INK` reused from the existing controller (names verified against the file). Downhill = `−RightVector`, uphill = `+RightVector` consistent across railing (Task 3) and poles (Task 2/4).

## Notes for the implementer

- **Build order matters:** Task 1 (controller) must land before Task 2 Step 3 (Play-verify the glyph). Iterate the chōchin look in Edit (Task 2 Step 2) before the Play check.
- Roblox cylinder primitive's long axis is **local X** — vertical cylinders need the `CFrame.Angles(0,0,90°)` (`VERT`) shown; rails along a run use `CFrame.lookAt(mid,end) * CFrame.Angles(0,90°,0)`.
- Keep all params identical across deployed instances so the lanterns/railings read consistent.
- BillboardGui sizing is distance-dependent — expect to tune `Size`/`MaxDistance` in Play (Task 2 Step 3).
