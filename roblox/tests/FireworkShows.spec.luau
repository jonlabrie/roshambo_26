--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkShows = require("../src/shared/FireworkShows")
local ShowPlan = require("../src/shared/ShowPlan")
local ProvingPlan = require("../src/shared/ProvingPlan")
local MortarPlacement = require("../src/shared/MortarPlacement")
local shellFixture = require("./fixtures/fireworkShells")

local known = ShowPlan.knownShellSet(shellFixture.shells)

describe("FireworkShows -- every draft is a valid proving-stage show", function()
    test("ORDER names every draft exactly once", function()
        local seen = {}
        for _, name in FireworkShows.ORDER do
            expect(FireworkShows.DRAFTS[name]).toBeTruthy()
            expect(seen[name]).toBeNil()
            seen[name] = true
        end
        local n = 0
        for _ in FireworkShows.DRAFTS do
            n += 1
        end
        expect(#FireworkShows.ORDER).toBe(n)
    end)
    for name, draft in FireworkShows.DRAFTS do
        test(`{name} validates against PROVING_SLOTS with shipped shells only`, function()
            local r =
                ShowPlan.validate(draft.cues, ShowPlan.PROVING_SLOTS, MortarPlacement.SHELL_MORTAR, known)
            expect(r.ok).toBe(true)
        end)
        test(`{name} uses only real stations`, function()
            local racks = {}
            for _, r in ProvingPlan.RACKS do
                racks[r] = true
            end
            for _, c in draft.cues do
                expect(racks[c.slot]).toBe(true)
            end
        end)
    end
    test("finale_v1 is LARGE: it exists to stress the director", function()
        local f = FireworkShows.DRAFTS.finale_v1
        expect(#f.cues >= 80).toBe(true)
        -- at least one moment with six cues inside 300 ms -- a real volley, not a metronome
        local best = 0
        for i, c in f.cues do
            local n = 0
            for j = i, #f.cues do
                if f.cues[j].t_ms - c.t_ms <= 300 then
                    n += 1
                end
            end
            best = math.max(best, n)
        end
        expect(best >= 6).toBe(true)
    end)
end)
