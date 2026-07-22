--!strict
-- Pure, Lune-safe core of the day/night cycle. Maps a normalized cycle position
-- t ∈ [0,1) (uniform time) to the current phase, a normalized nightFactor, and a
-- plain-data Lighting state the client applies. NO Roblox types here (no Color3/
-- Enum/Instance/workspace) — colors are {r,g,b} arrays 0–1; it runs under both the
-- Lune tests and the Roblox client. See docs/.../2026-07-22-day-night-cycle-design.md.
local DayNight = {}

-- Night-dominant proportions as t-fractions of one loop; MUST stay contiguous + sum to 1.
DayNight.PHASES = {
    { name = "dawn", from = 0.00, to = 0.10 }, -- nightFactor ramps 1 → 0
    { name = "day", from = 0.10, to = 0.28 }, -- nightFactor 0
    { name = "dusk", from = 0.28, to = 0.53 }, -- the amber "magic hour"; ramps 0 → 1
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

-- phase + normalized nightFactor at cycle position t.
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

-- Starting mood targets (gate-tuned in Play). Colors are {r,g,b} 0–1.
local DAY = {
    brightness = 2.0,
    outdoorAmbient = { 0.55, 0.55, 0.55 },
    ambient = { 0.35, 0.35, 0.35 },
    fogEnd = 4000,
    fogColor = { 0.78, 0.82, 0.88 },
    ccTint = { 1.0, 1.0, 1.0 },
    ccBrightness = 0.0,
}
local NIGHT = {
    brightness = 0.4,
    outdoorAmbient = { 0.10, 0.12, 0.18 }, -- moonlit blue-grey, NOT pitch black (playability)
    ambient = { 0.06, 0.07, 0.11 },
    fogEnd = 1200,
    fogColor = { 0.05, 0.07, 0.12 },
    ccTint = { 0.75, 0.82, 1.0 }, -- cool
    ccBrightness = -0.05,
}

local function lerp(a: number, b: number, k: number): number
    return a + (b - a) * k
end
local function lerp3(a: { number }, b: { number }, k: number): { number }
    return { lerp(a[1], b[1], k), lerp(a[2], b[2], k), lerp(a[3], b[3], k) }
end

-- clockTime swept per band so the built-in sun/moon matches the night-dominant schedule.
-- Monotonic increasing 5 → 29 over the loop; the client applies (clockTime % 24).
local CLOCK = {
    { to = 0.10, a = 5, b = 8 }, -- dawn
    { to = 0.28, a = 8, b = 16 }, -- day
    { to = 0.53, a = 16, b = 19 }, -- dusk
    { to = 1.00, a = 19, b = 29 }, -- night (29 % 24 = 5, i.e. wraps to next dawn)
}
local function clockAt(x: number): number
    local from = 0
    for _, band in CLOCK do
        if x < band.to then
            return lerp(band.a, band.b, (x - from) / (band.to - from))
        end
        from = band.to
    end
    return 29
end

-- Plain-data Lighting state at cycle position t.
function DayNight.lightingAt(t: number): {
    clockTime: number,
    brightness: number,
    outdoorAmbient: { number },
    ambient: { number },
    fogEnd: number,
    fogColor: { number },
    ccTint: { number },
    ccBrightness: number,
}
    local x = frac(t)
    local nf = DayNight.phaseAt(x).nightFactor
    return {
        clockTime = clockAt(x),
        brightness = lerp(DAY.brightness, NIGHT.brightness, nf),
        outdoorAmbient = lerp3(DAY.outdoorAmbient, NIGHT.outdoorAmbient, nf),
        ambient = lerp3(DAY.ambient, NIGHT.ambient, nf),
        fogEnd = lerp(DAY.fogEnd, NIGHT.fogEnd, nf),
        fogColor = lerp3(DAY.fogColor, NIGHT.fogColor, nf),
        ccTint = lerp3(DAY.ccTint, NIGHT.ccTint, nf),
        ccBrightness = lerp(DAY.ccBrightness, NIGHT.ccBrightness, nf),
    }
end

return DayNight
