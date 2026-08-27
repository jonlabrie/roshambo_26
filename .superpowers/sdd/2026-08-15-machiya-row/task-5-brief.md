### Task 5: Accessories (Machiya_4) — OWNER GATE

Same file set and step shape as Task 4 with these substitutions (repeat Task 4's steps 1–7 with them). The guard tests, in full (helpers per Task 4 Step 1's note):

```lua
describe("accessories shell", function()
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.accessories)
    local parts = allParts(m)
    test("subordinate to the tower", function()
        for _, p in parts do
            local topY = p.properties.CFrame[2] + p.properties.Size[2] / 2
            expect(topY <= ArenaLayout.towerTopY - 9.0).toBe(true)
        end
    end)
    test("has a dressing set and it stays inside the envelope", function()
        local e = MachiyaShops.accessories.envelope
        local d = find(m, "Dressing")
        expect(d ~= nil).toBe(true)
        for _, p in allParts(d) do
            expect(p.properties.CFrame[1] >= e.x0 and p.properties.CFrame[1] <= e.x1).toBe(true)
            expect(p.properties.CFrame[3] >= e.z0 and p.properties.CFrame[3] <= e.z1).toBe(true)
        end
    end)
end)
```

- `identity`: `noren = { color = warm russet {0.55,0.28,0.18}, segments = 4 }`, `chochin = true`, `board = true` (blank timber kanban, texture deferred as in Task 4), `glow = { color = {1.0,0.85,0.6}, brightness = 1.2 }`, `dress = function(ctx)`: **two shelf walls** (each: three 0.4-thick shelves at 2.2/4.2/6.2, full bay width, on the east and west interior walls) stocked with decoration-economy prop MINIATURES built from primitives — per shelf: two 1.6-tall stone-lantern forms (stacked cylinders per the `StoneLantern.luau` silhouette: base disc 0.9, shaft 0.3, firebox cube 0.55, cap disc 1.0), two 1.2 × 1.8 folding-screen slabs at 15° zigzag pairs, three 0.3 × 1.4 rolled-flag cylinders; a **display plinth** centre-floor (1.8³ cube, one 2.2 lantern form on top); counter + rear shelf exactly as Task 4's.
- genmodels key/model/convention name: `MachiyaAccessories`.
- Commit: `feat(roblox): accessories machiya — the Piece B window display`.
- OWNER GATE as Task 4 Step 7.

---

