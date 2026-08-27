### Task 3: The archetype grows its variants — frontage, interior, yaw, identity kit

**Files:**
- Modify: `roblox/tools/builders/Machiya.luau`
- Test: `roblox/tests/Machiya.spec.luau` (add a variants describe-block)

**Interfaces:**
- Consumes: `Shop` tables from Tasks 1–2.
- Produces: `Machiya.build` honoring all Shop fields, plus the identity-kit contract used by Tasks 4–6:

```lua
-- shop.identity = {
--     noren = { color: {number}, segments: number }?,   -- nil = no noren
--     chochin = boolean?,                                -- eave chōchin pair, 花火屋 pattern
--     board = boolean?,                                  -- blank exterior board (sports book)
--     glow = { color: {number}, brightness: number }?,   -- interior PointLights
--     dress = ((ctx: DressCtx) -> { any })?,             -- returns PartSpecs, parented into the model
-- }
-- DressCtx = { env = {x0,x1,z0,z1,floorY,w,d,cx,cz}, palette: any,
--              consts = { SLAB_T: number, COUNTER_H: number, POST_W: number, KOSHI_T: number } }
```

- [ ] **Step 1: Write the failing variant tests** (against a synthetic shop so no survey dependency):

```lua
local SHELL = {
    name = "TestShell",
    envelope = { x0 = 0, x1 = 16, z0 = 100, z1 = 113, floorY = 113.10 },
    yaw = 0, frontage = "open", interior = "shallow",
}
describe("machiya variants", function()
    test("shallow interior emits no stair, no attic, no well", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, SHELL)
        for _, p in allParts(m) do
            expect(string.find(p.name, "Stair") == nil).toBe(true)
            expect(string.find(p.name, "Attic") == nil).toBe(true)
        end
    end)
    test("koshi frontage closes the street wall and opens nothing", function()
        local closed = table.clone(SHELL); closed.frontage = "koshi"; closed.interior = "none"
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, closed :: any)
        local sawKoshi = false
        for _, p in allParts(m) do
            if string.find(p.name, "KoshiFront") then sawKoshi = true end
            expect(string.find(p.name, "Counter") == nil).toBe(true)
        end
        expect(sawKoshi).toBe(true)
    end)
    test("yaw rotates every part about the envelope centre", function()
        local turned = table.clone(SHELL); turned.yaw = 90
        local m0 = Machiya.build(ZenDojo.palette, ArenaLayout, SHELL)
        local m1 = Machiya.build(ZenDojo.palette, ArenaLayout, turned :: any)
        local a = allParts(m0)[1].properties.CFrame
        local b = allParts(m1)[1].properties.CFrame
        -- centre (8, 106.5): x' = cx + (z - cz), z' = cz - (x - cx) for +90°
        expect(b[1]).toBeCloseTo(8 + (a[3] - 106.5), 0.01)
        expect(b[3]).toBeCloseTo(106.5 - (a[1] - 8), 0.01)
    end)
end)
```

(`allParts` already exists in Machiya.spec — reuse it.)
- [ ] **Step 2: Run, verify the three fail** (the Task-1 assert rejects them).
- [ ] **Step 3: Implement.** In `Machiya.luau`: remove the Task-1 assert; gate the stair/attic/well/counter emission behind `shop.interior == "full"` (shallow keeps slab/posts/walls/roof/upper-lattice; none additionally skips interior lighting hooks); add the `koshi` frontage branch — where `open` emits the six-post frontage + bays, `koshi` emits full-width lattice panels named `KoshiFront_<i>` (reuse the existing kōshi lattice constants `KOSHI_T`/`FRAME_VAR` from the upper storey) with a timber frame on the frontage plane; implement `shop.identity` per the contract (noren via the existing segment-chain emission generalized to take color/segments; chochin via the eave-corner recipe already in the file's sign/chochin region; `board` = one blank `SignBoard` slab on the frontage plane above the kamoi; `glow` = anchored invisible parts with PointLight children named `InteriorGlow_<i>`; `dress` called last, its returned specs appended under a `Dressing` child model). Apply `shop.yaw` as the FINAL pass: for every part, `CFrame` position → `Spec.rotY(pos − centre) + centre` and rotation → `Spec.matMul(Spec.rotYMat(shop.yaw), rot)` (exact helper names per `Spec.luau:74-93`).
  **花火屋's identity stays inline** where it is, still behind `interior == "full"` — do not migrate it to the kit in this task.
- [ ] **Step 4: Run the suite** → variant tests pass, every existing Machiya test passes.
- [ ] **Step 5: The byte gate** — genmodels; `git diff --exit-code assets/Hanabiya.model.json` → exit 0.
- [ ] **Step 6: Lint, commit** — `feat(roblox): machiya variants — koshi frontage, shallow/none interiors, yaw, identity kit`.

---

