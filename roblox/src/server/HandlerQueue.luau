--!strict
-- Per-uid FIFO serialization for the mutating server handlers (2026-07-19 spec). Each handler
-- body is a thunk that may yield on HTTP; run(uid, thunk) guarantees one player's thunks run
-- strictly one at a time — no mid-yield interleaving, no overlapping PUTs. The thread-spawn
-- primitive is injected so the module is pure and Lune-testable. One worker drains a lane
-- sequentially; a thunk's yield suspends the whole worker, so the next thunk cannot start until
-- the current one returns. A hung/retrying HTTP call blocks that uid's entire lane (bounded by
-- transport timeout + NetworkClient retry); only that player's mutating handlers are affected.
local HandlerQueue = {}
HandlerQueue.__index = HandlerQueue

-- Lune has no `warn` global; fall back to `print` off-Roblox.
local logWarn: (...any) -> () = (warn :: any) or print

local MAX_PENDING = 8
HandlerQueue.MAX_PENDING = MAX_PENDING

type Lane = { running: boolean, pending: { () -> () } }
export type HandlerQueue = typeof(setmetatable(
    {} :: { _spawn: (() -> ()) -> (), _lanes: { [string]: Lane } },
    HandlerQueue
))

function HandlerQueue.new(spawn: (() -> ()) -> ()): HandlerQueue
    return setmetatable({ _spawn = spawn, _lanes = {} }, HandlerQueue)
end

function HandlerQueue._drain(self: HandlerQueue, uid: string)
    local lane = self._lanes[uid]
    if lane == nil then
        return
    end
    lane.running = true
    -- exactly one worker for this lane; it closes over `lane` so a concurrent clear+new-run that
    -- installs a fresh lane never gets drained by this worker (identity guard on retire, below).
    self._spawn(function()
        while #lane.pending > 0 do
            local thunk = table.remove(lane.pending, 1) :: () -> ()
            local ok, err = pcall(thunk)
            if not ok then
                logWarn(`[QUEUE] handler error for {uid}: {tostring(err)}`)
            end
        end
        lane.running = false
        if self._lanes[uid] == lane and #lane.pending == 0 then
            self._lanes[uid] = nil
        end
    end)
end

function HandlerQueue.run(self: HandlerQueue, uid: string, thunk: () -> ()): boolean
    local lane = self._lanes[uid]
    if lane == nil then
        lane = { running = false, pending = {} }
        self._lanes[uid] = lane
    end
    if #lane.pending >= MAX_PENDING then
        logWarn(`[QUEUE] dropping request for {uid}: queue full ({MAX_PENDING})`)
        return false
    end
    table.insert(lane.pending, thunk)
    if not lane.running then
        self:_drain(uid)
    end
    return true
end

function HandlerQueue.clear(self: HandlerQueue, uid: string)
    local lane = self._lanes[uid]
    if lane ~= nil then
        table.clear(lane.pending) -- drop not-yet-run thunks
        self._lanes[uid] = nil
    end
end

return HandlerQueue
