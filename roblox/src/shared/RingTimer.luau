--!strict
-- The round timer's ring, as arithmetic. Roblox has no SVG and no radial fill, so the PWA's
-- stroke-dash sweep (src/components/PieTimer.tsx) becomes a ring of discrete segments, lit from
-- the top clockwise. Which segments are lit is pure and lives here; HudController only paints
-- what it is told.
--
-- No Roblox globals — this runs under Lune like everything else in src/shared.
local RingTimer = {}

-- 36 segments = one every 10 degrees. Enough to read as a ring at 54px; few enough that the
-- controller builds 36 Frames once and only recolours them thereafter.
RingTimer.SEGMENTS = 36

-- How many segments are lit for `fraction` of the round remaining.
--
-- CEIL, not floor or round, and that matters at one end: any time at all leaves at least one
-- segment lit, because the round is still open and the throw buttons are still live. An empty
-- ring must mean the round is over, and nothing else.
function RingTimer.lit(fraction: number, segments: number): number
    local f = math.clamp(fraction, 0, 1)
    return math.clamp(math.ceil(f * segments), 0, segments)
end

-- Where segment `index` sits, in degrees clockwise from the top. Roblox's `Rotation` is already
-- clockwise-positive, so this feeds it directly.
function RingTimer.angleAt(index: number, segments: number): number
    return (index - 1) * (360 / segments)
end

-- Whether the ring should read as urgent. `escalateAt` is passed in rather than owned here so
-- the ring and the escalation prompt cannot drift apart — see HudModel.ESCALATE_AT.
--
-- Deliberately NOT gated on `secondsLeft > 0` the way HudModel's `escalate` is. That gate exists
-- because a prompt at zero would be pointless; a colour at zero is harmless, and at zero there
-- are no lit segments to colour anyway.
function RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean
    return secondsLeft <= escalateAt
end

-- A segment's width. Its share of the circumference would leave hairline gaps once each segment
-- is rotated about its own centre, so they are widened to overlap and the ring reads solid.
function RingTimer.segmentWidth(radius: number, segments: number): number
    return math.ceil(2 * math.pi * radius / segments) + 1
end

return RingTimer
