--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local VacantState = require("../src/shared/VacantState")

test("vacant cliff (omitted or dormant-structure) -> dark structure, unlit", function()
    local t = VacantState.resolve(nil, nil, nil)
    expect(t.kind).toBe("structure")
    expect(t.loadout.baseStyle).toBe("teahouse-1story")
    expect(t.loadout.colorScheme).toBe("scheme.dormant")
    expect(t.lit).toBe(false)
    expect(VacantState.resolve(nil, nil, "dormant-structure").lit).toBe(false)
end)

test("claimed with loadout -> owner structure (passed through), lit", function()
    local owner = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }
    local t = VacantState.resolve("player1", owner, "dormant-structure")
    expect(t.kind).toBe("structure")
    expect(t.loadout).toBe(owner) -- same reference, not a copy
    expect(t.lit).toBe(true)
end)

test("claimed without loadout -> dormant structure, lit (defensive)", function()
    local t = VacantState.resolve("player1", nil, "dormant-structure")
    expect(t.kind).toBe("structure")
    expect(t.loadout.colorScheme).toBe("scheme.dormant")
    expect(t.lit).toBe(true)
end)

test("vacant valley (pocket-garden) -> garden marker", function()
    local t = VacantState.resolve(nil, nil, "pocket-garden")
    expect(t.kind).toBe("garden")
end)
