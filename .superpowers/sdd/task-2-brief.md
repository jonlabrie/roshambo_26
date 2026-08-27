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

