--!strict
-- WHAT RENDERS, WHEN, AND AT WHAT DETAIL. Pure policy — the controller owns the instances and does
-- what this says. Split that way because no harness in this repo loads a `.client.luau`, so this
-- is the only part of the rendering path that can be tested at all.
--
-- PROVENANCE: docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md. Read it before changing
-- a number here. The short version: a Samsung A13 survived 10 shells/sec at ~700 particles each,
-- which is roughly 4x these constants — but that is a LOWER BOUND from ONE launcher at the camera's
-- feet, and the multi-player case these constants exist for was never measured. Known-conservative
-- beats unknown; a cap that is too generous fails on somebody else's phone, in front of guests.
--
-- Mobile is fill-rate bound, so the budget is a ceiling on simultaneous overlapping PARTICLES, not
-- on shells.
local FireworkDirector = {}

-- Bursts rendered at once. Beyond this they are STAGGERED, never dropped: the cap decouples cost
-- from player count, so a whole server firing together still costs the same as this many.
FireworkDirector.MAX_CONCURRENT = 14

-- Distance bands, in studs.
FireworkDirector.NEAR_STUDS = 250
FireworkDirector.FAR_STUDS = 700
-- Past this, do not render at all. The canyon is long and a burst at the far rim is a few pixels.
FireworkDirector.DROP_STUDS = 1400

FireworkDirector.PARTICLES_NEAR = 400
FireworkDirector.PARTICLES_FAR = 90

local STAGGER_MIN_MS = 100
local STAGGER_MAX_MS = 300

-- Render now, or shortly. `delayMs` grows with the overflow so a simultaneous volley spreads across
-- a few hundred milliseconds — visually indistinguishable from all-at-once, and the difference
-- between a steady frame rate and a hitch.
--
-- The delay is CLAMPED at STAGGER_MAX_MS. A 50-player battle must not push one player's shell
-- minutes into the future: past the clamp the sky is simply busy, and a shell that arrives late
-- enough to feel unresponsive is worse than a shell in a crowded sky.
function FireworkDirector.admit(activeCount: number, distance: number): { render: boolean, delayMs: number }
    if distance > FireworkDirector.DROP_STUDS then
        return { render = false, delayMs = 0 }
    end
    local over = activeCount - FireworkDirector.MAX_CONCURRENT
    if over < 0 then
        return { render = true, delayMs = 0 }
    end
    local span = STAGGER_MAX_MS - STAGGER_MIN_MS
    local delay = STAGGER_MIN_MS + math.min(span, over * (span / 8))
    return { render = true, delayMs = delay }
end

-- Particle budget and whether the burst is audible. Linear between the bands, so there is no visible
-- step as a burst recedes.
function FireworkDirector.lodFor(distance: number): { particles: number, sound: boolean }
    local near, far = FireworkDirector.NEAR_STUDS, FireworkDirector.FAR_STUDS
    local pNear, pFar = FireworkDirector.PARTICLES_NEAR, FireworkDirector.PARTICLES_FAR
    local particles
    if distance <= near then
        particles = pNear
    elseif distance >= far then
        particles = pFar
    else
        local t = (distance - near) / (far - near)
        particles = math.floor(pNear + (pFar - pNear) * t)
    end
    return { particles = particles, sound = distance <= near }
end

return FireworkDirector
