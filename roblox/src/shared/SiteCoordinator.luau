--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (treatment) and SizeClasses (size-cap fit). Pure
-- (Lune-tested): no Roblox datatypes. A site carries a `maxSize`; onJoin claims the
-- first vacant site whose maxSize accommodates the player's largest owned size,
-- biggest-first. The Studio-side TreatmentApplier executes the Actions (scale + posts).
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
    footprint: SizeClasses.Footprint?,
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

-- A vacant site renders its dormant shell at the site's own max size.
local function dormantOf(spec: any): (number, SizeClasses.Footprint?)
    local maxSize = spec and spec.maxSize
    if maxSize == nil then
        return 1, nil
    end
    return SizeClasses.scale[maxSize], SizeClasses.footprintFor(maxSize)
end

function SiteCoordinator:vacantActions(): { Action }
    local out: { Action } = {}
    for _, id in self._padIds do
        local rec = self._registry:get(id)
        if rec and rec.occupant == nil then
            local scale, footprint = dormantOf(rec.spec)
            table.insert(out, {
                padId = id,
                spec = rec.spec,
                treatment = VacantState.resolve(nil, nil, rec.spec.vacantForm),
                scale = scale,
                footprint = footprint,
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
    for _, size in SizeClasses.order do -- L, M, S (biggest first)
        local loadout = ownedTeahouses[size]
        if loadout ~= nil then
            for _, id in self._padIds do -- registration order (first-fit)
                local rec = self._registry:get(id)
                if rec and rec.occupant == nil and SizeClasses.fitsWithin(size, rec.spec.maxSize) then
                    self._registry:claim(id, playerId)
                    self._held[playerId] = id
                    return {
                        padId = id,
                        spec = rec.spec,
                        treatment = VacantState.resolve(playerId, loadout, rec.spec.vacantForm),
                        scale = SizeClasses.scale[size],
                        sizeClass = size,
                        footprint = SizeClasses.footprintFor(size),
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
    local spec = rec and rec.spec
    local scale, footprint = dormantOf(spec)
    return {
        padId = padId,
        spec = spec,
        treatment = VacantState.resolve(nil, nil, spec and spec.vacantForm),
        scale = scale,
        footprint = footprint,
    }
end

return SiteCoordinator
