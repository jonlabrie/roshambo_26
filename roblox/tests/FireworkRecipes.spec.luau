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

    test("a burst may omit its texture — the style role resolves one at render", function()
        local r = goodRecipe()
        r.phases[3].texture = nil
        expect(FireworkRecipes.validate(r)).toBe(true)
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

    test("a burst may carry a known style; an unknown one fails", function()
        local r = goodRecipe()
        r.phases[3].style = "ring"
        expect(FireworkRecipes.validate(r)).toBe(true)
        r.phases[3].style = "chrysanthemum" -- not a wave-one word
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("staged fields belong to bursts alone", function()
        for _, field in { "style", "points", "scatter", "share" } do
            local r = goodRecipe();
            (r.phases[2] :: any)[field] = if field == "style" then "peony" else 2
            expect(FireworkRecipes.validate(r)).toBe(false)
        end
    end)

    test("points is an integer 1..MAX_POINTS; scatter >= 0; share > 0", function()
        local BurstStyles = require("../src/shared/BurstStyles")
        local cases: { { field: string, value: any, ok: boolean } } = {
            { field = "points", value = 1, ok = true },
            { field = "points", value = BurstStyles.MAX_POINTS, ok = true },
            { field = "points", value = 0, ok = false },
            { field = "points", value = BurstStyles.MAX_POINTS + 1, ok = false },
            { field = "points", value = 2.5, ok = false },
            { field = "scatter", value = 0, ok = true },
            { field = "scatter", value = -1, ok = false },
            { field = "share", value = 0.5, ok = true },
            { field = "share", value = 0, ok = false },
        }
        for _, c in cases do
            local r = goodRecipe();
            (r.phases[3] :: any)[c.field] = c.value
            expect(FireworkRecipes.validate(r)).toBe(c.ok)
        end
    end)
end)
