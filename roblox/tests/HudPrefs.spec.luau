--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local HudPrefs = require("../src/shared/HudPrefs")

describe("HudPrefs.merge", function()
    test("a patch naming only resultSplash leaves escalationPrompts untouched", function()
        -- the sabotage case: a merge that discards `current` and returns a fresh default table
        -- would pass this by coincidence (both start true), so the DEFAULTS start already
        -- disagrees with what the patch sets.
        local current = { escalationPrompts = true, resultSplash = true }
        local next = HudPrefs.merge(current, { resultSplash = false })
        expect(next.resultSplash).toBe(false)
        expect(next.escalationPrompts).toBe(true)
    end)

    test("a patch naming only escalationPrompts leaves resultSplash untouched", function()
        -- the mirror: neither key may be privileged over the other
        local current = { escalationPrompts = true, resultSplash = true }
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
        local current = { escalationPrompts = true, resultSplash = true }
        local next = HudPrefs.merge(current, { resultSplash = "false" :: any })
        expect(next.resultSplash).toBe(true)
    end)

    test("a missing key in the patch leaves current's value alone", function()
        local current = { escalationPrompts = false, resultSplash = true }
        local next = HudPrefs.merge(current, { resultSplash = false })
        expect(next.escalationPrompts).toBe(false)
    end)

    test("does not mutate current — a caller holding the old table must not see it change", function()
        local current = { escalationPrompts = true, resultSplash = true }
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
end)
