--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ProvingPlan = require("../src/shared/ProvingPlan")

describe("ProvingPlan — variants onto racks and clocks", function()
    test("ladder maps variants to racks A.. in order", function()
        local plan = ProvingPlan.ladder("kiku", { "v1", "v2", "v3" })
        expect(#plan).toBe(3)
        expect(plan[1].id).toBe("draft:kiku/v1")
        expect(plan[1].rack).toBe("Rack_A")
        expect(plan[3].rack).toBe("Rack_C")
    end)

    test("ladder caps at the five racks", function()
        local plan = ProvingPlan.ladder("x", { "a", "b", "c", "d", "e", "f", "g" })
        expect(#plan).toBe(5)
        expect(plan[5].rack).toBe("Rack_E")
    end)

    test("sequence fires everything from Rack_C's clock, SEQUENCE_GAP apart", function()
        local plan = ProvingPlan.sequence("kiku", { "v1", "v2", "v3" })
        expect(#plan).toBe(3)
        expect(plan[1].delaySeconds).toBe(0)
        expect(plan[2].delaySeconds).toBe(ProvingPlan.SEQUENCE_GAP)
        expect(plan[3].delaySeconds).toBe(2 * ProvingPlan.SEQUENCE_GAP)
        expect(plan[2].id).toBe("draft:kiku/v2")
    end)

    test("empty variants make empty plans", function()
        expect(#ProvingPlan.ladder("kiku", {})).toBe(0)
        expect(#ProvingPlan.sequence("kiku", {})).toBe(0)
    end)
end)
