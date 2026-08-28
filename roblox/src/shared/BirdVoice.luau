--!strict
-- What each familiar SOUNDS like. Pure: ids and numbers only, no Roblox types, so Lune can
-- test the selection rule that `BirdController` merely obeys.
--
-- ⚠ THE VOICE IS PER SPECIES, NOT PER CLIP LIST. A crow is not a loud warbler — it is a
-- different instrument, and volume and rolloff belong to the bird as much as its calls do.
-- This table is also the seam bird SELECTION will read from, so it is not throwaway.
local BirdVoice = {}

export type Clip = { id: number, weight: number }
export type Voice = { clips: { Clip }, volume: number, rolloff: { number } }

-- ⚠ WEIGHTS EXIST BECAUSE THE KARASU'S CLIPS ARE NOT SUBSTITUTABLE. The uguisu's three are
-- three ways of saying one thing, so they are equal. The karasu's are ONE, TWO and THREE caws
-- (0.52s / 1.30s / 2.08s) -- a remark, a statement and a declaration. Uniform selection would
-- make the two-second declaration a third of every song, and a thing heard every third time is
-- not a declaration. Numbers to TUNE BY EAR in one play session, not to get right on paper.
BirdVoice.VOICE = {
    Uguisu = {
        -- Shared with the falls-dock bird's Call_1/2/3, deliberately: it is the same species and
        -- the same throat. See docs/wiki/world/falls-dock.md.
        clips = {
            { id = 74571915778017, weight = 1 },
            { id = 93957494294947, weight = 1 },
            { id = 133151225815336, weight = 1 },
        },
        volume = 0.85,
        rolloff = { 9, 34 },
    },
    Karasu = {
        clips = {
            { id = 136463941193848, weight = 45 }, -- karasu-1, one caw,    0.52s
            { id = 120005368709153, weight = 35 }, -- karasu-2, two caws,   1.30s
            { id = 125330698317872, weight = 20 }, -- karasu-3, three caws, 2.08s
        },
        -- ⚠ LOUDER THAN THE UGUISU FOR A MEASURED REASON, not because crows are loud. The
        -- karasu source clips peak at -7.4 to -9.9 dBFS against the uguisu's -5.4, so at equal
        -- Volume the crow would play QUIETER than the warbler, which is backwards. This offsets
        -- the recording, it does not editorialise about the bird. Check it by ear.
        volume = 1.0,
        -- Same reach as the uguisu on purpose: the familiar sings ON YOUR SHOULDER, and the
        -- short rolloff is what keeps it a private event rather than canyon-wide ambience.
        rolloff = { 9, 34 },
    },
} :: { [string]: Voice }

-- ⚠ MEASURED FROM THE SOURCE RECORDING, kept so it is never re-derived by ear. In the original
-- phrase the gap between caw groups is 0.76s, and between caws inside a group 0.48-0.60s. The
-- clips carry their own padding (karasu-3 ends with 0.20s of room tone, karasu-2 opens with
-- 0.08s), so composing a 3+2 means delaying only 0.76 - 0.20 - 0.08 = 0.48s after the first
-- clip ends. Using 0.76 there would insert a second of dead air and read as a hesitation.
-- Verified offline: the composed phrase is sample-identical to the baked one apart from 0.48s
-- of room tone at -56 dBFS. Not wired yet; recorded for when it is.
BirdVoice.GROUP_GAP_SECONDS = 0.48
BirdVoice.CAW_GAP_RANGE = { 0.48, 0.60 }

-- Pick one clip id for `species`, weighted. `rand` returns a float in [0, 1).
-- ⚠ Returns nil for a species with no voice rather than borrowing another bird's. A fallback
-- would make a new familiar sound like a warbler, and the bug would present as "the crane sounds
-- wrong" instead of "the crane has no voice yet".
function BirdVoice.pick(species: string, rand: () -> number): number?
    local voice = BirdVoice.VOICE[species]
    if not voice then
        return nil
    end
    local total = 0
    for _, c in voice.clips do
        total += c.weight
    end
    local r = rand() * total
    for _, c in voice.clips do
        r -= c.weight
        if r < 0 then
            return c.id
        end
    end
    -- Only reachable if rand() returns exactly 1.0, which the contract excludes; the last clip
    -- is the honest answer rather than nil, which the caller would read as "no voice".
    return voice.clips[#voice.clips].id
end

return BirdVoice
