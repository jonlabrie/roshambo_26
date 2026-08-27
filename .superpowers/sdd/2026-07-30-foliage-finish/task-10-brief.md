### Task 10: Sync the Studio mirror (scatterPreserve)

**Files:**
- Modify: `roblox/tools/studio/scatterPreserve.luau`

**Interfaces:**
- Consumes: Tasks 5–9 verbatim (this file MIRRORS the planner + recipes — copy the logic, keep the header's sync warning).
- Produces: a bake tool whose `MODE="plan"` reports per-zone counts under the new rules. Task 12 runs it.

- [ ] **Step 1: Mirror the recipe table** from Task 9 into the `RECIPES` block (types too).
- [ ] **Step 2: Mirror the planner changes** into the inline planner: `indexSamples`/`footingDrop`, the accepts gates (keep-out first, then steep, footing, submersion), care-banded density, PlanOptions equivalent.
- [ ] **Step 3: Upgrade `sampleTerrain` for submersion** — ground under shallow water must become a sample (today `hit.Material == Water` cells are skipped entirely):

```lua
local function sampleTerrain(zones: { Zone }): { Sample }
    local rpGround = RaycastParams.new()
    rpGround.FilterType = Enum.RaycastFilterType.Include
    rpGround.FilterDescendantsInstances = { workspace.Terrain }
    rpGround.IgnoreWater = true
    local rpWater = RaycastParams.new()
    rpWater.FilterType = Enum.RaycastFilterType.Include
    rpWater.FilterDescendantsInstances = { workspace.Terrain }
    rpWater.IgnoreWater = false
    -- (bbox loop unchanged)
    for x = x1, x2, SAMPLE_PITCH do
        for z = z1, z2, SAMPLE_PITCH do
            local origin = Vector3.new(x, PROBE_TOP, z)
            local ground = workspace:Raycast(origin, Vector3.new(0, -900, 0), rpGround)
            if ground then
                local surface = workspace:Raycast(origin, Vector3.new(0, -900, 0), rpWater)
                local depth = 0
                if surface and surface.Material == Enum.Material.Water then
                    depth = surface.Position.Y - ground.Position.Y
                end
                table.insert(samples, {
                    x = x,
                    z = z,
                    y = ground.Position.Y,
                    steep = 1 - math.clamp(ground.Normal.Y, 0, 1),
                    depth = depth,
                    material = ground.Material.Name,
                })
            end
        end
    end
    return samples
end
```

- [ ] **Step 4: Keep-out callback** — mirror `CanyonKeepOuts.MATERIALS` + `ZONES` as inline constants (with the sync-warning comment) and pass `keepOut = function(x, z, m) ... end` implementing the same `blocks` logic.
- [ ] **Step 5: Care distance** — build a bucketed index over `readBuiltCells()` (reuse the `WATER_BUCKET` pattern) plus the staged-site override (the FallsDock footprint gets a 15-stud garden radius — read `RoshamboStage.FallsDock`'s bbox and append its perimeter points to the care cells). `careBand = function(x, z) return CareModelBand(x, nearestCareDist(x, z)) end` with `CareModelBand` mirrored from Task 8. Nearest distance by expanding ring over buckets:

```lua
local function nearestCareDist(index, x, z): number
    for ring = 0, 8 do -- 8 buckets * 16 studs = beyond any reach
        local best = math.huge
        local bx, bz = math.floor(x / WATER_BUCKET), math.floor(z / WATER_BUCKET)
        for gx = bx - ring, bx + ring do
            for gz = bz - ring, bz + ring do
                if math.max(math.abs(gx - bx), math.abs(gz - bz)) == ring then
                    local bucket = index[`{gx},{gz}`]
                    if bucket then
                        for _, c in bucket do
                            local dx, dz = x - c[1], z - c[2]
                            best = math.min(best, dx * dx + dz * dz)
                        end
                    end
                end
            end
        end
        if best < math.huge and ring >= 1 then -- one extra ring so a closer diagonal can't hide
            return math.sqrt(best)
        end
    end
    return math.huge
end
```

- [ ] **Step 6: Lint** (`stylua --check src tools tests && selene src tools` — selene runs on tools; dead locals fail CI).
- [ ] **Step 7: Smoke it** via MCP `execute_luau` (Edit): run with `MODE="plan"` — it should print per-zone counts without stamping. Expect zeros for WaterMargin (zones not restored yet — that's Task 11).
- [ ] **Step 8: Commit:** `git commit -m "feat(roblox): scatterPreserve mirrors the ecology predicates"`

