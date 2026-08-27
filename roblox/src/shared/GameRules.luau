--!strict
-- Luau mirror of server/src/engine/GameRules.ts. The shared JSON fixtures are
-- the contract; if you change one side, the other side's CI fails.
local GameRules = {}

export type Throw = "R" | "P" | "S"
export type RoundResult = "WIN" | "SAFE" | "LOSS"

local BEATS: { [string]: string } = { R = "S", P = "R", S = "P" }

function GameRules.calculateResult(player: Throw, world: Throw): RoundResult
    if player == world then
        return "SAFE"
    end
    return if BEATS[player] == world then "WIN" else "LOSS"
end

-- Pot math: 0 -> 1 -> 3 -> 9 -> 27 ... (3^n). SAFE preserves the pot; LOSS forfeits it.
function GameRules.nextPot(currentPot: number, result: RoundResult): number
    if result == "WIN" then
        return if currentPot == 0 then 1 else currentPot * 3
    end
    if result == "LOSS" then
        return 0
    end
    return currentPot
end

-- On WIN the delta is the NEW pot value (not the increment); LOSS is -old pot; SAFE is 0.
function GameRules.potDelta(currentPot: number, result: RoundResult): number
    if result == "WIN" then
        return GameRules.nextPot(currentPot, "WIN")
    end
    if result == "LOSS" then
        return if currentPot == 0 then 0 else -currentPot
    end
    return 0
end

-- Streaks survive only on WIN.
function GameRules.nextStreak(currentStreak: number, result: RoundResult): number
    return if result == "WIN" then currentStreak + 1 else 0
end

-- PARTIAL BANKING: a pot may be dropped to a LOWER RUNG, banking the difference. Rungs rather
-- than a slider so every pot stays a power of three and every banked difference is an integer.
-- Returns every ladder value strictly below `pot`, ascending, 0 first; 0 is the full bank.
--
-- Mirrors server/src/engine/GameRules.ts. Both are held to shared-fixtures/game-rules.json, so
-- drift fails CI rather than being a promise.
function GameRules.keepOptions(pot: number): { number }
    -- `pot ~= pot` is the NaN test; Luau has no isNaN.
    if pot ~= pot or pot == math.huge or pot <= 0 then
        return {}
    end
    local options = { 0 }
    local rung = 1
    while rung < pot do
        table.insert(options, rung)
        rung *= 3
    end
    return options
end

function GameRules.isValidKeep(pot: number, keep: number): boolean
    -- ⚠ DEFENCE, NOT THE FRACTIONAL CHECK THAT ACTUALLY BITES -- no rung is ever fractional, so
    -- the scan below already rejects 13.5. Mutation testing showed the TS twin's equivalent line
    -- is unreachable; this one is kept for the same reason, and the fixture does not prove it.
    if keep % 1 ~= 0 then
        return false
    end
    for _, option in GameRules.keepOptions(pot) do
        if option == keep then
            return true
        end
    end
    return false
end

-- A `keep` arriving from a CLIENT (the BankRequest RemoteEvent) rather than from our own code.
-- Returns the sanitised value, or nil meaning REFUSE THE REQUEST.
--
-- ⚠ MALFORMED MUST NOT BECOME 0. `keep = 0` is a FULL bank, so coercing junk to 0 would cash out
-- a player's whole pot because their client sent something odd. Absent IS 0 — the bank button
-- fires with no argument and that is a full bank, exactly as it was before partial banking.
--
-- The TS transports get the same semantics from `Number(x ?? 0)`: absent coerces to 0, garbage
-- coerces to NaN, and `isValidKeep` rejects NaN. This function is the Luau-side equivalent, and
-- is deliberately not mirrored in `GameRules.ts` — there is no RemoteEvent on that side.
function GameRules.keepFromWire(value: any): number?
    if value == nil then
        return 0
    end
    if typeof(value) ~= "number" then
        return nil
    end
    -- ⚠ BELT AND BRACES, AND THE FIXTURE DOES NOT PROVE IT. `value ~= value` is the NaN test and
    -- math.huge would serialise as invalid JSON -- but the `% 1` check below already rejects both,
    -- because `NaN % 1` and `math.huge % 1` are each NaN and so are `~= 0`. Mutation testing showed
    -- this block can be deleted with every test still green. It stays because relying on that
    -- emergent behaviour is subtler than saying what we mean; do not read the tests as covering it.
    if value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    if value < 0 or value % 1 ~= 0 then
        return nil
    end
    return value
end

return GameRules
