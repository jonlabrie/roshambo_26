--!strict
-- Locks every animated part name the client controllers depend on, across all five
-- centerpiece builders, BEFORE the art pass edits them. If an art edit renames or
-- drops an animated part, this fails — catching a silently-broken mechanism at CI
-- instead of in-world. Names sourced from HammerController/DrumController/WheelController.
local harness = require("./harness")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local Bonsho = require("../tools/builders/Bonsho")
local Shoro = require("../tools/builders/Shoro")
local Waterwheel = require("../tools/builders/Waterwheel")
local ThrowDrum = require("../tools/builders/ThrowDrum")
local BellDrive = require("../tools/builders/BellDrive")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function nameSet(spec: any): { [string]: boolean }
    local names = {}
    for _, c in spec.children :: any do
        names[c.name] = true
    end
    return names
end

local function requireAll(names: { [string]: boolean }, required: { string })
    for _, r in required do
        expect(names[r]).toBe(true)
    end
end

local function countMatching(spec: any, pat: string): number
    local n = 0
    for _, c in spec.children :: any do
        if (c.name :: string):match(pat) then
            n += 1
        end
    end
    return n
end

describe("centerpiece mechanism contract", function()
    test("BonshoRig keeps the striker/bell/chain parts", function()
        local names = nameSet(Bonsho.build(ZenDojo.palette, L))
        requireAll(names, {
            "Bonsho",
            "ShuMoku",
            "ShuMokuDrawDowel",
            "ShuMokuDowel",
            "Chain1",
            "Chain2",
            "Chain3",
            "Chain4",
            "HangerBeam",
            "Spreader1",
            "Spreader2",
        })
    end)
    test("ThrowDrum keeps the hub and 12 facets (no spokes)", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local names = nameSet(spec)
        requireAll(names, {
            "Drum",
            "Face0",
            "Face1",
            "Face2",
            "Face3",
            "Face4",
            "Face5",
            "Face6",
            "Face7",
            "Face8",
            "Face9",
            "Face10",
            "Face11",
        })
        expect(countMatching(spec, "^Spoke%d+$")).toBe(0)
    end)
    test("Waterwheel keeps Wheel1, its paddles, and the ratchet", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local names = nameSet(spec)
        requireAll(names, { "Wheel1", "RatchetDrum" })
        expect(countMatching(spec, "^Paddle1_%d+$")).toBe(Waterwheel.PADDLES)
    end)
    test("BellDrive keeps a Cam part plus the shafts/gears/yokes", function()
        local spec = BellDrive.build(ZenDojo.palette, L)
        local names = nameSet(spec)
        requireAll(names, {
            "CamShaft",
            "BevelMainA",
            "BevelJackA",
            "BevelJackB",
            "BevelCamB",
            "JackShaftF1",
            "MainShaft",
            "VertShaft",
            "VertPaddle",
            "DriveGearA",
            "DriveGearB",
            "DrivePaddle",
            "DriveGearBShaft",
        })
        expect(countMatching(spec, "^Cam") >= 1).toBe(true)
    end)
    test("Shoro still builds a model (no contract parts, art may change freely)", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        expect(spec.className).toBe("Model")
    end)
end)
