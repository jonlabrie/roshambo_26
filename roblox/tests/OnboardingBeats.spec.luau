--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Beats = require("../src/shared/OnboardingBeats")

describe("OnboardingBeats", function()
    test("there are exactly four beats, in order, with distinct ids", function()
        expect(#Beats.BEATS).toBe(4)
        local ids = {}
        for _, b in Beats.BEATS do
            expect(ids[b.id]).toBe(nil)
            ids[b.id] = true
            expect(#b.copy > 0).toBe(true)
            expect(#b.anchor > 0).toBe(true)
        end
    end)

    test("no beat teaches movement — that is deliberate", function()
        -- the design de-emphasises movement and the owner narrates in person
        for _, b in Beats.BEATS do
            expect(b.id ~= "move").toBe(true)
        end
    end)

    test("an event returns its beat when unseen", function()
        local b = Beats.next({}, "join")
        expect(b ~= nil).toBe(true)
        expect(b.event).toBe("join")
    end)

    test("a seen beat never returns again", function()
        local b = Beats.next({}, "join")
        expect(Beats.next({ b.id }, "join")).toBe(nil)
    end)

    test("an unknown event returns nothing", function()
        expect(Beats.next({}, "sneezed")).toBe(nil)
    end)

    test("beats are independent — seeing one does not consume another", function()
        local first = Beats.next({}, "join")
        local second = Beats.next({ first.id }, "win")
        expect(second ~= nil).toBe(true)
        expect(second.event).toBe("win")
    end)

    test("events may arrive out of order", function()
        -- a player can win before anyone has explained the drum; the win beat still fires
        local b = Beats.next({}, "win")
        expect(b ~= nil).toBe(true)
        expect(b.event).toBe("win")
    end)
end)

describe("OnboardingBeats — anchors match what the HUD actually builds", function()
    test("no beat anchors to a plate that has left the top band", function()
        for _, beat in Beats.BEATS do
            expect(beat.anchor ~= "plate").toBe(true)
        end
    end)

    test("every anchor is one the controller knows", function()
        local known = { drum = true, throwArea = true, potIndicator = true, wallet = true }
        for _, beat in Beats.BEATS do
            expect(known[beat.anchor] == true).toBe(true)
        end
    end)
end)
