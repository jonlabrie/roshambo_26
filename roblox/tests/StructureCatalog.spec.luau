--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local Catalog = require("../src/shared/StructureCatalog")

test("get returns a recolor entry with per-role palette", function()
    local e = Catalog.get("scheme.ink")
    expect(e).toBeTruthy()
    expect((e :: any).type).toBe("recolor")
    expect((e :: any).slot).toBe("colorScheme")
    expect((e :: any).payload.cap).toEqual({ 45, 48, 56 })
end)

test("get returns texture and attachment entries", function()
    expect((Catalog.get("shoji.crane") :: any).type).toBe("texture")
    expect((Catalog.get("tatami.gold") :: any).type).toBe("texture")
    local flag = Catalog.get("flag.clan") :: any
    expect(flag.type).toBe("attachment")
    expect(flag.payload.prefabId).toBe("flag_clan")
end)

test("get returns nil for an unknown id", function()
    expect(Catalog.get("nope.nope")).toBeNil()
end)

test("get returns the dormant recolor scheme with a dark per-role palette", function()
    local e = Catalog.get("scheme.dormant")
    expect(e).toBeTruthy()
    expect((e :: any).type).toBe("recolor")
    expect((e :: any).slot).toBe("colorScheme")
    expect((e :: any).payload.timber).toEqual({ 48, 46, 44 })
    expect((e :: any).payload.wall).toEqual({ 70, 68, 64 })
    expect((e :: any).payload.roof).toEqual({ 36, 37, 40 })
    expect((e :: any).payload.cap).toEqual({ 40, 42, 46 })
end)
