--!strict
local harness = require("./harness")
local Model = require("../src/shared/TeahouseMenuModel")
local describe, test, expect = harness.describe, harness.test, harness.expect

local CATALOG = { deck = { S = 50, M = 500, L = 3000 }, teahouse = { S = 30, M = 300, L = 2000 } }
local function state(over)
    local s = {
        totalPoints = 1000,
        maxDeckSize = nil,
        teahouseSizes = {},
        deckDisplay = nil,
        teahouseDisplay = nil,
        padPreferences = {},
        catalog = CATALOG,
    }
    for k, v in over do
        s[k] = v
    end
    return s
end
local function rung(ladder, size)
    for _, r in ladder do
        if r.size == size then
            return r
        end
    end
    return nil
end

describe("TeahouseMenuModel.viewModel", function()
    test("non-owner: nothing owned, deck S is next, teahouse locked", function()
        local vm = Model.viewModel(state({}))
        expect(vm.ownsDeck).toBe(false)
        expect(rung(vm.deckLadder, "S").isNext).toBe(true)
        expect(rung(vm.deckLadder, "S").price).toBe(50)
        expect(rung(vm.teahouseLadder, "S").locked).toBe(true) -- needs a deck first
    end)
    test("locked teahouse rung carries no price or affordability", function()
        local vm = Model.viewModel(state({}))
        local s = rung(vm.teahouseLadder, "S")
        expect(s.locked).toBe(true)
        expect(s.isNext).toBe(false)
        expect(s.price).toBe(nil)
        expect(s.affordable).toBe(nil)
    end)
    test("owned deck M marks S,M owned; L is next; affordability from points", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", totalPoints = 100 }))
        expect(rung(vm.deckLadder, "M").owned).toBe(true)
        expect(rung(vm.deckLadder, "L").isNext).toBe(true)
        expect(rung(vm.deckLadder, "L").affordable).toBe(false) -- 100 < 3000
    end)
    test("teahouse rung locked above the owned deck size", function()
        local vm = Model.viewModel(state({ maxDeckSize = "S", teahouseSizes = {} }))
        expect(rung(vm.teahouseLadder, "S").locked).toBe(false) -- deck S covers teahouse S
        expect(rung(vm.teahouseLadder, "M").locked).toBe(true)
    end)
    test("display options enabled only up to owned; selection reflects state", function()
        local vm = Model.viewModel(state({
            maxDeckSize = "M",
            teahouseSizes = { "S", "M" },
            deckDisplay = "S",
            teahouseDisplay = "none",
        }))
        local function opt(list, v)
            for _, o in list do
                if o.value == v then
                    return o
                end
            end
            return nil
        end
        expect(opt(vm.deckDisplayOptions, "S").enabled).toBe(true)
        expect(opt(vm.deckDisplayOptions, "L").enabled).toBe(false)
        expect(opt(vm.deckDisplayOptions, "S").selected).toBe(true)
        expect(opt(vm.teahouseDisplayOptions, "none").selected).toBe(true)
        expect(opt(vm.teahouseDisplayOptions, "S").enabled).toBe(true)
        expect(opt(vm.teahouseDisplayOptions, "L").enabled).toBe(false)
    end)
    test("favorites pass through", function()
        local vm = Model.viewModel(state({ padPreferences = { "T05", "T09" } }))
        expect(#vm.favorites).toBe(2)
    end)
end)
