--!strict
local harness = require("./harness")
local BellDrive = require("../tools/builders/BellDrive")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BellDrive drive train (face-cog wheels + lantern pinion)", function()
    local spec = BellDrive.build(ZenDojo.palette, L)
    local d = L.bellDrive
    local byName = {}
    local cogs = { FaceWheelMain = 0, CamFaceWheel = 0 }
    local staves = 0
    for _, c in spec.children :: any do
        byName[c.name] = c
        local stem = c.name:match("^(%a+)_C%d+$")
        if stem and cogs[stem] ~= nil then
            cogs[stem] += 1
        end
        if c.name:match("^JackLanternStave%d+$") then
            staves += 1
        end
    end
    test("the train exists by name; the peg bevels are gone", function()
        for _, want in
            {
                "MainShaft",
                "JackShaftF1",
                "JackShaftF4",
                "FaceWheelMain",
                "CamFaceWheel",
                "CamFaceWheelHub",
                "JackLanternFlange1",
                "JackLanternFlange2",
                "CamShaft",
                "CamShaftF1",
                "JackHangerArm",
                "BearingPost5",
                "VertShaft",
                "VertPaddle",
            }
        do
            expect(byName[want] ~= nil).toBe(true)
        end
        for name in byName do
            expect(name:match("^Bevel")).toBeNil()
        end
    end)
    test("cog and stave counts state the ratio: 12 combs in, 24 combs out", function()
        expect(cogs.FaceWheelMain).toBe(d.faceWheelMainCogs)
        expect(cogs.CamFaceWheel).toBe(d.camFaceWheelCogs)
        expect(d.camFaceWheelCogs / d.faceWheelMainCogs).toBeCloseTo(2, 0.001) -- REDUCTION mirror
        expect(staves).toBe(d.lantern.staves)
    end)
    test("the arbor and cage clear both horizontal shafts (the intersection bugs)", function()
        -- the cage sits BELOW the cam shaft at the plan crossing: vertical clearance
        expect(d.camShaft.y - 0.5 >= d.jack.yTop + 0.3).toBe(true)
        expect(d.jack.yBottom - 0.2 >= d.shaftFrom[2] + 0.52).toBe(true) -- arbor bottom above the main-shaft octagon
        expect(math.abs(d.bearings[3].z - d.lantern.z) >= 1.5).toBe(true) -- pillow out of the cage
    end)
    test("the wheel discs stay clear of the stave sweep (either side)", function()
        local reach = d.lantern.staveRingR + 0.14
        expect(math.abs(d.faceWheelMain[3] - d.lantern.z) - 0.2 >= reach + 0.05).toBe(true)
        expect(math.abs(d.camFaceWheel[1] - d.lantern.x) - 0.2 >= reach + 0.05).toBe(true)
    end)
    test("the cage is SHORT: only the cam wheel's lower arc reaches it", function()
        expect(d.lantern.yTop < d.camFaceWheel[2]).toBe(true) -- cage tops out below the cam axle
        expect(d.jack.yTop >= d.lantern.yTop + 0.5).toBe(true) -- arbor carries the cage
    end)
    test("the kick paddle and pillow blocks hold their stations", function()
        expect(byName["VertPaddle"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
        expect(byName["BearingSaddle4"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
        -- the corner pillow carries the cam shaft's gear end
        expect(byName["BearingSaddle5"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
        expect(byName["BearingSaddle5"].properties.CFrame[1]).toBeCloseTo(-15, 0.001)
    end)
    test("the corner pillow clears the cage staves and the cam wheel's cog tips", function()
        local p5 = d.bearings[5]
        -- post sits WEST of the cage on the shaft line: X clearance to the stave sweep
        expect(d.lantern.x - (d.lantern.staveRingR + 0.14) >= p5.x + 0.45 + 0.2).toBe(true)
        -- cog tips (max jitter) stay east of the post's east face
        expect(p5.x + 0.45 <= d.camFaceWheel[1] - 0.2 - 1.26 / 2 - 0.05).toBe(true)
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
