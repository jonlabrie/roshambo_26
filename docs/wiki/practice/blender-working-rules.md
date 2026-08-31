---
shelf: practice
updated: 2026-08-31
---

# Blender Working Rules

⚠ **HOW WE WORK IN BLENDER, not what breaks in it.** The traps — FBX lands at 100×, a partial PBR
set renders worse than none, a bone survives only if it deforms a vertex — live on
[[blender-pipeline]]. This page is the process, and it exists because that separation was missing:
500 lines of engine facts and nothing saying when to stop, what one step is, or who decides a step
is done. Every rule below was earned on 2026-08-29/30, in one session, on one bird.

Owner: *"blender is going to be a significant ongoing part of the Roshambo development pipeline.
It's as important as Studio, frankly, not an ad-hoc sort of thing."*

⚠ **RULES 7 AND 8 ARE CHECKS, NOT SENTENCES, AND RULE 0 IS A HOOK.** Prose is the weakest mechanism
available: on 2026-08-30 [[owner-rulings]] was read, quoted back to the owner, and then broken for
the rest of the session. Where a rule can run, it runs — see each rule for its command. The rest
depend on the model actually stopping, and the owner should weight trust accordingly.

## 0. The rules are injected before the first Blender call of a session

`tools/hooks/blender_rules.sh`, wired as a `PreToolUse` hook on `mcp__blender__.*` in
`.claude/settings.json`. ⚠ **Asked when it would re-read this page, the honest answer was: never
spontaneously.** Pages are read when something prompts a lookup — a grep, a wikilink, an error —
and nothing signals "you are re-entering Blender". A long session also compacts, so text read early
degrades to a summary line saying it was read. The hook does not depend on remembering.
⚠ **Once per session, keyed on the session id**: twenty Blender calls each carrying nine rules is
noise, and noise is ignored.

**How the owner verifies it fired**, without trusting the model's own report:

```
cat .blender-rules.log        # gitignored; one line per Blender session
/hooks                        # confirms the hook is registered
```

The log records `RULES INJECTED before first Blender call` for each session served, and
`(already served this session)` for every later call. ⚠ **"Ask the model whether it saw the rules"
is exactly the report that should not be load-bearing here** — the log is a filesystem fact.
If a session does Blender work and the log gains no line, the hook is not running.

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
claiming the audio could not be read — the WAVs were on disk.

**The check:**

```
python3 roblox/tools/audio/measure_caws.py --check roblox/src/shared/BirdSpecies.luau \
  "~/Desktop/Roshambo Reference/sound/birds"
```

Re-derives every onset from the WAVs and exits non-zero on drift. ⚠ Verified by re-introducing the
original error — the modelled 0.62 against the measured 0.865 — which it reports as a 0.2450s drift.
Tolerance is 6 ms because onsets are read at a 5 ms envelope resolution; agreement finer than the
measurement window is not meaningful.

## 8. A script never overwrites what the owner authored.

**The check:** `karasu_retarget.OWNER_AUTHORED` is the registry and `assert_writable(path)` the
guard, called before every file write in the pipeline. It raises rather than overwriting, and the
message says the owner replaces such a file — or that removing it from the registry is a decision
and should look like one.

⚠ **A TOOL THAT REGENERATES ITS OWN INPUT EVENTUALLY DESTROYS WORK NOBODY CAN GET BACK**, silently,
on a run that was about something else entirely. A Photoshop curve is not re-derivable from the bake
it was applied to.

**Extended 2026-08-30 from a file to a whole asset.** The karasu's bill is now hand-finished in
`karasu_authored.blend` — a traced culmen fit, a lined mouth, and owner vertex edits at the tip.
The fit is reproducible; the hand edits are not. So the registry gained `karasu_authored.blend`,
and `run()` gained `assert_authored_bill_absent()` as its FIRST statement.

⚠ **THE BACKSTOP AT THE WRITE IS NOT ENOUGH ONCE A WHOLE ASSET IS AUTHORED.** `run()` rebuilds
from the vendor blend, so by the time `assert_writable` fires at the export the run has already
thrown away everything it was going to. The guard has to be a stop sign at the door, not a lock on
the till. Move `AUTHORED_BLEND` aside to rebuild the base bird — an action, not an accident.

**Where the guarded files live (2026-08-30).** `art/` at the repo root is the in-repo home for
hand-authored source; `art/README.md` carries the admission rule. CI enforces one half of it:
`art/` must contain no derived files.

⚠ **GUARD THE SOURCE, AND ONLY THE SOURCE.** `karasu_body.fbx` was briefly in `OWNER_AUTHORED` on
the day the registry grew, and that **single wrong entry generated every tangle that followed**: a
CI check that demanded the FBX be stored under `art/` while the rule above rejects `.fbx` there, an
`ART_SOURCES` split invented to paper over the contradiction, <!-- lint-ok: naming the retired split in order to bury it --> and a guard that refused the very
export the authored blend exists to produce. A derivative can always be re-exported, so guarding
one buys nothing and costs the legitimate path. The correct model is **one source of truth per
asset, changing hands exactly once**: `run()` owns a bird until a human makes an edit the script
cannot reproduce, and from that moment the `.blend` owns it. The one-way door is
`assert_authored_bill_absent()`; nothing else needs guarding.

⚠ **BLEND SAVES ARE MILESTONE-ONLY, AND THAT IS A SIZE CONSTRAINT, NOT ETIQUETTE.** Git cannot
diff a `.blend`; every save is a full copy kept forever, and Blender writes a `.blend1` backup
beside it on each save (gitignored — committing one doubles the cost for nothing).
`karasu_authored.blend` is 7.2 MB against a 57 MB repo history: one file, 13% of everything. Git
LFS was considered and deliberately declined — it adds a tool every contributor and CI job must
install plus a metered quota, and the repo had no churn to solve. `.git` outgrowing the working
tree is the evidence that would change that answer.

## 9. Verify instrumentation is live before spending the owner's time on it.

Two play rounds were spent on diagnostics: the first was one-shot and fired mid-flight where the
condition it printed was legitimately false, proving nothing; the second never reached Studio at all.

⚠ **This one stays prose, because there is nothing to assert** — it is a step to take, not a state
to check. The step: `script_grep` for the diagnostic's own literal text and confirm it appears under
`Players.<name>.PlayerScripts`, which proves Rojo synced it, BEFORE asking anyone to play a round.

## 10. Place the camera. Ask the owner to look. Do NOT look first.

Owner's ruling, 2026-08-30: *"you're pretty good at placing the camera, and pretty bad at deciding
what it is you're 'seeing'... place the camera and ask me to look, don't iterate. Checking images is
token-heavy, and while your vision skills are pretty impressive generally, they're not strong when
viewing 3D meshes and geometry."*

**The division of labour in Blender**: position the model, the pose and the camera at the angle that
shows the change — that part is reliable — then hand it over. The owner evaluates. If the owner
wants the model to see something, they frame it and ask for a capture, or send one.

⚠ **THE EVIDENCE IS A CASE OF READING PAST WHAT MATTERED, not of failing to render.** The beak was
posed open at 30°, rendered, examined, and reported as working. The owner looked at the same
geometry and immediately saw two defects in frame: the split sitting below the model's own mouth
line, and vertices connecting the upper and lower mandibles. Both were the defects that mattered.
Measurement afterwards confirmed both — 0.0107 studs low, 13 bridging faces — so the information was
recoverable by MEASURING and was not recoverable by LOOKING.

⚠ **AND A REJECTED HALF-MEASURE, recorded so it is not re-proposed.** The model offered to take one
capture purely to confirm framing — subject in frame, lit, file saved — on the grounds that two
captures that day had wasted the owner's attention on a macro shot and a black PNG. The owner ruled
against it: the line is cleaner without it, and "checking the framing" degrades into "having a look
and adjusting", which is self-approval by another name. **An occasional badly framed shot is cheaper
than that.**

**How to capture, when asked:**

```python
bpy.ops.render.opengl(write_still=True, view_context=True)   # what the viewport shows
bpy.ops.screen.screenshot(filepath=...)                      # the whole window, for panels/nodes
```

Both verified working 2026-08-30; `screen.screenshot_area` is not (writes 250 bytes). <!-- lint-ok: bpy operator names, third-party API — not repo symbols -->
⚠ `render.opengl` needs a `temp_override` carrying the VIEW_3D area and its WINDOW region. <!-- lint-ok: bpy operator name, third-party API — not a repo symbol -->

