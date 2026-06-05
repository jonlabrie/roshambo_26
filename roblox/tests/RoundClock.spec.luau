--!strict
local harness = require("./harness")
local RoundClock = require("../src/shared/RoundClock")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("RoundClock", function()
    test("no sync before first sample", function()
        local c = RoundClock.new()
        expect(c:hasSync()).toBe(false)
    end)

    test("computes offset = serverTime + rtt/2 - localReceive", function()
        local c = RoundClock.new()
        -- server says 1000ms; rtt 100ms; we received at local 600ms
        -- offset = 1000 + 50 - 600 = 450
        c:addSample(1000, 100, 600)
        expect(c:hasSync()).toBe(true)
        expect(c:toServerTime(600)).toBe(1050)
        expect(c:toLocalTime(1050)).toBe(600)
    end)

    test("keeps the lowest-RTT sample (spike rejected)", function()
        local c = RoundClock.new()
        c:addSample(1000, 100, 600) -- offset 450
        c:addSample(5000, 400, 4000) -- spike: rtt 400 -> ignored
        expect(c:toServerTime(600)).toBe(1050) -- still offset 450
    end)

    test("a better (lower-RTT) sample replaces the offset", function()
        local c = RoundClock.new()
        c:addSample(1000, 100, 600) -- offset 450
        c:addSample(2000, 40, 1540) -- offset = 2000 + 20 - 1540 = 480
        expect(c:toServerTime(0)).toBe(480)
    end)

    test("reset() clears sync so a fresh epoch can be learned", function()
        local c = RoundClock.new()
        c:addSample(1000, 100, 600)
        c:reset()
        expect(c:hasSync()).toBe(false)
    end)
end)
