--!strict
local harness = require("./harness")
local Choreo = require("../src/shared/ChoreographyMachine")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function fixedSelect(slot: string, ctx: any): string?
    if slot == "LOSS" then
        return "fate" .. ctx.worldThrow
    end
    return slot:lower()
end

local OPTS = {
    staggerMaxMs = 600,
    random = function()
        return 0.5
    end,
    selectEffect = fixedSelect,
}

describe("ChoreographyMachine.phaseCues", function()
    test("REVEAL cues", function()
        expect(Choreo.phaseCues("REVEAL")).toEqual({})
    end)

    test("OPEN carries the ambient cues", function()
        expect(Choreo.phaseCues("OPEN")).toEqual({
            "lanternsAmbient",
            "hammerReset",
            "tickerCountdown",
        })
    end)

    test("LOCK carries the wind-up cues", function()
        expect(Choreo.phaseCues("LOCK")).toEqual({
            "lanternsDim",
            "drumrollStart",
            "heroTileSpin",
            "tickerCascade",
        })
    end)

    test("the retired names cue nothing", function()
        expect(#Choreo.phaseCues("ACTIVE")).toBe(0)
        expect(#Choreo.phaseCues("TALLY")).toBe(0)
    end)
end)

describe("ChoreographyMachine.revealCues", function()
    local reveal = {
        worldThrow = "S",
        results = { ["9"] = { result = "WIN", pick = "R" }, ["10"] = { result = "LOSS", pick = "P" } },
        whiffed = { ["11"] = true },
    }

    test("base cues fire at t=0 and consequences are staggered", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        expect(cues[1].atMs).toBe(0)
        local kinds = {}
        for _, c in cues do
            if c.atMs == 0 then
                table.insert(kinds, c.kind)
            end
        end
        expect(kinds).toEqual({ "drumrollStop", "basinErupt", "heroTileLand" })
    end)

    test("each participant gets one consequence cue with the selected effect", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        local byUser = {}
        for _, c in cues do
            if c.kind == "consequence" then
                byUser[c.userId] = c
            end
        end
        expect(byUser["9"].effect).toBe("win")
        expect(byUser["10"].effect).toBe("fateS")
        expect(byUser["9"].atMs).toBe(300) -- random 0.5 * 600
    end)

    test("whiffed users get a whiffToast cue", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        local found = false
        for _, c in cues do
            if c.kind == "whiffToast" and c.userId == "11" then
                found = true
            end
        end
        expect(found).toBe(true)
    end)

    test("cues are sorted by atMs", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        for i = 2, #cues do
            expect(cues[i].atMs >= cues[i - 1].atMs).toBe(true)
        end
    end)

    test("heroTileLand carries the world throw", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        for _, c in cues do
            if c.kind == "heroTileLand" then
                expect(c.worldThrow).toBe("S")
            end
        end
    end)
end)
