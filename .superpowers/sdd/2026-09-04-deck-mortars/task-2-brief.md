### Task 2: MortarPlacement — defaults, overrides, clamp, nudge, muzzle math

**Files:**
- Create: `roblox/src/shared/MortarPlacement.luau`
- Test: `roblox/tests/MortarPlacement.spec.luau`

**Interfaces:**
- Consumes: nothing (pure; deck bounds passed in).
- Produces (exact names later tasks rely on):
  - `MortarPlacement.MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }` (⚠ mirrors `MORTAR_IDS` in `server/src/fireworks.ts` — carry the TS<->Luau drift caveat comment)
  - `MortarPlacement.TUBE: { [string]: { bore: number, length: number } }` — S `{1/6, 0.85}`, M `{1/3, 1.5}`, L `{0.5, 2.5}` (the proving-range proportions, 1 stud = 1 ft)
  - `type Placement = { x: number, z: number, facing: string }`
  - `MortarPlacement.resolve(deckBounds: Bounds, owned: { string }, stored: { [string]: { offset: { number }, facing: string } }?, teahouseFP: Bounds?): { [string]: Placement }` where `Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }` (DecorationLayout's shape)
  - `MortarPlacement.muzzleWorld(deckRow: { number }, placement: Placement, mortarId: string): (number, number, number)` — world x,y,z of the tube's muzzle: the 12-number row-major deck CFrame (position + 3x3 rotation, `PadSites.deckPlacements` convention) transforming the deck-local `(x, baseTop + length, z)` point, where baseTop = 0.5 (the timber base height used by the render task).

Behavior pinned by the spec:
- **Front edge = local `maxZ`** (deck rows are view-oriented; the canyon-facing side is +Z in deck-local space — the same convention `DecorationLayout`/`BuildingPlacer` use for "front"). Defaults sit at `z = maxZ - 1` (1-stud inset), owned tiers in MORTAR_ORDER order spread evenly across the middle half of the X span (e.g. one mortar at center; two at ±25% of span; three at −25%/0/+25%).
- Stored placements override defaults per mortar; both stored and default are **clamped** into `[minX+0.5, maxX-0.5] × [minZ+0.5, maxZ-0.5]`.
- **Teahouse nudge**: a resolved spot strictly inside `teahouseFP` moves to `z = maxZ - 1` keeping its clamped x; if STILL inside the footprint, walk x outward in 1-stud steps (alternating +/−) until clear or the bounds clamp stops progress — always returning a position, never nil, never mutating `stored`.
- Unknown or unowned ids in `stored` are ignored; every OWNED mortar always gets a row in the result.

- [ ] **Step 1: Write the failing spec** — `roblox/tests/MortarPlacement.spec.luau` (harness idiom: `describe/test/expect(...).toBe`):

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MortarPlacement = require("../src/shared/MortarPlacement")

local BOUNDS = { minX = -8, maxX = 8, minZ = -6, maxZ = 6 }
local ALL = { "mortar:S", "mortar:M", "mortar:L" }

describe("MortarPlacement — default-first gear placement", function()
    test("every owned mortar gets a spot; defaults sit on the front edge, staggered", function()
        local out = MortarPlacement.resolve(BOUNDS, ALL, nil, nil)
        local xs = {}
        for _, id in MortarPlacement.MORTAR_ORDER do
            local p = out[id]
            expect(p ~= nil).toBe(true)
            assert(p)
            expect(p.z).toBe(BOUNDS.maxZ - 1)
            table.insert(xs, p.x)
        end
        expect(xs[1] < xs[2] and xs[2] < xs[3]).toBe(true) -- S left of M left of L
    end)

    test("a single owned mortar defaults to front-center", function()
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, nil, nil)
        expect(out["mortar:S"].x).toBe(0)
        expect(out["mortar:M"] == nil).toBe(true)
    end)

    test("stored placements override defaults and get clamped, never mutated", function()
        local stored = { ["mortar:S"] = { offset = { 40, -40 }, facing = "E" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, nil)
        expect(out["mortar:S"].x).toBe(BOUNDS.maxX - 0.5)
        expect(out["mortar:S"].z).toBe(BOUNDS.minZ + 0.5)
        expect(out["mortar:S"].facing).toBe("E")
        expect(stored["mortar:S"].offset[1]).toBe(40) -- untouched
    end)

    test("a spot inside the teahouse footprint NUDGES clear -- mortars never hide", function()
        local teahouse = { minX = -8, maxX = 8, minZ = 2, maxZ = 6 } -- swallows the front edge
        local stored = { ["mortar:S"] = { offset = { 0, 5 }, facing = "N" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, teahouse)
        local p = out["mortar:S"]
        local inside = p.x > teahouse.minX and p.x < teahouse.maxX and p.z > teahouse.minZ and p.z < teahouse.maxZ
        expect(inside).toBe(false)
    end)

    test("unowned/unknown stored ids are ignored", function()
        local stored = { ["mortar:L"] = { offset = { 0, 0 }, facing = "N" }, nonsense = { offset = { 0, 0 }, facing = "N" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, nil)
        expect(out["mortar:L"] == nil).toBe(true)
        expect(out["mortar:S"] ~= nil).toBe(true)
    end)

    test("muzzleWorld transforms deck-local to world through the 12-number row", function()
        -- identity rotation, deck origin at (100, 50, -20)
        local row = { 100, 50, -20, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local x, y, z = MortarPlacement.muzzleWorld(row, { x = 2, z = 3, facing = "N" }, "mortar:L")
        expect(x).toBe(102)
        expect(z).toBe(-17)
        expect(math.abs(y - (50 + 0.5 + 2.5)) < 1e-6).toBe(true) -- baseTop + L tube length
        -- 90-degree yaw: local x maps to world -z (row-major R applied as p' = R*p)
        local rot = { 100, 50, -20, 0, 0, 1, 0, 1, 0, -1, 0, 0 }
        local rx, _, rz = MortarPlacement.muzzleWorld(rot, { x = 2, z = 0, facing = "N" }, "mortar:S")
        expect(math.abs(rx - 100) < 1e-6).toBe(true)
        expect(math.abs(rz - (-22)) < 1e-6).toBe(true)
    end)
end)
```

- [ ] **Step 2: Verify failure** — `lune run tests/run`: module not found.
- [ ] **Step 3: Implement** per the Interfaces block (row-major transform: `world = pos + R * local`, with `R` rows `{r[4],r[5],r[6]; r[7],r[8],r[9]; r[10],r[11],r[12]}` — matching how `Spec.cframe` lays out model.json CFrames).
- [ ] **Step 4: Green** — `lune run tests/run`.
- [ ] **Step 5: Lint (FULL output) + commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/MortarPlacement.luau tests/MortarPlacement.spec.luau
git commit -m "feat(mortars): MortarPlacement -- front-edge defaults, overrides, clamp, teahouse nudge, muzzle math"
```

---

