# 花火屋 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the firework shop — a machiya on the reserved shop corridor with a working counter — so that the four shells and three mortars the server already sells can actually be bought.

**Architecture:** A pure Luau builder emits the building as committed Rojo JSON, exactly like the other seven hero props. A pure threshold module owns the "am I inside the shop" rule so it can be tested, because no harness in this repo loads a `.client.luau`. The panel is a new client controller that renders server-supplied prices and counts and evaluates nothing. Two shipped defects are fixed en route: prices never reached the client, and buying never refreshed the count.

**Tech Stack:** Luau (Rojo + Lune), TypeScript (Express/vitest), stylua, selene.

## Global Constraints

- **The owner's transform is authoritative, not a proposal.** Building extents: **x −1.67 … 16.26, z 44.00 … 52.00, floor y 113.10, top y 127.36** (17.93 wide × 8.00 deep × 14.26 tall, yaw 0). Read back from the holdout block they moved in Studio. Never re-derive these.
- **The promenade is inviolable at ground level.** `shopCorridor = { -20, 28, 34, 44 }`. No part may stand in it. The eave is the single deliberate exception and is aerial only — see Task 4.
- **The shop must stay subordinate to the shōrō.** Top 127.36 against the shōrō's 136.5. A roof change that closes that 9-stud gap is a defect.
- **The client never evaluates a requirement or a price.** It renders `{ count, launchable, reason }` and a server-supplied catalog. Hardcoding a price client-side is the defect class this project has been bitten by three times.
- **Outer edges flush** — posts and girders inset so their outer face aligns with the slab edge (`x ± POST_W/2`).
- **Committed builder output must be byte-identical on arm64 and x86_64** or the CI drift check fails. Integer arithmetic only; no transcendental hashes.
- **Materials come from `ZenDojo.palette`** — `timber`, `cypressWeathered`, `slateTile`, `ink`, `ivory`, `gold`. No new palette entries.
- Lint gates: `stylua --check src tests tools && selene src tools` from `roblox/`, zero warnings. Tests: `lune run tests/run` from `roblox/`, `npm test && npm run build` from `server/`.

---

### Task 1: The catalog carries shell and mortar prices

Closes spec §6a. `EconomyState.catalog` sends `PRICES` from `economy.ts`; `SHELL_PRICES` and `MORTAR_PRICES` live in `fireworks.ts` and reach nobody, so a panel would have to hardcode them.

**Files:**
- Modify: `server/src/routes/apiV1.ts` (the `/economy` route's `catalog` field, ~line 226)
- Test: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: `SHELL_PRICES`, `MORTAR_PRICES` from `server/src/fireworks.ts`.
- Produces: `GET /api/v1/players/:id/economy` → `catalog.fireworks: Record<string, number>` and `catalog.mortars: Record<string, number>`.

- [ ] **Step 1: Write the failing test**

Add inside the existing `describe('fireworks', ...)` block in `server/src/routes/apiV1.test.ts`:

```typescript
        it('the economy catalog carries shell and mortar prices', async () => {
            // Without this the shop panel has to hardcode prices, which is the defect class
            // this project has already hit three times: a number authoritative on the server,
            // re-derived client-side, going stale.
            await User.create({ robloxId: '907', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/907/economy')
                .set('X-API-Key', API_KEY)
                .expect(200);
            expect(res.body.catalog.fireworks).toEqual({
                firecracker: 1,
                peony: 3,
                willow: 4,
                ishibana: 6,
            });
            expect(res.body.catalog.mortars).toEqual({
                'mortar:S': 40,
                'mortar:M': 250,
                'mortar:L': 1000,
            });
        });

        it('every sellable shell has a catalogued price', async () => {
            // The gate that matters: a shell added to SHELL_IDS but not to the payload would
            // render in the shop with a blank price.
            await User.create({ robloxId: '908', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/908/economy')
                .set('X-API-Key', API_KEY)
                .expect(200);
            for (const id of SHELL_IDS) {
                expect(typeof res.body.catalog.fireworks[id]).toBe('number');
            }
        });
```

Add `SHELL_IDS` to the file's imports from `../fireworks` (the file already imports nothing from it; add a new import line beside the others at the top):

```typescript
import { SHELL_IDS } from '../fireworks';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `server/`: `npx vitest run src/routes/apiV1.test.ts`

Expected: FAIL — `catalog.fireworks` is `undefined`.

- [ ] **Step 3: Extend the payload**

In `server/src/routes/apiV1.ts`, add to the imports beside the existing `fireworks` import:

```typescript
import { shellStates, SHELL_IDS, LaunchContext, SHELL_PRICES, MORTAR_PRICES } from '../fireworks';
```

(That line already exists importing the first three — replace it with this one rather than adding a second import from the same module.)

Then in the `/players/:robloxUserId/economy` route, replace `catalog: PRICES,` with:

```typescript
                // The client is told PRICES, never requirements. Shells and mortars live in
                // fireworks.ts rather than economy.ts, so they have to be spliced in here — the
                // alternative is a second copy of every price in the Roblox client.
                catalog: { ...PRICES, fireworks: SHELL_PRICES, mortars: MORTAR_PRICES },
```

- [ ] **Step 4: Run the tests to verify they pass**

Run from `server/`: `npx vitest run src/routes/apiV1.test.ts`

Expected: PASS.

- [ ] **Step 5: Verify the gate by mutation**

Temporarily delete the `ishibana: 6,` line from `SHELL_PRICES` in `server/src/fireworks.ts` and re-run.

Expected: the "every sellable shell has a catalogued price" test FAILS. If it passes, the gate is decoration. **Restore the line before continuing.**

- [ ] **Step 6: Run the full suite and commit**

```bash
cd server && npm test && npm run build && cd ..
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): the economy catalog carries shell and mortar prices"
```

---

### Task 2: Buying a shell refreshes the count

Closes spec §6b. `RequestPurchase` echoes `EconomyState` so points update, but nothing pushes `FireworkState` — a player would buy a peony, watch their balance drop, and see the picker still reading ×0 until the next reveal.

**Files:**
- Modify: `roblox/src/server/main.server.luau` (the `RequestPurchase.OnServerEvent` handler)

**Interfaces:**
- Consumes: `pushFireworkState(player: Player)`, already defined in this file by the fireworks referee.
- Produces: nothing new. `FireworkState` fires after a firework or mortar purchase.

- [ ] **Step 1: Find the purchase handler's success path**

Run from `roblox/`:

```bash
grep -n "RequestPurchase.OnServerEvent" -A 40 src/server/main.server.luau | grep -n "echoEconomy"
```

The handler ends its success path with an `echoEconomy(player, uid)` call. That is the anchor.

- [ ] **Step 2: Push firework state after a firework or mortar purchase**

Immediately after that `echoEconomy(player, uid)` inside the `RequestPurchase` handler, add:

```lua
            -- Buying a shell changes a COUNT, and the count lives in FireworkState, not
            -- EconomyState. Without this the balance drops and the picker keeps reading the old
            -- number until the next reveal happens to push state for its own reasons — which
            -- reads as the purchase having failed.
            if typeof(item) == "string" and (item:sub(1, 9) == "firework:" or item:sub(1, 7) == "mortar:") then
                if pushFireworkState then
                    pushFireworkState(player)
                end
            end
```

`item` is the handler's existing local holding the requested item string. If it is named differently in the handler, use that name — do not introduce a second local.

- [ ] **Step 3: Run every gate**

Run from `roblox/`:

```bash
stylua src tests tools && stylua --check src tests tools && selene src tools && lune run tests/run
```

Expected: clean, zero warnings, all tests pass. **Note what this does and does not prove:** no harness loads `main.server.luau`. Green means nothing regressed elsewhere; the behaviour is a Studio-gate item.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "fix(roblox): buying a shell refreshes the count, not just the balance"
```

---

### Task 3: `ShopThreshold` — the inside test

The "am I in the shop" rule, pure and Lune-testable, for the same reason `LaunchSites` is pure: no harness in this repo loads a `.client.luau`, so a rule worth trusting has to live outside one.

**Files:**
- Create: `roblox/src/shared/ShopThreshold.luau`
- Test: `roblox/tests/ShopThreshold.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ShopThreshold.Box = { x0: number, x1: number, y0: number, y1: number, z0: number, z1: number }`
  - `ShopThreshold.isInside(pos: { x: number, y: number, z: number }, box: Box): boolean`
  - `ShopThreshold.FRONT_INSET = 1`

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/ShopThreshold.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShopThreshold = require("../src/shared/ShopThreshold")

local function v(x: number, y: number, z: number)
    return { x = x, y = y, z = z }
end

-- 花火屋's volume: the owner's footprint, with the front edge inset one stud past the frontage.
local SHOP = { x0 = -1.67, x1 = 16.26, y0 = 113.1, y1 = 118.0, z0 = 45.0, z1 = 52.0 }

describe("ShopThreshold", function()
    test("a player standing in the middle of the shop is inside", function()
        expect(ShopThreshold.isInside(v(7, 114, 48), SHOP)).toBe(true)
    end)

    test("THE PROMENADE IS NOT THE SHOP", function()
        -- The whole reason the volume starts at z45 rather than the z44 frontage: a trigger on
        -- the frontage line fires on every player crossing the square.
        expect(ShopThreshold.isInside(v(7, 114, 44.5), SHOP)).toBe(false)
        expect(ShopThreshold.isInside(v(7, 114, 36), SHOP)).toBe(false)
    end)

    test("the front inset is exactly one stud", function()
        expect(ShopThreshold.FRONT_INSET).toBe(1)
    end)

    test("walking off either end leaves the shop", function()
        expect(ShopThreshold.isInside(v(-2.5, 114, 48), SHOP)).toBe(false)
        expect(ShopThreshold.isInside(v(17, 114, 48), SHOP)).toBe(false)
    end)

    test("walking through the back wall leaves the shop", function()
        expect(ShopThreshold.isInside(v(7, 114, 53), SHOP)).toBe(false)
    end)

    test("height is bounded, so standing on the roof is not shopping", function()
        expect(ShopThreshold.isInside(v(7, 126, 48), SHOP)).toBe(false)
        expect(ShopThreshold.isInside(v(7, 110, 48), SHOP)).toBe(false)
    end)

    test("the bounds are inclusive at their faces", function()
        expect(ShopThreshold.isInside(v(-1.67, 113.1, 45.0), SHOP)).toBe(true)
        expect(ShopThreshold.isInside(v(16.26, 118.0, 52.0), SHOP)).toBe(true)
    end)

    test("a degenerate box admits nothing", function()
        local empty = { x0 = 0, x1 = 0, y0 = 0, y1 = 0, z0 = 0, z1 = 0 }
        expect(ShopThreshold.isInside(v(1, 1, 1), empty)).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — the module does not exist.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/ShopThreshold.luau`:

```lua
--!strict
-- AM I IN THE SHOP? Pure and Roblox-free (positions are plain {x,y,z} tables) so it runs under
-- Lune — the client controller converts Vector3 at the boundary.
--
-- This exists as its own module for one reason: no harness in this repo loads a `.client.luau`.
-- A rule embedded in the controller could not be tested at all, and the rule here is not
-- obvious — see FRONT_INSET.
local ShopThreshold = {}

export type Vec = { x: number, y: number, z: number }
export type Box = { x0: number, x1: number, y0: number, y1: number, z0: number, z1: number }

-- THE WHOLE DESIGN, IN ONE NUMBER. The shop's frontage is open — there is no door — so the
-- trigger volume starts one stud INSIDE the building rather than on the frontage line. A volume
-- flush with the frontage would fire on every player walking the promenade past the shop, and
-- "walk in, the panel opens" would become "cross the square, the panel flickers".
ShopThreshold.FRONT_INSET = 1

function ShopThreshold.isInside(pos: Vec, box: Box): boolean
    return pos.x >= box.x0
        and pos.x <= box.x1
        and pos.y >= box.y0
        and pos.y <= box.y1
        and pos.z >= box.z0
        and pos.z <= box.z1
end

return ShopThreshold
```

Note the degenerate-box test passes because `(1,1,1)` lies outside a zero-volume box at the origin; no special case is needed.

- [ ] **Step 4: Run to verify it passes, then lint**

Run from `roblox/`:

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
```

Expected: PASS, clean, zero warnings.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/ShopThreshold.luau roblox/tests/ShopThreshold.spec.luau
git commit -m "feat(roblox): the shop threshold, and the one stud that keeps it off the promenade"
```

---

### Task 4: The `Machiya` builder

The building. Pure and deterministic, emitted to committed Rojo JSON like the other seven hero props.

**Files:**
- Create: `roblox/tools/builders/Machiya.luau`
- Create: `roblox/tests/Machiya.spec.luau`
- Modify: `roblox/tools/genmodels.luau`
- Modify: `roblox/default.project.json`
- Generated: `roblox/assets/Hanabiya.model.json` (committed, never hand-edited)

**Interfaces:**
- Consumes: `Spec` (`Spec.part`, `Spec.model`, `Spec.cframe`), `ZenDojo.palette`.
- Produces: `Machiya.build(palette: any, layout: any): PartSpec` — a Model named `Hanabiya` containing a child named `Threshold` (the trigger volume) and a child named `Kanban` (the sign board face).

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/Machiya.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Machiya = require("../tools/builders/Machiya")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")

local model = Machiya.build(ZenDojo.palette, ArenaLayout)

-- THE OWNER'S TRANSFORM, read back from the holdout block they placed in Studio 2026-08-05.
-- These are not proposals; a change here means the building moved.
local X0, X1 = -1.67, 16.26
local Z0, Z1 = 44.00, 52.00
local FLOOR, TOP = 113.10, 127.36

local function find(node, name)
    for _, c in node.children do
        if c.name == name then
            return c
        end
    end
    return nil
end

local function countPrefix(node, prefix)
    local n = 0
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then
            n += 1
        end
    end
    return n
end

-- a part's y extents from its CFrame array + Size
local function yspan(part)
    local cy = part.properties.CFrame[2]
    local h = part.properties.Size[2]
    return cy - h / 2, cy + h / 2
end

describe("Machiya — the owner's envelope", function()
    test("it is a model named Hanabiya", function()
        expect(model.name).toBe("Hanabiya")
        expect(model.className).toBe("Model")
    end)

    test("the floor slab spans the owner's footprint exactly", function()
        local slab = find(model, "FloorSlab")
        expect(slab ~= nil).toBe(true)
        expect(slab.properties.Size[1]).toBe(X1 - X0)
        expect(slab.properties.Size[3]).toBe(Z1 - Z0)
        -- centred on the footprint
        expect(math.abs(slab.properties.CFrame[1] - (X0 + X1) / 2) < 0.001).toBe(true)
        expect(math.abs(slab.properties.CFrame[3] - (Z0 + Z1) / 2) < 0.001).toBe(true)
    end)

    test("NOTHING RISES ABOVE THE OWNER'S TOP", function()
        -- The shop must stay 9 studs subordinate to the shōrō (136.5). A roof tweak that
        -- closes that gap is a defect, not a style change.
        for _, c in model.children do
            if c.properties.Size and c.properties.CFrame then
                local _, hi = yspan(c)
                expect(hi <= TOP + 0.001).toBe(true)
            end
        end
    end)

    test("nothing stands on the ground inside the promenade", function()
        -- shopCorridor z28..44 is inviolable at ground level. The eave is the ONE exception
        -- and is aerial — so anything reaching north of z44 must clear an avatar.
        for _, c in model.children do
            if c.properties.Size and c.properties.CFrame then
                local cz, dz = c.properties.CFrame[3], c.properties.Size[3]
                local lo = yspan(c)
                if cz - dz / 2 < Z0 - 0.001 then
                    expect(lo >= FLOOR + 6).toBe(true)
                end
            end
        end
    end)
end)

describe("Machiya — what makes it a shop and not a teahouse", function()
    test("the frontage is OPEN — no wall spans it", function()
        -- The single strongest signal that this is a machiya. A wall part sitting on the
        -- frontage line would make it another teahouse.
        for _, c in model.children do
            if c.properties.Size and c.properties.CFrame and (c.name :: string):sub(1, 4) == "Wall" then
                local cz = c.properties.CFrame[3]
                expect(math.abs(cz - Z0) > 1).toBe(true)
            end
        end
    end)

    test("it has front posts, a counter and an upper floor", function()
        expect(countPrefix(model, "FrontPost") >= 4).toBe(true)
        expect(find(model, "Counter") ~= nil).toBe(true)
        expect(find(model, "UpperFloor") ~= nil).toBe(true)
    end)

    test("the eave overhangs the frontage", function()
        local eave = find(model, "Eave")
        expect(eave ~= nil).toBe(true)
        expect(eave.properties.CFrame[3] - eave.properties.Size[3] / 2 < Z0).toBe(true)
    end)

    test("kōshi lattice fills the upper storey", function()
        expect(countPrefix(model, "Koshi") >= 6).toBe(true)
    end)

    test("the noren hangs under the eave and you can walk through it", function()
        expect(countPrefix(model, "Noren") >= 3).toBe(true)
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Noren" then
                expect(c.properties.CanCollide).toBe(false)
            end
        end
    end)
end)

describe("Machiya — the parts other tasks bind to", function()
    test("the Threshold volume is inset one stud from the frontage", function()
        local t = find(model, "Threshold")
        expect(t ~= nil).toBe(true)
        local cz, dz = t.properties.CFrame[3], t.properties.Size[3]
        expect(math.abs((cz - dz / 2) - (Z0 + 1)) < 0.001).toBe(true)
        expect(math.abs((cz + dz / 2) - Z1) < 0.001).toBe(true)
    end)

    test("the Threshold is invisible and never collides or blocks a ray", function()
        local t = find(model, "Threshold")
        expect(t.properties.Transparency).toBe(1)
        expect(t.properties.CanCollide).toBe(false)
        expect(t.properties.CanQuery).toBe(false)
        expect(t.properties.CanTouch).toBe(false)
    end)

    test("the Kanban exists and faces the promenade", function()
        local k = find(model, "Kanban")
        expect(k ~= nil).toBe(true)
        expect(k.properties.CFrame[3] < (Z0 + Z1) / 2).toBe(true)
    end)
end)

describe("Machiya — the flush rule", function()
    test("front posts sit inside the slab, not proud of it", function()
        local slab = find(model, "FloorSlab")
        local sx0 = slab.properties.CFrame[1] - slab.properties.Size[1] / 2
        local sx1 = slab.properties.CFrame[1] + slab.properties.Size[1] / 2
        for _, c in model.children do
            if (c.name :: string):sub(1, 9) == "FrontPost" then
                local cx, dx = c.properties.CFrame[1], c.properties.Size[1]
                expect(cx - dx / 2 >= sx0 - 0.001).toBe(true)
                expect(cx + dx / 2 <= sx1 + 0.001).toBe(true)
            end
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — the builder does not exist.

- [ ] **Step 3: Write the builder**

Create `roblox/tools/builders/Machiya.luau`:

```lua
--!strict
-- 花火屋 — the firework shop, and the merchant row's first machiya.
--
-- A MACHIYA IS NOT A TEAHOUSE. Every enclosed structure in this canyon so far is a dwelling; a
-- shop has to read differently at a glance. What does that here: an OPEN frontage (no wall on
-- the street side, just posts and a raised timber floor), a deep eave over it, and a closed
-- upper storey of kōshi lattice carrying the sign high enough to read from the bridge.
--
-- EVERY DIMENSION BELOW IS THE OWNER'S. A holdout block was placed in Studio at the proposed
-- footprint and they moved and resized it; these are its measured extents, read back
-- 2026-08-05. The study block survives at Workspace.Sandbox.HanabiyaStudy. Do not re-derive
-- them from anything — see docs/superpowers/specs/2026-08-05-hanabiya-shop-design.md §1.
local Spec = require("./Spec")

local Machiya = {}

-- ===== the owner's envelope =====
local X0, X1 = -1.67, 16.26 -- west, east
local Z0, Z1 = 44.00, 52.00 -- frontage (north, onto the promenade), back (south, into the cut)
local FLOOR = 113.10 -- finished floor, = the karesansui datum
local TOP = 127.36 -- ridge. The shōrō tops at 136.5 and must stay above it.

local W = X1 - X0
local D = Z1 - Z0
local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2

-- ===== storey heights, derived from the envelope so they cannot drift out of it =====
local SLAB_T = 0.6 -- the raised timber floor, recipe §2's deck slab
local STOREY_H = 6.0 -- ground storey: clear height under the upper floor
local UPPER_H = 4.0 -- the closed lattice storey
local EAVE_Y = FLOOR + STOREY_H + UPPER_H -- 123.10, where the roof springs
local ROOF_RISE = TOP - EAVE_Y -- 4.26

-- The eave overhangs the frontage by this much. THIS IS THE ONE DELIBERATE ENCROACHMENT on the
-- reserved promenade, and it is aerial: its underside sits a full storey up, so nothing at
-- ground level enters the corridor. Without it the building has no shopfront shadow and reads
-- as a shed.
local EAVE_OVERHANG = 2.5
local EAVE_T = 0.5
local ROOF_RIDGE_Z = (Z0 - EAVE_OVERHANG + Z1) / 2 -- ridge centred on the ROOF span, not the walls

local POST_W = 1.125 -- recipe §2: 25% lighter than the Overlook's 1.5
local GIRDER_H, GIRDER_W = 1.2, 0.825
local WALL_T = 0.5
local KOSHI_T = 0.18
local COUNTER_H = 1.1
local COUNTER_D = 1.4

-- inset a coordinate so a post's OUTER face sits flush with the slab edge (recipe standing rule)
local function flushX(x: number): number
    if math.abs(x - X0) < 0.01 then
        return x + POST_W / 2
    elseif math.abs(x - X1) < 0.01 then
        return x - POST_W / 2
    end
    return x
end

-- row-major rotation about X, for the roof slopes
local function rotX(deg: number): { number }
    local r = math.rad(deg)
    local c, s = math.cos(r), math.sin(r)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Machiya.build(palette: any, _layout: any): any
    local children = {}
    local timber = palette.timber
    local cypress = palette.cypressWeathered
    local tile = palette.slateTile
    local ink = palette.ink

    local function add(name: string, size: { number }, pos: { number }, colour: { number }, material: string, rot: { number }?)
        table.insert(
            children,
            Spec.part(name, {
                Size = size,
                CFrame = Spec.cframe(pos, rot),
                Color = colour,
                Material = material,
                CanCollide = true,
                CastShadow = false,
            })
        )
    end

    -- ----- the raised timber floor -----
    add("FloorSlab", { W, SLAB_T, D }, { CX, FLOOR - SLAB_T / 2, CZ }, timber, "WoodPlanks")

    -- ----- the OPEN frontage: six posts, no wall -----
    local FRONT_POSTS = 6
    for i = 1, FRONT_POSTS do
        local t = (i - 1) / (FRONT_POSTS - 1)
        local x = flushX(X0 + (X1 - X0) * t)
        add(
            `FrontPost{i}`,
            { POST_W, STOREY_H, POST_W },
            { x, FLOOR + STOREY_H / 2, Z0 + POST_W / 2 },
            timber,
            "Wood"
        )
    end

    -- ----- side and back walls (ground storey) -----
    add("WallWest", { WALL_T, STOREY_H, D }, { X0 + WALL_T / 2, FLOOR + STOREY_H / 2, CZ }, cypress, "WoodPlanks")
    add("WallEast", { WALL_T, STOREY_H, D }, { X1 - WALL_T / 2, FLOOR + STOREY_H / 2, CZ }, cypress, "WoodPlanks")
    add("WallBack", { W, STOREY_H, WALL_T }, { CX, FLOOR + STOREY_H / 2, Z1 - WALL_T / 2 }, cypress, "WoodPlanks")

    -- ----- girders + the upper floor -----
    add(
        "GirderFront",
        { W, GIRDER_H, GIRDER_W },
        { CX, FLOOR + STOREY_H - GIRDER_H / 2, Z0 + GIRDER_W / 2 },
        timber,
        "Wood"
    )
    add(
        "GirderBack",
        { W, GIRDER_H, GIRDER_W },
        { CX, FLOOR + STOREY_H - GIRDER_H / 2, Z1 - GIRDER_W / 2 },
        timber,
        "Wood"
    )
    add("UpperFloor", { W, SLAB_T, D }, { CX, FLOOR + STOREY_H + SLAB_T / 2, CZ }, timber, "WoodPlanks")

    -- ----- the closed upper storey: kōshi lattice to the street, boards elsewhere -----
    local KOSHI_N = 14
    for i = 1, KOSHI_N do
        local t = (i - 0.5) / KOSHI_N
        add(
            `Koshi{i}`,
            { KOSHI_T, UPPER_H, KOSHI_T },
            { X0 + (X1 - X0) * t, FLOOR + STOREY_H + UPPER_H / 2, Z0 + KOSHI_T },
            ink,
            "Wood"
        )
    end
    add(
        "UpperWallWest",
        { WALL_T, UPPER_H, D },
        { X0 + WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, CZ },
        cypress,
        "WoodPlanks"
    )
    add(
        "UpperWallEast",
        { WALL_T, UPPER_H, D },
        { X1 - WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, CZ },
        cypress,
        "WoodPlanks"
    )
    add(
        "UpperWallBack",
        { W, UPPER_H, WALL_T },
        { CX, FLOOR + STOREY_H + UPPER_H / 2, Z1 - WALL_T / 2 },
        cypress,
        "WoodPlanks"
    )

    -- ----- the eave over the shopfront: aerial, a full storey up -----
    local eaveD = (Z0 - (Z0 - EAVE_OVERHANG))
    add(
        "Eave",
        { W + 1.0, EAVE_T, eaveD },
        { CX, FLOOR + STOREY_H + EAVE_T / 2, Z0 - EAVE_OVERHANG / 2 },
        tile,
        "Slate"
    )

    -- ----- the roof: a gabled kirizuma, ridge running east-west along the street -----
    -- Machiya are hirairi — you enter on the long side, under the eave, with the gables at the
    -- ends. Two slopes, symmetric about a ridge centred on the ROOF span (which reaches further
    -- north than the walls because of the overhang).
    local frontRun = ROOF_RIDGE_Z - (Z0 - EAVE_OVERHANG)
    local backRun = Z1 - ROOF_RIDGE_Z
    local frontLen = math.sqrt(frontRun * frontRun + ROOF_RISE * ROOF_RISE)
    local backLen = math.sqrt(backRun * backRun + ROOF_RISE * ROOF_RISE)
    local frontDeg = math.deg(math.atan2(ROOF_RISE, frontRun))
    local backDeg = math.deg(math.atan2(ROOF_RISE, backRun))
    local ROOF_T = 0.5

    add(
        "RoofNorth",
        { W + 1.0, ROOF_T, frontLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (Z0 - EAVE_OVERHANG + ROOF_RIDGE_Z) / 2 },
        tile,
        "Slate",
        rotX(frontDeg)
    )
    add(
        "RoofSouth",
        { W + 1.0, ROOF_T, backLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1) / 2 },
        tile,
        "Slate",
        rotX(-backDeg)
    )
    add("Ridge", { W + 1.2, 0.4, 0.6 }, { CX, TOP - 0.2, ROOF_RIDGE_Z }, ink, "Slate")

    -- Gable ends. Each is TWO right triangles back to back, which is what an isosceles gable is;
    -- a WedgePart's native slope descends toward +Z with its vertical face at -Z, so the north
    -- half is that wedge turned 180° about Y and the south half is it unturned.
    local GABLE_T = 0.4
    for _, end_ in { { "West", X0 + GABLE_T / 2 }, { "East", X1 - GABLE_T / 2 } } do
        local name, x = end_[1] :: string, end_[2] :: number
        table.insert(
            children,
            Spec.part(`Gable{name}North`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, frontRun },
                CFrame = Spec.cframe(
                    { x, EAVE_Y + ROOF_RISE / 2, (Z0 - EAVE_OVERHANG + ROOF_RIDGE_Z) / 2 },
                    { -1, 0, 0, 0, 1, 0, 0, 0, -1 }
                ),
                Color = cypress,
                Material = "WoodPlanks",
                CanCollide = true,
                CastShadow = false,
            })
        )
        table.insert(
            children,
            Spec.part(`Gable{name}South`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, backRun },
                CFrame = Spec.cframe({ x, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1) / 2 }),
                Color = cypress,
                Material = "WoodPlanks",
                CanCollide = true,
                CastShadow = false,
            })
        )
    end

    -- ----- noren: the split curtain under the eave, the sign that a shop is OPEN -----
    -- Four panels with gaps, hung from the eave line. Non-collidable: you walk through a noren.
    local NOREN_N = 4
    local norenSpan = W * 0.8
    local norenW = norenSpan / NOREN_N - 0.25
    for i = 1, NOREN_N do
        local t = (i - 0.5) / NOREN_N
        table.insert(
            children,
            Spec.part(`Noren{i}`, {
                Size = { norenW, 2.2, 0.08 },
                CFrame = Spec.cframe({
                    CX - norenSpan / 2 + norenSpan * t,
                    FLOOR + STOREY_H - 1.1,
                    Z0 - EAVE_OVERHANG + 0.4,
                }),
                Color = palette.vermilion,
                Material = "Fabric",
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
            })
        )
    end

    -- ----- the counter -----
    add(
        "Counter",
        { W - 2 * WALL_T - 1.0, COUNTER_H, COUNTER_D },
        { CX, FLOOR + COUNTER_H / 2, Z0 + 2.6 },
        timber,
        "WoodPlanks"
    )

    -- ----- the kanban: the sign board, under the upper floor, facing the promenade -----
    -- Blank here; Task 5 puts the lettering on it. TextSize caps at 100px and TextScaled is
    -- inert, so the sign reads big only via a LOW SurfaceGui.PixelsPerStud — a small canvas.
    add(
        "Kanban",
        { W * 0.55, 2.6, 0.25 },
        { CX, FLOOR + STOREY_H - 1.6, Z0 - 0.2 },
        ink,
        "WoodPlanks"
    )

    -- ----- the trigger volume -----
    -- Inset one stud from the frontage. See ShopThreshold.FRONT_INSET for why: flush with the
    -- frontage it would fire on everyone crossing the square.
    local tz0 = Z0 + 1
    table.insert(
        children,
        Spec.part("Threshold", {
            Size = { W, 4.9, Z1 - tz0 },
            CFrame = Spec.cframe({ CX, FLOOR + 4.9 / 2, (tz0 + Z1) / 2 }),
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )

    return Spec.model("Hanabiya", children)
end

return Machiya
```

**Note on `Spec.part` and `className`:** `Spec.part` hardcodes `className = "Part"` and copies every other key into `properties`. The two gable wedges above pass `className` inside the props table, which would land in `properties` rather than on the node. Fix this in `Spec.luau` by having `Spec.part` honour an explicit `className`:

```lua
function Spec.part(name: string, props: { [string]: any }): PartSpec
    local kids = props.children
    local properties: { [string]: any } = { Anchored = true }
    for k, v in props do
        if k ~= "children" and k ~= "className" then
            properties[k] = v
        end
    end
    return { name = name, className = props.className or "Part", properties = properties, children = kids }
end
```

- [ ] **Step 4: Register the output**

In `roblox/tools/genmodels.luau`, add the require beside the others:

```lua
local Machiya = require("./builders/Machiya")
```

and the output entry inside `OUTPUTS`:

```lua
    ["Hanabiya"] = Machiya.build(ZenDojo.palette, ArenaLayout),
```

- [ ] **Step 5: Declare it to Rojo**

In `roblox/default.project.json`, add beside the other hero props under `RoshamboStage`:

```json
                "Hanabiya": { "$path": "assets/Hanabiya.model.json" },
```

- [ ] **Step 6: Generate, test and lint**

Run from `roblox/`:

```bash
lune run tools/genmodels && lune run tests/run && stylua --check src tests tools && selene src tools
```

Expected: `assets/Hanabiya.model.json` is written, all tests pass, lint clean.

- [ ] **Step 7: Verify the envelope test bites**

Temporarily change `local TOP = 127.36` to `137.0` in the builder, regenerate, and re-run the tests.

Expected: "NOTHING RISES ABOVE THE OWNER'S TOP" FAILS. **Restore 127.36 and regenerate before continuing.** A test that cannot fail is not protecting the shōrō.

- [ ] **Step 8: Commit**

```bash
git add roblox/tools/builders/Machiya.luau roblox/tools/builders/Spec.luau \
        roblox/tests/Machiya.spec.luau roblox/tools/genmodels.luau \
        roblox/default.project.json roblox/assets/Hanabiya.model.json
git commit -m "feat(roblox): 花火屋 — the merchant row's first machiya, built to the owner's envelope"
```

---

### Task 5: The kanban

The sign. **Not** through the glyph pipeline — see below.

**Files:**
- Modify: `roblox/tools/builders/Machiya.luau` (the `Kanban` part gains a SurfaceGui child)
- Modify: `roblox/assets/Hanabiya.model.json` (regenerated)

**Interfaces:**
- Consumes: `Machiya`'s `Kanban` part from Task 4.
- Produces: nothing downstream.

**WHY NOT THE GLYPH PIPELINE, despite what the spec says.** `tools/glyphs/glyphgen.cjs` is a
*dependency-free stroked-path rasterizer*: it draws R, P and S as three geometric strokes over a
signed distance field, and it has no font support of any kind. 花火屋 is three kanji of seven to
nine strokes each. Hand-authoring them as stroke coordinates would be a day of miserable work, and
it would then need an asset upload with a moderation wait — the same pipeline that once had a green
maple leaf removed as a false positive.

A Roblox `SurfaceGui` renders CJK from the built-in fonts for free. The documented catch is that
**`TextSize` caps at 100px and `TextScaled` is inert**, so large lettering needs a *small canvas* —
which is exactly what `SurfaceGui.PixelsPerStud` controls. Set it low and 90px text fills a
2.6-stud board.

If the built-in font turns out not to cover these three characters, the fallback is an uploaded
PNG — but check before spending anything on it.

- [ ] **Step 1: Replace the Kanban part with a signed one**

In `roblox/tools/builders/Machiya.luau`, replace the `add("Kanban", ...)` call with:

```lua
    -- The sign board. A SurfaceGui, not a Decal: Roblox renders CJK from the built-in fonts, and
    -- the glyph pipeline next door is a stroked-path rasterizer with no font support — it draws
    -- R/P/S as line segments and could not produce a kanji without hand-authored stroke geometry.
    --
    -- PixelsPerStud is LOW on purpose. TextSize caps at 100 and TextScaled is inert, so the only
    -- way to get large lettering is a small canvas — 20 px/stud over a 2.6-stud board means 90px
    -- text fills it.
    table.insert(
        children,
        Spec.part("Kanban", {
            Size = { W * 0.55, 2.6, 0.25 },
            CFrame = Spec.cframe({ CX, FLOOR + STOREY_H - 1.6, Z0 - 0.2 }),
            Color = ink,
            Material = "WoodPlanks",
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
            children = {
                {
                    name = "Face",
                    className = "SurfaceGui",
                    properties = {
                        -- Front is -Z, which is north: onto the promenade.
                        Face = "Front",
                        PixelsPerStud = 20,
                        ZIndexBehavior = "Sibling",
                        AlwaysOnTop = false,
                    },
                    children = {
                        {
                            name = "Text",
                            className = "TextLabel",
                            properties = {
                                Size = { 1, 0, 1, 0 },
                                BackgroundTransparency = 1,
                                Text = "花火屋",
                                TextColor3 = palette.ivory,
                                TextSize = 90,
                                Font = "GothamBold",
                            },
                        },
                    },
                },
            },
        })
    )
```

`Size = { 1, 0, 1, 0 }` is a UDim2 in Rojo's scale/offset order — full width, full height of the
canvas.

- [ ] **Step 2: Add the test**

Add to `roblox/tests/Machiya.spec.luau`, inside the "the parts other tasks bind to" describe:

```lua
    test("the Kanban carries the shop's name", function()
        local k = find(model, "Kanban")
        local face = find(k, "Face")
        expect(face ~= nil).toBe(true)
        local text = find(face, "Text")
        expect(text ~= nil).toBe(true)
        expect(text.properties.Text).toBe("花火屋")
        -- TextSize caps at 100 and TextScaled is inert: a LOW PixelsPerStud is the only lever
        -- that makes the lettering read from the bridge.
        expect(face.properties.PixelsPerStud <= 25).toBe(true)
    end)
```

- [ ] **Step 3: Regenerate, test, lint**

Run from `roblox/`:

```bash
lune run tools/genmodels && lune run tests/run && stylua --check src tests tools && selene src tools
```

Expected: PASS, clean, zero warnings.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/builders/Machiya.luau roblox/tests/Machiya.spec.luau roblox/assets/Hanabiya.model.json
git commit -m "feat(roblox): the 花火屋 kanban, on a small canvas so it reads big"
```

---

### Task 6: The shop panel

The counter. A new client controller that opens on entering the shop and renders what the server sent.

**Files:**
- Create: `roblox/src/client/ShopController.client.luau`
- Modify: `roblox/src/client/EventBus.luau`
- Modify: `roblox/src/server/main.server.luau` (tag the Threshold at startup)

**Interfaces:**
- Consumes: `ShopThreshold.isInside` (Task 3); the `Hanabiya` model's `Threshold` child (Task 4); `EconomyState` (`catalog.fireworks`, `catalog.mortars`, `totalPoints`, from Task 1); `FireworkState` (`shells`, `mortars`).
- Produces: `EventBus.ShopPurchase:Fire(item: string)` → `RequestPurchase:FireServer({ item = item })`.

- [ ] **Step 1: Add the EventBus signal**

In `roblox/src/client/EventBus.luau`, add to `NAMES` beside `HudFireworkLaunch`:

```lua
    -- The shop counter asking to buy. Carries an item string ("firework:peony", "mortar:S") and
    -- nothing else: affordability and tier order are the server's answer, never this client's.
    "ShopPurchase",
```

- [ ] **Step 2: Tag the threshold server-side**

In `roblox/src/server/main.server.luau`, after the other startup wiring, add:

```lua
-- The shop's trigger volume ships inside the Rojo model, so it is here at startup rather than
-- created at runtime. Tagging it server-side means the client can find it by tag (which
-- replicates) instead of by a path that would break the moment a second shop is built.
do
    local hanabiya = stage:FindFirstChild("Hanabiya")
    local threshold = hanabiya and hanabiya:FindFirstChild("Threshold")
    if threshold then
        threshold:SetAttribute("shopId", "hanabiya")
        CollectionService:AddTag(threshold, "ShopThreshold")
    end
end
```

`stage` is this file's existing `Workspace.RoshamboStage` handle — use whatever local it already binds; do not add a second one.

- [ ] **Step 3: Write the controller**

Create `roblox/src/client/ShopController.client.luau`:

```lua
--!strict
-- THE SHOP COUNTER. Opens when you step inside 花火屋, closes when you leave, and renders exactly
-- what the server sent — prices from EconomyState.catalog, counts from FireworkState.
--
-- IT EVALUATES NOTHING. Not affordability, not mortar tier order, not what a shell requires. Every
-- one of those is a server fact, and this codebase has a named, recurring defect where a number
-- authoritative on the server is re-derived client-side and goes stale. The one rule that lives
-- here is geometric — am I inside the box — and even that is in a tested module.
--
-- NOTHING HERE IS TESTED. No harness in this repo loads a `.client.luau`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local ShopThreshold = require(shared:WaitForChild("ShopThreshold"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local FireworkState = remotes:WaitForChild("FireworkState") :: RemoteEvent
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent

local SHELL_ORDER = { "firecracker", "peony", "willow", "ishibana" }
local SHELL_NAME: { [string]: string } = {
    firecracker = "Firecracker",
    peony = "Peony",
    willow = "Willow",
    ishibana = "Ishibana",
}
local MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }
local MORTAR_NAME: { [string]: string } = {
    ["mortar:S"] = "Small mortar",
    ["mortar:M"] = "Medium mortar",
    ["mortar:L"] = "Large mortar",
}

local INK = Color3.fromRGB(60, 45, 28)
local INK_CREAM = Color3.fromRGB(240, 234, 216)
local WASHI = Color3.fromRGB(26, 24, 28)
local GOLD = Color3.fromRGB(212, 176, 102)
local DIM = Color3.fromRGB(206, 199, 182)

-- ===== state, all of it the server's =====
local prices: { [string]: number } = {}
local mortarPrices: { [string]: number } = {}
local points = 0
local shells: any = nil
local ownedMortars: { [string]: boolean } = {}

-- ===== the panel =====
local gui = Instance.new("ScreenGui")
gui.Name = "ShopPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
-- ZIndexBehavior defaults to Global, under which a child does NOT draw above its parent.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(340, 420)
panel.BackgroundColor3 = WASHI
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 34)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.TextColor3 = INK_CREAM
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "花火屋"
title.Parent = panel

local balance = Instance.new("TextLabel")
balance.Size = UDim2.new(1, -20, 0, 18)
balance.Position = UDim2.fromOffset(10, 40)
balance.BackgroundTransparency = 1
balance.TextColor3 = DIM
balance.Font = Enum.Font.Code
balance.TextSize = 13
balance.TextXAlignment = Enum.TextXAlignment.Left
balance.Parent = panel

local list = Instance.new("Frame")
list.Size = UDim2.new(1, -20, 1, -70)
list.Position = UDim2.fromOffset(10, 64)
list.BackgroundTransparency = 1
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = list

type Row = { button: TextButton, title: TextLabel, sub: TextLabel, item: string }
local rows: { Row } = {}

local function makeRow(order: number, item: string, label: string): Row
    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = WASHI
    b.BackgroundTransparency = 0.3
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Parent = list
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -12, 0, 18)
    t.Position = UDim2.fromOffset(8, 3)
    t.BackgroundTransparency = 1
    t.TextColor3 = INK_CREAM
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = label
    t.Parent = b

    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -12, 0, 14)
    s.Position = UDim2.fromOffset(8, 21)
    s.BackgroundTransparency = 1
    s.TextColor3 = DIM
    s.Font = Enum.Font.Code
    s.TextSize = 11
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = b

    local row: Row = { button = b, title = t, sub = s, item = item }
    b.MouseButton1Click:Connect(function()
        EventBus.ShopPurchase:Fire(item)
    end)
    return row
end

do
    local order = 0
    for _, id in SHELL_ORDER do
        order += 1
        table.insert(rows, makeRow(order, "firework:" .. id, SHELL_NAME[id]))
    end
    for _, id in MORTAR_ORDER do
        order += 1
        table.insert(rows, makeRow(order, id, MORTAR_NAME[id]))
    end
end

local function paint()
    balance.Text = ("%d points"):format(points)
    for _, row in rows do
        local isShell = row.item:sub(1, 9) == "firework:"
        local key = if isShell then row.item:sub(10) else row.item
        local price = if isShell then prices[key] else mortarPrices[key]
        local afford = price ~= nil and points >= price
        local detail
        if price == nil then
            -- The catalog has not arrived yet. Say so rather than showing a confident zero.
            detail = "..."
        elseif isShell then
            local held = shells and shells[key] and shells[key].count or 0
            detail = ("%d pts   you hold %d"):format(price, held)
        elseif ownedMortars[key] then
            detail = "owned"
        else
            detail = ("%d pts"):format(price)
        end
        row.sub.Text = detail
        local live = price ~= nil and afford and not (not isShell and ownedMortars[key])
        row.button.BackgroundTransparency = if live then 0.3 else 0.65
        row.title.TextTransparency = if live then 0 else 0.4
    end
end

EconomyState.OnClientEvent:Connect(function(state)
    if typeof(state) ~= "table" then
        return
    end
    points = state.totalPoints or points
    local cat = state.catalog
    if typeof(cat) == "table" then
        prices = cat.fireworks or prices
        mortarPrices = cat.mortars or mortarPrices
    end
    paint()
end)

FireworkState.OnClientEvent:Connect(function(state)
    if typeof(state) ~= "table" then
        return
    end
    shells = state.shells
    ownedMortars = {}
    for _, id in state.mortars or {} do
        ownedMortars[id] = true
    end
    paint()
end)

EventBus.ShopPurchase.Event:Connect(function(item: string)
    RequestPurchase:FireServer({ item = item })
end)

-- ===== the threshold =====
-- Found by TAG, not by path: tags replicate, and a path would break the moment a second shop is
-- built. The added-signal handles the replication race — the model may arrive after this script.
local boxes: { { part: BasePart, box: any } } = {}

local function register(part: Instance)
    if not part:IsA("BasePart") then
        return
    end
    local p, s = part.Position, part.Size
    table.insert(boxes, {
        part = part,
        box = {
            x0 = p.X - s.X / 2,
            x1 = p.X + s.X / 2,
            y0 = p.Y - s.Y / 2,
            y1 = p.Y + s.Y / 2,
            z0 = p.Z - s.Z / 2,
            z1 = p.Z + s.Z / 2,
        },
    })
end

for _, part in CollectionService:GetTagged("ShopThreshold") do
    register(part)
end
CollectionService:GetInstanceAddedSignal("ShopThreshold"):Connect(register)

local inside = false
RunService.Heartbeat:Connect(function()
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local now = false
    if root then
        local p = root.Position
        local pos = { x = p.X, y = p.Y, z = p.Z }
        for _, entry in boxes do
            if ShopThreshold.isInside(pos, entry.box) then
                now = true
                break
            end
        end
    end
    if now ~= inside then
        inside = now
        gui.Enabled = now
        if now then
            paint()
        end
    end
end)
```

- [ ] **Step 4: Run every gate**

Run from `roblox/`:

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
```

Expected: PASS, clean, zero warnings. **This proves the other tasks still pass. It does not prove a panel opens.**

- [ ] **Step 5: Verify no price or requirement logic leaked into the client**

Run from `roblox/`:

```bash
grep -rnE "= *(1|3|4|6|40|250|1000) *$|NEEDS_MORTAR|lastWorldThrow" src/client/ShopController.client.luau
```

Expected: **no output.** A literal price or a requirement comparison in this file means a server fact has been copied, which is the defect this plan's global constraints exist to prevent.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/client/ShopController.client.luau roblox/src/client/EventBus.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): the 花火屋 counter — walk in, and the shop is open"
```

---

### Task 7: Cut the hill and walk the gate

The one place-only step, and the verification the tests cannot do.

**Files:**
- Create: `roblox/tools/studio/cutHanabiyaSite.luau`

**Interfaces:**
- Consumes: the owner's envelope (Task 4's constants).
- Produces: nothing in code — a terrain excavation in the saved place.

- [ ] **Step 1: Write the rough-carve script**

Create `roblox/tools/studio/cutHanabiyaSite.luau`:

```lua
-- cutHanabiyaSite.luau — rough-carve the cut behind 花火屋 (2026-08-05)
--
-- HOW TO RUN: paste into the Studio command bar in EDIT mode, then SAVE AND PUBLISH. Terrain is
-- place-only and in no repository.
--
-- THIS IS A ROUGH CARVE, NOT A FINISH. The owner finish-smooths — that is the standing handoff
-- for every path and terrace in this canyon, and a script that tried to do both would produce a
-- clean-edged trench nobody wants.
--
-- The hill here is not a slope: a saddle at x-8..7 and a ridge at x10..22, so the cut behind the
-- building runs about 6.8 studs deep at its west end and 12.5 at its east. That wedge is expected.
local Terrain = workspace.Terrain

local X0, X1 = -1.67, 16.26
local Z0, Z1 = 44.00, 52.00
local FLOOR = 113.10

-- Standing rule: walls register to the BUILT edge with a 1.5-2 stud standoff, never to the
-- excavation line. So carve WIDER than the building and backfill rough behind it.
local STANDOFF = 2.0
local HEAD = 14.0 -- clear to above the eave line

local region = Region3.new(
    Vector3.new(X0 - STANDOFF, FLOOR - 1, Z0 - 1),
    Vector3.new(X1 + STANDOFF, FLOOR + HEAD, Z1 + STANDOFF)
):ExpandToGrid(4)

Terrain:FillRegion(region, 4, Enum.Material.Air)

print(
    ("[Hanabiya] rough-carved x%.1f..%.1f z%.1f..%.1f up to y%.1f. NOW FINISH-SMOOTH, then SAVE AND PUBLISH.")
        :format(X0 - STANDOFF, X1 + STANDOFF, Z0 - 1, Z1 + STANDOFF, FLOOR + HEAD)
)
```

- [ ] **Step 2: Lint and commit the tool**

```bash
cd roblox && stylua tools && stylua --check src tests tools && selene src tools && cd ..
git add roblox/tools/studio/cutHanabiyaSite.luau
git commit -m "tools(roblox): rough-carve the 花火屋 site"
```

- [ ] **Step 3: Run it in Studio, then hand back**

Paste the script into the command bar in Edit mode. Then **stop and ask the owner to finish-smooth** before anything else is judged — an unsmoothed carve reads as a bug and will contaminate every other verdict below.

- [ ] **Step 4: Dress the cut and hang the lanterns**

Both use tools that already exist and are locked. **Do not reimplement either** — the recipes doc
records what failed the first time round for both.

**Ishigaki on the exposed cut** (recipe §3). Run `tools/studio/buildIshigakiWalls.luau` against the
new cut faces. Note from the spec: with the building butted into its own cut, most of the retaining
face is hidden *behind* it — what is actually visible is where the cut runs past the shop's ends, so
that is what has to read well. The wall is a varying height (≈6.8 studs at the west end, ≈12.5 at
the east); §3's `w = vs / Hs` rule maps the stone field to local wall height precisely so a
varying-height wall fills base-to-top rather than leaving a mid-span dip.

**Two chōchin under the eave** (recipe §4). Run `tools/studio/buildChochinPole.luau`, or place two
of its lanterns directly, hung from the eave line at roughly `x = 1.5` and `x = 13`, `z ≈ 42`. Tag
each glyph plate **`RoundLantern`** — discovery is by CollectionService tag, not by name or parent,
and not by living under `RoshamboStage`. They will then carry the round result like every other
lantern in the canyon, which ties the shop to the game for free.

Both are place-only. **Save the place.**

- [ ] **Step 5: Walk the gate**

With the place saved and published, check each of these. **Stop at the first failure and report it rather than fixing and continuing** — one visual attempt, then ask.

1. The building reads as a **shop, not a teahouse**, from the promenade. The open frontage is the thing carrying that.
2. It reads as **subordinate to the shōrō** from the square. If it competes, the roof is too tall.
3. The **kanban is legible from the suspension bridge** — the reason the upper storey exists at all.
4. **Walking the promenade does NOT open the panel.** Walking in does. Walking out closes it.
5. **Buy a firecracker for 1 point** — the balance drops and the count rises *immediately*, without waiting for a reveal. That is Task 2.
6. **Buy `mortar:S`, then a peony**, walk to a launch site, and the peony flies. That is the whole loop the project exists to close.
7. **`mortar:M` before `mortar:S`** is refused.
8. The **ishigaki** reads as supporting the hill rather than as a trench — judged at the shop's
   ENDS, where the cut is actually visible past the building.
9. The **chōchin light the shopfront** and paint the round result like every other lantern.
10. **Save and publish.** The terrain, the ishigaki meshes and the lanterns are all place-only and
    in no repository.

- [ ] **Step 6: Record the as-built**

Append to `docs/superpowers/specs/2026-08-05-hanabiya-shop-design.md` an "As built" section: any dimension the owner adjusted at the gate, the ishigaki span ids, the chōchin placements, and the final terrain state. Recipe §0 step 6 — a stretch is not done until its as-built is written down.

```bash
git add docs/superpowers/specs/2026-08-05-hanabiya-shop-design.md
git commit -m "docs: 花火屋 as-built"
```
