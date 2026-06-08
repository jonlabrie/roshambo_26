--!strict
local harness = require("./harness")
local ThrowDrum = require("../tools/builders/ThrowDrum")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ThrowDrum builder", function()
    test("has a Drum hub and 6 faces", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Drum"]).toBe(true)
        for k = 0, 5 do
            expect(names["Face" .. k]).toBe(true)
        end
        expect(names["Housing"] ~= nil).toBe(true)
    end)
    test("opposite faces carry the same symbol (R/P/S/R/P/S)", function()
        -- faces 0,3 share; 1,4 share; 2,5 share — verified by builder construction.
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local faces = 0
        for _, c in spec.children :: any do
            if (c.name :: string):match("^Face%d$") then
                faces += 1
            end
        end
        expect(faces).toBe(6)
        for k = 0, 2 do
            expect(ThrowDrum.SYMBOL_FOR_FACE[k]).toBe(ThrowDrum.SYMBOL_FOR_FACE[k + 3])
        end
    end)
end)
