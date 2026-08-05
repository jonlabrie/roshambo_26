--!strict
-- The round timer's ring, as arithmetic. Roblox has no SVG, no arc primitive and no radial
-- fill, so the PWA's stroke-dash sweep (src/components/PieTimer.tsx) is rebuilt from a track
-- circle and two half-discs. A half-disc is a circular Frame whose UIGradient.Transparency
-- steps hard at offset 0.5; UIGradient.Rotation sweeps the cut. No clipping (Roblox's
-- ClipsDescendants carries a documented caveat about rotated descendants) and no image asset.
--
-- This module owns the ANGLES. HudController owns the instances and paints what it is told.
--
-- THE GEOMETRY, derived once so nobody re-derives it:
-- a half-disc's visible half is the clockwise arc [a, a + 180] measured from the top. The
-- gradient's visible side is the one BEFORE the step, and Rotation = 0 points the gradient axis
-- to the right — 90 degrees clockwise from the top. Hence:
--
--     UIGradient.Rotation = a + 180
--
-- To light the clockwise arc [0, theta]:
--   theta <= 180 : half A lit at a = 0 (covers 0-180); half B in TRACK at a = theta
--                  (covers theta..theta+180), painting back over the excess. Net: 0-theta.
--   theta >  180 : half A lit at a = 0; half B ALSO LIT at a = theta - 180. Union: 0-theta.
--
-- No Roblox globals — this runs under Lune like everything else in src/shared.
local RingTimer = {}

-- The smallest arc a live round may draw.
--
-- This is the old segment count's `math.ceil` restated for a continuous ring, and it is
-- load-bearing: an empty ring must mean the round is over and nothing else. A raw
-- fraction * 360 breaks that silently, because 0.2s of a 51s OPEN is 1.4 degrees — sub-pixel
-- at 44px, and it renders as nothing while the throw buttons are still live. 6 degrees is
-- roughly 2px along a 38px-diameter phone ring: small, but visibly not gone.
RingTimer.MIN_SWEEP_DEGREES = 6

export type Sweep = { rotationA: number, rotationB: number, bLit: boolean }

-- Degrees of the clockwise sweep for `fraction` of the round remaining.
function RingTimer.sweepDegrees(fraction: number): number
    local f = math.clamp(fraction, 0, 1)
    if f <= 0 then
        return 0
    end
    return math.max(f * 360, RingTimer.MIN_SWEEP_DEGREES)
end

-- The two gradient rotations that draw that sweep, and whether half B is lit or track.
--
-- `rotationA` is always 180 and is RETURNED rather than exported as a bare constant, so the
-- pair that must agree is produced in one place and a renderer cannot pick up one without the
-- other.
function RingTimer.sweep(fraction: number): Sweep
    local theta = RingTimer.sweepDegrees(fraction)
    if theta <= 180 then
        return { rotationA = 180, rotationB = theta + 180, bLit = false }
    end
    return { rotationA = 180, rotationB = theta, bLit = true }
end

-- Whether the ring should read as urgent. `escalateAt` is passed in rather than owned here so
-- the ring and the escalation prompt cannot drift apart — see HudModel.ESCALATE_AT.
--
-- Deliberately NOT gated on `secondsLeft > 0` the way HudModel's `escalate` is. That gate exists
-- because a prompt at zero would be pointless; a colour at zero is harmless, and at zero there
-- is no arc to colour anyway.
function RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean
    return secondsLeft <= escalateAt
end

return RingTimer
