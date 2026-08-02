--!strict
-- LanternGlow — what a lantern looks like at a given nightFactor.
--
-- Pure: no Roblox instances, no services. The client scripts read a profile from here and
-- apply it; the curve itself is testable under Lune.
--
-- TWO PROFILES, BECAUSE THE CANYON HAS TWO KINDS OF LANTERN AND THEY ARE NOT THE SAME THING.
--
--   stone  the yamadoro — rustic trail lanterns, set once, lit only after dusk. These go
--          FULLY out by day: transparency 1 skips the draw entirely, so the firebox reads as
--          an empty dark opening rather than a dim bulb. This reproduces exactly the curve
--          YamadoroDayNight.client.luau carried inline before it was extracted here.
--
--   paper  the chōchin and the square deck/newel lanterns. These NEVER go out, and that is
--          deliberate: LanternController drives them as the round telegraph — every one of
--          them shows the last World Throw's glyph and fades blank before the next reveal.
--          They are a thing players READ, so a nightFactor curve that extinguishes them by
--          day would dim a game display, not just an ornament. They ride the curve between a
--          daytime floor and full night glow instead: calmer at noon, never illegible.
--
-- Neon illuminates only itself, so the visible glow and the pool of light on the ground are
-- two separate channels — Transparency drives the first, PointLight.Brightness the second.
-- `enabled` falls out of brightness rather than being set by hand: a light at brightness 0
-- still occupies one of the renderer's light slots, so the stone profile switches its light
-- off outright by day while the paper profile never does.

local LanternGlow = {}

export type Glow = { transparency: number, brightness: number, enabled: boolean }
export type Profile = {
    transparencyDark: number,
    transparencyLit: number,
    brightnessDark: number,
    brightnessLit: number,
}

-- transparencyLit stays well above 0: at 0 the Neon reads as a solid hot block rather than a
-- glowing paper skin, which is the difference between a lantern and a lightbulb.
local PROFILES: { [string]: Profile } = {
    stone = {
        transparencyDark = 1.00,
        transparencyLit = 0.32,
        brightnessDark = 0.00,
        brightnessLit = 1.00,
    },
    paper = {
        transparencyDark = 0.62,
        transparencyLit = 0.42,
        brightnessDark = 0.35,
        brightnessLit = 1.10,
    },
}
LanternGlow.PROFILES = PROFILES

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

-- nightFactor is clamped, not trusted: it arrives over an EventBus from a controller that
-- can be primed, replayed, or fired mid-transition, and a value outside [0,1] would push
-- transparency past 1 (invisible when it should be lit) or below 0 (an error).
function LanternGlow.at(profileName: string, nightFactor: number): Glow
    local profile = PROFILES[profileName]
    assert(profile, `LanternGlow: unknown profile "{profileName}"`)
    local t = math.clamp(nightFactor, 0, 1)
    local brightness = lerp(profile.brightnessDark, profile.brightnessLit, t)
    return {
        transparency = lerp(profile.transparencyDark, profile.transparencyLit, t),
        brightness = brightness,
        enabled = brightness > 0.01,
    }
end

return LanternGlow
