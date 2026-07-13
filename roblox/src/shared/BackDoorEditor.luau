--!strict
-- Pure one-door-slot logic for the modular back wall. A teahouse's back wall carries at most
-- one `door` bay; setBackDoor sets / moves / clears it and returns a NEW wallBays map with a
-- DENSE back list (JSON-array-safe). backDoorIndex reads the current back door bay. No Roblox
-- datatypes -> Lune-tested. Mirrors PreferenceEditor. The Map type is structurally WallBays.Map.
local BackDoorEditor = {}

export type Map = { [string]: { string } }

-- the 1-based index of the back wall's `door` bay, or nil if none.
function BackDoorEditor.backDoorIndex(wallBays: Map?): number?
    if wallBays == nil then
        return nil
    end
    local back = wallBays.back
    if back == nil then
        return nil
    end
    for i, state in back do
        if state == "door" then
            return i
        end
    end
    return nil
end

-- Return a NEW map whose back wall has a single `door` at `index` (all other back bays `solid`),
-- or NO back door when `index` is nil, out of 1..backBayCount, or equal to the bay that is ALREADY
-- the door (toggle-off). Clearing drops the `back` key entirely so WallBays.resolve falls back to
-- the all-solid default. Other sides are shallow-copied through unchanged (side lists hold only strings); the input is not mutated.
function BackDoorEditor.setBackDoor(wallBays: Map?, index: number?, backBayCount: number): Map
    local out: Map = {}
    if wallBays ~= nil then
        for side, states in wallBays do
            if side ~= "back" then
                out[side] = table.clone(states)
            end
        end
    end
    local current = BackDoorEditor.backDoorIndex(wallBays)
    local keep = false
    if index ~= nil and index >= 1 and index <= backBayCount and index ~= current then
        keep = true
    end
    if keep then
        local back = {}
        for i = 1, backBayCount do
            back[i] = if i == index then "door" else "solid"
        end
        out.back = back
    end
    return out
end

return BackDoorEditor
