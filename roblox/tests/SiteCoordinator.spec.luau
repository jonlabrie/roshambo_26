--!strict
local harness = require("./harness")
local SiteCoordinator = require("../src/shared/SiteCoordinator")
local PadRegistry = require("../src/shared/PadRegistry")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

local HUGE = { minX = -1000, maxX = 1000, minZ = -1000, maxZ = 1000 }
local function spec(id: string, footprint: any?)
    return {
        id = id,
        mountCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        footprint = footprint or HUGE,
        vacantForm = "dormant-structure",
    }
end
local LOADOUT = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }
local OWNED = { M = LOADOUT } -- a player owning a single (M) teahouse

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
        local a = c:onJoin("player1", OWNED)
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.kind).toBe("structure")
        expect((a :: any).treatment.lit).toBe(true)
        expect((a :: any).treatment.loadout).toBe(LOADOUT)
    end)

    test("a wanderer (nil map) claims nothing", function()
        local c = coordWithPads({ "p1" })
        expect(c:onJoin("player1", nil)).toBe(nil)
        expect((c:onJoin("player2", OWNED) :: any).padId).toBe("p1")
    end)

    test("an owner gets nil when every pad is occupied", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", OWNED)
        expect(c:onJoin("player2", OWNED)).toBe(nil)
    end)

    test("two owners claim two distinct pads; a third gets nil", function()
        local c = coordWithPads({ "p1", "p2" })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
        expect(c:onJoin("cc", OWNED)).toBe(nil)
    end)

    test("a duplicate onJoin by the same player claims nothing and consumes no extra pad", function()
        local c = coordWithPads({ "p1", "p2" })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect(c:onJoin("a", OWNED)).toBe(nil)
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
    end)

    test("picks the largest owned size that fits, with its scale/sizeClass", function()
        local c = SiteCoordinator.new(PadRegistry.new())
        c:registerPad("big", spec("big", SizeClasses.footprintFor("L")))
        local a = c:onJoin("p", { S = LOADOUT, M = LOADOUT, L = LOADOUT })
        expect((a :: any).sizeClass).toBe("L")
        expect((a :: any).scale).toBe(2.0)
        expect((a :: any).treatment.lit).toBe(true)
    end)

    test("falls back to a smaller owned size when the vacant pad is too small for the largest", function()
        -- pad fits M (1.5x) but not L (2x)
        local padFP = { minX = -11.84, maxX = 24.0, minZ = -18.72, maxZ = 6.912 }
        local c1 = SiteCoordinator.new(PadRegistry.new())
        c1:registerPad("m", spec("m", padFP))
        expect(c1:onJoin("p", { L = LOADOUT })).toBe(nil) -- owns only L, which doesn't fit

        local c2 = SiteCoordinator.new(PadRegistry.new())
        c2:registerPad("m", spec("m", padFP))
        local a = c2:onJoin("p", { L = LOADOUT, M = LOADOUT })
        expect((a :: any).sizeClass).toBe("M")
        expect((a :: any).scale).toBe(1.5)
    end)
end)

describe("SiteCoordinator.onLeave", function()
    test("a holder releases with a dormant treatment and frees the pad", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", OWNED)
        local a = c:onLeave("player1")
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.lit).toBe(false)
        expect((a :: any).treatment.loadout.colorScheme).toBe("scheme.dormant")
        expect((c:onJoin("player2", OWNED) :: any).padId).toBe("p1")
    end)

    test("a non-holder leaving is a no-op", function()
        local c = coordWithPads({ "p1" })
        expect(c:onLeave("ghost")).toBe(nil)
    end)

    test("dormant action carries the pad's native-size scale", function()
        local c = SiteCoordinator.new(PadRegistry.new())
        c:registerPad("big", spec("big", SizeClasses.footprintFor("L")))
        c:onJoin("p", { L = LOADOUT })
        expect((c:onLeave("p") :: any).scale).toBe(2.0) -- big pad's native size is L
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

    test("skips pads that are currently occupied", function()
        local c = coordWithPads({ "p1", "p2" })
        c:onJoin("player1", OWNED)
        local acts = c:vacantActions()
        expect(#acts).toBe(1)
        expect(acts[1].padId).toBe("p2")
    end)

    test("each dormant action carries the pad's native-size scale", function()
        local c = SiteCoordinator.new(PadRegistry.new())
        c:registerPad("small", spec("small", SizeClasses.footprintFor("S")))
        c:registerPad("big", spec("big", SizeClasses.footprintFor("L")))
        local acts = c:vacantActions()
        expect(acts[1].scale).toBe(1.0) -- small pad -> native S
        expect(acts[2].scale).toBe(2.0) -- big pad -> native L
    end)
end)
