--!strict
-- Pure index math for the hexagonal throw drum. Faces 0..5 around the axis;
-- face index % 3 → symbol (0=R, 1=P, 2=S). Faces k and k+3 carry the same
-- symbol, so opposite faces (front/back windows) always match.
local DrumStep = {}

local SYMBOLS = { R = 0, P = 1, S = 2 }

-- the low face index (0..2) carrying this throw's symbol
function DrumStep.faceForThrow(throw: string): number
    return SYMBOLS[throw] or 0
end

-- the opposite face (180° around): same symbol, other window
function DrumStep.symmetric(index: number): number
    return (index + 3) % 6
end

-- Continuing the drum's +1 detent stepping from `currentFace`, the next face
-- that brings `throw`'s symbol to the window. Always 1..3 steps ahead; result
-- index % 3 == faceForThrow(throw). Used at the strike to snap onto the result.
function DrumStep.landingStep(currentFace: number, throw: string): number
    local target = DrumStep.faceForThrow(throw)
    for m = 1, 3 do
        local face = (currentFace + m) % 6
        if face % 3 == target then
            return face
        end
    end
    return currentFace -- unreachable (a match exists within 3 steps)
end

return DrumStep
