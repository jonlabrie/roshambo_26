--!strict
local harness = require("./harness")
local BellDrive = require("../tools/builders/BellDrive")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BellDrive drive train (jack shaft + toothed bevels)", function()
    local spec = BellDrive.build(ZenDojo.palette, L)
    local byName = {}
    local counts = {}
    for _, c in spec.children :: any do
        byName[c.name] = c
        local stem = c.name:match("^(Bevel%a+)_T%d+$")
        if stem then
            counts[stem] = (counts[stem] or 0) + 1
        end
    end
    test("the train exists by name; the old placeholder gears are gone", function()
        for _, want in
            {
                "MainShaft",
                "JackShaftF1",
                "JackShaftF4",
                "BevelMainA",
                "BevelJackA",
                "BevelJackB",
                "BevelCamB",
                "CamShaft",
                "CamShaftF1",
                "CamShaftF4",
                "JackFramePost",
                "VertShaft",
                "VertPaddle",
            }
        do
            expect(byName[want] ~= nil).toBe(true)
        end
        expect(byName["DriverGear"]).toBeNil()
        expect(byName["CamGear"]).toBeNil()
    end)
    test("tooth counts state the reduction: 10/10 then 10/20", function()
        expect(counts.BevelMainA).toBe(10)
        expect(counts.BevelJackA).toBe(10)
        expect(counts.BevelJackB).toBe(10)
        expect(counts.BevelCamB).toBe(20)
        expect(L.bellDrive.bevelR2 / L.bellDrive.bevelR1).toBeCloseTo(2, 0.001) -- REDUCTION mirror
    end)
    test("the cam shaft proxy rides the cam axle line and is invisible", function()
        local cs = byName["CamShaft"].properties
        expect(cs.Transparency).toBe(1)
        expect(cs.CFrame[2]).toBeCloseTo(L.bellDrive.camShaft.y, 0.001)
        expect(cs.CFrame[3]).toBeCloseTo(L.bellDrive.camShaft.z, 0.001)
    end)
    test("the kick paddle meets the raised dowel", function()
        expect(byName["VertPaddle"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
    end)
    test("the tall cam-shaft pillow block sits under the cam shaft", function()
        expect(byName["BearingSaddle4"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
        expect(byName["BearingPost4"] ~= nil).toBe(true)
        expect(byName["BearingPlate4"] ~= nil).toBe(true)
    end)
end)
