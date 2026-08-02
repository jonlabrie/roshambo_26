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
-- LightInfluence IS THE LEVER, AND IT CANNOT BE SCALED. First attempt dimmed Brightness and
-- LightEmission only, which measurably worked (1.00 -> 0.55 on all 135 objects) and was
-- visually almost undetectable. The reason is that at LightInfluence 0 an effect is FULLY
-- self-lit — it does not know the sun has gone down — so dimming it just makes a self-lit
-- object slightly less self-lit. Nothing lets the darkness touch it.
--
-- Raising LightInfluence was dismissed the first time on the grounds that 1.0 lights the
-- particle by the scene alone and would turn whitewater black. That was a false dichotomy:
-- LightInfluence is a continuous blend, not a switch, and a partial value is exactly the
-- "responds to the night without vanishing into it" the falls want. Note it must be LERPED
-- TOWARD a target, never scaled — the authored value is 0 (a few at 0.10), and zero times any
-- factor is still zero, which is the shape of bug that made the first pass a no-op.
--
-- SCALES FOR EMISSION, A TARGET FOR INFLUENCE. Each object keeps its own authored look — the
-- hero fall is brighter than a gentle run, foam sits at LightEmission 0.25 while whitewater
-- sits at 0.60 — so those two channels are FRACTIONS of what the artist set. LightInfluence
-- is the one property where every object should end up in the same place after dark, because
-- it describes a relationship to the scene rather than a look.

-- THE BLUE CAST, AND WHY IT ONLY APPEARS AT NIGHT. Every whitewater and foam emitter is
-- authored with a two-key ramp: born pale cyan (189,246,255), fading to white as the particle
-- dies. In daylight LightEmission 0.60 at LightInfluence 0 blew that out — the spray was
-- self-lit hard enough that the blue washed to white before anyone could see it. Dimming
-- emission and letting the scene reach the particles makes the authored birth colour survive,
-- so the falls picked up a blue cast the moment the night curve started working. The colour
-- was always there; daylight was hiding it. neutraliseColor walks the ramp back toward white
-- as night comes on, leaving the daytime authoring untouched.

local VfxNightDim = {}

export type Values = { brightness: number, lightEmission: number, lightInfluence: number }
export type ColorKey = { t: number, r: number, g: number, b: number }

-- Night targets. The falls should still be the loudest feature in a night canyon, just
-- luminous grey rather than blazing white. LightEmission falls further than Brightness
-- because self-lit is the specifically daytime quality.
local NIGHT_BRIGHTNESS = 0.45
local NIGHT_LIGHT_EMISSION = 0.35
local NIGHT_LIGHT_INFLUENCE = 0.75
-- 1.0 = the ramp is fully white at full night. Lower it to leave a whisper of the authored
-- cyan; the user asked for the cast neutralised, so it goes all the way.
local NIGHT_COLOR_NEUTRALISE = 1.0

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

-- nightFactor is clamped for the same reason LanternGlow clamps it: the signal arrives over
-- an EventBus that can be primed, replayed, or fired mid-transition, and a negative value
-- would scale emission ABOVE its authored maximum — a brighter-than-daylight waterfall.
function VfxNightDim.at(authored: Values, nightFactor: number): Values
    local t = math.clamp(nightFactor, 0, 1)
    return {
        brightness = authored.brightness * lerp(1, NIGHT_BRIGHTNESS, t),
        lightEmission = authored.lightEmission * lerp(1, NIGHT_LIGHT_EMISSION, t),
        lightInfluence = lerp(authored.lightInfluence, NIGHT_LIGHT_INFLUENCE, t),
    }
end

-- Plain data in, plain data out: ColorSequence is a Roblox type and this has to stay
-- Lune-testable, so the client converts at the boundary. Keypoint TIMES are preserved
-- exactly — Roblox requires the first at 0, the last at 1, and strictly increasing between,
-- so rebuilding them from scratch would be a way to construct an invalid sequence.
function VfxNightDim.neutraliseColor(keys: { ColorKey }, nightFactor: number): { ColorKey }
    local t = math.clamp(nightFactor, 0, 1) * NIGHT_COLOR_NEUTRALISE
    local out: { ColorKey } = {}
    for i, k in keys do
        out[i] = {
            t = k.t,
            r = lerp(k.r, 1, t),
            g = lerp(k.g, 1, t),
            b = lerp(k.b, 1, t),
        }
    end
    return out
end

return VfxNightDim
