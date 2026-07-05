--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local PadBuilder = require("../src/shared/PadBuilder")

local IDENT = { 0, 20, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local FP = { minX = -7, maxX = 15, minZ = -11, maxZ = 4 }

test("build calls buildPost per planned post and returns the mount", function()
    local built = {}
    local ground = {}
    local ops = {
        raycastGround = function(x, z)
            table.insert(ground, { x, z })
            return 0
        end,
        buildPost = function(pos, height)
            table.insert(built, { pos = pos, height = height })
        end,
    }
    local mount = PadBuilder.build({ mountCF = IDENT, hand = "right", footprint = FP }, ops)
    expect(#built).toBe(6)
    expect(#ground).toBe(6) -- planner queried ground once per candidate post
    expect(built[1].height).toBe(21) -- FL, flat ground at y=0, datum y=20
    expect(mount.cframe).toEqual(IDENT)
    expect(mount.hand).toBe("right")
    expect(mount.footprint).toEqual(FP)
end)

test("build skips buildPost for over-void posts", function()
    local built = 0
    local ops = {
        raycastGround = function(_x, z)
            if z < -5 then return nil end
            return 0
        end,
        buildPost = function(_pos, _height)
            built += 1
        end,
    }
    PadBuilder.build({ mountCF = IDENT, hand = "left", footprint = FP }, ops)
    expect(built).toBe(3) -- FL/FR/MF omitted
end)
