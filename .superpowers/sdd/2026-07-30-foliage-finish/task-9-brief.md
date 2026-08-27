### Task 9: Recipe overhaul

**Files:**
- Modify: `roblox/tools/studio/foliageZoneRecipes.luau`
- Test: `roblox/tests/FoliageZoneRecipes.spec.luau` (append)

**Interfaces:**
- Consumes: the Task 4 fern verdict; Task 1's `MuhlyGrass` template names.
- Produces: recipes the Task 10 mirror copies verbatim. Key changes below; every value is a starting point, tuned live at the Task 12 gate.

- [ ] **Step 1: Write the failing tests** (append):

```luau
describe("recipes name only species that exist", function()
    -- the kit as of Task 1-3 + the reed/weed exemplars Task 11 clones in
    local KNOWN = {
        MuhlyGrass = true,
        ReedClump = true,
        WeedStalks = true,
        FernClump = true, -- drop this line if the Task 4 verdict was park
        XfHinokiT = true,
        XfHinokiMT = true,
        XfSpruceMT = true,
        XfFirMT = true,
        XfSugi25T = true,
        XfHinokiYb = true,
        XfSpruceYb = true,
        XfFirYb = true,
        XfSugiYb = true,
        XfHinokiM = true,
        XfSpruceM = true,
        XfFirM = true,
        XfSugi40 = true,
    }
    for name, recipe in Recipes do
        test(name .. " pool is real", function()
            for _, sp in recipe.pool do
                expect(KNOWN[sp.name] == true).toBe(true)
            end
        end)
    end
end)

describe("waterline ecology", function()
    test("margin flora refuses steep hillsides", function()
        expect(Recipes.WaterMargin.maxSteep <= 0.4).toBe(true)
    end)
    test("reeds wade, muhly keeps damp feet only", function()
        expect(Recipes.WaterMargin.pool[1].name).toBe("MuhlyGrass")
        expect(Recipes.WaterMargin.submergeMax ~= nil).toBe(true)
    end)
end)
```

(`FoliageZoneRecipes.spec.luau` already requires the recipes table — follow its existing local names.)

- [ ] **Step 2: Run to verify failure** (WallFringe pool still names ConiferA etc.).
- [ ] **Step 3: Rewrite the recipe table** — the deltas:
  - `Recipe` type += `footingRadius: number?`, `footingMaxDrop: number?`, `submergeMax: number?`, `careDensity: { [string]: number }?` (mirror of Task 5-8).
  - **WallFringe** pool → the Xfrog untrimmed adults: `{ XfHinokiM 30, XfSpruceM 30, XfFirM 25, XfSugi40 15 }`, drop the per-species toolbox scales, keep `heightScale = 0.5` as the starting tune, add `footingRadius = 3, footingMaxDrop = 6` (walls are steep; sparser is accepted — the spec says so).
  - **PreserveCore** += `footingRadius = 2.5, footingMaxDrop = 4`.
  - **PreserveBrush** += `footingRadius = 1.5, footingMaxDrop = 3`, `careDensity = { GARDEN = 0.25, TENDED = 0.6 }` (understory cleared where tended — "clearing the floor is most of what tending a wood actually is").
  - **WaterMargin** → `pool = { MuhlyGrass 45, ReedClump 30, WeedStalks 15, FernClump 10 }` (drop FernClump if parked, reweight to 50/35/15), `maxSteep = 0.35` (the user's "weeds on steep hillsides just look bad"), `submergeMax = 1.0` (partial submersion is a feature), `footingRadius = 1, footingMaxDrop = 2`, keep `nearWater = 8`, `layer = "ground"`.
  - Deciduous accents and bamboo appear in NO pool (composition layer only — add a comment saying exactly that).
- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): recipes learn ecology - real species, wet feet, footing, care"`

