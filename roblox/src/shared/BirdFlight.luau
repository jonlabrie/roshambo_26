--!strict
-- WHERE THE BIRD IS, as a pure function of state, time and a per-player seed. No Roblox service
-- and no randomness at call time: two clients watching the same player must draw the same bird,
-- and Lune must be able to check the curves without a DataModel.
--
-- RETURNS PLAIN {x, y, z} TABLES, NOT Vector3, following DoomEscalation: a pure module names no
-- Roblox type, and the client controller converts at the boundary. That is what lets this file be
-- tested under Lune at all -- Vector3 does not exist there.
--
-- THE GRAMMAR IS VERTICAL DIRECTION (owner, 2026-08-18). Win RISES, safe PERCHES, loss SINKS.
-- The space above a player's head is the only region never occluded by another avatar, so height
-- is what survives a crowd of fifty on a phone -- colour and detail do not.
--
-- ⚠ A RESULT IS A STANDING DISPLAY, NOT AN ANIMATION (owner, 2026-08-18). The first version played
-- a 2-3 second flourish and returned to idle, which meant the result was only visible if you
-- happened to be watching that player at the instant the drum rested -- "if you weren't looking at
-- an avatar right as the drum came to a rest, you'll miss it."
--
-- So a result has a short ENTRY animation and then a HELD POSE. It first held until the next round
-- -- about a minute -- and that was too far the other way (owner, 2026-08-18): "after the bird
-- flies to me to indicate a result, it just keeps hovering until the next round. Feels too long."
-- RESULT_HOLD is the settled answer: long enough that glancing over a few seconds later still
-- tells you what happened, short enough that the bird gets back to living in the world.
--
-- ⚠ FOUR STATES, AND ONLY TWO OF THEM HAVE A BEHAVIOUR (owner, 2026-08-18).
--
--   WIN     rises and stays up
--   LOSS    bolts, then sinks and stays low
--   SAFE    NOTHING. Safe means nothing changed, so the bird does not change either.
--   RESTING no entry -- the player did not throw this round, or has not thrown in an hour.
--
-- RESTING is the state the first version forgot, and forgetting it was a bug rather than an
-- omission: holding a result "until the next round" with nothing to end it left a bird that won an
-- hour ago still circling triumphantly. Every bird is returned to RESTING at the start of each
-- reveal, and only a WIN or LOSS cue moves it off.
--
-- Which is also why LOSS must not come home to the resting orbit -- that would make "lost" and
-- "did not play" identical -- so it sinks low and stays there. Down, in a grammar where up means
-- won.
local BirdFlight = {}

-- ENTRY is the length of the ANIMATION, not the length of the state: the state itself persists
-- until the next result replaces it.
BirdFlight.ENTRY = { WIN = 2.4, LOSS = 1.8 } :: { [string]: number }

-- How long a WIN or LOSS is worn before the bird goes back to the world. Owner's number.
BirdFlight.RESULT_HOLD = 15

-- The state a bird is ACTUALLY in, given how long it has been in the one it was given. Results
-- lapse; RESTING does not. A reveal also resets every bird to RESTING regardless, so this only
-- decides what happens between rounds.
function BirdFlight.stateAfter(state: string, elapsed: number): string
    if (state == "WIN" or state == "LOSS") and elapsed > BirdFlight.RESULT_HOLD then
        return "RESTING"
    end
    return state
end

export type Point = { x: number, y: number, z: number }

-- Each held pose is an orbit: radius, height, angular speed. SAFE is the exception -- it is a
-- fixed perch, because a bird that has landed does not orbit anything.
-- ⚠ RESTING IS A PLACEHOLDER ORBIT, AND IT IS THE NEXT THING TO BUILD. Owner, 2026-08-18: birds
-- circling every head "will look like a bad cartoon where everyone just got knocked on the head".
-- A resting familiar belongs in the WORLD -- perched on a railing, a branch, a roof ridge -- near
-- its owner and ready to react, not orbiting them. Until that exists this is a holding pattern in
-- the most literal sense.
-- ⚠ WIN IS A SHOULDER PERCH AS OF 2026-08-21, AND IT OVERTURNS THE VERTICAL GRAMMAR ABOVE.
-- Owner, having seen the real mesh in play: "it's really small, almost unreadable as a bird at
-- all... perch on the player's shoulder, chirp out one of the three songs while hopping back and
-- forth on its legs. Then I can see if it reads at all as a bird and not some oversized insect."
--
-- This is a DIAGNOSTIC first and a behaviour second. A life-size bird is 0.55 studs against a
-- 5-stud avatar, and at the WIN orbit's 8.2 studs it is a speck. Height cannot rescue something
-- too small to identify -- legibility has to come before occlusion, because an unreadable bird
-- communicates nothing at any height.
--
-- ⚠ IF THE ANSWER IS "SCALE THE BIRD UP" RATHER THAN "BRING IT CLOSER", REVERT THIS and restore
-- the high orbit: the crowd-occlusion argument for vertical separation is still sound, and it is
-- what the LOSS and RESTING holds still rely on.
local SHOULDER = { x = 0.62, y = 1.05, z = -0.18 }
local HOP_PERIOD = 0.62 -- one hop; a small bird's is quick
local HOP_HEIGHT = 0.13
local HOP_SHUFFLE = 0.09 -- side to side across the shoulder, because a hop turns the bird

local HOLD = {
    RESTING = { r = 2.6, y = 3.2, speed = 1.1 },
    -- Kept though offsetFor no longer uses it: this is the high orbit to restore if the
    -- shoulder-perch diagnostic says the fix was scale, not proximity.
    WIN = { r = 3.4, y = 8.2, speed = 2.0 },
    LOSS = { r = 2.0, y = 0.9, speed = 0.55 },
}
BirdFlight.HOLD_WIN_ORBIT_Y = HOLD.WIN.y

local function orbit(t: number, seed: number, o: { r: number, y: number, speed: number }): Point
    local a = t * o.speed + seed
    return { x = math.cos(a) * o.r, y = o.y + math.sin(a * 1.7) * 0.25, z = math.sin(a) * o.r }
end

local function lerp(a: Point, b: Point, k: number): Point
    return { x = a.x + (b.x - a.x) * k, y = a.y + (b.y - a.y) * k, z = a.z + (b.z - a.z) * k }
end

-- Exported because both the tests and the controller's LOD want it, and neither should reach for
-- Vector3 to get it.
function BirdFlight.magnitude(p: Point): number
    return math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
end

function BirdFlight.distance(a: Point, b: Point): number
    -- ⚠ THE WING LIFT CEILING IS 30 DEGREES, AND IT IS A MEASUREMENT, NOT A PREFERENCE.
    -- The mesh carries a FOLDED wing, and a folded wing is short: there is no hidden wing area in
    -- there to unfold, so lifting it stretches flank surface rather than opening a wing. Measured in
    -- Blender, the panel's reach saturates -- 0.072 studs folded, 0.109 at 30 deg, 0.146 at 50,
    -- 0.171 at 70, 0.181 at 90, and 70->90 buys 0.009. Past ~50 it reads as a cape. A full spread
    -- would need a SEPARATE spread-wing mesh shown only in flight; see [[familiars]].
    -- A Blender bone constraint cannot carry this -- constraints do not survive FBX -- so the limit
    -- lives here, and the test pins it.
    BirdFlight.WING_MAX_DEG = 30

    local FLAP_RATE = 16.0 -- rad/sec in flight; ~2.5 beats a second
    local FLUTTER_PERIOD = 9.0 -- average gap between perched flutters
    local FLUTTER_BURST = 0.7 -- and how long one lasts
    local FLUTTER_PEAK = 0.55 -- a resting flutter is a twitch, not a display

    -- Deterministic 0..1 hash, so flutters are not metronomic but two clients still agree.
    local function hash01(n: number): number
        local h = math.sin(n * 12.9898) * 43758.5453
        return h - math.floor(h)
    end

    -- How far the wings are lifted, in DEGREES, as a pure function of time and seed.
    --
    -- ⚠ A PERCHED BIRD IS STILL MOST OF THE TIME. Owner, 2026-08-19: "even a perched bird flutters
    -- its wings occasionally, and certainly when arriving or leaving a perch." Occasionally is the
    -- load-bearing word -- constant fluttering reads as a distressed bird, not a resting one, so the
    -- perched case is zero except for short bursts a few seconds apart.
    function BirdFlight.wingAngle(elapsed: number, seed: number, flying: boolean): number
        if flying then
            local beat = 0.5 - 0.5 * math.cos(elapsed * FLAP_RATE + seed)
            return math.clamp(beat * BirdFlight.WING_MAX_DEG, 0, BirdFlight.WING_MAX_DEG)
        end
        local phase = elapsed / FLUTTER_PERIOD + seed
        local idx = math.floor(phase)
        local start = 0.15 + hash01(idx + seed * 7.31) * 0.6
        local t = (phase - idx - start) * FLUTTER_PERIOD
        if t < 0 or t > FLUTTER_BURST then
            return 0
        end
        local envelope = math.sin(math.pi * t / FLUTTER_BURST) -- in and out, no snap
        local beat = 0.5 - 0.5 * math.cos(t * 40) -- quick beats inside it
        local lift = FLUTTER_PEAK * envelope * beat * BirdFlight.WING_MAX_DEG
        return math.clamp(lift, 0, BirdFlight.WING_MAX_DEG)
    end

    return BirdFlight.magnitude({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z })
end

function BirdFlight.offsetFor(state: string, elapsed: number, seed: number): Point
    local idle = orbit(elapsed, seed, HOLD.RESTING)

    -- SAFE is deliberately absent and falls through to RESTING: nothing changed, so the bird does
    -- not change either.
    if state == "WIN" then
        -- LANDS ON THE SHOULDER AND HOPS. The flight in is a quick arc from wherever the bird
        -- was; after that it stays put and hops, which is the read the owner is testing for.
        local hop = elapsed / HOP_PERIOD
        local bob = math.abs(math.sin(hop * math.pi)) * HOP_HEIGHT
        -- The shuffle alternates sides every hop rather than oscillating smoothly: a bird
        -- re-plants its feet, it does not sway.
        local side = (math.floor(hop) % 2 == 0) and 1 or -1
        local perch = {
            x = SHOULDER.x + side * HOP_SHUFFLE,
            y = SHOULDER.y + bob,
            z = SHOULDER.z,
        }
        local k = math.min(1, elapsed / BirdFlight.ENTRY.WIN)
        if k >= 1 then
            return perch
        end
        local ease = 1 - (1 - k) * (1 - k) * (1 - k)
        return lerp(idle, perch, ease)
    elseif state == "LOSS" then
        -- BOLTS, THEN SINKS. Out fast and wide -- the pot was lost, not the companion -- then
        -- back to a low, slow orbit around the knees, where it stays. Low is the whole point: an
        -- idle-orbit return would make "lost" and "has not thrown yet" look identical.
        local low = orbit(elapsed, seed, HOLD.LOSS)
        local k = math.min(1, elapsed / BirdFlight.ENTRY.LOSS)
        if k >= 1 then
            return low
        end
        local away = orbit(elapsed, seed, { r = 15, y = HOLD.RESTING.y + 3.5, speed = 2.4 })
        return if k < 0.35 then lerp(idle, away, k / 0.35) else lerp(away, low, (k - 0.35) / 0.65)
    end
    return idle
end

-- ⚠ THE WING LIFT CEILING IS 30 DEGREES, AND IT IS A MEASUREMENT, NOT A PREFERENCE.
-- The mesh carries a FOLDED wing, and a folded wing is short: there is no hidden wing area in
-- there to unfold, so lifting it stretches flank surface rather than opening a wing. Measured in
-- Blender, the panel's reach saturates -- 0.072 studs folded, 0.109 at 30 deg, 0.146 at 50,
-- 0.171 at 70, 0.181 at 90, and 70->90 buys 0.009. Past ~50 it reads as a cape. A full spread
-- would need a SEPARATE spread-wing mesh shown only in flight; see [[familiars]].
-- A Blender bone constraint cannot carry this -- constraints do not survive FBX -- so the limit
-- lives here, and the test pins it.
BirdFlight.WING_MAX_DEG = 30

local FLAP_RATE = 16.0 -- rad/sec in flight; ~2.5 beats a second
local FLUTTER_PERIOD = 9.0 -- average gap between perched flutters
local FLUTTER_BURST = 0.7 -- and how long one lasts
local FLUTTER_PEAK = 0.55 -- a resting flutter is a twitch, not a display

-- Deterministic 0..1 hash, so flutters are not metronomic but two clients still agree.
local function hash01(n: number): number
    local h = math.sin(n * 12.9898) * 43758.5453
    return h - math.floor(h)
end

-- How far the wings are lifted, in DEGREES, as a pure function of time and seed.
--
-- ⚠ A PERCHED BIRD IS STILL MOST OF THE TIME. Owner, 2026-08-19: "even a perched bird flutters
-- its wings occasionally, and certainly when arriving or leaving a perch." Occasionally is the
-- load-bearing word -- constant fluttering reads as a distressed bird, not a resting one, so the
-- perched case is zero except for short bursts a few seconds apart.
function BirdFlight.wingAngle(elapsed: number, seed: number, flying: boolean): number
    if flying then
        local beat = 0.5 - 0.5 * math.cos(elapsed * FLAP_RATE + seed)
        return math.clamp(beat * BirdFlight.WING_MAX_DEG, 0, BirdFlight.WING_MAX_DEG)
    end
    local phase = elapsed / FLUTTER_PERIOD + seed
    local idx = math.floor(phase)
    local start = 0.15 + hash01(idx + seed * 7.31) * 0.6
    local t = (phase - idx - start) * FLUTTER_PERIOD
    if t < 0 or t > FLUTTER_BURST then
        return 0
    end
    local envelope = math.sin(math.pi * t / FLUTTER_BURST) -- in and out, no snap
    local beat = 0.5 - 0.5 * math.cos(t * 40) -- quick beats inside it
    local lift = FLUTTER_PEAK * envelope * beat * BirdFlight.WING_MAX_DEG
    return math.clamp(lift, 0, BirdFlight.WING_MAX_DEG)
end

return BirdFlight
