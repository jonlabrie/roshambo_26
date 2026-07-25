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
