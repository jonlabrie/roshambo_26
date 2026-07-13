--!strict
-- Orchestration test for PadBuilder.buildDeck: verifies it wires slab -> 5 beams ->
-- 3 railings (front/left/right; the back edge is left open) -> planned posts in the right
-- shape, with faked geometry ops (the parts themselves are visual-gated in Studio; this
-- locks the CALL GRAPH only).
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local PadBuilder = require("../src/shared/PadBuilder")

-- datum at y=100; flat ground 5 studs below -> all 6 posts plan (within MAXPOST, below datum)
local FLAT_MOUNT = { 0, 100, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function fakeOps()
    local calls = { slab = 0, beams = {}, rails = {}, posts = 0 }
    local ops = {
        raycastGround = function(_x: number, _z: number): number?
            return 95
        end,
        buildPost = function(_pos: { number }, _height: number)
            calls.posts += 1
        end,
        buildDeckSlab = function(_fp)
            calls.slab += 1
        end,
        buildBeam = function(fromNode, toNode)
            table.insert(calls.beams, fromNode.id .. "-" .. toNode.id)
        end,
        buildRailing = function(edge)
            table.insert(calls.rails, edge)
        end,
    }
    return calls, ops
end

describe("PadBuilder.buildDeck", function()
    test(
        "S: slab once, 5 beams (2 long + 3 short), 3 railings (back open), 6 posts on flat ground",
        function()
            local calls, ops = fakeOps()
            PadBuilder.buildDeck("S", FLAT_MOUNT, ops)
            expect(calls.slab).toBe(1)
            expect(#calls.beams).toBe(5)
            expect(#calls.rails).toBe(3)
            expect(calls.posts).toBe(6)
            local set = {}
            for _, b in calls.beams do
                set[b] = true
            end
            expect(set["FL-FR"]).toBe(true) -- long front
            expect(set["BL-BR"]).toBe(true) -- long back BEAM stays (only the back RAIL is dropped)
            expect(set["MF-MB"]).toBe(true) -- short middle
        end
    )

    test("railings cover front/left/right only — the back edge is left open", function()
        local calls, ops = fakeOps()
        PadBuilder.buildDeck("S", FLAT_MOUNT, ops)
        local normals = {}
        for _, e in calls.rails do
            table.insert(normals, e.nx .. "," .. e.nz)
        end
        table.sort(normals)
        expect(#normals).toBe(3)
        expect(normals[1]).toBe("-1,0") -- right
        expect(normals[2]).toBe("0,1") -- front
        expect(normals[3]).toBe("1,0") -- left
        for _, n in normals do
            expect(n == "0,-1").toBe(false) -- back rail intentionally absent
        end
    end)

    test("L: identical wiring (footprint scales, call graph does not)", function()
        local calls, ops = fakeOps()
        local mount = PadBuilder.buildDeck("L", FLAT_MOUNT, ops)
        expect(calls.slab).toBe(1)
        expect(#calls.beams).toBe(5)
        expect(#calls.rails).toBe(3)
        expect(calls.posts).toBe(6)
        expect(mount.footprint.maxX).toBeCloseTo(13 * math.sqrt(1.6)) -- L deck footprint returned
    end)
end)
