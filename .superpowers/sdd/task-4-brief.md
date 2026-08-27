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

