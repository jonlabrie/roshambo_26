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
    edgeLo: number, -- |dot(plane normal, to-camera)| at/below which a plane hides
    edgeHi: number, -- |dot| at/above which a plane is fully shown
    vertFadeLo: number, -- elevation degrees where vertical planes start fading out
    vertFadeHi: number, -- degrees where verticals are fully hidden (caps carry it)
}

ImpostorFade.DEFAULT = {
    capFadeLo = 25,
    capFadeHi = 45,
    edgeLo = 0.25,
    edgeHi = 0.7,
    vertFadeLo = 60,
    vertFadeHi = 80,
} :: Config

-- Linear 1→0 ramp helper: 1 at/below lo, 0 at/above hi.
local function ramp(value: number, lo: number, hi: number): number
    if hi <= lo then
        return if value > lo then 0 else 1
    end
    return 1 - math.clamp((value - lo) / (hi - lo), 0, 1)
end

-- The baker lays vertical planes at fixed local yaws (0°, 60°, 120°), spanning
-- Blender +X rotated by the yaw; the FBX importer maps Blender (x, y) to Roblox
-- (−X, Z). planeNormal(i) is plane i's horizontal normal in the MODEL's local
-- space — rotate by the part's world CFrame before dotting with the camera dir.
function ImpostorFade.planeNormal(index: number): { x: number, z: number }
    local ang = math.rad((index - 1) * 60)
    -- span S = (−cos a, sin a) in Roblox local XZ; normal = up × S = (S.z, −S.x)
    return { x = math.sin(ang), z = math.cos(ang) }
end

-- LocalTransparencyModifier for a vertical plane seen edge-on: hidden as the
-- camera sweeps across its edge, shown when facing.
function ImpostorFade.edgeTransparency(absDot: number, cfg: Config?): number
    local c = cfg or ImpostorFade.DEFAULT
    return ramp(absDot, c.edgeLo, c.edgeHi)
end

-- Combined vertical-plane fade: the stronger of the edge fade and the steep-
-- elevation fade (from overhead the caps carry the clump; verticals bow out).
function ImpostorFade.vertTransparency(absDot: number, elevationDeg: number, cfg: Config?): number
    local c = cfg or ImpostorFade.DEFAULT
    local elevationFade = 1 - ramp(elevationDeg, c.vertFadeLo, c.vertFadeHi)
    return math.max(ImpostorFade.edgeTransparency(absDot, c), elevationFade)
end

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
