--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Beats = require("../src/shared/OnboardingBeats")

describe("OnboardingBeats — the journey's chain", function()
    test("eight beats, in journey order, with distinct ids", function()
        expect(#Beats.BEATS).toBe(8)
        local order =
            { "welcome", "throw", "win", "bank", "shopDoor", "launchDoor", "modelDoor", "modelHome" }
        for i, b in Beats.BEATS do
            expect(b.id).toBe(order[i])
            expect(#b.copy > 0).toBe(true)
            expect(#b.anchor > 0).toBe(true)
        end
    end)

    test("each tour beat fires on the event the previous one advances on", function()
        -- the chain: bank card dismissed -> shop -> shell bought -> launch -> shell launched ->
        -- model -> arrival. advanceOn is the controller's advance-through hook (a tour event
        -- arriving while its predecessor's card is still up dismisses it rather than dropping).
        local byId = {}
        for _, b in Beats.BEATS do
            byId[b.id] = b
        end
        expect(byId.shopDoor.event).toBe("bankDismissed")
        expect(byId.shopDoor.advanceOn).toBe("shellBought")
        expect(byId.launchDoor.event).toBe("shellBought")
        expect(byId.launchDoor.advanceOn).toBe("shellLaunched")
        expect(byId.modelDoor.event).toBe("shellLaunched")
        expect(byId.modelDoor.advanceOn).toBe("modelArrival")
        expect(byId.modelHome.event).toBe("modelArrival")
        expect(byId.modelHome.advanceOn).toBe(nil)
    end)

    test("the welcome carries three pages and copy is page one", function()
        local welcome = Beats.BEATS[1]
        expect(welcome.event).toBe("join")
        expect(welcome.pages ~= nil).toBe(true)
        expect(#welcome.pages).toBe(3)
        for _, page in welcome.pages do
            expect(#page > 0).toBe(true)
        end
        expect(welcome.copy).toBe(welcome.pages[1])
    end)

    test("only the welcome has pages — every other beat is one card", function()
        for i, b in Beats.BEATS do
            if i > 1 then
                expect(b.pages).toBe(nil)
            end
        end
    end)

    test("no beat teaches movement — that is deliberate", function()
        -- the HUD de-emphasises movement DURING PLAY; tour beats direct travel between stops,
        -- which is a tour's job, but none of them may point at the thumbstick itself.
        for _, b in Beats.BEATS do
            expect(b.id ~= "move").toBe(true)
        end
    end)

    test("no copy uses gambling vocabulary (owner ruling)", function()
        -- 'pot', 'ride', 'stake', 'wager', 'bet' are banned near points; 'pile' is the
        -- sanctioned replacement. Checked on WORD BOUNDARIES ('%f[%a]bet%f[%A]') so 'better'
        -- or a future 'bets' can't slip past on a substring technicality.
        for _, b in Beats.BEATS do
            local pages = b.pages or { b.copy }
            for _, text in pages do
                local lower = text:lower()
                for _, banned in { "pot", "ride", "stake", "wager", "bet" } do
                    expect(lower:find("%f[%a]" .. banned .. "%f[%A]")).toBe(nil)
                end
            end
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
        local b = Beats.next({}, "win")
        expect(b ~= nil).toBe(true)
        expect(b.event).toBe("win")
    end)

    test("the bank beat teaches the ring gesture, not just the bank itself", function()
        -- The ring replaced the hamburger but looks like a readout — this beat is the only thing
        -- left to teach the tap. The copy must name the clock/ring itself AND describe what the
        -- second tap reaches (the ledger's full detail), not just "tap...again".
        local b = Beats.next({}, "bank")
        expect(b ~= nil).toBe(true)
        expect(b.anchor).toBe("wallet")
        local lower = b.copy:lower()
        expect(lower:find("clock") ~= nil or lower:find("ring") ~= nil).toBe(true)
        expect(lower:find("everything") ~= nil or lower:find("ledger") ~= nil).toBe(true)
    end)
end)

describe("OnboardingBeats — anchors match what the controller builds", function()
    test("no beat anchors to a plate that has left the top band", function()
        for _, beat in Beats.BEATS do
            expect(beat.anchor ~= "plate").toBe(true)
        end
    end)

    test("every anchor is one the controller knows", function()
        local known = { drum = true, throwArea = true, potIndicator = true, wallet = true, tour = true }
        for _, beat in Beats.BEATS do
            expect(known[beat.anchor] == true).toBe(true)
        end
    end)

    test("all four tour beats share the tour anchor", function()
        for i, beat in Beats.BEATS do
            if i >= 5 then
                expect(beat.anchor).toBe("tour")
            end
        end
    end)
end)
