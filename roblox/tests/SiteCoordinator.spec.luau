--!strict
local harness = require("./harness")
local SiteCoordinator = require("../src/shared/SiteCoordinator")
local PadRegistry = require("../src/shared/PadRegistry")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function spec(id: string, maxSize: string?)
    return {
        id = id,
        mountCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        maxSize = maxSize or "L",
        vacantForm = "dormant-structure",
    }
end
local LOADOUT = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }
local OWNED = { M = LOADOUT }

local function coord(specs: { any })
    local c = SiteCoordinator.new(PadRegistry.new())
    for _, s in specs do
        c:registerPad(s.id, s)
    end
    return c
end

describe("SiteCoordinator.onJoin", function()
    test("an owner claims the first fitting site, lit, with size fields", function()
        local c = coord({ spec("p1"), spec("p2") })
        local a = c:onJoin("player1", OWNED)
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.lit).toBe(true)
        expect((a :: any).treatment.loadout).toBe(LOADOUT)
        expect((a :: any).sizeClass).toBe("M")
        expect((a :: any).scale).toBe(1.5)
        expect((a :: any).footprint.maxX).toBeCloseTo(SizeClasses.footprintFor("M").maxX)
    end)

    test("a wanderer (nil map) claims nothing", function()
        local c = coord({ spec("p1") })
        expect(c:onJoin("player1", nil)).toBe(nil)
        expect((c:onJoin("player2", OWNED) :: any).padId).toBe("p1")
    end)

    test("nil when every site is occupied", function()
        local c = coord({ spec("p1") })
        c:onJoin("player1", OWNED)
        expect(c:onJoin("player2", OWNED)).toBe(nil)
    end)

    test("two owners take two distinct sites; a third gets nil", function()
        local c = coord({ spec("p1"), spec("p2") })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
        expect(c:onJoin("cc", OWNED)).toBe(nil)
    end)

    test("duplicate onJoin by the same player claims nothing and consumes no site", function()
        local c = coord({ spec("p1"), spec("p2") })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect(c:onJoin("a", OWNED)).toBe(nil)
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
    end)

    test("biggest-first: owning S,M,L claims the L site at L", function()
        local c = coord({ spec("L1", "L"), spec("M1", "M"), spec("S1", "S") })
        local a = c:onJoin("p", { S = LOADOUT, M = LOADOUT, L = LOADOUT })
        expect((a :: any).padId).toBe("L1")
        expect((a :: any).sizeClass).toBe("L")
        expect((a :: any).scale).toBe(2.0)
    end)

    test("size-cap fallback: only-L owner + only an M-max site => nil; L,M owner => M on it", function()
        local c1 = coord({ spec("m", "M") })
        expect(c1:onJoin("p", { L = LOADOUT })).toBe(nil)

        local c2 = coord({ spec("m", "M") })
        local a = c2:onJoin("p", { L = LOADOUT, M = LOADOUT })
        expect((a :: any).padId).toBe("m")
        expect((a :: any).sizeClass).toBe("M")
    end)
end)

describe("SiteCoordinator.onJoin preference", function()
    local function sites()
        return { spec("T02", "L"), spec("T06", "M"), spec("T04", "S") }
    end
    local OWNED_MS = { M = LOADOUT, S = LOADOUT }

    test("a preferred site is claimed first within the fitting size tier", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS, { "T06" })
        expect((a :: any).padId).toBe("T06")
        expect((a :: any).sizeClass).toBe("M")
    end)

    test("size stays primary: preference never trades away a larger owned size", function()
        local c = coord(sites())
        -- owns only L; prefers the M-max site T06, which cannot fit L
        local a = c:onJoin("p1", { L = LOADOUT }, { "T06" })
        expect((a :: any).padId).toBe("T02")
        expect((a :: any).sizeClass).toBe("L")
    end)

    test("nil preference reproduces registration order", function()
        local c = coord(sites())
        -- M is the biggest owned; T06 is the only M-max site (T02 is L-max and fits M too);
        -- registration order tries T02 first, which fits M -> T02.
        local a = c:onJoin("p1", OWNED_MS, nil)
        expect((a :: any).padId).toBe("T02")
    end)

    test("a stale/unregistered preference id is ignored", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS, { "NOPE", "T06" })
        expect((a :: any).padId).toBe("T06")
    end)

    test("a duplicate preferred id does not double-place or error", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS, { "T06", "T06" })
        expect((a :: any).padId).toBe("T06")
    end)
end)

describe("SiteCoordinator.onLeave", function()
    test("a holder releases dormant at the site's max size and frees it", function()
        local c = coord({ spec("L1", "L") })
        c:onJoin("player1", { L = LOADOUT })
        local a = c:onLeave("player1")
        expect((a :: any).treatment.lit).toBe(false)
        expect((a :: any).treatment.loadout.colorScheme).toBe("scheme.dormant")
        expect((a :: any).scale).toBe(2.0)
        expect((c:onJoin("player2", { L = LOADOUT }) :: any).padId).toBe("L1")
    end)

    test("a non-holder leaving is a no-op", function()
        local c = coord({ spec("p1") })
        expect(c:onLeave("ghost")).toBe(nil)
    end)
end)

describe("SiteCoordinator.vacantActions", function()
    test("one dormant action per site at the site's max-size scale", function()
        local c = coord({ spec("L1", "L"), spec("S1", "S") })
        local acts = c:vacantActions()
        expect(#acts).toBe(2)
        expect(acts[1].scale).toBe(2.0)
        expect(acts[2].scale).toBe(1.0)
        expect(acts[1].treatment.lit).toBe(false)
    end)

    test("skips occupied sites", function()
        local c = coord({ spec("p1"), spec("p2") })
        c:onJoin("player1", OWNED)
        local acts = c:vacantActions()
        expect(#acts).toBe(1)
        expect(acts[1].padId).toBe("p2")
    end)
end)
