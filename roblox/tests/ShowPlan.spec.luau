--!strict
-- The fixture IS the contract: every case shared-fixtures/shows.json defines runs against both
-- validators, so a rule that exists only on the server (or only here) fails CI instead of letting
-- the console author a show the backend refuses. The tests below the loop cover the three things
-- JSON cases cannot express -- non-finite times, the strict `>` at the duration limit, and a
-- non-table payload -- and they are deliberately the same behaviours server/src/shows.ts has.
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShowPlan = require("../src/shared/ShowPlan")
local MortarPlacement = require("../src/shared/MortarPlacement")
local fixture = require("./fixtures/shows")
local shellFixture = require("./fixtures/fireworkShells")

local known = ShowPlan.knownShellSet(shellFixture.shells)

describe("ShowPlan -- the fixture is the contract", function()
    test("LIMITS equal the fixture", function()
        expect(ShowPlan.LIMITS).toEqual(fixture.limits)
    end)
    test("DECK_SLOTS and PROVING_SLOTS equal the fixture stages", function()
        expect(ShowPlan.DECK_SLOTS).toEqual(fixture.stages.deck)
        expect(ShowPlan.PROVING_SLOTS).toEqual(fixture.stages.proving)
    end)
end)

describe("ShowPlan.validate -- every fixture case", function()
    for _, c in fixture.cases do
        test(c.name, function()
            local r = ShowPlan.validate(c.cues, fixture.stages[c.stage], MortarPlacement.SHELL_MORTAR, known)
            if c.expect == "ok" then
                expect(r.ok).toBe(true)
                expect(r.error).toBeNil()
            else
                expect(r.ok).toBe(false)
                expect(r.error).toBe(c.expect)
                if c.cue ~= nil then
                    expect(r.cue).toBe(c.cue)
                end
            end
        end)
    end
    test("TOO_MANY_CUES at maxCues + 1, and exactly maxCues is fine", function()
        local cues = {}
        for i = 1, ShowPlan.LIMITS.maxCues + 1 do
            table.insert(cues, { t_ms = (i - 1) * 10, slot = "hand", shellId = "firecracker" })
        end
        expect(ShowPlan.validate(cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe(
            "TOO_MANY_CUES"
        )
        table.remove(cues)
        expect(ShowPlan.validate(cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).ok).toBe(
            true
        )
    end)
    test("non-table input is EMPTY", function()
        expect(ShowPlan.validate(nil, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe(
            "EMPTY"
        )
        expect(ShowPlan.validate("nope", ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe(
            "EMPTY"
        )
    end)
    test("a non-finite t_ms is a BAD_CUE, not a time error", function()
        -- Number.isFinite on the TypeScript side; NaN and both infinities are malformed cues, and
        -- BAD_CUE outranks NEGATIVE_TIME, so -inf never reads as a negative time.
        local nan = 0 / 0
        for _, bad in { nan, math.huge, -math.huge } do
            local r = ShowPlan.validate(
                { { t_ms = bad, slot = "hand", shellId = "firecracker" } },
                ShowPlan.DECK_SLOTS,
                MortarPlacement.SHELL_MORTAR,
                known
            )
            expect(r.error).toBe("BAD_CUE")
            expect(r.cue).toBe(0)
        end
    end)
    test("TOO_LONG is strict: a show ending exactly at the limit is legal", function()
        local edge = ShowPlan.LIMITS.maxDurationS * 1000
        local function at(t: number)
            return ShowPlan.validate({
                { t_ms = 0, slot = "hand", shellId = "firecracker" },
                { t_ms = t, slot = "hand", shellId = "firecracker" },
            }, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known)
        end
        expect(at(edge).ok).toBe(true)
        expect(at(edge + 1).error).toBe("TOO_LONG")
    end)
    test("a slot whose stage value is not a legal shape is BAD_SLOT", function()
        -- The grammar allows only "none", "any" and "mortar:X"; a typo'd tier must be a bad slot
        -- rather than silently degrading to "any" -- the same shape check server/src/shows.ts makes.
        local r = ShowPlan.validate(
            { { t_ms = 0, slot = "deck", shellId = "firecracker" } },
            { deck = "mortars" },
            MortarPlacement.SHELL_MORTAR,
            known
        )
        expect(r.error).toBe("BAD_SLOT")
        expect(r.cue).toBe(0)
    end)
end)

describe("ShowPlan.tally", function()
    test("counts per shell id", function()
        expect(ShowPlan.tally({
            { t_ms = 0, slot = "hand", shellId = "firecracker" },
            { t_ms = 0, slot = "mortar:S", shellId = "peony" },
            { t_ms = 500, slot = "hand", shellId = "firecracker" },
        })).toEqual({ firecracker = 2, peony = 1 })
    end)
end)
