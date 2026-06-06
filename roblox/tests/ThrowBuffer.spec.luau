--!strict
local harness = require("./harness")
local ThrowBuffer = require("../src/server/ThrowBuffer")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ThrowBuffer", function()
    test("collects picks and reports unflushed count", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("10", "P")
        expect(b:unflushedCount()).toBe(2)
    end)

    test("re-pick overwrites and counts once", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("9", "S")
        expect(b:unflushedCount()).toBe(1)
        expect(b:picks()["9"]).toBe("S")
    end)

    test("takeDelta returns unflushed picks and marks them flushed", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("10", "P")
        local delta = b:takeDelta()
        expect(#delta).toBe(2)
        expect(b:unflushedCount()).toBe(0)
        -- picks remain known for local reveal calc
        expect(b:picks()["9"]).toBe("R")
    end)

    test("a re-pick after flush is dirty again (next delta carries it)", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:takeDelta()
        b:setPick("9", "P")
        local delta = b:takeDelta()
        expect(#delta).toBe(1)
        expect(delta[1].robloxUserId).toBe("9")
        expect(delta[1].throw).toBe("P")
    end)

    test("requeue marks entries unflushed unless a newer pick superseded them", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("10", "P")
        local delta = b:takeDelta()
        b:setPick("10", "S") -- newer pick while the flush was in flight
        b:requeue(delta)
        local redo = b:takeDelta()
        -- "9" requeued with R; "10" keeps its NEWER value S (already dirty), not the stale P
        local byId = {}
        for _, t in redo do
            byId[t.robloxUserId] = t.throw
        end
        expect(byId["9"]).toBe("R")
        expect(byId["10"]).toBe("S")
    end)

    test("clearRound wipes everything", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:clearRound()
        expect(b:unflushedCount()).toBe(0)
        expect(b:picks()["9"]).toBeNil()
    end)

    test("takeDelta on empty buffer returns an empty array", function()
        local b = ThrowBuffer.new()
        expect(#b:takeDelta()).toBe(0)
    end)
end)
