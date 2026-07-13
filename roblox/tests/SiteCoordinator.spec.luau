--!strict
local harness = require("./harness")
local SiteCoordinator = require("../src/shared/SiteCoordinator")
local PadRegistry = require("../src/shared/PadRegistry")
local describe, test, expect = harness.describe, harness.test, harness.expect

local PLACEMENT = { offset = { 0, 0 }, facing = "N" }
local function spec(id: string, maxSize: string?)
    return {
        id = id,
        maxSize = maxSize or "L",
        deckSize = maxSize or "L",
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

-- Brief-shaped helper: registers pads from bare { id, maxSize } tables (as opposed to
-- `coord`, which takes fully-built specs via `spec()`).
local function makeCoordinatorWithSites(sites: { { id: string, maxSize: string? } })
    local specs = {}
    for _, s in sites do
        table.insert(specs, spec(s.id, s.maxSize))
    end
    return coord(specs)
end

-- economy shapes: a deck owner with a set of built teahouses (biggest-owned-within-deck wins)
local OWNED_ECONOMY = { maxDeckSize = "L", teahouses = OWNED }

describe("SiteCoordinator.onJoin", function()
    test("an owner claims the first fitting site, lit, with deck + teahouse fields", function()
        local c = coord({ spec("p1"), spec("p2") })
        local a = c:onJoin("player1", OWNED_ECONOMY)
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.lit).toBe(true)
        expect((a :: any).treatment.loadout).toBe(LOADOUT)
        -- deck = the site's maxSize (L), capped from the owner's L maxDeckSize; building =
        -- the owner's M teahouse on the site placement
        expect((a :: any).deckSize).toBe("L")
        expect((a :: any).teahouse.size).toBe("M")
        expect((a :: any).teahouse.loadout).toBe(LOADOUT)
        expect((a :: any).teahouse.placement).toEqual(PLACEMENT)
    end)

    test("a wanderer (nil economy) claims nothing", function()
        local c = coord({ spec("p1") })
        expect(c:onJoin("player1", nil)).toBe(nil)
        expect((c:onJoin("player2", OWNED_ECONOMY) :: any).padId).toBe("p1")
    end)

    test("nil when every site is occupied", function()
        local c = coord({ spec("p1") })
        c:onJoin("player1", OWNED_ECONOMY)
        expect(c:onJoin("player2", OWNED_ECONOMY)).toBe(nil)
    end)

    test("two owners take two distinct sites; a third gets nil", function()
        local c = coord({ spec("p1"), spec("p2") })
        expect((c:onJoin("a", OWNED_ECONOMY) :: any).padId).toBe("p1")
        expect((c:onJoin("b", OWNED_ECONOMY) :: any).padId).toBe("p2")
        expect(c:onJoin("cc", OWNED_ECONOMY)).toBe(nil)
    end)

    test("duplicate onJoin by the same player claims nothing and consumes no site", function()
        local c = coord({ spec("p1"), spec("p2") })
        expect((c:onJoin("a", OWNED_ECONOMY) :: any).padId).toBe("p1")
        expect(c:onJoin("a", OWNED_ECONOMY)).toBe(nil)
        expect((c:onJoin("b", OWNED_ECONOMY) :: any).padId).toBe("p2")
    end)

    test(
        "first vacant site in registration order is claimed; teahouse is the biggest owned, capped to the deck",
        function()
            local c = coord({ spec("L1", "L"), spec("M1", "M"), spec("S1", "S") })
            local a =
                c:onJoin("p", { maxDeckSize = "L", teahouses = { S = LOADOUT, M = LOADOUT, L = LOADOUT } })
            expect((a :: any).padId).toBe("L1")
            expect((a :: any).teahouse.size).toBe("L")
        end
    )

    test(
        "deck and teahouse are CAPPED to the perch's maxSize, not gated (no more nil-on-mismatch)",
        function()
            -- an L-deck owner still claims an M-max site; the deck is capped down to M, deck-only
            local c1 = coord({ spec("m", "M") })
            local a1 = c1:onJoin("p", { maxDeckSize = "L", teahouses = {} })
            expect((a1 :: any).padId).toBe("m")
            expect((a1 :: any).deckSize).toBe("M")
            expect((a1 :: any).teahouse == nil).toBe(true)

            -- with an L teahouse also owned, the teahouse built is likewise capped down to M
            local c2 = coord({ spec("m", "M") })
            local a2 = c2:onJoin("p", { maxDeckSize = "L", teahouses = { L = LOADOUT, M = LOADOUT } })
            expect((a2 :: any).padId).toBe("m")
            expect((a2 :: any).teahouse.size).toBe("M")
        end
    )

    test("deck-only owner claims a bare deck (no teahouse)", function()
        local sc = makeCoordinatorWithSites({ { id = "P1", maxSize = "L" } })
        local action = sc:onJoin("u1", { maxDeckSize = "S", teahouses = {} }, nil)
        expect(action.deckSize).toBe("S")
        expect(action.teahouse == nil).toBe(true)
    end)

    test("sizes come from inventory (maxDeckSize), not the pad default", function()
        local sc = makeCoordinatorWithSites({ { id = "P1", maxSize = "L" } })
        local action =
            sc:onJoin("u1", { maxDeckSize = "M", teahouses = { S = { baseStyle = "teahouse-1story" } } }, nil)
        expect(action.deckSize).toBe("M")
        expect(action.teahouse.size).toBe("S") -- biggest owned teahouse (S) within the M deck
    end)

    test("a player who owns no deck does not claim", function()
        local sc = makeCoordinatorWithSites({ { id = "P1", maxSize = "L" } })
        expect(sc:onJoin("u1", { maxDeckSize = nil, teahouses = {} }, nil) == nil).toBe(true)
        expect(sc:onJoin("u1", nil, nil) == nil).toBe(true)
    end)
end)

describe("SiteCoordinator.onJoin preference", function()
    local function sites()
        return { spec("T02", "L"), spec("T06", "M"), spec("T04", "S") }
    end
    local OWNED_MS_ECONOMY = { maxDeckSize = "M", teahouses = { M = LOADOUT, S = LOADOUT } }

    test("a preferred site is claimed first within the fitting size tier", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS_ECONOMY, { "T06" })
        expect((a :: any).padId).toBe("T06")
        expect((a :: any).teahouse.size).toBe("M")
    end)

    test("preference is honored into a smaller-max site: deck/teahouse cap down, no gating", function()
        local c = coord(sites())
        -- owns an L deck + L teahouse; prefers the M-max site T06 -> claims T06, capped to M
        local a = c:onJoin("p1", { maxDeckSize = "L", teahouses = { L = LOADOUT } }, { "T06" })
        expect((a :: any).padId).toBe("T06")
        expect((a :: any).deckSize).toBe("M")
        expect((a :: any).teahouse.size).toBe("M")
    end)

    test("nil preference reproduces registration order", function()
        local c = coord(sites())
        -- registration order tries T02 first; the first vacant site is always claimed
        local a = c:onJoin("p1", OWNED_MS_ECONOMY, nil)
        expect((a :: any).padId).toBe("T02")
    end)

    test("a stale/unregistered preference id is ignored", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS_ECONOMY, { "NOPE", "T06" })
        expect((a :: any).padId).toBe("T06")
    end)

    test("a duplicate preferred id does not double-place or error", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS_ECONOMY, { "T06", "T06" })
        expect((a :: any).padId).toBe("T06")
    end)
end)

describe("SiteCoordinator.onLeave", function()
    test("a holder releases to the S starter bundle and frees the site", function()
        local c = coord({ spec("L1", "L") })
        c:onJoin("player1", { maxDeckSize = "L", teahouses = { L = LOADOUT } })
        local a = c:onLeave("player1")
        expect((a :: any).treatment.lit).toBe(false)
        expect((a :: any).treatment.loadout.colorScheme).toBe("scheme.dormant")
        -- reverts to S deck + dormant S teahouse (NOT the perch max size)
        expect((a :: any).deckSize).toBe("S")
        expect((a :: any).teahouse.size).toBe("S")
        expect((a :: any).teahouse.loadout.colorScheme).toBe("scheme.dormant")
        expect((c:onJoin("player2", { maxDeckSize = "L", teahouses = { L = LOADOUT } }) :: any).padId).toBe(
            "L1"
        )
    end)

    test("a non-holder leaving is a no-op", function()
        local c = coord({ spec("p1") })
        expect(c:onLeave("ghost")).toBe(nil)
    end)
end)

describe("SiteCoordinator.isVacant", function()
    test("a registered, unclaimed pad is vacant", function()
        local c = coord({ spec("p1") })
        expect(c:isVacant("p1")).toBe(true)
    end)

    test("a claimed pad is not vacant", function()
        local c = coord({ spec("p1") })
        c:onJoin("player1", OWNED_ECONOMY)
        expect(c:isVacant("p1")).toBe(false)
    end)

    test("an unregistered pad id is not vacant", function()
        local c = coord({ spec("p1") })
        expect(c:isVacant("NOPE")).toBe(false)
    end)
end)

describe("SiteCoordinator.vacantActions", function()
    test("one S-starter dormant action per site (S deck + dormant S teahouse), regardless of max", function()
        local c = coord({ spec("L1", "L"), spec("S1", "S") })
        local acts = c:vacantActions()
        expect(#acts).toBe(2)
        -- both are the S starter, even the L-max perch
        expect(acts[1].deckSize).toBe("S")
        expect(acts[1].teahouse.size).toBe("S")
        expect(acts[1].treatment.lit).toBe(false)
    end)

    test("skips occupied sites", function()
        local c = coord({ spec("p1"), spec("p2") })
        c:onJoin("player1", OWNED_ECONOMY)
        local acts = c:vacantActions()
        expect(#acts).toBe(1)
        expect(acts[1].padId).toBe("p2")
    end)
end)
