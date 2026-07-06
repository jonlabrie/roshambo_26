--!strict
local harness = require("./harness")
local SiteCoordinator = require("../src/shared/SiteCoordinator")
local PadRegistry = require("../src/shared/PadRegistry")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function spec(id: string)
    return {
        id = id,
        mountCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        footprint = {},
        vacantForm = "dormant-structure",
    }
end
local LOADOUT = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }

local function coordWithPads(ids: { string })
    local c = SiteCoordinator.new(PadRegistry.new())
    for _, id in ids do
        c:registerPad(id, spec(id))
    end
    return c
end

describe("SiteCoordinator.onJoin", function()
    test("an owner claims the first vacant pad with a lit treatment", function()
        local c = coordWithPads({ "p1", "p2" })
        local a = c:onJoin("player1", LOADOUT)
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.kind).toBe("structure")
        expect((a :: any).treatment.lit).toBe(true)
        expect((a :: any).treatment.loadout).toBe(LOADOUT)
    end)

    test("a wanderer (nil loadout) claims nothing", function()
        local c = coordWithPads({ "p1" })
        expect(c:onJoin("player1", nil)).toBe(nil)
        -- pad still vacant: a real owner can still claim it
        expect((c:onJoin("player2", LOADOUT) :: any).padId).toBe("p1")
    end)

    test("an owner gets nil when every pad is occupied", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", LOADOUT)
        expect(c:onJoin("player2", LOADOUT)).toBe(nil)
    end)

    test("two owners claim two distinct pads; a third gets nil", function()
        local c = coordWithPads({ "p1", "p2" })
        expect((c:onJoin("a", LOADOUT) :: any).padId).toBe("p1")
        expect((c:onJoin("b", LOADOUT) :: any).padId).toBe("p2")
        expect(c:onJoin("cc", LOADOUT)).toBe(nil)
    end)
end)

describe("SiteCoordinator.onLeave", function()
    test("a holder releases with a dormant treatment and frees the pad", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", LOADOUT)
        local a = c:onLeave("player1")
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.lit).toBe(false)
        expect((a :: any).treatment.loadout.colorScheme).toBe("scheme.dormant")
        -- freed: a new owner can claim it again
        expect((c:onJoin("player2", LOADOUT) :: any).padId).toBe("p1")
    end)

    test("a non-holder leaving is a no-op", function()
        local c = coordWithPads({ "p1" })
        expect(c:onLeave("ghost")).toBe(nil)
    end)
end)

describe("SiteCoordinator.vacantActions", function()
    test("one dormant action per registered pad", function()
        local c = coordWithPads({ "p1", "p2" })
        local acts = c:vacantActions()
        expect(#acts).toBe(2)
        expect(acts[1].padId).toBe("p1")
        expect(acts[1].treatment.lit).toBe(false)
        expect(acts[2].padId).toBe("p2")
    end)
end)
