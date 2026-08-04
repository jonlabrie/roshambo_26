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
-- (DrumController's STALL_MAX — waiting for a late World Throw before settling — is deliberately NOT
-- in here: it is an exception path, not the normal choreography, and padding every round by it would
-- make the grow late for everyone to cover a case that hardly ever happens.)
DrumStep.STRIKE_SWING_SECONDS = 0.45
DrumStep.SPIN_SECONDS = 1.0
DrumStep.GLIDE_SECONDS = 2.0
DrumStep.SETTLE_SECONDS = DrumStep.STRIKE_SWING_SECONDS + DrumStep.SPIN_SECONDS + DrumStep.GLIDE_SECONDS

-- The spin's angular velocity, rad/s — DrumController's old private `DRUM_KICK`, here for the same
-- reason as the durations above. The glide is a Hermite that CARRIES this velocity, so how much
-- angle the drum still has to turn at any instant cannot be computed without it — and that figure
-- is what `glideResidual` (below) returns and what DrumStep.spec asserts against. A hand-copied 4
-- in the test was not merely stale-if-changed: the assertion inverts across the plausible range (at
-- ω = 1 the worst case is 0.780 and the test fails; at ω = 8 it passes while describing a drum
-- nobody is running).
--
-- DrumController still honours the "DrumKick" stage attribute, which OVERRIDES this at `gongHit`.
-- Nothing here can see that attribute — which is precisely why the splash cue triggers on the
-- residual computed from the LIVE ω rather than on a constant lead sized against this one. Retune
-- the kick in Studio and the cue retimes itself; a constant would silently go wrong.
DrumStep.KICK_OMEGA = 4

-- WHEN THE PERSONAL RESULT MAY LAND (spec §2, amended 2026-08-04 by the owner's ruling).
--
-- The whole 3.45s of swing + spin + glide sat between a round closing and the player being told
-- what happened, and the owner's word for it was "a long time". But the wait is not padding —
-- it is what stops the result being announced before the drum has shown the world's throw.
--
-- This was first a fixed lead, sized against "the drum has covered >80% of its travel". That
-- criterion measures the wrong thing. What the splash needs to know is not how far the drum has
-- COME but WHETHER THE CORRECT SYMBOL IS IN THE WINDOW, and the two part company: at a 0.7s lead
-- the drum was 83-88% home yet still had 28.1° (best landing) to 53.4° (worst) left to turn, with
-- facets 30° apart and each carrying a DIFFERENT symbol. For a further 0.19-0.34s the window read a
-- NEIGHBOURING throw while the splash named the result — on a LOSS, visibly disagreeing with it.
--
-- No constant fixes that. The residual depends on the travel `landTargetFor` happens to pick
-- (D ∈ [ω·G/2, ω·G/2 + π/2); the longer the travel, the smaller the share the carried-velocity term
-- contributes, so the LARGEST D is the worst case). At a 0.5s lead the worst case is still 28.4°, a
-- full facet off; a fixed lead safe on EVERY landing is ≈0.36s, which barely improves on 3.45s.
--
-- So the cue triggers on the RESIDUAL ANGLE, not the clock: the first frame the drum is within half
-- a facet of home, the correct symbol is the one in the window and the splash may show. That yields
-- a variable ≈0.36-0.51s lead — right on every landing rather than on the lucky ones — and it is
-- the only formulation that survives a retune of ω (see KICK_OMEGA above).
--
-- HALF A FACET, derived from FACES so it cannot drift out of step with the drum's geometry. Half is
-- the widest it may ever be: at more than half a facet of residual the NEXT facet round is still the
-- one nearer the window, so the player would be reading a different symbol from the one named.
DrumStep.SPLASH_RESIDUAL_RADIANS = (2 * math.pi / FACES) / 2

-- How much angle the glide still has to turn, in radians, at normalised progress `s` ∈ [0,1].
--
-- DrumController drives the glide as
--     θ(s) = θ₀ − d·(3s² − 2s³) − ω·G·(s³ − 2s² + s),   landing at θ₀ − d,
-- so the angle still owed is
--     residual(s) = d·(1 − (3s² − 2s³)) − ω·G·(s³ − 2s² + s).
--
-- IT IS A HERMITE, NOT A BARE SMOOTHSTEP — a smoothstep PLUS the spin's exit velocity carried into
-- the glide, because ω is not zeroed until the glide completes. (This module's header used to claim
-- a plain smoothstep and misled a reader: the smoothstep alone reads 72% travelled where the real
-- curve reads 83-88%.) Note s³ − 2s² + s = s(1−s)², non-negative on [0,1], so the carried term only
-- ever brings the drum home sooner. residual(0) = d exactly; residual(1) = 0 exactly.
--
-- `d` is the glide's total travel and `omega` the LIVE angular velocity entering it — pass what the
-- controller is actually running, not KICK_OMEGA, or a "DrumKick" stage override goes unseen.
function DrumStep.glideResidual(d: number, omega: number, s: number): number
    local smooth = 3 * s * s - 2 * s * s * s
    local carried = s * s * s - 2 * s * s + s
    return d * (1 - smooth) - omega * DrumStep.GLIDE_SECONDS * carried
end

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
