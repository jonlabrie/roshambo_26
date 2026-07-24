--!strict
local harness = require("./harness")
local CamMesh = require("../src/shared/CamMesh")
local CamProfile = require("../src/shared/CamProfile")
local describe, test, expect = harness.describe, harness.test, harness.expect

local G = { gapZ = 2.2, draw = 3.0, rise = 0.45, dowelR = 0.25, dropDeg = 12 }

describe("CamMesh (smooth snail extrusion)", function()
    local mesh = CamMesh.build(G, 64, 0.7)
    test("vertex/normal/triangle bookkeeping is consistent", function()
        expect(#mesh.verts).toBe(#mesh.normals)
        -- 2 centres + top/bottom rings of (9 base-arc + 64 locus) samples + cliff foot
        expect(#mesh.verts).toBe(2 + 2 * 74)
        expect(#mesh.tris).toBe(4 * 74) -- fan top + fan bottom + 2 wall tris per segment
        for _, t in mesh.tris do
            for _, i in t do
                expect(i >= 1 and i <= #mesh.verts).toBe(true)
            end
        end
    end)
    test("all verts are local-space, centred on the axle, within the lobe", function()
        local lobe = select(1, CamProfile.contact(1, G))
        for _, v in mesh.verts do
            expect(math.abs(v[1]) <= 0.7 + 0.001).toBe(true) -- axial extent = halfWidth
            expect(math.sqrt(v[2] ^ 2 + v[3] ^ 2) <= lobe + 0.001).toBe(true)
        end
    end)
    test("the rim reaches the lobe radius (the mesh really is the hero flank)", function()
        local lobe = select(1, CamProfile.contact(1, G))
        local maxR = 0
        for _, v in mesh.verts do
            maxR = math.max(maxR, math.sqrt(v[2] ^ 2 + v[3] ^ 2))
        end
        expect(math.abs(maxR - lobe) <= 0.01).toBe(true)
    end)
end)
