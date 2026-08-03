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
    -- The glyph the player has chosen this round, the glyph currently carrying a SWITCH?
    -- prompt, and whether the pick has gone over the wire. `chosen` is the player's
    -- commitment; `sent` is the wire's. They are separate because the pick is held locally
    -- until the lockout, which is the only thing that makes a back-out honest.
    chosen: string?,
    switchPrompt: string?,
    sent: boolean,
    declinedThisRound: boolean,
}

export type View = {
    plate: { streak: number, pot: number, points: number },
    throwsEnabled: boolean,
    slot: string, -- "pot" | "fate" | "none"
    potPulses: boolean,
    escalate: boolean,
    secondsLeft: number,
    -- The glyph to light as the player's current choice.
    selected: string?,
}

-- Four seconds. A prompt is a question, and an unanswered question must not sit on screen
-- indefinitely — but note the expiry is safe in BOTH directions: expiring restores exactly the
-- state before the stray tap, and answering only ever unlocks. Neither outcome throws anything.
HudModel.SWITCH_PROMPT_SECONDS = 4

-- The round takes taps for the whole of ACTIVE. There is deliberately no "you have committed,
-- so the round is closed to you" state: that state is what made backing out impossible, and
-- backing out is now the point.
local function throwsEnabledFor(inputs: Inputs): boolean
    return inputs.phase == "ACTIVE" and inputs.secondsLeft > 0
end

export type TapState = { chosen: string?, switchPrompt: string? }

-- What a tap on `symbol` does. Evaluated top to bottom; first match wins.
--
--   "choose" — light it; the throw is chosen (locally — see sendAtLockout)
--   "prompt" — raise SWITCH? over `symbol`, moving it if it was elsewhere
--   "clear"  — all three available again, NOTHING chosen. This is the back-out.
--   "ignore" — the round cannot take a throw, or the tap lands on the lit glyph
--
-- TAPPING THE LIT GLYPH DOES NOTHING (owner's ruling). The switch path is the only way out, so
-- there is exactly one gesture to learn. A lit glyph that also un-chose would give one button
-- two meanings depending on invisible state.
--
-- CONFIRMING A SWITCH UNLOCKS; IT DOES NOT SELECT. That is the whole reason a back-out exists:
-- a confirm-that-also-selects would leave no way to end a round having chosen nothing.
function HudModel.tapAction(inputs: Inputs, symbol: string): string
    if not throwsEnabledFor(inputs) then
        return "ignore"
    end
    if inputs.chosen == nil then
        return "choose"
    end
    if symbol == inputs.chosen then
        return "ignore"
    end
    if symbol == inputs.switchPrompt then
        return "clear"
    end
    return "prompt"
end

-- The state transition for a `tapAction` result. In here rather than inline in the controller
-- so the table is enforced in ONE place a future edit has to touch, and pinned by the
-- exhaustive test in HudModel.spec.luau.
--
-- Pure: the controller still owns the side effects (publishing, the wire) — this computes the
-- two fields and nothing else.
function HudModel.applyTap(state: TapState, action: string, symbol: string): TapState
    if action == "choose" then
        return { chosen = symbol, switchPrompt = nil }
    elseif action == "prompt" then
        return { chosen = state.chosen, switchPrompt = symbol }
    elseif action == "clear" then
        return { chosen = nil, switchPrompt = nil }
    end
    return { chosen = state.chosen, switchPrompt = state.switchPrompt }
end

-- Whether a standing prompt has aged out. A predicate rather than a timer so it is pure and
-- testable; main.client's existing 10Hz heartbeat is what calls it, which is ample resolution
-- for a four-second question.
function HudModel.switchPromptExpired(setAt: number?, now: number): boolean
    return setAt ~= nil and (now - setAt) >= HudModel.SWITCH_PROMPT_SECONDS
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
        selected = inputs.selectedThrow,
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
