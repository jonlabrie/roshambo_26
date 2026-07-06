--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (treatment) and SizeClasses (multi-size fit). Pure
-- (Lune-tested): no Roblox datatypes. The Studio-side TreatmentApplier executes
-- the Actions (and applies Action.scale via Model:ScaleTo).
local VacantState = require("./VacantState")
local SizeClasses = require("./SizeClasses")

local SiteCoordinator = {}
SiteCoordinator.__index = SiteCoordinator

export type Action = {
    padId: string,
    spec: any,
    treatment: VacantState.Treatment,
    scale: number,
    sizeClass: string?,
}

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

local function dormantScale(spec: any): number
    local native = spec and SizeClasses.nativeSize(spec.footprint)
    return if native then SizeClasses.scale[native] else 1
end

function SiteCoordinator:vacantActions(): { Action }
    local out: { Action } = {}
    for _, id in self._padIds do
        local rec = self._registry:get(id)
        if rec and rec.occupant == nil then
            table.insert(out, {
                padId = id,
                spec = rec.spec,
                treatment = VacantState.resolve(nil, nil, rec.spec.vacantForm),
                scale = dormantScale(rec.spec),
            })
        end
    end
    return out
end

function SiteCoordinator:onJoin(playerId: string, ownedTeahouses: { [string]: any }?): Action?
    if self._held[playerId] ~= nil then
        return nil
    end
    if ownedTeahouses == nil then
        return nil
    end
    for _, size in SizeClasses.order do
        local loadout = ownedTeahouses[size]
        if loadout ~= nil then
            local claim = self._registry:claimVacantFor(playerId, SizeClasses.footprintFor(size))
            if claim then
                self._held[playerId] = claim.id
                return {
                    padId = claim.id,
                    spec = claim.spec,
                    treatment = VacantState.resolve(playerId, loadout, claim.spec.vacantForm),
                    scale = SizeClasses.scale[size],
                    sizeClass = size,
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
    local spec = rec and rec.spec
    return {
        padId = padId,
        spec = spec,
        treatment = VacantState.resolve(nil, nil, spec and spec.vacantForm),
        scale = dormantScale(spec),
    }
end

return SiteCoordinator
