--!strict
local harness = require("./harness")
local CareModel = require("../tools/builders/CareModel")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("CareModel.reach", function()
    test("the garden-floor spec's anchor values hold", function()
        -- Square x=+40 → 28 (clamped); dock x=−345 → 11.6; west end x=−430 → 8
        expect(CareModel.reach(40)).toBe(28)
        expect(math.abs(CareModel.reach(-345) - 11.6) < 0.05).toBe(true)
        expect(CareModel.reach(-430)).toBe(8)
        expect(CareModel.reach(-9999)).toBe(8)
    end)
end)

describe("CareModel.band", function()
    test("GARDEN is the inner 35% of reach", function()
        expect(CareModel.band(40, 9.7)).toBe("GARDEN") -- 0.35*28 = 9.8
        expect(CareModel.band(40, 9.9)).toBe("TENDED")
        expect(CareModel.band(40, 28.0)).toBe("TENDED")
        expect(CareModel.band(40, 28.1)).toBe("PRESERVE")
    end)
end)
