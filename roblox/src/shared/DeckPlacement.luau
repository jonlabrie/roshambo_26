--!strict
-- Pure per-size deck-placement lookup. Each pad authors a deck-pivot CFrame (12-number array)
-- per size in `deckPlacements`; resolve returns the one for `deckSize`, falling back to
-- `maxSize`'s placement when a size is unauthored (e.g. a not-yet-surveyed S/M), and nil when
-- even that is missing (the Roblox caller then skips the deck). Pure (Lune-tested).
local DeckPlacement = {}

export type Placements = { [string]: { number } }

function DeckPlacement.resolve(deckPlacements: Placements, deckSize: string, maxSize: string): { number }?
    return deckPlacements[deckSize] or deckPlacements[maxSize]
end

return DeckPlacement
