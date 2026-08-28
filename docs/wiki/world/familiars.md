---
shelf: world
updated: 2026-08-28
---

# Familiars

The player's own bird — the bird that reads your round. The architecture shared with ambient
birds, and why both are client-rendered while only one is client-authoritative, is
[[ambient-birds]].

Every player has one small bird. It reacts to their result, wears their grade, and rests on the
world rather than orbiting their head. Built 2026-08-18 as the core of
[[friends-family-baseline]] item 6.

**This is an ACTIVATION of design approved 2026-07-04**, not a new idea. The metagame spec
specified familiars as *"the mobile status display complementing the teahouse's static one"*, with
these exact reactions and with plumage earned from milestone banks. It was parked on one blocker —
a dusk cycle — which shipped as [[day-night]]. Specs:
`docs/superpowers/specs/2026-08-18-familiars-and-grades-design.md` and
`2026-08-18-familiar-perches-design.md`.

## The four states, and only two have a behaviour

| state | the bird | why |
|---|---|---|
| **WIN** | spirals up, holds a high quick orbit | the only motion that rises |
| **LOSS** | nothing at all | ⚠ ruled out 2026-08-26 — see below |
| **SAFE** | nothing at all | safe means nothing changed, so the bird does not change |
| **RESTING** | perched on the world | no entry, or a result that has lapsed |

⚠ **VERTICAL DIRECTION CARRIES THE OUTCOME.** The space above a player's head is the only region
never occluded by another avatar, so height is what survives a crowd of fifty on a phone — colour
and detail do not. A test pins that the three differing holds are separable **by height alone**.

⚠ **THE LOSS ANIMATION IS RETIRED (2026-08-26).** Owner: *"no bird animation for a loss or tie."*
`stateAfter` resolves LOSS to RESTING immediately, so the bird never leaves its perch and a loss is
indistinguishable from a SAFE or from not having thrown.

**That last part was previously forbidden**, and the rule is worth stating as retired rather than
deleting: from 2026-08-18 the page read *"A LOSS MUST NOT COME HOME to the resting orbit — that
would make 'lost' and 'has not thrown' identical."* True, and now beside the point. The bolt-and-
sink was watched in play on 2026-08-25 and rejected — *"not in the same visual class as a bird
dancing on your shoulder"* — and the distinction was judged not worth an animation the next day.
⚠ Do NOT reinstate a low orbit to restore the distinction; that needs a new decision, not a
rediscovered constant. The old configuration (r 2.0, y 0.9, speed 0.55) is recorded in
`BirdFlight` as a comment for the same reason.

**Only a WIN moves the bird now.** The vertical grammar that opened this page — up means won, down
means lost — survives only in the reserved high orbit, which nothing uses.

**A result lapses after 15 seconds** (`BirdFlight.RESULT_HOLD`). Two corrections got here: the
first version played a 2–3s flourish, which the owner missed unless watching at the instant the
drum rested; the second held until the next round, which read as hovering. Every bird is also
reset to RESTING on `heroTileLand` at the start of each reveal, so "no entry" is a real state
rather than a stuck one.

⚠ **THE DRUM GATE IS UPSTREAM AND MUST NOT BE RE-APPLIED.** `TheaterController` holds the whole cue
schedule and builds it at flush time on `drumRest`, so a `consequence` cue is *already* past the
drum when it reaches the bus. The first version stashed cues waiting for a `drumRest` that had
therefore already fired, and the bird never reacted at all. The gate still matters — a bird is
visible across the arena, so an early celebration spoils the round for everyone watching that
player, not just its owner.

The cue carries `result` as of this work. It previously carried only `effect`, and `LOSS`'s pool
is empty, so a listener could not tell a loss from an unknown effect.

## Grades

⚠ **Where grade is DISPLAYED — and the three clocks it sits in — is [[status-display]].**
That page carries the aura, the rejected carriers, and why grade's reward is the unlock rather than
a badge. This section is the mechanism only.

**Grade is a count of milestones earned** (owner ruling). A rate is an *inference* and needs
sample — that is item 7's 360-throw floor — while a milestone is an *event*: exactly true when it
happens, unaffected by TEST_MODE, and impossible to lose by logging off. That last matters because
the program bar says *rounds skippable, no penalty*.

Fifteen grades, kyū counting down then dan counting up, stopping at 5th dan. Five **plumage
bands**, not fifteen: fifteen visually distinct birds is neither achievable nor legible across an
arena. Milestone families: pot depth and career banked are **powers**, which extends the ladder
indefinitely without hand-authoring a hundred achievements.

⚠ **NEVER BUILD A MILESTONE ON `totalPoints`** — it is a wallet, decremented by purchases, so the
milestone would be revoked by shopping. `bestPot` (`$max`) and `lifetimeBanked` are the safe bases.
A test pins this.

`presence.qualified` is awarded on the join call, not at settlement: it needs a 7-day throw count
and settling a round must not run a per-player aggregation for every participant.

## Perches

326 tagged `Attachment`s, name-encoded (`FamiliarPerch_rail` / `_post` / `_branch`). Search radius
20 studs from the **owner**; a new perch is picked at random from what is in range so a bird
sometimes returns to the one it just left; held 10–60s; a 70-stud leash stops an owner walking off
and stranding their familiar.

⚠ **THE 20-STUD RADIUS AND THE 70-STUD LEASH DO NOT SCALE WITH THE BIRD, deliberately.** They
describe how far a familiar will stray from its OWNER — territory, which is a fact about the
player, not about how long the bird is. A crow's perch search widening because a crow is longer
would be arithmetic standing in for a design decision. Motion scales; territory is chosen. See
the scale section below.

⚠ **THREE LIFETIMES, AND THE SWEEP OWNS ONE.** Getting this wrong works when tested and degrades
silently in play:

| category | examples | who emits |
|---|---|---|
| Rojo-owned | every roof, Overlook, SwitchbackDeck | the builder, via `Spec.perch` → `genmodels` |
| runtime-built | teahouse **engawa** railings | `PadOps.buildRailing`, on every pad claim |
| place-only | path railings, both bridges, hero trees, chōchin crosspoles | `tools/studio/sweepFamiliarPerches.luau` |

⚠ **MATCH RAIL NAMES BY PATTERN.** The canyon's 1,250 path railings are `Rail`; everything else
suffixes (`RailNUpperDeckCap1`, `RailCapN_1`). An exact-name sweep missed both bridges and both
hero decks, including the one the spawn sits on.

⚠ **NEVER CACHE A PERCH CFRAME.** `StreamingEnabled` is on and a distant railing can stream out
mid-flight, landing the bird on remembered air.

**Birds do not go indoors** (owner). This needs no indoor detection: there are no perches inside,
so a bird that has one keeps it and waits outside, and only a bird with none follows its owner in.

## The uguisu — a real bird, built 2026-08-19/20

The four-part greybox is superseded by a **skinned MeshPart**, verified in the place. It is the
first of a ROSTER (owner: uguisu first, karasu second), not the only bird.

⚠ **Sizes, bone counts and asset IDs are MEASURED, not recorded here** — run
`roblox/tools/studio/measureBirds.luau`. A transcribed size and a transcribed MeshId were both
wrong on this page for a week (see [log.md](../log.md), 2026-08-26).

**The one contract worth stating in prose:** origin is **feet at z = 0**, centred in x/y, and body
and wings must agree — that is what makes `perch.WorldPosition` the bird's position with no fudge.


Built by retargeting a purchased sparrow (TurboSquid "Rigged Low Poly Bird Collection" 1603819,
Standard License; source lives outside the repo). What was inherited: the standing posture, ten
correctly-weighted leg and toe bones, clean quad topology, and a non-overlapping unwrap — which
is most of what the model was actually worth. What was changed: tail +25%, head seated 0.024
down (crown rise above the back line 0.064 → 0.027), bill root narrowed to 37% of the sparrow's,
and the whole ColorMap repainted from photoreal sparrow to plain olive uguisu.

**The origin at the feet is load-bearing.** It makes `perch.WorldPosition` the bird's position
with no fudge, retiring the `+ Vector3.new(0, 0.2, 0)` the four-part bird needed.

⚠ **`BAND_COLOR` DOES NOT SURVIVE THIS.** <!-- lint-ok: naming a deleted constant --> The controller shows grade band by setting `p.Color`
on four parts; a textured MeshPart does not tint that way. Grade must become **ornament on
separate tinted pieces** — crest, tail streamer — rather than a recoloured bird, which is the
better answer anyway: it keeps an uguisu an uguisu at every grade instead of producing five
differently-painted birds.

### The bill opens, and the bird has TWO wings

The bill is **split into two mandibles** — bisected along the gape, both halves capped, watertight
(0 boundary edges, 0 non-manifold), +44 triangles. The cut stops short of the jaw so the halves
stay joined at the back: a real hinge, and no hole in the head. Gape at the tip measures
0.0099 / 0.0168 / 0.0224 studs at 12° / 22° / 32°.

⚠ **THE BIRD HAS TWO WINGS AND THEY NEVER COEXIST.** A **folded** wing is sculpted into the flank
and painted with its covert edge — that is the accurate one, and it is what shows for the ~90% of
the time the bird is perched. A **spread** wing lives in a SEPARATE MeshPart (`UguisuWings`,
824 tris, `wing_R`/`wing_L` + `wrist_R`/`wrist_L`) and exists only in flight. Because they are
never both visible, neither compromises for the other. The folded wing is not the compromise —
the spread one is the approximation.

⚠ **THE WINGS ARE A SEPARATE PART BECAUSE NOTHING ELSE CAN HIDE THEM.** Owner ruling
2026-08-22: they "should completely disappear when the bird is perched/at rest". Three approaches
were built and failed — bone scale (Roblox discards it), folding (93 of 208 verts stay outside the
body), and translating inside (a 0.22-long folded wing only fits a 0.22-wide body if perfectly
aligned). `Transparency = 1` is the only complete answer. All three failures are on
[[blender-pipeline]] so nobody rebuilds them.

Two bones per wing, hinged at 46% of span: **0.467 studs spread → 0.093 folded**, inside the
0.112 body half-width. Verified in Roblox, not only in Blender.

⚠ **THE SHIPPED UGUISU WING CANNOT BE REGENERATED FROM ANY SCRIPT, AND THE PAGE SAID NOTHING
ABOUT IT UNTIL 2026-08-27.** `roblox/tools/blender/spread_wing.py` is that wing's ORIGIN, not its
definition: measured off the committed mesh the wing holds a uniform ~23.9° angle of attack across
its span, where the script's formula yields about 8° at the root. It was reshaped after the script
ran, by a step nobody wrote down. The 2026-08-26 tip fix therefore had to be applied to the MESH,
in `uguisu_retarget.blend`.
**Do not assume re-running `build()` reproduces what is in the game.** The warning has lived in
that file's header since the day it was found — where only somebody already editing the script
would meet it, which is the wrong audience for a fact about the shipped asset. This is the same
failure shape as the recorded 0.552 size, one layer up: the artifact and its record disagree, and
nothing was positioned to notice. The karasu does not share it — `karasu_retarget.py` runs end to
end ([[blender-pipeline]]).

**Amended 2026-08-25:** "completely disappear" now means *at rest*, not *while perched*. A perched
bird flutters (below), and a flutter is a half-unfold — so the wings are visible for half a second
at a time on a perch. Transparency still returns to 1 the instant the burst ends. The owner made
this amendment themselves when asking for the flutter; it is not drift.

⚠ **THE FOLD SWEEPS HORIZONTALLY, AND ITS SIGN WAS WRONG FOR THREE DAYS.** `wing_*`/`wrist_*` turn
about a local Z that runs **vertical**, so folding is a fore-and-aft sweep, not an up-and-down
flap. At the shipped `-70/-110` it swept the wrong way. Measured on the live bird, wingtip in
part-local space where `-Z` is forward:

| pose | tip z |
|---|---|
| spread (rest) | −0.123 |
| fold as shipped (−70/−110) | **−0.391** — a quarter-stud past the head |
| fold corrected (+70/+110) | **+0.146** — back over the body |

⚠ **AND NOTHING COULD HAVE SHOWN IT, which is the transferable part.** The only two poses anyone
had ever seen are exactly the two where the sign cannot matter: fully spread is 0° either way, and
fully folded is `Transparency = 1`. Takeoff crosses the wrong region in 0.28s while the bird is
also translating away. A bug can live indefinitely in the states you never hold still and look at
— the flutter was the first thing to hold a partial fold in view, and it exposed it on the first
gate. Tests now state the fold as a **direction** rather than repeating two magic numbers.

### The beat, the arc and the gear — all measured, gated 2026-08-25

⚠ **THE BEAT HAD NO VERTICAL COMPONENT AT ALL.** It spent its whole amplitude on the same local Z
the fold uses, which is horizontal — so the bird sculled rather than flew, and the wing visibly
SHORTENED each stroke, because rotating in the horizontal plane foreshortens the span (tip x 0.431
→ 0.335 at 40°). Measured per axis, wingtip travel over ±60°:

| bone axis | vertical | fore-aft | |
|---|---|---|---|
| local X | **0.712** | 0.000 | the lift axis, unused until now |
| local Y | 0.000 | 0.000 | runs along the span; moves the tip not at all |
| local Z | 0.000 | **0.712** | what the beat was using for everything |

**The fore-aft sweep is not a bug — it is half of a real beat.** Owner: *"in actual flight it's
both."* Correct, and the pairing runs the other way: the DOWNSTROKE is the power stroke and sweeps
forward as it descends, the upstroke recovering back and up. So the fix was to ADD the missing axis
**90° out of phase** — sin for the stroke, cos for the sweep — making the tip trace an inclined
ellipse. In phase they would draw a straight diagonal and retrace it: a line, not a loop, and worse
than the single axis it replaced. Vertical 45°, fore-aft 13°, so the sweep TILTS the loop rather
than carrying it.

⚠ **MIRRORING DIFFERS PER AXIS.** local X does NOT mirror — the same sign raises both wings; local
Z does. Guessing would have had one wing rise while the other fell.

⚠ **THE ARC MUST KEY OFF DISTANCE COVERED, NOT TIME ELAPSED.** `along` is the integral of a speed
profile and is near zero at the start, because the bird launches from rest on a perch — while
`rise` was a function of raw `t` and climbed immediately. At 10% of a 30-stud flight that is 0.76
studs forward against 1.64 up: the bird went up like a rocket and then turned toward the target
(owner). Rise and CIRCLE's side-swing now key off `along`, so the climb is proportional to
progress. Endpoints and peak heights are unchanged; only the schedule moves.

⚠ **GEAR UP.** Fixed legs read as *"a plane flying with the wheels down"*. Measured: **`BirdFlight.LEG_TUCK_DEG` at the
hip** (100° today) lifts the foot 0.280 studs, from y −0.281 to −0.001, and puts EVERY joint of the leg chain
inside the body's bounding box (protrusion 0.000) — so the hip alone folds the leg into the flank
and no knee bone is needed. At rest the foot protrudes 0.045 below, which is correct: feet should
show on a perch. Up by 22% of the flight, down from 78%, so it extends BEFORE touchdown.

**Owner gate 2026-08-25: "bird is looking good, let's roll with those settings."**

### Flight, and the idle that matters more

⚠ **A FLIGHT IS A SHAPED PATH OVER A MINIMUM DURATION**, not a lerp. The original
`Lerp(target, speedCappedStep)` at 34 studs/sec caused three separate symptoms from one line: no
ramp, a **slide** along rails (a short hop finished inside two frames, so the branch that turns
the bird never ran long enough to see), and invisible wings (0.6s crossings against a 0.28s
unfold). Now: `FLIGHT_MIN_TIME` 0.85s, `CRUISE_SPEED` **11** — a real songbird's ~33 is 40
body-lengths/sec at this size and reads as teleporting, so believable speed is the wrong target.
Three phases, with `along` computed as the **integral of a speed profile** tied to the phase
boundaries so position and phase cannot disagree. Three path shapes: DIRECT, ARC, CIRCLE (the
owner's "half circle around the perch while spotting the landing zone").

⚠ **PERCHED IS ~90% OF VIEWING TIME AND IT WAS INERT.** The idle is the cheapest sign of life in
the whole familiar. There are now **three perch motions**, and they are mutually exclusive — two at
once read as one confused compound move rather than two habits.

| motion | what it is | when |
|---|---|---|
| **look around** | head snaps and holds; 42% of moves are **checks** (go look, come straight back) | continuous |
| **flutter** | three half-unfolds in 0.5s | on landing, on a win, else every ~22s |
| **turn** | a 0.25s hop that lands facing 35–110° off, either way | every ~18s, real perches only |

**The head snaps and holds** — a smooth pan reads as a security camera — and the checks are what
stop the bird reading as slowly rotating over time. Plus a tail flick on its own clock.

⚠ **THE FLUTTER IS A FOLD, NOT A LIFT — and for its first three days it was neither.** It lived in
`wingAngle` (the lift channel) while `wingExtension` returns 0 whenever the bird is not flying and
Transparency follows openness: the wings were invisible for every burst and the lift rotated
something nobody could see. Two channels fighting, one hiding the wing and the other animating it.
Moving it onto the fold channel — the owner's "half unfold/refold" — makes the wing appear *because*
it is unfolding.

⚠ **0.5s IS A FLOOR, AND IT IS SET BY PHONES.** A flex is an up AND a down, so it needs frames to
resolve as motion rather than strobe. At 0.5s each of the three flexes gets five frames on a 30fps
phone; below that the peaks fall between samples and the flexes come out visibly uneven. Past this
point the only honest way to go quicker is FEWER flexes, not a shorter burst. Pinned by a test, so
the next person to reach for "quicker" is told rather than discovering it on a device.

⚠ **WING TRANSPARENCY IS A FADE, NOT A FLIP.** At the best fold 93 of 208 verts sit outside the
body, so the wings are hidden by Transparency rather than by being tucked — flipping at `open > 0`
pops a fully-formed tucked wing into existence in one frame. Invisible mid-takeoff where motion
covers it; glaring on a stationary bird. It fades over `open ∈ [0, 0.15]`, which takeoff crosses in
~40ms, and landing still snaps shut because openness drops to 0 in a single step.

⚠ **THE TURN MUST BE DRIVEN FROM ABSOLUTE ANGLES.** The perched branch derives its heading by
reading the bird's own `LookVector` back each frame, so a turn applied as a per-frame offset feeds
its own output back in and compounds into a **spin**. `turnFrom`/`turnTo` are captured once when
the turn fires. The two idle gaps (~18s turn, ~22s flutter) are deliberately not multiples, so the
habits drift instead of firing together; a test pins that they never coincide.

The victory hop is a **weight shift**, not a slide: the bird stays put, the feet alternate on the
two independent leg chains the vendor rig provided, and the body rolls toward whichever foot is
planted. A bird never lifts both feet while perched, and a test pins it.

⚠ **THE SHOULDER SEAT IS MEASURED OFF THE AVATAR, NOT A CONSTANT.** `RightUpperArm`'s top sits at
y +0.847, x +1.117 from the HumanoidRootPart on a stock R15 (arm 0.943 × 1.213 × 0.759) — and R6,
R15 and scaled bodies all differ, so no constant could be right.

**Gated 2026-08-26**, after three corrections, and every number is a PROPORTION of the arm so a
scaled avatar gets the same result:

| | | why |
|---|---|---|
| `SEAT_INBOARD` | 0.42 of arm width | the middle of the shoulder; `arm.Position` is the arm's CENTRE, and 0.18 left the bird out over the arm |
| `SEAT_LIFT` | 0.031 of arm height | ⚠ a part's top FACE is not the visible shoulder — the mesh and any layered clothing sit proud of it, so at 0 the feet sank in. 0.45 inches on a stock R15 |
| `SHOULDER_YAW` | 0 | faces forward with the avatar |

⚠ **AND A BIGGER BIRD IS GIVEN BACK THE WIDTH IT GAINED** (`BirdFlight.seatRelief`, 2026-08-28).
The three proportions above place the bird's **feet**, and a bird is centred on its feet — so a
wider bird reaches half a width further inboard from an identical footprint and crowds the neck.
Owner, watching the karasu on a shoulder: *"a little tight to the head."* Holding the bird's INNER
EDGE where the reference bird's sat is the whole correction and needs no tuning constant: it is
the difference of two half-widths, **exactly zero for the reference bird** whose seat was gated.

⚠ **BOTH WIDTHS ARE MEASURED; NEITHER IS INFERRED FROM LENGTH.** The first version took the
reference width as `width / scale`, assuming a bigger bird is a scaled one. It is not — see the
measured proportions below — and the assumption over-relieved by about a third of an inch. Both
templates sit in `RoshamboBirds` at once, so there is nothing to infer.

⚠ **THE VICTORY SONG FIRES ON THE LANDING, AND NO TIMER CAN REPLACE THAT.** Three attempts said
otherwise: a random 0–2.2s, then `ENTRY.WIN` + stagger, then this. Both timers sang before the bird
arrived, and the reason is structural — the bird FLIES in, and `flightDuration` is 0.85s plus
distance over cruise speed, so twenty studs needs 2.65s and across the canyon needs far more. **Any
constant is wrong for every distance but one.** The cue arms the song; the update loop fires it at
the instant the dance begins, where "has it landed" is true rather than estimated.

## The karasu — the second bird, built 2026-08-26

Owner ruling 2026-08-19 was *"uguisu first, karasu second"*, and 2026-08-25 made the roster
**unlocks** rather than a grade ladder — so this is the first bird a player can earn the right to
choose. It is not wired into play; it is built, verified and waiting on import.

⚠ **Measured, not transcribed** — `roblox/tools/studio/measureBirds.luau`, same as the uguisu
above. Rebuilt end to end by `roblox/tools/blender/karasu_retarget.py` (`run()`, `verify_rig()`,
`bake_and_finish()`); source FBXs and the ColorMap live in
`~/Desktop/Roshambo Reference/models/birds/probe/`.

⚠ **Triangle counts are the exception** and have to be recorded, because Roblox exposes no face
count for a MeshPart at runtime: body 2,666, spread wings 1,304. `karasu_retarget.run()` reports
both, and is the only place they can be re-derived.


⚠ **LIFE SIZE, AND THAT IS ABOUT TWICE THE UGUISU.** Owner-chosen 2026-08-26: a hashibutogarasu
(~50cm). `measureBirds` prints the exact ratio; it was first written here as "three times", from
the uguisu's designed size rather than its shipped one. It follows two standing rulings
rather than inventing one — *"life size, maybe slightly larger"* (2026-08-19) and *"a presumably
larger bird, like a raven/crow to carry it"* (2026-08-22).

**The motion consequence is handled** — see the scale section below. `SEAT_INBOARD` / `SEAT_LIFT`
remain proportions of the AVATAR's arm and are correctly untouched by bird size, with a separate
width relief for the body; see the seat table above.

⚠ **THE WINGSPAN IS THE DIAL MOST LIKELY TO WANT THE OWNER'S EYE.** It ships at **1.49× body
length**. A live crow is 2.0× (50cm long, ~100cm span) and the shipped uguisu is 1.13× — so the
uguisu too came in well under life proportion and was gated as good. 1.49 is deliberately between
them. `KARASU["wing_spread"]["span"]` is the number.

### What the purchase actually bought — and what it did not

Retargeted from the same TurboSquid collection as the uguisu. ⚠ **The reason it was cheap is not
the reason anyone expected.** The crow does ship the wing bones the sparrow lacked
(`Shoulder → Arm → ForeArm` per side) — but that was never the blocker: the uguisu builds
`wing_*`/`wrist_*` from scratch on its own spread-wing part, and what makes those bones work is
not that they exist but their AXES. They are **deleted and rebuilt** here.

What it did buy, measured rather than assumed:

- **A clean body unwrap** — 108,504 texels at 512², **23 overlapping (0.0%) and zero mirrored**.
  That is what makes `bake_bird_texture`'s shade-as-a-function-of-position legal on the mesh at
  all, and it is most of what a bought model is worth.
- **A real crow head and bill**, which is the half of the silhouette a sparrow cannot become.

What had to be built anyway: the folded wing (the crow ships wings SPREAD and welded into the
body), the tail (48 triangles of alpha card, and we ship a plain ColorMap so an alpha card is an
opaque rectangle), the jaw (no `bill_lower`, one closed shell), and the whole rig's naming.

⚠ **THE CROW'S OWN TAIL BONE IS NAMED `joint1`, AND SO IS THE ROOT'S TARGET NAME.** A one-pass
rename makes Blender silently produce `joint1.001`, and the root `BirdController` looks up is then
the tail. Renamed through a temporary namespace.

⚠ **THE LEG SIDES WERE INVERTED IN THE FIRST DRAFT OF THE MAP.** Measured off the shipped uguisu:
in armature-local space (bird facing +Y) `joint12` sits at x −0.038 and `joint25` at x +0.088, and
the bird's right when facing +Y is +X — so **joint25 is the right leg**. Getting it backwards is
invisible at rest and shows only in the victory hop, where the body rolls toward the planted foot.

### Verified by driving the rig, not by looking

`verify_rig()` rotates each driven bone and measures what moved. On-chain displacement against
off-chain, in studs:

| bone | on chain | off chain |
|---|---|---|
| `joint4` head | 0.1167 | **0.0000** tail |
| `joint8` tail | 0.2865 | **0.0000** head |
| `joint3` neck | 0.1299 | **0.0000** tail |
| `bill_lower` | 0.0249 | **0.0000** rest of bird |
| `wing_R` | 0.8011 | **0.0000** left wing |
| `wrist_R` | 0.5277 outboard | **0.0000** inboard of the hinge |

⚠ **AND THE WING AXES MATCH THE UGUISU'S MEASURED TABLE**, which is the check that actually
matters: `BirdController`'s beat and fold are written against two measured facts that only hold if
the bone roll is right. Rotating 40° about local **X** lifts the right tip +0.7413 and the left
tip +0.7413 — *the same sign raises both, local X does not mirror*. About local **Z** it sweeps
them +0.7984 and −0.7060 — *opposite, local Z does mirror*. Local X moves the tip only vertically
and local Z only fore-and-aft, exactly as measured on the uguisu.

### Importing a bird — the checklist

⚠ **This was written as a hand-off to the main thread; that thread split is retired
([[parallel-threads]]) and the karasu is imported.** Kept as the checklist for the NEXT bird,
with the reasoning left on the pages that own it rather than restated here — a third copy of a
trap is a third thing to correct when the trap is corrected.

1. Import body and wings. **Do not rescale** if the source is authored 1:1 (the karasu is; the
   uguisu was built at one size and scaled in Studio).
2. **Delete any `SurfaceAppearance` the importer creates; use `TextureID`** —
   [[material-and-mesh-traps]] §8 (ColorMap-only renders warm and shiny).
3. **Set `part.CFrame` directly, never `PivotTo`** — [[blender-pipeline]] (the importer bakes a
   rotation into the CFrame with a compensating `PivotOffset`).
4. **Anchored: TRUE** — it is an importer dialog setting; an unanchored probe falls out of the
   world on the first Play.
5. **Vertex colours: OFF** — [[blender-pipeline]] (a baked-AO `colorSet0` layer is MULTIPLIED in).
6. Confirm `HasSkinnedMesh`, then bone-drive test before gating — ⚠ **measure a DESCENDANT of the
   driven bone, never the driven bone itself**, which cannot move under its own rotation and reads
   a meaningless zero.

Run `roblox/tools/studio/measureBirds.luau` for the roster's actual sizes, bone counts and asset
ids rather than reading them here.

## The species record — `roblox/src/shared/BirdSpecies.luau`

⚠ **ONE RECORD PER BIRD, carrying voice AND measured `bodyLength`.** This file was `BirdVoice`
and held only clips; body length arrived beside it on 2026-08-28 and went INTO the same record
rather than into a second table, because two parallel lists keyed by species name is
[[duplicated-server-constants]] with a different subject. `BirdSpecies.REFERENCE` names the bird
every motion constant was tuned against, and `scaleOf` divides by it.

⚠ **A crow is not a loud warbler.** Clips, volume and rolloff are all per species now; the
uguisu's values moved unchanged, with the reasoning that earned them. Read the module for the
asset ids rather than trusting a list here.

**The karasu's three clips are NOT substitutable**, which is why the pick is weighted. They are
one, two and three caws — a remark, a statement and a declaration. Uniform selection would make
the declaration a third of every song, and a thing heard every third time is not a declaration.
⚠ **The weights are unturned by ear** — set from reasoning, to be fixed in one play session.

**Cut from a source recording** at `~/Desktop/Roshambo Reference/sound/birds/Large-billed
Crow.mp3` (place-only; not in git). ⚠ **All three come from the FIRST phrase**, measured: the
second phrase's background sits 9.3 dB noisier (−37.7 dB against −47.0), which the owner heard
before it was measured. The measured group gaps live in the module as constants so nobody
re-derives them by ear.

⚠ **The karasu plays at volume 1.0 against the uguisu's 0.85 for a MEASURED reason, not because
crows are loud**: its source clips peak 2–4.5 dB quieter, so equal Volume would make the crow
quieter than the warbler. It offsets the recording; it does not editorialise about the bird.

⚠ **Composing is possible and deliberately not wired.** A 3+2 phrase built from the three-caw
and two-caw clips is sample-identical to a baked recording apart from 0.48s of room tone at
−56 dBFS — verified by diffing, not by ear. `GROUP_GAP_SECONDS` is the delay it needs, and it is
NOT the 0.76s gap you would measure off the source: the clips carry their own padding.

⚠ **AND NONE OF THE KARASU IS REACHABLE, but the gap is now one line.** `BirdController`
hardcodes `SPECIES = "Uguisu"` because nothing selects a bird per player. As of 2026-08-28 that
ONE name drives the mesh (`{SPECIES}Body` / `{SPECIES}Wings`, both already declared in
`default.project.json`), the voice and the motion scale — so flipping it changes the whole bird
rather than half of it. A test pins that the three cannot drift apart, because a bird wearing a
crow's body with a warbler's song is the failure that has nothing positioned to notice it.

⚠ **The familiar sings ONLY on a win, and that is a RULING, not an implementation detail.** It
protects the falls-dock uguisu's gate — *"this bird lives here and you have to be close to hear
it"* ([[falls-dock]]). Owner 2026-08-27: birds will eventually be found around the world,
flying and perching and calling occasionally, which **reverses that premise**. Design that
before building it.

⚠ **AND MUCH OF THE MACHINERY ALREADY EXISTS — a claim written here on 2026-08-27 that "there is
no world population, no perching" was WRONG and is deleted.** It came from grepping for
"ambient" and from a stale comment in `BirdFlight` calling the resting orbit a placeholder. The
familiar perches on tagged `FamiliarPerch` attachments swept across railings, hero trees, chōchin
poles and the descent stair; the orbit is only the fallback for when none is in range. Count them
with `CollectionService:GetTagged("FamiliarPerch")` rather than trusting a number here.

**What genuinely does not exist** is an OWNERLESS bird: `pickPerch` already takes a position
rather than an owner, so the seam is narrow, but nothing spawns a bird with no player attached,
nothing schedules its calls (the dock uguisu's bout pattern on [[falls-dock]] is the proven
design), and nothing decides how many there are or stops one being mistaken for your familiar.

## ⚠ THE KARASU'S EYE IS PAINTED, AND FOR TWO DAYS IT PAINTED NOTHING

Owner, 2026-08-28, in play: *"nothing reads as an eye on the existing model."* The karasu's eye
lives in the ColorMap — unlike the uguisu, which carries eye GEOMETRY from `bird_familiar._eyes`.
⚠ **An untextured solid-shaded render of this bird therefore has no eyes at all**, which is worth
knowing before it costs a look.

⚠ **THE FIRST DIAGNOSIS WAS WRONG AND IS RECORDED SO IT IS NOT REACHED FOR AGAIN.** A session
explained the miss as "a crow's eye is as dark as its head, so it cannot read" — an
oversimplification the owner rejected with a reference photograph. Two measurements settled it:

- **The eye has 31 texels across** at the shipped 1024 atlas, computed from the UV area of the
  faces around it. **Resolution was never the limit.** A flat near-black disc with a dot on it
  spends all 31 of them saying nothing.
- **Sampled off `birds/Jungle_crow_Close-up.jpg`**, as luminance ratios against the plain head
  feather beside the eye — so they survive the palette's ~35% legibility lift:

| | vs the feathers |
|---|---|
| highlight (sky reflection) | **3.08×** |
| ear-covert stipple | **1.37×** |
| lid rim | 0.72× / 0.50× |
| iris | **0.66×** |
| pupil | 0.14× |

⚠ **THE IRIS IS DARKER THAN THE FEATHERS, NOT LIGHTER.** Every part of the eye except the glint
is darker than the head around it. What makes a crow's eye read is **contrast with its own
surround** — a dark socket holding one big glint, framed by paler feathering — not a pale iris.

⚠ **And the catchlight's BRIGHTNESS was right all along, at 3.4× the crown against a measured
3.08. Its SIZE was the bug**: 38% of the eye's radius, so ~15% of its area, where the real
reflection covers about a third of the eyeball as a broad cap. That is why "add a catchlight"
looked done and was not — the failing dimension was not the one anyone had checked. The glint is
now an ellipse, wider in y than z because a reflection on a sphere lies along the horizon.

**Five layers now**, painted outward-in, and the frame matters as much as the eye: pale ear-covert
patch, dark socket rim, iris, pupil, glint. The periocular frame was **missing entirely** rather
than mis-tuned, and on a bird with no other head markings it is what says "there is a face here".

**Modelling it remains the fallback**, not the plan: with 31 texels available the miss was a paint
bug, and geometry would additionally buy a view-dependent engine specular if paint proves not to
be enough in play.

## Motion scales with the bird — built 2026-08-28

⚠ **EVERY MOTION CONSTANT IN `BirdFlight` WAS TUNED AGAINST THE UGUISU**, and the karasu is about
twice as long, so the ones expressed in studs or seconds were all wrong on it while the ones in
degrees were fine. That is [[derive-from-what-it-touches]] applied to animation.

`BirdSpecies.scaleOf` returns a bird's length over the reference bird's; `BirdFlight.profile`
turns that one number into two multipliers, and every scale-sensitive function takes the profile
as a trailing argument. The three rules:

| | rule | why |
|---|---|---|
| **angles** | unchanged | 45° is 45° on a wren or an eagle |
| **distances** | × scale | the hop was an absolute 0.05 studs — 6% of the uguisu, 3% of the karasu, and a crow doing a uguisu-sized hop reads as STIFF |
| **durations** | × **√**scale | bigger animals move slower roughly as the square root of length, so a 2× bird is ~1.41× slower; × scale overshoots into slow motion |

⚠ **RATES ARE RECIPROCAL TIMES AND ARE DIVIDED, NOT MULTIPLIED.** `FLAP_RATE` and `CRUISE_SPEED`
were both missing from the constant audit that preceded this work. Left alone, a crow flaps at a
warbler's 2.5 beats a second — which presents as *"the animation is wrong"* rather than *"a
constant was absolute"*, and that misdiagnosis is the expensive one.

⚠ **THE UGUISU AT SCALE 1 IS BIT-IDENTICAL, and that property is what made this safe to land.**
Multiplying by 1.0 and dividing by √1 are exact in IEEE arithmetic; a test asserts the whole
surface output-for-output, so the one bird anyone has actually watched provably did not move.
Nobody has yet seen a karasu perch, so its numbers are reasoned, not gated — **they want the
owner's eye before they are called right.**

**Deliberately NOT scaled**, recorded so restraint is not read as oversight: the resting orbit
(geometry about the player, and only a fallback for "no perch in range"), the shoulder seat (an
anchor on the avatar), the flight path's bow (already proportional to flight distance),
`RESULT_HOLD` (an owner-set display duration, not a motion), and the two idle **gaps** — how
often a bird fidgets is per-species character to be chosen by eye, not a consequence of a square
root. The rule that separates the last case: a gap a gesture lives *inside* scales with the
gesture; a gap *between* independent events is character.

⚠ **THE ONE MISTAKE THAT CANNOT BE CAUGHT AT RUNTIME** is forgetting the argument — it compiles,
runs, and looks almost right. `BirdController` is a Roblox-runtime file so Lune cannot execute
it, and `tests/BirdScaleConvention.spec.luau` reads its SOURCE instead: every call must pass the
profile, and no gate may read a duration off the module. ⚠ The list of functions it polices is
**derived from `BirdFlight`'s own signatures**, never typed in the test — a hand-kept list would
go stale exactly at the newest function, which is the worst place for it.

### Watched on a shoulder, 2026-08-28 — the first look at a karasu familiar

`SPECIES` was flipped to Karasu for a look. Owner's read, in their order:

| | verdict |
|---|---|
| the victory hop | **fine** |
| the wings | **fine for now** |
| the shoulder seat | *"a little tight to the head"* — corrected, see the seat table above; awaits a second look |
| overall size | ⚠ *"the karasu seems small, but I'm not sure we should chase that now"* — **parked, see below** |

### ⚠ MEASURED IN THE LIVE PLACE, 2026-08-28 — and the bird is not scaled, it is SLIMMER

Run the query yourself rather than trusting this paragraph — `roblox/tools/studio/measureBirds.luau`
in Edit, or the same reads against `ReplicatedStorage.RoshamboBirds` in a Play client. Two facts
came out of it that nothing on this page had predicted:

⚠ **THE KARASU IS NOT A SCALED UGUISU.** Length 1.98×, height 1.90×, **width only 1.47×**. Any
code that derives one dimension from another across species is wrong, and one already was — the
seat relief above. `BirdFlight`'s motion scale is unaffected: it keys off `bodyLength` and applies
to time and distance, not to the mesh.

⚠ **THE AVATAR'S HEAD IS THE REASON A LIFE-SIZE BIRD READS SMALL, and this is the same finding
that got the uguisu upscaled** ([[status-display]] and the ruling below). Measured on a stock R15:
head **1.196 studs wide against a 5.88-stud body** — 20% of height, where a real human head is
about 8%. The avatar's head is roughly **two and a half times too wide for its body**, so anything
sized to *reality* and placed beside it reads at about 40% of what a real observer would see.
**The karasu is not small; the head it stands next to is big.** That reframes the size question
from "is the measurement wrong" (it is not) to "does life-size survive stylized proportions"
(it may not) — which is a design decision with a precedent, not a bug.

⚠ **The wingspan figure is now VERIFIED and was previously marked unverified.** Measured off the
spread-wing MeshPart rather than a rest pose: **1.49× body length**, against a live large-billed
crow's ~2.0×. The uguisu's is 1.13×. So both birds ship short-winged, and the crow — a bird that
reads as long-winged in life — loses more by it. This remains the cheapest lead on "seems small".

⚠ **THE SIZE OBSERVATION IS DEFERRED, NOT DISMISSED, and it is a genuinely open question rather
than a bug.** The karasu measures life-size against a real hashibutogarasu, so "seems small" is a
statement about how it READS, not about whether the number is right — and the same tension already
has a ruling on the other bird, in the opposite direction, one section down. Do not resolve it by
quietly rescaling the mesh. The most likely lead is already on record below as `⚠ unverified`: the
**wingspan** ships at about 1.49× body length where a live crow is ~2.0×, and crows read as
long-winged in flight, so short wings may be most of why a life-size body does not feel big.
That would make it a wingspan question, not a size question. See [[backlog]].

## ⚠ THE UGUISU IS DELIBERATELY OVERSIZED — do not "correct" it toward life-size

Owner ruling 2026-08-27, after watching the karasu fly and asking whether it was too small.
Measured in the live place rather than guessed: **the karasu is life-size and the uguisu is not.**
A hashibutogarasu is ~50-59cm and the karasu is at the bottom of that range; a Japanese bush
warbler is ~15-16cm and the uguisu is roughly 65% over it. So the pair reads at about 2x when
nature is about 3.2x.

**The crow is correct. Leave it.** ⚠ **And leave the warbler too** — owner: *"I deliberately
chose to upscale it because it was hard to see; we might revisit that decision in the future."*
A future session that measures this pair will find the uguisu oversized and be tempted to fix it.
**That is the fix to NOT make.** Legibility at arena distance beat realism, on purpose.

Note the legibility complaint on record — *"a 7-inch bird cannot carry status at arena
distance"* — was made about a bird SMALLER than what shipped: seven inches is ~0.55 studs, and
the uguisu ships larger than that. The bird you have is already the answer to that objection.

⚠ **unverified, worth a look if sizes are ever revisited:** the karasu's body is life-size but its
wingspan measured ~75% of life (about 1.5x body length where a real crow is ~2.0x). Crows read as
long-winged in flight, so short wings may be part of why it does not feel big. Taken from a
bounding box on a rest pose, so confirm before acting on it.


**Import verified 2026-08-26.** No `SurfaceAppearance` was created (the trap in step 2 did not
fire); `TextureID` came through as `rbxassetid://129407256075817` on both parts; `HasSkinnedMesh`
true; 15 bones on the body and 5 on the wings, sharing `joint1`, for the 19 claimed. All seven
bone-drive pairs pass — non-zero on the chain, exactly 0.0000 off it — and the axis contract
reproduces the uguisu's: local X +40 moves BOTH tips −0.6579 vertically and 0.0000 fore-aft, local
Z +40 moves them +0.6579 and −0.6579 fore-aft and 0.0000 vertically.
⚠ Those magnitudes differ from the Blender-side figures recorded above (+0.7413 / +0.7984 /
−0.7060). The SIGN RELATIONSHIPS — which are what the beat and fold depend on — agree exactly; the
absolute numbers do not, and the in-place measurement is the one that governs.

Not yet done, and it is code rather than asset work: **nothing selects a bird per player.** The
motion constants are no longer uguisu-only — see the scale section above — so selection is now
the single thing standing between the karasu and being playable.

## Still thin

- **Plumage is band colour only.** The spec describes a lengthening tail streamer, a crest and a
  night glow off `nightFactor`; none is built, so "you wear your grade" currently reads as a
  slightly different colour.
- **The progression is invisible to its owner** — milestones are earned silently and grades change
  silently. Nothing announces a grade-up and nothing prints the grade.
- **Tree perches are derived from bounding boxes**, not authored per template.
- **The static half of the status pair is unbuilt**: nobori, crest on the noren, scrolls in the
  alcove. Item 6 cannot close without it ([[friends-family-baseline]]).

## Raw layer

`roblox/src/shared/BirdFlight.luau` (pure, Lune-tested), `roblox/src/client/BirdController.client.luau`,
`roblox/tools/studio/watchWingbeat.luau` (⚠ **the only way to gate a beat change** — flights are on
a 10–60s random hold, so watching one side-on otherwise means loitering and hoping; ISOLATED parks
a bird in front of the camera at a fraction of speed with the wingtip path traced, FLIGHT sends a
test-only bird back and forth along the Overlook's upper deck, north rail ↔ south rail, 30 studs.
⚠ **RUN IT IN EDIT** — no Play, no datamodel to choose, no StreamingEnabled, free camera. In Play
it must run on the CLIENT: server-built parts never reach the screen, which is why the real
familiars work at all — `Workspace.Familiars` does not exist on the server),
`roblox/src/shared/ChoreographyMachine.luau`, `server/src/engine/Milestones.ts`,
`roblox/tools/studio/sweepFamiliarPerches.luau`, `roblox/tools/builders/Spec.luau`
