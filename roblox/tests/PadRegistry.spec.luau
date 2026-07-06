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

test("findVacant returns first-registered vacant id; nil when full", function()
    local r = PadRegistry.new()
    r:register("a", 1)
    r:register("b", 2)
    expect(r:findVacant()).toBe("a")
    r:claim("a", "owner1")
    expect(r:findVacant()).toBe("b")
    r:claim("b", "owner2")
    expect(r:findVacant()).toBeNil()
end)

test("claim: false on unknown id and on already-claimed", function()
    local r = PadRegistry.new()
    r:register("a", 1)
    expect(r:claim("nope", "o")).toBe(false)
    expect(r:claim("a", "o1")).toBe(true)
    expect(r:claim("a", "o2")).toBe(false)
    expect(r:get("a").occupant).toBe("o1")
end)

test("claimVacant returns {id,spec}, marks claimed, hands out in registration order", function()
    local r = PadRegistry.new()
    r:register("a", "sa")
    r:register("b", "sb")
    local first = r:claimVacant("o1")
    expect(first.id).toBe("a")
    expect(first.spec).toBe("sa")
    local second = r:claimVacant("o2")
    expect(second.id).toBe("b")
    expect(r:claimVacant("o3")).toBeNil()
    expect(r:get("a").occupant).toBe("o1")
end)

test("release frees a claimed pad; false on unknown; no-op true on already vacant", function()
    local r = PadRegistry.new()
    r:register("a", 1)
    r:claim("a", "o1")
    expect(r:release("a")).toBe(true)
    expect(r:findVacant()).toBe("a")
    expect(r:release("a")).toBe(true) -- no-op on already-vacant
    expect(r:release("nope")).toBe(false)
end)

test("get returns nil for unknown id", function()
    local r = PadRegistry.new()
    expect(r:get("nope")).toBeNil()
end)

test("fits: contained/exact -> true; overhang -> false", function()
    local pad = { minX = -10, maxX = 15, minZ = -12, maxZ = 5 }
    expect(PadRegistry.fits(pad, { minX = -7, maxX = 12, minZ = -10, maxZ = 4 })).toBe(true) -- contained
    expect(PadRegistry.fits(pad, pad)).toBe(true) -- exact
    expect(PadRegistry.fits(pad, { minX = -7, maxX = 16, minZ = -10, maxZ = 4 })).toBe(false) -- wider +X
    expect(PadRegistry.fits(pad, { minX = -7, maxX = 12, minZ = -10, maxZ = 6 })).toBe(false) -- deeper +Z
    expect(PadRegistry.fits(pad, { minX = -11, maxX = 12, minZ = -10, maxZ = 4 })).toBe(false) -- under-min -X
end)

test("claimVacantFor: skips a too-small vacant pad, claims the first fitting one", function()
    local r = PadRegistry.new()
    local small = { minX = -3, maxX = 3, minZ = -3, maxZ = 3 }
    local big = { minX = -10, maxX = 15, minZ = -12, maxZ = 5 }
    r:register("small", { footprint = small })
    r:register("big", { footprint = big })
    local struct = { minX = -7, maxX = 12, minZ = -10, maxZ = 4 } -- fits big, not small
    local claimed = r:claimVacantFor("owner1", struct)
    expect(claimed.id).toBe("big")
    expect(claimed.spec.footprint).toEqual(big)
    expect(r:get("big").occupant).toBe("owner1")
    expect(r:get("small").occupant).toBeNil() -- untouched
end)

test("claimVacantFor: nil when none fit", function()
    local r = PadRegistry.new()
    r:register("small", { footprint = { minX = -3, maxX = 3, minZ = -3, maxZ = 3 } })
    expect(r:claimVacantFor("o", { minX = -7, maxX = 12, minZ = -10, maxZ = 4 })).toBeNil()
end)

test("claimVacantFor: skips a pad whose spec has no footprint", function()
    local r = PadRegistry.new()
    r:register("nofp", { other = true }) -- no footprint
    r:register("ok", { footprint = { minX = -10, maxX = 15, minZ = -12, maxZ = 5 } })
    local claimed = r:claimVacantFor("o", { minX = -7, maxX = 12, minZ = -10, maxZ = 4 })
    expect(claimed.id).toBe("ok")
    expect(r:get("nofp").occupant).toBeNil()
end)
