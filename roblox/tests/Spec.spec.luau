--!strict
local harness = require("./harness")
local Spec = require("../tools/builders/Spec")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Spec.part", function()
    test("does not mutate the caller's props table", function()
        local child: Spec.PartSpec = { name = "Child", className = "Part", properties = {}, children = nil }
        local props: { [string]: any } = { Size = { 1, 1, 1 }, children = { child } }
        local spec1 = Spec.part("A", props)
        local spec2 = Spec.part("A", props)
        -- Input table must still have its children key after both calls
        expect(props.children ~= nil).toBe(true)
        -- Both returned specs must carry the children list
        expect(spec1.children ~= nil).toBe(true)
        expect(spec2.children ~= nil).toBe(true)
    end)
end)

describe("Spec.segment", function()
    test("vertical segment: length and midpoint", function()
        local pos, len = Spec.segment({ 0, 0, 0 }, { 0, 10, 0 })
        expect(math.abs(len - 10) < 1e-6).toBe(true)
        expect(pos[1]).toBe(0)
        expect(pos[2]).toBe(5)
        expect(pos[3]).toBe(0)
    end)
    test("diagonal segment: length matches euclidean distance", function()
        local a, b = { 1, 2, 3 }, { 4, 6, 15 }
        local _, len = Spec.segment(a, b)
        local euclid = math.sqrt(3 * 3 + 4 * 4 + 12 * 12)
        expect(math.abs(len - euclid) < 1e-6).toBe(true)
    end)
end)
