--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local LanternGlow = require("../src/shared/LanternGlow")

local function near(a: number, b: number): boolean
    return math.abs(a - b) < 1e-6
end

describe("LanternGlow.at", function()
    test("stone goes fully out by day — transparency 1 skips the draw", function()
        local g = LanternGlow.at("stone", 0)
        expect(near(g.transparency, 1)).toBe(true)
        expect(near(g.brightness, 0)).toBe(true)
        -- a light at brightness 0 still costs a renderer slot, so it must be switched off
        expect(g.enabled).toBe(false)
    end)

    test("stone at full night matches the values the cores are authored with", function()
        local g = LanternGlow.at("stone", 1)
        expect(near(g.transparency, 0.32)).toBe(true)
        expect(near(g.brightness, 1.0)).toBe(true)
        expect(g.enabled).toBe(true)
    end)

    test("paper NEVER goes out — it is the round telegraph, not an ornament", function()
        local day = LanternGlow.at("paper", 0)
        expect(day.enabled).toBe(true)
        expect(day.brightness > 0).toBe(true)
        -- and it stays clearly translucent, so the glyph reads against it at noon
        expect(day.transparency < 1).toBe(true)
    end)

    test("paper is dimmer by day than by night, on both channels", function()
        local day, night = LanternGlow.at("paper", 0), LanternGlow.at("paper", 1)
        expect(day.brightness < night.brightness).toBe(true)
        expect(day.transparency > night.transparency).toBe(true)
        expect(near(night.transparency, 0.42)).toBe(true)
        expect(near(night.brightness, 1.1)).toBe(true)
    end)

    test("halfway is halfway", function()
        local g = LanternGlow.at("stone", 0.5)
        expect(near(g.transparency, 0.66)).toBe(true)
        expect(near(g.brightness, 0.5)).toBe(true)
    end)

    test("nightFactor is CLAMPED, not trusted", function()
        -- the signal arrives over an EventBus that can be primed, replayed or fired
        -- mid-transition; out-of-range would push transparency past 1 or below 0
        for _, profile in { "stone", "paper" } do
            local lo, under = LanternGlow.at(profile, 0), LanternGlow.at(profile, -5)
            local hi, over = LanternGlow.at(profile, 1), LanternGlow.at(profile, 12)
            expect(near(under.transparency, lo.transparency)).toBe(true)
            expect(near(under.brightness, lo.brightness)).toBe(true)
            expect(near(over.transparency, hi.transparency)).toBe(true)
            expect(near(over.brightness, hi.brightness)).toBe(true)
        end
    end)

    test("monotonic across the cycle — no flicker as nightFactor sweeps", function()
        for _, profile in { "stone", "paper" } do
            local prevT, prevB = math.huge, -math.huge
            for i = 0, 20 do
                local g = LanternGlow.at(profile, i / 20)
                expect(g.transparency <= prevT + 1e-9).toBe(true)
                expect(g.brightness >= prevB - 1e-9).toBe(true)
                prevT, prevB = g.transparency, g.brightness
            end
        end
    end)

    test("an unknown profile is an error, not a silent default", function()
        local ok = pcall(function()
            return LanternGlow.at("bonfire", 0.5)
        end)
        expect(ok).toBe(false)
    end)
end)
