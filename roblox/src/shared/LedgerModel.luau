--!strict
-- Maximal-panel ("the ledger") view model. Pure arithmetic over the persisted counters.
--
-- GameRules is INJECTED rather than required, both because shared modules never require each
-- other and because the "a win here pays N" figure must track the real pot progression. A
-- hardcoded ×3 here would silently lie the day the progression changes.
local LedgerModel = {}

export type Counters = {
    roundsPlayed: number,
    wins: number,
    safes: number,
    losses: number,
    lifetimeBanked: number,
    bestPot: number,
    throwsR: number,
    throwsP: number,
    throwsS: number,
}
export type Live = { pot: number, streak: number, points: number }

-- Largest-remainder apportionment. Rounding three shares independently leaves them summing to
-- 99 or 101, which shows as a gap or an overrun in a segmented bar. This distributes the
-- rounding error to the largest fractional parts so the total is always exactly 100.
local function shares(parts: { number }): { number }
    local total = 0
    for _, p in parts do
        total += p
    end
    local out = {}
    if total <= 0 then
        for i = 1, #parts do
            out[i] = 0
        end
        return out
    end
    local floors, remainders, sum = {}, {}, 0
    for i, p in parts do
        local exact = p / total * 100
        floors[i] = math.floor(exact)
        remainders[i] = { i = i, r = exact - floors[i] }
        sum += floors[i]
    end
    table.sort(remainders, function(a, b)
        if a.r == b.r then
            return a.i < b.i -- stable: never let equal remainders reorder run to run
        end
        return a.r > b.r
    end)
    local leftover = 100 - sum
    for k = 1, leftover do
        floors[remainders[k].i] += 1
    end
    for i = 1, #parts do
        out[i] = floors[i]
    end
    return out
end

function LedgerModel.view(counters: Counters, live: Live, rules: any)
    local bar = shares({ counters.wins, counters.safes, counters.losses })
    local mix = shares({ counters.throwsR, counters.throwsP, counters.throwsS })
    return {
        paysNext = rules.nextPot(live.pot, "WIN"),
        winRatePct = if counters.roundsPlayed > 0
            then math.round(counters.wins / counters.roundsPlayed * 100)
            else 0,
        bar = { win = bar[1], safe = bar[2], loss = bar[3] },
        mix = { R = mix[1], P = mix[2], S = mix[3] },
        lifetime = counters,
        live = live,
    }
end

return LedgerModel
