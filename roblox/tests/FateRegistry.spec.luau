--!strict
local harness = require("./harness")
local FateRegistry = require("../src/shared/FateRegistry")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("FateRegistry", function()
    test("begin binds; isBound reflects it", function()
        local r = FateRegistry.new()
        expect(r:isBound("9")).toBe(false)
        r:begin("9")
        expect(r:isBound("9")).toBe(true)
    end)

    test("resolve unbinds and reports whether the user was bound", function()
        local r = FateRegistry.new()
        r:begin("9")
        expect(r:resolve("9")).toBe(true)
        expect(r:isBound("9")).toBe(false)
        expect(r:resolve("9")).toBe(false) -- double-resolve is safe
    end)

    test("bindings are per-user", function()
        local r = FateRegistry.new()
        r:begin("9")
        expect(r:isBound("10")).toBe(false)
    end)

    test("remove clears a user without resolution semantics (player left)", function()
        local r = FateRegistry.new()
        r:begin("9")
        r:remove("9")
        expect(r:isBound("9")).toBe(false)
    end)
end)
