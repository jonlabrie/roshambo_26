--!strict
local harness = require("./harness")
local EffectRegistry = require("../src/shared/EffectRegistry")
local EffectSelector = require("../src/shared/EffectSelector")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("EffectSelector", function()
    test("LOSS maps deterministically by world throw", function()
        -- Fixture, not the real EffectRegistry: LOSS is parked there (empty pool), but the
        -- byThrow branch itself is still live code and still needs coverage.
        local s = EffectSelector.new({
            LOSS = { byThrow = { R = "fateBoulder", P = "fatePaper", S = "fateShears" } },
        }, {
            random = function()
                return 0
            end,
        })
        expect(s:select("LOSS", { worldThrow = "R" })).toBe("fateBoulder")
        expect(s:select("LOSS", { worldThrow = "P" })).toBe("fatePaper")
        expect(s:select("LOSS", { worldThrow = "S" })).toBe("fateShears")
    end)

    test("other slots pick from the pool via injected random", function()
        local s = EffectSelector.new({ WIN = { "a", "b", "c" } }, {
            random = function()
                return 0.5
            end,
        })
        expect(s:select("WIN", {})).toBe("b")
    end)

    test("single-variant pools always return the variant", function()
        local s = EffectSelector.new(EffectRegistry, {
            random = function()
                return 0.99
            end,
        })
        expect(s:select("REVEAL", {})).toBe("waterHammer")
        -- SAFE emptied 2026-08-18: `umbrellaPop` drew a featureless disc the owner read as a
        -- cloud, and the familiar's perch carries SAFE now. Empty pool -> nil, same contract the
        -- parked fates rely on.
        expect(s:select("SAFE", {})).toBe(nil)
    end)

    test("unknown slot returns nil", function()
        local s = EffectSelector.new(EffectRegistry, {
            random = function()
                return 0
            end,
        })
        expect(s:select("NOPE", {})).toBeNil()
    end)
end)

describe("EffectRegistry — fates are parked", function()
    test("LOSS selects to nothing, for every world throw", function()
        local selector = EffectSelector.new(EffectRegistry, {
            random = function()
                return 0
            end,
        })
        for _, w in { "R", "P", "S" } do
            expect(selector:select("LOSS", { worldThrow = w })).toBe(nil)
        end
    end)

    test("the celebrations that remain are untouched", function()
        local selector = EffectSelector.new(EffectRegistry, {
            random = function()
                return 0
            end,
        })
        -- SAFE joined LOSS as a deliberately empty pool on 2026-08-18 — both outcomes are carried
        -- by the familiar now, not by a one-off effect. WIN keeps its petals as a flourish
        -- ALONGSIDE the bird: petals were never the problem, being the only thing was.
        for _, slot in { "REVEAL", "WIN", "BANK" } do
            expect(selector:select(slot, {}) ~= nil).toBe(true)
        end
        for _, slot in { "SAFE", "LOSS" } do
            expect(selector:select(slot, {})).toBe(nil)
        end
    end)
end)
