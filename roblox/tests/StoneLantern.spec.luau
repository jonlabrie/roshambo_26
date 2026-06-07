--!strict
local harness = require("./harness")
local StoneLantern = require("../tools/builders/StoneLantern")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("StoneLantern builder", function()
    test("builds a model with base, post, firebox, cap", function()
        local spec = StoneLantern.build(ZenDojo.palette, { 0, 0, 0 })
        expect(spec.className).toBe("Model")
        expect(#(spec.children :: any)).toBe(4)
    end)
    test("every part uses only palette colors", function()
        local spec = StoneLantern.build(ZenDojo.palette, { 0, 0, 0 })
        local allowed = {}
        for _, c in ZenDojo.palette :: any do
            allowed[table.concat(c, ",")] = true
        end
        for _, child in spec.children :: any do
            expect(allowed[table.concat(child.properties.Color, ",")]).toBe(true)
        end
    end)
    test("position offset moves every part", function()
        local a = StoneLantern.build(ZenDojo.palette, { 0, 0, 0 })
        local b = StoneLantern.build(ZenDojo.palette, { 10, 0, 0 })
        expect((b.children :: any)[1].properties.CFrame[1] - (a.children :: any)[1].properties.CFrame[1]).toBe(
            10
        )
    end)
end)
