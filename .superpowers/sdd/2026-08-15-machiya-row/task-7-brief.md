### Task 7: `Chaya.luau` + DockDeck — OWNER GATE

**Files:**
- Create: `roblox/tools/builders/Chaya.luau`; generated `roblox/assets/Chaya.model.json`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`, `roblox/src/shared/WorkspaceConvention.luau`
- Test: `roblox/tests/Chaya.spec.luau`

**Interfaces:**
- Consumes: Task 2's survey record for `Machiya_2` (envelope, floorY) + `DockDeck` (pivot, size); `Spec.part/model/cframe`, `ZenDojo.palette`.
- Produces: `Chaya.build(palette: any, layout: any) -> Spec.PartSpec` (site literals live IN the builder with the survey comment, hanabiya-style); stage model `Chaya` containing the pavilion + the dock deck; the invisible anchor part **`ChayaKeeperSlot`**.

- [ ] **Step 1: Write the failing tests**:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Chaya = require("../tools/builders/Chaya")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")

local m = Chaya.build(ZenDojo.palette, ArenaLayout)
-- reuse the allParts/find helpers pattern from Machiya.spec (copy them in; the
-- harness has no shared helpers module)

describe("chaya", function()
    test("the counter splits the floor: keeper slot behind, bench in front", function()
        local counter = find(m, "Counter")
        local slot = find(m, "ChayaKeeperSlot")
        local bench = find(m, "Bench")
        expect(counter ~= nil and slot ~= nil and bench ~= nil).toBe(true)
        -- slot is on the working side (behind the counter's back face), bench on the customer side
    end)
    test("the keeper slot is clear: avatar-width, nothing intersects it", function()
        local slot = find(m, "ChayaKeeperSlot")
        expect(slot.properties.Size[1] >= 4 and slot.properties.Size[3] >= 4).toBe(true)
        expect(slot.properties.Size[2] >= 7).toBe(true) -- head height
        expect(slot.properties.Transparency).toBe(1)
        expect(slot.properties.CanCollide).toBe(false)
        for _, p in allParts(m) do
            if p.name ~= "ChayaKeeperSlot" then
                expect(intersects(p, slot)).toBe(false) -- AABB overlap helper, write it in this file
            end
        end
    end)
    test("gear is within reach of the slot", function()
        local slot = find(m, "ChayaKeeperSlot")
        for _, name in { "Brazier", "Kettle", "CaddyShelf" } do
            local g = find(m, name)
            expect(g ~= nil).toBe(true)
            local dx = math.abs(g.properties.CFrame[1] - slot.properties.CFrame[1])
            local dz = math.abs(g.properties.CFrame[3] - slot.properties.CFrame[3])
            expect(math.sqrt(dx * dx + dz * dz) <= 6).toBe(true) -- a step-and-reach, in studs≈feet
        end
    end)
    test("dock deck edges are flush: boards end on the frame, not past it", function()
        local deck = find(m, "DockDeck")
        expect(deck ~= nil).toBe(true)
        -- assert every board's outer face <= the frame's outer face on both axes
    end)
end)
```

- [ ] **Step 2: Run, verify fails.**
- [ ] **Step 3: Build `Chaya.luau`.** Site literals from the Task-2 survey (Machiya_2: pivot ~(−57.4, 118.4, 14.9), 14.4 × 13.2 — re-read the exact surveyed values from MachiyaShops' comment block; floorY from its probes). Structure, all from `Spec.part`/`Spec.model`: 4–6 posts (0.45², `CypressWeathered` per the dock's treatment — grep the variant name from `FallsDock.luau` and reuse it), raised floor slab (0.6, the recipe deck slab), gabled roof (two tilted slabs + end boards, `rotX` matrices per the Teahouse.luau pattern — NOT a mesh); **service counter** front-of-centre (COUNTER_H 3.0, 2.0 deep, spanning ~70% of width) splitting the floor; working side: `ChayaKeeperSlot` (invisible, 4 × 7.5 × 4, CanCollide false, CanQuery false), `Brazier` (1.4 dia × 1.0 cylinder + inner glow part), `Kettle` (0.8 sphere + 0.3 spout cylinder) ON the counter back edge, `CaddyShelf` (rear shelf 0.4 × 5.0 at 4.5) with four 0.4 caddy cylinders + two 0.25-cube cup stacks; customer side: `Bench` (5.5 × 1.4 seat at 1.5 + legs) facing the water (−Z per the site), two 1.6 × 0.2 floor cushions; half-noren across the front eave (3 segments, `NorenCloth` variant). **DockDeck**: at its surveyed pivot/size, framed post-and-board deck per `docs/wiki/practice/build-recipes.md` deck recipe — outer boards flush with the frame faces (the flush rule), 4 posts to the riverbed, board gaps 0.1.
- [ ] **Step 4: Run tests → pass; full suite; lint.**
- [ ] **Step 5: Register + emit** — genmodels `OUTPUTS["Chaya"] = Chaya.build(ZenDojo.palette, ArenaLayout)`; project.json + WorkspaceConvention (`"Chaya", -- riverside tea stand + dock (assets/Chaya.model.json)`); byte gate on Hanabiya still exit 0.
- [ ] **Step 6: Commit** — `feat(roblox): riverside chaya + dock — counter, keeper slot, gear`.
- [ ] **Step 7: OWNER GATE** — as Task 4 Step 7.

---

