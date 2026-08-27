### Task 4: Apparel (Machiya_1) — first shell, OWNER GATE

**Files:**
- Modify: `roblox/tools/builders/MachiyaShops.luau` (apparel identity + dress), `roblox/tools/genmodels.luau` (add output), `roblox/default.project.json`, `roblox/src/shared/WorkspaceConvention.luau`
- Create (generated): `roblox/assets/MachiyaApparel.model.json`
- Test: `roblox/tests/MachiyaShops.spec.luau` (guard block)

**Interfaces:**
- Consumes: Task 2's `MachiyaShops.apparel` envelope, Task 3's identity kit.
- Produces: stage model `MachiyaApparel`; the per-shell guard test pattern Tasks 5–7 repeat.

- [ ] **Step 1: Write the failing guard tests** (first copy the `allParts` and `find` helpers from `Machiya.spec.luau` into `MachiyaShops.spec.luau` — the harness has no shared helpers module):

```lua
describe("apparel shell", function()
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.apparel)
    local parts = allParts(m)
    test("subordinate to the tower", function()
        for _, p in parts do
            local topY = p.properties.CFrame[2] + p.properties.Size[2] / 2
            expect(topY <= ArenaLayout.towerTopY - 9.0).toBe(true)
        end
    end)
    test("has a dressing set and it stays inside the envelope", function()
        local e = MachiyaShops.apparel.envelope
        local d = find(m, "Dressing")
        expect(d ~= nil).toBe(true)
        for _, p in allParts(d) do
            expect(p.properties.CFrame[1] >= e.x0 and p.properties.CFrame[1] <= e.x1).toBe(true)
            expect(p.properties.CFrame[3] >= e.z0 and p.properties.CFrame[3] <= e.z1).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run, verify fails** (no identity/dress yet → no Dressing model).
- [ ] **Step 3: Fill `MachiyaShops.apparel.identity`.** First attempt (owner corrects from here): `noren = { color = palette-indigo (from ZenDojo palette's existing deep blue; if none, {0.16,0.18,0.32}), segments = 5 }`, `chochin = true`, `board = true` (blank timber kanban above the kamoi — the glyph-pipeline texture is a gate follow-up with the owner, not this task), `glow = { color = {1.0,0.85,0.6}, brightness = 1.2 }`, and `dress = function(ctx)`: two **kimono racks** (each: 2 posts 0.3² × 5.5 + a 0.2 rail spanning them; three hanging 2.2 × 3.8 × 0.15 cloth slabs, Fabric, alternating two palette colours) set in the two westmost open bays 1.2 inside the frontage plane; a **fold table** (4.0 × 2.6 top at 2.5, four 0.25² legs) mid-floor with three 0.9 × 0.5 × 0.6 folded-cloth stacks; a **counter** reusing `ctx.consts.COUNTER_H` (3.0) and 2.0 deep, 60% of the envelope width, 4.4 off the back wall (花火屋's standoff — same rule, same number); a **rear shelf** (0.4 thick, 5.5 up, full counter width) with five 0.8-cube cloth bolts. All positions computed from `ctx.env`, nothing hardcoded to world coordinates.
- [ ] **Step 4: Register the model** — genmodels `OUTPUTS["MachiyaApparel"] = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.apparel)`; project.json line after Hanabiya's: `"MachiyaApparel": { "$path": "assets/MachiyaApparel.model.json" },`; WorkspaceConvention entry `"MachiyaApparel", -- apparel machiya, merchant row (assets/MachiyaApparel.model.json)`.
- [ ] **Step 5: Suite + byte gate + lint** — all green; Hanabiya.model.json unchanged; `git add` the four source files AND the new generated JSON.
- [ ] **Step 6: Commit** — `feat(roblox): apparel machiya — the row's first shell`.
- [ ] **Step 7: OWNER GATE** — stop; report the shell is ready (owner reconnects Rojo and looks). Do not proceed to Task 5 in the same dispatch. On corrections: apply, re-run Step 5, one commit per correction round, wiki gate entry when accepted (`## [date] gate | apparel machiya accepted` + item-4 page current-state line).

---

