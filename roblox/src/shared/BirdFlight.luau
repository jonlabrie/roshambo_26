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
-- ⚠ THE Z SIGN CAUGHT ME OUT: in Roblox -Z IS FORWARD, so the z = -0.42 that shipped here put
-- the bird 0.42 studs IN FRONT of the shoulder, hovering off the body -- owner, 2026-08-22:
-- "perched in mid-air, about 6 inches up and forward of my shoulder". The comment that used to
-- sit here claimed it was BEHIND. It did clear the tail from the avatar's head, but only by
-- accident, by moving the whole bird away.
--
-- The bird now sits ON the shoulder, and the tail is cleared the right way instead: by yawing it
-- further outboard (see SHOULDER_YAW) so the tail swings away from the head rather than the whole
-- bird standing off.
local SHOULDER = { x = 0.86, y = 1.00, z = -0.06 }
BirdFlight.SHOULDER_YAW = -46 -- degrees outboard; also puts the bird in profile, which is the
-- only angle a small bird is identifiable from
-- Exported so the hop test can assert about the SHAPE of the hop without hardcoding the offset,
-- which would then need editing every time the perch is retuned.
BirdFlight.SHOULDER_X = SHOULDER.x
BirdFlight.SHOULDER_Y = SHOULDER.y
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

-- ⚠ THE BIRD HAS TWO WINGS AND THEY NEVER COEXIST. A FOLDED wing is sculpted into the flank and
-- painted with its covert edge -- that is the accurate one, and it is what shows for the ~90% of
-- the time the bird is perched. A SPREAD wing is bound to `wing_R`/`wing_L` and exists only in
-- flight. Because they are never both visible, neither has to compromise for the other.
--
-- ⚠ PERCHING DOES NOT FOLD THE SPREAD WING -- IT COLLAPSES IT. One rigid bone can rotate but
-- cannot SHORTEN, and a real wing folds at the wrist; swept back 88 degrees the tip still reached
-- 0.37 studs against a 0.112 body half-width, swinging forward past the head instead of tucking.
-- Scaling the bone draws every wing vertex home to the shoulder: measured, scale 0.06 puts the
-- tip at 0.078 -- inside the body -- so the modelled folded wing is all that remains.
--
-- The old 30-degree lift ceiling is GONE. It was measured against the folded wing's stretch limit
-- (its reach saturated at 0.181 studs and past ~50 degrees it read as a cape), and nothing lifts
-- that geometry any more. A real spread wing wants a real beat.
BirdFlight.WING_MAX_DEG = 55
-- The FOLD, in degrees per bone. Measured in Blender and verified in Roblox: at these angles the
-- wing draws in against the flank; at 0/0 it is fully spread.
BirdFlight.FOLD_SHOULDER = -70
BirdFlight.FOLD_WRIST = -110
BirdFlight.WING_OPEN_TIME = 0.28 -- seconds from folded to full spread

local FLAP_RATE = 16.0 -- rad/sec in flight; ~2.5 beats a second
local FLUTTER_PERIOD = 9.0 -- average gap between perched flutters
local FLUTTER_BURST = 0.7 -- and how long one lasts
local FLUTTER_PEAK = 0.55 -- a resting flutter is a twitch, not a display

-- Deterministic 0..1 hash, so flutters are not metronomic but two clients still agree.
local function hash01(n: number): number
    local h = math.sin(n * 12.9898) * 43758.5453
    return h - math.floor(h)
end

-- ===== FLIGHT =====
-- ⚠ THE BIRD USED TO SLIDE. Movement was a speed-capped lerp straight at the target: full speed
-- on frame one, dead stop on arrival, no arc. Owner, 2026-08-22: "flying very fast between
-- perches, there doesn't seem to be a smooth ramp... literally looks like the bird is sliding
-- sideways down the rail." Three separate faults, all from that one line —
--   * no ramp, because a speed cap has no acceleration;
--   * the SLIDE, because a short hop finished inside one or two frames, so the branch that turns
--     the bird to face its heading never got to run for long enough to see;
--   * invisible wings, because a 20-stud crossing took ~0.6s and the wings need 0.28s to open.
--
-- So a flight is now a SHAPED PATH over a MINIMUM DURATION, in three phases.
BirdFlight.FLIGHT_MIN_TIME = 0.85 -- even a hop to the next spot on the same rail takes this long
BirdFlight.CRUISE_SPEED = 11 -- studs/sec. A real songbird does ~33, which at 0.83 studs long is
-- 40 body-lengths a second and reads as teleporting. Believable speed is the wrong target here.
local TAKEOFF_END = 0.20
local LANDING_START = 0.68 -- landing is the LONGEST phase: the flare is what sells the arrival

-- Which phase of a flight, given progress 0..1.
function BirdFlight.flightPhase(k: number): string
    if k < TAKEOFF_END then
        return "TAKEOFF"
    elseif k < LANDING_START then
        return "CRUISE"
    end
    return "LANDING"
end

-- How long a flight of this distance should take. The floor is what stops a short hop finishing
-- before the eye can register it.
function BirdFlight.flightDuration(distance: number): number
    return BirdFlight.FLIGHT_MIN_TIME + math.max(0, distance) / BirdFlight.CRUISE_SPEED
end

-- Which shape this bird flies on its Nth flight. Deterministic, so two clients agree.
function BirdFlight.flightShape(seed: number, index: number): string
    local r = hash01(index * 3.41 + seed * 11.7)
    if r < 0.34 then
        return "ARC"
    elseif r < 0.55 then
        return "CIRCLE"
    end
    return "DIRECT"
end

-- Where along the flight the bird is, at progress k.
-- Returns `along` (0..1 of the straight line between perches), `side` and `rise` (studs off it).
--
-- ⚠ THE EASE IS DELIBERATELY ASYMMETRIC. A bird leaves a perch hard and arrives slowly: it
-- accelerates in a couple of wingbeats, then bleeds speed into a flare. A symmetric smoothstep
-- reads as a lift on rails.
function BirdFlight.flightPoint(k: number, distance: number, shape: string): (number, number, number)
    local t = math.min(1, math.max(0, k))
    -- ⚠ `along` IS THE INTEGRAL OF A SPEED PROFILE, not an eased position curve, and it is tied
    -- to the phase boundaries so the two can never disagree. Speed ramps 0 -> 1 across TAKEOFF,
    -- holds through CRUISE, and bleeds 1 -> 0 across LANDING. That makes the bird start from rest
    -- (it is sitting on a perch) and arrive slowly (a flare), which is what "no smooth ramp" was
    -- asking for. Closed form rather than a numeric integral: this runs per bird per frame.
    --   s(u) = u^2(3-2u)      smoothstep
    --   ∫₀ˣ s = x³ - x⁴/2
    local a, bnd = TAKEOFF_END, LANDING_START
    local total = a * 0.5 + (bnd - a) + (1 - bnd) * 0.5
    local dist
    if t < a then
        local x = t / a
        dist = a * (x * x * x - 0.5 * x * x * x * x)
    elseif t < bnd then
        dist = a * 0.5 + (t - a)
    else
        local x = (t - bnd) / (1 - bnd)
        local w = 1 - x
        dist = a * 0.5 + (bnd - a) + (1 - bnd) * (0.5 - (w * w * w) + 0.5 * (w * w * w * w))
    end
    local along = dist / total

    -- RISE: every flight bows upward, so none of them is a flat drag across the ground.
    local bow = math.min(2.6, 0.16 * distance + 0.35)
    local risePeak = 0.5
    if shape == "ARC" then
        bow = math.min(4.5, 0.30 * distance + 0.6)
        risePeak = 0.42 -- climbs early, then a long glide down
    end
    local rp = if t < risePeak then t / risePeak * 0.5 else 0.5 + (t - risePeak) / (1 - risePeak) * 0.5
    local rise = math.sin(math.pi * rp) * bow

    -- SIDE: only CIRCLE leaves the straight line. Owner: "maybe sometimes a half circle around
    -- the perch while spotting the landing zone" -- so the swing peaks LATE, near the target.
    local side = 0
    if shape == "CIRCLE" then
        local radius = math.min(6.0, 0.42 * distance + 1.2)
        side = math.sin(math.pi * t ^ 0.75) * radius
    end
    return along, side, rise
end

-- ===== IDLE =====
-- ⚠ A PERCHED BIRD IS ~90% OF VIEWING TIME AND IT WAS DOING NOTHING AT ALL (owner, 2026-08-22:
-- "the bird does nothing while perched"). This is the cheapest sign of life in the whole
-- familiar, and it is worth more than the flight it sits between.
--
-- ⚠ THE HEAD SNAPS AND HOLDS. It does not sweep. A bird's head jumps to a new angle in about a
-- tenth of a second, holds for a second or two, and jumps again -- a smooth pan reads as a
-- security camera, not an animal. A test pins that the head is STILL for most of any sample,
-- which is the property that makes it read as a bird.
BirdFlight.HEAD_YAW_MAX = 62 -- degrees; a small bird turns further than this, but past it the
BirdFlight.HEAD_PITCH_MAX = 18 -- neck geometry shears rather than rotates
BirdFlight.LOOK_HOLD = 1.55 -- average seconds between head moves
local LOOK_HOLD = BirdFlight.LOOK_HOLD
local LOOK_SNAP = 0.11 -- and how long the move itself takes
-- ⚠ A CHECK IS A LOOK THAT COMES STRAIGHT BACK. Owner, 2026-08-22: "head twists left to check
-- something, then immediately returns to where it was." Without it every move commits to a new
-- heading and the bird reads as slowly rotating over time rather than REACTING to things.
local CHECK_CHANCE = 0.42
local CHECK_HOLD = 0.30 -- how long it looks before returning
local TAIL_PERIOD = 5.2 -- warblers flick the tail constantly; this is the average gap
local TAIL_STROKE = 0.28 -- one flick, down and back
local TAIL_MAX = 9 -- degrees

-- Where a perched bird is looking, and what its tail is doing, at time `elapsed`.
-- Returns head yaw, head pitch and tail pitch, all in DEGREES. Pure and seed-deterministic, so
-- two clients watching the same bird see the same idle.
function BirdFlight.idlePose(elapsed: number, seed: number): (number, number, number)
    -- Slots of ~LOOK_HOLD, each with its own target. Jittered per slot so the rhythm is not a
    -- metronome, which is the other way a fake idle gives itself away.
    local phase = elapsed / LOOK_HOLD + seed
    local slot = math.floor(phase)
    local function isCheck(i: number): boolean
        return hash01(i * 4.13 + seed * 7.77) < CHECK_CHANCE
    end
    local function draw(i: number): (number, number)
        local a = hash01(i * 1.37 + seed * 5.11)
        local b = hash01(i * 2.71 + seed * 3.19)
        return (a * 2 - 1) * BirdFlight.HEAD_YAW_MAX, (b * 2 - 1) * BirdFlight.HEAD_PITCH_MAX
    end
    -- Where the head RESTS at the end of slot i. A check ends where it began, so it inherits the
    -- last committed pose -- walk back to find it, bounded so this stays a pure O(1)-ish lookup.
    local function restPose(i: number): (number, number)
        for back = 0, 8 do
            if not isCheck(i - back) then
                return draw(i - back)
            end
        end
        return draw(i - 8)
    end

    local fromYaw, fromPitch = restPose(slot - 1)
    local into = (phase - slot) * LOOK_HOLD
    local yaw, pitch

    if isCheck(slot) then
        -- OUT, hold briefly, BACK. The return is the whole point.
        local toYaw, toPitch = draw(slot)
        local outK = math.min(1, math.max(0, into / LOOK_SNAP))
        local backStart = LOOK_SNAP + CHECK_HOLD
        local backK = math.min(1, math.max(0, (into - backStart) / LOOK_SNAP))
        local eOut = 1 - (1 - outK) * (1 - outK) * (1 - outK)
        local eBack = 1 - (1 - backK) * (1 - backK) * (1 - backK)
        local peakYaw = fromYaw + (toYaw - fromYaw) * eOut
        local peakPitch = fromPitch + (toPitch - fromPitch) * eOut
        yaw = peakYaw + (fromYaw - peakYaw) * eBack
        pitch = peakPitch + (fromPitch - peakPitch) * eBack
    else
        local toYaw, toPitch = restPose(slot)
        local k = math.min(1, math.max(0, into / LOOK_SNAP))
        local ease = 1 - (1 - k) * (1 - k) * (1 - k)
        yaw = fromYaw + (toYaw - fromYaw) * ease
        pitch = fromPitch + (toPitch - fromPitch) * ease
    end

    -- The tail flick is on its own clock, so it does not always land with a head turn.
    local tphase = elapsed / TAIL_PERIOD + seed * 0.61
    local tslot = math.floor(tphase)
    local start = 0.1 + hash01(tslot + seed * 9.7) * 0.7
    local tinto = (tphase - tslot - start) * TAIL_PERIOD
    local tail = 0
    if tinto >= 0 and tinto <= TAIL_STROKE then
        -- one stroke: down and back, never a wag
        tail = math.sin(math.pi * tinto / TAIL_STROKE) * TAIL_MAX
    end
    return yaw, pitch, tail
end

-- How far the wings are OPEN: 0 folded, 1 fully spread. The controller turns this into the two
-- fold angles and into the wings part's Transparency.
--
-- ⚠ THIS USED TO RETURN A BONE SCALE AND THAT WAS UNSHIPPABLE. `Bone.Transform` DISCARDS SCALE in
-- Roblox -- measured, set 0.06 and it reads back 1.0000, because a bone transform is rigid by
-- definition. Rotation and translation survive; scale cannot. The tests passed anyway, because
-- they only asserted the number this function returned and never that Roblox honoured it.
--
-- ⚠ AND FOLDING ALONE CANNOT HIDE A WING. Measured: at the best fold, 93 of 208 wing vertices are
-- still outside the body. The wings are therefore a SEPARATE MeshPart whose Transparency the
-- controller drives -- owner, 2026-08-22: wings "should completely disappear when the bird is
-- perched/at rest... only unfold when the bird takes flight".
--
-- Opening is eased with per-bird jitter so fifty birds do not spread as one. Closing is INSTANT,
-- on purpose: the owner asked for wings that "quickly fold in and disappear when it lands", and
-- easing shut would leave a perched bird holding its wings half-open.
function BirdFlight.wingExtension(elapsed: number, seed: number, flying: boolean): number
    if not flying then
        return 0
    end
    local span = BirdFlight.WING_OPEN_TIME * (0.85 + 0.30 * hash01(seed))
    local k = math.min(1, math.max(0, elapsed / span))
    return 1 - (1 - k) * (1 - k) * (1 - k)
end

-- The two fold angles for a given openness, in DEGREES. Folded at 0, spread at 1.
function BirdFlight.foldAngles(open: number): (number, number)
    local k = math.min(1, math.max(0, open))
    return BirdFlight.FOLD_SHOULDER * (1 - k), BirdFlight.FOLD_WRIST * (1 - k)
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
