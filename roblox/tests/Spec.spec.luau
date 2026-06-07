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
