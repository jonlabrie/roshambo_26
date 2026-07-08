--!strict
-- Per-server pad occupancy model. Stateful object; sub-project D creates one per Roblox
-- server, registers that server's pads at startup, then release() on leave. Pure Luau
-- (Lune-tested): no Roblox datatypes, no math.random. `spec` is an opaque PadSpec.
local PadRegistry = {}
PadRegistry.__index = PadRegistry

export type PadRecord = { id: string, spec: any, occupant: string? }
export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }

function PadRegistry.new()
    return setmetatable({ _order = {} :: { string }, _pads = {} :: { [string]: PadRecord } }, PadRegistry)
end

function PadRegistry:register(id: string, spec: any): boolean
    if self._pads[id] then
        return false
    end
    self._pads[id] = { id = id, spec = spec, occupant = nil }
    table.insert(self._order, id)
    return true
end

function PadRegistry:claim(id: string, owner: string): boolean
    local pad = self._pads[id]
    if not pad or pad.occupant ~= nil then
        return false
    end
    pad.occupant = owner
    return true
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
