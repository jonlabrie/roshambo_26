--!strict
-- Analytic snail-cam flank for the bell-drive draw. The cam axle sits at the draw
-- dowel's height, gapZ north of its rest plane; the dowel draws +Z by `draw` and
-- rises `rise·p²` on the rope arc. HammerController locks cam angle to the draw
-- fraction p (one revolution per round, peak on the dowel at the strike), so a
-- flank whose radius at local angle λ(p) equals the contact radius r(p) stays
-- visually in contact through the WHOLE draw — geometric honesty by construction.
-- Local angle convention matches the controller's anchor: 0° = the cliff/peak,
-- angles measured in the cam's rotation sense; the flank trails the cliff.
local CamProfile = {}

export type Geom = {
    gapZ: number,
    draw: number,
    rise: number,
    dowelR: number,
    dropDeg: number,
    clearance: number?, -- face generated this much shy of the dowel's surface
    strikeP: number?, -- fraction of the round at which the strike lands
    -- ((active+tally)/period; default 1). samples() builds the EXACT contact
    -- locus for the metronome kinematics — see below.
}

-- Dowel contact radius + azimuth (degrees, from the rest direction toward the
-- rise) at draw fraction f — the DOWEL's state, not a flank parameter.
function CamProfile.contact(f: number, g: Geom): (number, number)
    local dz = g.gapZ + g.draw * f
    local dy = g.rise * f * f
    return math.sqrt(dz * dz + dy * dy) - g.dowelR - (g.clearance or 0), math.deg(math.atan2(dy, dz))
end

-- The flank as the EXACT runtime contact locus. Kinematics: the cam turns one
-- revolution per round; the controller pins the cliff (local angle 0) on the
-- dowel's azimuth at each strike (CamPhaseDeg's correct value is therefore 0).
-- Between strikes the dowel, drawing with fraction f in [0, strikeP], meets the
-- flank at local angle lambda(f) = 360·(strikeP − f) + az(f) − az(strikeP) —
-- so we EMIT the dowel's own (lambda, radius) at each f: contact is uniform at
-- `clearance` through the whole draw by construction, no angular model to drift.
-- Points that sweep the dowel while the log rests/swings (lambda beyond
-- lambda(0), up to the drop wall at 360 − dropDeg) form a rest-radius base arc.
-- Output: descending local angle, first = base-arc start, last = the cliff (0).
function CamProfile.samples(g: Geom, n: number): { { deg: number, r: number } }
    local sp = g.strikeP or 1
    local restR = CamProfile.contact(0, g)
    local _, azStrike = CamProfile.contact(sp, g)
    local lambda0 = 360 * sp - azStrike -- az(0) = 0: where the draw locus begins
    local top = 360 - g.dropDeg
    local out = {}
    -- uniform DESCENDING angles top -> 0 (strictly monotone for any strikeP);
    -- rest radius beyond the locus start, else invert lambda(f) per point
    local total = n + 8
    for i = 0, total do
        local lam = top * (1 - i / total)
        local r
        if lam >= lambda0 then
            r = restR
        else
            -- invert lambda(f) = 360(sp - f) + az(f) - azStrike; the az term is
            -- tiny, so three fixed-point passes land well inside mesh tolerance
            local f = sp - lam / 360
            for _ = 1, 3 do
                local _, az = CamProfile.contact(math.clamp(f, 0, sp), g)
                f = sp - (lam - az + azStrike) / 360
            end
            r = CamProfile.contact(math.clamp(f, 0, sp), g)
        end
        table.insert(out, { deg = lam, r = r })
    end
    return out
end

return CamProfile
