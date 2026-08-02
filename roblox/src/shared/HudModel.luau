--!strict
-- Minimal-HUD view model. Pure: no Roblox globals, no I/O, so it runs under Lune.
--
-- The escalation rule is the delicate part. Roshambo is an ambient game — most people in the
-- canyon at any moment are not playing, they are hanging out. An ungated "CHOOSE A THROW" alarm
-- would fire at them every single round, forever, and turn the calmest part of the game into an
-- alarm clock. So the prompt ARMS generously (a new arrival, someone who threw last round, or
-- anyone with a pot riding) and DISARMS itself after three consecutive ignored rounds.
--
-- Crucially, a round only counts as ignored if the player COULD have thrown. Rounds spent
-- win-bound or fate-bound are not misses — the player was prevented, not inattentive. Counting
-- them would disarm the prompt for exactly the player who was stuck on a decision.
local HudModel = {}

local ESCALATE_AT = 5 -- seconds remaining
local BACKOFF_MISSES = 3

export type Session = {
    hasThrownThisSession: boolean,
    threwLastRound: boolean,
    consecutiveMisses: number,
}

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
    choiceUp: boolean,
    escalate: boolean,
    secondsLeft: number,
}

function HudModel.newSession(): Session
    return { hasThrownThisSession = false, threwLastRound = false, consecutiveMisses = 0 }
end

function HudModel.view(inputs: Inputs, session: Session): View
    -- Win-bound and fate-bound are both server-enforced; this only mirrors them so the UI can
    -- dim. The server is what actually refuses the pick.
    local bound = inputs.unresolvedWin or inputs.fateBound
    local throwsEnabled = inputs.phase == "ACTIVE"
        and inputs.secondsLeft > 0
        and not bound
        and not inputs.pickedThisRound

    -- The choice has no expiry: it survives the round, the session, and a week away. It is NOT
    -- gated on phase for that reason.
    local choiceUp = inputs.unresolvedWin

    local armed = inputs.escalationPrompts
        and not bound
        and inputs.phase == "ACTIVE"
        and not inputs.pickedThisRound
        and session.consecutiveMisses < BACKOFF_MISSES
        and (
            not session.hasThrownThisSession -- a new arrival, who needs the prompt most
            or session.threwLastRound -- actively playing
            or inputs.pointsAtStake > 0 -- something on the line
        )

    return {
        plate = {
            streak = inputs.currentStreak,
            pot = inputs.pointsAtStake,
            points = inputs.totalPoints,
        },
        throwsEnabled = throwsEnabled,
        choiceUp = choiceUp,
        escalate = armed and inputs.secondsLeft > 0 and inputs.secondsLeft <= ESCALATE_AT,
        secondsLeft = inputs.secondsLeft,
    }
end

function HudModel.onRoundEnded(session: Session, outcome: { couldThrow: boolean, picked: boolean }): Session
    if outcome.picked then
        return { hasThrownThisSession = true, threwLastRound = true, consecutiveMisses = 0 }
    end
    if not outcome.couldThrow then
        -- prevented, not inattentive — carry the session forward untouched
        return {
            hasThrownThisSession = session.hasThrownThisSession,
            threwLastRound = session.threwLastRound,
            consecutiveMisses = session.consecutiveMisses,
        }
    end
    return {
        hasThrownThisSession = session.hasThrownThisSession,
        threwLastRound = false,
        consecutiveMisses = session.consecutiveMisses + 1,
    }
end

return HudModel
