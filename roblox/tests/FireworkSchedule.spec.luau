--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkSchedule = require("../src/shared/FireworkSchedule")

-- A nested shell: one main break, then six secondary points a third of a second later. No shipping
-- shell uses this yet — it is here because the FORMAT and the PLAYER must support it, so the first
-- nested shell is authored rather than engineered.
local NESTED = {
    phases = {
        { at = 0.0, kind = "report", anchor = "origin", sound = "rbxassetid://1" },
        { at = 0.02, kind = "ascent", anchor = "origin", sound = "rbxassetid://2" },
        {
            at = 1.1,
            kind = "burst",
            anchor = "apex",
            points = 1,
            scatter = 0,
            share = 2,
            sound = "rbxassetid://3",
        },
        {
            at = 1.45,
            kind = "burst",
            anchor = "apex",
            points = 6,
            scatter = 26,
            share = 1,
            sound = "rbxassetid://4",
        },
    },
}

local SIMPLE = {
    phases = {
        { at = 0.0, kind = "report", anchor = "origin" },
        { at = 0.02, kind = "ascent", anchor = "origin" },
        { at = 1.1, kind = "burst", anchor = "apex" },
    },
}

describe("FireworkSchedule — compiling a recipe", function()
    test("it emits one event per phase, in time order", function()
        local ev = FireworkSchedule.compile(NESTED, 400)
        expect(#ev).toBe(4)
        local prev = -1
        for _, e in ev do
            expect(e.at >= prev).toBe(true)
            prev = e.at
        end
    end)

    test("phases authored out of order are sorted into time order", function()
        local scrambled = {
            phases = {
                { at = 1.1, kind = "burst", anchor = "apex" },
                { at = 0.0, kind = "report", anchor = "origin" },
                { at = 0.02, kind = "ascent", anchor = "origin" },
            },
        }
        local ev = FireworkSchedule.compile(scrambled, 400)
        expect(ev[1].kind).toBe("report")
        expect(ev[2].kind).toBe("ascent")
        expect(ev[3].kind).toBe("burst")
    end)

    test("non-burst phases carry no particles", function()
        for _, e in FireworkSchedule.compile(NESTED, 400) do
            if e.kind ~= "burst" then
                expect(e.particles).toBe(0)
            end
        end
    end)

    test("sounds survive compilation", function()
        local ev = FireworkSchedule.compile(NESTED, 400)
        expect(ev[1].sound).toBe("rbxassetid://1")
        expect(ev[4].sound).toBe("rbxassetid://4")
    end)

    test("defaults fill in for a simple shell", function()
        local ev = FireworkSchedule.compile(SIMPLE, 400)
        local burst = ev[3]
        expect(burst.points).toBe(1)
        expect(burst.scatter).toBe(0)
        expect(burst.particles).toBe(400) -- the only burst gets the whole budget
    end)
end)

describe("FireworkSchedule — THE BUDGET IS PER SHELL", function()
    test("total particles across every break point never exceed the budget", function()
        -- THE LOAD-BEARING TEST. A nested shell has 7 break points; at the full near-budget each,
        -- it would cost seven times what the mobile floor was measured against — authored in good
        -- faith by someone assuming each break looks like a normal break.
        for _, budget in { 90, 250, 400 } do
            local total = 0
            for _, e in FireworkSchedule.compile(NESTED, budget) do
                total += e.particles * e.points
            end
            expect(total <= budget).toBe(true)
        end
    end)

    test("adding break points does not add particles — it divides them", function()
        -- The property the rule exists for: a shell author cannot buy fill-rate by nesting harder.
        local function cost(points: number): number
            local recipe = {
                phases = {
                    { at = 0.0, kind = "report", anchor = "origin" },
                    { at = 1.0, kind = "burst", anchor = "apex", points = points },
                },
            }
            local total = 0
            for _, e in FireworkSchedule.compile(recipe, 400) do
                total += e.particles * e.points
            end
            return total
        end
        expect(cost(12) <= cost(1)).toBe(true)
        expect(cost(1) <= 400).toBe(true)
    end)

    test("share splits the budget between burst phases", function()
        -- share 2 : share 1 over 400, with the second phase spread across 6 points.
        local ev = FireworkSchedule.compile(NESTED, 400)
        expect(ev[3].particles).toBe(266) -- floor(400 * 2/3)
        expect(ev[3].points).toBe(1)
        expect(ev[4].particles).toBe(22) -- floor(400 * 1/3 / 6)
        expect(ev[4].points).toBe(6)
    end)

    test("a break point always gets at least one particle", function()
        -- At the far LOD a heavily nested shell could round to zero and vanish silently, which
        -- reads as a bug rather than as distance.
        for _, e in FireworkSchedule.compile(NESTED, 8) do
            if e.kind == "burst" then
                expect(e.particles >= 1).toBe(true)
            end
        end
    end)

    test("a recipe with no burst phases does not divide by zero", function()
        local ev =
            FireworkSchedule.compile({ phases = { { at = 0, kind = "report", anchor = "origin" } } }, 400)
        expect(#ev).toBe(1)
        expect(ev[1].particles).toBe(0)
    end)

    test("boost and glow pass through compile untouched", function()
        local recipe = {
            phases = {
                {
                    at = 0,
                    kind = "burst",
                    anchor = "apex",
                    glow = 1.5,
                    boost = { chance = 0.3, points = 2 },
                    texture = "t",
                },
            },
        }
        local events = FireworkSchedule.compile(recipe :: any, 300)
        expect(events[1].glow).toBe(1.5)
        expect(events[1].boost ~= nil and events[1].boost.chance == 0.3).toBe(true)
    end)

    test("style passes through compile untouched", function()
        local recipe = {
            phases = {
                { at = 0, kind = "burst", anchor = "apex", style = "ring", texture = "t" },
            },
        }
        local events = FireworkSchedule.compile(recipe :: any, 300)
        expect(events[1].style).toBe("ring")
    end)

    test("A STYLE NEVER TOUCHES COST: particle totals identical with styles stripped", function()
        local styled = {
            phases = {
                { at = 0, kind = "report", anchor = "origin" },
                { at = 0.02, kind = "ascent", anchor = "origin" },
                { at = 1.0, kind = "burst", anchor = "apex", style = "ring", share = 2, texture = "t" },
                {
                    at = 1.5,
                    kind = "burst",
                    anchor = "apex",
                    style = "strobe",
                    points = 5,
                    scatter = 8,
                    share = 1,
                    texture = "t",
                },
                { at = 2.0, kind = "burst", anchor = "apex", style = "kamuro", share = 1, texture = "t" },
            },
        }
        local stripped = { phases = {} }
        for _, ph in styled.phases do
            local copy = table.clone(ph)
            copy.style = nil
            table.insert(stripped.phases, copy)
        end
        for _, budget in { 60, 300, 700 } do
            local a = FireworkSchedule.compile(styled :: any, budget)
            local b = FireworkSchedule.compile(stripped :: any, budget)
            local ta, tb = 0, 0
            for _, ev in a do
                ta += ev.particles * ev.points
            end
            for _, ev in b do
                tb += ev.particles * ev.points
            end
            expect(ta).toBe(tb)
        end
    end)
end)
