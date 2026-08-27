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

