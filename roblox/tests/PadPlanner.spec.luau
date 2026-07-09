--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local PadPlanner = require("../src/shared/PadPlanner")

local IDENT = { 0, 20, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } -- datum plane at y=20, identity rotation
local FP = { minX = -7, maxX = 15, minZ = -11, maxZ = 4 }

test("flat ground: 6 posts at corners+mids, flush, spanning datum->ground-embed", function()
    local s = PadPlanner.planSupport(FP, IDENT, function()
        return 0
    end)
    expect(#s.posts).toBe(6)
    expect(#s.omitted).toBe(0)
    -- FL is first: outer corner flush -> centre (minX+0.6, .., minZ+0.6) = (-6.4, .., -10.4)
    expect(s.posts[1].pos[1]).toBe(-6.4)
    expect(s.posts[1].pos[3]).toBe(-10.4)
    -- height = datum(20) - (ground(0) - embed(1)) = 21; centre y = (20 + -1)/2 = 9.5
    expect(s.posts[1].height).toBe(21)
    expect(s.posts[1].pos[2]).toBe(9.5)
    -- MF (5th) sits at footprint centre-x = (-7+15)/2 = 4, minZ+0.6 = -10.4
    expect(s.posts[5].pos[1]).toBe(4)
    expect(s.posts[5].pos[3]).toBe(-10.4)
end)

test("sloped ground: per-post height follows groundAt(x,z)", function()
    -- ground rises 1 stud per +x; FR is at x = 15-0.6 = 14.4 -> ground 14.4
    local s = PadPlanner.planSupport(FP, IDENT, function(x, _z)
        return x
    end)
    -- FR is posts[2]; height = 20 - (14.4 - 1) = 6.6
    expect(s.posts[2].pos[1]).toBe(14.4)
    expect(s.posts[2].height).toBeCloseTo(6.6, 1e-6)
end)

test("over-void: nil ground omits the post and records its label", function()
    -- no ground on the front edge (minZ side): omit FL, FR, MF
    local s = PadPlanner.planSupport(FP, IDENT, function(_x, z)
        if z < -5 then
            return nil
        end
        return 0
    end)
    expect(#s.posts).toBe(3)
    expect(s.omitted).toEqual({ "FL", "FR", "MF" })
end)

test("rotated mount: 180-degree yaw negates local X/Z into world", function()
    -- yaw 180: R = {-1,0,0, 0,1,0, 0,0,-1}; world = pos + R*local
    local yaw180 = { 100, 20, 50, -1, 0, 0, 0, 1, 0, 0, 0, -1 }
    local s = PadPlanner.planSupport(FP, yaw180, function()
        return 0
    end)
    -- FL local (-6.4, 0, -10.4) -> world (100 - -6.4, .., 50 - -10.4) = (106.4, .., 60.4)
    expect(s.posts[1].pos[1]).toBe(106.4)
    expect(s.posts[1].pos[3]).toBe(60.4)
end)

test("embed: ground at/above the datum omits the post (deck beds into the slope)", function()
    -- datum plane y = 20; ground at +25 everywhere (above the deck) -> all 6 omitted
    local s = PadPlanner.planSupport(FP, IDENT, function()
        return 25
    end)
    expect(#s.posts).toBe(0)
    expect(#s.omitted).toBe(6)
end)

test("too-deep: ground more than MAXPOST(80) below the datum omits the post (void)", function()
    -- datum y = 20; ground at -70 -> depth 90 > 80 -> omit
    local s = PadPlanner.planSupport(FP, IDENT, function()
        return -70
    end)
    expect(#s.posts).toBe(0)
    expect(#s.omitted).toBe(6)
end)

test("path keep-out: a post that would land on a tagged path is omitted (deck cantilevers)", function()
    -- flat ground; `blocked` flags only the FR post (x=14.4, front z<0) as over a path
    -- (BR shares maxX at x=14.4, so disambiguate by z to hit FR alone)
    local s = PadPlanner.planSupport(FP, IDENT, function()
        return 0
    end, function(x, z, _topY, _groundY)
        return x > 14 and z < 0
    end)
    expect(#s.posts).toBe(5)
    expect(s.omitted).toEqual({ "FR" })
end)

test("path keep-out predicate is optional: nil -> no path omission", function()
    local s = PadPlanner.planSupport(FP, IDENT, function()
        return 0
    end)
    expect(#s.posts).toBe(6)
    expect(#s.omitted).toBe(0)
end)

test(
    "path keep-out is only consulted for otherwise-buildable posts (stacks with void, no double-count)",
    function()
        -- front 3 (FL/FR/MF) over void via nil ground; blocked returns true for everything.
        -- The 3 buildable back posts get omitted by path; the front 3 by void -> 6 omitted, 0 posts.
        local s = PadPlanner.planSupport(FP, IDENT, function(_x, z)
            if z < -5 then
                return nil
            end
            return 0
        end, function()
            return true
        end)
        expect(#s.posts).toBe(0)
        expect(#s.omitted).toBe(6)
    end
)

test("path keep-out receives the post top (x,z,y) and ground y", function()
    -- assert the predicate is called with the FL post's world coords and Ys
    local seen = nil
    PadPlanner.planSupport(FP, IDENT, function()
        return 0
    end, function(x, z, topY, groundY)
        if x == -6.4 and z == -10.4 then
            seen = { x, z, topY, groundY }
        end
        return false
    end)
    expect(seen).toEqual({ -6.4, -10.4, 20, 0 })
end)
