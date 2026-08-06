--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local LaunchSites = require("../src/shared/LaunchSites")

-- Vector3 is a Roblox global, absent under Lune. LaunchSites takes plain {x,y,z} tables so it
-- stays pure and testable, exactly like every other module under src/shared.
local function v(x: number, y: number, z: number)
    return { x = x, y = y, z = z }
end

describe("LaunchSites", function()
    test("a public site admits anyone within its radius", function()
        local sites = { { pos = v(0, 0, 0), radius = 10, ownerUserId = nil } }
        expect(LaunchSites.isValid(v(3, 0, 4), sites, "u1")).toBe(true) -- 5 away
        expect(LaunchSites.isValid(v(30, 0, 0), sites, "u1")).toBe(false)
    end)

    test("the radius is inclusive at its edge", function()
        local sites = { { pos = v(0, 0, 0), radius = 10, ownerUserId = nil } }
        expect(LaunchSites.isValid(v(6, 0, 8), sites, "u1")).toBe(true) -- exactly 10
    end)

    test("distance ignores height, so a deck above a site still counts", function()
        local sites = { { pos = v(0, 0, 0), radius = 10, ownerUserId = nil } }
        expect(LaunchSites.isValid(v(3, 400, 4), sites, "u1")).toBe(true)
    end)

    test("an owned site admits ONLY its owner", function()
        local sites = { { pos = v(0, 0, 0), radius = 10, ownerUserId = "u1" } }
        expect(LaunchSites.isValid(v(1, 0, 1), sites, "u1")).toBe(true)
        expect(LaunchSites.isValid(v(1, 0, 1), sites, "u2")).toBe(false)
    end)

    test("standing in someone else's deck does not block a public site you also stand in", function()
        local sites = {
            { pos = v(0, 0, 0), radius = 10, ownerUserId = "u2" },
            { pos = v(0, 0, 0), radius = 10, ownerUserId = nil },
        }
        expect(LaunchSites.isValid(v(1, 0, 1), sites, "u1")).toBe(true)
    end)

    test("no sites means nowhere to launch", function()
        expect(LaunchSites.isValid(v(0, 0, 0), {}, "u1")).toBe(false)
    end)
end)
