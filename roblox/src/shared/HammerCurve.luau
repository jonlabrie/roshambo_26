--!strict
-- The Water Hammer's arm state as a pure function of phase + time (spec §5).
-- The arm IS the round countdown: it cranks from rest to apex over ACTIVE,
-- latches at lockout (T0-2s), trembles through TALLY, releases at REVEAL.
local HammerCurve = {}

export type Cfg = { activeSeconds: number, lockoutLeadSec: number, restDeg: number, apexDeg: number }
export type State = { angleDeg: number, latched: boolean, trembling: boolean, released: boolean }

local DEFAULT: Cfg = { activeSeconds = 20, lockoutLeadSec = 2, restDeg = 0, apexDeg = 100 }

function HammerCurve.state(phase: string, secondsLeft: number, cfg: Cfg?): State
    local c = cfg or DEFAULT
    if phase == "REVEAL" then
        return { angleDeg = c.apexDeg, latched = false, trembling = false, released = true }
    end
    if phase == "TALLY" then
        return { angleDeg = c.apexDeg, latched = true, trembling = true, released = false }
    end
    local crank = c.activeSeconds - c.lockoutLeadSec
    local elapsed = c.activeSeconds - secondsLeft
    local p = math.clamp(elapsed / crank, 0, 1)
    return {
        angleDeg = c.restDeg + (c.apexDeg - c.restDeg) * p,
        latched = secondsLeft <= c.lockoutLeadSec,
        trembling = secondsLeft <= c.lockoutLeadSec,
        released = false,
    }
end

return HammerCurve
