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

-- How much of the countdown an unconfirmed selection is given back before it is thrown anyway. It is
-- NOT zero: the pick has to travel client -> SubmitPick -> ThrowBuffer and be flushed before the
-- server's lockout, and `secondsLeft` reaching zero IS the lockout. Half a second is the slack for
-- that trip, and it costs a player who was about to tap almost nothing.
local AUTO_COMMIT_AT = 0.5 -- seconds remaining

export type Session = { consecutiveMisses: number }

export type Inputs = {
    phase: string,
    secondsLeft: number,
    pointsAtStake: number,
    currentStreak: number,
    totalPoints: number,
    unresolvedWin: boolean,
    fateBound: boolean,
    -- "HAS A COMMITTED PICK RIGHT NOW", not "has tapped". A player who releases their confirmation
    -- (see tapAction) goes back to false, because the server no longer holds anything they still
    -- stand behind.
    pickedThisRound: boolean,
    escalationPrompts: boolean,
    -- The confirm-a-throw preference (default ON) and the glyph the player is currently standing on.
    -- `selectedThrow` OUTLIVES the commit: it is what a release falls back to, and what the lockout
    -- throws.
    confirmThrows: boolean,
    selectedThrow: string?,
}

export type View = {
    plate: { streak: number, pot: number, points: number },
    throwsEnabled: boolean,
    slot: string, -- "pot" | "fate" | "none"
    potPulses: boolean,
    escalate: boolean,
    secondsLeft: number,
    -- The glyph to light as the player's current choice, and the two things the confirm strip can
    -- say about it. All three come apart:
    --   confirmPending : chosen but NOT thrown — the strip asks for the second tap.
    --   releasable     : thrown, and still changeable — the strip says so.
    -- Banking mid-selection ends the REQUIREMENT to confirm without ending the SELECTION, so
    -- `selected` can be set with neither flag up (see confirmRequired).
    selected: string?,
    confirmPending: boolean,
    releasable: boolean,
}

-- WHEN A THROW HAS TO BE CONFIRMED. Only when there is a pot: the owner's "especially if there's
-- points riding on the throw" read as the CONDITION rather than as emphasis. Roshambo is an ambient
-- hangout and most throws in the canyon cost nothing; making every one of those a two-tap ritual
-- would tax the calm case to protect the rare one. A mis-tap only costs something when there is
-- something at stake, and that is exactly when this is on.
function HudModel.confirmRequired(inputs: Inputs): boolean
    return inputs.confirmThrows ~= false and inputs.pointsAtStake > 0
end

-- Only a FATE blocks a throw outright. An unacknowledged win does not: throwing again IS riding,
-- which is why there is no RISK button and nothing to resolve. Server-enforced either way; this only
-- mirrors it so the UI can dim. Factored out because the confirm rule needs the same answer as
-- `view`, and two copies of it would be two places to forget the fate.
--
-- A COMMITTED PICK NO LONGER CLOSES THE ROUND. Nothing is final until the lockout (owner's ruling):
-- while confirmation is in play the tiles have to stay live, because tapping the lit glyph is how a
-- confirmation is released and tapping another is how it is moved. Without confirmation there is no
-- release gesture to make, so a commit is the end of it, exactly as before.
local function throwsEnabledFor(inputs: Inputs): boolean
    if inputs.phase ~= "ACTIVE" or inputs.secondsLeft <= 0 or inputs.fateBound then
        return false
    end
    if not inputs.pickedThisRound then
        return true
    end
    return HudModel.confirmRequired(inputs)
end

-- What a tap on `symbol` does:
--   "commit"  — throw it (the ONLY action that talks to the server)
--   "select"  — light it and wait for the second tap; drops any confirmation that was standing
--   "release" — take the confirmation back, LEAVING the glyph selected
--   "ignore"  — the round cannot take a throw at all
--
-- A tap on a DIFFERENT glyph moves the selection rather than committing — a player correcting a
-- mis-tap must not have the correction itself count as the confirmation, which would make the second
-- tap of every correction throw the wrong-then-right glyph in one motion and defeat the whole thing.
--
-- "release" NEVER EMPTIES THE SELECTION. It is only ever returned for the glyph that is already
-- selected, so the lockout always still has something to send, and that send overwrites whatever the
-- server last received (the throw buffer upserts per player, seq-guarded). A release that returned
-- the player to "nothing chosen" would leave the earlier pick standing on the server with nothing on
-- screen saying so — the one failure this feature could introduce.
function HudModel.tapAction(inputs: Inputs, symbol: string): string
    if not throwsEnabledFor(inputs) then
        return "ignore"
    end
    if not HudModel.confirmRequired(inputs) then
        return "commit"
    end
    if inputs.selectedThrow ~= symbol then
        return "select"
    end
    if inputs.pickedThisRound then
        return "release"
    end
    return "commit"
end

-- The selection that must be thrown NOW rather than lost, or nil.
--
-- Owner's decision, and the reason this exists at all: a player who tapped a glyph clearly meant to
-- throw it, and losing a round to a missed second tap reads as broken. The confirm guards a mis-tap;
-- it must never cost a round.
--
-- Deliberately NOT gated on `confirmRequired`. Banking mid-round removes the requirement but not the
-- selection, and dropping it there would silently cost exactly the round the player was mid-decision
-- on. A fate arriving mid-round DOES drop it: the server will refuse that pick whatever we do, and
-- lighting a tile the server threw away is a lie.
function HudModel.autoCommit(inputs: Inputs): string?
    local selected = inputs.selectedThrow
    if selected == nil or inputs.pickedThisRound or inputs.fateBound then
        return nil
    end
    if inputs.phase ~= "ACTIVE" then
        -- The round moved on with a selection still pending — the unsynced-clock path never reaches
        -- the boundary below, because its countdown is a constant. Last chance: the server may
        -- refuse it as PICKS_CLOSED, and the whiff toast then says so honestly. Trying and being
        -- told beats never trying.
        return selected
    end
    if inputs.secondsLeft > AUTO_COMMIT_AT then
        return nil
    end
    return selected
end

function HudModel.newSession(): Session
    return { consecutiveMisses = 0 }
end

function HudModel.view(inputs: Inputs, session: Session): View
    local blocked = inputs.fateBound
    local throwsEnabled = throwsEnabledFor(inputs)

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

    -- A selection only exists while the round could still take it: it is cleared by the round
    -- closing and by a fate, both of which throwsEnabled already covers. It is NOT cleared by the
    -- pick landing — a committed pick stays lit and stays changeable while confirmation is in play,
    -- and once it is not, throwsEnabled has gone false anyway and the controller lights the
    -- authoritative pick instead.
    local selected = if throwsEnabled then inputs.selectedThrow else nil

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
        selected = selected,
        -- Pending means CHOSEN BUT NOT THROWN. A committed pick is not pending — the strip must
        -- never say "TAP AGAIN TO THROW" about something that has already gone.
        confirmPending = selected ~= nil and not inputs.pickedThisRound and HudModel.confirmRequired(inputs),
        -- Thrown, and still takeable back. throwsEnabled already encodes "committed AND confirmation
        -- is in play", so this needs no second copy of that rule.
        releasable = throwsEnabled and inputs.pickedThisRound,
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
