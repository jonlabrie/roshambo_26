# Karesansui Square Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Tasks marked [MAIN SESSION] need Studio MCP / user gates and must NOT be dispatched to subagents.**

**Goal:** Build the framed, viewed karesansui garden wrapping the pavilion's east and south flanks — slate kerb, raked-sand field, low guard, tag-driven ripple rings around place-only boulders — with plaza-width thoroughfare reservations baked into ArenaLayout.

**Architecture:** Generated asset (`Karesansui.model.json`: kerb + slabs + guards from a new `ArenaLayout.karesansui` block, TerraceDressing pattern) + a deterministic Node texture tool feeding two place-side MaterialVariants + a pure `RakingMesh` module assembled client-side by `KaresansuiController` around `KaresansuiIsland`-tagged rocks (CamMesh pattern).

**Tech Stack:** Luau + Lune harness, Rojo model.json assets, Node (dependency-free PNG gen, glyphgen precedent), Studio MCP for survey/upload/gates.

**Spec:** `docs/superpowers/specs/2026-07-24-karesansui-square-design.md`

## Global Constraints

- All roblox commands from `roblox/`: `lune run tests/run`, `lune run tools/genmodels`, `stylua --check src tests tools`, `selene src tools` (warnings fail CI). Commit per task with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.
- `src/shared/` modules are pure/DI — no Roblox APIs; only `.client.luau`/`.server.luau` touch the engine.
- Generated assets must be byte-identical across arches: integer-LCG randomness only, no transcendental-seeded jitter (genmodels portability rule).
- Layout rects are `{x1, z1, x2, z2}` world studs, axis-aligned, on the terrace floor (`floorY = 112`). Kerb width 0.8, kerb proud 0.5, slab proud 0.15, guard height 3.5, guard CollisionGroup `"EngawaBarrier"` (already registered in the place by the engawa-barrier build — verify at the Task 6 gate, do NOT re-register in code).
- Corridors are inviolable: no kerb/slab/guard part may intersect `shopCorridor` or `eastCorridor` (test-pinned).
- Standing rules: consult `docs/superpowers/references/zendojo-canyon-build-recipes.md` before Studio work; ONE visual attempt then stop-and-ask; save/publish the place after place-only changes.

---

### Task 1: [MAIN SESSION] Survey + `ArenaLayout.karesansui` block + geometry tests

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau` (new `karesansui` block after `bellDrive`)
- Test: `roblox/tests/ArenaLayout.spec.luau` (append a describe)

**Interfaces:**
- Produces: `ArenaLayout.karesansui = { floorY, kerbW = 0.8, kerbProud = 0.5, slabProud = 0.15, guardH = 3.5, panels = { east = {x1,z1,x2,z2}, south = {...} }, corridors = { shopCorridor = {...}, eastCorridor = {...} } }`. Task 2 consumes exactly this shape.

- [ ] **Step 1: Survey in Studio (Edit datamodel, execute_luau)**

Measure and record (world X/Z extents at terrace level y≈112–114):
- Portal deck west face and full footprint (the big deck east of the pavilion)
- ArenaSpawn pad rect (declared at CFrame x30, z8, size 8×8 — verify placed reality)
- Stair/bridge feet touching the terrace (south stair, NE bridge landing)
- Pavilion post positions (nominal ±9 from `pavilion.pos` {-2, 112, 0}) and the bearing-plinth line (x −15)
- Terrace usable extents (terrain edge / river bank to the north, slope breaks east/south)
- The flank where the merchant row will stand (west/northwest upslope edge)

One probe script per group, raycast down from y130 where needed (separate calls from any terrain edits; Terrain reads are stale in the same call).

- [ ] **Step 2: Choose rectangles from measurements**

Rules: `shopCorridor` and `eastCorridor` 16–20 studs wide, running the full length of their flanks (shop corridor along the merchant flank; east corridor between the east panel's kerb and the portal deck face, jogging to keep the ArenaSpawn pad fully inside corridor ground, never garden). Every other kerb edge ≥ 8 studs from the nearest obstruction (posts, plinths, stair feet, terrace edge). Panels are what remains: east panel fronting the tower, south panel along the gathering side. Machine sightlines: the line from the east corridor to the bell must cross the east panel.

- [ ] **Step 3: Write the failing tests**

Append to `roblox/tests/ArenaLayout.spec.luau`:

```lua
describe("karesansui garden layout (spec 2026-07-24)", function()
    local K = L.karesansui
    local function overlaps(a: { number }, b: { number }): boolean
        return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
    end
    test("panels and corridors exist with sane extents", function()
        for _, name in { "east", "south" } do
            local r = K.panels[name]
            expect(r[3] > r[1]).toBe(true)
            expect(r[4] > r[2]).toBe(true)
        end
        for _, name in { "shopCorridor", "eastCorridor" } do
            local c = K.corridors[name]
            local w = math.min(c[3] - c[1], c[4] - c[2])
            expect(w >= 16).toBe(true) -- plaza-width main streets
        end
    end)
    test("no panel touches a corridor (the plaza is the point)", function()
        for _, p in K.panels :: any do
            for _, c in K.corridors :: any do
                expect(overlaps(p, c)).toBe(false)
            end
        end
    end)
    test("panels clear the machine ground: pavilion posts and the plinth line", function()
        local px, pz = L.pavilion.pos[1], L.pavilion.pos[3]
        local s = L.pavilion.postSpacing / 2
        for _, cx in { px - s, px + s } do
            for _, cz in { pz - s, pz + s } do
                for _, p in K.panels :: any do
                    local inside = cx > p[1] and cx < p[3] and cz > p[2] and cz < p[4]
                    expect(inside).toBe(false)
                end
            end
        end
        for _, p in K.panels :: any do
            expect(p[1] > -15 + 2).toBe(true) -- east of the bearing-plinth line
        end
    end)
    test("frame constants match the spec", function()
        expect(K.kerbW).toBeCloseTo(0.8, 0.001)
        expect(K.kerbProud).toBeCloseTo(0.5, 0.001)
        expect(K.slabProud).toBeCloseTo(0.15, 0.001)
        expect(K.guardH).toBeCloseTo(3.5, 0.001)
    end)
end)
```

Run `lune run tests/run` — the new describe FAILS (`K` is nil).

- [ ] **Step 4: Add the layout block**

In `roblox/tools/builders/ArenaLayout.luau`, after the `bellDrive` table:

```lua
    -- ===== Karesansui garden (spec 2026-07-24): framed VIEWED garden, plaza-first =====
    -- SURVEYED rects {x1, z1, x2, z2} on the terrace floor — measured in Studio at
    -- Task 1, never derived from placed parts. Corridors are the square's main
    -- streets (crowd-width, inviolable); the merchant row later builds against the
    -- SAME shopCorridor reservation.
    karesansui = {
        floorY = 112,
        kerbW = 0.8, -- dressed-slate frame (bearing-plinth vocabulary)
        kerbProud = 0.5,
        slabProud = 0.15, -- raked field rides proud of the terrace like flags-of-bed
        guardH = 3.5, -- EngawaBarrier low guard: blocks walking, never traps jumpers
        panels = {
            east = { 8, -12, 22, 14 }, -- REPLACE with surveyed values
            south = { -12, 17, 22, 27 }, -- REPLACE with surveyed values
        },
        corridors = {
            shopCorridor = { -30, -12, -14, 27 }, -- REPLACE with surveyed values
            eastCorridor = { 24, -12, 42, 14 }, -- REPLACE with surveyed values
        },
    },
```

Replace the four rects with the Step 2 numbers. Run `lune run tests/run` — all green (if a rule test fails, the RECTS are wrong, not the test).

- [ ] **Step 5: Lint + commit**

`stylua --check src tests tools && selene src tools`, then:

```bash
git add roblox/tools/builders/ArenaLayout.luau roblox/tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): karesansui layout block — surveyed panels + inviolable plaza corridors"
```

---

### Task 2: Karesansui builder + generated asset + stage wiring

**Files:**
- Create: `roblox/tools/builders/Karesansui.luau`
- Modify: `roblox/tools/genmodels.luau` (registry entry), `roblox/default.project.json` (stage child), `roblox/src/shared/WorkspaceConvention.luau` (DECLARED_STAGE_CHILDREN)
- Test: `roblox/tests/Karesansui.spec.luau` (new); check `roblox/tests/WorkspaceConvention.spec.luau` for a pinned child list and update it too if present
- Generated: `roblox/assets/Karesansui.model.json`

**Interfaces:**
- Consumes: `ArenaLayout.karesansui` (Task 1 shape), `Spec.part`/`Spec.model` (`tools/builders/Spec.luau`), `ZenDojo.palette.gravel`.
- Produces: model `Karesansui` with, PER PANEL `<name>` in {East, South}: `Kerb<name>N/S/E/W` (4 parts), `Field<name>` (1 slab), `Guard<name>N/S/E/W` (4 invisible walls). Field MaterialVariant: `RakedSandNS` when the panel is taller (Z-extent) than wide, else `RakedSandEW`.

- [ ] **Step 1: Write the failing tests**

Create `roblox/tests/Karesansui.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Karesansui = require("../tools/builders/Karesansui")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Karesansui garden (kerb + field + guard)", function()
    local spec = Karesansui.build(ZenDojo.palette, L)
    local K = L.karesansui
    local byName = {}
    for _, c in spec.children :: any do
        byName[c.name] = c
    end
    local function rectOf(part): { number } -- world XZ rect from CFrame + Size
        local cf, sz = part.properties.CFrame, part.properties.Size
        return { cf[1] - sz[1] / 2, cf[3] - sz[3] / 2, cf[1] + sz[1] / 2, cf[3] + sz[3] / 2 }
    end
    local function overlaps(a: { number }, b: { number }): boolean
        return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
    end
    test("every panel emits kerb x4, field, guard x4 — and nothing else", function()
        local count = 0
        for _, panel in { "East", "South" } do
            for _, side in { "N", "S", "E", "W" } do
                expect(byName[`Kerb{panel}{side}`] ~= nil).toBe(true)
                expect(byName[`Guard{panel}{side}`] ~= nil).toBe(true)
                count += 2
            end
            expect(byName[`Field{panel}`] ~= nil).toBe(true)
            count += 1
        end
        expect(#(spec.children :: any)).toBe(count)
    end)
    test("NOTHING intersects the corridors (the inviolable rule)", function()
        for _, c in spec.children :: any do
            for _, corr in K.corridors :: any do
                expect(overlaps(rectOf(c), corr)).toBe(false)
            end
        end
    end)
    test("fields sit inside their kerbs, proud of the terrace", function()
        for i, panel in { "East", "South" } do
            local key = if panel == "East" then "east" else "south"
            local p = K.panels[key]
            local f = rectOf(byName[`Field{panel}`])
            expect(f[1] >= p[1]).toBe(true)
            expect(f[2] >= p[2]).toBe(true)
            expect(f[3] <= p[3]).toBe(true)
            expect(f[4] <= p[4]).toBe(true)
            local cf = byName[`Field{panel}`].properties.CFrame
            local sz = byName[`Field{panel}`].properties.Size
            expect(cf[2] + sz[2] / 2).toBeCloseTo(K.floorY + K.slabProud, 0.001)
        end
    end)
    test("guards: invisible, 3.5 tall, EngawaBarrier group, on the kerb lines", function()
        for _, panel in { "East", "South" } do
            for _, side in { "N", "S", "E", "W" } do
                local g = byName[`Guard{panel}{side}`]
                expect(g.properties.Transparency).toBe(1)
                expect(g.properties.Size[2]).toBeCloseTo(K.guardH, 0.001)
                expect(g.properties.CollisionGroup).toBe("EngawaBarrier")
                expect(g.properties.CanCollide).toBe(true)
            end
        end
    end)
    test("kerb wears the plinth vocabulary: Slate, gravel palette, proud", function()
        local k = byName.KerbEastN
        expect(k.properties.Material).toBe("Slate")
        local top = k.properties.CFrame[2] + k.properties.Size[2] / 2
        expect(top).toBeCloseTo(K.floorY + K.kerbProud, 0.001)
    end)
    test("field variants follow the panel's long axis", function()
        for _, panel in { "East", "South" } do
            local key = if panel == "East" then "east" else "south"
            local p = K.panels[key]
            local want = if (p[4] - p[2]) >= (p[3] - p[1]) then "RakedSandNS" else "RakedSandEW"
            expect(byName[`Field{panel}`].properties.MaterialVariant).toBe(want)
        end
    end)
end)
```

Run — FAILS (module not found).

- [ ] **Step 2: Implement the builder**

Create `roblox/tools/builders/Karesansui.luau`:

```lua
--!strict
-- Framed VIEWED karesansui garden (spec 2026-07-24): dressed-slate kerb, raked-sand
-- field slab, and a low invisible EngawaBarrier guard, per surveyed panel. Boulder
-- islands are PLACE-ONLY (tagged KaresansuiIsland); ripple rings are client-built
-- (RakingMesh) — this builder emits only the frame and field.
local Spec = require("./Spec")

local Karesansui = {}

function Karesansui.build(palette: any, L: any): Spec.PartSpec
    local K = L.karesansui
    local children: { Spec.PartSpec } = {}
    local kerbH = 1.2 -- rooted below grade; top = floorY + kerbProud
    local kerbTopY = K.floorY + K.kerbProud
    local slabTopY = K.floorY + K.slabProud

    local function panel(name: string, r: { number })
        local x1, z1, x2, z2 = r[1], r[2], r[3], r[4]
        local w = K.kerbW
        -- kerb: N/S beams span the full width; E/W beams inset between them (mitre-read)
        local beams = {
            N = { (x1 + x2) / 2, z1 + w / 2, x2 - x1, w },
            S = { (x1 + x2) / 2, z2 - w / 2, x2 - x1, w },
            W = { x1 + w / 2, (z1 + z2) / 2, w, z2 - z1 - 2 * w },
            E = { x2 - w / 2, (z1 + z2) / 2, w, z2 - z1 - 2 * w },
        }
        for side, b in beams do
            table.insert(
                children,
                Spec.part(`Kerb{name}{side}`, {
                    Size = { b[3], kerbH, b[4] },
                    CFrame = Spec.cframe({ b[1], kerbTopY - kerbH / 2, b[2] }),
                    Color = palette.gravel,
                    Material = "Slate",
                })
            )
            table.insert(
                children,
                Spec.part(`Guard{name}{side}`, {
                    Size = { b[3], K.guardH, b[4] },
                    CFrame = Spec.cframe({ b[1], kerbTopY + K.guardH / 2, b[2] }),
                    Transparency = 1,
                    CanCollide = true,
                    CollisionGroup = "EngawaBarrier",
                    CanQuery = false,
                    CanTouch = false,
                    CastShadow = false,
                })
            )
        end
        -- field slab inside the kerb, proud of the terrace
        local fw, fd = (x2 - x1) - 2 * w, (z2 - z1) - 2 * w
        local variant = if (z2 - z1) >= (x2 - x1) then "RakedSandNS" else "RakedSandEW"
        table.insert(
            children,
            Spec.part(`Field{name}`, {
                Size = { fw, 0.4, fd },
                CFrame = Spec.cframe({ (x1 + x2) / 2, slabTopY - 0.2, (z1 + z2) / 2 }),
                Color = { 0.87, 0.85, 0.79 }, -- pale zen sand under the variant
                Material = "Sand",
                MaterialVariant = variant,
            })
        )
    end

    panel("East", K.panels.east)
    panel("South", K.panels.south)
    return Spec.model("Karesansui", children)
end

return Karesansui
```

(If `Spec.model` is named differently, match how `BellDrive.luau` returns its root — same call.)

- [ ] **Step 3: Wire the asset**

- `roblox/tools/genmodels.luau`: add `local Karesansui = require("./builders/Karesansui")` with the other builder requires, and `["Karesansui"] = Karesansui.build(ZenDojo.palette, ArenaLayout),` to the registry table.
- `roblox/default.project.json`: inside `RoshamboStage`, after `"SwitchbackDeck"`: `"Karesansui": { "$path": "assets/Karesansui.model.json" },`
- `roblox/src/shared/WorkspaceConvention.luau`: add `"Karesansui",` to `DECLARED_STAGE_CHILDREN` (after `"SwitchbackDeck"`); if a WorkspaceConvention spec pins the list, update it to match.

- [ ] **Step 4: Generate + verify green**

`lune run tools/genmodels && lune run tests/run && stylua --check src tests tools && selene src tools` — all green, `assets/Karesansui.model.json` created, no drift in other assets.

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/Karesansui.luau roblox/tests/Karesansui.spec.luau roblox/tools/genmodels.luau roblox/default.project.json roblox/src/shared/WorkspaceConvention.luau roblox/assets/Karesansui.model.json roblox/tests/WorkspaceConvention.spec.luau
git commit -m "feat(roblox): Karesansui generated asset — slate kerb, raked field slabs, EngawaBarrier guards"
```

---

### Task 3: Raked-sand texture tool

**Files:**
- Create: `roblox/tools/glyphs/rakedtex.cjs`
- Generated (committed): `roblox/tools/glyphs/raked/rakedsand_albedo_ns.png`, `rakedsand_albedo_ew.png`, `rakedsand_normal_ns.png`, `rakedsand_normal_ew.png`

**Interfaces:**
- Consumes: nothing (dependency-free Node, the glyphgen.cjs PNG-writer precedent — reuse its zlib/PNG encoding approach verbatim).
- Produces: four 512×512 tileable PNGs. Convention: the texture tile covers **8 studs** in-world (StudsPerTile = 8 at the Studio step), grooves at 0.8-stud pitch → **10 grooves per tile** (64 px pitch). NS = grooves running along image Y (world Z when applied); EW = the same rotated 90°.

- [ ] **Step 1: Write the tool**

`rakedtex.cjs`, structured like glyphgen.cjs (same PNG/zlib encoder functions — copy them):

```js
// Dependency-free raked-sand texture gen: tileable albedo + normal at 10 grooves/tile.
// Deterministic: integer LCG only (genmodels portability discipline).
const N = 512;
const PITCH = N / 10; // 64px = 0.8 studs at StudsPerTile 8
let seed = 20260724;
function lcg() { seed = (1103515245 * seed + 12345) % 2147483648; return seed / 2147483648; }

// height(x,y): cosine groove profile + LCG speckle; PERIODIC in both axes by construction
function height(x, y) {
    const phase = (2 * Math.PI * x) / PITCH;
    return 0.5 + 0.5 * Math.cos(phase); // crest at groove lines, trough between
}
// albedo: pale zen-sand base modulated by height + fine speckle
// normal: central differences of height with WRAPPED sampling (tileability), Y-up
//   nx = (h(x-1,y)-h(x+1,y))*S, nz = (h(x,y-1)-h(x,y+1))*S, ny = 1, normalize,
//   encode (n*0.5+0.5)*255 into RGB. S tuned so ridges read (~2.0).
// Emit NS (as computed) and EW (x/y swapped) for both albedo and normal.
```

Full implementation: generate the four buffers pixel-by-pixel, speckle = `0.9 + 0.2 * lcg()` multiplied into albedo channels (base RGB ≈ [222, 217, 202]), write PNGs with the copied encoder. End the script by asserting tileability: row 0 vs row N−1 and col 0 vs col N−1 of the height function differ by < 1e-9 (throw if not).

- [ ] **Step 2: Run + eyeball**

`node tools/glyphs/rakedtex.cjs` → four PNGs. Open the albedo locally (or `Read` them as images) — parallel pale grooves with subtle speckle, no visible seam when mentally tiled.

- [ ] **Step 3: Commit**

```bash
git add roblox/tools/glyphs/rakedtex.cjs roblox/tools/glyphs/raked/
git commit -m "feat(roblox): deterministic tileable raked-sand texture tool (albedo+normal, NS/EW)"
```

---

### Task 4: RakingMesh pure module

**Files:**
- Create: `roblox/src/shared/RakingMesh.luau`
- Test: `roblox/tests/RakingMesh.spec.luau`

**Interfaces:**
- Consumes: nothing (pure).
- Produces: `RakingMesh.build(g, segments)` where `g = { footprintR: number, maxR: number, pitch: number?, amplitude: number?, ridgeW: number? }` → `{ verts, normals, tris }` (CamMesh Mesh shape, LOCAL space centered on the island, XZ plane, ridges rising +Y). Ring radii start at `footprintR + pitch/2` and step by `pitch` (default 0.8) up to `maxR`; each ring is a triangular ridge cross-section (inner foot y0 → crest at `amplitude` (default 0.15) → outer foot y0), `ridgeW` wide (default 0.5), `segments` points around. `RakingMesh.ringRadii(g)` exposed separately for tests.

- [ ] **Step 1: Write the failing tests**

```lua
--!strict
local harness = require("./harness")
local RakingMesh = require("../src/shared/RakingMesh")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("RakingMesh (concentric ripple ridges)", function()
    local g = { footprintR = 2, maxR = 5.4, pitch = 0.8, amplitude = 0.15, ridgeW = 0.5 }
    test("ring radii ascend from the footprint at the pitch", function()
        local radii = RakingMesh.ringRadii(g)
        expect(#radii).toBe(4) -- 2.4, 3.2, 4.0, 4.8 (5.6 exceeds maxR)
        expect(radii[1]).toBeCloseTo(2.4, 0.001)
        for i = 2, #radii do
            expect(radii[i] - radii[i - 1]).toBeCloseTo(0.8, 0.001)
            expect(radii[i] + g.ridgeW / 2 <= g.maxR + 0.001).toBe(true)
        end
    end)
    test("mesh bookkeeping: verts/normals match, tris index in range, local-space", function()
        local m = RakingMesh.build(g, 24)
        expect(#m.verts).toBe(#m.normals)
        expect(#m.verts).toBe(4 * 3 * 24) -- rings x (inner,crest,outer) x segments
        expect(#m.tris).toBe(4 * 4 * 24) -- 2 quad strips x 2 tris per segment per ring
        for _, t in m.tris do
            for _, i in t do
                expect(i >= 1 and i <= #m.verts).toBe(true)
            end
        end
        local maxY, minY = -math.huge, math.huge
        for _, v in m.verts do
            maxY = math.max(maxY, v[2])
            minY = math.min(minY, v[2])
            expect(math.sqrt(v[1] ^ 2 + v[3] ^ 2) <= g.maxR + 0.001).toBe(true)
        end
        expect(maxY).toBeCloseTo(g.amplitude, 0.001)
        expect(minY).toBeCloseTo(0, 0.001)
    end)
    test("crest normals point up-ish, foot normals splay outward", function()
        local m = RakingMesh.build(g, 24)
        for i, v in m.verts do
            local n = m.normals[i]
            local len = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
            expect(math.abs(len - 1) < 0.01).toBe(true)
            expect(n[2] > 0).toBe(true) -- every normal has an upward component
        end
    end)
end)
```

Run — FAILS (module not found).

- [ ] **Step 2: Implement**

`RakingMesh.luau`: `ringRadii` = while-loop from `footprintR + pitch/2` stepping `pitch` while `r + ridgeW/2 <= maxR`. `build`: for each radius, three vertex circles (r − ridgeW/2 at y 0, r at y amplitude, r + ridgeW/2 at y 0), `segments` points each; normals: feet tilted (radial ± up blend, normalized: inner foot `(-cosθ*a, b, -sinθ*a)`, outer `(cosθ*a, b, sinθ*a)` with `a = amplitude/hyp, b = (ridgeW/2)/hyp, hyp = sqrt(amplitude² + (ridgeW/2)²)`), crest `(0,1,0)`; tris: two strips (inner→crest, crest→outer) wound so faces point up/outward. Pure Luau, `--!strict`, no Roblox APIs.

- [ ] **Step 3: Green + lint + commit**

`lune run tests/run && stylua --check src tests tools && selene src tools`, then:

```bash
git add roblox/src/shared/RakingMesh.luau roblox/tests/RakingMesh.spec.luau
git commit -m "feat(roblox): RakingMesh — pure concentric ripple-ridge geometry"
```

---

### Task 5: KaresansuiController (tag-driven ring assembly)

**Files:**
- Create: `roblox/src/client/KaresansuiController.client.luau`

**Interfaces:**
- Consumes: `RakingMesh` (Task 4), CollectionService tag `KaresansuiIsland` (place-only rocks), `workspace.RoshamboStage.Karesansui` (Task 2 asset — used only as the parent for spawned rings).

- [ ] **Step 1: Implement**

```lua
--!strict
-- Builds the karesansui ripple rings around every KaresansuiIsland-tagged rock at
-- boot (EditableMesh doesn't replicate and Rojo JSON can't carry mesh geometry —
-- the CamMesh pattern). Move/add/remove a tagged boulder in Studio and the rings
-- follow on the next Play; no code edits. Rings are VISUAL ONLY (spec).
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local RakingMesh = require(shared:WaitForChild("RakingMesh"))

local stage = workspace:WaitForChild("RoshamboStage")
local garden = stage:WaitForChild("Karesansui")

local SEGMENTS = 48
local PITCH = 0.8 -- matches the field texture's groove pitch
local AMPLITUDE = 0.15
local RIDGE_W = 0.5
local RING_BAND = 3.2 -- ripple field extends this far beyond the island footprint

local SAND = Color3.new(0.87, 0.85, 0.79) -- matches the Field slabs

local function buildRings(island: BasePart)
    local footprintR = math.max(island.Size.X, island.Size.Z) / 2
    local g = {
        footprintR = footprintR,
        maxR = footprintR + RING_BAND,
        pitch = PITCH,
        amplitude = AMPLITUDE,
        ridgeW = RIDGE_W,
    }
    local ok, err = pcall(function()
        local m = RakingMesh.build(g, SEGMENTS)
        local em = AssetService:CreateEditableMesh()
        local vids, nids = table.create(#m.verts), table.create(#m.normals)
        for i, v in m.verts do
            vids[i] = em:AddVertex(Vector3.new(v[1], v[2], v[3]))
            nids[i] = em:AddNormal(Vector3.new(m.normals[i][1], m.normals[i][2], m.normals[i][3]))
        end
        for _, t in m.tris do
            local f = em:AddTriangle(vids[t[1]], vids[t[2]], vids[t[3]])
            em:SetFaceNormals(f, { nids[t[1]], nids[t[2]], nids[t[3]] })
        end
        local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
        part.Name = "RakingRings"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Sand
        part.Color = SAND
        -- rings lie flat on the field, proud like the flags (island pos, field top Y)
        local fieldTopY = 112.15 -- floorY + slabProud; MIRRORS ArenaLayout.karesansui
        part.CFrame = CFrame.new(island.Position.X, fieldTopY, island.Position.Z)
        part.Parent = garden
    end)
    if not ok then
        warn(`[KARESANSUI] rings skipped for {island:GetFullName()}: {err}`)
    end
end

for _, island in CollectionService:GetTagged("KaresansuiIsland") do
    if island:IsA("BasePart") then
        buildRings(island)
    end
end
CollectionService:GetInstanceAddedSignal("KaresansuiIsland"):Connect(function(inst)
    if inst:IsA("BasePart") then
        buildRings(inst)
    end
end)
```

- [ ] **Step 2: Verify + commit**

`lune run tests/run && stylua --check src tests tools && selene src tools` (controller has no Lune coverage by convention). Commit:

```bash
git add roblox/src/client/KaresansuiController.client.luau
git commit -m "feat(roblox): KaresansuiController — client-built ripple rings around tagged islands"
```

---

### Task 6: [MAIN SESSION] Studio: MaterialVariants + kerb/field gate (visual gate 2)

- [ ] **Step 1:** Run `node tools/glyphs/rakedtex.cjs`; upload the four PNGs via the Studio MCP `upload_image` pipeline (recipe doc §9). If moderation rejects, the field falls back to plain Sand — note it and continue; retry later.
- [ ] **Step 2:** In Studio (Edit), create two MaterialVariants under MaterialService — names EXACTLY `RakedSandNS` and `RakedSandEW`, BaseMaterial Sand, ColorMap/NormalMap from the uploads, `StudsPerTile = 8`, MaterialPattern **Organic** (the §9 gotcha).
- [ ] **Step 3:** Rojo-sync (or verify serve) so the Karesansui asset is in the place; confirm the guards collide for an avatar but fireworks pass (EngawaBarrier group exists — if the group is missing from this place, register it once in Studio: PhysicsService > add group `EngawaBarrier`, non-collidable with `Projectile`, collidable with Default).
- [ ] **Step 4:** ONE screenshot pass of kerb + raked field from plaza eye-level and from the teahouse overlook. **STOP and ask the user to look** (gate 2). Tune StudsPerTile/color ONLY on their direction. Save the place after sign-off.

---

### Task 7: [MAIN SESSION] Studio: boulders + rings + night gates (visual gates 3 + 4)

- [ ] **Step 1:** Place 3–5 mossy boulders per the classic asymmetric-triad read (odd counts, varied sizes, off-center) INSIDE the panels using the existing canyon rock vocabulary (duplicate from `CanyonWorld.Arena` rocks); tag each `KaresansuiIsland` (CollectionService tag editor or execute_luau `CollectionService:AddTag`).
- [ ] **Step 2:** Play — rings should generate around every island. ONE screenshot pass. **STOP for gate 3.**
- [ ] **Step 3:** Night pass: set the day/night dev knob (`DayNightLockT` = 0.75 on Workspace), Play, screenshot the ripple relief under lantern light. **STOP for gate 4.** Remove the lock attribute after.
- [ ] **Step 4:** After sign-off: SAVE/PUBLISH the place (boulders + tags + variants are place-only).

---

### Task 8: Full verification + wrap

- [ ] **Step 1:** From `roblox/`: `lune run tests/run && lune run tools/genmodels && git status --short assets && stylua --check src tests tools && selene src tools` — green, no drift. Run `tools/studio/verifyWorkspaceConvention.luau` in Studio (new stage child must pass).
- [ ] **Step 2:** `git push`; confirm `roblox-ci` success (`gh run list --limit 3`; old gh CLI — no `--json`/`--branch`).
- [ ] **Step 3:** Update the arena-amplified memory: karesansui DONE, corridors reserved (merchant row inherits `shopCorridor`), and any gate-tuned values worth recording.
