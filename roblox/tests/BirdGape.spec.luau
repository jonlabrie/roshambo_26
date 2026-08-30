--!strict
-- ⚠ THE BEAK MUST OPEN ON THE CAW, NOT NEAR IT.
--
-- The gape shipped as `math.sin(now * 9) ^ 2` gated on the WIN state: a fixed 9 rad/s chatter with
-- no relationship to the audio. Two things were wrong with it. A bird that never sings -- and most
-- do not, since `sing()` is gated by MAX_CONCURRENT_SONGS and a chance roll so a crowd is not a
-- wall of noise -- still sat there mouthing. And a bird that DID caw opened on a rhythm unrelated
-- to the clip it was playing.
--
-- ⚠ THE CLIPS ARE FIXED RECORDINGS, and that is the constraint the whole design turns on. karasu-1
-- is one caw, karasu-2 is two, karasu-3 is three, at 0.52 / 1.30 / 2.08 seconds. Their internal
-- timing cannot be jittered -- the mouth would drift off the sound. Randomness has to come from
-- WHICH clip plays and WHEN, never from the envelope.
local harness = require("./harness")
local BirdFlight = require("../src/shared/BirdFlight")
local BirdSpecies = require("../src/shared/BirdSpecies")
local describe, test, expect = harness.describe, harness.test, harness.expect

local OPEN = BirdSpecies.CAW_GAPE_SECONDS

describe("BirdFlight.gapeAt", function()
    test("the beak is shut before the first caw and after the last", function()
        local caws = { 0.10, 0.64 }
        expect(BirdFlight.gapeAt(0.0, caws, OPEN)).toBe(0)
        expect(BirdFlight.gapeAt(0.09, caws, OPEN)).toBe(0)
        expect(BirdFlight.gapeAt(0.64 + OPEN + 0.01, caws, OPEN)).toBe(0)
        expect(BirdFlight.gapeAt(99, caws, OPEN)).toBe(0)
    end)

    describe("BirdController drives the gape from the clip", function()
        local fs = require("@lune/fs")
        local CONTROLLER = "src/client/BirdController.client.luau"

        test("the beak is not driven by a free-running oscillator", function()
            -- ⚠ THE EXACT SHAPE THAT SHIPPED: `math.sin(now * 9 + b.seed)`, gated on the WIN state.
            -- It looks like a bird chattering and is unrelated to any sound the bird is making.
            local src = harness.stripComments(fs.readFile(CONTROLLER))
            local gape = string.match(src, "if b%.billLower then.-\n            end")
            expect(gape ~= nil).toBe(true)
            gape = gape :: string
            expect(string.find(gape, "math.sin", 1, true)).toBe(nil)
            expect(string.find(gape, "BirdFlight.gapeAt", 1, true) ~= nil).toBe(true)
            -- ⚠ CLIP TIME, NOT WALL TIME -- the per-bird pitch jitter moves every onset by up to 3%.
            expect(string.find(gape, "cawSpeed", 1, true) ~= nil).toBe(true)
        end)

        test("singing arms the beak, and only singing", function()
            -- The onsets and the clip's pitch are known ONLY where the clip is chosen. If `sing` stops
            -- recording them the beak goes silent for good, with no error anywhere.
            local src = harness.stripComments(fs.readFile(CONTROLLER))
            local fn = string.match(src, "local function sing%(.-\nend")
            expect(fn ~= nil).toBe(true)
            for _, needed in { "cawFrom", "cawOnsets", "cawSpeed", "clipById" } do
                expect(string.find(fn :: string, needed, 1, true) ~= nil).toBe(true)
            end
        end)
    end)

    test("it reaches full gape once per caw", function()
        -- ⚠ COUNT THE PEAKS. A single wide bump covering both caws would satisfy "opens when the
        -- bird caws" and still look wrong -- the beak has to CLOSE between them or a two-caw clip
        -- reads as one long croak.
        local caws = { 0.10, 0.64, 1.18 }
        local peaks, was = 0, 0
        local rising = false
        for i = 0, 2000 do
            local g = BirdFlight.gapeAt(i / 1000, caws, OPEN)
            if g > was + 1e-9 then
                rising = true
            elseif rising and g < was - 1e-9 then
                peaks += 1
                rising = false
            end
            was = g
        end
        expect(peaks).toBe(3)
    end)

    test("it shuts fully between caws", function()
        -- karasu-2's gap is 0.54s against a 0.30s gape, so there is real silence between them.
        local caws = { 0.08, 0.62 }
        expect(BirdFlight.gapeAt(0.08 + OPEN + 0.005, caws, OPEN)).toBe(0)
    end)

    test("a caw opens FAST and closes slower", function()
        -- ⚠ NOT SYMMETRIC. A crow's bill snaps open on the attack and lingers; a symmetric bump
        -- reads as a yawn. Measured against the envelope's own peak rather than a magic number.
        local caws = { 0.0 }
        local quarter = BirdFlight.gapeAt(OPEN * 0.25, caws, OPEN)
        local threeq = BirdFlight.gapeAt(OPEN * 0.75, caws, OPEN)
        expect(quarter > threeq).toBe(true)
        expect(BirdFlight.gapeAt(OPEN * 0.3, caws, OPEN)).toBe(1)
    end)

    test("no caws means a shut beak, never an error", function()
        -- A species with no onsets recorded yet must not take the client down mid-round.
        expect(BirdFlight.gapeAt(0.5, {}, OPEN)).toBe(0)
    end)

    test("a clip can be recovered from the id `pick` returns", function()
        -- ⚠ `pick` HANDS BACK AN ID, not a record, and the caller needs the record: the id goes to
        -- the Sound and the onsets go to the beak. Widening `pick` would break its own tests and
        -- every existing caller for one new need, so the lookup is additive.
        local clips = (BirdSpecies.voiceOf("Karasu") :: any).clips
        for _, c in clips do
            local found = BirdSpecies.clipById("Karasu", c.id)
            expect(found ~= nil).toBe(true)
            expect((found :: any).id).toBe(c.id)
        end
        expect(BirdSpecies.clipById("Karasu", 1)).toBe(nil)
        expect(BirdSpecies.clipById("Crane", clips[1].id)).toBe(nil)
    end)

    test("every karasu clip carries onsets, one per caw it contains", function()
        -- ⚠ THE ONSETS AND THE CAW COUNT ARE THE SAME FACT. A clip whose comment says "two caws"
        -- and whose data says one onset would open the beak once over a two-caw recording, which
        -- is exactly the drift this exists to prevent.
        local clips = (BirdSpecies.voiceOf("Karasu") :: any).clips
        expect(#clips).toBe(3)
        for i, c in clips do
            expect(#c.caws).toBe(i) -- karasu-1 has one, karasu-2 two, karasu-3 three
            local prev = -1
            for _, onset in c.caws do
                expect(onset > prev).toBe(true) -- strictly increasing
                expect(onset + BirdSpecies.CAW_GAPE_SECONDS <= c.seconds).toBe(true)
                prev = onset
            end
        end
    end)
end)
