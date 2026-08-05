--!strict
-- Pure index math for the World-Throw drum. 12 facets 0..11 around the vertical
-- axis; face index % 3 → symbol (0=R, 1=P, 2=S). R,P,S repeats FOUR times around the
-- ring, so a symbol recurs every 3 facets (90°) and all four windows (90° apart)
-- show the same symbol at every detent.
local DrumStep = {}

local FACES = 12
local SYMBOLS = { R = 0, P = 1, S = 2 }

-- ===== The strike-to-rest timing =====
-- These used to be private literals in DrumController (SPIN_SEC/GLIDE_SEC) and HammerController (the
-- 0.45s forward swing). They live here now because a THIRD party needs them: the server schedules
-- the winner's avatar grow, and a grow that lands while the drum is still turning announces the
-- result before the drum does — the exact spoiler the client's `drumRest` gate exists to prevent.
-- `drumRest` is a client cue, so the server cannot listen for it; it can only wait the same span,
-- and it must wait the REAL span rather than a guess that drifts the first time the choreography is
-- retimed.
--
-- The chain, from the scheduled strike instant:
--   STRIKE_SWING : the shu-moku's forward swing. `gongHit` (and with it the drum's kick) fires at
--                  CONTACT, at the end of this tween, not when the swing starts.
--   SPIN         : the constant-velocity spin before the drum will consider landing.
--   GLIDE        : the decelerating glide onto the detent. `drumRest` fires when it completes.
-- SETTLE_SECONDS is the NORMAL chain only. The stall (STALL_MAX_SECONDS, below) is deliberately not
-- folded into it: it is an exception path, and padding every round by it would make the grow late
-- for everyone to cover a case that hardly ever happens.
DrumStep.STRIKE_SWING_SECONDS = 0.45
DrumStep.SPIN_SECONDS = 1.0
DrumStep.GLIDE_SECONDS = 2.0
DrumStep.SETTLE_SECONDS = DrumStep.STRIKE_SWING_SECONDS + DrumStep.SPIN_SECONDS + DrumStep.GLIDE_SECONDS

-- ===== The stall, and the reveal-safety windows derived from it =====
-- THE STALL. If the World Throw has not reached the client by the end of the spin, DrumController
-- keeps spinning for up to this long, waiting for it, before it settles on the last one anyway.
-- It was a private literal in that client file; it lives here because the fallback below is sized
-- from it and a fallback sized from a number no test can see is a fallback that silently rots.
DrumStep.STALL_MAX_SECONDS = 6

-- THE REVEAL-SAFETY FALLBACK. main.client.luau holds the round's result until `drumRest`, with a
-- fallback so a dropped cue cannot strand it forever. That fallback used to be a flat 3s armed from
-- RevealResult ARRIVING — an unrelated constant, measured from an unrelated event — and it beat the
-- drum on every instrumented round (RevealResult t=8.28s, ring glyph t=11.31s = 8.28 + 3.00 + a
-- frame), which is precisely the spoiler THE RULE forbids. It is armed from the STRIKE now and sized
-- from the choreography above, so it cannot precede the rest it is protecting:
--   SAFETY_AFTER_STRIKE_SECONDS          the World Throw is already in hand at the strike, so the
--                                        drum CANNOT stall; rest is the normal chain away.
--   SAFETY_AFTER_STRIKE_STALLED_SECONDS  the throw has not arrived yet, so the drum may wait out
--                                        the whole stall before it even begins to glide.
-- Both are measured from `gongHit`, which fires at the END of the swing — so re-counting
-- STRIKE_SWING_SECONDS inside SETTLE_SECONDS is free headroom in the safe direction, on top of the
-- explicit margin. The margin itself covers the frame the cue is dispatched on and the client's
-- phase-poll lag.
DrumStep.SAFETY_MARGIN_SECONDS = 0.5
DrumStep.SAFETY_AFTER_STRIKE_SECONDS = DrumStep.SETTLE_SECONDS + DrumStep.SAFETY_MARGIN_SECONDS
DrumStep.SAFETY_AFTER_STRIKE_STALLED_SECONDS = DrumStep.SAFETY_AFTER_STRIKE_SECONDS
    + DrumStep.STALL_MAX_SECONDS

-- The spin's angular velocity, rad/s — DrumController's old private `DRUM_KICK`, here for the same
-- reason as the durations above. DrumController still honours the "DrumKick" stage attribute,
-- which OVERRIDES this at `gongHit` and can retune the drum's spin at runtime; a private local in
-- that client file could be retuned with no test able to see it, which is why the base value lives
-- here instead, where DrumStep.spec can pin it down.
DrumStep.KICK_OMEGA = 4

-- How the glide's own curve behaves — descriptive only; nothing in this module computes it.
--
-- DrumController drives the glide as
--     θ(s) = θ₀ − d·(3s² − 2s³) − ω·G·(s³ − 2s² + s),   landing at θ₀ − d,
-- for normalised progress s ∈ [0,1], travel d and the LIVE angular velocity ω entering the glide
-- (not KICK_OMEGA — a "DrumKick" stage override changes ω without touching this constant).
--
-- IT IS A HERMITE, NOT A BARE SMOOTHSTEP — a smoothstep PLUS the spin's exit velocity carried into
-- the glide, because ω is not zeroed until the glide completes. (This header used to claim a plain
-- smoothstep and misled a reader: the smoothstep alone reads 72% travelled where the real curve
-- reads 83-88%.) Note s³ − 2s² + s = s(1−s)², non-negative on [0,1], so the carried term only ever
-- brings the drum home sooner. θ(0) = θ₀ exactly; θ(1) = θ₀ − d exactly.
--
-- HOW MUCH ANGLE IS STILL OWED at a given s used to be computed here, feeding a splash cue that
-- fired before the drum stopped turning. The owner ruled (2026-08-04) that the drum is
-- authoritative: nothing may reflect the world's throw anywhere else until it is fully at rest.
-- There is no longer a question for that computation to answer, so it is gone — do not rebuild it.
-- `drumRest`, fired once the glide reaches s = 1, is the only signal anything outside this module
-- should wait on.

-- the low face index (0..2) carrying this throw's symbol
function DrumStep.faceForThrow(throw: string): number
    return SYMBOLS[throw] or 0
end

-- the next same-symbol face 90° around (used by consumers reasoning about windows)
function DrumStep.symmetric(index: number): number
    return (index + 3) % FACES
end

-- Continuing +1 detent stepping from `currentFace`, the next face that brings
-- `throw`'s symbol to the window. Always 1..3 steps ahead; result % 3 == faceForThrow.
function DrumStep.landingStep(currentFace: number, throw: string): number
    local target = DrumStep.faceForThrow(throw)
    for m = 1, 3 do
        local face = (currentFace + m) % FACES
        if face % 3 == target then
            return face
        end
    end
    return currentFace -- unreachable (a match exists within 3 steps)
end

return DrumStep
