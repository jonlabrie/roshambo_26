---
shelf: practice
updated: 2026-08-30
---

# Blender Working Rules

⚠ **HOW WE WORK IN BLENDER, not what breaks in it.** The traps — FBX lands at 100×, a partial PBR
set renders worse than none, a bone survives only if it deforms a vertex — live on
[[blender-pipeline]]. This page is the process, and it exists because that separation was missing:
500 lines of engine facts and nothing saying when to stop, what one step is, or who decides a step
is done. Every rule below was earned on 2026-08-29/30, in one session, on one bird.

Owner: *"blender is going to be a significant ongoing part of the Roshambo development pipeline.
It's as important as Studio, frankly, not an ad-hoc sort of thing."*

## 1. A step is ONE operation that changes what the bird looks like. Then stop.

Not "one feature". The eye was treated as a single attempt — seat it, loft a lid collar, build the
eyeball, weight it, export — five shape decisions the owner never saw, and the fifth was
unfixable. The loft went the same way: apply, join, re-run, hunt the next fault.

⚠ **THE SMALLEST EXECUTABLE UNIT IS NOT THE SMALLEST STEP.** `run()` rebuilds the bird from the
vendor blend, so "change one thing and look" costs a full pipeline pass — and the response was to
batch changes, which is backwards. **Step size was large because the tooling made small steps
expensive, and the tooling is ours.** See rule 6.

## 2. Defects are mine to judge. Shape is the owner's. Never infer one from the other.

A number can settle *is it broken*: watertight, weights summing to 1, no zero-area UVs, no face
owning vertices from both mandibles. No number settles *is it right*.

⚠ **THE FAILURE THIS NAMES:** faces bridging the mandibles went 13 → 11 and that read as progress.
It is not progress toward a bird anyone would accept; it is a number moving. Measurement pointed at
a question the owner asked is useful; measurement used to steer is blind, because the one thing
that cannot be measured here is the thing being made.

## 3. No Studio until there is something that can ONLY be seen, evaluated or approved there.

Owner's ruling, 2026-08-30. Four exports were made in one day and one import was useful. An export
exists to feed an import; an import exists to answer a question Blender cannot. Re-cutting a beak
is not such a question. ⚠ **The cost is not the export, it is pulling the owner into a round trip
they had already declined.**

What genuinely needs Studio: how a thing reads at arena distance on a phone, runtime material
response, anything driven by `BirdController`, and final approval.

## 4. Geometry commits need the owner's eyes first. Tool code does not.

⚠ **FOUR GREEN CHECKS PASSED ON A BIRD WHOSE FACE WAS TORN OPEN.** `af7a134` committed a bill with
142 boundary edges and a hole in the head; Luau tests, stylua, selene and the wiki lint all went
green, and **none of them look at geometry**. A test suite is not a substitute for looking, because
nothing in it can see.

## 5. An approach is abandoned when the OWNER says it is.

Owner's ruling, 2026-08-30, and it is a ruling because the alternative failed three times in one
session: the displaced bill, the modelled eye, and the lofted bill's assembly each ran a
patch-and-retry loop until the owner stopped it. ⚠ **There is no self-assessed criterion here.**
Do not invent one; report what is failing and let the owner call it.

## 6. Explore in the live scene. Codify into `run()` only after approval.

⚠ **A SCRIPT ENCODES A GENERAL RULE WHERE A MODELLER MAKES A SPECIFIC JUDGMENT.** "Displace vertices
above the gape plane, weighted by distance, by 0.060" is a law; "pull this loop up a bit, look, pull
it again" is a judgment. Sculpting is a sequence of judgments, and turning each into a parameterised
function — then defending the parameters in comments — makes guesses read like findings.

So: edit the live scene with `bmesh` in place, look, adjust, look. Codify the settled operation
afterwards. ⚠ This does NOT weaken [[blender-pipeline]]'s rule that the retarget must be a script —
it strengthens it, because what lands in `run()` is then the approved operation rather than the
search for it.

## 7. A number is MEASURED only if a committed script re-derives it. Anything else says so.

⚠ **`CAW_GAP_RANGE` CARRIED THE COMMENT "MEASURED FROM THE SOURCE RECORDING, kept so it is never
re-derived by ear" AND MATCHED NO RECORDING IN THE PROJECT.** Measured across all three shipped
clips and the original source, every gap falls in 0.695–0.82; the constant said 0.48–0.60. An
unmeasured number wearing a measured label is worse than an admitted guess, because the label is
precisely what stops the next person checking.

Same session, same defect twice: caw onsets were modelled from clip durations and shipped while
claiming the audio could not be read — the WAVs were on disk. `tools/audio/measure_caws.py` now
re-derives them in one command. This is schema rule 9 applied to Blender work: record how to
measure, not what was measured.

## 8. A script never overwrites what the owner authored.

`karasu_retarget.COLORMAP_AUTHORITY` names the hand-graded ColorMap and the bake **raises rather
than substituting** if it is missing. Generalise: owner-authored files are upstream of our tools,
and a tool that regenerates its own input will eventually destroy a Photoshop pass nobody can
reproduce.

## 9. Verify instrumentation is live before spending the owner's time on it.

Two play rounds were spent on diagnostics: the first was one-shot and fired mid-flight where the
condition it printed was legitimately false, proving nothing; the second never reached Studio at
all. ⚠ **One `script_grep` for the diagnostic's own text confirms it is running.** Do that before
asking anyone to play a round.
