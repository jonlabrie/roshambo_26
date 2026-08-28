--!strict
-- WHAT EACH BIRD IS: how big it is and what it sounds like. Pure -- ids and numbers only, no
-- Roblox types -- so Lune can test the rules that `BirdController` merely obeys.
--
-- ⚠ ONE RECORD PER SPECIES, NOT ONE TABLE PER PROPERTY. This file was `BirdVoice` and held only
-- clips; adding body length beside it as a second table would have been two lists to keep in
-- step, which is the defect class in `practice/duplicated-server-constants.md`. A species is a
-- thing, so it gets a record, and everything a bird needs to be itself hangs off that one entry.
-- This is also the table bird SELECTION will read from, so it is not throwaway.
local BirdSpecies = {}

export type Clip = { id: number, weight: number }
export type Voice = { clips: { Clip }, volume: number, rolloff: { number } }
export type Species = { bodyLength: number, voice: Voice }

-- ⚠ THE REFERENCE SPECIES, and it is load-bearing. Every motion constant in `BirdFlight` was
-- tuned by eye against this bird, so its scale must come out at exactly 1 and its behaviour must
-- stay bit-identical. Changing this name re-times the one bird the owner has actually watched.
BirdSpecies.REFERENCE = "Uguisu"

-- ⚠ BODY LENGTH IS NOSE-TO-TAIL IN STUDS, MEASURED FROM THE SHIPPED ASSET, not from Blender and
-- not from a design doc. Re-derive with `tools/studio/measureBirds.luau` in the Studio command
-- bar: it reads `Size.Z` off each MeshPart under `ReplicatedStorage.RoshamboBirds` and prints the
-- ratio. ⚠ Z, because the FBX axis conversion puts nose-to-tail on z -- reading `Size.X` gets you
-- the wingspan.
--
-- These two numbers are the only place proportion is written down, and everything downstream
-- divides rather than copies. `familiars.md` carried the uguisu at 0.552 for a week -- its size
-- in BLENDER -- because a figure had been transcribed instead of measured; if these ever
-- disagree with the tool's output, the tool is right.
--
-- ⚠ WEIGHTS EXIST BECAUSE THE KARASU'S CLIPS ARE NOT SUBSTITUTABLE. The uguisu's three are
-- three ways of saying one thing, so they are equal. The karasu's are ONE, TWO and THREE caws
-- (0.52s / 1.30s / 2.08s) -- a remark, a statement and a declaration. Uniform selection would
-- make the two-second declaration a third of every song, and a thing heard every third time is
-- not a declaration. Numbers to TUNE BY EAR in one play session, not to get right on paper.
BirdSpecies.SPECIES = {
    Uguisu = {
        -- ⚠ DELIBERATELY NOT LIFE-SIZE. A real uguisu is about half this; the owner upscaled it
        -- because at life size it was hard to see, and ruled 2026-08-28 to leave it that way.
        -- Do not "correct" it toward reality -- that decision has been made and may be revisited
        -- only by the owner.
        bodyLength = 0.828,
        voice = {
            -- Shared with the falls-dock bird's Call_1/2/3, deliberately: it is the same species
            -- and the same throat. See docs/wiki/world/falls-dock.md.
            clips = {
                { id = 74571915778017, weight = 1 },
                { id = 93957494294947, weight = 1 },
                { id = 133151225815336, weight = 1 },
            },
            volume = 0.85,
            rolloff = { 9, 34 },
        },
    },
    Karasu = {
        -- Life-size, owner ruling: 1.64 studs is about 19.7 inches nose to tail, which is a
        -- large-billed crow. Almost exactly twice the uguisu, which is why the two of them
        -- together are a real test of whether the motion scales at all.
        bodyLength = 1.640,
        voice = {
            clips = {
                { id = 136463941193848, weight = 45 }, -- karasu-1, one caw,    0.52s
                { id = 120005368709153, weight = 35 }, -- karasu-2, two caws,   1.30s
                { id = 125330698317872, weight = 20 }, -- karasu-3, three caws, 2.08s
            },
            -- ⚠ LOUDER THAN THE UGUISU FOR A MEASURED REASON, not because crows are loud. The
            -- karasu source clips peak at -7.4 to -9.9 dBFS against the uguisu's -5.4, so at
            -- equal Volume the crow would play QUIETER than the warbler, which is backwards.
            -- This offsets the recording, it does not editorialise about the bird. Check by ear.
            volume = 1.0,
            -- Same reach as the uguisu on purpose: the familiar sings ON YOUR SHOULDER, and the
            -- short rolloff is what keeps it a private event rather than canyon-wide ambience.
            rolloff = { 9, 34 },
        },
    },
} :: { [string]: Species }

-- ⚠ MEASURED FROM THE SOURCE RECORDING, kept so it is never re-derived by ear. In the original
-- phrase the gap between caw groups is 0.76s, and between caws inside a group 0.48-0.60s. The
-- clips carry their own padding (karasu-3 ends with 0.20s of room tone, karasu-2 opens with
-- 0.08s), so composing a 3+2 means delaying only 0.76 - 0.20 - 0.08 = 0.48s after the first
-- clip ends. Using 0.76 there would insert a second of dead air and read as a hesitation.
-- Verified offline: the composed phrase is sample-identical to the baked one apart from 0.48s
-- of room tone at -56 dBFS. Not wired yet; recorded for when it is.
BirdSpecies.GROUP_GAP_SECONDS = 0.48
BirdSpecies.CAW_GAP_RANGE = { 0.48, 0.60 }

-- The voice for `species`, or nil if it has none. See `pick` for why nil rather than a fallback.
function BirdSpecies.voiceOf(species: string): Voice?
    local rec = BirdSpecies.SPECIES[species]
    return if rec then rec.voice else nil
end

-- How this bird's proportions relate to the REFERENCE bird, as a plain multiplier: 1 for the
-- uguisu, ~2 for the karasu. `BirdFlight.profile` turns it into scaled distances and durations.
--
-- ⚠ RETURNS nil FOR AN UNKNOWN SPECIES RATHER THAN 1. Defaulting to the reference is precisely
-- the failure this whole scaling pass exists to prevent: a new bird would move on uguisu timings
-- and present as "the animation is wrong" instead of "the species is not registered", and the
-- first diagnosis costs a day while the second costs a line.
function BirdSpecies.scaleOf(species: string): number?
    local rec = BirdSpecies.SPECIES[species]
    if not rec then
        return nil
    end
    return rec.bodyLength / BirdSpecies.SPECIES[BirdSpecies.REFERENCE].bodyLength
end

-- Pick one clip id for `species`, weighted. `rand` returns a float in [0, 1).
-- ⚠ Returns nil for a species with no voice rather than borrowing another bird's. A fallback
-- would make a new familiar sound like a warbler, and the bug would present as "the crane sounds
-- wrong" instead of "the crane has no voice yet".
function BirdSpecies.pick(species: string, rand: () -> number): number?
    local voice = BirdSpecies.voiceOf(species)
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

return BirdSpecies
