--!strict
local harness = require("./harness")
local Kamon = require("../src/shared/Kamon")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Kamon", function()
    test("fourteen crests, every id unique", function()
        expect(#Kamon.CRESTS).toBe(14)
        local seen = {}
        for _, c in Kamon.CRESTS do
            expect(seen[c.id]).toBe(nil)
            seen[c.id] = true
        end
    end)

    test("every crest draws from ring, disc and bar ONLY — the no-upload guarantee", function()
        -- This is the test that keeps the catalog free of image assets. Roblox removed a green
        -- palmate leaf from this account (practice/image-moderation.md) and plants are the
        -- commonest kamon motif, so a drawable catalog has no moderation surface at all. A fourth
        -- primitive would almost certainly mean an image, so it must fail here first.
        local allowed = { ring = true, disc = true, bar = true }
        for _, c in Kamon.CRESTS do
            expect(#c.shapes > 0).toBe(true)
            for _, s in c.shapes do
                expect(allowed[s.kind]).toBe(true)
            end
        end
    end)

    test("the three throw glyphs each have a family, and none is empty", function()
        -- The catalog is built on this game's own vocabulary: circle, bar, chevron.
        local counts: { [string]: number } = {}
        for _, c in Kamon.CRESTS do
            counts[c.family] = (counts[c.family] or 0) + 1
        end
        for _, f in { "circle", "bar", "chevron", "neutral" } do
            expect((counts[f] or 0) > 0).toBe(true)
        end
    end)

    test("every shape stays inside the normalised square, so nothing clips its surface", function()
        for _, c in Kamon.CRESTS do
            for _, s in c.shapes do
                local x, y = s.x or 0, s.y or 0
                local reach = if s.kind == "bar" then math.max(s.w, s.h) / 2 else s.r
                expect(math.abs(x) + reach <= 0.62).toBe(true)
                expect(math.abs(y) + reach <= 0.62).toBe(true)
            end
        end
    end)

    test("assignment is deterministic and stable for the same id", function()
        expect(Kamon.forUserId("12345").id).toBe(Kamon.forUserId("12345").id)
        expect(Kamon.forUserId("").id ~= nil).toBe(true)
    end)

    test("assignment spreads across the catalog rather than favouring one crest", function()
        -- A weak hash would give everyone the same mon, which looks like a bug and reads as one.
        local seen: { [string]: boolean } = {}
        local n = 0
        for i = 1, 400 do
            local id = Kamon.forUserId(tostring(i * 7919)).id
            if not seen[id] then
                seen[id] = true
                n += 1
            end
        end
        expect(n).toBe(14)
    end)

    test("byId round-trips, and an unknown id is nil rather than a default", function()
        expect(Kamon.byId("janome").id).toBe("janome")
        expect(Kamon.byId("no-such-crest")).toBe(nil)
        expect(Kamon.byId(nil)).toBe(nil)
    end)
end)
