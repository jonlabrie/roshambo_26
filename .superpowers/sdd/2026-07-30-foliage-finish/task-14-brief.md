### Task 14: Moss collector + re-bake + USER GATE

**Files:**
- Create: `roblox/tools/studio/buildMossTransitions.luau`

**Interfaces:**
- Consumes: `MossTransitions.plan` (MIRRORED inline — Studio cannot require from disk; carry the sync-warning header), `ServerStorage.MossLibrary` (49 meshes, families `Moss_A/B/D/E`, `Moos_C` — note the kit's own typo), the moss seating lessons (bottom-of-box + absolute sink + re-raycast at final position).
- Produces: `CanyonWorld.Foliage.MossTransitions` folder; the old `MossScatter` parked.

- [ ] **Step 1: Write the collector** with `MODE = "plan" | "bake" | "wipe"`. Seed generation, one function per kind:
  - **`stone`** — for every BasePart under `CanyonWorld` whose name matches `^Stone_` (the 35 trail stones) plus every Model in the rock folders (`CanyonWorld.Arena` rock models, any `RockLibrary`-sourced clones): 6–10 perimeter points around the base at bbox-bottom height.
  - **`footing`** — for BaseParts under `CanyonWorld.Paths` and `CanyonWorld.Structures` whose bbox bottom sits within 0.75 studs of the terrain (raycast at the part centre): points along the two long bottom edges, stepped every ~4 studs (reuse the `readBuiltCells` stepping pattern from scatterPreserve).
  - **`waterline`** — WaterMap cells (`Workspace.Sandbox.WaterMap.WaterMarkers`) that have at least one missing 4-stud neighbour cell (edge of water = the splash band), seeded at the cell position.
  - **`crevice`** — terrain raycast grid (pitch 4) over the corridor bounds; keep samples whose `1 - normal.Y` sits in a band (default 0.35–0.65: steep enough to be a fold, not a cliff face).
  Params defaults: `spacing = 1.5, maxDist = 5, dartsPerSeed = 16, kindDensity = { stone = 0.9, footing = 0.7, waterline = 0.8, crevice = 0.5 }`, pool weighted toward mats (`Moss_A` 3, `Moos_C` 2, `Moss_D` 2, `Moss_E` 1, `Moss_B` 1 — sporophyte accent stays rare).
  Seating at bake: fresh ground raycast at each placement's (x, z); position the clone so the BOTTOM of its bounding box sits at ground minus an absolute `SINK = 0.15` studs. Engine flags via the same `flagClone` treatment as scatterPreserve (never collide). Sort seeds by (x, z) before planning so collection order can't change the bake.
- [ ] **Step 2: `MODE="plan"`** — print seed counts per kind and total placements. Sanity: hundreds to ~1,500, not tens of thousands; if crevice dominates 10:1 the band is too wide.
- [ ] **Step 3: Park the old moss:** move `CanyonWorld.Foliage.MossScatter` → `ServerStorage.ParkedFoliage.MossConfetti_2026_08`.
- [ ] **Step 4: Bake.** One attempt. Screenshot survey (same discipline as Task 12 Step 3).
- [ ] **Step 5: USER GATE.** Walk: moss should read as gathering at feet-of-things and waterline, not broadcast. Tune `kindDensity`/`maxDist` only as directed.
- [ ] **Step 6: Lint + commit the tool:** `git add roblox/tools/studio/buildMossTransitions.luau && git commit -m "feat(roblox): moss gathers at the transitions"`
- [ ] **Step 7: User saves the place.**

---

## Part 4 — Composition layer

