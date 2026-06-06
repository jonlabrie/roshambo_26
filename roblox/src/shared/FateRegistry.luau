--!strict
-- Tracks fate-bound players (spec §6.1): while bound, the server refuses
-- their throws — you can't play until you face your fate.
local FateRegistry = {}
FateRegistry.__index = FateRegistry

function FateRegistry.new()
    return setmetatable({ _bound = {} :: { [string]: boolean } }, FateRegistry)
end

function FateRegistry.begin(self: any, userId: string)
    self._bound[userId] = true
end

function FateRegistry.isBound(self: any, userId: string): boolean
    return self._bound[userId] == true
end

function FateRegistry.resolve(self: any, userId: string): boolean
    local was = self._bound[userId] == true
    self._bound[userId] = nil
    return was
end

function FateRegistry.remove(self: any, userId: string)
    self._bound[userId] = nil
end

return FateRegistry
