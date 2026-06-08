--!strict
local harness = require("./harness")
local JumbotronFrame = require("../tools/builders/JumbotronFrame")
local L = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("JumbotronFrame builder", function()
    test("four lacquer bars + four gold trim bars", function()
        local spec = JumbotronFrame.build(L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        for _, want in { "FrameTop", "FrameBottom", "FrameLeft", "FrameRight", "Trim1", "Trim4" } do
            expect(names[want]).toBe(true)
        end
    end)
    test("frame surrounds the board (top bar above the board's top edge)", function()
        local spec = JumbotronFrame.build(L)
        local boardTop = L.jumbotron.pos[2] + L.jumbotron.size[2] / 2
        for _, c in spec.children :: any do
            if c.name == "FrameTop" then
                expect(c.properties.CFrame[2] > boardTop).toBe(true)
            end
        end
    end)
end)
