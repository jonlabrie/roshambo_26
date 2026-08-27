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

