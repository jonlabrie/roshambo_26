--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (treatment) and SizeClasses (built-size resolution). Pure
-- (Lune-tested): no Roblox datatypes. Claim eligibility keys off DECK ownership
-- (`economy.maxDeckSize ~= nil`), not teahouse ownership; a deck-only owner (empty
-- `teahouses`) claims a bare deck. onJoin claims the first vacant site in preference
-- order (a player's preferred site ids, passed to onJoin, are scanned first, then
-- registration order); the built deckSize + optional teahouse are resolved via
-- SizeClasses.resolveBuilt, which CAPS the deck/teahouse down to the perch's maxSize
-- rather than gating the claim on a size mismatch. The passed economy may also carry
-- `deckDisplay`/`teahouseDisplay` (B3), which resolveBuilt applies as a further, owner-chosen
-- clamp that only ever shrinks what's built (never past what's owned or perch-capped). The
-- Studio-side TreatmentApplier executes the Actions (scale + posts).
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
        teahouse = {
            size = STARTER,
            loadout = treatment.loadout,
            placement = (treatment.loadout and treatment.loadout.placement) or CENTERED,
        },
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
    economy: {
        maxDeckSize: string?,
        teahouses: { [string]: any },
        deckDisplay: string?,
        teahouseDisplay: string?,
    }?,
    preferences: { string }?
): Action?
    if self._held[playerId] ~= nil then
        return nil
    end
    if economy == nil or economy.maxDeckSize == nil then
        return nil -- not an owner (owns no deck) -> no auto-claim
    end
    local teahouses = economy.teahouses or {}
    local teaSizes: { string } = {}
    for size in teahouses do
        table.insert(teaSizes, size)
    end
    local order = self:_orderedSiteIds(preferences)
    for _, id in order do
        local rec = self._registry:get(id)
        if rec and rec.occupant == nil then
            local built = SizeClasses.resolveBuilt(
                economy.maxDeckSize,
                teaSizes,
                rec.spec.maxSize,
                economy.deckDisplay,
                economy.teahouseDisplay
            )
            if built ~= nil then
                self._registry:claim(id, playerId)
                self._held[playerId] = id
                local teaLoadout = if built.teahouseSize ~= nil then teahouses[built.teahouseSize] else nil
                local teahouse = if built.teahouseSize ~= nil
                    then {
                        size = built.teahouseSize,
                        loadout = teaLoadout,
                        placement = (teaLoadout and teaLoadout.placement) or CENTERED,
                    }
                    else nil
                return {
                    padId = id,
                    spec = rec.spec,
                    treatment = VacantState.resolve(playerId, teaLoadout, rec.spec.vacantForm),
                    deckSize = built.deckSize,
                    teahouse = teahouse,
                }
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

-- Whether a registered pad is currently unclaimed. Unregistered ids are reported as
-- not vacant (nothing to claim there) rather than erroring.
function SiteCoordinator:isVacant(padId: string): boolean
    local rec = self._registry:get(padId)
    return rec ~= nil and rec.occupant == nil
end

-- The model teahouse (onboarding journey, owner 2026-09-03): one named pad claimed at boot
-- by a sentinel "owner" and materialized as the lit stock S bundle — exactly what the
-- starter SKU buys, standing built so a guest can walk its deck and slide its shoji
-- (visitor slides are live-only, so the model tidies itself). Claimed through the SAME
-- registry as every player claim, which is the whole trick: onJoin and buy-to-claim skip it
-- because it is simply occupied.
function SiteCoordinator:claimModel(ownerId: string, padId: string): Action?
    if self._held[ownerId] ~= nil then
        return nil
    end
    local rec = self._registry:get(padId)
    if rec == nil or rec.occupant ~= nil then
        return nil
    end
    local loadout = { baseStyle = "teahouse-1story" }
    self._registry:claim(padId, ownerId)
    self._held[ownerId] = padId
    return {
        padId = padId,
        spec = rec.spec,
        treatment = VacantState.resolve(ownerId, loadout, rec.spec and rec.spec.vacantForm),
        deckSize = "S",
        teahouse = { size = "S", loadout = loadout, placement = CENTERED },
    }
end

return SiteCoordinator
