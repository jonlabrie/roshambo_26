--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (treatment) and SizeClasses (size-cap fit). Pure
-- (Lune-tested): no Roblox datatypes. A site carries a `maxSize`; onJoin claims the
-- first vacant site whose maxSize accommodates the player's largest owned size,
-- biggest-first. Within a size tier, a player's preferred site ids (passed to onJoin)
-- are scanned first. The Studio-side TreatmentApplier executes the Actions (scale + posts).
local VacantState = require("./VacantState")
local SizeClasses = require("./SizeClasses")

local SiteCoordinator = {}
SiteCoordinator.__index = SiteCoordinator

export type Teahouse = { size: string, loadout: any, placement: any }
export type Action = {
    padId: string,
    spec: any,
    treatment: VacantState.Treatment,
    -- pad/deck separation (Piece A): the pad size to build, and the optional building placed
    -- on it. `teahouse` is nil for a garden (or a future bare deck).
    deckSize: string?,
    teahouse: Teahouse?,
}

-- The starter bundle shown at every unoccupied/left cliff pad: an S deck + a dormant
-- (darkened) S teahouse. NOT the perch maxSize — S fits any perch and advertises the upgrade.
local STARTER = "S"

-- The teahouse sits centered on the deck (walk-around default), inheriting the deck's view
-- orientation. Where the player REpositions it, or adds a back door, is Piece B.
local CENTERED = { offset = { 0, 0 }, facing = "N" }

function SiteCoordinator.new(registry: any)
    return setmetatable({
        _registry = registry,
        _padIds = {} :: { string },
        _held = {} :: { [string]: string },
    }, SiteCoordinator)
end

function SiteCoordinator:registerPad(id: string, spec: any): boolean
    local ok = self._registry:register(id, spec)
    if ok then
        table.insert(self._padIds, id)
    end
    return ok
end

-- The vacant/left action: the S starter bundle (S deck + dormant S teahouse) for a cliff
-- pad, or a bare garden action for a valley pad (applier deferred). `spec` may be nil.
local function starterAction(padId: string, spec: any): Action
    local treatment = VacantState.resolve(nil, nil, spec and spec.vacantForm)
    if treatment.kind ~= "structure" then
        -- valley/garden pad: no deck or building in Piece A
        return { padId = padId, spec = spec, treatment = treatment, deckSize = nil, teahouse = nil }
    end
    return {
        padId = padId,
        spec = spec,
        treatment = treatment,
        deckSize = STARTER,
        teahouse = { size = STARTER, loadout = treatment.loadout, placement = CENTERED },
    }
end

function SiteCoordinator:vacantActions(): { Action }
    local out: { Action } = {}
    for _, id in self._padIds do
        local rec = self._registry:get(id)
        if rec and rec.occupant == nil then
            table.insert(out, starterAction(id, rec.spec))
        end
    end
    return out
end

-- Sites to scan for this join: preferred ids (in preference order, deduped, filtered
-- to registered ids) first, then the remaining registered ids in registration order.
function SiteCoordinator:_orderedSiteIds(preferences: { string }?): { string }
    if preferences == nil then
        return self._padIds
    end
    local registered: { [string]: boolean } = {}
    for _, id in self._padIds do
        registered[id] = true
    end
    local ordered: { string } = {}
    local taken: { [string]: boolean } = {}
    for _, id in preferences do
        if registered[id] and not taken[id] then
            taken[id] = true
            table.insert(ordered, id)
        end
    end
    for _, id in self._padIds do
        if not taken[id] then
            table.insert(ordered, id)
        end
    end
    return ordered
end

function SiteCoordinator:onJoin(
    playerId: string,
    ownedTeahouses: { [string]: any }?,
    preferences: { string }?
): Action?
    if self._held[playerId] ~= nil then
        return nil
    end
    if ownedTeahouses == nil then
        return nil
    end
    local order = self:_orderedSiteIds(preferences)
    for _, size in SizeClasses.order do -- L, M, S (biggest first)
        local loadout = ownedTeahouses[size]
        if loadout ~= nil then
            for _, id in order do -- preferred-first within this size tier
                local rec = self._registry:get(id)
                if rec and rec.occupant == nil and SizeClasses.fitsWithin(size, rec.spec.maxSize) then
                    self._registry:claim(id, playerId)
                    self._held[playerId] = id
                    -- deck = the site's default deck (bounded by maxSize); building = the
                    -- owner's largest fitting teahouse, placed per the site's default placement.
                    local deckSize = rec.spec.deckSize or rec.spec.maxSize
                    return {
                        padId = id,
                        spec = rec.spec,
                        treatment = VacantState.resolve(playerId, loadout, rec.spec.vacantForm),
                        deckSize = deckSize,
                        teahouse = { size = size, loadout = loadout, placement = CENTERED },
                    }
                end
            end
        end
    end
    return nil
end

function SiteCoordinator:onLeave(playerId: string): Action?
    local padId = self._held[playerId]
    if not padId then
        return nil
    end
    self._registry:release(padId)
    self._held[playerId] = nil
    local rec = self._registry:get(padId)
    return starterAction(padId, rec and rec.spec)
end

return SiteCoordinator
