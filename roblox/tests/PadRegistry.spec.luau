--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local PadRegistry = require("../src/shared/PadRegistry")

test("register adds vacant pads; duplicate id returns false and does not overwrite", function()
    local r = PadRegistry.new()
    expect(r:register("a", { tag = "specA" })).toBe(true)
    expect(r:register("a", { tag = "OTHER" })).toBe(false)
    expect(r:get("a").spec.tag).toBe("specA")
    expect(r:get("a").occupant).toBeNil()
end)

test("claim: false on unknown id and on already-claimed", function()
    local r = PadRegistry.new()
    r:register("a", 1)
    expect(r:claim("nope", "o")).toBe(false)
    expect(r:claim("a", "o1")).toBe(true)
    expect(r:claim("a", "o2")).toBe(false)
    expect(r:get("a").occupant).toBe("o1")
end)

test("release frees a claimed pad; false on unknown; no-op true on already vacant", function()
    local r = PadRegistry.new()
    r:register("a", 1)
    r:claim("a", "o1")
    expect(r:release("a")).toBe(true)
    expect(r:get("a").occupant).toBeNil()
    expect(r:release("a")).toBe(true) -- no-op on already-vacant
    expect(r:release("nope")).toBe(false)
end)

test("get returns nil for unknown id", function()
    local r = PadRegistry.new()
    expect(r:get("nope")).toBeNil()
end)
