--!strict
-- THE ROUND DISPLAY — one unit, high on the cavern's west wall: a large throw flipper beside a
-- 0:00 countdown. Pure, so the two rules that matter can be pinned by tests rather than asserted
-- in comments.
--
-- WHY IT EXISTS. The Stats room is under ~18 studs of rock, out of sight and earshot of the
-- taiko drum that is the round's authoritative signal. Without a round display, walking in here
-- means silently dropping out of the game. It supersedes the four clerestory band segments,
-- which existed only to hold that ground until this landed.
local RoundDisplayModel = {}

-- ===== THE DIGIT DRUM (owner's ruling, 2026-08-17) =====
-- "A drum that is only ever going to show digits should only ever have digits on it. It's a
-- different drum."
--
-- The first version ran every cell on the 49-character alphanumeric drum, so a countdown going
-- 3 -> 2 travelled 48 steps forward through the alphabet, hit the 9-step cap, and rolled
-- `U V W X Y Z 0 1 2` -- about 750ms of motion every second, so the digit never settled.
--
-- DESCENDING is the other half of the ruling, and ascending would not have fixed it: on
-- `0123456789`, counting down 3 -> 2 is still 9 steps. Descending makes it 1.
--
-- The BLANK sits last so `0 -> blank` at round end and `blank -> 9` at round start are each a
-- single step too. The one multi-step case left is the ten-second rollover `0 -> 9`, which
-- passes through the blank -- unavoidable on a cyclic drum carrying one, and correct: a real
-- board shows the flaps it passes through.
RoundDisplayModel.DIGITS = "9876543210 "

-- Two characters, not one. FlapBoard starts every cell blank, and a single-character drum could
-- never leave that blank -- the colon would never appear.
RoundDisplayModel.COLON = " :"

export type ClockState = { phase: string?, secondsLeft: number? }
export type ThrowState = {
    phase: string?,
    previousThrow: string?,
    worldThrow: string?,
    worldRested: boolean?,
}

function RoundDisplayModel.drums(): { string }
    return {
        RoundDisplayModel.DIGITS,
        RoundDisplayModel.COLON,
        RoundDisplayModel.DIGITS,
        RoundDisplayModel.DIGITS,
    }
end

local MAX_SECONDS = 599 -- 9:59, the most four columns can honestly say

-- Four columns: minutes, colon, tens, units. The minutes digit never moves at a 60s round; it is
-- kept because `0:43` reads as a clock where `43` reads as a quantity, and because the format
-- stops being a lie the day a round grows.
function RoundDisplayModel.clock(state: ClockState): string
    if state.phase ~= "OPEN" then
        -- Between rounds (LOCK + REVEAL = 9s), and before any schedule has replicated. The colon
        -- stays lit: a bare colon reads as a clock at rest, four blanks read as a broken board.
        return " :  "
    end
    local secs = math.clamp(math.floor(state.secondsLeft or 0), 0, MAX_SECONDS)
    return string.format("%d:%02d", secs // 60, secs % 60)
end

-- Holds LAST round's throw through OPEN, turns from the moment the countdown expires, and lands
-- only when the drum outside has come to rest.
--
-- LANDING IS THE `drumRest` CUE AND NOTHING ELSE. `worldThrow` arrives on RevealTheater about
-- 3.45s before the drum stops; naming it then is the spoiler five other displays in this project
-- have each had to be corrected for. Making `worldRested` a parameter is how this one cannot.
function RoundDisplayModel.throwState(state: ThrowState): { glyph: string?, spinning: boolean }
    local phase = state.phase
    if phase ~= "LOCK" and phase ~= "REVEAL" then
        return { glyph = state.previousThrow, spinning = false }
    end
    if phase == "REVEAL" and state.worldRested and state.worldThrow then
        return { glyph = state.worldThrow, spinning = false }
    end
    return { glyph = state.previousThrow, spinning = true }
end

return RoundDisplayModel
