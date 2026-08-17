--!strict
-- THE ROUND DISPLAY — one unit, high on the cavern's west wall: a large throw flipper beside a
-- 0:00 countdown. Pure, so the two rules that matter can be pinned by tests rather than asserted
-- in comments.
--
-- WHY IT EXISTS. The Stats room is under ~18 studs of rock, out of sight and earshot of the
-- taiko drum that is the round's authoritative signal. Without a round display, walking in here
-- means silently dropping out of the game. It supersedes the four clerestory band segments,
-- which existed only to hold that ground until this landed.
local ReelStep = require("./ReelStep")
local DrumStep = require("./DrumStep")

local RoundDisplayModel = {}

RoundDisplayModel.SYMBOLS = { "R", "P", "S" }

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

-- PRINTED ON THE BOARD, NOT MOUNTED ON A DRUM (owner, 2026-08-17): "the colon should be printed
-- between the minute and seconds columns, not in a flipper column of its own". No real board
-- puts a fixed separator on a flap. `statics()` hands FlapBoard the column to paint; it carries
-- no drum at all and the planner skips it, so it can never be asked to turn.
RoundDisplayModel.COLON = ":"

export type ClockState = { phase: string?, secondsLeft: number? }
export type ThrowState = {
    phase: string?,
    previousThrow: string?,
    worldThrow: string?,
    worldRested: boolean?,
    -- Seconds since CONTACT (the bell, `DrumStep.STRIKE_SWING_SECONDS` after REVEAL opens).
    -- Negative while the shu-moku is still swinging, nil when the reel is not armed.
    contactElapsed: number?,
}

-- Column 2 is deliberately absent: it is printed, not turned.
function RoundDisplayModel.drums(): { [number]: string }
    return { [1] = RoundDisplayModel.DIGITS, [3] = RoundDisplayModel.DIGITS, [4] = RoundDisplayModel.DIGITS }
end

function RoundDisplayModel.statics(): { [number]: string }
    return { [2] = RoundDisplayModel.COLON }
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

-- THE SAME REEL THE HUD'S RING RUNS, not an imitation of it (owner, 2026-08-17: the flipper
-- "should go blank at the same time the round timer disappears in the HUD, should start flipping
-- at the same time the HUD does (as the drum spins) and should come to rest at the same time as
-- the drum/HUD"). Driving it from `ReelStep` is how that holds by construction rather than by two
-- sets of constants drifting apart.
--
-- The first version began turning at the END OF OPEN, which is 2.45s ahead of the ring: LOCK's two
-- seconds plus the shu-moku's 0.45s swing. `DrumStep` warns about exactly this half-second half of
-- the error -- "anything animating ALONGSIDE the wheel wants TURN_SECONDS... mixing them puts an
-- animation 0.45s ahead of the thing it is standing in for, which is exactly how the reel first
-- shipped." It is how this shipped too.
--
-- So: hold last round's throw through OPEN; go BLANK the moment the countdown does, and stay blank
-- through LOCK and the swing; cycle from contact; and stop only when the drum has rested.
--
-- TWO PROPERTIES ARE LOAD-BEARING, both inherited from ReelStep and both tested. The cycle never
-- stops on its own -- it decelerates to a plateau, because a cycle that ran out before the drum
-- rested would be sitting on a glyph that is NOT the World Throw, which reads as an answer and is
-- worse than an early one because it is the WRONG one. And the cycling glyph is a function of
-- elapsed time alone: it is never handed the answer, so it cannot leak it.
function RoundDisplayModel.throwState(state: ThrowState): { glyph: string?, reeling: boolean }
    if state.worldRested and state.worldThrow then
        return { glyph = state.worldThrow, reeling = false }
    end
    local phase = state.phase
    if phase ~= "LOCK" and phase ~= "REVEAL" then
        return { glyph = state.previousThrow, reeling = false }
    end
    local elapsed = state.contactElapsed
    if elapsed == nil or elapsed < 0 then
        -- LOCK, and the swing. Blank on purpose, so the flipper starts with the bell and the
        -- wheel rather than filling a gap ahead of both.
        return { glyph = nil, reeling = false }
    end
    -- TURN_SECONDS, not SETTLE_SECONDS: this stands in for the wheel, and the wheel's travel
    -- begins at contact. Against SETTLE the curve would pace a 3.45s journey the drum makes in
    -- 3.0s from here, and plateau early.
    return {
        glyph = ReelStep.symbolAt(RoundDisplayModel.SYMBOLS, elapsed, DrumStep.TURN_SECONDS),
        reeling = true,
    }
end

return RoundDisplayModel
