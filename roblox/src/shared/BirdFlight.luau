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
BirdFlight.ENTRY = { WIN = 2.4 } :: { [string]: number }

-- How long a WIN or LOSS is worn before the bird goes back to the world. Owner's number.
BirdFlight.RESULT_HOLD = 15

-- The state a bird is ACTUALLY in, given how long it has been in the one it was given. Results
-- lapse; RESTING does not. A reveal also resets every bird to RESTING regardless, so this only
-- decides what happens between rounds.
-- ⚠ A LOSS IS NEVER WORN AT ALL as of 2026-08-26. Owner: "no bird animation for a loss or tie."
-- Only a WIN takes the bird off its perch now, so LOSS resolves to RESTING immediately rather than
-- after RESULT_HOLD, and the controller's perch branch keeps the bird where it was.
--
-- ⚠ THIS RETIRES "A LOSS MUST NOT COME HOME", a rule that stood from 2026-08-18 on the grounds that
-- letting a loss return to the resting orbit would make "lost" and "has not thrown" identical. That
-- was true and is now beside the point: the owner has ruled the distinction is not worth an
-- animation. Do not reinstate the low orbit to restore the distinction — it was looked at in play
-- and rejected as "not in the same visual class as a bird dancing on your shoulder".
function BirdFlight.stateAfter(state: string, elapsed: number): string
    if state == "LOSS" then
        return "RESTING"
    end
    if state == "WIN" and elapsed > BirdFlight.RESULT_HOLD then
        return "RESTING"
    end
    return state
end

export type Point = { x: number, y: number, z: number }

-- Each held pose is an orbit: radius, height, angular speed. SAFE is the exception -- it is a
-- fixed perch, because a bird that has landed does not orbit anything.
-- ⚠ THE RESTING ORBIT IS NOW A FALLBACK, NOT A PLACEHOLDER -- corrected 2026-08-28. Owner,
-- 2026-08-18: birds circling every head "will look like a bad cartoon where everyone just got
-- knocked on the head", and a resting familiar belongs in the WORLD, perched on a railing or a
-- branch near its owner. THAT WAS BUILT THE SAME DAY: the controller picks a tagged
-- `FamiliarPerch` and only falls back to this orbit when none is in range -- which is also what
-- keeps birds out of buildings, since indoors has no perches.
--
-- ⚠ This comment said "the NEXT THING TO BUILD" for ten days after it was built, and on
-- 2026-08-28 it caused a session to tell the owner that perching did not exist. A note that
-- describes finished work as pending is not merely untidy: it is read and believed.
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
-- ⚠ FACES FORWARD, WITH THE AVATAR. Owner ruling 2026-08-25. This supersedes a -46 degree outboard
-- yaw that was justified two ways, and both justifications have not survived:
--   "puts the bird in profile, the only angle a small bird is identifiable from" — the owner has
--   now looked at it in play and prefers forward, which settles it; identifiability is what the
--   OWNER can read, not what a comment asserts.
--   "clears the tail from the avatar's head" — forward-facing clears it BETTER. At yaw 0 the tail
--   trails straight back behind the shoulder; at -46 it swung backward and INBOARD, toward the
--   neck. The old value was working against its own stated reason.
BirdFlight.SHOULDER_YAW = 0
-- Exported so the hop test can assert about the SHAPE of the hop without hardcoding the offset,
-- which would then need editing every time the perch is retuned.
BirdFlight.SHOULDER_X = SHOULDER.x
BirdFlight.SHOULDER_Y = SHOULDER.y
-- ⚠ WHICH CONSTANTS IN THIS FILE SURVIVE A SECOND SPECIES, AUDITED 2026-08-28.
-- Every number here was tuned against the uguisu at 0.828 studs. The karasu is 1.640 -- almost
-- exactly 2x -- so anything expressed in STUDS or SECONDS is wrong on it, while anything in
-- DEGREES is fine. This is `practice/derive-from-what-it-touches.md` applied to motion.
--
--   SAFE, scale-free .. every angle: WING_BEAT_DEG, WING_SWEEP_DEG, FOLD_SHOULDER, FOLD_WRIST,
--                      LEG_TUCK_DEG, TURN_MIN_DEG, TURN_MAX_DEG. 45 degrees is 45 degrees on a
--                      wren or an eagle.
--   ⚠ DISTANCES ..... HOP_HEIGHT (0.05) and TURN_HOP (0.06) are ABSOLUTE. On the uguisu they are
--                      6.0% and 7.2% of body length; on the karasu, 3.0% and 3.7%. A crow doing a
--                      uguisu-sized hop reads as STIFF, and it diagnoses as "the animation is
--                      wrong" rather than "the constant is absolute", which is the expensive kind
--                      of bug. Scale these LINEARLY with body length.
--   ⚠ TIMES ......... HOP_PERIOD, FLUTTER_BURST, TURN_TIME, WING_OPEN_TIME, FLIGHT_MIN_TIME.
--                      Bigger animals move SLOWER, roughly as sqrt(length) for pendulum-like
--                      motion -- so a 2x bird is about 1.41x slower, NOT 2x. Scaling times
--                      linearly overshoots into slow motion. The comment below already knew:
--                      "a small bird's is quick" was a warning written before there was a second
--                      bird.
--   TASTE, not scale . IDLE_FLUTTER_GAP and IDLE_TURN_GAP are how OFTEN a bird fidgets. A crow is
--                      plausibly more deliberate than a warbler, but that is character per
--                      species, not proportion, and it should be chosen by eye.
--
-- BUILT 2026-08-28, and this is how it works. `BirdSpecies` carries each bird's measured
-- `bodyLength`; `BirdSpecies.scaleOf` divides it by the reference bird's; `BirdFlight.profile`
-- turns that one number into the two multipliers below, and every scale-sensitive function takes
-- an optional trailing Profile. ⚠ THE UGUISU AT SCALE 1 IS BIT-IDENTICAL -- multiplying by 1.0
-- and dividing by sqrt(1) are exact in IEEE arithmetic, and a test asserts the whole surface
-- output-for-output. That property is what made this safe to land before anyone had watched a
-- karasu perch: the one bird the owner HAS watched provably did not move.
--
-- ⚠ WHAT IS DELIBERATELY NOT SCALED, so the next reader does not read restraint as an oversight:
--   the RESTING orbit ... geometry about the PLAYER, not the bird, and a fallback for "no perch
--                        in range" that the owner's perch ruling already retired from normal play.
--   SHOULDER ........... an anchor on a 5-stud avatar. The bird's origin is at its FEET, so this
--                        says where the feet go, and a shoulder does not move because the bird
--                        standing on it got bigger.
--   flightPoint's bow .. already proportional to flight distance, which is world geometry. Only
--                        its small constant terms are bird-ish, and they shape a PATH.
--   REPLAN_* ........... thresholds tied to the unscaled orbit radii; scaling one and not the
--                        other is how the replan loop of 2026-08-25 came back.
--
-- ⚠ AND THE RULE FOR GAPS, because the audit above left it half-stated. A gap that a GESTURE
-- LIVES INSIDE scales with the gesture -- LOOK_HOLD is the slot the head's snap, hold and return
-- must fit within, so a fixed slot around a stretched gesture eventually overflows and garbles
-- the pose. A gap BETWEEN INDEPENDENT EVENTS is character: IDLE_FLUTTER_GAP and IDLE_TURN_GAP
-- have nothing inside them, so how often a crow fidgets stays a choice somebody makes by eye,
-- not a consequence of a square root. Per-species character belongs on the species record, named,
-- rather than half-applied here and hidden.
export type Profile = {
    scale: number, -- body length relative to the reference bird
    linear: number, -- multiply DISTANCES by this
    time: number, -- multiply DURATIONS by this: sqrt(scale), not scale
    -- The two durations the CONTROLLER gates on. It must read them from here and never from the
    -- module fields, or a crow's turn would end on a uguisu's clock while running on its own.
    TURN_TIME: number,
    FLUTTER_BURST: number,
}

-- ⚠ sqrt, NOT linear. Bigger animals move slower roughly as the square root of length for
-- pendulum-like limbs, so a 2x bird is about 1.41x slower. Scaling times linearly overshoots
-- into slow motion, which is the mistake this function exists to make impossible to repeat.

-- Hermite smoothstep. BirdFlight had no easing helper -- the two places that ease a value inline
-- both use a cubic ease-OUT (`1 - (1-k)^3`), which is a different curve and deliberately so.
local function smoothstep(e0: number, e1: number, x: number): number
    local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
end

-- How wide the bill is open, 0 to 1, `elapsed` seconds into a clip whose caws begin at `caws`.
--
-- ⚠ THE ENVELOPE IS NOT SYMMETRIC. A crow's bill snaps open on the attack and lingers before it
-- shuts; a symmetric bump reads as a yawn. Peak lands at 30% of the window, so the open is roughly
-- twice as fast as the close.
--
-- ⚠ AND `open` MUST BE SHORTER THAN THE GAP BETWEEN CAWS. Overlap them and two calls merge into one
-- long croak, which is the failure this replaced: a fixed `sin(now * 9)` chatter that ran whenever
-- the bird was in the WIN state, whether or not it was singing and whatever clip it had chosen.
-- `BirdSpecies.CAW_GAPE_SECONDS` is 0.30 against a 0.48 minimum gap for exactly this reason.
--
-- ⚠ NOT SCALE-SENSITIVE, so it takes no profile. A caw's timing is the RECORDING's, not the bird's:
-- a bigger crow does not caw more slowly, it plays the same clip. Every other duration in this
-- module scales by sqrt(length); this one must not, or the beak drifts off the audio on any bird
-- whose scale is not 1.
-- ⚠ NOTHING CALLS THIS TODAY. The beak split and the `bill_lower` bone were retired 2026-08-30 --
-- a tomium is a curve and the plane cut could not follow it -- so no geometry opens. Kept because
-- the envelope is tested and the onsets it consumes are MEASURED off the source WAVs; both are
-- inputs the next attempt at a jaw needs, and neither depends on how the bill splits.
function BirdFlight.gapeAt(elapsed: number, caws: { number }, open: number): number
    if open <= 0 or open ~= open then
        error(`BirdFlight.gapeAt: open must be a positive number, got {open}`)
    end
    local peak = 0.3
    local best = 0
    for _, onset in caws do
        local u = (elapsed - onset) / open
        if u >= 0 and u <= 1 then
            local g
            if u <= peak then
                g = smoothstep(0, peak, u)
            else
                g = 1 - smoothstep(peak, 1, u)
            end
            if g > best then
                best = g
            end
        end
    end
    return best
end

function BirdFlight.profile(scale: number): Profile
    -- ⚠ REFUSED, not clamped. A zero or negative scale makes every duration zero and every
    -- clock a division by zero, and NaN positions surface frames later as "the bird vanished" --
    -- a diagnosis that costs a day, from a caller mistake that costs a line to report here.
    if not (scale > 0) or scale == math.huge then
        error(`BirdFlight.profile: scale must be a positive finite number, got {scale}`, 2)
    end
    local time = math.sqrt(scale)
    return {
        scale = scale,
        linear = scale,
        time = time,
        TURN_TIME = BirdFlight.TURN_TIME * time,
        FLUTTER_BURST = BirdFlight.FLUTTER_BURST * time,
    }
end

-- The reference bird's profile, so an omitted argument means "the uguisu" rather than "no scale".
-- ⚠ Read as a FIELD at call time, not captured: it is assigned at the bottom of this file,
-- because building it needs constants declared further down than the functions that use it.
local function prof(p: Profile?): Profile
    return p or BirdFlight.REFERENCE_PROFILE
end
local HOP_PERIOD = 0.62 -- one hop; a small bird's is quick
local HOP_HEIGHT = 0.05
-- ⚠ THE HOP NO LONGER MOVES THE BIRD. It used to translate the whole body 0.09 studs each way
-- across the shoulder, which read as sliding rather than hopping (owner, 2026-08-22: "change it
-- from the whole bird hopping left to right to it simply hopping between left and right legs
-- while staying in place"). The bird now stays put and the LEGS do the work -- see legPose.
local LIFT_FRACTION = 0.34 -- how much of each beat a foot spends off the perch
local BODY_ROLL = 4.5 -- degrees of lean toward the planted side

local HOLD = {
    RESTING = { r = 2.6, y = 3.2, speed = 1.1 },
    -- Kept though offsetFor no longer uses it: this is the high orbit to restore if the
    -- shoulder-perch diagnostic says the fix was scale, not proximity.
    WIN = { r = 3.4, y = 8.2, speed = 2.0 },
    -- ⚠ NO LOSS ENTRY. A loss has no animation at all as of 2026-08-26 (owner: "no bird animation
    -- for a loss or tie"), so there is no orbit to configure. The old low orbit -- r 2.0, y 0.9,
    -- speed 0.55 -- is recorded here rather than kept: it was watched in play and rejected as "not
    -- in the same visual class as a bird dancing on your shoulder", and reinstating it needs a new
    -- decision, not a rediscovered constant.
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

function BirdFlight.offsetFor(state: string, elapsed: number, seed: number, profile: Profile?): Point
    local p = prof(profile)
    -- The orbit is NOT scaled: see the note on the profile above -- it is a fallback ring about
    -- the PLAYER, and its radius has nothing to do with how long the bird is.
    local idle = orbit(elapsed, seed, HOLD.RESTING)

    -- SAFE and LOSS are deliberately absent and fall through to RESTING: nothing changed for a
    -- SAFE, and a LOSS gets no animation at all (owner, 2026-08-26). The bird does
    -- not change either.
    if state == "WIN" then
        -- LANDS ON THE SHOULDER AND HOPS. The flight in is a quick arc from wherever the bird
        -- was; after that it stays put and hops, which is the read the owner is testing for.
        local hop = elapsed / (HOP_PERIOD * p.time)
        local bob = math.abs(math.sin(hop * math.pi)) * HOP_HEIGHT * p.linear
        local perch = { x = SHOULDER.x, y = SHOULDER.y + bob, z = SHOULDER.z }
        local k = math.min(1, elapsed / (BirdFlight.ENTRY.WIN * p.time))
        if k >= 1 then
            return perch
        end
        local ease = 1 - (1 - k) * (1 - k) * (1 - k)
        return lerp(idle, perch, ease)
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
-- ⚠ TWO AXES, MEASURED 2026-08-25, not guessed. Sweeping each bone axis and logging the wingtip
-- in the bird's own frame: local X moves it 0.712 studs VERTICALLY and 0.000 fore-aft; local Z
-- moves it 0.712 FORE-AFT and 0.000 vertically; local Y runs along the span and does not move the
-- tip at all. The beat used to put its entire amplitude on Z, so the bird sculled rather than
-- flew -- and the wing visibly SHORTENED each stroke, because rotating in the horizontal plane
-- foreshortens the span (0.431 -> 0.335 at 40 degrees).
BirdFlight.WING_BEAT_DEG = 45 -- vertical, the stroke that carries the beat
BirdFlight.WING_SWEEP_DEG = 13 -- fore-aft, which TILTS the loop rather than carrying it
-- The FOLD, in degrees per bone. Measured in Blender and verified in Roblox: at these angles the
-- wing draws in against the flank; at 0/0 it is fully spread.
--
-- ⚠ THE SIGN WAS INVERTED FOR THREE DAYS AND NOTHING COULD SHOW IT. These bones rotate about a
-- local Z that runs VERTICAL, so the fold is a horizontal sweep fore-and-aft -- and at -70/-110 it
-- swept FORWARD, past the head. Measured on the live bird, part-local -Z being forward, with the
-- wingtip at the flutter's peak: spread rests at z -0.123, the old fold reached z -0.391 (0.27
-- studs beyond the head), the corrected fold reaches z +0.146 (back over the body).
--
-- It survived because the only two poses anyone had ever SEEN are the two where the sign cannot
-- matter: fully spread is 0 degrees either way, and fully folded is Transparency 1. The flutter is
-- the first thing to hold a partial fold in view, and it exposed it immediately (owner,
-- 2026-08-25: "extended forward, towards the head - actually passing it").
BirdFlight.FOLD_SHOULDER = 70
BirdFlight.FOLD_WRIST = 110
BirdFlight.WING_OPEN_TIME = 0.28 -- seconds from folded to full spread

local FLAP_RATE = 16.0 -- rad/sec in flight; ~2.5 beats a second

-- THE PERCHED FLUTTER. Owner, 2026-08-25: "a quick 'half unfold/refold' cycle a couple of times
-- that might read as a flutter", fired on events "plus a longer idle period".
BirdFlight.FLUTTER_BURST = 0.5 -- how long one flutter lasts
-- Three, not two: at two the motion read as slightly too slow to be a flutter (owner,
-- 2026-08-25, "three 'flexes' instead of two in the same amount of time"). The BURST is unchanged,
-- so this is purely a rate increase.
BirdFlight.FLUTTER_CYCLES = 3
local FLUTTER_OPEN = 0.35 -- a HALF unfold, and the reach is held where two flexes had it
local IDLE_FLUTTER_GAP = 22.0 -- background rate, jittered; was 9.0 and free-running

-- THE PERCH TURN. Owner, 2026-08-25: "a short hop that changes the direction the bird is facing".
BirdFlight.TURN_TIME = 0.25
local TURN_MIN_DEG = 35 -- under this it reads as a twitch rather than a decision
local TURN_MAX_DEG = 110 -- over it, as a spin
local TURN_HOP = 0.06 -- barely above the victory hop's 0.05; both feet leave together
local IDLE_TURN_GAP = 18.0

-- Legs are up by just after takeoff and down again well before touchdown.
BirdFlight.LEG_TUCK_DEG = 100
local TUCK_IN_END = 0.22
local TUCK_OUT_START = 0.78
-- Openness at which the wing is fully opaque. Takeoff crosses this in ~40ms, so flight is
-- unaffected; it exists so a PERCHED flutter fades in instead of popping.
local WING_FADE_IN = 0.15

-- Deterministic 0..1 hash, so flutters are not metronomic but two clients still agree.
local function hash01(n: number): number
    local h = math.sin(n * 12.9898) * 43758.5453
    return h - math.floor(h)
end

-- How much each foot is lifted (0 planted, 1 fully up) and how far the body leans, in degrees.
--
-- ⚠ A BIRD NEVER LIFTS BOTH FEET WHILE PERCHED -- that is letting go of the branch, and a test
-- pins it. The feet alternate on the hop clock, each spending only a third of its beat in the
-- air, and the body ROLLS toward whichever foot is planted. That roll is what makes this read as
-- weight shifting rather than as legs twitching independently of the bird above them.
function BirdFlight.legPose(elapsed: number, seed: number, profile: Profile?): (number, number, number)
    local phase = elapsed / (HOP_PERIOD * prof(profile).time) + seed * 0.37
    local beat = math.floor(phase)
    local into = phase - beat
    local lift = 0
    if into < LIFT_FRACTION then
        lift = math.sin(math.pi * into / LIFT_FRACTION)
    end
    local leftUp = (beat % 2 == 0)
    local l = if leftUp then lift else 0
    local r = if leftUp then 0 else lift
    -- lean AWAY from the raised foot, i.e. onto the one still holding on
    local roll = (if leftUp then -1 else 1) * lift * BODY_ROLL
    return l, r, roll
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
-- How far a destination must move MID-FLIGHT before it counts as a genuinely new destination
-- rather than a target that is merely drifting. Must exceed the widest orbit's diameter (RESTING,
-- r 2.6, so 5.2 across) or drift masquerades as a destination change.
BirdFlight.REPLAN_INTERRUPT = 8
local REPLAN_MOVED = 0.35 -- once arrived, this much movement is a new place to fly to

-- Should the bird tear up its current route and plan a new one?
--
-- ⚠ A FLIGHT IN PROGRESS IS NOT TORN UP BY A DRIFTING TARGET, and that is the whole point of this
-- function. A result-state orbit MOVES: LOSS orbits at radius 2.0 and speed 0.55, so it slides 1.1
-- studs a second and crossed the old flat 0.35 threshold every ~0.32s -- while the flight that
-- triggered lasted ~0.88s. The flight could never finish, so `k` never reached 1, so the
-- arrive-and-track branch never engaged, so it replanned forever. Each replan also re-rolled the
-- path shape, so the bird restarted its takeoff three times a second along a randomly changing arc
-- (owner, 2026-08-25: "jerking around between many orientations and locations").
--
-- Perch-to-perch travel is unaffected: the bird arrives, and THEN a new perch is a new destination.
function BirdFlight.shouldReplan(arrived: boolean, drift: number): boolean
    if drift > BirdFlight.REPLAN_INTERRUPT then
        return true -- a real change of destination, worth abandoning the route for
    end
    return arrived and drift > REPLAN_MOVED
end

function BirdFlight.flightDuration(distance: number, profile: Profile?): number
    -- CRUISE_SPEED is a distance over a time, so it goes as linear/time; the floor is a time. A
    -- bird twice as long crossing twice the distance therefore takes 1.41x as long, not 2x.
    local p = prof(profile)
    local speed = BirdFlight.CRUISE_SPEED * p.linear / p.time
    return BirdFlight.FLIGHT_MIN_TIME * p.time + math.max(0, distance) / speed
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
    -- ⚠ THE ARC IS A FUNCTION OF ALONG, NOT OF t, AND THAT IS THE WHOLE DIFFERENCE. `along` is the
    -- integral of a speed profile, so it is near zero at the start -- the bird launches from rest
    -- on a perch. Driving the climb off raw t while horizontal progress crawled put the bird, at
    -- 10% of the flight, twice as high as it was far along: it went up like a rocket and then
    -- turned toward the target (owner, 2026-08-25). Tying rise to DISTANCE COVERED makes the climb
    -- proportional to progress, which is what an arc is.
    local rp = if along < risePeak
        then along / risePeak * 0.5
        else 0.5 + (along - risePeak) / (1 - risePeak) * 0.5
    local rise = math.sin(math.pi * rp) * bow

    -- SIDE: only CIRCLE leaves the straight line. Owner: "maybe sometimes a half circle around
    -- the perch while spotting the landing zone" -- so the swing peaks LATE, near the target.
    local side = 0
    if shape == "CIRCLE" then
        local radius = math.min(6.0, 0.42 * distance + 1.2)
        side = math.sin(math.pi * along ^ 0.75) * radius -- along, for the same reason as rise
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
function BirdFlight.idlePose(elapsed: number, seed: number, profile: Profile?): (number, number, number)
    -- ⚠ THE WHOLE IDLE IS ONE TIME DILATION, applied once to the input rather than to five
    -- separate constants. Every clock in here -- the look slot, the snap, the check hold, the
    -- tail's period and stroke -- is a duration, and they are structurally coupled: the snap and
    -- its return must FIT INSIDE the slot, so stretching one without the other eventually
    -- overflows and garbles the pose. Dividing the input keeps them in step by construction, and
    -- makes the guarantee exact: a bigger bird runs the identical motion on a slower clock, and
    -- no angle changes. Head yaw is 62 degrees on a wren and on an eagle.
    local clock = elapsed / prof(profile).time
    -- Slots of ~LOOK_HOLD, each with its own target. Jittered per slot so the rhythm is not a
    -- metronome, which is the other way a fake idle gives itself away.
    local phase = clock / LOOK_HOLD + seed
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
    local tphase = clock / TAIL_PERIOD + seed * 0.61
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
function BirdFlight.wingExtension(elapsed: number, seed: number, flying: boolean, profile: Profile?): number
    if not flying then
        return 0
    end
    local span = BirdFlight.WING_OPEN_TIME * prof(profile).time * (0.85 + 0.30 * hash01(seed))
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
-- The wingbeat, as TWO bone angles in degrees: vertical (local X, positive = DOWN) and fore-aft
-- (local Z, negative = FORWARD). Both zero when perched.
--
-- ⚠ THEY ARE 90 DEGREES OUT OF PHASE, AND THAT IS THE WHOLE POINT. Owner, 2026-08-25: "in actual
-- flight it's both - forward and up, backward and down". Compound, yes -- and the pairing runs the
-- other way, because the DOWNSTROKE is the power stroke and sweeps forward as it descends, the
-- upstroke recovering back and up. So fore-aft tracks the DIRECTION of vertical travel (its
-- derivative), not its position: sin for the stroke, cos for the sweep. In phase, the tip would
-- trace a straight diagonal and retrace it -- a line, not a loop, and worse than the single axis
-- this replaced.
--
-- ⚠ MIRRORING DIFFERS PER AXIS, also measured: local X does NOT mirror (-30 raises BOTH wings),
-- local Z DOES (forward is -Z on the right, +Z on the left). Guessing would have had one wing
-- rise while the other fell.
function BirdFlight.beatPose(
    elapsed: number,
    seed: number,
    flying: boolean,
    profile: Profile?
): (number, number)
    if not flying then
        return 0, 0
    end
    -- ⚠ A RATE IS A RECIPROCAL TIME, so it is DIVIDED by the time multiplier, not multiplied.
    -- The audit that classified this file's constants missed FLAP_RATE entirely; left alone, a
    -- crow flaps at a warbler's 2.5 beats a second, which is the exact "the animation is wrong"
    -- misdiagnosis the audit was written to prevent. The AMPLITUDES stay put -- they are angles.
    local q = elapsed * (FLAP_RATE / prof(profile).time) + seed
    return BirdFlight.WING_BEAT_DEG * math.sin(q), -BirdFlight.WING_SWEEP_DEG * math.cos(q)
end

-- How far open the wings are during a perched flutter, given seconds SINCE THAT FLUTTER BEGAN.
-- 0 outside the burst, and 0 again at its midpoint -- the refold is half the point.
--
-- ⚠ THIS DRIVES THE FOLD CHANNEL, NOT THE LIFT CHANNEL, AND THAT IS THE WHOLE FIX. The flutter
-- used to be a lift burst inside `wingAngle`, which nothing could ever see: `wingExtension`
-- returns 0 whenever the bird is not flying, and Transparency follows openness, so the wings were
-- invisible for the entire burst. Unfolding is what makes the wing appear, so the flutter has to
-- BE an unfold. Half open, twice, per the owner (2026-08-25).
--
-- WHEN a flutter happens is the CONTROLLER's business -- it fires them on landing and on a win,
-- and otherwise on `nextFlutterGap`. This function owns only the shape.
function BirdFlight.flutterExtension(t: number, seed: number, profile: Profile?): number
    local burst = prof(profile).FLUTTER_BURST
    if t <= 0 or t >= burst then
        return 0
    end
    local u = t / burst
    -- ⚠ FLATTENED (^0.5). A plain sine envelope over THREE flexes makes the middle one twice the
    -- reach of its neighbours, which reads as one flex with a stutter either side rather than
    -- three. The root pulls the shoulders up while still tapering both ends to zero.
    local envelope = math.sin(math.pi * u) ^ 0.5
    local cycle = 0.5 - 0.5 * math.cos(2 * math.pi * BirdFlight.FLUTTER_CYCLES * u)
    local reach = FLUTTER_OPEN * (0.85 + 0.30 * hash01(seed)) -- fifty birds, fifty flutters
    return reach * envelope * cycle
end

-- Seconds until the NEXT idle flutter. Longer than the old 9-second free-run, because landing and
-- winning now fire flutters directly and a bird that also twitches every nine seconds reads as
-- distressed rather than resting.
function BirdFlight.nextFlutterGap(seed: number, index: number): number
    return IDLE_FLUTTER_GAP * (0.7 + 0.9 * hash01(index * 3.77 + seed * 7.31))
end

-- How far this turn goes, in SIGNED degrees. Jittered in both magnitude and side, because a fixed
-- quarter-turn reads as a mechanism and a bird that only ever turns one way reads as broken.
-- How far the legs are tucked, 0 (standing) to 1 (folded up into the belly), across a flight.
--
-- ⚠ MEASURED, 2026-08-25: rotating the hip +100 degrees about its local X lifts the foot 0.280
-- studs, from y -0.281 to -0.001, and puts EVERY joint of the leg chain inside the body's bounding
-- box (protrusion 0.000). At rest the foot protrudes 0.045 below, which is correct -- feet should
-- show on a perch. So no knee fold is needed: the hip alone folds the whole leg into the flank.
--
-- Owner, 2026-08-25: "the fixed legs make it look like a plane flying with the wheels down... then
-- extended right before landing". Gear down BEFORE touchdown, not at it.
function BirdFlight.legTuck(k: number): number
    local t = math.clamp(k, 0, 1)
    local up = math.clamp(t / TUCK_IN_END, 0, 1)
    local down = math.clamp((1 - t) / (1 - TUCK_OUT_START), 0, 1)
    local v = math.min(up, down)
    return v * v * (3 - 2 * v)
end

function BirdFlight.turnAmount(seed: number, index: number): number
    local mag = TURN_MIN_DEG + (TURN_MAX_DEG - TURN_MIN_DEG) * hash01(index * 5.13 + seed * 2.71)
    return if hash01(index * 9.41 + seed * 4.07) < 0.5 then -mag else mag
end

-- Progress (0..1) and hop height (studs) for a turn, given seconds since it began.
--
-- ⚠ THE CALLER MUST DRIVE THIS FROM ABSOLUTE STORED ANGLES, not by adding an offset to the bird's
-- current facing. The perched branch of the controller derives its heading by reading the bird's
-- OWN LookVector back each frame, so an incremental turn would compound into a spin. Capture
-- `from` and `to` once when the turn starts and interpolate between them.
function BirdFlight.turnPose(t: number, profile: Profile?): (number, number)
    local p = prof(profile)
    if t <= 0 then
        return 0, 0
    end
    if t >= p.TURN_TIME then
        return 1, 0 -- ⚠ hop returns to ZERO, or the bird is left standing in the air
    end
    local u = t / p.TURN_TIME
    -- Progress is scale-free; the hop is a DISTANCE, and at an absolute 0.06 it was 7.2% of the
    -- uguisu but 3.7% of the karasu -- a crow barely leaving the rail reads as stiff.
    return u * u * (3 - 2 * u), math.sin(math.pi * u) * TURN_HOP * p.linear
end

-- Seconds until the next idle turn. Deliberately NOT a multiple of the flutter gap: two habits on
-- a shared period would always fire together and read as one compound move.
function BirdFlight.nextTurnGap(seed: number, index: number): number
    return IDLE_TURN_GAP * (0.65 + 0.95 * hash01(index * 6.29 + seed * 1.87))
end

-- Wing Transparency for a given openness.
--
-- ⚠ NOT BINARY, and the reason is geometric: at the best fold 93 of 208 wing verts are still
-- OUTSIDE the body, so the wings are hidden by Transparency rather than by being tucked. Flipping
-- it at open > 0 therefore pops a fully-formed tucked wing into existence in one frame -- fine
-- mid-takeoff where motion covers it, glaring on a stationary perched bird. Landing still snaps
-- shut, because `wingExtension` drops openness to 0 in a single step.
function BirdFlight.wingTransparency(open: number): number
    return 1 - math.clamp(open / WING_FADE_IN, 0, 1)
end

-- How far OUTBOARD to shift a perched bird's feet, in studs, so its body does not crowd the
-- avatar's neck. Both widths are the birds' own measured `Size.X`.
--
-- ⚠ THE SEAT SAYS WHERE THE FEET GO; THE BODY IS WHAT CROWDS THE HEAD. The controller's
-- SEAT_INBOARD is a proportion of the AVATAR's arm and is right to stay one -- a shoulder does
-- not move because the bird standing on it got bigger. But the bird is centred on its feet, so a
-- bird half a width wider reaches that much further inboard from an identical footprint, and that
-- is what the owner saw on 2026-08-28: "shoulder seat is a little tight to the head".
--
-- Hold the bird's INNER EDGE where the reference bird's sat and the correction is just the
-- difference of two half-widths -- no tuning constant, and EXACTLY ZERO for the reference bird,
-- whose seat the owner gated.
--
-- ⚠ TAKE THE REFERENCE WIDTH, DO NOT INFER IT FROM SCALE. The first version of this used
-- `width / scale`, assuming a bigger bird is a scaled one. Measured in the live place: the karasu
-- is 1.98x the uguisu in length, 1.90x in height and only 1.47x in WIDTH. Birds are not scaled
-- copies of each other, and the assumption over-relieved by about a third of an inch. Both
-- templates are in `ReplicatedStorage.RoshamboBirds` at once, so there is nothing to infer.
function BirdFlight.seatRelief(bodyWidth: number, referenceWidth: number): number
    return (bodyWidth - referenceWidth) * 0.5
end

-- ⚠ ASSIGNED HERE, AT THE BOTTOM, ON PURPOSE. `profile` reads TURN_TIME and FLUTTER_BURST,
-- which are declared further down this file than the functions that need the reference -- so it
-- cannot be built at the point it is explained. `prof()` looks it up as a field at CALL time,
-- by which point module load has finished and this line has run.
BirdFlight.REFERENCE_PROFILE = BirdFlight.profile(1)

return BirdFlight
