### Task 6: Submersion affinity (ZoneScatter)

**Files:**
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces: `Sample` gains `depth: number?` (studs of water above the ground point; nil/0 = dry). `Recipe` gains `submergeMax: number?` — nil preserves today's behavior (submerged samples never existed before; now they are REJECTED unless the recipe opts in), a number accepts `0 < depth <= submergeMax`. Task 10 fills `depth` from Studio raycasts.

- [ ] **Step 1: Write the failing tests:**

```luau
describe("ZoneScatter submersion", function()
    local function shoreSamples(): { ZoneScatter.Sample }
        -- x<=48 dry bank y=50; x>=52 shallow water: ground 49, half a stud deep
        local s = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                if x >= 52 then
                    table.insert(s, { x = x, z = z, y = 49, steep = 0, depth = 0.5 })
                else
                    table.insert(s, { x = x, z = z, y = 50, steep = 0 })
                end
            end
        end
        return s
    end
    local zones: { ZoneScatter.Zone } = {
        {
            name = "A",
            shape = "rect",
            bounds = { 0, 0, 100, 100 },
            recipe = "R",
            densityScale = 1,
            seed = 7,
        },
    }

    test("a dry recipe never plants in water", function()
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = CORE })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x <= 48).toBe(true)
        end
    end)

    test("a wet-footed recipe wades in, to its depth limit", function()
        local reed = table.clone(CORE)
        reed.submergeMax = 1.0
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = reed })
        local wet = 0
        for _, p in placements do
            if p.x >= 52 then
                wet += 1
            end
        end
        expect(wet > 0).toBe(true)
    end)

    test("too deep is still too deep", function()
        local reed = table.clone(CORE)
        reed.submergeMax = 0.3 -- shallower than the 0.5 water
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = reed })
        for _, p in placements do
            expect(p.x <= 48).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure** (`wet > 0` fails — depth is ignored today, so the dry-recipe test also fails by planting everywhere).
- [ ] **Step 3: Implement.** `Sample` type += `depth: number?`; `Recipe` type += `submergeMax: number?`. In `accepts`, after the footing gate:

```luau
        local depth = s.depth or 0
        if depth > 0 then
            local submergeMax = recipe.submergeMax
            if submergeMax == nil or depth > submergeMax then
                return false
            end
        end
```

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): submersion affinity - reeds may wade, everything else stays dry"`

