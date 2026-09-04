### Task 1: `AmbientBudget` — the policy module

**Files:**
- Create: `roblox/src/shared/AmbientBudget.luau`
- Test: `roblox/tests/AmbientBudget.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, and every later task depends on these exact names:
  - `AmbientBudget.Config` = `{ radius: number, behindDot: number, interval: number }`
  - `AmbientBudget.DEFAULT: Config`
  - `AmbientBudget.inRange(distSq: number, cfg: Config?): boolean`
  - `AmbientBudget.inView(forwardDot: number, cfg: Config?): boolean`
  - `AmbientBudget.step(acc: number, dt: number, interval: number): (boolean, number)`

Note the argument order and the optional trailing `cfg`, which matches `ImpostorFade`. `step` returns **two** values, `(fire, nextAcc)`, in that order.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/AmbientBudget.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local AmbientBudget = require("../src/shared/AmbientBudget")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("AmbientBudget.inRange", function()
    test("at the camera is in range", function()
        expect(AmbientBudget.inRange(0)).toBe(true)
    end)

    test("exactly at the radius is still in range", function()
        local r = AmbientBudget.DEFAULT.radius
        expect(AmbientBudget.inRange(r * r)).toBe(true)
    end)

    test("just beyond the radius is out", function()
        local r = AmbientBudget.DEFAULT.radius
        expect(AmbientBudget.inRange(r * r + 1)).toBe(false)
    end)

    test("a custom radius is respected", function()
        local cfg = { radius = 10, behindDot = -0.15, interval = 1 / 30 }
        expect(AmbientBudget.inRange(100, cfg)).toBe(true)
        expect(AmbientBudget.inRange(101, cfg)).toBe(false)
    end)
end)

describe("AmbientBudget.inView", function()
    test("dead ahead is in view", function()
        expect(AmbientBudget.inView(1)).toBe(true)
    end)

    test("directly behind is not", function()
        expect(AmbientBudget.inView(-1)).toBe(false)
    end)

    test("exactly at the margin is still in view", function()
        expect(AmbientBudget.inView(AmbientBudget.DEFAULT.behindDot)).toBe(true)
    end)

    test("the margin keeps a little slack behind square", function()
        -- a prop level with the camera plane must survive a fast turn
        expect(AmbientBudget.inView(0)).toBe(true)
        expect(AmbientBudget.DEFAULT.behindDot < 0).toBe(true)
    end)
end)

describe("AmbientBudget.step", function()
    test("does not fire before the interval elapses", function()
        local fire, acc = AmbientBudget.step(0, 0.01, 1 / 30)
        expect(fire).toBe(false)
        expect(math.abs(acc - 0.01) < 1e-9).toBe(true)
    end)

    test("fires once the interval is reached", function()
        local fire = AmbientBudget.step(0.02, 0.02, 1 / 30)
        expect(fire).toBe(true)
    end)

    test("carries the remainder rather than zeroing", function()
        -- 0.05s against a 0.03s interval leaves 0.02s owed to the next tick;
        -- zeroing here is what silently drags a nominal 30Hz down to the frame rate
        local _, acc = AmbientBudget.step(0, 0.05, 0.03)
        expect(math.abs(acc - 0.02) < 1e-9).toBe(true)
    end)

    test("a long stall does not bank unbounded catch-up", function()
        local fire, acc = AmbientBudget.step(0, 5, 1 / 30)
        expect(fire).toBe(true)
        expect(acc < 1 / 30).toBe(true)
    end)

    test("a zero interval fires every call without dividing by zero", function()
        local fire, acc = AmbientBudget.step(0, 0.001, 0)
        expect(fire).toBe(true)
        expect(acc).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
cd roblox && lune run tests/run
```

Expected: failure resolving `../src/shared/AmbientBudget` — the module does not exist yet.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/AmbientBudget.luau`:

```lua
--!strict
-- The "do not animate what the player cannot see" policy, in ONE place. Pure: no Roblox globals and
-- no instances, so Lune tests it -- unlike the .client.luau files that call it, which no harness in
-- this repo can load at all (see NorenSway.client.luau's header).
--
-- The controllers keep the vector math and the CollectionService bookkeeping; this module owns the
-- thresholds and the decision. That split is the only reason the rule is testable, and it mirrors
-- ImpostorFade's relationship to FoliageImpostorController.
local AmbientBudget = {}

export type Config = {
    radius: number, -- studs; beyond this an ambient prop is not animated
    behindDot: number, -- normalized forward dot below which the prop is behind the camera
    interval: number, -- seconds between updates while the prop IS being animated
}

AmbientBudget.DEFAULT = {
    radius = 180,
    behindDot = -0.15,
    interval = 1 / 30,
} :: Config

-- ⚠ TAKES DISTANCE SQUARED, deliberately. The caller has the squared distance for free and the
-- square root is the expensive half; for a canyon of lanterns most candidates fail THIS test, so it
-- has to be the one that can run first and short-circuit before anything calls math.sqrt.
function AmbientBudget.inRange(distSq: number, cfg: Config?): boolean
    local c = cfg or AmbientBudget.DEFAULT
    return distSq <= c.radius * c.radius
end

-- `forwardDot` is dot(normalize(prop - camera), cameraLook): 1 dead ahead, -1 directly behind.
--
-- NOT A FRUSTUM TEST, and not trying to be. `behindDot` is a MARGIN: it culls only what is clearly
-- behind the player, leaving slack for a wide FOV and for a fast turn -- because the cost of being
-- wrong is a prop the player watches start moving as it swings into view.
function AmbientBudget.inView(forwardDot: number, cfg: Config?): boolean
    local c = cfg or AmbientBudget.DEFAULT
    return forwardDot >= c.behindDot
end

-- Fixed-interval accumulator. Returns whether this frame should do the work, and the accumulator to
-- carry into the next one. Pure rather than stateful so the throttle itself is testable.
--
-- ⚠ CARRIES THE REMAINDER instead of zeroing. Zeroing discards up to a frame of time on every tick,
-- which quietly drags a nominal 30Hz down toward whatever the frame rate happens to be. The modulo
-- also bounds catch-up after a stall: one update is owed, not fifty.
function AmbientBudget.step(acc: number, dt: number, interval: number): (boolean, number)
    local elapsed = acc + dt
    if elapsed < interval then
        return false, elapsed
    end
    if interval <= 0 then
        return true, 0
    end
    return true, elapsed % interval
end

return AmbientBudget
```

- [ ] **Step 4: Run the test and watch it pass**

```bash
cd roblox && lune run tests/run
```

Expected: PASS, with the pre-existing suites still green.

- [ ] **Step 5: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run
git add roblox/src/shared/AmbientBudget.luau roblox/tests/AmbientBudget.spec.luau
git commit -m "feat(client): AmbientBudget -- the policy for not animating what nobody can see"
```

---

