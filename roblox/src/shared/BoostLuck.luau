--!strict
-- THE PITY RAMP (owner, 2026-09-06). A flat 30% strands 1 player in 36 with nothing after
-- ten boosted shells -- and they experience it as a broken product (the owner did, same
-- day, and filed it as a bug). Each consecutive miss raises the next roll by PITY_STEP x
-- the base chance, a hit resets to the floor, and the ramp caps at certainty -- so the
-- base chance stays the recipe's honest floor, the average lifts slightly, and a drought
-- cannot outlast the ramp ("always a surprise and never a disappointment").
--
-- Pure math: the SERVER owns the state (per-player, per-shell miss streaks, session-lived)
-- and sends the verdict in the launch payload; every client renders the same luck. The
-- proving range bypasses this entirely -- auditions judge the recipe's floor, not the ramp.
local BoostLuck = {}

-- Fraction of the BASE chance added per consecutive miss. At 0.5 a 30% shell walks
-- 30 -> 45 -> 60 -> 75 -> 90 -> 100: the worst drought is five shells.
BoostLuck.PITY_STEP = 0.5

function BoostLuck.chanceFor(base: number, misses: number): number
    return math.min(1, base * (1 + BoostLuck.PITY_STEP * misses))
end

-- One launch's verdict. `roll01` is the caller's uniform [0,1) draw, passed in so this
-- stays pure and testable. Returns the verdict and the streak to store.
function BoostLuck.roll(base: number, misses: number, roll01: number): (boolean, number)
    local boosted = roll01 < BoostLuck.chanceFor(base, misses)
    return boosted, if boosted then 0 else misses + 1
end

-- The recipe's floor: the first boost-carrying phase's chance (the shell-level roll keys
-- off exactly that phase on the client). nil = the recipe has no luck to ramp.
function BoostLuck.baseChance(recipe: any): number?
    if typeof(recipe) ~= "table" or typeof(recipe.phases) ~= "table" then
        return nil
    end
    for _, ph in recipe.phases :: { any } do
        if typeof(ph) == "table" and typeof(ph.boost) == "table" then
            return ph.boost.chance
        end
    end
    return nil
end

return BoostLuck
