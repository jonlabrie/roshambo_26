### Task 5: Footing predicate + PlanOptions plumbing (ZoneScatter)

**Files:**
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces (later tasks and the Studio mirror rely on these exact names):
  - `ZoneScatter.indexSamples(samples: { Sample }, pitch: number): SampleIndex`
  - `ZoneScatter.footingDrop(index: SampleIndex, pitch: number, x: number, z: number, y: number, radius: number): number?`
  - `export type PlanOptions = { pitch: number?, keepOut: ((number, number, string?) -> boolean)?, careBand: ((number, number) -> string)? }` (keepOut lands in Task 7, careBand in Task 8 — declare the full type now so the signature never churns)
  - `ZoneScatter.plan(zones, samples, recipes, water, built, opts: PlanOptions?)` — 6th parameter, optional, fully backward compatible
  - New `Recipe` fields: `footingRadius: number?`, `footingMaxDrop: number?`

- [ ] **Step 1: Write the failing tests** (append to `tests/ZoneScatter.spec.luau`):

```luau
describe("ZoneScatter.footingDrop", function()
    local function grid(yFn: (number, number) -> number?): { ZoneScatter.Sample }
        local s = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                local y = yFn(x, z)
                if y ~= nil then
                    table.insert(s, { x = x, z = z, y = y, steep = 0 })
                end
            end
        end
        return s
    end

    test("flat ground drops nothing", function()
        local idx = ZoneScatter.indexSamples(grid(function()
            return 50
        end), 4)
        expect(ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)).toBe(0)
    end)

    test("a cliff lip reports the drop", function()
        local idx = ZoneScatter.indexSamples(grid(function(x)
            return if x >= 52 then 10 else 50
        end), 4)
        local drop = ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)
        expect(drop).toBe(40)
    end)

    test("a missing probe (void/water) is nil, not level ground", function()
        local idx = ZoneScatter.indexSamples(grid(function(x)
            return if x >= 52 then nil else 50
        end), 4)
        expect(ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)).toBe(nil)
    end)
end)

describe("ZoneScatter.plan footing gate", function()
    test("placements never straddle the cliff", function()
        local samples = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                table.insert(samples, { x = x, z = z, y = if x >= 52 then 10 else 50, steep = 0 })
            end
        end
        local footed = table.clone(CORE)
        footed.footingRadius = 4
        footed.footingMaxDrop = 4
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Footed",
                densityScale = 1,
                seed = 7,
            },
        }
        local placements = ZoneScatter.plan(zones, samples, { Footed = footed }, nil, nil, { pitch = 4 })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            -- within footingRadius of the lip (x 52) the drop exceeds 4
            expect(p.x < 48 or p.x > 56).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure:** `lune run tests/run` — expected: `indexSamples` is not a function.
- [ ] **Step 3: Implement.** In `ZoneScatter.luau`: add after the `WaterIndex` section:

```luau
export type SampleIndex = { [string]: Sample }
export type PlanOptions = {
    pitch: number?,
    keepOut: ((number, number, string?) -> boolean)?,
    careBand: ((number, number) -> string)?,
}

local function sampleKey(x: number, z: number, pitch: number): string
    return `{math.floor(x / pitch + 0.5)},{math.floor(z / pitch + 0.5)}`
end

function ZoneScatter.indexSamples(samples: { Sample }, pitch: number): SampleIndex
    local index: SampleIndex = {}
    for _, s in samples do
        index[sampleKey(s.x, s.z, pitch)] = s
    end
    return index
end

-- Max drop in studs from (x,z,y) to the ground at 8 compass probes `radius` out.
-- nil = a probe found NO sample (void: water, off-grid, past a lip) — callers
-- treat that as the WORST footing, never as level ground.
function ZoneScatter.footingDrop(
    index: SampleIndex,
    pitch: number,
    x: number,
    z: number,
    y: number,
    radius: number
): number?
    local worst = 0
    for i = 0, 7 do
        local ang = i * math.pi / 4
        local probe = index[sampleKey(x + math.cos(ang) * radius, z + math.sin(ang) * radius, pitch)]
        if probe == nil then
            return nil
        end
        worst = math.max(worst, y - probe.y)
    end
    return worst
end
```

In `plan(...)`: change the signature to `function ZoneScatter.plan(zones, samples, recipes, water, built, opts: PlanOptions?)`; at the top add `local o: PlanOptions = opts or {}`, `local pitch = o.pitch or 4`, `local sampleIndex = ZoneScatter.indexSamples(samples, pitch)`. Add to `Recipe` type: `footingRadius: number?`, `footingMaxDrop: number?`. In the `accepts` closure, after the steep check:

```luau
        local fr = recipe.footingRadius
        if fr ~= nil then
            local drop = ZoneScatter.footingDrop(sampleIndex, pitch, s.x, s.z, s.y, fr)
            if drop == nil or drop > (recipe.footingMaxDrop or 4) then
                return false
            end
        end
```

- [ ] **Step 4: Run tests:** `lune run tests/run` — all green (existing plan() callers pass nil opts implicitly).
- [ ] **Step 5: Lint:** `stylua --check src tools tests && selene src tools`
- [ ] **Step 6: Commit:** `git add roblox/tools/builders/ZoneScatter.luau roblox/tests/ZoneScatter.spec.luau && git commit -m "feat(roblox): footing predicate - 8-point ground sample in ZoneScatter"`

