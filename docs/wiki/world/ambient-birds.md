---
shelf: world
updated: 2026-08-30
---

# Birds — the two systems, and the one architecture

Roshambo has birds in two roles: the **familiar** that belongs to a player ([[familiars]]) and
**ambient** birds that belong to the world. This page is the architecture over both. It exists
because the two were repeatedly described as different systems and they are not.

## ⚠ THE SPLIT IS AUTHORITY, NOT RENDERING

Both are **client-rendered**. That is a binding house rule, not a preference — [[fireworks]]:
*"Client-side VFX only; the server sends a tiny launch event."* A server-rendered bird would be
the only moving thing in the game replicating a CFrame every frame, against a budget gated on a
Samsung A13 ([[friends-family-baseline]] item 2.5).

What differs is what the server has an opinion about:

| | server is authoritative for | client renders |
|---|---|---|
| fireworks | a launch event | the whole shell |
| **familiar** | who has one, who won | flight, perch, song |
| **ambient** | which bird, where, when it calls | the same way |

⚠ **"Client-side" does NOT mean private.** Each client builds a bird for EVERY rostered player,
so everyone sees everyone's familiar and everyone's win-dance — which the unlock model depends
on, since *"you fly a rare bird you could only have earned"* means nothing unseen
([[status-display]]).

**What may diverge between screens is only which perch a bird idles on**, and that is a recorded
trade: *"two players' birds may double up across machines, and nobody can see both screens.
Paying for agreement would mean a server round-trip for a decoration."* ⚠ **That trade does NOT
transfer to ambient birds.** The familiar survives disagreement because it is anchored to a
player — wrong railing, still "Bob's bird near Bob". An ambient bird has no such anchor, so two
players on one dock would be looking at different birds. **This is the whole reason the server
owns ambient placement.**

## Territory is a property of the BIRD, not a mode of the system

`pickPerch(anchor)` already takes a position; only the radius is a module constant. Make that a
parameter and one mechanism covers every case:

| | anchor | radius |
|---|---|---|
| familiar | **moves** — its owner | 20 studs |
| dock uguisu | the dock, static | small — it lives there |
| a crow | a roost, static | wide |

**The familiar is already a territorial bird whose territory follows a player.** Nothing new is
needed for ambient placement except a static anchor.

⚠ **The uguisu's territory is already ruled**, not open: *"Birds are ephemeral… this bird lives
here and you have to be close to hear it"* ([[falls-dock]]). Canyon-wide range for that bird
would contradict a gate already given. It is also authentic — uguisu hold small territories and
sing from within them; large-billed crows range between roosts.

## ⚠ Long flights are nearly free, because nobody can watch them

`StreamingEnabled` is on, and a client only holds nearby geometry — `GetTagged("FamiliarPerch")`
returns what is streamed in, so **a client cannot see a perch across the canyon; it does not
exist locally.** `perchIsGone` exists for exactly this: *"a cached CFrame lands the bird on
remembered air."*

So a long flight is unobservable for most of its length by definition. A bird leaving your
streamed region and arriving elsewhere reads, from a fixed vantage point, as *"a bird flew away"*
and later *"a bird arrived"* — which is what a real bird looks like. **Range costs nothing; only
the TRANSITION needs care**, so a bird resumes at a perch rather than popping into existence
mid-air.

## What exists today

**Familiars — mostly built.** `BirdController.client.luau` (client) over the pure, Lune-tested
`BirdFlight` and `BirdSpecies`. Perches on tagged `FamiliarPerch` attachments near its owner;
holds, leashes, flutters, turns, lands on a shoulder and sings on a win. Two species built, one
reachable — **nothing selects a bird per player** ([[familiars]]).

⚠ **THE PERCH BEHAVIOURS ARE SPECIES-INDEPENDENT AS OF 2026-08-28**, which is what makes any of
this reusable. Head turns, tail flicks, the weight-shift hop, the flutter and the perch turn all
take a scale profile: angles unchanged, distances × scale, durations × √scale. So an ambient bird
of any size gets the built idle for free, and the only thing an ambient bird still needs is an
ANCHOR that is not a player. See [[familiars]] for the rules and what is deliberately not scaled.

**Ambient — one hand-built instance, and it has no body.** The falls-dock uguisu is a place-only
Part + three Sounds + a `Script` under `CanyonWorld.Ambience`. ⚠ **It is a PRECEDENT, not a
platform** — no registry, no spawner, no module. It contributes its schedule design and its
owner ruling; not its implementation.

⚠ **It is also server-RENDERED today only because it renders nothing.** It is audible and
invisible. Adding a visible bird server-side would introduce exactly the per-frame replication
the house rule forbids, so a visible dock uguisu is the FAMILIAR's renderer with a static
anchor, plus a small server voice for placement and call timing.

**Count the perches rather than trusting a number here:**
`#game:GetService("CollectionService"):GetTagged("FamiliarPerch")` — they are swept across path
railings, hero trees, chōchin poles, the descent stair and the Rojo builders' output.

## ⚠ Constants are duplicated between the two, today

| | dock Script | `BirdController` |
|---|---|---|
| pitch jitter | ±3% | ±3% |
| timing band | 10–60s bouts | 10–60s perch hold |
| clip set | the same three ids | the same three ids |

Arrived at independently, living in two places, one of them place-only and invisible to git —
[[duplicated-server-constants]]'s exact defect class. **Making the dock bird visible is the
moment to fix it**: a server `Script` can `require` `ReplicatedStorage.RoshamboShared.BirdSpecies`,
so the numbers move into the committed, Lune-tested module and the place keeps only wiring.

## The species list — started 2026-08-30

**Ambient and familiar birds are DIFFERENT SPECIES** (owner ruling). And the distinction is
ecological, not a rule the code has to enforce: **familiars are birds that come to people;
ambient birds keep their distance.** You never see a heron on a shoulder because a heron
wouldn't. That answers the distinguishability question below without a size clamp or a
behavioural exception.

⚠ **THE COST DRIVER IS BEHAVIOUR CLASSES, NOT SPECIES COUNT.** The system does one thing today:
perch, hop, flutter, fly perch-to-perch, sing. A bird that fits is nearly free; a bird that does
not buys a whole class. Soaring (a kite), wading (a heron), ground-walking (a pheasant) and
flocking (sparrows) are four separate pieces of work, and each is a session on its own.

**First slice, chosen 2026-08-30 — four perching birds, all free on the built behaviour:**
yamagara (varied tit), mejiro (Japanese white-eye), hiyodori (brown-eared bulbul), sekirei
(wagtail). All four are one body plan, so they are ONE retarget with four proportion sets and
four palettes, not four efforts.

### ⚠ The zebra dove is an OWNER RULING, not an oversight

`dove.blend` becomes a **zebra dove** (*Geopelia striata*), chosen for its call — owner, 2026-08-30:
*"I know it's invasive almost everywhere but I love its call from my time spent in Hawaii and I'll
find it soothing here."* It is native to Southeast Asia and introduced in Hawaii, so it is not a
Japanese bird and is not meant to be. **Do not "correct" it toward a kijibato on authenticity
grounds** — that decision has been made and may be revisited only by the owner. Same standing as
the uguisu's deliberate oversize ([[familiars]]).

Two consequences that are easy to misread as defects:

- ⚠ **ITS BEAK MUST NOT OPEN, AND `caws = nil` IS THE CORRECT DATA.** Doves coo with the bill
  essentially closed; the sound is the throat inflating. A silent beak here is authentic, not
  missing onsets — so do NOT run `tools/audio/measure_caws.py` at it, and ignore
  `watchWingbeat`'s no-caws warning for this species.
- **Its markings are a new kind of paint.** The bird's whole identity is fine barring across neck
  and flanks. `bake_bird_texture.py` rasterises a colour FUNCTION of 3D position, which suits
  gradients and features like a supercilium; regular fine barring is periodic instead, and at
  1024² over a whole bird the bars may not resolve. Test a swatch before committing.

### ⚠ The uguisu IS the sparrow, and the sparrow was never discarded

Checked 2026-08-30 against an owner recollection that it had been rejected. It had not, and the
distinction matters because it decides the base for every future small bird:

- The uguisu is the vendor **sparrow**, repainted. `bake_bird_texture.py`: *"the vendor's map is a
  photoreal SPARROW... and the target is a plain olive uguisu"*, keeping the vendor unwrap because
  *"a non-overlapping unwrap is most of what the purchased model is worth."*
- **The sparrow's rig is the contract the whole system runs on.** `BirdController` drives the
  sparrow's bone names (`joint1/3/4/8/12/25` + `wing_*`/`wrist_*`); the crow arrived as a Maya
  QuickRig humanoid and every bone was renamed into the sparrow's scheme.
- What WAS rejected is the sparrow **as a base for the karasu**, and only for one reason:
  *"a real crow head and bill... is the half of the silhouette a sparrow cannot be reshaped into."*

⚠ **THAT OBJECTION IS ABOUT A HEAD AND BILL, AND IS SILENT FOR SMALL BIRDS.** Every bird in the
first slice has a fine passerine bill, which is what a sparrow already has — so the sparrow is the
right base for all four.

## Open, not decided

- ~~**Distinguishability.**~~ **Decided 2026-08-30** by ecological register — see the species
  list above. Ambient and familiar are different species, and familiars are the birds that come
  to people.
- **The species list is started, not finished.** Four perching birds and the zebra dove are
  chosen; the larger ambient birds (a kite, a heron, a flock) are candidates only, and each buys
  a behaviour class the system does not have.
- **Anchors want to be COMMITTED DATA, not place tags.** `GetTagged` returns a different set per
  client under `StreamingEnabled`, so a tag sweep cannot be derived deterministically. A committed
  table of territories (name, position, radius, species, which events it reacts to) is identical
  on every client by construction — which makes placement derivable from a shared clock with
  **zero server traffic**, and closes the divergence problem this page opens with. Not built.
- ⚠ **THE BELL STARTLE IS ALREADY FREE, and nobody has used it.** `RoundMetronome` is pure and
  clock-agnostic, and its `Schedule` carries `strikeAt` — the server publishes the strike as a
  SCHEDULE, not an event. So a startle is a pure function of `(strikeAt, now, seed)`: no remote,
  no replication, and every client scatters the same birds on the same toll by construction.
  ⚠ A round is 60s, so a canyon-wide reaction every minute would read as a machine — startle
  belongs to the TERRITORY (the bell tower roof), not to the world.
- **Population and lifecycle**: how many, spawned by what, retired when.
