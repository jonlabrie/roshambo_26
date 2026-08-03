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
-- ONE miss instead of three, giving the most common case the least grace. A deliberate back-out
-- also counts as an answer, not a miss: it silences the prompt for the rest of the round without
-- touching the backoff count, because the player plainly saw the question and answered it.
--
-- A round only counts as ignored if the player COULD have thrown. Rounds where the player was
-- prevented from throwing are not misses — the player was held out, not inattentive. Counting
-- them would disarm the prompt for exactly the player who was prevented.
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
    escalationPrompts: boolean,
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
    plate: { streak: number, points: number },
    throwsEnabled: boolean,
    -- The pot's own control. It is a button, not a readout: the figure belongs IN the thing
    -- that acts on it, which is why the plate no longer carries a pot at all.
    bankVisible: boolean,
    pot: number,
    potPulses: boolean,
    escalate: boolean,
    secondsLeft: number,
    chosen: string?,
    switchPrompt: string?,
}

-- Four seconds. A prompt is a question, and an unanswered question must not sit on screen
-- indefinitely — but note the expiry is safe in BOTH directions: expiring restores exactly the
-- state before the stray tap, and answering only ever unlocks. Neither outcome throws anything.
HudModel.SWITCH_PROMPT_SECONDS = 4

-- Taps stay live for as long as the choice can still be honoured. That is NOT the whole of
-- ACTIVE: it ends the moment the pick goes on the wire (`sendAtLockout`, roughly the last
-- half-second), because ThrowBuffer has no removal — no undo in the buffer, the delta, or
-- POST /api/v1/throws — so a tap we cannot honour is worse than a tap we refuse. Everything
-- before that moment is still open, which is what makes backing out possible at all.
local function throwsEnabledFor(inputs: Inputs): boolean
    return inputs.phase == "ACTIVE" and inputs.secondsLeft > 0 and not inputs.sent
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

-- The chosen glyph, if this is the moment it has to go over the wire, or nil.
--
-- ONE TRIP PER ROUND. The pick is held client-side until here because ThrowBuffer is
-- upsert-only — there is no removal in the buffer, in the delta, or in POST /api/v1/throws —
-- so sending on the first tap would make backing out a lie. `secondsLeft` is
-- secondsToLockout, so zero IS the lockout; half a second is the slack for the
-- client -> SubmitPick -> ThrowBuffer trip that the buffer's own lockout flush then carries.
local SEND_AT = 0.5

function HudModel.sendAtLockout(inputs: Inputs): string?
    local chosen = inputs.chosen
    if chosen == nil or inputs.sent then
        return nil
    end
    if inputs.phase ~= "ACTIVE" then
        return chosen
    end
    if inputs.secondsLeft > SEND_AT then
        return nil
    end
    return chosen
end

function HudModel.newSession(): Session
    return { consecutiveMisses = 0 }
end

function HudModel.view(inputs: Inputs, session: Session): View
    local throwsEnabled = throwsEnabledFor(inputs)

    -- A round only nags someone who has not answered it. `chosen` is the answer; a deliberate
    -- back-out (`declinedThisRound`) is ALSO an answer, and re-nagging the player who just
    -- withdrew is exactly wrong — they are demonstrably paying attention.
    local armed = inputs.escalationPrompts
        and not inputs.declinedThisRound
        and inputs.phase == "ACTIVE"
        and inputs.chosen == nil
        and session.consecutiveMisses < BACKOFF_MISSES

    return {
        plate = { streak = inputs.currentStreak, points = inputs.totalPoints },
        throwsEnabled = throwsEnabled,
        -- Not gated on phase: an unbanked pot outlives the round, the session and a week away.
        bankVisible = inputs.pointsAtStake > 0,
        pot = inputs.pointsAtStake,
        -- unresolvedWin's only job: "the last scored round was a WIN and the player has not
        -- banked since". It drives the pulse and nothing else.
        potPulses = inputs.pointsAtStake > 0 and inputs.unresolvedWin,
        escalate = armed and inputs.secondsLeft > 0 and inputs.secondsLeft <= ESCALATE_AT,
        secondsLeft = inputs.secondsLeft,
        -- The choice OUTLIVES the round: after the lockout it is what was thrown, and the tile
        -- stays lit through TALLY/REVEAL saying so. main.client clears it when ACTIVE reopens.
        chosen = inputs.chosen,
        -- The prompt does not. A question about a round that has closed cannot be answered.
        switchPrompt = if throwsEnabled then inputs.switchPrompt else nil,
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
