--!strict
-- Minimal-HUD view model. Pure: no Roblox globals, no I/O, so it runs under Lune.
--
-- The escalation rule is the delicate part. Roshambo is an ambient game — most people in the
-- canyon at any moment are not playing, they are hanging out. An ungated "CHOOSE A THROW" alarm
-- would fire at them every single round, forever, and turn the calmest part of the game into an
-- alarm clock.
--
-- The rule is a UNIFORM backoff: anyone stays armed for three consecutive ignored rounds, then
-- goes silent, and re-arms the instant they throw again. "New arrival", "threw last round" and
-- "pot riding" describe who STARTS armed — a fresh session has zero misses — but they are not
-- ongoing conditions, so they do not appear here. An earlier draft carried them as live OR-terms
-- and a player who threw, won nothing and missed once fell out of the OR: the prompt died after
-- ONE miss instead of three, giving the most common case the least grace.
--
-- A round only counts as ignored if the player COULD have thrown. Rounds spent fate-bound are not
-- misses — the player was prevented, not inattentive. Counting them would disarm the prompt for
-- exactly the player who was held out of the round.
local HudModel = {}

local ESCALATE_AT = 5 -- seconds remaining
local BACKOFF_MISSES = 3

export type Session = { consecutiveMisses: number }

export type Inputs = {
    phase: string,
    secondsLeft: number,
    pointsAtStake: number,
    currentStreak: number,
    totalPoints: number,
    unresolvedWin: boolean,
    fateBound: boolean,
    pickedThisRound: boolean,
    escalationPrompts: boolean,
}

export type View = {
    plate: { streak: number, pot: number, points: number },
    throwsEnabled: boolean,
    slot: string, -- "pot" | "fate" | "none"
    potPulses: boolean,
    escalate: boolean,
    secondsLeft: number,
}

function HudModel.newSession(): Session
    return { consecutiveMisses = 0 }
end

function HudModel.view(inputs: Inputs, session: Session): View
    -- Only a FATE blocks a throw. An unacknowledged win does not: throwing again IS riding,
    -- which is why there is no RISK button and nothing to resolve. Server-enforced either way;
    -- this only mirrors it so the UI can dim.
    local blocked = inputs.fateBound
    local throwsEnabled = inputs.phase == "ACTIVE"
        and inputs.secondsLeft > 0
        and not blocked
        and not inputs.pickedThisRound

    -- One slot above the throw row, two possible tenants. A LOSS forfeits the pot, so
    -- pointsAtStake is always 0 while fate-bound and these cannot really coexist -- but fate
    -- takes precedence defensively, because the wrong tenant here would hide the only way out.
    -- Neither is gated on phase: an unbanked pot outlives the round, the session and a week away.
    local slot: string = if inputs.fateBound then "fate" elseif inputs.pointsAtStake > 0 then "pot" else "none"

    local armed = inputs.escalationPrompts
        and not blocked
        and inputs.phase == "ACTIVE"
        and not inputs.pickedThisRound
        and session.consecutiveMisses < BACKOFF_MISSES

    return {
        plate = {
            streak = inputs.currentStreak,
            pot = inputs.pointsAtStake,
            points = inputs.totalPoints,
        },
        throwsEnabled = throwsEnabled,
        slot = slot,
        -- unresolvedWin's only remaining job: "the last scored round was a WIN and the player has
        -- not banked since". It drives the pulse and nothing else.
        potPulses = slot == "pot" and inputs.unresolvedWin,
        escalate = armed and inputs.secondsLeft > 0 and inputs.secondsLeft <= ESCALATE_AT,
        secondsLeft = inputs.secondsLeft,
    }
end

function HudModel.onRoundEnded(session: Session, outcome: { couldThrow: boolean, picked: boolean }): Session
    if outcome.picked then
        return { consecutiveMisses = 0 }
    end
    if not outcome.couldThrow then
        -- prevented, not inattentive — carry the count forward untouched
        return { consecutiveMisses = session.consecutiveMisses }
    end
    return { consecutiveMisses = session.consecutiveMisses + 1 }
end

return HudModel
