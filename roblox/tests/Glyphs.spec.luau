--!strict
local harness = require("./harness")
local Glyphs = require("../src/shared/Glyphs")
local describe, test, expect = harness.describe, harness.test, harness.expect

local GOLD = { 0.83, 0.69, 0.40 }

describe("Glyphs.parts", function()
    test("rock is an outlined ring: white outline behind, colored core in front", function()
        local p = Glyphs.parts("R", GOLD)
        expect(#p).toBe(2)
        expect(p[1].kind).toBe("ring")
        expect(p[2].kind).toBe("ring")
        -- outline is white and thicker than the core
        expect(p[1].color[1]).toBe(1)
        expect(p[1].color[2]).toBe(1)
        expect(p[1].color[3]).toBe(1)
        expect(p[1].thickness > p[2].thickness).toBe(true)
        -- core carries the requested color
        expect(p[2].color[1]).toBe(GOLD[1])
    end)

    test("paper is an outlined horizontal bar (outline taller than core, both centered)", function()
        local p = Glyphs.parts("P", GOLD)
        expect(#p).toBe(2)
        expect(p[1].kind).toBe("bar")
        expect(p[2].kind).toBe("bar")
        expect(p[1].size[2] > p[2].size[2]).toBe(true) -- outline height > core height
        expect(p[1].pos[2]).toBe(0.5) -- centered vertically
        expect(p[1].rotation).toBe(0)
    end)

    test("scissors is an upward chevron: two mirrored arms, apex up", function()
        local p = Glyphs.parts("S", GOLD)
        expect(#p).toBe(4) -- 2 arms x (outline + core)
        -- every arm centre sits in the upper half (apex up => arm midpoints above 0.5)
        for _, part in p do
            expect(part.kind).toBe("bar")
            expect(part.pos[2] < 0.5).toBe(true)
        end
        -- arms mirror about x=0.5: at least one left (x<0.5) and one right (x>0.5)
        local left, right = false, false
        for _, part in p do
            if part.pos[1] < 0.5 then
                left = true
            elseif part.pos[1] > 0.5 then
                right = true
            end
        end
        expect(left and right).toBe(true)
    end)

    test("outlineColor override is honored", function()
        local p = Glyphs.parts("P", GOLD, { outlineColor = { 0, 0, 0 } })
        expect(p[1].color[1]).toBe(0)
        expect(p[1].color[2]).toBe(0)
        expect(p[1].color[3]).toBe(0)
    end)
end)
