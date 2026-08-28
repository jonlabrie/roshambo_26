--!strict
local harness = require("./harness")
local BirdVoice = require("../src/shared/BirdVoice")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BirdVoice", function()
    test("every species has clips, and every id is a whole number", function()
        -- ⚠ A typo'd asset id fails SILENTLY in Roblox: the Sound simply never plays, and the
        -- bird looks like it chose not to sing. Guarding the shape here is the only cheap check.
        local n = 0
        for species, voice in BirdVoice.VOICE do
            n += 1
            expect(#voice.clips > 0).toBe(true)
            expect(voice.volume > 0).toBe(true)
            expect(voice.rolloff[1] < voice.rolloff[2]).toBe(true)
            for _, c in voice.clips do
                expect(c.id % 1 == 0).toBe(true)
                expect(c.id > 0).toBe(true)
                expect(c.weight > 0).toBe(true)
            end
            expect(typeof(species)).toBe("string")
        end
        expect(n >= 2).toBe(true) -- uguisu and karasu at minimum
    end)

    test("an unknown species is SILENT rather than borrowing another bird's voice", function()
        -- ⚠ Falling back to the uguisu would make a new bird sound like a warbler, and the bug
        -- would present as "the crane sounds wrong" rather than "the crane has no voice yet".
        expect(BirdVoice.pick("Crane", function()
            return 0.5
        end)).toBe(nil)
        expect(BirdVoice.pick("", function()
            return 0.5
        end)).toBe(nil)
    end)

    test("the pick is WEIGHTED, not uniform", function()
        -- The karasu's clips are 1, 2 and 3 caws. Uniform would make a two-second three-caw
        -- declaration a third of all songs; the long one has to stay uncommon to stay an event.
        local k = BirdVoice.VOICE.Karasu
        local total = 0
        for _, c in k.clips do
            total += c.weight
        end
        local first, last = k.clips[1].weight / total, k.clips[#k.clips].weight / total
        expect(first > last).toBe(true)
        expect(last < 0.3).toBe(true)
    end)

    test("every point in 0..1 selects a clip, and the boundaries do not fall off the end", function()
        for _, species in { "Uguisu", "Karasu" } do
            for i = 0, 100 do
                local id = BirdVoice.pick(species, function()
                    return i / 100
                end)
                expect(id ~= nil).toBe(true)
            end
        end
    end)

    test("the distribution actually follows the weights", function()
        -- Walk r across 0..1 and count which clip each lands on; the proportions must track the
        -- declared weights. A pick that ignored weight would still pass the boundary test above.
        local k = BirdVoice.VOICE.Karasu
        local total = 0
        for _, c in k.clips do
            total += c.weight
        end
        local counts: { [number]: number } = {}
        local N = 10000
        for i = 0, N - 1 do
            local id = BirdVoice.pick("Karasu", function()
                return i / N
            end)
            counts[id :: number] = (counts[id :: number] or 0) + 1
        end
        for _, c in k.clips do
            local share = (counts[c.id] or 0) / N
            local want = c.weight / total
            expect(math.abs(share - want) < 0.01).toBe(true)
        end
    end)
end)
