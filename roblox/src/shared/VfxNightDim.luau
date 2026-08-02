--!strict
-- VfxNightDim — how much the water VFX give back at a given nightFactor.
--
-- Pure: no instances, no services. The client script multiplies each emitter's AUTHORED
-- values by these scales; the curve is testable under Lune.
--
-- THE PROBLEM THIS SOLVES. Every cascade Beam and whitewater ParticleEmitter in the canyon
-- is authored with LightInfluence 0 (a few at 0.10), which means it ignores scene lighting
-- completely and renders at full daylight brightness at midnight. The falls looked identical
-- at noon and at 2am, which in a night-first arena is the single most obvious tell.
--
-- WHY NOT JUST RAISE LightInfluence AT NIGHT. Because it overshoots: at LightInfluence 1 a
-- particle is lit only by the scene, and a night canyon is dark, so the whitewater would go
-- nearly black. That is wrong in the other direction — moonlit falls are the BRIGHTEST thing
-- in a night landscape, not the dimmest. What changes after dark is that they read as
-- luminous grey rather than blazing white. So the two self-emission channels come down
-- partway and stop: Brightness (overall output) and LightEmission (how much the texture
-- ignores shading).
--
-- SCALES, NOT VALUES. Each object keeps its own authored look — the hero fall is authored
-- brighter than a gentle run, foam sits at LightEmission 0.25 while whitewater sits at 0.60 —
-- and this module only says what FRACTION of it survives the night. One curve therefore
-- governs 135 objects without flattening the differences between them.

local VfxNightDim = {}

export type Scale = { brightness: number, lightEmission: number }

-- Night floors, chosen so the falls stay legible as the loudest feature in the canyon while
-- no longer reading as daylight. LightEmission falls further than Brightness: it is the
-- channel that makes spray look self-lit, and that is the specifically daytime quality.
local NIGHT_BRIGHTNESS = 0.55
local NIGHT_LIGHT_EMISSION = 0.45

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

-- nightFactor is clamped for the same reason LanternGlow clamps it: the signal arrives over
-- an EventBus that can be primed, replayed, or fired mid-transition, and a negative value
-- would scale emission ABOVE its authored maximum — a brighter-than-daylight waterfall.
function VfxNightDim.scaleAt(nightFactor: number): Scale
    local t = math.clamp(nightFactor, 0, 1)
    return {
        brightness = lerp(1, NIGHT_BRIGHTNESS, t),
        lightEmission = lerp(1, NIGHT_LIGHT_EMISSION, t),
    }
end

return VfxNightDim
