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

-- HOW EARLY THE PERSONAL RESULT MAY LAND, measured back from drumRest (spec §2).
--
-- The whole 3.45s of swing + spin + glide sat between a round closing and the player being told
-- what happened, and the owner's word for it was "a long time". But the wait is not padding —
-- it is what stops the result being announced before the drum has shown the world's throw.
--
-- The glide is a smoothstep, so it is nearly home long before it stops: at 0.7s from rest the
-- drum has covered ~88% of its travel and the face is effectively in the window. The remaining
-- beat is settling, not suspense. So the SPLASH fires here and the TAPE TILE does not — the tape
-- is the record of the WORLD's throw, the real spoiler, and it has no urgency.
DrumStep.SPLASH_LEAD_SECONDS = 0.7

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
