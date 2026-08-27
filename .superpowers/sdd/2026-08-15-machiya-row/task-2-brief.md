### Task 2: Survey the massing and terrain (Studio, no geometry built)

**Files:**
- Modify: `roblox/tools/builders/MachiyaShops.luau` (add `apparel`, `accessories`, `sportsbook`, plus a `chayaSurvey` comment block for Task 7)
- Test: `roblox/tests/MachiyaShops.spec.luau` (extend)

**Interfaces:**
- Consumes: `MachiyaShops.Shop` from Task 1.
- Produces: three filled spec tables (envelopes + yaw from the survey; `frontage`/`interior` per the design spec: apparel & accessories `open`/`shallow`, sportsbook `koshi`/`none`) and a recorded terrain/footing survey for each site + the chaya site.

- [ ] **Step 1: Confirm Studio** — `mcp__Roblox_Studio__list_roblox_studios`; if empty, report BLOCKED (the survey needs the open place).
- [ ] **Step 2: Survey each massing block** via `execute_luau` (datamodel Edit). For each of `Machiya_1`, `Machiya_4`, `Machiya_East` under `game.ServerStorage.Sandbox_PARKED.MerchantMassing`, and `Machiya_2` + `DockDeck` for Task 7's record:

```lua
local out = {}
for _, name in { "Machiya_1", "Machiya_4", "Machiya_East", "Machiya_2", "DockDeck" } do
    local b = game.ServerStorage.Sandbox_PARKED.MerchantMassing[name]
    local cf = b:GetPivot()
    local sz = b:GetExtentsSize()
    local _, yawY, _ = cf.Rotation:ToEulerAnglesYXZ()
    table.insert(out, string.format("%s pivot(%.2f,%.2f,%.2f) size(%.2f,%.2f,%.2f) yawDeg %.2f",
        name, cf.X, cf.Y, cf.Z, sz.X, sz.Y, sz.Z, math.deg(yawY)))
end
return table.concat(out, "\n")
```

- [ ] **Step 3: Footing probes** — for each site, raycast terrain at the four envelope corners AND the midpoints of each edge (the full-footprint footing-ring rule), from y+40 downward 80, `RaycastParams` filtering to `workspace.Terrain`. Record hit heights. Also probe `Machiya_East`'s surroundings: nearest Overlook structure part west of it (`workspace.CanyonWorld` + `workspace.RoshamboStage.Overlook` — use `workspace:GetPartBoundsInBox` around its envelope) — record clearances.
- [ ] **Step 4: Derive each envelope as literals** — `x0 = pivotX − sizeX/2` etc. **If a block's yaw is not ~0 (±1°), the envelope is the block's LOCAL box: record x0..x1/z0..z1 in the local frame around the pivot and set `shop.yaw` to the measured yaw** (Task 3's transform applies it). `floorY`: choose per site from the footing probes — the HIGHEST corner hit + slab logic consistent with 花火屋 (its floor 113.10 sits on the promenade grade); flag any site where corners disagree by >1.5 studs as a concern for the controller rather than inventing terracing.
- [ ] **Step 5: Write the three spec tables** into `MachiyaShops.luau` with the survey recorded in comments (date, pivot, yaw, probe heights — the same read-back style as hanabiya's). `identity = nil` still.
- [ ] **Step 6: Extend the registry test** — same shape as Step 1's, one block per shop, asserting the surveyed literals and: apparel/accessories `frontage=="open"`,`interior=="shallow"`; sportsbook `frontage=="koshi"`,`interior=="none"`; run suite → new tests pass (build() still rejects non-hanabiya configs — that assert is Task 3's to lift; do NOT call build() on the new shops yet).
- [ ] **Step 7: Lint, commit** — `feat(roblox): survey the merchant-row envelopes into MachiyaShops`.

---

