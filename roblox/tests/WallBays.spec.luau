--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local WallBays = require("../src/shared/WallBays")

local AVAIL = {
    { side = "front", index = 1 },
    { side = "front", index = 2 },
    { side = "back", index = 1 },
    { side = "left", index = 1 },
}

local function stateOf(resolved, side, index)
    for _, b in resolved do
        if b.side == side and b.index == index then
            return b.state
        end
    end
    return nil
end

describe("WallBays.defaultState", function()
    test("front opens as shoji; other sides are solid", function()
        expect(WallBays.defaultState("front")).toBe("shoji")
        expect(WallBays.defaultState("back")).toBe("solid")
        expect(WallBays.defaultState("left")).toBe("solid")
        expect(WallBays.defaultState("right")).toBe("solid")
    end)
end)

describe("WallBays.validate", function()
    test("accepts a map of known states", function()
        expect(WallBays.validate({ back = { "solid", "door" }, front = { "shoji" } })).toBe(true)
    end)
    test("rejects an unknown state", function()
        expect(WallBays.validate({ back = { "window" } })).toBe(false)
    end)
end)

describe("WallBays.resolve", function()
    test("no map -> per-side defaults for every available bay", function()
        local r = WallBays.resolve(AVAIL, nil)
        expect(#r).toBe(4)
        expect(stateOf(r, "front", 1)).toBe("shoji")
        expect(stateOf(r, "front", 2)).toBe("shoji")
        expect(stateOf(r, "back", 1)).toBe("solid")
        expect(stateOf(r, "left", 1)).toBe("solid")
    end)
    test("a valid map overrides per (side,index); unlisted bays keep the default", function()
        local r = WallBays.resolve(AVAIL, { back = { "door" }, front = { [2] = "solid" } })
        expect(stateOf(r, "back", 1)).toBe("door") -- overridden
        expect(stateOf(r, "front", 2)).toBe("solid") -- overridden
        expect(stateOf(r, "front", 1)).toBe("shoji") -- default kept (not listed)
        expect(stateOf(r, "left", 1)).toBe("solid") -- default kept (side absent)
    end)
    test("an invalid map is ignored WHOLESALE -> a valid override elsewhere is discarded too", function()
        local r = WallBays.resolve(AVAIL, { back = { "trapdoor" }, front = { [1] = "solid" } })
        expect(stateOf(r, "back", 1)).toBe("solid") -- the bogus bay defaults
        expect(stateOf(r, "front", 1)).toBe("shoji") -- a VALID override is ALSO discarded (whole map ignored)
    end)
    test(
        "a valid map with a side present but this bay's index absent -> that bay keeps its default",
        function()
            local r = WallBays.resolve(AVAIL, { front = { [2] = "solid" } }) -- front index 1 absent
            expect(stateOf(r, "front", 1)).toBe("shoji") -- default kept (index 1 not in map)
            expect(stateOf(r, "front", 2)).toBe("solid") -- index 2 overridden
        end
    )
end)
