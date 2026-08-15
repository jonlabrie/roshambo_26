--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MachiyaShops = require("../tools/builders/MachiyaShops")

describe("MachiyaShops registry", function()
    test("hanabiya carries the owner's envelope verbatim", function()
        local h = MachiyaShops.hanabiya
        expect(h.name).toBe("Hanabiya")
        expect(h.envelope.x0).toBe(-1.67)
        expect(h.envelope.x1).toBe(16.26)
        expect(h.envelope.z0).toBe(36.00)
        expect(h.envelope.z1).toBe(52.00)
        expect(h.envelope.floorY).toBe(113.10)
        expect(h.yaw).toBe(0)
        expect(h.frontage).toBe("open")
        expect(h.interior).toBe("full")
    end)
end)
