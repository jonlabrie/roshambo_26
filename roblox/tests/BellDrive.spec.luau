--!strict
local harness = require("./harness")
local BellDrive = require("../tools/builders/BellDrive")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BellDrive builder", function()
    local function names(spec)
        local n = {}
        for _, c in spec.children :: any do
            n[c.name] = true
        end
        return n
    end
    test("emits the whole train by name", function()
        local n = names(BellDrive.build(ZenDojo.palette, L))
        for _, want in { "MainShaft", "DriverGear", "CamGear", "CamShaft", "Cam", "VertShaft", "VertPaddle" } do
            expect(n[want]).toBe(true)
        end
    end)
    test("two drum-yoke arms carry the drum", function()
        local n = names(BellDrive.build(ZenDojo.palette, L))
        expect(n["DrumYoke1"] and n["DrumYoke2"]).toBe(true)
    end)
    test("the gears are placed at the layout centres", function()
        local spec = BellDrive.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "DriverGear" then
                expect(c.properties.CFrame[1]).toBe(L.bellDrive.driverGear[1])
                expect(c.properties.CFrame[2]).toBe(L.bellDrive.driverGear[2])
            end
        end
    end)
end)
