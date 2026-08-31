--!strict
-- ⚠ THE CONTRACT BETWEEN THE BIRD DATA AND EVERYTHING THAT READS IT.
--
-- `BirdGape.spec` tests the karasu's clips specifically, which is right -- its onsets are measured
-- and worth pinning. This file tests the SHAPE every species must have, so that adding bird #3
-- cannot introduce a defect that only shows up as a silent familiar or a division by zero inside
-- `BirdFlight.profile` at spawn.
--
-- ⚠ NONE OF THIS ASSERTS WHAT A BIRD LOOKS LIKE OR SOUNDS LIKE. That is the owner's ear and eye.
-- What is checked is only what is mechanically checkable, which is exactly the class of defect a
-- person will not notice: onsets running past the end of a recording, a rolloff pair the wrong
-- way round, a clip id pasted twice.
local harness = require("./harness")
local BirdSpecies = require("../src/shared/BirdSpecies")
local BirdFlight = require("../src/shared/BirdFlight")
local describe, test, expect = harness.describe, harness.test, harness.expect

local SPECIES = (BirdSpecies :: any).SPECIES

describe("BirdSpecies contract", function()
    test("every species has a body length BirdFlight can build a profile from", function()
        -- ⚠ `BirdFlight.profile` REFUSES a non-positive scale rather than clamping: a zero makes
        -- every duration zero and every clock a division by zero, and NaN surfaces frames later
        -- as "the bird vanished". A bad bodyLength would trip that at spawn, not here.
        local n = 0
        local ref = SPECIES[BirdSpecies.REFERENCE].bodyLength
        for _, sp in SPECIES do
            n += 1
            expect(type(sp.bodyLength) == "number").toBe(true)
            expect(sp.bodyLength > 0).toBe(true)
            local profile = BirdFlight.profile(sp.bodyLength / ref)
            expect(profile.scale > 0).toBe(true)
            expect(profile.time > 0).toBe(true)
        end
        expect(n > 0).toBe(true)
    end)

    test("the reference species exists and is its own unit", function()
        -- Every motion constant in BirdFlight was tuned against this bird, so its scale must come
        -- out at exactly 1 or the one bird the owner has actually watched is re-timed.
        local ref = SPECIES[BirdSpecies.REFERENCE]
        expect(ref ~= nil).toBe(true)
        expect(BirdFlight.profile(ref.bodyLength / ref.bodyLength).scale).toBe(1)
    end)

    test("every voice is playable: real ids, positive weights, an ascending rolloff", function()
        for name, _ in SPECIES do
            local voice = BirdSpecies.voiceOf(name)
            if voice then
                expect(#voice.clips > 0).toBe(true)
                for _, c in voice.clips do
                    expect(type(c.id) == "number" and c.id > 0).toBe(true)
                    expect(type(c.weight) == "number" and c.weight > 0).toBe(true)
                end
                expect(voice.volume > 0).toBe(true)
                expect(#voice.rolloff == 2).toBe(true)
                -- min before max, or the sound is audible everywhere or nowhere
                expect(voice.rolloff[1] < voice.rolloff[2]).toBe(true)
            end
        end
    end)

    test("clip ids are unique within a voice", function()
        -- A duplicated id errors nowhere; it just makes one call twice as likely as the weights
        -- say, which is invisible and unfalsifiable by ear.
        for name, _ in SPECIES do
            local voice = BirdSpecies.voiceOf(name)
            if voice then
                local seen: { [number]: boolean } = {}
                for _, c in voice.clips do
                    expect(seen[c.id]).toBe(nil)
                    seen[c.id] = true
                end
            end
        end
    end)

    test("a clip with onsets carries its duration, and the gape fits inside it", function()
        -- ⚠ ONSETS AND `seconds` ARE ONE FACT. `gapeAt` holds the beak open for
        -- CAW_GAPE_SECONDS from each onset; an onset too near the end leaves it open after the
        -- sound has stopped, which reads as a bird still calling in silence.
        for name, _ in SPECIES do
            local voice = BirdSpecies.voiceOf(name)
            if voice then
                for _, c in voice.clips do
                    if c.caws then
                        expect(type(c.seconds) == "number").toBe(true)
                        local secs = c.seconds :: number
                        expect(secs > 0).toBe(true)
                        local prev: number? = nil
                        for _, onset in c.caws do
                            expect(onset >= 0).toBe(true)
                            expect(onset + BirdSpecies.CAW_GAPE_SECONDS <= secs).toBe(true)
                            if prev then
                                expect(onset > prev).toBe(true)
                                -- two gapes must not merge into one held croak
                                expect(onset - prev > BirdSpecies.CAW_GAPE_SECONDS).toBe(true)
                            end
                            prev = onset
                        end
                    end
                end
            end
        end
    end)

    test("a clip carries onsets or an envelope, never both", function()
        -- Both would be a bird described two ways, and nothing says which the controller should
        -- believe -- it checks `caws` first, so an envelope would silently never play.
        for name, _ in SPECIES do
            local voice = BirdSpecies.voiceOf(name)
            if voice then
                for _, c in voice.clips do
                    expect(c.caws ~= nil and c.env ~= nil).toBe(false)
                end
            end
        end
    end)

    test("an envelope has one sample per ENV_HZ of its own duration", function()
        -- ⚠ THE DEFECT THIS CATCHES IS AN EDITED `seconds`. The envelope is indexed by TIME, so a
        -- clip whose duration is changed without re-extracting slides the beak out of sync with
        -- its own audio -- silently, and worse the further into the clip you get.
        -- `tools/audio/measure_envelope.py --check` is the same check against the source WAVs.
        for name, _ in SPECIES do
            local voice = BirdSpecies.voiceOf(name)
            if voice then
                for _, c in voice.clips do
                    if c.env then
                        expect(type(c.seconds) == "number").toBe(true)
                        local want = (c.seconds :: number) * BirdSpecies.ENV_HZ
                        expect(math.abs(#(c.env :: { number }) - want) <= 1.5).toBe(true)
                        for _, v in c.env :: { number } do
                            expect(v >= 0 and v <= 1).toBe(true)
                        end
                    end
                end
            end
        end
    end)

    test("the sing lift is a real angle, split between neck and head", function()
        -- ⚠ THE LIFT IS WHAT SINGING LOOKS LIKE ON A BIRD TOO SMALL FOR A GAPE. A 20 degree jaw
        -- is 6.8 pixels on a karasu at ordinary distance and 2.6 on a mejiro, so the posture
        -- carries the read. It must not exceed the neck's own limit or the bird folds backwards.
        expect(BirdSpecies.SING_LIFT_DEG > 0).toBe(true)
        expect(BirdSpecies.SING_LIFT_DEG <= BirdFlight.HEAD_PITCH_MAX).toBe(true)
        -- strictly between 0 and 1: at either end the lift becomes a hinge at one joint
        expect(BirdSpecies.SING_NECK_FRAC > 0 and BirdSpecies.SING_NECK_FRAC < 1).toBe(true)
        -- ⚠ STILLNESS MUST NOT EXCEED 1, or `singLift` would drive the idle motion NEGATIVE and
        -- the bird would counter-wobble against its own look-around while singing.
        expect(BirdSpecies.SING_STILLNESS >= 0 and BirdSpecies.SING_STILLNESS <= 1).toBe(true)
    end)

    test("the gape constants are scale-free and sane", function()
        expect(BirdSpecies.ENV_HZ > 0).toBe(true)
        expect(BirdSpecies.CAW_GAPE_SECONDS > 0).toBe(true)
        expect(BirdSpecies.CAW_GAPE_DEGREES > 0).toBe(true)
        expect(BirdSpecies.CAW_GAPE_DEGREES < 90).toBe(true)
        -- the open window must fit inside the shortest gap the scheduler will ever leave
        expect(BirdSpecies.CAW_GAPE_SECONDS < BirdSpecies.CAW_GAP_RANGE[1]).toBe(true)
        expect(BirdSpecies.CAW_GAP_RANGE[1] < BirdSpecies.CAW_GAP_RANGE[2]).toBe(true)
    end)
end)
