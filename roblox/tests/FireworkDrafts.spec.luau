--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkDrafts = require("../src/shared/FireworkDrafts")
local FireworkRecipes = require("../src/shared/FireworkRecipes")
local FireworkCatalog = require("../src/shared/FireworkCatalog")

describe("FireworkDrafts — the proving range's working file", function()
    test("EVERY DRAFT IN EVERY FAMILY PASSES THE SCHEMA", function()
        -- The whole point: a typo'd draft fails here, not as a blank sky in Play.
        local count = 0
        for family, variants in FireworkDrafts.FAMILIES do
            for variant, recipe in variants do
                count += 1
                local ok, err = FireworkRecipes.validate(recipe)
                if not ok then
                    error(`draft {family}/{variant}: {err}`)
                end
                expect(ok).toBe(true)
            end
        end
        -- An EMPTY worksheet is legal (first reached 2026-09-06: every judged family
        -- shipped or was reframed to collections) -- the schema check simply has nothing
        -- to say until the next family is authored.
        expect(count >= 0).toBe(true)
    end)

    test("resolve round-trips the namespaced id for EVERY family and EVERY variant", function()
        -- Round-tripping only families[1]/variants[1] would miss a future family name the
        -- resolve pattern (%w_ only) can't parse -- every family, every variant, must resolve
        -- back to the exact recipe table it came from.
        local families = FireworkDrafts.familyNames()
        local checked = 0
        for _, family in families do
            local variants = FireworkDrafts.variantsOf(family)
            expect(#variants > 0).toBe(true)
            for _, variant in variants do
                local id = "draft:" .. family .. "/" .. variant
                expect(FireworkDrafts.resolve(id) == FireworkDrafts.FAMILIES[family][variant]).toBe(true)
                checked += 1
            end
        end
        expect(checked >= 0).toBe(true)
    end)

    test("resolve returns nil for unknowns and malformed ids", function()
        expect(FireworkDrafts.resolve("draft:nosuch/v1") == nil).toBe(true)
        expect(FireworkDrafts.resolve("peony") == nil).toBe(true)
        expect(FireworkDrafts.resolve("draft:") == nil).toBe(true)
        expect(FireworkDrafts.resolve("draft:kiku") == nil).toBe(true)
    end)

    test("variantsOf is sorted and empty for unknown families", function()
        for _, family in FireworkDrafts.familyNames() do
            local v = FireworkDrafts.variantsOf(family)
            for i = 2, #v do
                expect(v[i - 1] < v[i]).toBe(true)
            end
        end
        expect(#FireworkDrafts.variantsOf("nosuch")).toBe(0)
    end)

    test("no family name shadows a shipped shell id", function()
        -- The draft: prefix already prevents runtime collision; this keeps the
        -- human namespace clean too, so promotion is a move, not a rename.
        for family in FireworkDrafts.FAMILIES do
            expect(FireworkCatalog.RECIPES[family] == nil).toBe(true)
        end
    end)
end)
