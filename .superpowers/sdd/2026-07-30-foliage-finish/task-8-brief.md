### Task 8: CareModel + care-banded density

**Files:**
- Create: `roblox/tools/builders/CareModel.luau`
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/CareModel.spec.luau` (new), `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces:
  - `CareModel.reach(x: number): number` — `clamp(8 + 20 * (x + 430) / 470, 8, 28)` (the garden-floor spec's formula, verbatim)
  - `CareModel.band(x: number, distToCare: number): string` — `"GARDEN"` within 35% of reach, `"TENDED"` within reach, else `"PRESERVE"`
  - `Recipe.careDensity: { [string]: number }?` — per-band multiplier on the zone's densityScale, applied only when `PlanOptions.careBand` is provided

- [ ] **Step 1: Write the failing tests** (`tests/CareModel.spec.luau`):

```luau
--!strict
local harness = require("./harness")
local CareModel = require("../tools/builders/CareModel")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("CareModel.reach", function()
    test("the garden-floor spec's anchor values hold", function()
        -- Square x=+40 → 28 (clamped); dock x=−345 → 11.6; west end x=−430 → 8
        expect(CareModel.reach(40)).toBe(28)
        expect(math.abs(CareModel.reach(-345) - 11.6) < 0.05).toBe(true)
        expect(CareModel.reach(-430)).toBe(8)
        expect(CareModel.reach(-9999)).toBe(8)
    end)
end)

describe("CareModel.band", function()
    test("GARDEN is the inner 35% of reach", function()
        expect(CareModel.band(40, 9.7)).toBe("GARDEN") -- 0.35*28 = 9.8
        expect(CareModel.band(40, 9.9)).toBe("TENDED")
        expect(CareModel.band(40, 28.0)).toBe("TENDED")
        expect(CareModel.band(40, 28.1)).toBe("PRESERVE")
    end)
end)
```

And in `ZoneScatter.spec.luau`:

```luau
describe("ZoneScatter care-banded density", function()
    test("a zero GARDEN multiplier clears the tended front yard", function()
        local weedy = table.clone(CORE)
        weedy.careDensity = { GARDEN = 0 }
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
        local placements = ZoneScatter.plan(zones, flatSamples(), { R = weedy }, nil, nil, {
            careBand = function(x, _z)
                return if x < 50 then "GARDEN" else "PRESERVE"
            end,
        })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x >= 50).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.** `CareModel.luau`:

```luau
--!strict
-- The care model (spec 2026-07-29-canyon-garden-floor-design): how far human
-- tending reaches from paths and staged sites, as a distance in STUDS. Pure.
local CareModel = {}

CareModel.GARDEN_FRACTION = 0.35

function CareModel.reach(x: number): number
    return math.clamp(8 + 20 * (x + 430) / 470, 8, 28)
end

function CareModel.band(x: number, distToCare: number): string
    local r = CareModel.reach(x)
    if distToCare <= CareModel.GARDEN_FRACTION * r then
        return "GARDEN"
    elseif distToCare <= r then
        return "TENDED"
    end
    return "PRESERVE"
end

return CareModel
```

In `ZoneScatter.plan`, `Recipe` type += `careDensity: { [string]: number }?`, and replace the density-thinning block:

```luau
        -- density thinning before spacing so DensityScale thins uniformly;
        -- the care band scales it further where recipes opt in
        local density = zone.densityScale
        if o.careBand ~= nil and recipe.careDensity ~= nil then
            local mul = recipe.careDensity[o.careBand(s.x, s.z)]
            if mul ~= nil then
                density *= mul
            end
        end
        if roll(zone) >= density then
            continue
        end
```

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): CareModel - the care gradient as a pure, testable reach"`

