--!strict
local harness = require("./harness")
local PreferenceEditor = require("../src/shared/PreferenceEditor")
local describe, test, expect = harness.describe, harness.test, harness.expect
local toggle = PreferenceEditor.togglePreference

describe("PreferenceEditor.togglePreference", function()
    test("appends an absent site (favorited=true), order preserved", function()
        local out, fav = toggle({ "T02" }, "T06", 32)
        expect(#out).toBe(2)
        expect(out[1]).toBe("T02")
        expect(out[2]).toBe("T06")
        expect(fav).toBe(true)
    end)

    test("removes a present site (favorited=false), order preserved", function()
        local out, fav = toggle({ "T02", "T06", "T04" }, "T06", 32)
        expect(#out).toBe(2)
        expect(out[1]).toBe("T02")
        expect(out[2]).toBe("T04")
        expect(fav).toBe(false)
    end)

    test("appended lists do not duplicate; toggling again removes", function()
        local out = toggle({ "T02" }, "T06", 32)
        local out2, fav2 = toggle(out, "T02", 32) -- T02 present -> removed
        expect(#out2).toBe(1)
        expect(out2[1]).toBe("T06")
        expect(fav2).toBe(false)
    end)

    test("at the cap, adding a new site is a no-op (favorited=false)", function()
        local full = {}
        for i = 1, 32 do
            full[i] = "S" .. i
        end
        local out, fav = toggle(full, "NEW", 32)
        expect(#out).toBe(32)
        expect(fav).toBe(false)
    end)

    test("removing works even when at the cap", function()
        local full = {}
        for i = 1, 32 do
            full[i] = "S" .. i
        end
        local out, fav = toggle(full, "S1", 32)
        expect(#out).toBe(31)
        expect(fav).toBe(false)
    end)
end)
