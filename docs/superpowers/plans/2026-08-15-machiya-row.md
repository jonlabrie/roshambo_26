# Machiya Row Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build friends-and-family item 4 — the machiya merchant row (apparel, accessories, sports-book teaser) plus the riverside chaya + dock, by generalizing the 花火屋 builder behind a byte-identical snapshot gate.

**Architecture:** `Machiya.luau` (1,183 lines, 花火屋-specific) becomes a parameterized archetype taking a per-shop spec table from a new `MachiyaShops.luau`; the committed `assets/Hanabiya.model.json` is the refactor's snapshot gate (byte-identical or the refactor changed something). Shells are surveyed from the owner's massing blocks in Studio, emitted through the existing `genmodels`→Rojo pipeline, and each is owner-gated visually. `Chaya.luau` is a separate small builder (open pavilion ≠ machiya).

**Tech Stack:** Luau (Lune test harness, bespoke — `lune run tests/run` from `roblox/`), Rojo, stylua/selene, Roblox Studio MCP for surveys.

**Spec:** `docs/superpowers/specs/2026-08-15-machiya-row-design.md`

## Global Constraints

- Work from `roblox/` for all Luau commands: tests `~/.rokit/bin/lune run tests/run`; regenerate models `~/.rokit/bin/lune run tools/genmodels`; lint `~/.rokit/bin/stylua --check src tests tools && ~/.rokit/bin/selene src tools` (selene FAILS on warnings — CI scope, match it).
- **The snapshot gate:** after ANY change to `Machiya.luau`/`MachiyaShops.luau` that should not move 花火屋, run genmodels then `git diff --exit-code roblox/assets/Hanabiya.model.json`. A non-empty diff fails the task.
- Committed `assets/*.model.json` are generated — never hand-edit. They must be byte-stable across arm64/x86_64 (no trig-derived floats in specs except through `Spec.rotY`/`Spec.yaw`, which are JsonEmit-rounded and CI-proven).
- New stage models need BOTH: an entry in `roblox/default.project.json` under `RoshamboStage` (`"<Name>": { "$path": "assets/<Name>.model.json" }`) AND the name + comment in `roblox/src/shared/WorkspaceConvention.luau`'s `DECLARED_STAGE_CHILDREN`. Rojo re-reads project.json only on plugin reconnect.
- Spec §1 guards run per shell: top ≤ `ArenaLayout.towerTopY − 9.0`; kamoi 6.8; eave encroachment aerial-only; timber faces exactly on the frontage plane, stucco set back (flush-outside-edges + derive-from-what-it-touches, `docs/wiki/practice/`).
- Owner-surveyed envelopes are literals, never derived. 1 stud ≈ 1 foot for dressing scale sanity (a counter is ~3.0, a shelf ~5–6, a teacup ~0.25).
- **OWNER GATE protocol** (tasks 4–7): after genmodels + tests pass, STOP. Report to the controller that the shell is ready to view (owner reconnects Rojo / syncs, looks in Studio). ONE visual attempt — never self-judge and iterate ([[stop-and-ask-after-each-attempt]] is a standing rule). The controller relays corrections; treat them as new requirements.
- No toolbox imports, ever. No signage copy for the sports book (wager-language ruling). Kanban textures only via the existing glyph pipeline and only if a task explicitly says so — otherwise geometry/blank boards.
- Wiki (`docs/wiki/`): each owner gate and each shipped shell updates `program/item-4-merchant-row.md` and appends a `log.md` entry (`## [YYYY-MM-DD] gate | ...` / `ship | ...`), same commit. Wiki lint must stay clean: `source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs` (repo root).
- Commits end with:

  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  ```
- Never commit `.rbxl`/`.rbxlx`. Studio MCP calls need `studio_id` from `list_roblox_studios` and `datamodel_type: "Edit"`.

---

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

### Task 8: Close item 4's build pass

**Files:**
- Modify: `docs/wiki/program/item-4-merchant-row.md`, `docs/wiki/world/arena-square.md` (street one-liner), `docs/wiki/log.md`; create `docs/wiki/world/merchant-row.md` ONLY if the item-4 page's as-built section has outgrown a status page (implementer's judgment, schema rules apply)

- [ ] **Step 1:** After the last gate: update item-4 (shells shipped + gates listed; remaining = commerce hookup at items 6/7, cavern at item 7, NPC later), append `## [date] ship | merchant row shells + chaya shipped` to log.
- [ ] **Step 2:** Wiki lint (repo root, nvm-prefixed) → 0 errors; full Luau suite + stylua/selene once more.
- [ ] **Step 3:** Commit `docs(wiki): item 4 build pass closed` and push (`git push` — the branch auto-deploys the dev server; these are client/builder assets, safe).
- [ ] **Step 4:** Remind the controller: the place needs a Studio SAVE by the owner (Rojo-synced stage children live in the place file too), and `place-state.md`'s inventory should gain the new stage children.

