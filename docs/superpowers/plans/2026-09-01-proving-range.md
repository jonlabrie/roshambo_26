# Fireworks Proving Range Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An in-Play, Studio-gated firing range at FallsLanding where draft firework recipes are fired through the production render path for the owner's judgment.

**Architecture:** Drafts are pure data (`FireworkDrafts.luau`, families of variants) resolved by the existing `FireworkController` when the catalog misses; a new `RequestProvingFire` remote lets a Studio session broadcast the existing `FireworkLaunched` event from a mortar rack with no inventory spend; a builder-generated yard (`ProvingGround`) hosts five racks and a firing post; a Studio-only client panel drives single/ladder/sequence fires and a local night override.

**Tech Stack:** Luau (strict), Lune test harness (`roblox/tests/harness.luau`), Rojo, builder→`genmodels`→`model.json` pipeline.

**Spec:** `docs/superpowers/specs/2026-09-01-proving-range-design.md`

## Global Constraints

- **Studio-gated everywhere**: the panel exists only when `RunService:IsStudio()` is true on the client, AND the server handler rejects when `RunService:IsStudio()` is false. Nothing proving-related may be reachable in a published place.
- **No BillboardGuis** (owner ruling 2026-09-01). Rack labels are physical plaques with `SurfaceGui` letters, part of the rack geometry.
- Draft ids are namespaced `"draft:" .. family .. "/" .. variant`. Drafts NEVER appear in `shared-fixtures/firework-shells.json`.
- `roblox/default.project.json` is edited **as text with Edit**, never via a JSON round-trip (a round-trip once reformatted the whole file — 242 insertions for a 3-line change).
- No new `BloomEffect`, no per-shell `PointLight`s, no changes to pooling/director/LOD — the render path is production, untouched except recipe resolution.
- Proving racks must NOT carry the `FireworkLaunchSite` tag (players must never be offered them as spend sites).
- All shared modules are pure `--!strict` Luau, no Roblox globals, loadable under Lune.
- Lint gate matches CI: from `roblox/`: `stylua --check src tests tools && selene src tools` (selene fails on warnings).
- Tests: from `roblox/`: `lune run tests/run`. `.client.luau`/`.server.luau` files are untested by design ("NOTHING HERE IS TESTED" header in `FireworkController.client.luau`) — decisions go in pure modules.
- Commit after each task. Commit messages follow repo style (`feat(fireworks): …`, `docs(fireworks): …`).

## File Structure

| File | Responsibility |
|---|---|
| `roblox/src/shared/FireworkRecipes.luau` (create) | The one recipe schema: `validate(recipe)` |
| `roblox/src/shared/FireworkDrafts.luau` (create) | Draft families + `resolve(id)` + `variantsOf(family)` |
| `roblox/src/shared/ProvingPlan.luau` (create) | Pure ladder/sequence → rack/delay mapping |
| `roblox/src/client/FireworkController.client.luau` (modify) | One line: resolve drafts after catalog miss |
| `roblox/src/server/main.server.luau` (modify) | `RequestProvingFire` handler |
| `roblox/default.project.json` (modify, text) | New remote; `ProvingGround` stage entry |
| `roblox/tools/builders/ProvingGround.luau` (create) | Yard geometry: 5 racks, plaques, firing post |
| `roblox/tools/genmodels.luau` (modify) | Register ProvingGround output |
| `roblox/src/shared/WorkspaceConvention.luau` (modify) | Declare ProvingGround as a stage child |
| `roblox/src/client/ProvingController.client.luau` (create) | Studio-only panel, fire modes, night toggle |
| Tests | `tests/FireworkRecipes.spec.luau`, `tests/FireworkDrafts.spec.luau`, `tests/ProvingPlan.spec.luau`, `tests/ProvingGround.spec.luau` |

All commands below run from `roblox/`.

---

### Task 1: FireworkRecipes — the one recipe schema

**Files:**
- Create: `roblox/src/shared/FireworkRecipes.luau`
- Test: `roblox/tests/FireworkRecipes.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces: `FireworkRecipes.validate(recipe: any): (boolean, string?)` — true, or false plus a message naming the failing phase. `FireworkRecipes.KINDS: { [string]: boolean }` — the phase kinds the controller can draw (`report`, `ascent`, `burst`).

The blank-sky trap is documented twice in this repo (catalog header, bench header): an emitter with `Texture == ""` renders nothing, silently. This module makes that a test failure instead.

- [ ] **Step 1: Write the failing spec**

`roblox/tests/FireworkRecipes.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkRecipes = require("../src/shared/FireworkRecipes")
local FireworkCatalog = require("../src/shared/FireworkCatalog")

local function goodRecipe(): any
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = "rbxasset://s" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 190, 200 } },
            {
                at = 1.1,
                kind = "burst",
                anchor = "apex",
                texture = "rbxasset://textures/particles/sparkles_main.dds",
                color = { 255, 120, 140 },
                spread = 42,
            },
        },
    }
end

describe("FireworkRecipes.validate — the one recipe schema", function()
    test("a well-formed recipe passes", function()
        local ok, err = FireworkRecipes.validate(goodRecipe())
        expect(err == nil).toBe(true)
        expect(ok).toBe(true)
    end)

    test("A BURST WITH NO TEXTURE FAILS — the blank-sky trap", function()
        local r = goodRecipe()
        r.phases[3].texture = nil
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("a burst with an EMPTY texture fails the same way", function()
        local r = goodRecipe()
        r.phases[3].texture = ""
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("an unknown phase kind fails", function()
        local r = goodRecipe()
        r.phases[2].kind = "crossette" -- vocabulary project, not yet a word
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("phase times must be non-negative and non-decreasing", function()
        local r = goodRecipe()
        r.phases[3].at = 0.01 -- before the ascent
        expect(FireworkRecipes.validate(r)).toBe(false)
        local r2 = goodRecipe()
        r2.phases[1].at = -0.5
        expect(FireworkRecipes.validate(r2)).toBe(false)
    end)

    test("an anchor must be origin or apex", function()
        local r = goodRecipe()
        r.phases[3].anchor = "player"
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("a color must be three numbers in 0..255", function()
        local r = goodRecipe()
        r.phases[3].color = { 255, 120 }
        expect(FireworkRecipes.validate(r)).toBe(false)
        local r2 = goodRecipe()
        r2.phases[3].edgeColor = { 300, 0, 0 }
        expect(FireworkRecipes.validate(r2)).toBe(false)
    end)

    test("no phases at all fails", function()
        expect(FireworkRecipes.validate({ phases = {} })).toBe(false)
        expect(FireworkRecipes.validate({})).toBe(false)
        expect(FireworkRecipes.validate("peony")).toBe(false)
    end)

    test("EVERY SHIPPED CATALOG RECIPE PASSES — one schema, not two", function()
        for id, recipe in FireworkCatalog.RECIPES do
            local ok, err = FireworkRecipes.validate(recipe)
            if not ok then
                error(`catalog recipe '{id}' fails its own schema: {err}`)
            end
            expect(ok).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — module `../src/shared/FireworkRecipes` not found.

- [ ] **Step 3: Implement**

`roblox/src/shared/FireworkRecipes.luau`:

```lua
--!strict
-- THE ONE RECIPE SCHEMA. FireworkCatalog (shipped) and FireworkDrafts (proving) both hold
-- recipes; this module is the single definition of what a well-formed one is, so a typo'd
-- draft fails `lune run tests/run` instead of silently rendering a blank sky in a Play
-- session (an emitter with Texture == "" renders NOTHING — the documented 2026-07-20 trap).
-- Pure, no Roblox globals; runs under Lune.
local FireworkRecipes = {}

-- The phase kinds FireworkController can draw. The vocabulary project widens this table;
-- widening it here without teaching the controller the word is exactly the drift this
-- module exists to catch, so the two must move together.
FireworkRecipes.KINDS = { report = true, ascent = true, burst = true } :: { [string]: boolean }

local ANCHORS = { origin = true, apex = true }

local function validColor(c: any): boolean
    if typeof(c) ~= "table" or #c ~= 3 then
        return false
    end
    for _, v in c :: { any } do
        if typeof(v) ~= "number" or v < 0 or v > 255 then
            return false
        end
    end
    return true
end

function FireworkRecipes.validate(recipe: any): (boolean, string?)
    if typeof(recipe) ~= "table" or typeof(recipe.phases) ~= "table" or #recipe.phases == 0 then
        return false, "a recipe is a table with a non-empty phases array"
    end
    local prevAt = 0
    for i, ph in recipe.phases :: { any } do
        if typeof(ph) ~= "table" then
            return false, `phase {i}: not a table`
        end
        if not FireworkRecipes.KINDS[ph.kind] then
            return false, `phase {i}: unknown kind '{tostring(ph.kind)}'`
        end
        if typeof(ph.at) ~= "number" or ph.at < 0 or ph.at < prevAt then
            return false, `phase {i}: 'at' must be a non-negative, non-decreasing number`
        end
        prevAt = ph.at
        if not ANCHORS[ph.anchor] then
            return false, `phase {i}: anchor must be 'origin' or 'apex'`
        end
        if ph.kind == "burst" and (typeof(ph.texture) ~= "string" or ph.texture == "") then
            return false, `phase {i}: a burst must name a non-empty texture (blank-sky trap)`
        end
        for _, key in { "color", "edgeColor" } do
            if ph[key] ~= nil and not validColor(ph[key]) then
                return false, `phase {i}: '{key}' must be three numbers in 0..255`
            end
        end
    end
    return true, nil
end

return FireworkRecipes
```

- [ ] **Step 4: Run tests to verify green**

Run: `lune run tests/run`
Expected: PASS (all suites — the catalog test exercises the four shipped recipes).

- [ ] **Step 5: Lint and commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/FireworkRecipes.luau tests/FireworkRecipes.spec.luau
git commit -m "feat(fireworks): FireworkRecipes -- the one recipe schema, blank-sky trap now a test failure"
```

---

### Task 2: FireworkDrafts — families of variants, resolvable by namespaced id

**Files:**
- Create: `roblox/src/shared/FireworkDrafts.luau`
- Test: `roblox/tests/FireworkDrafts.spec.luau`

**Interfaces:**
- Consumes: `FireworkRecipes.validate` (Task 1) — in the spec only.
- Produces: `FireworkDrafts.FAMILIES: { [string]: { [string]: any } }`; `FireworkDrafts.resolve(id: string): any?` (nil unless id is `draft:<family>/<variant>` and exists); `FireworkDrafts.variantsOf(family: string): { string }` (sorted variant names, empty for unknown family); `FireworkDrafts.familyNames(): { string }` (sorted).

Seeded with one real family — `kiku` (菊, chrysanthemum), three peony-derived variants that differ visibly in spread and edge color — so the range has a genuine ladder to fire on day one.

- [ ] **Step 1: Write the failing spec**

`roblox/tests/FireworkDrafts.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkDrafts = require("../src/shared/FireworkDrafts")
local FireworkRecipes = require("../src/shared/FireworkRecipes")
local FireworkCatalog = require("../src/shared/FireworkCatalog")

describe("FireworkDrafts — the proving range's working file", function()
    test("EVERY DRAFT IN EVERY FAMILY PASSES THE SCHEMA", function()
        -- The whole point: a typo'd draft fails here, not as a blank sky in Play.
        local count = 0
        for family, variants in FireworkDrafts.FAMILIES do
            for variant, recipe in variants do
                count += 1
                local ok, err = FireworkRecipes.validate(recipe)
                if not ok then
                    error(`draft {family}/{variant}: {err}`)
                end
                expect(ok).toBe(true)
            end
        end
        expect(count > 0).toBe(true) -- the file ships with a seed family
    end)

    test("resolve round-trips the namespaced id", function()
        local families = FireworkDrafts.familyNames()
        expect(#families > 0).toBe(true)
        local family = families[1]
        local variants = FireworkDrafts.variantsOf(family)
        expect(#variants > 0).toBe(true)
        local id = "draft:" .. family .. "/" .. variants[1]
        expect(FireworkDrafts.resolve(id) == FireworkDrafts.FAMILIES[family][variants[1]]).toBe(true)
    end)

    test("resolve returns nil for unknowns and malformed ids", function()
        expect(FireworkDrafts.resolve("draft:nosuch/v1") == nil).toBe(true)
        expect(FireworkDrafts.resolve("peony") == nil).toBe(true)
        expect(FireworkDrafts.resolve("draft:") == nil).toBe(true)
        expect(FireworkDrafts.resolve("draft:kiku") == nil).toBe(true)
    end)

    test("variantsOf is sorted and empty for unknown families", function()
        for _, family in FireworkDrafts.familyNames() do
            local v = FireworkDrafts.variantsOf(family)
            for i = 2, #v do
                expect(v[i - 1] < v[i]).toBe(true)
            end
        end
        expect(#FireworkDrafts.variantsOf("nosuch")).toBe(0)
    end)

    test("no family name shadows a shipped shell id", function()
        -- The draft: prefix already prevents runtime collision; this keeps the
        -- human namespace clean too, so promotion is a move, not a rename.
        for family in FireworkDrafts.FAMILIES do
            expect(FireworkCatalog.RECIPES[family] == nil).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — module `../src/shared/FireworkDrafts` not found.

- [ ] **Step 3: Implement**

`roblox/src/shared/FireworkDrafts.luau`:

```lua
--!strict
-- THE PROVING RANGE'S WORKING FILE. Families of candidate recipes, same format as
-- FireworkCatalog.RECIPES (see its header), fired at the range as "draft:<family>/<variant>".
-- Claude authors here; the owner judges in Play; an approved variant MOVES to FireworkCatalog
-- (plus the shared fixture and server/src/fireworks.ts) and the rest of its family is pruned in
-- the same or a following commit — git history is the archive, this file stays short.
--
-- NEVER add a draft to shared-fixtures/firework-shells.json: the CI contract would then demand
-- the server price it. Every entry here is schema-checked by FireworkDrafts.spec against
-- FireworkRecipes, so a typo fails `lune run tests/run` rather than rendering a blank sky.
-- Pure data + string parsing, no Roblox globals; runs under Lune.
local FireworkDrafts = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local S_REPORT = "rbxasset://sounds/collide.wav"
local S_ASCENT = "rbxasset://sounds/swoosh.wav"
local S_BURST = "rbxasset://sounds/impact_explosion_03.mp3"

-- 菊 kiku, chrysanthemum: a tight peony with a distinct edge tint. The seed ladder —
-- three spreads of the same idea so the range's first session has a real comparison.
local function kiku(spread: number, edge: { number })
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", sound = S_ASCENT, color = { 255, 214, 130 } },
            {
                at = 1.15,
                kind = "burst",
                anchor = "apex",
                sound = S_BURST,
                texture = SPARKLE,
                color = { 255, 190, 90 },
                edgeColor = edge,
                spread = spread,
                droop = false,
            },
        },
    }
end

FireworkDrafts.FAMILIES = {
    kiku = {
        v1 = kiku(28, { 255, 240, 200 }),
        v2 = kiku(38, { 255, 150, 60 }),
        v3 = kiku(50, { 200, 90, 40 }),
    },
} :: { [string]: { [string]: any } }

function FireworkDrafts.resolve(id: string): any?
    local family, variant = id:match("^draft:([%w_]+)/([%w_]+)$")
    if family == nil or variant == nil then
        return nil
    end
    local fam = FireworkDrafts.FAMILIES[family :: string]
    return fam and fam[variant :: string] or nil
end

function FireworkDrafts.variantsOf(family: string): { string }
    local out: { string } = {}
    local fam = FireworkDrafts.FAMILIES[family]
    if fam then
        for name in fam do
            table.insert(out, name)
        end
        table.sort(out)
    end
    return out
end

function FireworkDrafts.familyNames(): { string }
    local out: { string } = {}
    for name in FireworkDrafts.FAMILIES do
        table.insert(out, name)
    end
    table.sort(out)
    return out
end

return FireworkDrafts
```

- [ ] **Step 4: Run tests to verify green**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint and commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/FireworkDrafts.luau tests/FireworkDrafts.spec.luau
git commit -m "feat(fireworks): FireworkDrafts -- draft families, namespaced resolve, kiku seed ladder"
```

---

### Task 3: ProvingPlan — pure ladder/sequence mapping

**Files:**
- Create: `roblox/src/shared/ProvingPlan.luau`
- Test: `roblox/tests/ProvingPlan.spec.luau`

**Interfaces:**
- Consumes: variant lists as `{ string }` (from `FireworkDrafts.variantsOf`, but takes plain arrays so it stays decoupled).
- Produces: `ProvingPlan.RACKS: { string }` = `{"Rack_A","Rack_B","Rack_C","Rack_D","Rack_E"}`; `ProvingPlan.SEQUENCE_RACK = "Rack_C"`; `ProvingPlan.SEQUENCE_GAP = 2`; `ProvingPlan.ladder(family: string, variants: { string }): { { id: string, rack: string } }`; `ProvingPlan.sequence(family: string, variants: { string }): { { id: string, delaySeconds: number } }`.

- [ ] **Step 1: Write the failing spec**

`roblox/tests/ProvingPlan.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ProvingPlan = require("../src/shared/ProvingPlan")

describe("ProvingPlan — variants onto racks and clocks", function()
    test("ladder maps variants to racks A.. in order", function()
        local plan = ProvingPlan.ladder("kiku", { "v1", "v2", "v3" })
        expect(#plan).toBe(3)
        expect(plan[1].id).toBe("draft:kiku/v1")
        expect(plan[1].rack).toBe("Rack_A")
        expect(plan[3].rack).toBe("Rack_C")
    end)

    test("ladder caps at the five racks", function()
        local plan = ProvingPlan.ladder("x", { "a", "b", "c", "d", "e", "f", "g" })
        expect(#plan).toBe(5)
        expect(plan[5].rack).toBe("Rack_E")
    end)

    test("sequence fires everything from Rack_C's clock, SEQUENCE_GAP apart", function()
        local plan = ProvingPlan.sequence("kiku", { "v1", "v2", "v3" })
        expect(#plan).toBe(3)
        expect(plan[1].delaySeconds).toBe(0)
        expect(plan[2].delaySeconds).toBe(ProvingPlan.SEQUENCE_GAP)
        expect(plan[3].delaySeconds).toBe(2 * ProvingPlan.SEQUENCE_GAP)
        expect(plan[2].id).toBe("draft:kiku/v2")
    end)

    test("empty variants make empty plans", function()
        expect(#ProvingPlan.ladder("kiku", {})).toBe(0)
        expect(#ProvingPlan.sequence("kiku", {})).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

`roblox/src/shared/ProvingPlan.luau`:

```lua
--!strict
-- HOW A FAMILY OF DRAFTS BECOMES A FIRING PLAN. Pure: the panel controller executes these
-- plans (one RequestProvingFire per entry); the server never learns about modes. Ladder is
-- the range's whole reason to have five racks — variants burst side by side for comparison;
-- sequence is for shells whose read needs clean air.
local ProvingPlan = {}

ProvingPlan.RACKS = { "Rack_A", "Rack_B", "Rack_C", "Rack_D", "Rack_E" }
ProvingPlan.SEQUENCE_RACK = "Rack_C"
ProvingPlan.SEQUENCE_GAP = 2 -- seconds between sequence launches

local function draftId(family: string, variant: string): string
    return "draft:" .. family .. "/" .. variant
end

function ProvingPlan.ladder(family: string, variants: { string }): { { id: string, rack: string } }
    local plan = {}
    for i = 1, math.min(#variants, #ProvingPlan.RACKS) do
        table.insert(plan, { id = draftId(family, variants[i]), rack = ProvingPlan.RACKS[i] })
    end
    return plan
end

function ProvingPlan.sequence(family: string, variants: { string }): { { id: string, delaySeconds: number } }
    local plan = {}
    for i, variant in variants do
        table.insert(plan, { id = draftId(family, variant), delaySeconds = (i - 1) * ProvingPlan.SEQUENCE_GAP })
    end
    return plan
end

return ProvingPlan
```

- [ ] **Step 4: Run tests to verify green**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint and commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/ProvingPlan.luau tests/ProvingPlan.spec.luau
git commit -m "feat(fireworks): ProvingPlan -- pure ladder and sequence firing plans"
```

---

### Task 4: FireworkController resolves drafts

**Files:**
- Modify: `roblox/src/client/FireworkController.client.luau` (require block ~line 25; `play()` ~line 152)

**Interfaces:**
- Consumes: `FireworkDrafts.resolve(id)` (Task 2).
- Produces: any `FireworkLaunched` payload whose `shellId` is `draft:<family>/<variant>` now renders. Later tasks (5, 7) rely on exactly this.

No unit test: this file is untested by design (its own header explains why); the change is two lines and the decision (`resolve`) is already covered by Task 2's spec.

- [ ] **Step 1: Add the require**

After `local FireworkCatalog = require(shared:WaitForChild("FireworkCatalog"))` (line 25), add:

```lua
local FireworkDrafts = require(shared:WaitForChild("FireworkDrafts"))
```

- [ ] **Step 2: Widen the resolution**

In `play()`, replace:

```lua
    local recipe = FireworkCatalog.RECIPES[payload.shellId]
    if not recipe then
        return -- the contract test exists so this cannot happen in a shipped build
    end
```

with:

```lua
    -- Shipped shells first, then proving drafts ("draft:family/variant" — Studio only;
    -- resolve() is nil for anything else). Same interpreter either way: what the range
    -- proves is exactly what a player will get.
    local recipe = FireworkCatalog.RECIPES[payload.shellId] or FireworkDrafts.resolve(payload.shellId)
    if not recipe then
        return -- the contract test exists so this cannot happen in a shipped build
    end
```

- [ ] **Step 3: Lint, test, commit**

```bash
stylua --check src tests tools && selene src tools && lune run tests/run
git add src/client/FireworkController.client.luau
git commit -m "feat(fireworks): controller resolves draft: ids through the production phase player"
```

---

### Task 5: RequestProvingFire — remote and Studio-gated server handler

**Files:**
- Modify: `roblox/default.project.json` (RoshamboRemotes block, ~line 35, AS TEXT)
- Modify: `roblox/src/server/main.server.luau` (service getters at top; remote handles ~line 101; new handler after the `RequestFireworkLaunch` handler ends ~line 1318)

**Interfaces:**
- Consumes: `FireworkLaunched` broadcast (existing); `ProvingGround`/rack parts by name (Task 6 builds them; until then the handler validates and finds nothing, which is correct).
- Produces: RemoteEvent `ReplicatedStorage.RoshamboRemotes.RequestProvingFire`, signature `FireServer(shellOrDraftId: string, rackName: string)`. Task 7's panel fires it.

- [ ] **Step 1: Declare the remote (text edit)**

In `roblox/default.project.json`, replace the line:

```
                "FireworkState": { "$className": "RemoteEvent" },
```

with:

```
                "FireworkState": { "$className": "RemoteEvent" },
                "RequestProvingFire": { "$className": "RemoteEvent" },
```

(If the trailing comma differs because the entry is last in its block, match the file's actual text — Edit on exact lines, never a JSON reparse.)

- [ ] **Step 2: Server handler**

In `main.server.luau`: confirm `RunService` is among the service getters at the top of the file; it is not currently imported, so add beside the existing getters:

```lua
local RunService = game:GetService("RunService")
```

Beside the other remote handles (after line 103 `local FireworkState = ...`):

```lua
local RequestProvingFire = remotes:WaitForChild("RequestProvingFire") :: RemoteEvent
```

After the `RequestFireworkLaunch.OnServerEvent` handler (after line 1318):

```lua
-- THE PROVING RANGE (spec 2026-09-01-proving-range-design). Studio-only: fires any shell or
-- draft id from a named proving rack through the SAME FireworkLaunched broadcast the spend
-- path uses — director, LOD, pooling all engaged — but with NO inventory spend and NO backend
-- call. The IsStudio gate is the whole security model: a published client's request dies here.
RequestProvingFire.OnServerEvent:Connect(function(_player, shellId, rackName)
    if not RunService:IsStudio() then
        return
    end
    if typeof(shellId) ~= "string" or typeof(rackName) ~= "string" then
        return
    end
    local stage = workspace:FindFirstChild("RoshamboStage")
    local ground = stage and stage:FindFirstChild("ProvingGround")
    local rack = ground and ground:FindFirstChild(rackName)
    if not (rack and rack:IsA("BasePart")) then
        return
    end
    FireworkLaunched:FireAllClients({
        shellId = shellId,
        origin = rack.Position + Vector3.new(0, 3, 0),
        seed = math.random(1, 2 ^ 31 - 1),
        by = "proving",
    })
end)
```

- [ ] **Step 3: Lint, test, commit**

```bash
stylua --check src tests tools && selene src tools && lune run tests/run
git add default.project.json src/server/main.server.luau
git commit -m "feat(fireworks): RequestProvingFire -- Studio-gated rack fire over the production broadcast"
```

---

### Task 6: ProvingGround builder — five racks, plaque letters, firing post

**Files:**
- Create: `roblox/tools/builders/ProvingGround.luau`
- Modify: `roblox/tools/genmodels.luau` (require + OUTPUTS entry)
- Modify: `roblox/src/shared/WorkspaceConvention.luau` (`DECLARED_STAGE_CHILDREN`)
- Modify: `roblox/default.project.json` (RoshamboStage block, AS TEXT)
- Test: `roblox/tests/ProvingGround.spec.luau`
- Generated: `roblox/assets/ProvingGround.model.json` (committed; never hand-edit)

**Interfaces:**
- Consumes: `Spec` helpers (`tools/builders/Spec.luau`); `ProvingPlan.RACKS` (Task 3) for the rack names; Machiya's letter recipe (`tools/builders/Machiya.luau` `kanjiLabel`, lines ~37–104) as the SurfaceGui reference — same canvas configuration (`SizingMode = "PixelsPerStud"`, small canvas, fixed `TextSize`; `TextScaled` is unreliable).
- Produces: model `RoshamboStage.ProvingGround` containing five `BasePart` racks named per `ProvingPlan.RACKS`, each with a plaque child carrying a SurfaceGui letter (A–E), plus a `BasePart` named `FiringPost`. `ProvingGround.build(): Spec.PartSpec`; constants `ProvingGround.ORIGIN`, `ProvingGround.YAW_DEG` (provisional until Task 8's survey bakes them).

Geometry (all coordinates local to ORIGIN before yaw, following the FallsDock baked-constants pattern):
- Racks along local X at offsets −24, −12, 0, +12, +24 (12-stud spacing per spec), tubes facing up.
- Each rack: a main mortar tube — vertical cylinder, `Size = {3, 1.4, 1.4}` with `Spec.ROT.CYL_VERTICAL`, `Material = "Metal"`, `Color = {0.20, 0.20, 0.22}` — standing on a timber base block `{3, 0.6, 3}` in the grey-cypress treatment (`Material = "Wood"`, `Color = {0.847, 0.839, 0.808}` — 216/214/206, the FallsLanding timber). The tube part IS `Rack_X` (the server fires from its `Position`); base and plaque are children.
- Plaque: a `{1.2, 1.2, 0.15}` timber part on the firing-post side of the base (local +Z face toward the post), top at tube height, carrying a SurfaceGui (Face `"Back"` or `"Front"` to face +Z — verify against Machiya's Face usage) with one TextLabel: the rack's letter (`A`–`E`), dark ink color `{0.15, 0.13, 0.11}`, `TextSize` ~90 on a small PixelsPerStud canvas per the Machiya recipe, `BackgroundTransparency = 1`.
- `FiringPost`: a `{1.2, 0.6, 1.2}` stone part (`Material = "Slate"`, `Color = {0.55, 0.55, 0.52}`) at local `{0, 0, 14}` — 14 studs from the rack line, facing them.
- Provisional placement constants (replaced by Task 8's survey — same workflow as FallsDock's "user-dragged FallsDockMarker"): `ORIGIN = { -352, 205, -20 }`, `YAW_DEG = 0`, each commented `-- PROVISIONAL: baked from ProvingGroundMarker survey (Task 8)`.
- NO `Tags` property anywhere — racks must not be `FireworkLaunchSite`s.
- All parts `Anchored` (Spec.part defaults this), `CanCollide = true` for base/post, `false` for tubes and plaques.

- [ ] **Step 1: Write the failing spec**

`roblox/tests/ProvingGround.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ProvingGround = require("../tools/builders/ProvingGround")
local ProvingPlan = require("../src/shared/ProvingPlan")

local LETTERS = { Rack_A = "A", Rack_B = "B", Rack_C = "C", Rack_D = "D", Rack_E = "E" }

local function childNamed(spec: any, name: string): any?
    for _, c in (spec.children or {}) :: { any } do
        if c.name == name then
            return c
        end
    end
    return nil
end

local function findClass(spec: any, className: string): any?
    for _, c in (spec.children or {}) :: { any } do
        if c.className == className then
            return c
        end
        local deeper = findClass(c, className)
        if deeper then
            return deeper
        end
    end
    return nil
end

local function eachSpec(spec: any, fn: (any) -> ())
    fn(spec)
    for _, c in (spec.children or {}) :: { any } do
        eachSpec(c, fn)
    end
end

describe("ProvingGround — the yard the range fires from", function()
    local model = ProvingGround.build()

    test("every rack ProvingPlan can name exists as a BasePart with its plaque letter", function()
        for _, rackName in ProvingPlan.RACKS do
            local rack = childNamed(model, rackName)
            expect(rack ~= nil).toBe(true)
            assert(rack)
            expect(rack.className).toBe("Part") -- the server fires from rack.Position
            local gui = findClass(rack, "SurfaceGui")
            expect(gui ~= nil).toBe(true)
            assert(gui)
            local label = findClass(gui, "TextLabel") or gui.children and gui.children[1]
            expect(label ~= nil).toBe(true)
            assert(label)
            expect(label.properties.Text).toBe(LETTERS[rackName])
        end
    end)

    test("racks sit 12 studs apart along one line", function()
        local xs = {}
        for _, rackName in ProvingPlan.RACKS do
            local rack = childNamed(model, rackName)
            assert(rack)
            table.insert(xs, rack.properties.CFrame[1])
        end
        table.sort(xs)
        for i = 2, #xs do
            expect(math.abs((xs[i] - xs[i - 1]) - 12) < 0.01).toBe(true)
        end
    end)

    test("the firing post exists, set back from the rack line", function()
        local post = childNamed(model, "FiringPost")
        expect(post ~= nil).toBe(true)
        assert(post)
        local rackC = childNamed(model, "Rack_C")
        assert(rackC)
        local dz = math.abs(post.properties.CFrame[3] - rackC.properties.CFrame[3])
        expect(dz > 10).toBe(true)
    end)

    test("NOTHING IN THE YARD IS A LAUNCH SITE and nothing floats unanchored", function()
        eachSpec(model, function(spec)
            local props = spec.properties or {}
            expect(props.Tags == nil).toBe(true)
            if spec.className == "Part" then
                expect(props.Anchored).toBe(true)
            end
        end)
    end)
end)
```

Note: the yaw test above assumes `YAW_DEG = 0` keeps racks on a world-X line; write the spacing test against the builder's LOCAL offsets if the implementation applies yaw before emitting (compute spacing as 3D distance between adjacent rack positions instead of raw X — distance is yaw-invariant; prefer that form).

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — module `../tools/builders/ProvingGround` not found.

- [ ] **Step 3: Write the builder**

`roblox/tools/builders/ProvingGround.luau` per the geometry above. Structure it like `FallsDock.luau`: constants block (ORIGIN/YAW marked PROVISIONAL), pure helpers, `ProvingGround.build(): Spec.PartSpec` returning a Model spec named by genmodels. Apply yaw about ORIGIN when computing each part's world CFrame (with YAW_DEG = 0 this is the identity; bake-time yaw must not require restructuring). Copy the SurfaceGui/TextLabel property shape from Machiya's `kanjiLabel` (lines ~37–104) — one letter per plaque, no `TextScaled`.

- [ ] **Step 4: Register in genmodels and generate**

In `tools/genmodels.luau`: add `local ProvingGround = require("./builders/ProvingGround")` beside the other builder requires, and in `OUTPUTS` add:

```lua
    ["ProvingGround"] = ProvingGround.build(),
```

Run: `lune run tools/genmodels`
Expected: writes `assets/ProvingGround.model.json` (and rewrites the others byte-identically — `git status` must show ONLY the new file changed; any other diff means a builder is non-deterministic and the task stops there).

- [ ] **Step 5: Declare the stage child**

In `src/shared/WorkspaceConvention.luau`, add to `DECLARED_STAGE_CHILDREN`:

```lua
    "ProvingGround", -- fireworks proving range at FallsLanding (assets/ProvingGround.model.json)
```

In `roblox/default.project.json` (AS TEXT), replace:

```
                "FallsDock": { "$path": "assets/FallsDock.model.json" },
```

with:

```
                "FallsDock": { "$path": "assets/FallsDock.model.json" },
                "ProvingGround": { "$path": "assets/ProvingGround.model.json" },
```

- [ ] **Step 6: Run tests to verify green**

Run: `lune run tests/run`
Expected: PASS, including `WorkspaceConvention.spec.luau` (it checks the declared list's internal consistency).

- [ ] **Step 7: Lint and commit**

```bash
stylua --check src tests tools && selene src tools
git add tools/builders/ProvingGround.luau tools/genmodels.luau assets/ProvingGround.model.json \
  src/shared/WorkspaceConvention.luau default.project.json tests/ProvingGround.spec.luau
git commit -m "feat(fireworks): ProvingGround builder -- five racks, plaque letters, firing post"
```

---

### Task 7: ProvingController — the Studio-only panel

**Files:**
- Create: `roblox/src/client/ProvingController.client.luau`

**Interfaces:**
- Consumes: `RequestProvingFire:FireServer(id, rackName)` (Task 5); `ProvingPlan` (Task 3); `FireworkDrafts.familyNames/variantsOf` (Task 2); `FireworkCatalog.RECIPES` (existing); `RoshamboStage.ProvingGround.FiringPost` (Task 6). Cursor grip pattern from `ShopController.client.luau` (~lines 102–130): `BindToRenderStep` at `Enum.RenderPriority.Camera.Value + 1` forcing `MouseBehavior = Default` while the panel is open, unbound (once, guarded) on close.
- Produces: the owner-facing range UI. No later task consumes it.

Behavior (all of it inside a top-of-file `if not RunService:IsStudio() then return end` guard, so in a published place the script is inert by its first statement):
- Creates a `ProximityPrompt` on `FiringPost` (`ActionText = "Open Panel"`, `ObjectText = "Proving Range"`, `RequiresLineOfSight = false`, `MaxActivationDistance = 12`). Client-created, so the published place holds no prompt at all.
- Panel: one `ScreenGui` (`ResetOnSpawn = false`) with a scrolling frame. Sections:
  - **Drafts** — one row per family (from `familyNames()`): family name, `[Ladder]` button, `[Seq]` button, then one small button per variant (from `variantsOf()`) firing that variant alone from `ProvingPlan.SEQUENCE_RACK`.
  - **Shipped** — one row per catalog id (sorted), a `[Fire]` button firing it from `ProvingPlan.SEQUENCE_RACK`.
  - **Night** toggle button and a **Close** button.
- Fire wiring: single → `RequestProvingFire:FireServer(id, rack)`; ladder → iterate `ProvingPlan.ladder(family, variants)` firing all entries in the same frame; sequence → iterate `ProvingPlan.sequence(...)`, `task.delay(entry.delaySeconds, ...)` per entry.
- Night toggle: on first enable, save `Lighting.ClockTime`; while on, set `Lighting.ClockTime = 22`; on disable or panel close, restore the saved value. Local only — never a server write, so it cannot fight the shipped day-night cycle.
- Cursor grip: copy the ShopController pattern verbatim (bind on open, unbind-once on close — `Unbind` on a never-bound name THROWS, hence the guard flag; the comment at ShopController line ~116 explains).
- UI styling is functional-minimal (dark frame, monospace-ish default font, text buttons); this panel is a dev tool, not an art surface — do not spend rounds on its look.
- No unit tests (client file; all decisions already live in Tasks 2/3's pure modules). Verified live in Task 8.

- [ ] **Step 1: Write the controller** per the behavior block above.
- [ ] **Step 2: Lint and full suite**

```bash
stylua --check src tests tools && selene src tools && lune run tests/run
```

- [ ] **Step 3: Commit**

```bash
git add src/client/ProvingController.client.luau
git commit -m "feat(fireworks): ProvingController -- Studio-only range panel, ladder/sequence/night"
```

---

### Task 8: Placement, live verification, owner gate — MAIN SESSION ONLY

**Do not dispatch this task to a subagent.** It needs the connected Studio MCP session and the owner's eyes, and it follows the standing rulings: place the camera / set the scene, then the OWNER looks; one attempt, then ask.

**Files:**
- Modify: `roblox/tools/builders/ProvingGround.luau` (bake surveyed ORIGIN/YAW)
- Regenerate: `roblox/assets/ProvingGround.model.json`
- Modify: `docs/wiki/world/fireworks.md` (As built: one proving-range paragraph + wikilink to the spec), `docs/wiki/log.md` (ship entry)

- [ ] **Step 1: Rojo reconnect.** `default.project.json` gained entries mid-session in Tasks 5–6; entries added mid-session arrive without content until Rojo reconnects (the documented mid-session trap — the hiyodori's mesh-less MeshPart). Ask the owner to reconnect the Rojo plugin, then verify via MCP that `Workspace.RoshamboStage.ProvingGround` exists with five racks and `ReplicatedStorage.RoshamboRemotes.RequestProvingFire` exists.
- [ ] **Step 2: Marker survey** (the FallsDock workflow): create a `ProvingGroundMarker` part near FallsLanding, ask the owner to drag it to where the rack line should stand (and rotate it for the line's direction). Read back its CFrame via `execute_luau`.
- [ ] **Step 3: Bake** the surveyed ORIGIN/YAW_DEG into `ProvingGround.luau` (constants comment updated from PROVISIONAL to the survey date), run `lune run tools/genmodels`, `lune run tests/run`, confirm Rojo syncs the moved model, delete the marker.
- [ ] **Step 4: Owner Play gate.** Owner presses Play, walks to the firing post, opens the panel, and fires: one single, the kiku ladder, the kiku sequence, night toggle on and off, one shipped shell. Watch for: bursts reading side-by-side at 12-stud spacing, plaque letters legible from the post, no director starvation, ClockTime restored after night. Fix rounds as the owner calls them — an approach is abandoned when the owner says it is.
- [ ] **Step 5: Wiki + commit.** Update `fireworks.md` (As built) and append a `ship` entry to `log.md` recording the gate. Commit:

```bash
git add tools/builders/ProvingGround.luau assets/ProvingGround.model.json docs/wiki/world/fireworks.md docs/wiki/log.md
git commit -m "feat(fireworks): proving range placed at FallsLanding -- owner-gated in Play"
```

Then remind the owner: the place must be SAVED/PUBLISHED from Studio for the yard to persist (publishing, never `rojo build`).

---

## Self-Review (performed at write time)

- **Spec coverage:** yard (T6, T8), physical labels (T6), drafts + namespace + fixture absence (T2), gating + remote + real broadcast path (T5), controller resolution (T4), panel + 3 fire modes + night (T7), promotion (no task — the spec confirms existing CI covers it; promotion happens per-shell later), tests incl. schema + catalog coverage (T1) and ladder logic (T3). Builder registered in WorkspaceConvention (T6) — spec implies it via the Rojo convention.
- **Placeholder scan:** ORIGIN/YAW are explicitly PROVISIONAL by design with a defined bake step (T8) — the established FallsDock marker workflow, not a TBD. Task 7 has a behavior contract instead of full code: acceptable because every decision it encodes lives in T2/T3 modules with specs, and its two risky idioms (cursor grip, prompt) cite exact prior art lines.
- **Type consistency:** `resolve(id) : any?` (T2) matches T4's use; `ladder → {id, rack}` / `sequence → {id, delaySeconds}` (T3) match T7's wiring; rack names flow from `ProvingPlan.RACKS` into T5 (FindFirstChild), T6 (part names), T7 (plan entries).
