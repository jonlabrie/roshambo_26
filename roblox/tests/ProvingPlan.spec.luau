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

describe("ProvingPlan — shipped-shell modes", function()
    test("shippedLadder fires the one shell from EVERY rack", function()
        local plan = ProvingPlan.shippedLadder("kamuro")
        expect(#plan).toBe(#ProvingPlan.RACKS)
        for i, entry in plan do
            expect(entry.id).toBe("kamuro")
            expect(entry.rack).toBe(ProvingPlan.RACKS[i])
        end
    end)

    test("shippedSequence repeats the shell with clean air between", function()
        local plan = ProvingPlan.shippedSequence("hotaru")
        expect(#plan).toBe(ProvingPlan.SHIPPED_SEQUENCE_COUNT)
        for i, entry in plan do
            expect(entry.id).toBe("hotaru")
            expect(entry.delaySeconds).toBe((i - 1) * ProvingPlan.SEQUENCE_GAP)
        end
    end)
end)
