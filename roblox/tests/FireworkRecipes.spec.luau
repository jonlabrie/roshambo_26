--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkRecipes = require("../src/shared/FireworkRecipes")
local FireworkCatalog = require("../src/shared/FireworkCatalog")

local function goodRecipe(): any
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = "rbxasset://s" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 190, 200 } },
            {
                at = 1.1,
                kind = "burst",
                anchor = "apex",
                texture = "rbxasset://textures/particles/sparkles_main.dds",
                color = { 255, 120, 140 },
                spread = 42,
            },
        },
    }
end

describe("FireworkRecipes.validate — the one recipe schema", function()
    test("a well-formed recipe passes", function()
        local ok, err = FireworkRecipes.validate(goodRecipe())
        expect(err == nil).toBe(true)
        expect(ok).toBe(true)
    end)

    test("A BURST WITH NO TEXTURE FAILS — the blank-sky trap", function()
        local r = goodRecipe()
        r.phases[3].texture = nil
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("a burst with an EMPTY texture fails the same way", function()
        local r = goodRecipe()
        r.phases[3].texture = ""
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("an unknown phase kind fails", function()
        local r = goodRecipe()
        r.phases[2].kind = "crossette" -- vocabulary project, not yet a word
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("phase times must be non-negative and non-decreasing", function()
        local r = goodRecipe()
        r.phases[3].at = 0.01 -- before the ascent
        expect(FireworkRecipes.validate(r)).toBe(false)
        local r2 = goodRecipe()
        r2.phases[1].at = -0.5
        expect(FireworkRecipes.validate(r2)).toBe(false)
    end)

    test("an anchor must be origin or apex", function()
        local r = goodRecipe()
        r.phases[3].anchor = "player"
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("a color must be three numbers in 0..255", function()
        local r = goodRecipe()
        r.phases[3].color = { 255, 120 }
        expect(FireworkRecipes.validate(r)).toBe(false)
        local r2 = goodRecipe()
        r2.phases[3].edgeColor = { 300, 0, 0 }
        expect(FireworkRecipes.validate(r2)).toBe(false)
    end)

    test("no phases at all fails", function()
        expect(FireworkRecipes.validate({ phases = {} })).toBe(false)
        expect(FireworkRecipes.validate({})).toBe(false)
        expect(FireworkRecipes.validate("peony")).toBe(false)
    end)

    test("EVERY SHIPPED CATALOG RECIPE PASSES — one schema, not two", function()
        for id, recipe in FireworkCatalog.RECIPES do
            local ok, err = FireworkRecipes.validate(recipe)
            if not ok then
                error(`catalog recipe '{id}' fails its own schema: {err}`)
            end
            expect(ok).toBe(true)
        end
    end)
end)
