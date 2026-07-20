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
        claimed = true,
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

describe("TeahouseMenuModel.viewModel: claimless-owner gating (item A)", function()
    local function rung(ladder, size)
        for _, r in ladder do
            if r.size == size then
                return r
            end
        end
        return nil
    end
    local function opt(list, v)
        for _, o in list do
            if o.value == v then
                return o
            end
        end
        return nil
    end

    test("owner+unclaimed: no isNext anywhere, all display options disabled, needsClaim true", function()
        local vm = Model.viewModel(state({
            maxDeckSize = "M",
            teahouseSizes = { "S" },
            claimed = false,
        }))
        expect(vm.needsClaim).toBe(true)
        for _, r in vm.deckLadder do
            expect(r.isNext).toBe(false)
        end
        for _, r in vm.teahouseLadder do
            expect(r.isNext).toBe(false)
        end
        for _, o in vm.deckDisplayOptions do
            expect(o.enabled).toBe(false)
        end
        for _, o in vm.teahouseDisplayOptions do
            expect(o.enabled).toBe(false)
        end
    end)

    test("owner+claimed: unchanged from today", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", claimed = true }))
        expect(vm.needsClaim).toBe(false)
        expect(rung(vm.deckLadder, "L").isNext).toBe(true)
        expect(opt(vm.deckDisplayOptions, "S").enabled).toBe(true)
    end)

    test("non-owner: needsClaim false (their existing preview covers them)", function()
        local vm = Model.viewModel(state({ claimed = false }))
        expect(vm.needsClaim).toBe(false)
    end)
end)

describe("TeahouseMenuModel.viewModel: shown-smaller hints (item B)", function()
    test("deck display cap below owned -> true", function()
        local vm = Model.viewModel(state({ maxDeckSize = "L", deckDisplay = "S" }))
        expect(vm.deckShownSmaller).toBe(true)
    end)
    test("deck display cap equal to owned -> false", function()
        local vm = Model.viewModel(state({ maxDeckSize = "L", deckDisplay = "L" }))
        expect(vm.deckShownSmaller).toBe(false)
    end)
    test("deck display nil -> false", function()
        local vm = Model.viewModel(state({ maxDeckSize = "L", deckDisplay = nil }))
        expect(vm.deckShownSmaller).toBe(false)
    end)
    test("teahouse display 'none' with an owned teahouse -> true", function()
        local vm = Model.viewModel(state({
            maxDeckSize = "L",
            teahouseSizes = { "S" },
            teahouseDisplay = "none",
        }))
        expect(vm.teahouseShownSmaller).toBe(true)
    end)
    test("teahouse display cap below owned -> true", function()
        local vm = Model.viewModel(state({
            maxDeckSize = "L",
            teahouseSizes = { "L" },
            teahouseDisplay = "S",
        }))
        expect(vm.teahouseShownSmaller).toBe(true)
    end)
    test("teahouse display cap equal to owned -> false", function()
        local vm = Model.viewModel(state({
            maxDeckSize = "L",
            teahouseSizes = { "L" },
            teahouseDisplay = "L",
        }))
        expect(vm.teahouseShownSmaller).toBe(false)
    end)
    test("teahouse display nil -> false", function()
        local vm = Model.viewModel(state({
            maxDeckSize = "L",
            teahouseSizes = { "L" },
            teahouseDisplay = nil,
        }))
        expect(vm.teahouseShownSmaller).toBe(false)
    end)
end)

describe("TeahouseMenuModel.canMove", function()
    test("claimed owner with a shown teahouse can move", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", teahouseSizes = { "S" }, claimed = true }))
        expect(vm.canMove).toBe(true)
    end)
    test("display 'none' means nothing is standing to move", function()
        local vm = Model.viewModel(
            state({ maxDeckSize = "M", teahouseSizes = { "S" }, claimed = true, teahouseDisplay = "none" })
        )
        expect(vm.canMove).toBe(false)
    end)
    test("unclaimed owner cannot move", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", teahouseSizes = { "S" }, claimed = false }))
        expect(vm.canMove).toBe(false)
    end)
    test("deck-only owner has no teahouse to move", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", teahouseSizes = {}, claimed = true }))
        expect(vm.canMove).toBe(false)
    end)
end)

describe("TeahouseMenuModel.viewModel — decorations", function()
    local DecorationCatalog = require("../src/shared/DecorationCatalog")

    local function baseState(over)
        local s = {
            totalPoints = 1000,
            maxDeckSize = "S",
            teahouseSizes = {},
            claimed = true,
            claimedPadId = "T01",
            deckDisplay = nil,
            teahouseDisplay = nil,
            padPreferences = {},
            portalOwned = false,
            deckDecorations = {},
            catalog = {
                deck = { S = 50, M = 500, L = 3000 },
                teahouse = { S = 30, M = 300, L = 2000 },
                portal = 500,
                decoration = { ishidoro = 40, tsukubai = 60, bonsai = 25, bench = 35 },
            },
        }
        for k, v in over or {} do
            s[k] = v
        end
        return s
    end

    test("lists all catalog props in catalog order with price + affordability", function()
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState())
        expect(#vm.decorations).toBe(#DecorationCatalog.ids())
        expect(vm.decorations[1].propId).toBe("ishidoro")
        expect(vm.decorations[1].price).toBe(40)
        expect(vm.decorations[1].affordable).toBe(true)
        expect(vm.decorations[1].canBuy).toBe(true)
    end)

    test("unaffordable prop is not buyable", function()
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState({ totalPoints = 10 }))
        for _, d in vm.decorations do
            expect(d.affordable).toBe(false)
            expect(d.canBuy).toBe(false)
        end
    end)

    test("no claim -> nothing buyable", function()
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(
            baseState({ claimed = false, claimedPadId = nil })
        )
        for _, d in vm.decorations do
            expect(d.canBuy).toBe(false)
        end
    end)

    test("no deck -> nothing buyable", function()
        -- table-constructor elision: { maxDeckSize = nil } never adds the key, so the merge
        -- loop above can't null it out -- assign after construction instead.
        local st = baseState()
        st.maxDeckSize = nil
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(st)
        for _, d in vm.decorations do
            expect(d.canBuy).toBe(false)
        end
    end)

    test("at the cap -> nothing buyable", function()
        local full = {}
        for i = 1, DecorationCatalog.MAX_DECORATIONS do
            table.insert(full, { id = i, propId = "bonsai", offset = { 0, 0 }, facing = "N" })
        end
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState({ deckDecorations = full }))
        for _, d in vm.decorations do
            expect(d.canBuy).toBe(false)
        end
    end)
end)

describe("TeahouseMenuModel.portal", function()
    local CAT =
        { deck = { S = 50, M = 500, L = 3000 }, teahouse = { S = 30, M = 300, L = 2000 }, portal = 500 }
    test("claimed deck-owner who can afford and doesn't own it can buy", function()
        local vm = Model.viewModel(
            state({ maxDeckSize = "S", claimed = true, totalPoints = 500, portalOwned = false, catalog = CAT })
        )
        expect(vm.portal.owned).toBe(false)
        expect(vm.portal.price).toBe(500)
        expect(vm.portal.canBuy).toBe(true)
    end)
    test("already owned -> not buyable", function()
        local vm = Model.viewModel(
            state({ maxDeckSize = "S", claimed = true, totalPoints = 500, portalOwned = true, catalog = CAT })
        )
        expect(vm.portal.owned).toBe(true)
        expect(vm.portal.canBuy).toBe(false)
    end)
    test("too poor -> not buyable", function()
        local vm = Model.viewModel(
            state({ maxDeckSize = "S", claimed = true, totalPoints = 0, portalOwned = false, catalog = CAT })
        )
        expect(vm.portal.affordable).toBe(false)
        expect(vm.portal.canBuy).toBe(false)
    end)
    test("unclaimed -> not buyable", function()
        local vm = Model.viewModel(state({
            maxDeckSize = "S",
            claimed = false,
            totalPoints = 500,
            portalOwned = false,
            catalog = CAT,
        }))
        expect(vm.portal.canBuy).toBe(false)
    end)
end)
