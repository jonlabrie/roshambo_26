--!strict
local harness = require("./harness")
local DragonKings = require("../src/shared/DragonKings")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("DragonKings mapping", function()
    test("8 panels, each mapped to a known dragon with both asset maps", function()
        expect(#DragonKings.PANEL_DIRS).toBe(8)
        expect(#DragonKings.DRAGON_FOR_PANEL).toBe(8)
        for _, name in DragonKings.DRAGON_FOR_PANEL do
            local d = DragonKings.ASSETS[name]
            expect(d ~= nil).toBe(true)
            expect(d.normal:match("^rbxassetid://%d+$") ~= nil).toBe(true)
            expect(d.pierced:match("^rbxassetid://%d+$") ~= nil).toBe(true)
        end
    end)

    test("all 8 dragon kings are placed exactly once", function()
        local seen = {}
        for _, name in DragonKings.DRAGON_FOR_PANEL do
            expect(seen[name]).toBeNil() -- no dragon placed twice
            seen[name] = true
        end
        local count = 0
        for _ in DragonKings.ASSETS do
            count += 1
        end
        expect(count).toBe(8)
    end)

    test("Nanda / Upananda flank the +Z window on panels 4 & 5", function()
        expect(DragonKings.DRAGON_FOR_PANEL[4]).toBe("Nanda")
        expect(DragonKings.DRAGON_FOR_PANEL[5]).toBe("Upananda")
    end)
end)
