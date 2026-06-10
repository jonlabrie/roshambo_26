# ZenDojo Garden — Physical Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the bottom two terraces into a Japanese stroll-garden — teahouses fronting engawa-over-water channels with still reflecting pools, stone paths and arched bridges, and mature foliage — driven entirely by code (`ArenaLayout` authority → pure builders → committed `*.model.json`; water carved in the MCP terrain script).

**Architecture:** `ArenaLayout.luau` gains a `gardenTiers` block that becomes the single source of truth for teahouse ring radii, channel/pool/path radii, and creek meander — read by the builders AND re-pasted into the terrain script. New pure builders (`Bridge` helper, `Footpath`, `Foliage`) follow the existing `Spec.part`/`Spec.model` pattern, are registered in `tools/genmodels.luau` + `default.project.json`, and are fixture-tested under Lune. The terrain water (creek meander + tier channels + pools) is carved in `tools/studio/buildTerrain.luau`, which runs only via MCP `execute_luau` in Studio EDIT mode (it uses `math.noise`, unavailable in Lune) — so terrain tasks are verified at Studio gates, not unit tests.

**Tech Stack:** Luau, Rojo 7.6.1, Lune test harness, Roblox Terrain (WriteVoxels heightfield), MCP Roblox Studio.

**Scope:** This is **Phase 1 (physical garden)** of the spec `docs/superpowers/specs/2026-06-09-zendojo-garden-environment-design.md`. Phase 2 (atmosphere: time-of-day presets, lighting, fireflies) is a separate plan written after this one is gated.

**Conventions every task must honor:**
- Builders live in `roblox/tools/builders/`, require only `./Spec` (and sibling *helper* builders like `./StoneLantern`), and must be **deterministic** — no `math.random` (CI drift check) and no `math.noise` (Lune lacks it). Use the established sin-hash for jitter.
- After changing any builder, regenerate assets: from `roblox/`, `lune run tools/genmodels`. The committed `assets/*.model.json` are CI drift-checked — never hand-edit them.
- Gates (run from `roblox/`): `export PATH="$HOME/.rokit/bin:$PATH" && stylua --check src tests tools && selene src && lune run tests/run && lune run tools/genmodels && rojo build -o /tmp/b.rbxl`.
- New `$path` nodes in `default.project.json` require a **`rojo serve` restart** to appear in Studio (editing existing nodes' files live-syncs).
- Roblox compass: **−Z = North** (entrance/spawn), +Z = South, +X = East, −X = West. Y=0 is the basin waterline.
- The server already marks every `RoshamboStage` Model `ModelStreamingMode.Persistent` (`src/server/main.server.luau`), so new model nodes need no streaming work.
- **Do not commit when geometry "looks correct" — it isn't until verified at the Studio gate.** Within each task, commit the *code+test* once Lune tests pass; visual correctness is signed off separately at the gate tasks.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `roblox/tools/builders/ArenaLayout.luau` | Coordinate authority; add `gardenTiers`, `creek.meander`, `foliage`, `firefly` | Modify |
| `roblox/tools/builders/Bridge.luau` | `Bridge.arch(palette,a,b,width)` → parts for one cambered timber bridge (helper, not a genmodels output) | Create |
| `roblox/tools/builders/Teahouse.luau` | Read ring data from `ArenaLayout`; add engawa + posts + per-hut bridge | Modify |
| `roblox/tools/builders/Footpath.luau` | Stone ring paths, stepping stones, tier-link slabs, standalone pool bridges | Create |
| `roblox/tools/builders/Foliage.luau` | Maples, pines, bamboo, shrubs, moss, hero cherry, scattered from layout | Create |
| `roblox/tools/builders/TerraceDressing.luau` | Relocate lanterns off the channel band onto the path edge | Modify |
| `roblox/tools/builders/Creek.luau` | Apply the shared meander offset to bank/cascade stones | Modify |
| `roblox/tools/genmodels.luau` | Register `Footpath`, `Foliage` outputs | Modify |
| `roblox/default.project.json` | Add `Footpath`, `Foliage` stage nodes | Modify |
| `roblox/tools/studio/buildTerrain.luau` | Remove paddy band; carve meandering creek + tier channels + pools + weirs | Modify (MCP-run) |
| `roblox/tests/*.spec.luau` | Fixture tests for each builder + layout | Create/Modify |

---

## Task 1: ArenaLayout — `gardenTiers`, creek meander, foliage & firefly anchors

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau`
- Test: `roblox/tests/ArenaLayout.spec.luau`

The teahouse ring radii currently live hard-coded inside `Teahouse.luau` (`rings = {{ti=1,count=7,r=129,...}}`). Move that authority into `ArenaLayout` so the channels, pools, path, lanterns and terrain all derive from one place. Radii are chosen to sit on the existing tier plateaus (tier 1 plateau ≈ r116→145 at height 6; tier 2 plateau ≈ r152→181 at height 16), channel **centre-ward** of the hut ring, path centre-ward of the channel.

- [ ] **Step 1: Write the failing test**

Add to `roblox/tests/ArenaLayout.spec.luau` (create the file if absent, mirroring the `require`/`describe` shape of `tests/Teahouse.spec.luau`):

```lua
--!strict
local harness = require("./harness")
local L = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ArenaLayout garden", function()
    test("gardenTiers covers tiers 1 & 2 with the established counts", function()
        expect(#L.gardenTiers).toBe(2)
        expect(L.gardenTiers[1].tier).toBe(1)
        expect(L.gardenTiers[1].houseCount).toBe(7)
        expect(L.gardenTiers[2].houseCount).toBe(9)
        expect(L.topTier.houseCount).toBe(15) -- tier 3, dry garden
    end)

    test("each garden tier nests path < channel < houses, all on its plateau", function()
        for _, g in L.gardenTiers do
            expect(g.pathR < g.channelR).toBe(true)
            expect(g.channelR < g.houseR).toBe(true)
            -- channel + path sit inside the tier plateau (between this tier's wall
            -- top and the next tier's wall start = nextRadius - 7)
            local tier = L.tiers[g.tier]
            local nextR = L.tiers[g.tier + 1].radius
            expect(g.pathR > tier.radius).toBe(true)
            expect(g.houseR < nextR - 7).toBe(true)
        end
    end)

    test("creek meander + branch weirs + pool radius are defined", function()
        expect(L.creek.meander.amp > 0).toBe(true)
        expect(L.creek.meander.waves > 0).toBe(true)
        expect(#L.branchWeirs).toBe(2)
        expect(L.poolRadius > 0).toBe(true)
        expect(#L.foliage.heroCherry).toBe(3)
        expect(L.firefly.heroLightCount > 0).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (`gardenTiers` is nil / indexing nil).

- [ ] **Step 3: Add the layout data**

In `roblox/tools/builders/ArenaLayout.luau`, inside the `ArenaLayout = { ... }` table, add these fields (place them just after the existing `teahouses = {...}` block; keep the legacy `teahouses`/`paddyStripWidth` fields for now — nothing else reads them after Task 2, but removing them is out of scope):

```lua
    -- Garden tiers (bottom two terraces). Single source of truth for teahouse
    -- rings AND the water garden in front of them. Radii sit on each tier's
    -- plateau: channel is centre-ward of the hut ring, path centre-ward of the
    -- channel, so a bridge crosses path -> channel -> engawa toward the centre.
    gardenTiers = {
        { tier = 1, height = 6, houseR = 129, houseCount = 7, housePhase = 0.0, channelR = 122, channelWidth = 6, pathR = 118 },
        { tier = 2, height = 16, houseR = 164, houseCount = 9, housePhase = 0.21, channelR = 157, channelWidth = 6, pathR = 153 },
    },
    -- Tier 3 is DRY garden: huts + lanterns + foliage, no channel.
    topTier = { tier = 3, height = 28, houseR = 192, houseCount = 15, housePhase = 0.13 },
    poolRadius = 6, -- still reflecting-pool widenings between hut clusters
    -- the creek bleeds a little water into each tier channel where it crosses
    -- that channel's radius (small stone-lined weirs). onLine() = the drive line.
    branchWeirs = { onLine(157, 16), onLine(122, 6) },
    foliage = {
        heroCherry = { -22, 28, -180 }, -- weeping cherry by the torii/stele on the rim
    },
    firefly = { heroLightCount = 18 }, -- real-PointLight motes near the water (Phase 2)
```

Then extend the existing `creek = { ... }` table with a meander spec (add these two keys inside it):

```lua
        -- Sinuous lateral wiggle so the creek reads found, not surveyed. Lateral
        -- offset along the run t∈[0,1] = amp*sin(t*waves*2π), applied perpendicular
        -- to the drive line. Shared by Creek.luau (stones) and buildTerrain (water).
        meander = { amp = 6, waves = 2.5 },
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (all ArenaLayout garden tests green; existing specs still pass).

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/ArenaLayout.luau roblox/tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): ArenaLayout gardenTiers — ring/channel/path radii, creek meander, pool/weir/foliage anchors"
```

---

## Task 2: Teahouse reads ring data from ArenaLayout

**Files:**
- Modify: `roblox/tools/builders/Teahouse.luau:191-235` (the `Teahouse.build` rings table + loop)
- Test: `roblox/tests/Teahouse.spec.luau` (existing counts test must still pass)

Replace the hard-coded `rings` table with one derived from `L.gardenTiers` + `L.topTier`, so radii/counts/phases now come from `ArenaLayout`. Counts stay 7/9/15, so `tests/Teahouse.spec.luau` is unchanged and acts as the regression guard.

- [ ] **Step 1: Run the existing test to confirm current green baseline**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (Teahouse village 7/9/15).

- [ ] **Step 2: Replace the rings source**

In `Teahouse.build`, replace the literal `rings` table (currently lines ~196-200):

```lua
    local rings = {
        { ti = 1, count = 7, r = 129, phase = 0.0 },
        { ti = 2, count = 9, r = 164, phase = 0.21 },
        { ti = 3, count = 15, r = 192, phase = 0.13 },
    }
```

with one built from the layout authority:

```lua
    local rings = {}
    for _, g in L.gardenTiers do
        table.insert(rings, { ti = g.tier, count = g.houseCount, r = g.houseR, phase = g.housePhase })
    end
    table.insert(rings, { ti = L.topTier.tier, count = L.topTier.houseCount, r = L.topTier.houseR, phase = L.topTier.housePhase })
```

Leave the rest of `build` (jitter, `stacked`, `blockedTea`, the `hut(...)` call) unchanged. `gy` still uses `L.tiers[ring.ti].height + GROUND_LIFT`.

- [ ] **Step 3: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (7/9/15 unchanged; no-stack and porch-faces-centre tests still green).

- [ ] **Step 4: Regenerate assets and confirm no unintended drift**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels && git diff --stat roblox/assets/Teahouses.model.json`
Expected: `Teahouses.model.json` unchanged (same radii values), or only formatting-identical. If it changed, the radii in Task 1 don't match the old literals — reconcile before committing.

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/Teahouse.luau
git commit -m "refactor(roblox): Teahouse rings sourced from ArenaLayout.gardenTiers/topTier"
```

---

## Task 3: Bridge helper builder

**Files:**
- Create: `roblox/tools/builders/Bridge.luau`
- Test: `roblox/tests/Bridge.spec.luau`

A shared helper (like `StoneLantern`) that returns the parts of one slightly-cambered timber footbridge spanning world points `a → b`. Used by Teahouse (path→engawa) and Footpath (pool crossings). NOT a genmodels output — its parts are embedded into the caller's model.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/Bridge.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Bridge = require("../tools/builders/Bridge")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Bridge.arch", function()
    test("returns a deck, two rails and two abutment posts", function()
        local parts = Bridge.arch(ZenDojo.palette, { 0, 6, 0 }, { 0, 6, 10 }, 4, "X")
        local names = {}
        for _, p in parts do
            names[p.name] = true
        end
        expect(names["DeckX"]).toBe(true)
        expect(names["RailXL"]).toBe(true)
        expect(names["RailXR"]).toBe(true)
        expect(names["PostXA"]).toBe(true)
        expect(names["PostXB"]).toBe(true)
    end)

    test("the deck centre rises above the endpoints (camber)", function()
        local parts = Bridge.arch(ZenDojo.palette, { 0, 6, 0 }, { 0, 6, 10 }, 4, "Y")
        local deckY
        for _, p in parts do
            if p.name == "DeckY" then
                deckY = p.properties.CFrame[2]
            end
        end
        expect(deckY > 6).toBe(true) -- cambered up from the y=6 endpoints
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (`Bridge` module not found).

- [ ] **Step 3: Implement Bridge.luau**

```lua
--!strict
-- One slightly-cambered timber footbridge spanning world points a -> b. A helper
-- (returns a flat list of PartSpecs to embed in a caller's model), not a genmodels
-- output. Deck rises a little at its midpoint; low side rails; an abutment post at
-- each end. tag namespaces the part names so a model can hold several bridges.
local Spec = require("./Spec")

local Bridge = {}

function Bridge.arch(
    palette: { [string]: { number } },
    a: { number },
    b: { number },
    width: number,
    tag: string
): { Spec.PartSpec }
    local timber = palette.timber
    local mid = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 + 0.9, (a[3] + b[3]) / 2 } -- camber up 0.9
    local parts: { Spec.PartSpec } = {}

    -- deck in two cambered segments a->mid, mid->b
    for i, seg in { { a, mid, "A" }, { mid, b, "B" } } do
        local p, len, rot = Spec.segment(seg[1], seg[2])
        table.insert(
            parts,
            Spec.part(`Deck{tag}{if i == 1 then "" else "2"}`, {
                Size = { width, 0.3, len },
                CFrame = Spec.cframe(p, rot),
                Color = timber,
                Material = "WoodPlanks",
            })
        )
    end
    -- the single "Deck{tag}" name the test checks = first segment; rename to satisfy
    -- both: first segment is `Deck{tag}`, second `Deck{tag}2`.
    parts[1].name = `Deck{tag}`

    -- side rails along the full span (flat, low)
    local dx, dz = b[1] - a[1], b[3] - a[3]
    local flat = math.sqrt(dx * dx + dz * dz)
    local px, pz = -dz / flat, dx / flat -- perpendicular unit
    for _, e in { { width / 2, "L" }, { -width / 2, "R" } } do
        local ra = { a[1] + px * e[1], a[2] + 1.0, a[3] + pz * e[1] }
        local rb = { b[1] + px * e[1], b[2] + 1.0, b[3] + pz * e[1] }
        local p, len, rot = Spec.segment(ra, rb)
        table.insert(
            parts,
            Spec.part(`Rail{tag}{e[2]}`, {
                Size = { 0.25, 0.8, len },
                CFrame = Spec.cframe(p, rot),
                Color = timber,
                Material = "Wood",
            })
        )
    end

    -- abutment posts at each end, dropping 4 studs to the bank/bed
    for _, e in { { a, "A" }, { b, "B" } } do
        table.insert(
            parts,
            Spec.part(`Post{tag}{e[2]}`, {
                Size = { 0.6, 4, 0.6 },
                CFrame = Spec.cframe({ e[1][1], e[1][2] - 2, e[1][3] }),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    return parts
end

return Bridge
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (Bridge.arch tests green).

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/Bridge.luau roblox/tests/Bridge.spec.luau
git commit -m "feat(roblox): Bridge.arch helper — cambered timber footbridge between two points"
```

---

## Task 4: Teahouse engawa + posts + front bridge

**Files:**
- Modify: `roblox/tools/builders/Teahouse.luau` (the `hut(...)` function + require `Bridge`)
- Test: `roblox/tests/Teahouse.spec.luau`

Each hut gains an **engawa** veranda along its centre-facing front (local +Z), cantilevered out over the channel on two **posts**, and a **bridge** from the path back to the engawa. The hut's local +Z already faces the arena centre (`deg = atan2(-x,-z)`), and the channel/path sit centre-ward, so "+Z, outward" is "toward the water and path."

- [ ] **Step 1: Write the failing test**

Add to `roblox/tests/Teahouse.spec.luau` inside the `describe`:

```lua
    test("every hut on tiers 1 & 2 has an engawa, two posts and a bridge deck", function()
        local spec = Teahouse.build(ZenDojo.palette, L)
        for _, house in spec.children :: any do
            local ti = tonumber(house.name:match("^Teahouse_(%d)_"))
            if ti == 1 or ti == 2 then
                local have = {}
                for _, p in house.children do
                    have[p.name] = true
                end
                expect(have["Engawa"]).toBe(true)
                expect(have["EngawaPostL"]).toBe(true)
                expect(have["EngawaPostR"]).toBe(true)
                expect(have["DeckBR"]).toBe(true) -- bridge deck, tag "BR"
            end
        end
    end)

    test("tier 3 huts are dry — no engawa", function()
        local spec = Teahouse.build(ZenDojo.palette, L)
        for _, house in spec.children :: any do
            if house.name:match("^Teahouse_3_") then
                for _, p in house.children do
                    expect(p.name ~= "Engawa").toBe(true)
                end
            end
        end
    end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (no `Engawa` member).

- [ ] **Step 3: Implement engawa/posts/bridge in `hut`**

At the top of `Teahouse.luau`, add the require (after `local Spec = require("./Spec")`):

```lua
local Bridge = require("./Bridge")
```

Change the `hut` signature to learn whether this tier is wet, and where its path/channel sit. Replace the signature + the first line of locals:

```lua
local function hut(
    palette: { [string]: { number } },
    name: string,
    cx: number,
    cz: number,
    gy: number,
    deg: number,
    wet: { channelR: number, pathR: number, houseR: number }? -- nil on the dry top tier
)
```

Add a `worldPos` helper next to the existing `place` helper (inside `hut`):

```lua
    local function worldPos(lx: number, ly: number, lz: number): { number }
        local o = Spec.rotY({ lx, 0, lz }, deg)
        return { cx + o[1], gy + ly, cz + o[3] }
    end
```

Then, just before `return Spec.model(name, kids)` at the end of `hut`, add the wet-tier dressing:

```lua
    -- engawa veranda over the channel + a bridge back to the path (wet tiers only).
    -- Local +Z faces the arena centre; the channel and path are centre-ward, so the
    -- veranda cantilevers +Z over the water and the bridge continues +Z to the path.
    if wet then
        local engOut = 3 -- how far the veranda oversails the front wall
        local engZ = hd + engOut / 2
        part("Engawa", { W - 1, 0.3, engOut }, 0, 0.25, engZ, palette.timber, "WoodPlanks")
        -- two posts dropping from the veranda's outer corners into the channel
        for _, e in { { (W - 1) / 2 - 0.5, "R" }, { -((W - 1) / 2 - 0.5), "L" } } do
            part(`EngawaPost{e[2]}`, { 0.5, 4, 0.5 }, e[1], -1.85, hd + engOut, palette.timber, "Wood")
        end
        -- bridge from the path (houseR-pathR studs toward centre) to the veranda lip
        local toPath = wet.houseR - wet.pathR -- local +Z distance to the path
        local aWorld = worldPos(0, 0.25, hd + engOut) -- veranda outer edge
        local bWorld = worldPos(0, 0.0, toPath) -- path point
        for _, bp in Bridge.arch(palette, aWorld, bWorld, 3, "BR") do
            table.insert(kids, bp)
        end
    end
```

Finally, in `Teahouse.build`, pass `wet` to `hut`. Replace the `hut(...)` call line:

```lua
            table.insert(children, hut(palette, `Teahouse_{ring.ti}_{k + 1}`, x, z, gy, deg))
```

with:

```lua
            local wet = nil
            for _, g in L.gardenTiers do
                if g.tier == ring.ti then
                    wet = { channelR = g.channelR, pathR = g.pathR, houseR = g.houseR }
                end
            end
            table.insert(children, hut(palette, `Teahouse_{ring.ti}_{k + 1}`, x, z, gy, deg, wet))
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (engawa/posts/bridge present on tiers 1–2; tier 3 dry; counts still 7/9/15).

- [ ] **Step 5: Regenerate + gate**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && stylua --check src tests tools && selene src && lune run tools/genmodels && rojo build -o /tmp/b.rbxl`
Expected: all green; `assets/Teahouses.model.json` regenerated.

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/builders/Teahouse.luau roblox/tests/Teahouse.spec.luau roblox/assets/Teahouses.model.json
git commit -m "feat(roblox): teahouse engawa veranda + posts over the channel + path bridge (wet tiers)"
```

---

## Task 5: Footpath builder (ring paths, steppers, tier-link slabs, pool bridges)

**Files:**
- Create: `roblox/tools/builders/Footpath.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Test: `roblox/tests/Footpath.spec.luau`

A stone ring path on the centre side of each garden tier (at `pathR`), stepping stones across the still pools, slab paths linking tiers near the N ramp, and standalone arched bridges over the pool widenings. Path segments are short slabs laid around each ring (deterministic; no random).

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/Footpath.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Footpath = require("../tools/builders/Footpath")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Footpath", function()
    test("emits a ring of slabs for each garden tier, on that tier's surface", function()
        local spec = Footpath.build(ZenDojo.palette, L)
        local perTier = { [1] = 0, [2] = 0 }
        for _, c in spec.children :: any do
            local ti = tonumber(c.name:match("^PathSlab(%d)_"))
            if ti then
                perTier[ti] += 1
                -- slab y rests near the tier surface (height + ~ground lift)
                local g
                for _, gt in L.gardenTiers do
                    if gt.tier == ti then
                        g = gt
                    end
                end
                local y = c.properties.CFrame[2]
                expect(math.abs(y - (g.height + 2)) < 2).toBe(true)
            end
        end
        expect(perTier[1] > 0).toBe(true)
        expect(perTier[2] > 0).toBe(true)
    end)

    test("ring slabs sit at the tier's pathR, clear of the channel band", function()
        local spec = Footpath.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            local ti = tonumber(c.name:match("^PathSlab(%d)_"))
            if ti then
                local x, z = c.properties.CFrame[1], c.properties.CFrame[3]
                local r = math.sqrt(x * x + z * z)
                local g
                for _, gt in L.gardenTiers do
                    if gt.tier == ti then
                        g = gt
                    end
                end
                -- inside the channel inner edge (channelR - width/2)
                expect(r < g.channelR - g.channelWidth / 2).toBe(true)
            end
        end
    end)

    test("is deterministic", function()
        local a = Footpath.build(ZenDojo.palette, L)
        local b = Footpath.build(ZenDojo.palette, L)
        expect(#a.children).toBe(#b.children)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (`Footpath` not found).

- [ ] **Step 3: Implement Footpath.luau**

```lua
--!strict
-- Garden circulation: a stone ring path on the centre side of each wet tier (at
-- gardenTiers.pathR), stepping stones across the still pools, slab links toward the
-- N ramp, and arched bridges over the pool widenings. Deterministic (sin-hash
-- jitter only). The still pools and channel water are terrain; this is the stone.
local Spec = require("./Spec")
local Bridge = require("./Bridge")

local Footpath = {}

local GROUND_LIFT = 2 -- terrain renders ~2 studs proud (matches TerraceDressing/Teahouse)
local SANDO = 1.5 * math.pi -- entrance gap at -Z; leave it clear

local function rand(seed: number): number -- deterministic jitter in [0,1)
    local v = math.sin(seed * 12.9898) * 43758.5453
    return v - math.floor(v)
end

function Footpath.build(palette: { [string]: { number } }, L: any)
    local children = {}
    for _, g in L.gardenTiers do
        local gy = g.height + GROUND_LIFT
        local r = g.pathR
        local slabW = 3.2
        local step = slabW + 1.0 -- arc gap between slab centres
        local count = math.floor((2 * math.pi * r) / step)
        for k = 0, count - 1 do
            local a = (k / count) * 2 * math.pi
            if math.abs(((a - SANDO + math.pi) % (2 * math.pi)) - math.pi) < 0.18 then
                continue -- keep the sandō entrance clear
            end
            local jr = r + (rand(g.tier * 131 + k) - 0.5) * 1.2 -- slight in/out wobble
            local x, z = jr * math.cos(a), jr * math.sin(a)
            table.insert(
                children,
                Spec.part(`PathSlab{g.tier}_{k}`, {
                    Size = { slabW, 0.3, 2.6 },
                    CFrame = Spec.cframe({ x, gy + 0.15, z }, Spec.yaw(math.deg(a))),
                    Color = palette.gravel,
                    Material = "Slate",
                })
            )
        end
        -- a still-pool bridge at each pool gap (pools sit between hut clusters; one
        -- per two huts keeps it sparse). Bridge spans path -> channel outer edge.
        local pools = math.floor(g.houseCount / 2)
        for p = 0, pools - 1 do
            local a = g.housePhase + (p + 0.5) * (2 * math.pi / pools)
            if math.abs(((a - SANDO + math.pi) % (2 * math.pi)) - math.pi) < 0.2 then
                continue
            end
            local aWorld = { g.pathR * math.cos(a), gy, g.pathR * math.sin(a) }
            local outR = g.channelR + g.channelWidth / 2
            local bWorld = { outR * math.cos(a), gy, outR * math.sin(a) }
            for _, bp in Bridge.arch(palette, aWorld, bWorld, 3.2, `P{g.tier}_{p}`) do
                table.insert(children, bp)
            end
        end
    end
    -- N tier-link slabs: a short stair of slabs along +Z (north promontory side) at
    -- x≈0, stepping each tier height down toward the apron.
    for _, g in L.gardenTiers do
        local gy = g.height + GROUND_LIFT
        table.insert(
            children,
            Spec.part(`Link{g.tier}`, {
                Size = { 5, 0.3, 7 },
                CFrame = Spec.cframe({ 0, gy + 0.15, g.pathR }),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
    end
    return Spec.model("Footpath", children)
end

return Footpath
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (Footpath ring/clearance/determinism green).

- [ ] **Step 5: Register the output**

In `roblox/tools/genmodels.luau`, add the require (with the other builder requires) and the OUTPUT entry:

```lua
local Footpath = require("./builders/Footpath")
```
```lua
    ["Footpath"] = Footpath.build(ZenDojo.palette, ArenaLayout),
```

In `roblox/default.project.json`, add under `RoshamboStage` (after the `Teahouses` node):

```json
                "Footpath": { "$path": "assets/Footpath.model.json" },
```

- [ ] **Step 6: Regenerate + gate**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels && stylua --check src tests tools && selene src && lune run tests/run && rojo build -o /tmp/b.rbxl`
Expected: all green; `assets/Footpath.model.json` created.

- [ ] **Step 7: Commit**

```bash
git add roblox/tools/builders/Footpath.luau roblox/tests/Footpath.spec.luau roblox/tools/genmodels.luau roblox/default.project.json roblox/assets/Footpath.model.json
git commit -m "feat(roblox): Footpath builder — ring paths, pool bridges, tier-link slabs"
```

---

## Task 6: Foliage builder

**Files:**
- Create: `roblox/tools/builders/Foliage.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Test: `roblox/tests/Foliage.spec.luau`

Mature planting built from simple part trees (trunk + canopy blobs), scattered deterministically along the rear foliage banks of each tier and over the pools, plus the hero weeping cherry at `L.foliage.heroCherry`. Species differ by colour/shape. No meshes yet (graybox); a later art pass may swap them. Trees keep clear of the channel water and the bell sightline.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/Foliage.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Foliage = require("../tools/builders/Foliage")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function clusterCount(spec: any, prefix: string): number
    local n = 0
    for _, c in spec.children :: any do
        if c.name:match("^" .. prefix) then
            n += 1
        end
    end
    return n
end

describe("Foliage", function()
    test("places the hero weeping cherry at the layout anchor", function()
        local spec = Foliage.build(ZenDojo.palette, L)
        local cherry
        for _, c in spec.children :: any do
            if c.name == "Cherry" then
                cherry = c
            end
        end
        expect(cherry ~= nil).toBe(true)
        local trunk
        for _, p in cherry.children do
            if p.name == "Trunk" then
                trunk = p
            end
        end
        expect(math.abs(trunk.properties.CFrame[1] - L.foliage.heroCherry[1]) < 0.01).toBe(true)
    end)

    test("scatters maples, pines and bamboo", function()
        local spec = Foliage.build(ZenDojo.palette, L)
        expect(clusterCount(spec, "Maple") > 0).toBe(true)
        expect(clusterCount(spec, "Pine") > 0).toBe(true)
        expect(clusterCount(spec, "Bamboo") > 0).toBe(true)
    end)

    test("keeps trees off the channel water", function()
        local spec = Foliage.build(ZenDojo.palette, L)
        for _, tree in spec.children :: any do
            local trunk
            for _, p in tree.children do
                if p.name == "Trunk" then
                    trunk = p
                end
            end
            if trunk then
                local x, z = trunk.properties.CFrame[1], trunk.properties.CFrame[3]
                local r = math.sqrt(x * x + z * z)
                for _, g in L.gardenTiers do
                    local inChannel = r > g.channelR - g.channelWidth / 2 - 1 and r < g.channelR + g.channelWidth / 2 + 1
                    expect(inChannel).toBe(false)
                end
            end
        end
    end)

    test("is deterministic", function()
        expect(#Foliage.build(ZenDojo.palette, L).children).toBe(#Foliage.build(ZenDojo.palette, L).children)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (`Foliage` not found).

- [ ] **Step 3: Implement Foliage.luau**

```lua
--!strict
-- Mature planting as simple part-trees (trunk + canopy blobs). Scattered
-- deterministically (sin-hash) along each tier's rear foliage bank and the top
-- tier, plus a hero weeping cherry by the torii. Species vary by colour/shape.
-- Graybox fidelity: blobs, not meshes. Trees stay off the channel water and out of
-- the sandō gap. Colours come from the ZenDojo palette (moss/timber) plus a couple
-- of local accents kept here so the theme palette stays small.
local Spec = require("./Spec")

local Foliage = {}

local GROUND_LIFT = 2
local SANDO = 1.5 * math.pi

local MAPLE = { 0.55, 0.28, 0.20 } -- autumn red-bronze canopy
local PINE = { 0.20, 0.34, 0.24 } -- dark green
local CHERRY = { 0.80, 0.72, 0.74 } -- pale blossom

local function rand(seed: number): number
    local v = math.sin(seed * 12.9898) * 43758.5453
    return v - math.floor(v)
end

-- a tree = trunk + 1-3 canopy blobs. Returns a Model named `name`.
local function tree(name: string, x: number, y: number, z: number, h: number, canopy: { number }, blobs: number)
    local kids = {
        Spec.part("Trunk", {
            Size = { 0.8, h, 0.8 },
            CFrame = Spec.cframe({ x, y + h / 2, z }),
            Color = { 0.35, 0.26, 0.18 },
            Material = "Wood",
        }),
    }
    for b = 1, blobs do
        local s = 3 + rand(x * 7 + z * 13 + b) * 2.5
        local ox = (rand(x + b) - 0.5) * 2.5
        local oz = (rand(z + b * 3) - 0.5) * 2.5
        table.insert(
            kids,
            Spec.part(`Canopy{b}`, {
                Size = { s, s * 0.8, s },
                CFrame = Spec.cframe({ x + ox, y + h + s * 0.3, z + oz }),
                Color = canopy,
                Material = "Grass",
                Shape = "Ball",
            })
        )
    end
    return Spec.model(name, kids)
end

function Foliage.build(palette: { [string]: { number } }, L: any)
    local children = {}

    -- hero weeping cherry on the rim by the torii/stele
    local c = L.foliage.heroCherry
    table.insert(children, tree("Cherry", c[1], c[2], c[3], 6, CHERRY, 3))

    -- rear foliage bank on each tier (just inside the next wall) + top tier ring.
    local rings = {}
    for _, g in L.gardenTiers do
        table.insert(rings, { tier = g.tier, height = g.height, r = g.houseR + 8, species = "bank" })
    end
    table.insert(rings, { tier = L.topTier.tier, height = L.topTier.height, r = L.topTier.houseR + 10, species = "pine" })

    for _, ring in rings do
        local gy = ring.height + GROUND_LIFT
        local n = 10
        for k = 0, n - 1 do
            local a = (k / n) * 2 * math.pi + rand(ring.tier * 53 + k) * 0.2
            if math.abs(((a - SANDO + math.pi) % (2 * math.pi)) - math.pi) < 0.22 then
                continue
            end
            local r = ring.r + (rand(ring.tier * 17 + k) - 0.5) * 5
            local x, z = r * math.cos(a), r * math.sin(a)
            local pick = rand(ring.tier * 91 + k)
            if ring.species == "pine" or pick < 0.34 then
                table.insert(children, tree(`Pine{ring.tier}_{k}`, x, gy, z, 7, PINE, 2))
            elseif pick < 0.7 then
                table.insert(children, tree(`Maple{ring.tier}_{k}`, x, gy, z, 5, MAPLE, 3))
            else
                -- bamboo: a tight stand of thin tall stalks
                local kids = {}
                for s = 1, 5 do
                    local ox, oz = (rand(k + s) - 0.5) * 2, (rand(k * 2 + s) - 0.5) * 2
                    table.insert(
                        kids,
                        Spec.part(`Stalk{s}`, {
                            Size = { 0.3, 9, 0.3 },
                            CFrame = Spec.cframe({ x + ox, gy + 4.5, z + oz }),
                            Color = { 0.45, 0.5, 0.3 },
                            Material = "Wood",
                        })
                    )
                end
                -- a Trunk alias so the off-water test can read this stand's position
                kids[1].name = "Trunk"
                table.insert(children, Spec.model(`Bamboo{ring.tier}_{k}`, kids))
            end
        end
    end

    -- a hero maple leaning over one still pool per wet tier
    for _, g in L.gardenTiers do
        local a = g.housePhase + 0.4
        local r = g.channelR - g.channelWidth / 2 - 4 -- bankside, off the water
        table.insert(
            children,
            tree(`MaplePool{g.tier}`, r * math.cos(a), g.height + GROUND_LIFT, r * math.sin(a), 6, MAPLE, 3)
        )
    end
    return Spec.model("Foliage", children)
end

return Foliage
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (cherry anchor; maple/pine/bamboo present; off-water; deterministic).

- [ ] **Step 5: Register the output**

In `roblox/tools/genmodels.luau`:
```lua
local Foliage = require("./builders/Foliage")
```
```lua
    ["Foliage"] = Foliage.build(ZenDojo.palette, ArenaLayout),
```
In `roblox/default.project.json`, after the `Footpath` node:
```json
                "Foliage": { "$path": "assets/Foliage.model.json" },
```

- [ ] **Step 6: Regenerate + gate**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels && stylua --check src tests tools && selene src && lune run tests/run && rojo build -o /tmp/b.rbxl`
Expected: all green; `assets/Foliage.model.json` created.

- [ ] **Step 7: Commit**

```bash
git add roblox/tools/builders/Foliage.luau roblox/tests/Foliage.spec.luau roblox/tools/genmodels.luau roblox/default.project.json roblox/assets/Foliage.model.json
git commit -m "feat(roblox): Foliage builder — maples, pines, bamboo, hero cherry scattered from layout"
```

---

## Task 7: Relocate terrace lanterns off the channel band

**Files:**
- Modify: `roblox/tools/builders/TerraceDressing.luau:38-58`
- Test: `roblox/tests/TerraceDressing.spec.luau`

The lanterns currently land at `nextWall - 3`, which drops tier-1/2 lanterns into what is now the channel (the original bug: L1-8 in the trench). Reseat them on the path edge: for garden tiers, at `pathR - 2` (just centre-ward of the path, on dry plateau); for the top tier, keep an outer-edge ring.

- [ ] **Step 1: Write the failing test**

Replace the body of `roblox/tests/TerraceDressing.spec.luau` with (keep the file's existing `require` header; adjust the pinned assertion):

```lua
--!strict
local harness = require("./harness")
local TerraceDressing = require("../tools/builders/TerraceDressing")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("TerraceDressing lanterns", function()
    test("no lantern sits in a garden tier's channel band", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        for _, lan in spec.children :: any do
            local ti = tonumber(lan.name:match("^Lantern_(%d)_"))
            local base
            for _, p in lan.children do
                if p.name == "Base" then
                    base = p
                end
            end
            local x, z = base.properties.CFrame[1], base.properties.CFrame[3]
            local r = math.sqrt(x * x + z * z)
            for _, g in L.gardenTiers do
                if g.tier == ti then
                    local inBand = r > g.channelR - g.channelWidth / 2 - 2 and r < g.channelR + g.channelWidth / 2 + 2
                    expect(inBand).toBe(false)
                end
            end
        end
    end)

    test("garden-tier lanterns sit just inside the path", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        for _, lan in spec.children :: any do
            local ti = tonumber(lan.name:match("^Lantern_(%d)_"))
            local base
            for _, p in lan.children do
                if p.name == "Base" then
                    base = p
                end
            end
            local x, z = base.properties.CFrame[1], base.properties.CFrame[3]
            local r = math.sqrt(x * x + z * z)
            for _, g in L.gardenTiers do
                if g.tier == ti then
                    expect(r < g.pathR).toBe(true)
                end
            end
        end
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (current lanterns at `nextWall-3` land in/over the band).

- [ ] **Step 3: Re-seat the lantern radius**

In `roblox/tools/builders/TerraceDressing.luau`, replace the radius computation in the `for ti, tier in L.tiers do` loop (currently the `nextWall`/`r` lines ~44-45):

```lua
        local nextWall = if L.tiers[ti + 1] then L.tiers[ti + 1].radius - WALL_RUN else tier.radius + 22
        local r = nextWall - 3
```

with a path-relative seat that uses `gardenTiers` for the wet tiers and an outer ring for the dry top tier:

```lua
        -- garden tiers: just centre-ward of the path (dry plateau); top tier: an
        -- outer ring out toward the rim. Never on the channel band.
        local r
        local g = nil
        for _, gt in L.gardenTiers do
            if gt.tier == ti then
                g = gt
            end
        end
        if g then
            r = g.pathR - 2
        elseif L.tiers[ti + 1] then
            r = L.tiers[ti + 1].radius - WALL_RUN - 3
        else
            r = tier.radius + 22
        end
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (no lantern in the channel band; garden lanterns inside the path).

- [ ] **Step 5: Regenerate + commit**

```bash
cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels && lune run tests/run
git add roblox/tools/builders/TerraceDressing.luau roblox/tests/TerraceDressing.spec.luau roblox/assets/TerraceDressing.model.json
git commit -m "fix(roblox): seat terrace lanterns inside the path, clear of the new channel band"
```

---

## Task 8: Creek meander dressing

**Files:**
- Modify: `roblox/tools/builders/Creek.luau`
- Test: `roblox/tests/Creek.spec.luau`

Apply the shared `L.creek.meander` offset (amp·sin(t·waves·2π), perpendicular to the drive line) to the creek's bank stones and cascade rocks, so the stone garniture follows the same wiggle the terrain water will. This keeps the builder and terrain in visual agreement.

- [ ] **Step 1: Write the failing test**

Add to `roblox/tests/Creek.spec.luau` inside its `describe`:

```lua
    test("bank stones wander laterally per the meander amplitude", function()
        local L = require("../tools/builders/ArenaLayout")
        local ZenDojo = require("../src/shared/themes/ZenDojo")
        local spec = require("../tools/builders/Creek").build(ZenDojo.palette, L)
        -- project each stone onto the drive-line perpendicular; spread must exceed
        -- the plain channel half-width (meander actually moves them).
        local CK_DIRX, CK_DIRZ = -0.8387, -0.5446
        local maxOff = 0
        for _, c in spec.children :: any do
            if c.name:match("^Stone") then
                local x, z = c.properties.CFrame[1], c.properties.CFrame[3]
                local off = math.abs(x * CK_DIRZ - z * CK_DIRX)
                maxOff = math.max(maxOff, off)
            end
        end
        expect(maxOff > L.creek.width / 2 + L.creek.meander.amp - 2).toBe(true)
    end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (straight creek: stones never reach `width/2 + amp - 2`).

- [ ] **Step 3: Apply the meander offset in Creek.luau**

In `Creek.build`, the loop samples `t = i/N` and computes `x,z` on the straight line `e -> m`. Add the meander after computing the perpendicular `perpX,perpZ` and the base `x,z`. Replace the base point lines inside the loop:

```lua
        local t = i / N
        local x = e[1] + dx * t
        local z = e[3] + dz * t
```

with:

```lua
        local t = i / N
        local mo = L.creek.meander.amp * math.sin(t * L.creek.meander.waves * 2 * math.pi)
        local x = e[1] + dx * t + perpX * mo
        local z = e[3] + dz * t + perpZ * mo
```

(`perpX,perpZ` are already computed above the loop; this just nudges every sample along the bank-perpendicular by the meander offset, so bank stones and cascades both follow the wiggle.)

- [ ] **Step 4: Run tests to verify pass**

Run: `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (stones reach the meander envelope).

- [ ] **Step 5: Regenerate + commit**

```bash
cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels && lune run tests/run
git add roblox/tools/builders/Creek.luau roblox/tests/Creek.spec.luau roblox/assets/Creek.model.json
git commit -m "feat(roblox): creek bank stones follow the shared meander offset"
```

---

## Task 9: Terrain — remove paddy band; carve meandering creek + tier channels + pools + weirs (MCP)

**Files:**
- Modify: `roblox/tools/studio/buildTerrain.luau`

This is the heart of the water rework. `buildTerrain.luau` runs **only via MCP `execute_luau` in Studio EDIT mode** (it uses `math.noise`, which Lune lacks), so this task has **no Lune test** — it is verified at the Studio gate (Task 10). Make the edits, then run it in Studio.

> **Constants must mirror ArenaLayout** (the terrain script is a hand-pasted mirror, not a require). Re-paste these from `ArenaLayout.gardenTiers`: tier 1 → `channelR=122, width=6, pathR=118, height=6, houseCount=7, housePhase=0.0`; tier 2 → `channelR=157, width=6, pathR=153, height=16, houseCount=9, housePhase=0.21`. Meander → `amp=6, waves=2.5`. Pool radius `6`.

- [ ] **Step 1: Remove the paddy band**

In `roblox/tools/studio/buildTerrain.luau`, delete the paddy block in `evalColumn` (currently lines ~180-189):

```lua
        -- paddy: outer band of tiers 1 & 2, hugging the wall of the tier above.
        if ti and ti < #TIERS and pd >= PAD_SUPP then
            local tr = TIERS[ti + 1].r
            local bandIn, bandOut = tr - 12, tr - 2
            if rw >= bandIn and rw <= bandOut then
                local th = TIERS[ti].h
                res.g, res.wb, res.wt = th - 4, th - 4, th - 2
            end
        end
```

- [ ] **Step 2: Add the garden-tier data and a channel/pool evaluator**

Near the top of `buildTerrain.luau` (after the `TIERS`/`WALL_RUN` block ~line 40), add:

```lua
-- Garden water (mirror of ArenaLayout.gardenTiers). Each wet tier has a channel
-- ring centred at channelR (width WCH) on the centre side of the hut ring, holding
-- water to ~0.5 below the tier grade; it widens into still pools (radius POOLR) at
-- the gaps between hut clusters. Re-paste on layout change.
local GARDEN = {
    { tier = 1, h = 6, channelR = 122, w = 6, houseCount = 7, phase = 0.0 },
    { tier = 2, h = 16, channelR = 157, w = 6, houseCount = 9, phase = 0.21 },
}
local POOLR = 6
local CK_AMP, CK_WAVES = 6, 2.5 -- creek meander (mirror ArenaLayout.creek.meander)

-- water descriptor for a garden tier at (x,z), or nil. The channel is brimful to
-- grade-0.5; pools dip a touch deeper and read still.
local function gardenWater(x, z, r)
    for _, g in GARDEN do
        local a = math.atan2(z, x)
        -- still pools at the cluster gaps
        local pools = math.floor(g.houseCount / 2)
        for p = 0, pools - 1 do
            local pa = g.phase + (p + 0.5) * (2 * math.pi / pools)
            local px, pz = g.channelR * math.cos(pa), g.channelR * math.sin(pa)
            if (x - px) ^ 2 + (z - pz) ^ 2 < POOLR * POOLR then
                return { g = g.h - 4, wb = g.h - 4, wt = g.h - 0.4 }
            end
        end
        -- the channel ring
        if math.abs(r - g.channelR) < g.w / 2 then
            return { g = g.h - 3, wb = g.h - 3, wt = g.h - 0.5 }
        end
    end
    return nil
end
```

- [ ] **Step 3: Call the channel/pool evaluator in evalColumn**

In `evalColumn`, in the `else` branch (the tier branch), **after** the line `res = { g = surf }` and after the pad-flatten logic but where the paddy block used to be, insert:

```lua
        -- garden channels + still pools (replaced the paddy band)
        if pd >= PAD_SUPP then
            local gw = gardenWater(x, z, rw)
            if gw then
                res.g, res.wb, res.wt = gw.g, gw.wb, gw.wt
            end
        end
```

- [ ] **Step 4: Meander the creek**

In `creekColumn`, the channel currently tests `off = |x·CK_DIRZ − z·CK_DIRX|` against `halfW`. Offset that perpendicular distance by the meander so the channel centre wiggles. Replace the `off` computation:

```lua
    local off = math.abs(x * CK_DIRZ - z * CK_DIRX)
    if off > CREEK.halfW then
        return nil
    end
```

with:

```lua
    -- meander: shift the channel centreline laterally by amp·sin(t·waves·2π),
    -- where t is progress along the run (mouth..rim mapped 0..1).
    local t = (along - CREEK.mouthAlong) / (CREEK.rimAlong - CREEK.mouthAlong)
    local centre = CK_AMP * math.sin(t * CK_WAVES * 2 * math.pi)
    local off = math.abs((x * CK_DIRZ - z * CK_DIRX) - centre)
    if off > CREEK.halfW then
        return nil
    end
```

- [ ] **Step 5: Run the terrain build in Studio (MCP)**

In Studio, ensure Play is **stopped** (Edit datamodel). Run `buildTerrain.luau` via MCP `execute_luau` (datamodel_type `"Edit"`, and the script must `return` its summary). Paste the full updated file contents as the script.

Expected return: `"terrain v4 built (N tiles)"` with no error.

- [ ] **Step 6: Commit the script (source only — terrain itself isn't synced)**

```bash
git add roblox/tools/studio/buildTerrain.luau
git commit -m "feat(roblox): terrain — meandering creek + tier garden channels & still pools (paddy band removed)"
```

---

## Task 10: USER GATE — physical garden live

**Files:** none (verification only)

This is a **main-session Studio gate**, not a subagent task. Bring the full physical garden into Studio and verify with the user before Phase 2.

- [ ] **Step 1: Sync the new model nodes**

`Footpath` and `Foliage` are new `$path` nodes → **restart `rojo serve`** (stop it, start it, reconnect the Studio plugin). Confirm `Footpath` and `Foliage` models appear under `Workspace/RoshamboStage`.

- [ ] **Step 2: Rebuild terrain if not already current**

If terrain wasn't rebuilt in Task 9 Step 5 (or layout radii changed since), re-run `buildTerrain.luau` via MCP in Edit mode.

- [ ] **Step 3: Capture views and verify with the user**

Use MCP `screen_capture` from a few seats (entrance rim, a tier-1 teahouse, across the bowl to the bell). Confirm against the spec:
- Tier-1/2 teahouses front onto water; engawa oversails the channel; a bridge crosses path→engawa.
- Channels hold **continuous** water; still pools read calm; **no dry trenches**; **no lantern in the water** (the original L1-8 complaint resolved).
- Creek reads natural (meander + bank stones), still drives the wheel.
- Paths ring each tier; foliage banks read lush; bell sightlines stay open.

- [ ] **Step 4: Tune and reconcile**

Capture the user's adjustments (radii, widths, pool count/positions, foliage density). Apply them in `ArenaLayout`/builders (re-paste mirrored constants into `buildTerrain.luau`), regenerate, re-run terrain, re-verify. **Only commit tuning once the user signs off** — per the standing rule, do not commit when it merely "looks correct."

- [ ] **Step 5: Final commit of any gate tuning**

```bash
git add -A roblox/
git commit -m "tune(roblox): physical garden — gate adjustments (radii/widths/foliage)"
```

---

## Self-Review (completed by plan author)

**Spec coverage (Phase 1 scope):**
- §2 tier water gardens (engawa/channel/pools/bridges) → Tasks 1, 4, 5, 9 ✓
- §3 creek realism (meander, rock) → Tasks 8, 9 ✓ (riffle/pool grade breaks are tuned at the Task 10 gate via `buildTerrain` depth — noted there)
- §4 paths & bridges → Tasks 3, 5 ✓
- §5 foliage → Task 6 ✓
- §8 component changes (ArenaLayout, Teahouse, TerraceDressing, Creek, Footpath, Bridge, Foliage, genmodels, project.json, buildTerrain) → all covered ✓
- §10 testing (ArenaLayout/builder specs, drift check, gates) → each task ✓
- **Deferred to Phase 2 plan (atmosphere):** §6 lighting & time-of-day, §7 fireflies & reflections. The `L.firefly`/`L.foliage` anchors are seeded here so Phase 2 has its hooks.

**Placeholder scan:** No "TBD"/"handle edge cases"/bare prose steps — every code step shows code; every run step shows the command + expected result.

**Type/name consistency:** `gardenTiers` fields (`tier/height/houseR/houseCount/housePhase/channelR/channelWidth/pathR`), `topTier`, `poolRadius`, `branchWeirs`, `creek.meander.{amp,waves}`, `foliage.heroCherry`, `firefly.heroLightCount` are used identically across Tasks 1–9. `Bridge.arch(palette,a,b,width,tag)` signature is consistent in Tasks 3, 4, 5. Bridge deck names (`Deck{tag}`, `Rail{tag}{L,R}`, `Post{tag}{A,B}`) match between the helper and the tests that read them (`DeckBR` in Task 4, `Deck...` in Task 5).
