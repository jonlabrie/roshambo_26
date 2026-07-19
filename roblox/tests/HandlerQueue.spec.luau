--!strict
local harness = require("./harness")
local HandlerQueue = require("../src/server/HandlerQueue")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- A fake spawn that runs the worker in a coroutine and records it, so a thunk can `coroutine.yield()`
-- mid-run (simulating an HTTP round-trip) and the test resumes it deterministically.
local function coScheduler()
    local threads: { thread } = {}
    local function spawn(fn: () -> ())
        local co = coroutine.create(fn)
        table.insert(threads, co)
        coroutine.resume(co)
    end
    return spawn, threads
end

-- A fake spawn that DEFERS the worker (never runs it) so `pending` accumulates for cap/clear tests.
local function deferScheduler()
    local workers: { () -> () } = {}
    local function spawn(fn: () -> ())
        table.insert(workers, fn)
    end
    return spawn, workers
end

describe("HandlerQueue", function()
    test("serializes a lane's thunks in FIFO order across a yield", function()
        local spawn, threads = coScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u", function()
            table.insert(log, "A-start")
            coroutine.yield() -- suspend mid-"HTTP"
            table.insert(log, "A-end")
        end)
        -- B is enqueued while A is suspended: it must NOT run yet, and must NOT spawn a 2nd worker
        q:run("u", function()
            table.insert(log, "B")
        end)
        expect(#log).toBe(1) -- only "A-start"
        expect(#threads).toBe(1) -- single worker for the lane
        coroutine.resume(threads[1]) -- A finishes, then B runs
        expect(log[1]).toBe("A-start")
        expect(log[2]).toBe("A-end")
        expect(log[3]).toBe("B")
    end)

    test("different uids run on independent lanes", function()
        local spawn = coScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u1", function()
            table.insert(log, "u1")
        end)
        q:run("u2", function()
            table.insert(log, "u2")
        end)
        expect(log).toEqual({ "u1", "u2" })
    end)

    test("drops the 9th concurrent request and returns false", function()
        local spawn = deferScheduler() -- workers deferred, so pending accumulates
        local q = HandlerQueue.new(spawn)
        local results: { boolean } = {}
        for i = 1, 9 do
            results[i] = q:run("u", function() end)
        end
        for i = 1, 8 do
            expect(results[i]).toBe(true)
        end
        expect(results[9]).toBe(false)
    end)

    test("an erroring thunk does not block its successors", function()
        local spawn, workers = deferScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u", function()
            error("boom")
        end)
        q:run("u", function()
            table.insert(log, "after")
        end)
        workers[1]() -- the single worker drains both
        expect(log).toEqual({ "after" })
    end)

    test("clear drops not-yet-run pending thunks", function()
        local spawn, workers = deferScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u", function()
            table.insert(log, "A")
        end)
        q:run("u", function()
            table.insert(log, "B")
        end)
        q:clear("u")
        workers[1]() -- worker runs but pending was cleared
        expect(log).toEqual({})
    end)
end)
