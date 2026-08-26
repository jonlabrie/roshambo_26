--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local HudPrefs = require("../src/shared/HudPrefs")

describe("HudPrefs.merge", function()
    test("a patch naming only resultSplash leaves escalationPrompts untouched", function()
        -- the sabotage case: a merge that discards `current` and returns a fresh default table
        -- would pass this by coincidence (both start true), so the DEFAULTS start already
        -- disagrees with what the patch sets.
        local current = { escalationPrompts = true, resultSplash = true, statusBars = true }
        local next = HudPrefs.merge(current, { resultSplash = false })
        expect(next.resultSplash).toBe(false)
        expect(next.escalationPrompts).toBe(true)
    end)

    test("a patch naming only escalationPrompts leaves resultSplash untouched", function()
        -- the mirror: neither key may be privileged over the other
        local current = { escalationPrompts = true, resultSplash = true, statusBars = true }
        local next = HudPrefs.merge(current, { escalationPrompts = false })
        expect(next.escalationPrompts).toBe(false)
        expect(next.resultSplash).toBe(true)
    end)

    test("an empty patch changes nothing", function()
        local current = { escalationPrompts = false, resultSplash = false }
        local next = HudPrefs.merge(current, {})
        expect(next.escalationPrompts).toBe(false)
        expect(next.resultSplash).toBe(false)
    end)

    test("a non-boolean value in the patch is ignored, not coerced", function()
        local current = { escalationPrompts = true, resultSplash = true, statusBars = true }
        local next = HudPrefs.merge(current, { resultSplash = "false" :: any })
        expect(next.resultSplash).toBe(true)
    end)

    test("a missing key in the patch leaves current's value alone", function()
        local current = { escalationPrompts = false, resultSplash = true }
        local next = HudPrefs.merge(current, { resultSplash = false })
        expect(next.escalationPrompts).toBe(false)
    end)

    test("does not mutate current — a caller holding the old table must not see it change", function()
        local current = { escalationPrompts = true, resultSplash = true, statusBars = true }
        local next = HudPrefs.merge(current, { resultSplash = false })
        expect(current.resultSplash).toBe(true)
        expect(next == current).toBe(false)
    end)
end)

describe("HudPrefs.fromProfile", function()
    test("defaults a missing field to true", function()
        local prefs = HudPrefs.fromProfile({})
        expect(prefs.escalationPrompts).toBe(true)
        expect(prefs.resultSplash).toBe(true)
    end)

    test("respects an explicit false", function()
        local prefs = HudPrefs.fromProfile({ escalationPrompts = false, resultSplash = false })
        expect(prefs.escalationPrompts).toBe(false)
        expect(prefs.resultSplash).toBe(false)
    end)
end)

describe("HudPrefs.DEFAULTS", function()
    test("both keys are true", function()
        expect(HudPrefs.DEFAULTS.escalationPrompts).toBe(true)
        expect(HudPrefs.DEFAULTS.resultSplash).toBe(true)
    end)
    test("a patch naming only statusBars leaves the other two untouched", function()
        -- One remote carries every preference, so a body naming one must never reset the others.
        local current = { escalationPrompts = false, resultSplash = true, statusBars = true }
        local next = HudPrefs.merge(current, { statusBars = false })
        expect(next.statusBars).toBe(false)
        expect(next.escalationPrompts).toBe(false)
        expect(next.resultSplash).toBe(true)
    end)

    test("statusBars defaults ON, and an absent field on the wire reads as ON", function()
        -- No migration was run, so a row written before this field existed must show the feature
        -- rather than silently hide it.
        expect(HudPrefs.DEFAULTS.statusBars).toBe(true)
        expect(HudPrefs.fromProfile({}).statusBars).toBe(true)
        expect(HudPrefs.fromProfile({ statusBars = false }).statusBars).toBe(false)
    end)
end)

describe("HudPrefs.auraVisibility", function()
    local BASE =
        { escalationPrompts = true, resultSplash = true, statusBars = true, auraVisibility = "PUBLIC" }

    test("a recognised visibility is stored", function()
        for _, v in { "HIDDEN", "FRIENDS", "PUBLIC" } do
            expect(HudPrefs.merge(BASE, { auraVisibility = v }).auraVisibility).toBe(v)
        end
    end)

    test("⚠ an UNRECOGNISED visibility leaves the stored value alone", function()
        -- The first NON-BOOLEAN member of this table, so it cannot use the `type(x) == "boolean"`
        -- guard its neighbours use. A privacy setting that could be knocked to a default by a
        -- malformed body — or by a typo in a caller — is worse than one that refuses the write.
        local current =
            { escalationPrompts = true, resultSplash = true, statusBars = true, auraVisibility = "HIDDEN" }
        for _, bad in { "hidden", "", "PUBLICK", 3, true, {} } do
            expect(HudPrefs.merge(current, { auraVisibility = bad :: any }).auraVisibility).toBe("HIDDEN")
        end
        expect(HudPrefs.merge(current, {}).auraVisibility).toBe("HIDDEN")
    end)

    test("a patch naming only auraVisibility leaves the booleans untouched", function()
        local current =
            { escalationPrompts = false, resultSplash = true, statusBars = false, auraVisibility = "PUBLIC" }
        local next = HudPrefs.merge(current, { auraVisibility = "FRIENDS" })
        expect(next.auraVisibility).toBe("FRIENDS")
        expect(next.escalationPrompts).toBe(false)
        expect(next.resultSplash).toBe(true)
        expect(next.statusBars).toBe(false)
    end)

    test("absent on the wire means PUBLIC, and a stored value survives the round trip", function()
        -- Absent-means-PUBLIC matches this table's convention for every other field, and matches
        -- that a streak is ALREADY public in the stats room. No migration was run, so rows written
        -- before this field existed must read as PUBLIC rather than as silently hidden.
        expect(HudPrefs.fromProfile({}).auraVisibility).toBe("PUBLIC")
        expect(HudPrefs.fromProfile({ auraVisibility = "HIDDEN" }).auraVisibility).toBe("HIDDEN")
        expect(HudPrefs.fromProfile({ auraVisibility = "nonsense" }).auraVisibility).toBe("PUBLIC")
        expect(HudPrefs.DEFAULTS.auraVisibility).toBe("PUBLIC")
    end)
end)

describe("HudPrefs.isVisibility", function()
    test("recognises exactly the three wire values", function()
        -- ⚠ main.server.luau validates the SetHudPreference body with this, and that file is a
        -- Roblox-runtime file Lune never loads — so this is the only place the rule can be tested
        -- at all. If it moves back inline, it becomes untestable again, which is the mistake the
        -- whole HudPrefs module exists to have corrected once already.
        expect(HudPrefs.isVisibility("HIDDEN")).toBe(true)
        expect(HudPrefs.isVisibility("FRIENDS")).toBe(true)
        expect(HudPrefs.isVisibility("PUBLIC")).toBe(true)
        for _, bad in { "hidden", "Public", "", "GARBAGE", 3, true, {} } do
            expect(HudPrefs.isVisibility(bad :: any)).toBe(false)
        end
        expect(HudPrefs.isVisibility(nil)).toBe(false)
    end)
end)
