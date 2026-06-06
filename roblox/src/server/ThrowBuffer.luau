--!strict
-- Per-round pick collection with delta-flush tracking (spec §4: delta-only
-- batches). Pure: no I/O, no Roblox globals. The coordinator owns flush
-- timing; this module owns what's in each delta.
local ThrowBuffer = {}
ThrowBuffer.__index = ThrowBuffer

export type Entry = { robloxUserId: string, throw: string }

function ThrowBuffer.new()
    return setmetatable({
        _picks = {} :: { [string]: string },
        _dirty = {} :: { [string]: boolean },
    }, ThrowBuffer)
end

function ThrowBuffer.setPick(self: any, robloxUserId: string, throwValue: string)
    self._picks[robloxUserId] = throwValue
    self._dirty[robloxUserId] = true
end

function ThrowBuffer.unflushedCount(self: any): number
    local n = 0
    for _ in self._dirty do
        n += 1
    end
    return n
end

function ThrowBuffer.takeDelta(self: any): { Entry }
    local delta: { Entry } = {}
    for userId in self._dirty do
        table.insert(delta, { robloxUserId = userId, throw = self._picks[userId] })
    end
    self._dirty = {}
    return delta
end

-- Put a failed flush back. A pick made AFTER takeDelta is already dirty with a
-- newer value; don't clobber it with the stale in-flight one.
function ThrowBuffer.requeue(self: any, delta: { Entry })
    for _, entry in delta do
        if not self._dirty[entry.robloxUserId] then
            self._picks[entry.robloxUserId] = entry.throw
            self._dirty[entry.robloxUserId] = true
        end
    end
end

function ThrowBuffer.picks(self: any): { [string]: string }
    return self._picks
end

function ThrowBuffer.clearRound(self: any)
    self._picks = {}
    self._dirty = {}
end

return ThrowBuffer
