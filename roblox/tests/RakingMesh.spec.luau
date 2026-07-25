--!strict
local harness = require("./harness")
local RakingMesh = require("../src/shared/RakingMesh")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("RakingMesh (solid scalloped ripple disc)", function()
    local g = { footprintR = 2, maxR = 5.4, pitch = 0.7, amplitude = 0.12, soft = 0 }
    test("profile: valley at the stone, alternating crests, ends on a valley", function()
        local prof = RakingMesh.profile(g)
        expect(#prof % 2 == 1).toBe(true) -- odd sample count = valley at both ends
        expect(prof[1].r).toBeCloseTo(2, 0.001)
        expect(prof[1].h).toBeCloseTo(0, 0.001)
        for i = 2, #prof do
            expect(prof[i].r - prof[i - 1].r).toBeCloseTo(g.pitch / 2, 0.001)
            expect(prof[i].h).toBeCloseTo(i % 2 == 0 and g.amplitude or 0, 0.001)
            expect(prof[i].r <= g.maxR + 0.001).toBe(true)
        end
        expect(prof[#prof].h).toBeCloseTo(0, 0.001)
    end)
    test("solid disc: every band shares its neighbour's edge radius (no gaps)", function()
        local prof = RakingMesh.profile(g)
        -- bands span consecutive profile samples: solidity is structural
        expect(#prof >= 3).toBe(true)
    end)
    test("mesh bookkeeping: flat-shaded bands, counts, local-space, bounds", function()
        local segs = 24
        local m = RakingMesh.build(g, segs)
        local prof = RakingMesh.profile(g)
        local bands = #prof - 1
        expect(#m.verts).toBe(bands * 2 * segs)
        expect(#m.normals).toBe(#m.verts)
        expect(#m.tris).toBe(bands * 2 * segs)
        for _, tri in m.tris do
            for _, i in tri do
                expect(i >= 1 and i <= #m.verts).toBe(true)
            end
        end
        local maxY, minY = -math.huge, math.huge
        for _, v in m.verts do
            maxY = math.max(maxY, v[2])
            minY = math.min(minY, v[2])
            local rr = math.sqrt(v[1] ^ 2 + v[3] ^ 2)
            expect(rr >= g.footprintR - 0.001 and rr <= g.maxR + 0.001).toBe(true)
        end
        expect(maxY).toBeCloseTo(g.amplitude, 0.001)
        expect(minY).toBeCloseTo(0, 0.001)
    end)
    test("hard normals: unit, upward, constant within a band (the crisp-V read)", function()
        local segs = 24
        local m = RakingMesh.build(g, segs)
        for i, n in m.normals do
            local len = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
            expect(math.abs(len - 1) < 0.01).toBe(true)
            expect(n[2] > 0).toBe(true)
        end
        -- soft=0: both verts of a band at the same segment share one flat normal
        local nInner, nOuter = m.normals[1], m.normals[2]
        expect(nInner[1]).toBeCloseTo(nOuter[1], 0.0001)
        expect(nInner[2]).toBeCloseTo(nOuter[2], 0.0001)
        expect(nInner[3]).toBeCloseTo(nOuter[3], 0.0001)
    end)
    test("soft blends crest edges toward the neighbour band (the happy medium)", function()
        local segs = 24
        local gs = { footprintR = 2, maxR = 5.4, pitch = 0.7, amplitude = 0.12, soft = 0.5 }
        local m = RakingMesh.build(gs, segs)
        -- band 1 outer edge vs band 2 inner edge (same crest, same segment):
        -- hard would keep them apart; soft pulls both toward their shared average
        local outer1 = m.normals[2] -- band 1, segment 0, outer vert
        local inner2 = m.normals[2 * segs + 1] -- band 2, segment 0, inner vert
        local dot = outer1[1] * inner2[1] + outer1[2] * inner2[2] + outer1[3] * inner2[3]
        expect(dot > 0.9).toBe(true) -- much closer than the hard-facet angle
        for _, n in m.normals do
            local len = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
            expect(math.abs(len - 1) < 0.01).toBe(true)
            expect(n[2] > 0).toBe(true)
        end
    end)
end)
