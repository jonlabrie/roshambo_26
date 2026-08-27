### Task 6: Sports-book teaser (Machiya_East) — OWNER GATE

Same file set and step shape as Task 4, substitutions (registry key is `MachiyaShops.sportsbook`; its `name` field is `"MachiyaEast"`). The guard tests, in full (helpers per Task 4 Step 1's note):

```lua
describe("eastern machiya (sports-book teaser)", function()
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.sportsbook)
    local parts = allParts(m)
    test("subordinate to the tower", function()
        for _, p in parts do
            local topY = p.properties.CFrame[2] + p.properties.Size[2] / 2
            expect(topY <= ArenaLayout.towerTopY - 9.0).toBe(true)
        end
    end)
    test("closed koshi front, no dressing, blank board only", function()
        local sawKoshi = false
        for _, p in parts do
            if string.find(p.name, "KoshiFront") then sawKoshi = true end
        end
        expect(sawKoshi).toBe(true)
        expect(find(m, "Dressing") == nil).toBe(true)
        local board = find(m, "SignBoard")
        expect(board ~= nil).toBe(true)
        expect(board.children == nil or #board.children == 0).toBe(true) -- no Decal/Texture/SurfaceGui
    end)
end)
```

- Shop table already `frontage = "koshi"`, `interior = "none"`, `yaw` from the Task 2 survey (this is the shell that likely faces WEST toward the plaza — the guard tests must pass with the yaw applied, so compute expected positions through the same rotate-about-centre math as Task 3's yaw test rather than raw envelope bounds; for the dressing-containment test use the LOCAL envelope check on parts counter-rotated by −yaw about the centre).
- `identity`: `glow = { color = {1.0,0.55,0.25}, brightness = 2.0 }` (stronger — the teaser reads as something alive inside), `board = true` (blank, unlit, NO text — the naming is out of scope per the wager-language ruling), `chochin = false`, `noren = nil`, `dress = nil`.
- Guard tests: subordination; `KoshiFront_` parts exist; NO `Dressing` model; the blank `SignBoard` exists and carries no Decal/Texture/SurfaceGui child.
- genmodels/model/convention name: `MachiyaEast` (the neutral structure name — the business name comes later with the cavern).
- Commit: `feat(roblox): the eastern machiya — closed koshi teaser over the future cavern`.
- OWNER GATE as Task 4 Step 7.

---

