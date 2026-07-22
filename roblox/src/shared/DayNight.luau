--!strict
-- Pure, Lune-safe core of the day/night cycle. Maps a normalized cycle position t ∈ [0,1)
-- (uniform time) to:
--   • phaseAt(t)     → the current phase + a normalized nightFactor — the SIGNAL other systems
--                      read (glyph look, waterfall glow, …). This is the point of the system.
--   • clockTimeAt(t) → the scheduled Lighting.ClockTime, which drives Roblox's OWN sun/moon. The
--                      system controls the TIMING of day/night (how long each lasts), NOT the
--                      scene's light levels — it never touches Brightness/Ambient/Fog, so chōchin,
--                      glyphs, and everything else keep their natural brightness.
-- NO Roblox types here (no Color3/Enum/Instance/workspace) — it runs under both the Lune tests and
-- the Roblox client. See docs/.../2026-07-22-day-night-cycle-design.md.
local DayNight = {}

-- Night-dominant proportions as t-fractions of one loop; MUST stay contiguous + sum to 1.
-- (The manual timing controls are these proportions + the server's CycleLength / PhaseOffset.)
DayNight.PHASES = {
    { name = "dawn", from = 0.00, to = 0.10 }, -- nightFactor ramps 1 → 0
    { name = "day", from = 0.10, to = 0.28 }, -- nightFactor 0
    { name = "dusk", from = 0.28, to = 0.53 }, -- nightFactor ramps 0 → 1
    { name = "night", from = 0.53, to = 1.00 }, -- nightFactor 1 (the primary state)
}

local function smoothstep(x: number): number
    if x <= 0 then
        return 0
    elseif x >= 1 then
        return 1
    end
    return x * x * (3 - 2 * x)
end

local function frac(t: number): number
    return t - math.floor(t) -- normalize any real into [0,1)
end

-- phase + normalized nightFactor at cycle position t (the signal subscribers bind to).
function DayNight.phaseAt(t: number): { nightFactor: number, phase: string }
    local x = frac(t)
    if x < 0.10 then
        -- dawn: 1 → 0
        return { phase = "dawn", nightFactor = 1 - smoothstep(x / 0.10) }
    elseif x < 0.28 then
        return { phase = "day", nightFactor = 0 }
    elseif x < 0.53 then
        -- dusk: 0 → 1
        return { phase = "dusk", nightFactor = smoothstep((x - 0.28) / (0.53 - 0.28)) }
    else
        return { phase = "night", nightFactor = 1 }
    end
end

-- clockTime swept per band so Roblox's built-in sun/moon matches the night-dominant schedule:
-- the sun is up only through the (short) day band, and below the horizon across dawn/dusk/night.
-- Monotonic increasing 5 → 29 over the loop; the client applies (clockTime % 24).
local CLOCK = {
    { to = 0.10, a = 5, b = 8 }, -- dawn: sunrise
    { to = 0.28, a = 8, b = 16 }, -- day: sun climbs + sets low
    { to = 0.53, a = 16, b = 19 }, -- dusk: sunset
    { to = 1.00, a = 19, b = 29 }, -- night: 19 → 29 (29 % 24 = 5, wraps to next dawn)
}

-- scheduled ClockTime at cycle position t (0..29; caller applies % 24).
function DayNight.clockTimeAt(t: number): number
    local x = frac(t)
    local from = 0
    for _, band in CLOCK do
        if x < band.to then
            return band.a + (band.b - band.a) * ((x - from) / (band.to - from))
        end
        from = band.to
    end
    return 29
end

return DayNight
