---
shelf: world
updated: 2026-08-26
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
| Size | ⚠ **0.222 × 0.472 × 0.828 studs AS SHIPPED** — measured off the committed `.rbxm` 2026-08-26. This page long recorded 0.148 × 0.315 × 0.552 ("life size, ~7 inches"); that is the size it was DESIGNED at, and nothing rescales the clone — `BirdController` has no `ScaleTo` and no `Size` write — so what players see is 0.828, about 10 inches. Every ratio derived from 0.552 was therefore wrong by 1.5×. |
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
y +0.847, x +1.117 from the HumanoidRootPart on a stock R15 (arm 0.943 × 1.213 × 0.759) — and R6,
R15 and scaled bodies all differ, so no constant could be right.

**Gated 2026-08-26**, after three corrections, and every number is a PROPORTION of the arm so a
scaled avatar gets the same result:

| | | why |
|---|---|---|
| `SEAT_INBOARD` | 0.42 of arm width | the middle of the shoulder; `arm.Position` is the arm's CENTRE, and 0.18 left the bird out over the arm |
| `SEAT_LIFT` | 0.031 of arm height | ⚠ a part's top FACE is not the visible shoulder — the mesh and any layered clothing sit proud of it, so at 0 the feet sank in. 0.45 inches on a stock R15 |
| `SHOULDER_YAW` | 0 | faces forward with the avatar |

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

| | |
|---|---|
| Body | 0.328 × 1.640 × 0.897 studs, **2,666 triangles** |
| Wings | 2.446 studs tip to tip, **856 triangles** (`KarasuWings`, separate part) |
| Bones | **19**, one rig shared by both parts |
| Origin | **feet at z = 0**, centred in x/y — same contract as the uguisu |
| Source | `karasu_body.fbx`, `karasu_wings.fbx`, `karasu_colormap.png` in `~/Desktop/Roshambo Reference/models/birds/probe/` |
| Rebuilt by | `roblox/tools/blender/karasu_retarget.py` — `run()`, `verify_rig()`, `bake_and_finish()` |

⚠ **LIFE SIZE, AND THAT IS TWICE THE UGUISU** — not three times. Owner-chosen 2026-08-26: 1.64
studs / 19.7 inches, a hashibutogarasu (~50cm). The comparison was written against the uguisu's
DESIGNED 0.552; measured off the committed asset, the shipped uguisu is 0.828, so the real ratio
is **1.98×**. It follows two standing rulings
rather than inventing one — *"life size, maybe slightly larger"* (2026-08-19) and *"a presumably
larger bird, like a raven/crow to carry it"* (2026-08-22). **The consequence is real work for the
main thread:** `SEAT_INBOARD` / `SEAT_LIFT` are proportions of the avatar's arm, not of the bird,
so a bird three times longer than the shipped one will not seat correctly without retuning, and
`PERCH_RADIUS` and the flight tuning were both set looking at a 7-inch bird.

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

### ⚠ Import instructions — this is the hand-off, and one step is not optional

The asset thread does not touch Studio ([[parallel-threads]]). For the main thread:

1. Import `karasu_body.fbx` and `karasu_wings.fbx`. **Do not rescale** — unlike the uguisu (built
   at 0.828 and believed to have been scaled to 0.552 in Studio — measured 2026-08-26, the
   committed `.rbxm` is 0.828 and nothing rescales it, so that scaling either never happened or was
   undone), this one is 1:1 at its final size.
2. ⚠ **DELETE THE SurfaceAppearance THE IMPORTER CREATES AND USE `TextureID` INSTEAD.** The FBX
   carries a ColorMap and nothing else, and a **ColorMap-only SurfaceAppearance on opaque geometry
   renders warm and shiny** — Roblox substitutes its own defaults for the missing channels
   ([[material-and-mesh-traps]] §8). On a black bird that is glaring. The uguisu ships as a
   `TextureID` for exactly this reason.
3. ⚠ **Set `part.CFrame` directly — never `PivotTo`.** The importer bakes a rotation into the
   MeshPart's CFrame with a compensating one in `PivotOffset`, so an identity pivot lays the bird
   on its back ([[blender-pipeline]]).
4. ⚠ **Anchored: TRUE, and it IS an importer setting** — it is in the dialog, and a parked probe
   that is not anchored falls out of the world on the first Play.
5. ⚠ **Vertex colours: OFF.** The vendor meshes carry a `colorSet0` baked-AO layer running
   0.0–0.15 which Roblox MULTIPLIES into the surface ([[blender-pipeline]]). On the uguisu that read
   as a broken material for an hour; on a black crow it would be nearly invisible as a fault and
   simply ship 85% too dark.
6. Confirm `HasSkinnedMesh` and run a bone-drive test in the place before gating — and measure a
   DESCENDANT of the driven bone, never the driven bone itself, which cannot move under its own
   rotation and reads a meaningless zero.

**Import verified 2026-08-26.** No `SurfaceAppearance` was created (the trap in step 2 did not
fire); `TextureID` came through as `rbxassetid://129407256075817` on both parts; `HasSkinnedMesh`
true; 15 bones on the body and 5 on the wings, sharing `joint1`, for the 19 claimed. All seven
bone-drive pairs pass — non-zero on the chain, exactly 0.0000 off it — and the axis contract
reproduces the uguisu's: local X +40 moves BOTH tips −0.6579 vertically and 0.0000 fore-aft, local
Z +40 moves them +0.6579 and −0.6579 fore-aft and 0.0000 vertically.
⚠ Those magnitudes differ from the Blender-side figures recorded above (+0.7413 / +0.7984 /
−0.7060). The SIGN RELATIONSHIPS — which are what the beat and fold depend on — agree exactly; the
absolute numbers do not, and the in-place measurement is the one that governs.

Not yet done, and both are code rather than asset work: nothing selects a bird per player, and the
seat/perch constants above are still tuned for the uguisu.

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
