--!strict
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local harness = require("./harness")
local GameRules = require("../src/shared/GameRules")
local describe, test, expect = harness.describe, harness.test, harness.expect

local fixtures = serde.decode("json", fs.readFile("../shared-fixtures/game-rules.json"))

describe("GameRules (shared fixtures)", function()
    for _, row in fixtures.matchups do
        test(`{row.player} vs world {row.world} -> {row.result}`, function()
            expect(GameRules.calculateResult(row.player, row.world)).toBe(row.result)
        end)
    end

    for _, row in fixtures.potProgression do
        test(`pot {row.currentPot} + {row.result} -> pot {row.nextPot}, delta {row.delta}`, function()
            expect(GameRules.nextPot(row.currentPot, row.result)).toBe(row.nextPot)
            expect(GameRules.potDelta(row.currentPot, row.result)).toBe(row.delta)
        end)
    end

    for _, row in fixtures.streakRules do
        test(`streak {row.currentStreak} + {row.result} -> {row.nextStreak}`, function()
            expect(GameRules.nextStreak(row.currentStreak, row.result)).toBe(row.nextStreak)
        end)
    end

    for _, row in fixtures.partialBank do
        test(`pot {row.pot} may be dropped to {#row.keepOptions} rung(s)`, function()
            local got = GameRules.keepOptions(row.pot)
            expect(#got).toBe(#row.keepOptions)
            for i, want in row.keepOptions do
                expect(got[i]).toBe(want)
            end
            for _, keep in row.keepOptions do
                expect(GameRules.isValidKeep(row.pot, keep)).toBe(true)
            end
        end)
    end

    for _, row in fixtures.partialBankRejects do
        test(`pot {row.pot} rejects keep {row.keep}`, function()
            expect(GameRules.isValidKeep(row.pot, row.keep)).toBe(false)
        end)
    end
end)

describe("GameRules.keepFromWire", function()
    -- ⚠ THE FAILURE DIRECTION IS THE WHOLE POINT. `keep = 0` means BANK EVERYTHING, so coercing a
    -- malformed value to 0 would cash out a player's entire pot because their client sent junk.
    -- Absent is 0 (the bank button sends nothing, and that is a full bank, exactly as before);
    -- anything present but malformed REFUSES. The TS transports get the same semantics for free
    -- from `Number(x ?? 0)` — absent coerces to 0, garbage coerces to NaN and isValidKeep rejects it.
    test("absent means a FULL bank, because that is what the bank button sends", function()
        expect(GameRules.keepFromWire(nil)).toBe(0)
    end)

    test("a non-negative integer passes through untouched", function()
        expect(GameRules.keepFromWire(0)).toBe(0)
        expect(GameRules.keepFromWire(9)).toBe(9)
        expect(GameRules.keepFromWire(27)).toBe(27)
    end)

    test("⚠ anything malformed REFUSES rather than defaulting to a full bank", function()
        for _, junk in { -1, 13.5, "9", "", true, {}, 0 / 0, math.huge } do
            expect(GameRules.keepFromWire(junk)).toBe(nil)
        end
    end)
end)
