# ZenDojo Up-Canyon Watercourse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sculpt the up-canyon (head, −X) terrain into a descending watercourse — a hero infall down a sculpted western headwall into an upper basin, two staged falls into generous pools, a braided gravel stream, all flowing into the existing clearing pool.

**Architecture:** Native-voxel terrain work done via MCP `execute_luau` (Edit mode) scripts in `roblox/tools/studio/`. Carve/sculpt with `Terrain:FillBlock` (Air to remove, Rock to add); fill pools with Terrain water; falls reuse the tuned down-canyon beam-VFX recipe; greening reuses `greenCanyon`. **There are NO Lune/Vitest tests** — these scripts mutate live `workspace.Terrain` and cannot run headless. The "test" for each task is a **fresh raycast probe pass** (separate script execution — probes in the same script as a `FillBlock` read STALE) with expected elevations, plus a **user visual gate** in Studio. Every carve takes a `Terrain:CopyRegion` backup to `ServerStorage` first (reversible, precedent `GreenCanyonBackup`/`T*PadBackup`).

**Tech Stack:** Roblox Luau, MCP Roblox Studio (`execute_luau` datamodel=Edit, `start_stop_play`, `get_studio_state`), `Terrain:FillBlock`/`CopyRegion`/`FillRegion`, Beam-based fall VFX (existing `buildDowncanyon.luau`), `greenCanyon.luau`.

**Spec:** `docs/superpowers/specs/2026-06-20-zendojo-upcanyon-watercourse-design.md`

**World frame:** East=+X (downstream, built), **West=−X (head, this work)**, North=−Z, South=+Z. RES-4 voxels. `StreamingEnabled=true`. Probed profile: clearing pool y110 (ends ~x−80); existing clearing in-fall ~x−120 (y144); dry floor climbs y144→y205 (x−120→−400), jumps to y243 at x−440 (featureless headwall); gorge width 95–160.

**Target watercourse levels:** Upper Basin surface **y195** (x≈−370), Mid pool **y172** (x≈−280), Lower pool **y150** (x≈−180), braided stream grading y150→y144 into the clearing in-fall. Elevations are targets — confirm against live probes and adjust ≤±5 as terrain demands.

---

## File Structure

- **Create `roblox/tools/studio/buildUpcanyon.luau`** — the terrain carve/sculpt + water fill (headwall, 3 basins, 3 fall faces, braided stream, banks). Run section-by-section per task (each task adds/uncomments its block); idempotent via per-region backups. Mirrors the down-canyon carve approach; cannot `require` repo modules (inline everything).
- **Create `roblox/tools/studio/upcanyonFalls.luau`** — the 3 beam-falls in a Persistent Model `RoshamboStage.UpcanyonVFX`. Inlines the tuned down-canyon fall params (studio scripts can't require; copy values from `buildDowncanyon.luau`).
- **Modify `roblox/tools/studio/greenCanyon.luau`** — generalize its `REGION_MIN/MAX` (and East/West gradient) to also cover the up-canyon extents, OR add an up-canyon region pass. Keep the moss material + scatter logic shared.

## Shared helpers (used by buildUpcanyon.luau)

```lua
local ServerStorage = game:GetService("ServerStorage")
local Terrain = workspace.Terrain

-- CopyRegion backup of the AABB of a (possibly rotated) box, keyed by name. Guarded:
-- only backs up once per name so re-runs never capture already-carved terrain.
local function backup(name, cf, size)
  if ServerStorage:FindFirstChild(name) then return end
  local hs, mn, mx = size / 2, nil, nil
  for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
    local c = cf * Vector3.new(sx * hs.X, sy * hs.Y, sz * hs.Z)
    mn = mn and Vector3.new(math.min(mn.X, c.X), math.min(mn.Y, c.Y), math.min(mn.Z, c.Z)) or c
    mx = mx and Vector3.new(math.max(mx.X, c.X), math.max(mx.Y, c.Y), math.max(mx.Z, c.Z)) or c
  end end end
  local region = Region3.new(mn, mx):ExpandToGrid(4)
  local base = region.CFrame.Position - region.Size / 2
  local cx, cy, cz = base.X / 4, base.Y / 4, base.Z / 4
  local nx, ny, nz = region.Size.X / 4, region.Size.Y / 4, region.Size.Z / 4
  local bk = Terrain:CopyRegion(Region3int16.new(Vector3int16.new(cx, cy, cz), Vector3int16.new(cx + nx, cy + ny, cz + nz)))
  bk.Name = name; bk.Parent = ServerStorage
end

-- carve away terrain (Air) inside an axis-aligned box from floorY upward
local function carveDownTo(centerXZ, sizeXZ, floorY, topY)
  local h = topY - floorY
  Terrain:FillBlock(CFrame.new(centerXZ.X, (floorY + topY) / 2, centerXZ.Y), Vector3.new(sizeXZ.X, h, sizeXZ.Y), Enum.Material.Air)
end

-- add rock (build terrain up) inside an axis-aligned box from baseY to topY
local function fillRock(centerXZ, sizeXZ, baseY, topY)
  local h = topY - baseY
  Terrain:FillBlock(CFrame.new(centerXZ.X, (baseY + topY) / 2, centerXZ.Y), Vector3.new(sizeXZ.X, h, sizeXZ.Y), Enum.Material.Rock)
end

-- fill water inside a box (basin/stream)
local function fillWater(centerXZ, sizeXZ, botY, surfY)
  local h = surfY - botY
  Terrain:FillBlock(CFrame.new(centerXZ.X, (botY + surfY) / 2, centerXZ.Y), Vector3.new(sizeXZ.X, h, sizeXZ.Y), Enum.Material.Water)
end
```

## Shared probe (separate script — run AFTER any carve to verify; never in the same execution)

```lua
local rc = RaycastParams.new(); rc.FilterType = Enum.RaycastFilterType.Include; rc.FilterDescendantsInstances = { workspace.Terrain }
local function floorAt(x, z)
  local h = workspace:Raycast(Vector3.new(x, 280, z), Vector3.new(0, -360, 0), rc)
  return h and h.Position.Y or nil, h and h.Material.Name or "none"
end
-- usage: print floorAt across the worked region and compare to the task's expected band.
```

---

### Task 1: Sculpt the western headwall

**Files:** Create `roblox/tools/studio/buildUpcanyon.luau` (helpers above + this block).

The featureless rise (x−400→−460, y205→243+) becomes a tall **containing cliff/amphitheater**: a back face for the hero infall plus side wings (±Z) that cup the upper basin so water reads as held, not sheeting off a slope.

- [ ] **Step 1: Confirm Edit mode.** MCP `get_studio_state`; if Play, `start_stop_play{is_start=false}`.
- [ ] **Step 2: Backup the head region.** `backup("UpHeadBackup", CFrame.new(-435,205,0), Vector3.new(120,120,180))`.
- [ ] **Step 3: Raise the back face + side wings.** Build rock to form a headwall crest ~y240 across x−445..−465, and side wings rising to ~y235 along the ±Z edges of the basin footprint (x−360..−445):
```lua
fillRock(Vector2.new(-455, 0), Vector2.new(24, 170), 200, 240)            -- back face crest
fillRock(Vector2.new(-405, 70), Vector2.new(110, 28), 200, 235)           -- +Z wing
fillRock(Vector2.new(-405, -70), Vector2.new(110, 28), 200, 235)          -- -Z wing
```
- [ ] **Step 4: Cut the infall notch.** Carve a vertical chute down the back face for the hero plume: `carveDownTo(Vector2.new(-450, 0), Vector2.new(14, 26), 196, 246)` (a recessed channel from basin level up the crest).
- [ ] **Step 5: Verify (fresh probe pass).** Run the probe script: `floorAt(-455,0)` ≈ 240 (crest), `floorAt(-405,70)` & `(-405,-70)` ≈ 235 (wings), `floorAt(-450,0)` ≤ 198 (notch carved). Expected: crest/wings raised, notch low.
- [ ] **Step 6: USER GATE.** Ask the user to look: does the headwall read as a containing cliff framing where the infall will drop? Adjust crest/wing heights ±5 if requested.
- [ ] **Step 7: Commit.**
```bash
git add roblox/tools/studio/buildUpcanyon.luau
git commit -m "feat(roblox): sculpt up-canyon western headwall (hero infall containing cliff)"
```

### Task 2: Carve the Upper Basin + hero infall face

**Files:** Modify `roblox/tools/studio/buildUpcanyon.luau` (add this block).

The largest pool (surface y195) cupped by the Task-1 headwall, with a downstream sill at its mid-pool edge.

- [ ] **Step 1: Backup.** `backup("UpBasinBackup", CFrame.new(-370,190,0), Vector3.new(110,60,170))`.
- [ ] **Step 2: Carve the basin.** Flat bottom at y190 (surface fills to y195), footprint x−330..−420 × z−55..55:
```lua
carveDownTo(Vector2.new(-375, 0), Vector2.new(90, 110), 190, 230)   -- clear to basin floor 190
```
- [ ] **Step 3: Build the downstream sill.** A rock lip at the basin's +X (downstream) edge to hold water and form Fall-2's brink: `fillRock(Vector2.new(-330, 0), Vector2.new(8, 110), 190, 194)` (sill top y194, just under surface y195 so water spills).
- [ ] **Step 4: Verify (fresh probe).** `floorAt(-375,0)` ≈ 190 (basin floor); `floorAt(-330,0)` ≈ 194 (sill); headwall (Task 1) still ≥235 at wings.
- [ ] **Step 5: USER GATE.** Basin shape/extent look generous and contained? Adjust footprint to live width pinches if needed.
- [ ] **Step 6: Commit.** `git commit -am "feat(roblox): carve up-canyon upper basin + downstream sill"`

### Task 3: Carve Fall 2 face + Mid pool

**Files:** Modify `roblox/tools/studio/buildUpcanyon.luau`.

A ~23-stud fall face from the basin sill (y194) down into the Mid pool (surface y172).

- [ ] **Step 1: Backup.** `backup("UpMidBackup", CFrame.new(-300,175,0), Vector3.new(120,70,170))`.
- [ ] **Step 2: Carve the fall face + mid basin.** Fall face x−326..−312 dropping to mid floor y167; mid basin x−312..−250 flat floor y167 (surface 172):
```lua
carveDownTo(Vector2.new(-319, 0), Vector2.new(14, 100), 167, 196)    -- fall-2 face chute
carveDownTo(Vector2.new(-281, 0), Vector2.new(62, 110), 167, 196)    -- mid basin
```
- [ ] **Step 3: Downstream sill.** `fillRock(Vector2.new(-250, 0), Vector2.new(8, 110), 167, 171)` (sill y171, holds mid pool, forms Fall-3 brink).
- [ ] **Step 4: Verify (fresh probe).** `floorAt(-281,0)` ≈ 167; `floorAt(-250,0)` ≈ 171; basin sill (Task 2) ≈194 intact.
- [ ] **Step 5: USER GATE.** Fall-2 drop + mid-pool size read right?
- [ ] **Step 6: Commit.** `git commit -am "feat(roblox): carve up-canyon fall-2 face + mid pool"`

### Task 4: Carve Fall 3 face + Lower pool

**Files:** Modify `roblox/tools/studio/buildUpcanyon.luau`.

- [ ] **Step 1: Backup.** `backup("UpLowerBackup", CFrame.new(-185,158,0), Vector3.new(130,70,170))`.
- [ ] **Step 2: Carve fall face + lower basin.** Fall-3 face x−246..−232 to lower floor y146; lower basin x−232..−150 flat y146 (surface 150):
```lua
carveDownTo(Vector2.new(-239, 0), Vector2.new(14, 100), 146, 173)    -- fall-3 face
carveDownTo(Vector2.new(-191, 0), Vector2.new(82, 120), 146, 173)    -- lower basin
```
- [ ] **Step 3: Downstream sill.** `fillRock(Vector2.new(-150, 0), Vector2.new(8, 120), 146, 149)` (sill y149 → braided stream toward clearing).
- [ ] **Step 4: Verify (fresh probe).** `floorAt(-191,0)` ≈ 146; `floorAt(-150,0)` ≈ 149.
- [ ] **Step 5: USER GATE.**
- [ ] **Step 6: Commit.** `git commit -am "feat(roblox): carve up-canyon fall-3 face + lower pool"`

### Task 5: Braided gravel stream + banks

**Files:** Modify `roblox/tools/studio/buildUpcanyon.luau`.

A shallow gravel channel from the lower sill (y149) grading to the existing clearing in-fall (x−120, y144), with walkable mossy banks. Per spec floor type A.

- [ ] **Step 1: Backup.** `backup("UpStreamBackup", CFrame.new(-135,146,0), Vector3.new(80,40,140))`.
- [ ] **Step 2: Carve the shallow channel.** A central trough ~16 wide grading y149→y144 across x−150..−120, only ~3–4 studs deep (shallow, braided feel): carve in 3 short segments stepping the floor down 1–2 studs each, leaving gravel banks ±Z:
```lua
carveDownTo(Vector2.new(-145, 0), Vector2.new(16, 30), 147, 160)
carveDownTo(Vector2.new(-132, 0), Vector2.new(16, 30), 145, 160)
carveDownTo(Vector2.new(-122, 0), Vector2.new(18, 36), 144, 160)
```
- [ ] **Step 3: Material the channel bed.** Paint the trough bed to gravel-ish for the braided read: `Terrain:FillBlock(CFrame.new(-135,145,0), Vector3.new(50,2,18), Enum.Material.Ground)` (thin bed skin; moss pass later thins it).
- [ ] **Step 4: Verify (fresh probe).** `floorAt(-145,0)`≈147, `floorAt(-122,0)`≈144 — continuous grade into the clearing in-fall (no step up).
- [ ] **Step 5: USER GATE.** Stream reads shallow/walkable, connects cleanly to the clearing in-fall?
- [ ] **Step 6: Commit.** `git commit -am "feat(roblox): carve up-canyon braided stream + banks to clearing in-fall"`

### Task 6: Fill water (basins + stream)

**Files:** Modify `roblox/tools/studio/buildUpcanyon.luau`.

- [ ] **Step 1: Fill the three pools + stream at their surfaces:**
```lua
fillWater(Vector2.new(-375, 0), Vector2.new(88, 108), 188, 195)   -- upper basin -> 195
fillWater(Vector2.new(-281, 0), Vector2.new(60, 108), 165, 172)   -- mid pool -> 172
fillWater(Vector2.new(-191, 0), Vector2.new(80, 118), 144, 150)   -- lower pool -> 150
fillWater(Vector2.new(-135, 0), Vector2.new(48, 16),  143, 146)   -- braided stream
```
- [ ] **Step 2: Verify (fresh probe).** `floorAt` over each pool center returns material `Water` at ≈ the surface level (195/172/150); no water spilling over sills (sills y194/171/149 sit at/just below surface — confirm no flood past them).
- [ ] **Step 3: USER GATE.** Pools sit at the right levels, read reflective/contained, no leaks?
- [ ] **Step 4: Commit.** `git commit -am "feat(roblox): fill up-canyon pools + stream with terrain water"`

### Task 7: Falls VFX (hero infall + 2 staged falls)

**Files:** Create `roblox/tools/studio/upcanyonFalls.luau`.

Three beam-falls in a Persistent Model, mirroring the tuned down-canyon recipe (read exact texture id / `TextureMode=Stretch` / `TextureLength=1` / speed / crest-foam / splash / mist values from `buildDowncanyon.luau`). Hero infall = tallest, widest, most mist.

- [ ] **Step 1: Create the Persistent VFX model.**
```lua
local stage = workspace.RoshamboStage
local old = stage:FindFirstChild("UpcanyonVFX"); if old then old:Destroy() end
local m = Instance.new("Model"); m.Name = "UpcanyonVFX"; m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent; m.Parent = stage
```
- [ ] **Step 2: Define the 3 falls** (top edge = brink, bottom = pool surface), then build each with the down-canyon beam recipe (FaceCamera beams + water texture `rbxassetid://16808804567`, `TextureMode=Stretch`, `TextureLength=1`, `TextureSpeed≈0.55`, fade-in at lip, `CrestFoam` `16808075391`, splash `16829556885`, mist `16830667309`):
```lua
local FALLS = {
  { name="HeroInfall", top=Vector3.new(-450,224,0), bottom=Vector3.new(-440,195,0), width=12, mist=1.0 },
  { name="Fall2",      top=Vector3.new(-319,194,0), bottom=Vector3.new(-315,172,0), width=8,  mist=0.6 },
  { name="Fall3",      top=Vector3.new(-239,171,0), bottom=Vector3.new(-235,150,0), width=8,  mist=0.6 },
}
-- for each: build the beam stack + emitters parented under m (mirror buildDowncanyon.luau)
```
- [ ] **Step 3: Verify in Play.** `start_stop_play{is_start=true}`; confirm all 3 falls render as flowing water (not blobs/arrows) and persist under streaming. `start_stop_play{is_start=false}`.
- [ ] **Step 4: USER GATE.** Hero infall reads dominant; falls 2/3 proportional; mist tasteful (doesn't bury the teahouses).
- [ ] **Step 5: Commit.** `git add roblox/tools/studio/upcanyonFalls.luau && git commit -m "feat(roblox): up-canyon beam falls (hero infall + 2 staged) in Persistent VFX model"`

### Task 8: Greening (moss + sparse foliage on new walls/banks)

**Files:** Modify `roblox/tools/studio/greenCanyon.luau`.

- [ ] **Step 1: Add an up-canyon region pass.** Generalize `greenCanyon` to run its moss-skin + sparse-foliage logic over the up-canyon extents too — region min/max approx `(-470, 130, -95)` → `(-110, 250, 95)` (covers headwall, walls, banks). Keep the same `MOSS_COLOR`, near-water bare-rock rule, and density gradient (densest near the pools, thinning up the headwall). Guard the terrain SNAPSHOT (separate backup name `GreenUpcanyonBackup`).
- [ ] **Step 2: Run it (Edit).** Apply moss to new Rock/Basalt faces; keep bare wet rock within ~2 voxels of the new waterlines.
- [ ] **Step 3: Verify (fresh probe / visual).** New walls/banks show moss material; waterline rock stays bare; framerate acceptable.
- [ ] **Step 4: USER GATE.** Greening matches the down-canyon look; teahouse perches still readable through it.
- [ ] **Step 5: Commit.** `git commit -am "feat(roblox): green the up-canyon walls/banks (moss + sparse foliage)"`

### Task 9: Composition gate + continuity check

**Files:** none (review + tuning only).

- [ ] **Step 1: Flythrough head→clearing (Play or Edit camera).** Confirm ONE continuous river: hero infall → upper basin → Fall 2 → mid pool → Fall 3 → lower pool → braided stream → existing clearing in-fall → clearing pool. No dry gaps, no floating/leaking water.
- [ ] **Step 2: Tune mist density** so it evokes the North Star image without hiding the teahouses or tanking framerate (adjust emitter `Rate`/`Transparency` in `upcanyonFalls.luau`).
- [ ] **Step 3: Confirm teahouses + (future) bridge sightline** — the falls read well behind where the head bridge will cross; wall teahouses not buried by new terrain/mist.
- [ ] **Step 4: USER GATE — hero shots.** User signs off on the up-canyon composition.
- [ ] **Step 5: Save the place + final commit** of any tuning. `git commit -am "feat(roblox): up-canyon watercourse composition pass + mist tuning"`

---

## Self-Review

**Spec coverage:** headwall sculpt (T1 ✓), hero infall + upper basin (T2,T7 ✓), Fall 2 + mid pool (T3,T6,T7 ✓), Fall 3 + lower pool (T4,T6,T7 ✓), braided stream to clearing in-fall (T5,T6 ✓), water fill (T6 ✓), falls VFX reuse (T7 ✓), greening (T8 ✓), continuity + mist + teahouse-readability success criteria (T9 ✓), reversible backups (every carve task ✓), out-of-scope items (floor path/teahouse/bridge) not present ✓.

**Placeholder scan:** elevations, region boxes, backup names, texture ids, and verification readings are all concrete. Voxel geometry is explicitly "tuned ±5 against live probes" — a stated method, not a placeholder. No "TBD"/"handle edge cases".

**Consistency:** surface levels (195/172/150) and sills (194/171/149) match between carve (T2–T5), water (T6), and falls brinks (T7) across all tasks. Backup names unique per region. Probe helper + stale-read caveat applied uniformly.
