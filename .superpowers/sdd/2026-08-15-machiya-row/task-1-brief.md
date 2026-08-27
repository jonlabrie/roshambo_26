### Task 1: Extract the shop spec — refactor `Machiya.luau` behind the byte gate

**Files:**
- Create: `roblox/tools/builders/MachiyaShops.luau`
- Modify: `roblox/tools/builders/Machiya.luau` (signature + envelope/storey extraction), `roblox/tools/genmodels.luau:55`, `roblox/tests/Machiya.spec.luau:8` (call sites only)
- Test: `roblox/tests/MachiyaShops.spec.luau` (new)

**Interfaces:**
- Produces: `Machiya.build(palette: any, layout: any, shop: MachiyaShops.Shop) -> Spec.PartSpec` and the `Shop` shape every later task fills:

```lua
export type Shop = {
    name: string,          -- model name, e.g. "Hanabiya"
    envelope: { x0: number, x1: number, z0: number, z1: number, floorY: number },
    yaw: number,           -- degrees about the envelope centre; 0 = frontage faces north (−Z→z0 side), applied in Task 3
    frontage: "open" | "koshi",
    interior: "full" | "shallow" | "none",   -- full = 花火屋's stair/attic/counter/well
    storeys: { ground: number, upper: number }?,  -- nil = archetype defaults (9.0 / 5.0)
    identity: { [string]: any }?,            -- Task 3 defines the kit; nil in Task 1
}
```

- [ ] **Step 1: Write the failing test** — `roblox/tests/MachiyaShops.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MachiyaShops = require("../tools/builders/MachiyaShops")

describe("MachiyaShops registry", function()
    test("hanabiya carries the owner's envelope verbatim", function()
        local h = MachiyaShops.hanabiya
        expect(h.name).toBe("Hanabiya")
        expect(h.envelope.x0).toBe(-1.67)
        expect(h.envelope.x1).toBe(16.26)
        expect(h.envelope.z0).toBe(36.00)
        expect(h.envelope.z1).toBe(52.00)
        expect(h.envelope.floorY).toBe(113.10)
        expect(h.yaw).toBe(0)
        expect(h.frontage).toBe("open")
        expect(h.interior).toBe("full")
    end)
end)
```

- [ ] **Step 2: Run it, verify it fails** — `cd roblox && ~/.rokit/bin/lune run tests/run` → FAIL (module not found).

- [ ] **Step 3: Create `MachiyaShops.luau`** — the registry module. Move the ownership comment with the numbers:

```lua
--!strict
-- Per-shop spec tables for the Machiya archetype (design spec
-- docs/superpowers/specs/2026-08-15-machiya-row-design.md). EVERY envelope here is
-- the OWNER'S, measured from a holdout/massing block in Studio and read back as
-- literals. Do not re-derive them from anything.
local MachiyaShops = {}

export type Shop = {
    name: string,
    envelope: { x0: number, x1: number, z0: number, z1: number, floorY: number },
    yaw: number,
    frontage: "open" | "koshi",
    interior: "full" | "shallow" | "none",
    storeys: { ground: number, upper: number }?,
    identity: { [string]: any }?,
}

-- 花火屋 — measured from the holdout the owner placed 2026-08-05; front deepened
-- z44 -> z36 at the owner's direction 2026-08-13. See Machiya.luau's history notes.
MachiyaShops.hanabiya = {
    name = "Hanabiya",
    envelope = { x0 = -1.67, x1 = 16.26, z0 = 36.00, z1 = 52.00, floorY = 113.10 },
    yaw = 0,
    frontage = "open",
    interior = "full",
} :: Shop

return MachiyaShops
```

- [ ] **Step 4: Refactor `Machiya.luau` mechanically.** Rules (the implementer reads the whole file; these rules are exhaustive for THIS task):
  1. Signature: `function Machiya.build(palette: any, _layout: any, shop: any): any`. First lines bind the old names so the 1,000+ lines below compile untouched: `local X0, X1 = shop.envelope.x0, shop.envelope.x1`, `local Z0, Z1 = shop.envelope.z0, shop.envelope.z1`, `local FLOOR = shop.envelope.floorY`, `local STOREY_H = (shop.storeys and shop.storeys.ground) or 9.0`, `local UPPER_H = (shop.storeys and shop.storeys.upper) or 5.0`. Delete the old literal declarations of those five (keep every comment — move each onto its replacement line or into MachiyaShops where the number went). The model's name comes from `shop.name` (find where the root `Spec.model("Hanabiya", ...)` — or genmodels' key — names it; the root model must be built with `shop.name`).
  2. `shop.frontage`/`shop.interior`/`shop.yaw` are ACCEPTED but, in this task, only asserted: add at top `assert(shop.frontage == "open" and shop.interior == "full" and shop.yaw == 0, "only the hanabiya configuration is implemented until Task 3")`. No behavioral branches yet — that keeps the byte gate honest.
  3. Everything else (posts, bays, roof, stair, attic, counter, noren, sign) stays byte-for-byte where it is.
- [ ] **Step 5: Update call sites** — `genmodels.luau:55` → `Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.hanabiya)` (add `local MachiyaShops = require("./builders/MachiyaShops")`); `tests/Machiya.spec.luau:8` likewise (require path `../tools/builders/MachiyaShops`).
- [ ] **Step 6: Run the suite** — `~/.rokit/bin/lune run tests/run` → all pass (Machiya.spec's envelope literals now double-check the registry's).
- [ ] **Step 7: The byte gate** — `~/.rokit/bin/lune run tools/genmodels && git diff --exit-code assets/Hanabiya.model.json` → exit 0. Any diff = find what moved; do not commit until empty.
- [ ] **Step 8: Lint** — `~/.rokit/bin/stylua --check src tests tools && ~/.rokit/bin/selene src tools`.
- [ ] **Step 9: Commit** — `git add roblox/tools/builders/Machiya.luau roblox/tools/builders/MachiyaShops.luau roblox/tools/genmodels.luau roblox/tests/Machiya.spec.luau roblox/tests/MachiyaShops.spec.luau` · message `refactor(roblox): Machiya takes a shop spec; hanabiya proven unchanged by the byte gate`.

---

