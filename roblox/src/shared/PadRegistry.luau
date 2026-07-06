--!strict
-- Per-server pad occupancy model. Stateful object; sub-project D creates one per Roblox
-- server, registers that server's pads at startup, then claimVacant() on spawn / release()
-- on leave. Pure Luau (Lune-tested): no Roblox datatypes, no math.random. `spec` is an
-- opaque PadSpec. First-vacant assignment is deterministic (insertion-ordered id list).
local PadRegistry = {}
PadRegistry.__index = PadRegistry

export type PadRecord = { id: string, spec: any, occupant: string? }
export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }

function PadRegistry.new()
    return setmetatable({ _order = {} :: { string }, _pads = {} :: { [string]: PadRecord } }, PadRegistry)
end

function PadRegistry.fits(padFootprint: Footprint, structFootprint: Footprint): boolean
    return structFootprint.minX >= padFootprint.minX
        and structFootprint.maxX <= padFootprint.maxX
        and structFootprint.minZ >= padFootprint.minZ
        and structFootprint.maxZ <= padFootprint.maxZ
end

function PadRegistry:register(id: string, spec: any): boolean
    if self._pads[id] then
        return false
    end
    self._pads[id] = { id = id, spec = spec, occupant = nil }
    table.insert(self._order, id)
    return true
end

function PadRegistry:findVacant(): string?
    for _, id in self._order do
        if self._pads[id].occupant == nil then
            return id
        end
    end
    return nil
end

function PadRegistry:claim(id: string, owner: string): boolean
    local pad = self._pads[id]
    if not pad or pad.occupant ~= nil then
        return false
    end
    pad.occupant = owner
    return true
end

function PadRegistry:claimVacant(owner: string): { id: string, spec: any }?
    local id = self:findVacant()
    if not id then
        return nil
    end
    self._pads[id].occupant = owner
    return { id = id, spec = self._pads[id].spec }
end

function PadRegistry:claimVacantFor(owner: string, structFootprint: Footprint): { id: string, spec: any }?
    for _, id in self._order do
        local pad = self._pads[id]
        if pad.occupant == nil then
            local fp = pad.spec and pad.spec.footprint
            if fp ~= nil and PadRegistry.fits(fp, structFootprint) then
                pad.occupant = owner
                return { id = id, spec = pad.spec }
            end
        end
    end
    return nil
end

function PadRegistry:release(id: string): boolean
    local pad = self._pads[id]
    if not pad then
        return false
    end
    pad.occupant = nil
    return true
end

function PadRegistry:get(id: string): PadRecord?
    local pad = self._pads[id]
    if not pad then
        return nil
    end
    return { id = pad.id, spec = pad.spec, occupant = pad.occupant }
end

return PadRegistry
