--!strict
-- Angle-fade for card-impostor foliage (the muhly grass clumps). A clump ships
-- as two MeshParts: crossed vertical planes (the ground-level silhouette) and
-- horizontal top caps (the overlook view). The caps would cut through the
-- eye-level profile, so the client fades them by camera elevation instead:
-- hidden below capFadeLo degrees, fully shown above capFadeHi, linear between.
-- Pure math so Lune tests it; FoliageImpostorController drives
-- LocalTransparencyModifier (1 = hidden) from these numbers.
local ImpostorFade = {}

export type Config = {
    capFadeLo: number, -- degrees of camera elevation where caps start appearing
    capFadeHi: number, -- degrees where caps are fully shown
}

ImpostorFade.DEFAULT = {
    capFadeLo = 25,
    capFadeHi = 45,
} :: Config

-- Camera elevation in degrees above the clump anchor: rise over horizontal run.
function ImpostorFade.elevation(rise: number, run: number): number
    return math.deg(math.atan2(rise, run))
end

-- LocalTransparencyModifier for the caps at a given elevation (1 hidden, 0 shown).
function ImpostorFade.capTransparency(elevationDeg: number, cfg: Config?): number
    local c = cfg or ImpostorFade.DEFAULT
    if c.capFadeHi <= c.capFadeLo then
        return if elevationDeg > c.capFadeLo then 0 else 1
    end
    local t = (elevationDeg - c.capFadeLo) / (c.capFadeHi - c.capFadeLo)
    return 1 - math.clamp(t, 0, 1)
end

return ImpostorFade
