--!strict
local harness = require("./harness")
local Graybox = require("../tools/builders/Graybox")
local L = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Graybox", function()
    test("emits a shell for every layout landmark", function()
        local spec = Graybox.build(L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        for _, want in { "ToriiShell", "SteleShell" } do
            expect(names[want]).toBe(true)
        end
        expect(names["TeahouseShell1"]).toBe(true)
        expect(names["TeahouseShell3"]).toBe(true)
        expect(names["Promontory_Record"]).toBe(true)
        expect(names["Promontory_LocalHero"]).toBe(true)
    end)
end)
