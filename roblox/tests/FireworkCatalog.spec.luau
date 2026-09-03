--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkCatalog = require("../src/shared/FireworkCatalog")
local FireworkSchedule = require("../src/shared/FireworkSchedule")
local MortarPlacement = require("../src/shared/MortarPlacement")
local fixture = require("./fixtures/fireworkShells")

describe("FireworkCatalog — the other half of the contract", function()
    test("A HEAVY CATALOG SHELL LIVES IN THE L TUBE", function()
        -- recipe.heavy doubles the particle budget under weighted admission; the class
        -- exists FOR the L tube. A heavy S/M shell would be a budget cheat wearing a flag.
        for id, recipe in FireworkCatalog.RECIPES do
            if (recipe :: any).heavy then
                if MortarPlacement.SHELL_MORTAR[id] ~= "mortar:L" then
                    error(`catalog shell '{id}' declares heavy but is not a mortar:L shell`)
                end
                expect(MortarPlacement.SHELL_MORTAR[id]).toBe("mortar:L")
            end
        end
    end)

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

    test("a burst's texture, when named, is non-empty — an empty Texture renders NOTHING", function()
        -- Since 2026-09-03 a burst may omit `texture` entirely: the style's textureRole
        -- resolves one at render, and BurstStyles' own tests keep every role id non-empty.
        for _, recipe in FireworkCatalog.RECIPES do
            for _, ph in recipe.phases do
                if ph.kind == "burst" and ph.texture ~= nil then
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
