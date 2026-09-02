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

-- ⚠ `caws` IS THE BEAK'S SCORE, and it exists because the clip is a fixed recording. karasu-1 is
-- one caw, karasu-2 is two, karasu-3 is three, so the bill has to open once per onset or it drifts
-- off its own voice. `seconds` is the clip's length, kept beside the onsets so a test can assert
-- the last caw actually fits inside the recording.
-- ⚠ MEASURED OFF THE SOURCE WAVs by `tools/audio/measure_caws.py`, re-derivable in one command.
-- They were MODELLED first -- inferred from clip durations and room-tone padding -- and every value
-- was wrong: karasu-2's second caw was typed at 0.62s against a measured 0.865s. A quarter of a
-- second late is plainly visible on a beak. The WAVs were on disk the whole time.
-- ⚠ OPTIONAL, because not every voice is made of discrete calls. A karasu's song IS its caws --
-- countable, separable, each one a beak movement. An uguisu's is a continuous warble with no
-- onsets to hit, so it carries neither field and its bill simply does not open. A species with no
-- onsets gets a shut beak, never an error.
-- ⚠ A CLIP CARRIES ONSETS OR AN ENVELOPE, NOT BOTH, AND THE CHOICE IS THE BIRD'S NOT OURS. A
-- punctuated caller (karasu: two or three caws separated by 0.775s of silence) is described
-- exactly by `caws`. A warbler (mejiro: 5.3s voiced 46% of its own length, unbroken) has no
-- honest onset to name, and is described by `env` -- its measured loudness at `ENV_HZ`.
-- A clip with neither leaves the beak SHUT, which is correct for a dove: they coo with the bill
-- closed, so silence there is authentic rather than missing data.
export type Clip = {
    id: number,
    weight: number,
    seconds: number?,
    caws: { number }?,
    env: { number }?,
}
export type Voice = { clips: { Clip }, volume: number, rolloff: { number } }
-- ⚠ THERE IS NO EYE RECORD HERE, AND THAT IS THE ANSWER RATHER THAN AN OMISSION. A karasu's eye
-- is TEXELS: the vendor's hand-painted art -- iris, pupil, catchlight, lid line -- graded to the
-- corvid palette, with a derived roughness map so it stays wet while the feathers stay matte.
-- Nothing about it is a runtime decision, so nothing about it belongs in a data module.
--
-- ⚠ TWO SEPARATE-PART EYES WERE SHIPPED AND BOTH WERE WITHDRAWN (2026-08-28/29): a `Part` ball
-- parked on `eye_R`/`eye_L` bones, then a `KarasuEyes` MeshPart CFramed off the head. The second
-- failed for a reason no care would have fixed -- a rigid eyeball cannot track a SMOOTH-SKINNED
-- socket, and at a 30 degree head yaw the rim lands 0.57 of an eyeball radius off a rigid follow.
--
-- ⚠ AND THE PREMISE UNDER BOTH WAS FALSE. "One MeshPart, one plain ColorMap, so no per-texel
-- roughness, so a painted eye cannot be wet" described the bird's SETUP, not the engine. A
-- SurfaceAppearance carrying a full PBR set gives per-texel roughness; a partial one is worse than
-- none (practice/material-and-mesh-traps.md §8), which is the only reason it costs anything.
-- The three "painted eyes do not read" failures were all our own procedural bakes; the vendor's
-- painted eye was never in that sample and was in the file the whole time.
-- ⚠ PLAIN DATA, NO ROBLOX TYPES. This module runs under Lune, where `Color3` and `Enum` do not
-- exist -- naming one makes the whole file fail to load and takes every test with it. Same rule
-- as `BirdFlight`, which returns {x, y, z} tables rather than Vector3. `colour` is an RGB triple
-- and `material` is the Enum.Material NAME; `BirdController` converts at the boundary.
-- ⚠ `seatNudge`: HOW FAR THIS BIRD'S RENDER SITS OFF ITS OWN PIVOT, in studs, measured by eye.
-- Seating the pivot on the perch is what BirdRig does and it is very nearly exact: 0.000 on the
-- karasu, 0.002 on the uguisu. This carries only that residual.
--
-- ⚠ IT ONCE CARRIED 0.0164 FOR THE MEJIRO, AND THAT WAS A HACK COVERING AN ASSET DEFECT. The
-- mejiro was the uguisu's MeshPart resized inside Studio, which scales the mesh and leaves the
-- pivot data behind, so it needed a correction no other bird did. It is now exported from Blender
-- at its own 0.640 -- same geometry, uniformly scaled, pivot scaled with it -- so it takes the
-- uguisu's number because it IS the uguisu. Two birds, one measured value, no special case.
--
-- ⚠ A NON-ZERO VALUE HERE IS A SMELL, NOT A SETTING. If a new bird needs one bigger than the
-- uguisu's hair, suspect how it reached Studio before reaching for this field.
export type Species = { bodyLength: number, voice: Voice, seatNudge: number? }

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
        seatNudge = -0.002, -- uguisu: pivot-seating reads a hair high; below the eye's reliable resolution
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
        seatNudge = 0.0, -- karasu: natively exported, pivot-seating is exact
        voice = {
            clips = {
                -- karasu-1, ONE caw
                { id = 136463941193848, weight = 45, seconds = 0.52, caws = { 0.090 } },
                -- karasu-2, TWO caws. ⚠ The gap is 0.775s, not the 0.48-0.60 CAW_GAP_RANGE claims
                -- for caws inside a group -- these two read as separate groups.
                { id = 120005368709153, weight = 35, seconds = 1.30, caws = { 0.090, 0.865 } },
                -- karasu-3, THREE caws. ⚠ There is a 25ms blip at 1.245s, 16% of peak, which a
                -- plain envelope threshold counts as a FOURTH caw and the beak then snaps at
                -- nothing. Real caws here run 0.18-0.24s; the measuring tool rejects events under
                -- 0.10s for exactly this.
                { id = 125330698317872, weight = 20, seconds = 2.08, caws = { 0.100, 0.920, 1.635 } },
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
    Mejiro = {
        -- ⚠ MEASURED FROM THE SHIPPED ASSET with tools/studio/measureBirds.luau, not computed.
        -- The mejiro SHARES the uguisu's mesh, scaled 0.7729 on BOTH halves -- scale one and they
        -- mate with an offset that reads as a rigging bug. A real mejiro is ~11.5cm against an
        -- uguisu's ~15cm, so the uguisu's own deliberate oversize rides along.
        bodyLength = 0.640,
        seatNudge = -0.002, -- mejiro: the uguisu's number, because it IS the uguisu at 0.773
        voice = {
            -- ⚠ AN ENVELOPE BIRD, NOT AN ONSET BIRD. Every clip carries `env` rather than `caws`,
            -- because a mejiro warbles rather than calls. See BirdFlight.gapeFromEnvelope.
            -- Extracted by tools/audio/measure_envelope.py; `--check` re-derives against the WAVs.
            -- ⚠ WEIGHTS FOLLOW THE KARASU'S RHETORIC rather than being uniform: a thing heard
            -- every fourth time is not a declaration. 40/30/20/10, remark to full warble.
            clips = {
                -- mejiro-1, the remark -- one motif
                {
                    id = 122425020063111,
                    weight = 40,
                    seconds = 0.462,
                    env = { 0.74, 0.43, 0.78, 0.47, 0.93, 1.00 },
                },
                -- mejiro-2, the statement -- the motif that follows it
                {
                    id = 101817561528218,
                    weight = 30,
                    seconds = 0.806,
                    env = { 0.93, 1.00, 0.23, 0.53, 0.51, 1.00, 0.80, 0.40, 0.59, 0.28 },
                },
                -- mejiro-3, the full opening song
                {
                    id = 95932702425982,
                    weight = 20,
                    seconds = 2.766,
                    env = {
                        0.02,
                        0.40,
                        1.00,
                        0.78,
                        1.00,
                        0.18,
                        0.41,
                        1.00,
                        0.99,
                        1.00,
                        0.95,
                        0.37,
                        0.83,
                        0.88,
                        1.00,
                        0.76,
                        0.36,
                        0.82,
                        0.46,
                        0.08,
                        0.04,
                        0.02,
                        0.03,
                        0.02,
                        0.03,
                        0.08,
                        0.05,
                        0.03,
                        0.02,
                        0.05,
                        0.03,
                        0.02,
                        0.02,
                        0.01,
                    },
                },
                -- mejiro-4, ⚠ THE FULL WARBLE, and the reason `env` exists at all: 5.3s voiced 46% of
                --   its own length, with no honest onset to name inside it. Capped at 5.3s by
                --   the 8s leak guard in `sing()` -- the source's two longer passages (7.75s,
                --   8.40s) would be truncated mid-song by a net meant for failed loads.
                {
                    id = 91147593932949,
                    weight = 10,
                    seconds = 5.3,
                    env = {
                        0.10,
                        0.38,
                        0.67,
                        0.52,
                        0.28,
                        0.77,
                        0.70,
                        0.65,
                        1.00,
                        0.44,
                        0.12,
                        0.45,
                        0.70,
                        0.54,
                        0.55,
                        0.34,
                        0.16,
                        0.17,
                        0.97,
                        0.73,
                        0.03,
                        0.07,
                        0.78,
                        1.00,
                        1.00,
                        1.00,
                        0.99,
                        1.00,
                        0.09,
                        0.79,
                        0.70,
                        0.32,
                        0.03,
                        0.34,
                        0.41,
                        0.47,
                        0.22,
                        0.27,
                        0.62,
                        0.30,
                        0.31,
                        0.13,
                        0.77,
                        1.00,
                        0.89,
                        1.00,
                        0.57,
                        0.07,
                        0.13,
                        0.19,
                        1.00,
                        1.00,
                        0.43,
                        0.49,
                        1.00,
                        0.73,
                        0.50,
                        0.55,
                        0.28,
                        0.53,
                        0.22,
                        0.39,
                        0.03,
                        0.02,
                    },
                },
            },
            -- ⚠ THE UGUISU'S VOLUME, NOT THE KARASU'S, AND FOR THE SAME MEASURED REASON. These
            -- clips peak -3.3 to -7.8 dBFS, mean about -5.5, against the uguisu's -5.4 and the
            -- karasu's -7.4 to -9.9. The crow needs 1.0 to keep up; this bird does not.
            volume = 0.85,
            -- On your shoulder, like the others: a private event, not canyon ambience.
            rolloff = { 9, 34 },
        },
    },
    Hiyodori = {
        -- Sized against the uguisu's deliberate oversize, same reasoning as the mejiro: a real
        -- hiyodori is ~27cm -- bigger than the uguisu -- so it rides the same scale, not reality.
        bodyLength = 1.150,
        seatNudge = -0.002, -- the uguisu's number: shares the warbler body plan and its pivot seat
        voice = {
            -- ⚠ AN ENVELOPE BIRD, like the mejiro, NOT an onset bird: its shriek strings run
            -- 3-5 notes a second, faster than a beak articulates discrete snaps (the karasu's
            -- caws sit 0.775s apart). Envelopes extracted by tools/audio/measure_envelope.py
            -- from the 2026-09-02 cuts (Roshambo Reference/sound/birds/hiyodori/cuts);
            -- `--check` re-derives against the WAVs.
            -- Weights follow the karasu's rhetoric: the single "piyo" is the everyday remark,
            -- the six-note shriek phrase the rare declaration.
            clips = {
                -- hiyodori-5, one sharp piyo
                {
                    id = 83972125364897,
                    weight = 35,
                    seconds = 0.61,
                    env = { 0.06, 0.00, 1.00, 1.00, 0.41, 0.00, 0.00, 0.00 },
                },
                -- hiyodori-2, three notes
                {
                    id = 75813303704290,
                    weight = 20,
                    seconds = 1.09,
                    env = {
                        0.02,
                        0.04,
                        0.51,
                        0.83,
                        1.00,
                        0.10,
                        0.32,
                        0.16,
                        0.29,
                        1.00,
                        1.00,
                        0.02,
                        0.00,
                        0.00,
                    },
                },
                -- hiyodori-3, three notes, different voicing
                {
                    id = 81032361933993,
                    weight = 20,
                    seconds = 1.13,
                    env = {
                        0.02,
                        0.02,
                        0.68,
                        1.00,
                        0.87,
                        0.31,
                        0.25,
                        0.48,
                        0.06,
                        0.99,
                        1.00,
                        0.19,
                        0.01,
                        0.00,
                    },
                },
                -- hiyodori-4, three notes from the second session
                {
                    id = 133499317149598,
                    weight = 15,
                    seconds = 1.03,
                    env = { 0.00, 0.00, 0.59, 0.32, 0.60, 0.98, 0.56, 0.68, 1.00, 1.00, 0.02, 0.00, 0.00 },
                },
                -- hiyodori-1, the six-note declaration
                {
                    id = 111925871408982,
                    weight = 10,
                    seconds = 1.59,
                    env = {
                        0.00,
                        0.45,
                        0.15,
                        0.40,
                        0.52,
                        0.20,
                        0.02,
                        0.38,
                        0.30,
                        0.72,
                        1.00,
                        1.00,
                        0.24,
                        0.53,
                        0.07,
                        1.00,
                        0.99,
                        0.02,
                        0.00,
                        0.00,
                    },
                },
            },
            -- The uguisu's volume, for the measured reason: these cuts peak -3.0 to -7.2 dBFS
            -- (one common gain across the set), mean about -5.3, beside the uguisu's -5.4.
            volume = 0.85,
            -- On your shoulder, like the others.
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
-- ⚠ THIS ONE SURVIVED THE RE-MEASUREMENT and is kept. Its derivation was 0.76 between groups minus
-- karasu-3's 0.20s tail minus karasu-2's 0.08s lead; measured, the gap is 0.775, the tail 0.205 and
-- the lead 0.090, giving 0.48. The arithmetic and the inputs both hold.
BirdSpecies.GROUP_GAP_SECONDS = 0.48
-- ⚠ CORRECTED 2026-08-30: this read { 0.48, 0.60 } and described no recording in the project.
-- Measured with `tools/audio/measure_caws.py` across all three shipped clips AND the original
-- `japanese_raven_corbeau.wav`, every onset-to-onset gap falls in 0.695-0.82, mean 0.75. The one
-- outlier is 1.005s in karasu-3-2, which is a phrase break rather than a gap inside a phrase.
-- ⚠ The old value carried the comment "MEASURED FROM THE SOURCE RECORDING, kept so it is never
-- re-derived by ear" -- an unmeasured number wearing a measured label, which is worse than an
-- admitted guess because it stops anyone checking.
BirdSpecies.CAW_GAP_RANGE = { 0.70, 0.82 }

-- How long the bill stays open for ONE caw. ⚠ MEASURED, not chosen: every caw in all three clips
-- runs 0.18-0.24s, and 0.23s is the value four of the six land on exactly. It must also stay well
-- under the smallest gap between onsets -- 0.715s, karasu-3's second to third -- or consecutive
-- caws would merge into one long croak instead of reading as separate calls. It does, easily.
BirdSpecies.CAW_GAPE_SECONDS = 0.23

-- ⚠ HOW FAR THE JAW SWINGS, IN DEGREES ON `bill_lower`'s LOCAL +X. Shared rather than per-species
-- for the same reason the duration above is: an angle is scale-free, so a bigger crow does not
-- open wider, it opens the same. Every other bird constant scales by sqrt(length) and this one
-- must not, or the karasu's jaw would swing twice the uguisu's for one call.
--
-- ⚠ THE AXIS AND THE SIGN WERE MEASURED IN STUDIO, NOT DERIVED -- and the sign is OPPOSITE to
-- Blender's, where the same motion is -25 degrees. A probe rigidly attached to the bone one jaw
-- length out along its local +Y (the jaw direction; local +Z points at the floor) drops 0.0641
-- studs and swings 0.0156 back toward the tail under `CFrame.Angles(rad(+20), 0, 0)`. Local Z is
-- lateral yaw and does nothing useful. Guessing this costs a session.
--
-- 20 degrees is the owner's starting value, to be judged in Play and adjusted by eye.
BirdSpecies.CAW_GAPE_DEGREES = 20

-- ⚠ THE STORAGE RATE FOR `Clip.env`, AND IT IS A STORAGE RATE, NOT A PLAYBACK ONE.
-- `BirdFlight.gapeFromEnvelope` interpolates between samples, so this only has to be above the
-- rate a jaw can move -- not above the rate a bird can sing. 12 Hz costs 106 numbers for the
-- mejiro's four clips together; doubling it would double that for a jaw that cannot use it.
-- ⚠ CHANGING THIS INVALIDATES EVERY SHIPPED `env`. Re-run `tools/audio/measure_envelope.py`
-- over the source WAVs; `--check` fails on drift rather than letting the beak slide.
BirdSpecies.ENV_HZ = 12

-- ⚠ WHAT SINGING LOOKS LIKE ON A BIRD TOO SMALL FOR A GAPE TO READ. A 20 degree jaw on the
-- karasu is 6.8 pixels at ordinary third-person distance and worth its bill split; on the mejiro
-- it is 2.6, and on the uguisu 3.4. What carries at that size is the POSTURE -- a small bird
-- throws its head back to sing -- so the envelope also lifts the head and neck, on every bird.
-- ⚠ IT ADDS TO THE GAPE RATHER THAN REPLACING IT. The karasu does both, which is what a cawing
-- crow does; the uguisu and mejiro have no `bill_lower` at all (their bill is one closed shell
-- with zero boundary edges -- it cannot open) and get only the lift.
-- ⚠ AND IT IS A ROTATION, NOT A SWELL. `Bone.Transform` DISCARDS SCALE -- measured, set 0.06 and
-- it reads back 1.0 -- so a throat cannot puff. Degrees are all we have.
BirdSpecies.SING_LIFT_DEG = 15 -- head + neck total, at full envelope (was 11)
BirdSpecies.SING_NECK_FRAC = 0.55 -- the neck takes this much of it, so the lift is not a hinge
-- ⚠ HOW MUCH OF THE IDLE LOOK-AROUND TO REMOVE WHILE SINGING. At 11 degrees added ON TOP of the
-- idle pose the lift read as a head wobble, because the bird kept glancing about mid-song and the
-- two motions were the same size. Stilling the idle is what turns it into a held posture; the
-- degrees alone could not, however far they were pushed.
-- ⚠ 0.90, NOT 0.75, AND THE REASON IS ARITHMETIC. `idlePose` yaws up to 62 degrees against a
-- pitch of 18, and the head bone takes 0.6 of the yaw -- so at 0.75 the head still received 9.3
-- degrees of side-to-side against 6.8 of lift, and the SIDEWAYS motion was the larger of the two.
-- The owner saw "a side to side head wobble" because that is literally what was biggest.
BirdSpecies.SING_STILLNESS = 0.90
-- Seconds to settle at the start of a song and to release at the end. Long enough not to snap,
-- short enough that the bird is already still by the first syllable.
BirdSpecies.SING_GATE_RAMP = 0.15

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

-- Studs to lift this bird above a pivot-seated placement. Zero for anything exported at its own
-- size; only a MeshPart resized in Studio needs one.
function BirdSpecies.seatNudgeOf(name: string): number
    local rec = BirdSpecies.SPECIES[name]
    return (rec and rec.seatNudge) or 0
end

-- Pick one clip id for `species`, weighted. `rand` returns a float in [0, 1).
-- ⚠ Returns nil for a species with no voice rather than borrowing another bird's. A fallback
-- would make a new familiar sound like a warbler, and the bug would present as "the crane sounds
-- wrong" instead of "the crane has no voice yet".
-- The clip record behind an id. ⚠ `pick` returns an ID because that is what a Sound needs, but the
-- BEAK needs the record's `caws`, so the two have to be reunited somewhere. Widening `pick` would
-- have changed every caller and its tests for one new need; this is additive and does not.
function BirdSpecies.clipById(species: string, id: number): Clip?
    local voice = BirdSpecies.voiceOf(species)
    if not voice then
        return nil
    end
    for _, c in voice.clips do
        if c.id == id then
            return c
        end
    end
    return nil
end

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
