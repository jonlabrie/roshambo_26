### Task 7: Keep-out gate + terrain material in samples (ZoneScatter)

**Files:**
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces: `Sample` gains `material: string?` (terrain material name under the sample, Studio-filled). `PlanOptions.keepOut` (declared in Task 5) is now enforced: `keepOut(x, z, material?) -> true` vetoes a placement AND clump children. `CanyonKeepOuts.blocks(x, z, materialName?)` is the intended callback — this consolidates the two keep-out systems: FoliageZones "KeepOut" parts stay for ad-hoc dragging, CanyonKeepOuts is the authored authority, and the planner consults both.

- [ ] **Step 1: Write the failing tests:**

```luau
describe("ZoneScatter keep-out gate", function()
    local CanyonKeepOuts = require("../tools/builders/CanyonKeepOuts")
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

    test("an injected keep-out vetoes ground and clump children alike", function()
        local clumpy = table.clone(CORE)
        clumpy.clumpChance = 1
        clumpy.clumpSize = 3
        local placements = ZoneScatter.plan(zones, flatSamples(), { R = clumpy }, nil, nil, {
            keepOut = function(x, _z, _m)
                return x > 50
            end,
        })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x <= 50).toBe(true)
        end
    end)

    test("CanyonKeepOuts slots straight in as the callback", function()
        -- samples over the karesansui zone (x -25..38, z -16..22) get vetoed
        local samples = {}
        for x = -40, 60, 4 do
            for z = -30, 40, 4 do
                table.insert(samples, { x = x, z = z, y = 0, steep = 0 })
            end
        end
        local wide: { ZoneScatter.Zone } = {
            {
                name = "W",
                shape = "rect",
                bounds = { -40, -30, 60, 40 },
                recipe = "R",
                densityScale = 1,
                seed = 3,
            },
        }
        local placements = ZoneScatter.plan(wide, samples, { R = CORE }, nil, nil, {
            keepOut = function(x, z, m)
                return (CanyonKeepOuts.blocks(x, z, m))
            end,
        })
        for _, p in placements do
            expect(CanyonKeepOuts.zoneAt(p.x, p.z)).toBe(nil)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.** `Sample` type += `material: string?`. In `accepts`, first gate:

```luau
        if o.keepOut ~= nil and o.keepOut(s.x, s.z, s.material) then
            return false
        end
```

(Clump children already re-run `accepts` on their probe — extend the probe construction to carry the nearest sample's `material` and `depth`: `local probe: Sample = { x = cx, z = cz, y = cy, steep = if cs then cs.steep else 0, depth = cs and cs.depth or nil, material = cs and cs.material or nil }`.)

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): one keep-out authority - the planner consults CanyonKeepOuts"`

