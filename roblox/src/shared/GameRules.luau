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

return GameRules
