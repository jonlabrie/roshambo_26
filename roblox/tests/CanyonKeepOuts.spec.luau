--!strict
local harness = require("./harness")
local CanyonKeepOuts = require("../tools/builders/CanyonKeepOuts")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("CanyonKeepOuts.materialBlocked", function()
    test("raked sand is untouchable", function()
        expect(CanyonKeepOuts.materialBlocked("Sand")).toBe(true)
    end)

    test("ordinary ground is not", function()
        expect(CanyonKeepOuts.materialBlocked("Slate")).toBe(false)
        expect(CanyonKeepOuts.materialBlocked("Ground")).toBe(false)
        expect(CanyonKeepOuts.materialBlocked("Grass")).toBe(false)
    end)

    test("an unsampled material does not block -- absence of data is not a refusal", function()
        expect(CanyonKeepOuts.materialBlocked(nil)).toBe(false)
    end)
end)

describe("CanyonKeepOuts.zoneAt", function()
    test("the karesansui's raked field is a zone", function()
        local zn = CanyonKeepOuts.zoneAt(6.5, 3.0) -- the model's centre
        expect(zn).toBeTruthy()
        expect((zn :: any).name).toBe("Karesansui")
    end)

    test("the zone covers the model's measured extent, x -21..34 by z -12..18", function()
        for _, p in
            {
                { -21, -12 },
                { 34, -12 },
                { -21, 18 },
                { 34, 18 },
                { 0, 0 },
            }
        do
            local zn = CanyonKeepOuts.zoneAt(p[1], p[2])
            expect(("(%d,%d): %s"):format(p[1], p[2], zn and "blocked" or "OPEN")).toBe(
                ("(%d,%d): blocked"):format(p[1], p[2])
            )
        end
    end)

    test("it carries a margin, so a clump's spread stays off the field", function()
        -- the widest scatter mesh is ~3.8 studs across; the margin must exceed half that
        expect(CanyonKeepOuts.zoneAt(-24, 0)).toBeTruthy() -- outside the model, inside the margin
        expect(CanyonKeepOuts.zoneAt(37, 0)).toBeTruthy()
    end)

    test("the wider canyon is open", function()
        expect(CanyonKeepOuts.zoneAt(-300, 30)).toBeNil() -- the pool shore
        expect(CanyonKeepOuts.zoneAt(-140, 12)).toBeNil() -- the traverse
        expect(CanyonKeepOuts.zoneAt(200, 0)).toBeNil() -- east of everything
    end)
end)

describe("CanyonKeepOuts.blocks", function()
    test("blocks on material alone, anywhere", function()
        local ok, why = CanyonKeepOuts.blocks(-300, 30, "Sand")
        expect(ok).toBe(true)
        expect(type(why)).toBe("string")
    end)

    test("blocks on zone alone, whatever the ground is", function()
        local ok, why = CanyonKeepOuts.blocks(6.5, 3.0, "Slate")
        expect(ok).toBe(true)
        expect((why :: string):match("Karesansui") ~= nil).toBe(true)
    end)

    test("passes open ground on an ordinary material", function()
        local ok, why = CanyonKeepOuts.blocks(-300, 30, "Slate")
        expect(ok).toBe(false)
        expect(why).toBeNil()
    end)

    test("always explains itself -- an unexplained refusal is undebuggable", function()
        local _, a = CanyonKeepOuts.blocks(6.5, 3.0, nil)
        local _, b = CanyonKeepOuts.blocks(-300, 30, "Sand")
        expect(type(a)).toBe("string")
        expect(type(b)).toBe("string")
    end)
end)

describe("CanyonKeepOuts.validate", function()
    test("the shipped data validates", function()
        local ok, errs = CanyonKeepOuts.validate()
        expect(table.concat(errs, " | ")).toBe("")
        expect(ok).toBe(true)
    end)

    test("every zone states a reason", function()
        for _, zn in CanyonKeepOuts.ZONES do
            expect(("%s: %s"):format(zn.name, zn.why ~= "" and "has reason" or "NO REASON")).toBe(
                ("%s: has reason"):format(zn.name)
            )
        end
    end)
end)
