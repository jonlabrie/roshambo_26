--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("harness", function()
    test("toBe passes on equal primitives", function()
        expect(3).toBe(3)
        expect("a").toBe("a")
    end)

    test("toEqual deep-compares tables", function()
        expect({ R = 1, nested = { x = 2 } }).toEqual({ R = 1, nested = { x = 2 } })
    end)

    test("toEqual detects extra keys on either side", function()
        expect(function()
            expect({ a = 1 }).toEqual({ a = 1, b = 2 })
        end).toThrow()
        expect(function()
            expect({ a = 1, b = 2 }).toEqual({ a = 1 })
        end).toThrow()
    end)

    test("toBe failure throws with a message", function()
        expect(function()
            expect(1).toBe(2)
        end).toThrow()
    end)

    test("toBeCloseTo tolerates epsilon", function()
        expect(0.1 + 0.2).toBeCloseTo(0.3)
    end)
end)
