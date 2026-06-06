--!strict
local harness = require("./harness")
local ThemeManifest = require("../src/shared/ThemeManifest")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function validTheme(): any
    return {
        name = "T",
        labels = { boardHeader = "世界 · THE WORLD" },
        sounds = { clack = "0", gong = "0", drumroll = "0", latch = "0", splash = "0", bank = "0" },
        models = { boulder = "0", paperSheet = "0", shears = "0", umbrella = "0" },
    }
end

describe("ThemeManifest", function()
    test("accepts a complete theme", function()
        local ok, errs = ThemeManifest.validate(validTheme())
        expect(ok).toBe(true)
        expect(#errs).toBe(0)
    end)

    test("rejects missing name and boardHeader", function()
        local t = validTheme()
        t.name = nil
        t.labels.boardHeader = nil
        local ok, errs = ThemeManifest.validate(t)
        expect(ok).toBe(false)
        expect(#errs).toBe(2)
    end)

    test("rejects a missing required sound", function()
        local t = validTheme()
        t.sounds.gong = nil
        local ok, errs = ThemeManifest.validate(t)
        expect(ok).toBe(false)
        expect(errs[1]).toBe("missing sound: gong")
    end)

    test("rejects a non-string model ref", function()
        local t = validTheme()
        t.models.boulder = 123
        local ok = ThemeManifest.validate(t)
        expect(ok).toBe(false)
    end)

    test("the shipped ZenDojo theme validates", function()
        local ok, errs = ThemeManifest.validate(ZenDojo)
        expect(ok).toBe(true)
        expect(#errs).toBe(0)
    end)
end)
