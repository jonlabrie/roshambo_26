--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local StatsFilters = require("../src/shared/StatsFilters")

local upper = function(s: string): string
    return string.upper(s)
end
local F = StatsFilters.new(upper)

describe("StatsFilters.top", function()
    test(
        "filters displayName on the first 10 rows only, copying those rows, passing the rest through",
        function()
            local rows = {}
            for i = 1, 12 do
                table.insert(rows, { displayName = `p{i}`, points = i })
            end
            local out = F.top(rows)
            expect(#out).toBe(12)
            expect(out[1].displayName).toBe("P1")
            expect(out[10].displayName).toBe("P10")
            expect(out[11].displayName).toBe("p11")
            expect(rows[1].displayName).toBe("p1") -- input untouched
        end
    )
    test("a missing name filters as ?", function()
        expect(F.top({ {} })[1].displayName).toBe("?")
    end)
    test("nil is an empty list", function()
        expect(#F.top(nil)).toBe(0)
    end)
end)

describe("records / board / heat", function()
    test("records filters its three lists and nothing else", function()
        local r = F.records({
            longestStreaks = { { displayName = "a" } },
            biggestBanks = {},
            biggestRounds = {},
            other = 1,
        })
        expect(r.longestStreaks[1].displayName).toBe("A")
        expect(r.other).toBe(1)
    end)
    test("board filters rows; heat filters leaders; nil passes through", function()
        expect(F.board({ rows = { { displayName = "b" } } }).rows[1].displayName).toBe("B")
        expect(F.heat({ leaders = { { displayName = "c" } } }).leaders[1].displayName).toBe("C")
        expect(F.board(nil)).toBeNil()
        expect(F.heat(nil)).toBeNil()
        expect(F.records(nil)).toBeNil()
    end)
end)
