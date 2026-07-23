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

export type Geom = { gapZ: number, draw: number, rise: number, dowelR: number, dropDeg: number }

-- Contact radius + azimuth (degrees, from the rest direction toward the rise) at p.
function CamProfile.contact(p: number, g: Geom): (number, number)
    local dz = g.gapZ + g.draw * p
    local dy = g.rise * p * p
    return math.sqrt(dz * dz + dy * dy) - g.dowelR, math.deg(math.atan2(dy, dz))
end

-- n+1 flank samples from rest (p=0, local angle just behind a full turn) to the
-- release (p=1, local angle = the tilted contact azimuth, right at the cliff).
-- The blend (1−p)·(360−dropDeg) + az·p is monotonic because the draw dominates.
function CamProfile.samples(g: Geom, n: number): { { deg: number, r: number } }
    local out = {}
    for i = 0, n do
        local p = i / n
        local r, az = CamProfile.contact(p, g)
        table.insert(out, { deg = (1 - p) * (360 - g.dropDeg) + az * p, r = r })
    end
    return out
end

return CamProfile
