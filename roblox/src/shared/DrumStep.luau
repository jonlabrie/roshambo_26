--!strict
-- Pure index math for the World-Throw drum. 12 facets 0..11 around the vertical
-- axis; face index % 3 → symbol (0=R, 1=P, 2=S). R,P,S repeats FOUR times around the
-- ring, so a symbol recurs every 3 facets (90°) and all four windows (90° apart)
-- show the same symbol at every detent.
local DrumStep = {}

local FACES = 12
local SYMBOLS = { R = 0, P = 1, S = 2 }

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
