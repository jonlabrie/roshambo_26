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

describe("Snail cam geometry (mesh flank envelope)", function()
    local CamProfile = require("../src/shared/CamProfile")
    local spec = BellDrive.build(ZenDojo.palette, L)
    local d = L.bellDrive
    local G = {
        gapZ = L.shuMoku.drawDowel.from[3] - d.cam[3],
        draw = L.shuMoku.drawStuds,
        rise = d.camDowelRise,
        dowelR = 0.25,
        dropDeg = d.camDropDeg,
        clearance = d.camClearance,
    }
    local lobe = select(1, CamProfile.contact(1, G))
    test("the sweep clears the BELL FACE (the hero-cam regression)", function()
        -- bell: centre z=0, radius 5.1 → face at z≈5.1 near the strike height
        expect(d.cam[3] - lobe >= 5.1 + 0.4).toBe(true)
    end)
    test("the west hanger ropes clear the sweep (east face outboard of x -4.55)", function()
        -- rope line: spreader top (x=-6) to log attach (x=-2.8) crosses the cam's
        -- x-band; at x ≥ -4.55 the line dips inside the lobe at some draw phase
        expect(d.cam[1] + d.camWidth / 2 <= -4.55).toBe(true)
        -- and the dowel still spans past the cam's west face
        expect(L.shuMoku.drawDowel.to[1] <= d.cam[1] - d.camWidth / 2 - 0.2).toBe(true)
    end)
    test("the sweep clears the clearing floor", function()
        expect(d.cam[2] - lobe >= 112 + 1.5).toBe(true)
    end)
    test("the cam plane sits WEST of the log and its tail ring", function()
        local logWest = L.shuMoku.restPos[1] - L.shuMoku.radius -- the log's near flank
        local ringWest = L.shuMoku.restPos[1] - 1.95 / 2 -- tail ring reaches further
        expect(d.cam[1] + d.camWidth / 2 <= math.min(logWest, ringWest) - 0.1).toBe(true)
    end)
    test("the hub (the ^Cam contract part) is emitted; the plank flank is gone", function()
        local hub = false
        for _, c in spec.children :: any do
            if c.name == "Cam" then
                hub = true
            end
            expect(c.name:match("^CamEdge")).toBeNil()
            expect(c.name:match("^CamStrap")).toBeNil()
        end
        expect(hub).toBe(true)
    end)
end)
