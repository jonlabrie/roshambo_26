--!strict
local harness = require("./harness")
local BackDoorEditor = require("../src/shared/BackDoorEditor")
local describe, test, expect = harness.describe, harness.test, harness.expect
local set = BackDoorEditor.setBackDoor
local idx = BackDoorEditor.backDoorIndex

describe("BackDoorEditor.setBackDoor", function()
    test("sets a dense back list with the door at the chosen index", function()
        local out = set(nil, 2, 3)
        expect(#out.back).toBe(3)
        expect(out.back[1]).toBe("solid")
        expect(out.back[2]).toBe("door")
        expect(out.back[3]).toBe("solid")
    end)

    test("moves the door when a different index is chosen", function()
        local a = set(nil, 1, 3)
        local b = set(a, 3, 3)
        expect(b.back[1]).toBe("solid")
        expect(b.back[3]).toBe("door")
        expect(idx(b)).toBe(3)
    end)

    test("toggles off when the active index is re-chosen (drops back)", function()
        local a = set(nil, 2, 3)
        local b = set(a, 2, 3)
        expect(b.back == nil).toBe(true)
        expect(idx(b) == nil).toBe(true)
    end)

    test("clears when index is nil", function()
        local a = set(nil, 2, 3)
        local b = set(a, nil, 3)
        expect(b.back == nil).toBe(true)
    end)

    test("out-of-range index yields no back door", function()
        expect(set(nil, 0, 3).back == nil).toBe(true)
        expect(set(nil, 4, 3).back == nil).toBe(true)
    end)

    test("passes other sides through unchanged and does not mutate input", function()
        local input = { front = { "shoji", "shoji" } }
        local out = set(input, 1, 3)
        expect(out.front[1]).toBe("shoji")
        expect(out.front[2]).toBe("shoji")
        expect(out.back[1]).toBe("door")
        expect(input.back == nil).toBe(true) -- input untouched
        expect(#input.front).toBe(2)
    end)
end)

describe("BackDoorEditor.backDoorIndex", function()
    test("nil map / nil back / no door -> nil", function()
        expect(idx(nil) == nil).toBe(true)
        expect(idx({}) == nil).toBe(true)
        expect(idx({ back = { "solid", "solid" } }) == nil).toBe(true)
    end)

    test("finds the door index", function()
        expect(idx({ back = { "solid", "door", "solid" } })).toBe(2)
    end)
end)
