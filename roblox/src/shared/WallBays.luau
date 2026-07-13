--!strict
-- Pure bay-state model for the modular teahouse walls. A building's walls are a per-side,
-- per-bay state map (solid | shoji | door). resolve() picks each available bay's state from
-- an optional loadout map, falling back to the per-side default (front = shoji, else solid).
-- Pure (Lune-tested); no Roblox datatypes.
local WallBays = {}

WallBays.STATES = { solid = true, shoji = true, door = true } :: { [string]: boolean }

export type Bay = { side: string, index: number }
export type ResolvedBay = { side: string, index: number, state: string }
export type Map = { [string]: { string } }

-- the view front opens as shoji; every other side defaults to a solid wall
function WallBays.defaultState(side: string): string
    return if side == "front" then "shoji" else "solid"
end

-- structural validation: every entry is a known state (bay COUNTS are checked against the
-- prefab's actual bays in resolve, not here)
function WallBays.validate(map: Map): boolean
    for _side, states in map do
        -- a side's value must be a list of states; a malformed value (string/number/etc.)
        -- makes the whole map invalid rather than throwing when resolve iterates it (F2/F4)
        if type(states) ~= "table" then
            return false
        end
        for _, s in states do
            if not WallBays.STATES[s] then
                return false
            end
        end
    end
    return true
end

-- resolve each AVAILABLE bay (from the prefab manifest) to a concrete state. A structurally
-- valid map overrides per (side,index); anything missing/invalid falls back to the per-side
-- default. An entirely invalid map is ignored (all defaults) — non-fatal (F2/F4).
function WallBays.resolve(available: { Bay }, map: Map?): { ResolvedBay }
    local useMap = map ~= nil and WallBays.validate(map)
    local out: { ResolvedBay } = {}
    for _, bay in available do
        local state = WallBays.defaultState(bay.side)
        if useMap and map then
            local sideStates = map[bay.side]
            local chosen = sideStates and sideStates[bay.index]
            if chosen ~= nil and WallBays.STATES[chosen] then
                state = chosen
            end
        end
        table.insert(out, { side = bay.side, index = bay.index, state = state })
    end
    return out
end

return WallBays
