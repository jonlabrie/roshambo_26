# ZenDojo FW11 → FW10 Descent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry the trail from the FW11 switchback deck down to FarWall_10 — a short Slate-on-stringer stair off the deck (in the `SwitchbackDeck` builder), then a graded stepped-cobble path routed through user-adjusted draft markers.

**Architecture:** Task 1 adds the stair to the pure `SwitchbackDeck` builder (lune-tested, genmodels → Rojo) and publishes `SwitchbackDeck.STAIR_FOOT` as the descent's first route point. Task 2 drops draft markers from the stair foot to FW10 for the user to adjust. Task 3 builds the stepped-cobble descent through those markers in `Workspace.DescentPath` (ad-hoc Studio geometry, published cobble mesh) — same recipe as the upper-path extension.

**Tech Stack:** Luau, lune (headless tests in `tests/`), Rojo, Roblox Studio (`mcp__Roblox_Studio__execute_luau`), EditableMesh.

## Global Constraints

- **Source spec:** `docs/superpowers/specs/2026-06-27-zendojo-fw11-fw10-descent-design.md`.
- **Stair exit:** deck **West edge, south end**, centerline z ≈ **−62**; descends **−X** and down from deck top **138.46** to **stair foot ≈ (144.7, 134.95, −62)** (~3.5 drop over 6 studs, 3 steps).
- **Stair recipe (Overlook-style):** 3 **Slate** treads (`5 × 0.5 × 2.0`, colour `palette.ink`) + two sloped **Wood** stringers (`Spec.segment`, `len × 0.9 × 0.5`, dropped 0.7, colour `TIMBER`) + two framing **newels** (`NEWEL_W × NEWEL_H`).
- **Cobble-path recipe (reuse upper run):** timber risers (Wood `74/52/32`, `6.4 × 1.6 × 1.2`, ~3.5 spacing); per-section Voronoi cobbles (min-sep 0.55, ~3–4 seeds/gap, inset 0.08, 1-pass Chaikin, dome 0.42, **flat-up normals**, mossy `122/127/117`, Material Rock, **published**); cement-gravel bed (Concrete + `ZenCement2`, ~**6.42** wide, tint `138/142/142`); **6.4 tread width**.
- **Floats over the basin** through the middle — retaining walls are a **separate later pass**, not this plan.
- **Run from `roblox/`.** Tests: `lune run tests/run`. Models: `lune run tools/genmodels`. Lint: `stylua --check src tests` + `selene src` (run `stylua tools/builders/SwitchbackDeck.luau` to format the builder; `selene src` does not cover `tools`).
- **Studio geometry persistence:** unpublished EditableMesh becomes a placeholder box on reload — the descent cobble mesh MUST be published via `AssetService:CreateAssetAsync` (returns `(Enum.CreateAssetResult, assetId)`).

---

### Task 1: Deck→path stair (in the SwitchbackDeck builder)

**Files:**
- Modify: `roblox/tools/builders/SwitchbackDeck.luau`
- Modify: `roblox/tests/SwitchbackDeck.spec.luau`

**Interfaces:**
- Consumes: `Spec.part`, `Spec.cframe`, `Spec.segment`; existing module constants `DECK_TOP`, `X0`, `TIMBER`, `NEWEL_W`, `NEWEL_H`; `palette.ink`.
- Produces: children `Step1..Step3` (Slate), `Stringer1`/`Stringer2` (Wood), `StairNewel_1`/`StairNewel_2` (Wood); module field `SwitchbackDeck.STAIR_FOOT = {144.7, 134.95, -62}` (the descent's first route point).

- [ ] **Step 1: Write the failing test** (append inside the `describe` block in `tests/SwitchbackDeck.spec.luau`)

```lua
    test("has a 3-step Slate stair on stringers off the West-south edge, descending", function()
        local s1, s2, s3 = find(model, "Step1"), find(model, "Step2"), find(model, "Step3")
        expect(s1 ~= nil and s2 ~= nil and s3 ~= nil).toBe(true)
        expect(s1.properties.Material).toBe("Slate")
        -- treads descend in Y from the deck toward the foot
        expect(s1.properties.CFrame[2] > s2.properties.CFrame[2]).toBe(true)
        expect(s2.properties.CFrame[2] > s3.properties.CFrame[2]).toBe(true)
        expect(countPrefix(model, "Stringer") >= 2).toBe(true)
        expect(countPrefix(model, "StairNewel_") >= 2).toBe(true)
        -- publishes the descent's first route point, below the deck top
        expect(SwitchbackDeck.STAIR_FOOT[2] < 138.46).toBe(true)
    end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `Step1` nil / `STAIR_FOOT` nil.

- [ ] **Step 3: Write minimal implementation**

In `roblox/tools/builders/SwitchbackDeck.luau`, add the stair constants after the railing constants (near `RAIL_INSET`):

```lua
-- ===== deck->path stair (Overlook-style, off the West-south edge) =====
local STAIR_Z = -62 -- centerline on the West edge, south end
local STAIR_W = 5.0 -- tread width (along Z)
local STAIR_STEPS = 3
local STAIR_TOP = { X0, DECK_TOP, STAIR_Z } -- head of flight at the deck edge
local STAIR_FOOT = { X0 - 6, 134.95, STAIR_Z } -- ~3.5 drop over 6 studs -X
SwitchbackDeck.STAIR_FOOT = STAIR_FOOT -- exposed: the descent's first route marker
```

Then, inside `build`, just before `return Spec.model(...)`:

```lua
    -- 3 Slate treads from the deck edge down to the foot
    for k = 1, STAIR_STEPS do
        local t = (k - 0.5) / STAIR_STEPS
        table.insert(
            kids,
            Spec.part(`Step{k}`, {
                Size = { STAIR_W, 0.5, 2.0 },
                CFrame = Spec.cframe({
                    STAIR_TOP[1] + (STAIR_FOOT[1] - STAIR_TOP[1]) * t,
                    STAIR_TOP[2] + (STAIR_FOOT[2] - STAIR_TOP[2]) * t,
                    STAIR_Z,
                }),
                Color = palette.ink,
                Material = "Slate",
            })
        )
    end
    -- two sloped stringers under the tread edges
    for si, off in { -(STAIR_W / 2 - 0.3), STAIR_W / 2 - 0.3 } do
        local a = { STAIR_TOP[1], STAIR_TOP[2] - 0.7, STAIR_Z + off }
        local b = { STAIR_FOOT[1], STAIR_FOOT[2] - 0.7, STAIR_Z + off }
        local pos, len, rot = Spec.segment(a, b)
        table.insert(
            kids,
            Spec.part(`Stringer{si}`, {
                Size = { len, 0.9, 0.5 },
                CFrame = Spec.cframe(pos, rot),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end
    -- two newels framing the head of the flight (West edge is otherwise open)
    for i, zoff in { -(STAIR_W / 2), STAIR_W / 2 } do
        table.insert(
            kids,
            Spec.part(`StairNewel_{i}`, {
                Size = { NEWEL_W, NEWEL_H, NEWEL_W },
                CFrame = Spec.cframe({ X0 + NEWEL_W / 2, DECK_TOP + NEWEL_H / 2, STAIR_Z + zoff }),
                Color = TIMBER,
                Material = "Wood",
            })
        )
    end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (all SwitchbackDeck tests green).

- [ ] **Step 5: Regenerate + lint**

Run: `cd roblox && lune run tools/genmodels && stylua tools/builders/SwitchbackDeck.luau && stylua --check src tests && selene src`
Expected: rewrites `assets/SwitchbackDeck.model.json`; no lint errors.

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/builders/SwitchbackDeck.luau roblox/tests/SwitchbackDeck.spec.luau roblox/assets/SwitchbackDeck.model.json
git commit -m "feat(roblox): FW11 deck — Slate-on-stringer stair off the West-south edge"
```

- [ ] **Step 7: VISUAL REVIEW (stop for user)**

Rojo live-syncs. Ask the user to look at the stair off the deck's West-south edge: 3 Slate treads on stringers, framed by two newels, dropping ~3.5 studs to the foot (~134.95). Adjust step count / rise / z-position if asked, then re-sync. Stop until approved. **Make one attempt, then stop** (`stop-and-ask-after-each-attempt`).

---

### Task 2: Draft route markers (stair foot → FW10)

**Files:** none (Studio geometry only, via `execute_luau`).

**Interfaces:**
- Consumes: `SwitchbackDeck.STAIR_FOOT` (read the deck's stair foot in-world); `Workspace.PathDraft`.
- Produces: a `Workspace.PathDraft.Descent` folder of `Marker_1..N` Parts along the stair-foot→FW10 chord, for the user to reposition.

- [ ] **Step 1: Drop the draft markers** (via `mcp__Roblox_Studio__execute_luau`, datamodel Edit)

```lua
local ws = workspace
local pd = ws:FindFirstChild("PathDraft") or Instance.new("Folder")
pd.Name = "PathDraft"; pd.Parent = ws
local old = pd:FindFirstChild("Descent"); if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "Descent"; folder.Parent = pd

local foot = Vector3.new(144.7, 134.95, -62) -- SwitchbackDeck.STAIR_FOOT
local fw10 = ws.PathDraft.FarWall_10.Position
local N = 7 -- intermediate + end markers along the chord
for i = 0, N do
    local t = i / N
    local p = foot:Lerp(fw10, t)
    local m = Instance.new("Part")
    m.Name = string.format("Marker_%d", i)
    m.Shape = Enum.PartType.Ball
    m.Size = Vector3.new(2, 2, 2)
    m.Color = Color3.fromRGB(255, 170, 0)
    m.Material = Enum.Material.Neon
    m.Anchored = true
    m.CanCollide = false
    m.Position = p
    m:AddTag("DevMarker") -- hidden in Play by hideDevMarkers.client.luau
    m.Parent = folder
end
return string.format("dropped %d descent markers from foot (%.0f,%.0f,%.0f) to FW10 (%.0f,%.0f,%.0f)",
    N + 1, foot.X, foot.Y, foot.Z, fw10.X, fw10.Y, fw10.Z)
```

Expected: `dropped 8 descent markers ...`; a row of amber balls appears from the stair foot to FW10.

- [ ] **Step 2: USER ADJUSTS (stop for user)**

Ask the user to drag the `Workspace.PathDraft.Descent.Marker_*` balls in Studio to shape the descent line (and adjust count if they want). Stop until they say the line is set. The markers' final positions define the route.

---

### Task 3: Stepped-cobble descent path through the markers

**Files:** none in git (Studio geometry in `Workspace.DescentPath`); publishes a cobble mesh asset.

**Interfaces:**
- Consumes: `Workspace.PathDraft.Descent.Marker_*` (the adjusted route); the cobble-path recipe (Global Constraints).
- Produces: `Workspace.DescentPath` model — `DescTimber_*` + `DescBed` Parts and a **published** `DescCobbles` MeshPart; mirrors `Workspace.PathExtension`.

- [ ] **Step 1: Route + build timbers and bed** (via `execute_luau`, Edit)

Build a Catmull-Rom spline through the sorted markers, place timber risers along the arc at ~3.5-stud spacing conforming to the graded spline Y, and lay the cement-gravel bed ribbon along it.

```lua
local ws = workspace
local folder = ws.PathDraft.Descent
local pts = {}
do
    local ms = {}
    for _, c in folder:GetChildren() do
        local i = tonumber((c.Name :: string):match("Marker_(%d+)"))
        if i then table.insert(ms, { i = i, p = c.Position }) end
    end
    table.sort(ms, function(a, b) return a.i < b.i end)
    for _, m in ms do table.insert(pts, m.p) end
end

-- Catmull-Rom sample (phantom endpoints)
local function cr(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5
        * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end
local function sampleSpline(arr, perSeg)
    local out = {}
    for s = 1, #arr - 1 do
        local p0 = arr[math.max(s - 1, 1)]
        local p1, p2 = arr[s], arr[s + 1]
        local p3 = arr[math.min(s + 2, #arr)]
        local lo = s == 1 and 0 or 1
        for k = lo, perSeg do
            table.insert(out, cr(p0, p1, p2, p3, k / perSeg))
        end
    end
    return out
end

local model = ws:FindFirstChild("DescentPath"); if model then model:Destroy() end
model = Instance.new("Model"); model.Name = "DescentPath"; model.Parent = ws

local spline = sampleSpline(pts, 8)
-- arc-length walk placing timbers every ~3.5 studs
local SPACING = 3.5
local acc, ti = 0, 0
for s = 1, #spline - 1 do
    local a, b = spline[s], spline[s + 1]
    local seg = (b - a).Magnitude
    acc = acc + seg
    if acc >= SPACING then
        acc = 0
        ti = ti + 1
        local dir = (b - a)
        local horiz = Vector3.new(dir.X, 0, dir.Z).Unit
        local cross = Vector3.new(horiz.Z, 0, -horiz.X)
        local tb = Instance.new("Part")
        tb.Name = string.format("DescTimber_%d", ti)
        tb.Size = Vector3.new(6.4, 1.6, 1.2)
        tb.CFrame = CFrame.fromMatrix(b, cross, Vector3.yAxis)
        tb.Anchored = true
        tb.Material = Enum.Material.Wood
        tb.Color = Color3.fromRGB(74, 52, 32)
        tb.Parent = model
    end
end
return string.format("DescentPath: %d markers, %d spline pts, %d timbers", #pts, #spline, ti)
```

Expected: timbers march down the spline from the stair foot to FW10.

- [ ] **Step 2: VISUAL REVIEW (stop for user)** — confirm the timber line follows the intended descent; adjust markers + re-run Step 1 if needed.

- [ ] **Step 3: Per-section Voronoi cobbles + bed, then publish** (via `execute_luau`, Edit)

For each gap between consecutive `DescTimber_*`, generate the per-section Voronoi cobbles (same generator proven on `ExtCobbles`: min-sep 0.55, ~3–4 seeds/gap, inset 0.08, 1-pass Chaikin, dome 0.42, **flat-up normals** `(0,1,0)`, mossy `122/127/117`, base = bed-top + 0.10, clip cells to the tread half-width 3.2 and the gap bounds). Lay a `DescBed` ribbon (Concrete + `ZenCement2`, ~6.42 wide) under them. Build all cobbles as ONE EditableMesh, then:

```lua
-- after building the EditableMesh `em` of all gap cobbles:
local AssetService = game:GetService("AssetService")
local res, assetId = AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, {
    Name = "ZenDescentCobbles",
    Description = "FW11->FW10 descent cobbles",
})
assert(res == Enum.CreateAssetResult.Success, tostring(res))
local mp = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. assetId))
mp.Name = "DescCobbles"
mp.Material = Enum.Material.Rock
mp.Color = Color3.new(1, 1, 1)
mp.DoubleSided = true
mp.Anchored = true
mp.CanCollide = false
mp.CollisionFidelity = Enum.CollisionFidelity.Box
mp.CFrame = CFrame.new() -- verts authored in world space
mp:SetAttribute("PublishedAsset", "rbxassetid://" .. assetId)
mp.Parent = workspace.DescentPath
return "published DescCobbles rbxassetid://" .. assetId
```

(The full gap-cobble generator is the one used for `ExtCobbles` — per-section seeding, `clip`/`centroid` helpers, 3-ring dome with `AddNormal((0,1,0))` reused for every face, per-stone `AddColor`. Match those parameters exactly so the descent tones with the rest of the trail.)

- [ ] **Step 4: VISUAL REVIEW (stop for user)** — cobbles match the upper run (tone, size, proudness), bed width matches (no side overhang), path reads continuous from the stair to FW10. Iterate on dome/seat/width as on the extension. Record the published asset id.

- [ ] **Step 5: Update records** — append the descent's as-built (asset id, `Workspace.DescentPath`) to the descent spec and the `zendojo-fw11-switchback-deck` memory; commit the doc.

```bash
git add docs/superpowers/specs/2026-06-27-zendojo-fw11-fw10-descent-design.md
git commit -m "docs(roblox): FW11->FW10 descent — record as-built (DescentPath + published cobbles)"
```

---

## Self-Review

**1. Spec coverage:**
- §1 stair (Slate treads + stringers + framing newels, West-south, in the builder) → Task 1. ✓
- Route workflow (stair foot = first marker; draft markers; user adjusts; route through them) → `STAIR_FOOT` in Task 1, Task 2, Task 3 Step 1. ✓
- §2 cobble descent (timbers + per-section Voronoi cobbles published + bed, 6.4 width, floats over basin) → Task 3. ✓
- §3 materials / where-things-live (stair in builder; descent ad-hoc) → Tasks 1 vs 3. ✓
- Out of scope (retaining walls, FW10 tie-in, consolidation) → not planned; noted in Global Constraints. ✓

**2. Placeholder scan:** Task 3 Step 3 references the `ExtCobbles` generator rather than re-pasting ~120 lines; the recipe parameters are given verbatim in Global Constraints + Step 3, and the publish code is complete. This is a deliberate reuse of proven, in-repo-history code, not a "TBD". All other steps carry complete code/commands.

**3. Type consistency:** `SwitchbackDeck.STAIR_FOOT` defined in Task 1, consumed in Task 2/3. Child-name prefixes (`Step`, `Stringer`, `StairNewel_`, `DescTimber_`, `DescBed`, `DescCobbles`, `Marker_`) consistent across tasks. `CreateAssetAsync` return shape `(Enum.CreateAssetResult, assetId)` matches what was observed publishing `ExtCobbles`.

## Notes for the implementer

- Build is gated by **user marker adjustment** (Task 2 Step 2) — do not route the path (Task 3) until the user sets the markers.
- The descent **floats over the basin** by design; do not add fill or walls — that's the separate later pass.
- Keep the cobble generator parameters identical to `ExtCobbles` so tone/size/proudness match the rest of the trail (the hard-won values: per-section seeding, dome 0.42, flat-up normals, seat ~0.27 below where it reads too proud).
