---
shelf: world
updated: 2026-08-25
---

# Familiars — the bird that reads your round

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
| **LOSS** | bolts wide, then sinks to a low slow orbit | down, in a grammar where up means won |
| **SAFE** | nothing at all | safe means nothing changed, so the bird does not change |
| **RESTING** | perched on the world | no entry, or a result that has lapsed |

⚠ **VERTICAL DIRECTION CARRIES THE OUTCOME.** The space above a player's head is the only region
never occluded by another avatar, so height is what survives a crowd of fifty on a phone — colour
and detail do not. A test pins that the three differing holds are separable **by height alone**.

⚠ **A LOSS MUST NOT COME HOME to the resting orbit** — that would make "lost" and "has not thrown"
identical. It sinks and stays low.

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

| | |
|---|---|
| MeshId | `rbxassetid://114444614583565` |
| TextureID | `rbxassetid://133923547243928` (1024² ColorMap) |
| Size | 0.148 × 0.315 × 0.552 studs — **life size, ~7 inches** |
| Triangles | 2,688 |
| Bones | 19, including `bill_lower`, `wing_R`, `wing_L` |
| Origin | **feet at z = 0**, centred in x/y |

Built by retargeting a purchased sparrow (TurboSquid "Rigged Low Poly Bird Collection" 1603819,
Standard License; source lives outside the repo). What was inherited: the standing posture, ten
correctly-weighted leg and toe bones, clean quad topology, and a non-overlapping unwrap — which
is most of what the model was actually worth. What was changed: tail +25%, head seated 0.024
down (crown rise above the back line 0.064 → 0.027), bill root narrowed to 37% of the sparrow's,
and the whole ColorMap repainted from photoreal sparrow to plain olive uguisu.

**The origin at the feet is load-bearing.** It makes `perch.WorldPosition` the bird's position
with no fudge, retiring the `+ Vector3.new(0, 0.2, 0)` the four-part bird needed.

⚠ **`BAND_COLOR` DOES NOT SURVIVE THIS.** The controller shows grade band by setting `p.Color`
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

⚠ **GEAR UP.** Fixed legs read as *"a plane flying with the wheels down"*. Measured: **+100° at the
hip** lifts the foot 0.280 studs, from y −0.281 to −0.001, and puts EVERY joint of the leg chain
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
y +0.811, x +1.128 from the HumanoidRootPart on a stock R15 — and R6, R15 and scaled bodies all
differ, so no constant could be right.

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
