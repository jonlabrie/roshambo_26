--!strict
local harness = require("./harness")
local ThemeManifest = require("../src/shared/ThemeManifest")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function validTheme(): any
    return {
        name = "T",
        labels = { boardHeader = "世界 · THE WORLD" },
        sounds = {
            clack = "0",
            gong = "0",
            drumroll = "0",
            latch = "0",
            splash = "0",
            bank = "0",
            waterAmbience = "0",
        },
        models = { boulder = "0", paperSheet = "0", shears = "0", umbrella = "0" },
        palette = {
            moss = { 0.48, 0.54, 0.39 },
            ivory = { 0.87, 0.84, 0.76 },
            vermilion = { 0.63, 0.36, 0.27 },
            ink = { 0.18, 0.19, 0.22 },
            gold = { 0.83, 0.69, 0.40 },
            water = { 0.20, 0.35, 0.43 },
            gravel = { 0.79, 0.76, 0.70 },
            timber = { 0.42, 0.31, 0.20 },
        },
        lighting = {
            clockTime = 16.5,
            brightness = 2.4,
            ambient = { 90, 88, 84 },
            outdoorAmbient = { 130, 120, 105 },
        },
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

    test("v2: missing palette key fails loudly", function()
        local theme = validTheme()
        theme.palette.moss = nil
        local ok, errs = ThemeManifest.validate(theme)
        expect(ok).toBe(false)
        expect(table.concat(errs, ";"):find("palette.moss") ~= nil).toBe(true)
    end)

    test("v2: missing lighting key fails loudly", function()
        local theme = validTheme()
        theme.lighting.clockTime = nil
        local ok = ThemeManifest.validate(theme)
        expect(ok).toBe(false)
    end)

    test("v2: waterAmbience is a required sound", function()
        local theme = validTheme()
        theme.sounds.waterAmbience = nil
        local ok = ThemeManifest.validate(theme)
        expect(ok).toBe(false)
    end)

    test("ZenDojo theme passes v2 validation", function()
        local ok, errs = ThemeManifest.validate(ZenDojo)
        expect(ok).toBe(true)
    end)
end)
