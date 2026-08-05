--!strict
-- THE REEL. What the ring's centre shows while the drum is still turning — the three glyphs
-- cycling IN PLACE, decelerating, until the drum's rest ends it.
--
-- It runs from CONTACT — `DrumStep.STRIKE_SWING_SECONDS` after REVEAL opens, where the bell
-- sounds and the wheel starts turning — not from the lockout and not from REVEAL's edge. LOCK's two
-- seconds and the shu-moku's swing are both a black disc on purpose, so the reel reads as the wheel
-- turning rather than as the HUD filling a gap.
--
-- Callers therefore pass `DrumStep.TURN_SECONDS` as `settleSeconds`, not `SETTLE_SECONDS`: elapsed
-- and the wheel's travel start together, which is what makes the curve decelerate in step with the
-- thing it is standing in for.
--
-- WHY IN PLACE AND NOT SCROLLING. The obvious design is a slot-machine reel sliding sideways, and
-- it will not fit: the revealed glyph is 0.82 of the ring's inner disc, so its ink reaches ~0.35·D
-- from centre against a radius of 0.5·D. It can travel about ±0.15·D — ±9px on the real 60px ring —
-- before ink leaves the ring entirely, and the next glyph on a reel is 49px away. Measured in
-- Studio 2026-08-05. Clipping cannot help: it hides the spill but cannot make room, and no
-- axis-aligned clip that CONTAINS a 0.82 glyph fits inside the disc at all (the largest inscribed
-- square is 0.707·D). Cycling in place keeps the glyph at exactly the size the reveal uses, so the
-- handover is not an animation at all — the glyph simply stops changing.
--
-- THE RULE THIS SERVES. The drum is authoritative; nothing may reflect the World Throw before it
-- is fully at rest. A reel is a spoiler risk in a way a blank ring is not, so two properties are
-- load-bearing and both are tested:
--
--   1. THE CYCLE NEVER STOPS ON ITS OWN. It decelerates towards SLOW_SECONDS and plateaus there.
--      A cycle that ran out of momentum before the drum rested would be sitting on a glyph that is
--      NOT the World Throw — which reads as an answer, and is a worse failure than showing the
--      answer early, because it is showing the WRONG one. The drum's rest is the only thing that
--      ends it.
--   2. NOTHING HERE KNOWS THE ANSWER. `symbolAt` is a function of elapsed time and nothing else.
--      It cannot leak a result it was never given.
--
-- Pure and Roblox-free, so it runs under Lune like everything else in src/shared. `symbolAt` is a
-- closed form rather than an accumulator so a dropped frame cannot make it drift, and so the whole
-- thing is testable without simulating a clock.
local ReelStep = {}

-- The interval between glyph changes at the start of the settle, and the floor it decelerates to.
-- Tuned against the Studio prototype at 60px and 240px (2026-08-05): faster than FAST reads as
-- flicker rather than as glyphs, slower than SLOW reads as already stopped.
ReelStep.FAST_SECONDS = 0.05
ReelStep.SLOW_SECONDS = 0.26

-- Seconds between changes at `elapsed` into a settle of `settleSeconds`. Quadratic in elapsed, so
-- it holds near FAST for the first half and does most of its slowing late — a linear ramp spends
-- too long in the middle and reads as one long mush.
--
-- PAST `settleSeconds` IT PLATEAUS at SLOW rather than continuing to grow. That window is the
-- drum's stall, and a stall must look like a wheel still turning, not like a HUD that has frozen.
function ReelStep.intervalAt(elapsed: number, settleSeconds: number): number
    local p = math.clamp(elapsed / settleSeconds, 0, 1)
    return ReelStep.FAST_SECONDS + (ReelStep.SLOW_SECONDS - ReelStep.FAST_SECONDS) * p * p
end

-- How many changes have happened by `elapsed`. The integral of 1/intervalAt: with
-- interval(t) = a + b·t², that is (1/sqrt(ab))·atan(t·sqrt(b/a)), and past the settle the interval
-- is the constant SLOW so the tail is linear.
function ReelStep.changesBy(elapsed: number, settleSeconds: number): number
    if elapsed <= 0 then
        return 0
    end
    local a = ReelStep.FAST_SECONDS
    local b = (ReelStep.SLOW_SECONDS - a) / (settleSeconds * settleSeconds)
    local function ramp(t: number): number
        return (1 / math.sqrt(a * b)) * math.atan(t * math.sqrt(b / a))
    end
    if elapsed <= settleSeconds then
        return ramp(elapsed)
    end
    return ramp(settleSeconds) + (elapsed - settleSeconds) / ReelStep.SLOW_SECONDS
end

-- The glyph showing at `elapsed`. A pure function of time over the caller's symbol list — it is
-- never told the World Throw and so cannot reveal it.
function ReelStep.symbolAt(symbols: { string }, elapsed: number, settleSeconds: number): string
    local n = #symbols
    local i = math.floor(ReelStep.changesBy(elapsed, settleSeconds))
    return symbols[(i % n) + 1]
end

return ReelStep
