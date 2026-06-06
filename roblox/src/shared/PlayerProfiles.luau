--!strict
-- Wallet cache for players in this instance. Local results are OPTIMISTIC
-- (theater); the deferred reconciliation rows from /instances/.../results are
-- authoritative and overwrite via applyServer (spec §4).
local PlayerProfiles = {}
PlayerProfiles.__index = PlayerProfiles

export type Row = {
    totalPoints: number,
    pointsAtStake: number,
    currentStreak: number,
    stakingStreak: number,
    bestStreak: number,
}

function PlayerProfiles.new(rules: any)
    return setmetatable({ _rules = rules, _rows = {} :: { [string]: Row } }, PlayerProfiles)
end

function PlayerProfiles.applyServer(self: any, userId: string, row: Row)
    self._rows[userId] = {
        totalPoints = row.totalPoints,
        pointsAtStake = row.pointsAtStake,
        currentStreak = row.currentStreak,
        stakingStreak = row.stakingStreak,
        bestStreak = row.bestStreak,
    }
end

function PlayerProfiles.applyLocalResult(self: any, userId: string, result: string)
    local row = self._rows[userId]
    if not row then
        return
    end
    row.pointsAtStake = self._rules.nextPot(row.pointsAtStake, result)
    row.currentStreak = self._rules.nextStreak(row.currentStreak, result)
    row.stakingStreak = self._rules.nextStreak(row.stakingStreak, result)
    row.bestStreak = math.max(row.bestStreak, row.currentStreak)
end

function PlayerProfiles.get(self: any, userId: string): Row?
    return self._rows[userId]
end

return PlayerProfiles
