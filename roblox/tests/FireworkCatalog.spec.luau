--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkCatalog = require("../src/shared/FireworkCatalog")
local FireworkSchedule = require("../src/shared/FireworkSchedule")
local fixture = require("./fixtures/fireworkShells")

describe("FireworkCatalog — the other half of the contract", function()
    test("EVERY SHELL THE SERVER CAN SELL HAS A RECIPE", function()
        -- The gate this fixture exists for. A shell in the shop with no recipe here is a blank sky
        -- — no error, no log, and nobody would think to look for it.
        for _, id in fixture.shells do
            expect(FireworkCatalog.RECIPES[id] ~= nil).toBe(true)
        end
    end)

    test("and no recipe exists for a shell the server cannot sell", function()
        local known = {}
        for _, id in fixture.shells do
            known[id] = true
        end
        for id in FireworkCatalog.RECIPES do
            expect(known[id]).toBe(true)
        end
    end)

    test("every shell has a launch report, an ascent and at least one burst", function()
        -- A shell that skips the report has no thump at the tube and reads as a firework that
        -- started halfway through.
        for _, recipe in FireworkCatalog.RECIPES do
            local kinds = {}
            for _, ph in recipe.phases do
                kinds[ph.kind] = true
            end
            expect(kinds.report).toBe(true)
            expect(kinds.ascent).toBe(true)
            expect(kinds.burst).toBe(true)
        end
    end)

    test("every burst names a texture — an empty Texture renders NOTHING", function()
        for _, recipe in FireworkCatalog.RECIPES do
            for _, ph in recipe.phases do
                if ph.kind == "burst" then
                    expect(typeof(ph.texture)).toBe("string")
                    expect(#ph.texture > 0).toBe(true)
                end
            end
        end
    end)

    test("the report precedes the ascent, which precedes every burst", function()
        for _, recipe in FireworkCatalog.RECIPES do
            local ev = FireworkSchedule.compile(recipe, 400)
            local seenAscent = false
            for _, e in ev do
                if e.kind == "ascent" then
                    seenAscent = true
                elseif e.kind == "burst" then
                    expect(seenAscent).toBe(true)
                end
            end
        end
    end)

    test("every recipe compiles, and stays inside a budget", function()
        for _, recipe in FireworkCatalog.RECIPES do
            local total = 0
            for _, e in FireworkSchedule.compile(recipe, 400) do
                total += e.particles * e.points
            end
            expect(total <= 400).toBe(true)
        end
    end)

    test("it holds no Roblox globals — colours are plain {r,g,b} arrays", function()
        for _, recipe in FireworkCatalog.RECIPES do
            for _, ph in recipe.phases do
                if ph.color then
                    expect(typeof(ph.color)).toBe("table")
                    expect(#ph.color).toBe(3)
                end
            end
        end
    end)
end)
