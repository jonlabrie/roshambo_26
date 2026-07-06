--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (which treatment). Pure (Lune-tested): no Roblox
-- datatypes. The Studio-side TreatmentApplier executes the Actions.
local VacantState = require("./VacantState")

local SiteCoordinator = {}
SiteCoordinator.__index = SiteCoordinator

export type Action = { padId: string, spec: any, treatment: VacantState.Treatment }

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

function SiteCoordinator:vacantActions(): { Action }
    local out: { Action } = {}
    for _, id in self._padIds do
        local rec = self._registry:get(id)
        if rec then
            table.insert(out, {
                padId = id,
                spec = rec.spec,
                treatment = VacantState.resolve(nil, nil, rec.spec.vacantForm),
            })
        end
    end
    return out
end

function SiteCoordinator:onJoin(playerId: string, ownedLoadout: any?): Action?
    if ownedLoadout == nil then
        return nil
    end
    local claim = self._registry:claimVacant(playerId)
    if not claim then
        return nil
    end
    self._held[playerId] = claim.id
    return {
        padId = claim.id,
        spec = claim.spec,
        treatment = VacantState.resolve(playerId, ownedLoadout, claim.spec.vacantForm),
    }
end

function SiteCoordinator:onLeave(playerId: string): Action?
    local padId = self._held[playerId]
    if not padId then
        return nil
    end
    self._registry:release(padId)
    self._held[playerId] = nil
    local rec = self._registry:get(padId)
    local spec = rec and rec.spec
    return {
        padId = padId,
        spec = spec,
        treatment = VacantState.resolve(nil, nil, spec and spec.vacantForm),
    }
end

return SiteCoordinator
