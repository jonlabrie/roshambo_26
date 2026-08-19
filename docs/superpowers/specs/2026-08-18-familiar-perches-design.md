# Familiar Perches — design

**Status:** proposed, 2026-08-18.
**Governs:** the RESTING state of the familiar, which currently orbits its owner's head.
**Builds on:** `docs/superpowers/specs/2026-08-18-familiars-and-grades-design.md` (the bird, its
result states, and the grade it wears).

---

## 1. The problem

Every bird orbits its owner's head at all times. Owner, 2026-08-18: *"they can't just be circling
the heads of avatars, it'll look like a bad cartoon where everyone just got knocked on the head.
Familiar birds need to be interacting with the environment — landing on trees, railings, and
roofs. Nearby, ready to celebrate or commiserate, but not underfoot or overhead all the time."*

`BirdFlight`'s `HOLD.RESTING` orbit is already marked in-code as a placeholder for exactly this.

**What good looks like:** standing in the arena square, you see birds on the shōrō roof, along the
Overlook railings, and in the maples — and when a round resolves they leave those perches, do
their thing, and come back.

## 2. Where perches come from

**⚠ CORRECTED 2026-08-18 BY SURVEY.** This section first described TWO sources split by lifetime.
The place has **three**, and the third is the one that matters most — see §2c. It also assumed the
railing part was named `RailCap`; the canyon's 1,250 path railings are named `Rail`, and every
other railing in the world SUFFIXES (`RailNUpperDeckCap1`, `RailCapN_1`), so matching must be by
pattern, not by exact name.

Three sources, split on a line that matters: **who owns the geometry's lifetime.**

### 2a. Named surfaces, swept (hand-built and static geometry)

The world already names the surfaces a bird would land on. Verified 2026-08-18:

| what | part name | built by |
|---|---|---|
| deck + path railings | `RailCap` (the top member; `RailMid`/`RailBarrier` are not perches) | `src/server/PadOps.luau` |
| teahouse roof | `Ridge` | `tools/builders/Teahouse.luau` |
| machiya roof | `Ridge` | `tools/builders/Machiya.luau` |
| chaya roof | `RidgePurlin`, `RidgeBundle` | `tools/builders/Chaya.luau` |

**So the sweep finds perches BY NAME, not by geometry.** This is the whole reason not to raycast
for flat upward faces: a geometric sweep puts birds in the middle of a path, on top of a lantern,
and on a player's head, and tuning that out is open-ended. A name is a statement of intent by
whoever built the thing.

A Studio tool walks the world for those names and stamps `Attachment`s along each — spaced every
few studs on a rail, one or two per ridge. Re-runnable and idempotent, so geometry built later is
picked up by running it again.

### 2b. Per-template authoring (trees)

⚠ **CORRECTED BY SURVEY.** `FoliageKit` holds **78** templates, not the ~7 assumed here, and the
40 instances under `CanyonWorld.Foliage.Heroes` carry names that do not map cleanly onto them
(`SugiC`, `DockHero_1`, `Hero_11_PineNiwakiA`). Authoring per template is still the better answer,
but it is a much larger job than one line implied — so the sweep currently **derives** two perches
per tree from its bounding box at 62% height. That is a deliberate approximation to let the idea
be looked at; replace it with authored anchors if birds in trees read well.

**So perches are authored ONCE PER TEMPLATE and every instance inherits them** — a branch fork, an
outer bough, two or three per species. Seven templates, and it propagates across the whole canyon.
This is the same author-once-instance-many pattern as the `teahouse-1story-s/m/l` prefabs.

⚠ Trees already placed in the world are clones taken **before** the templates gain attachments, so
they will not have them. Re-stamping is `placeCanopyHeroes`'s own `MODE = "place"` path, but that
would discard any hand-dragging done since. **The tool must therefore also be able to graft
attachments onto existing clones by species**, which is cheaper and non-destructive.

### 2c. ⚠ THE SPLIT THAT MATTERS: THREE LIFETIMES, AND THE SWEEP OWNS ONE

**A perch stamped onto geometry a builder regenerates will vanish the next time it runs.**
`PadOps.buildRailing` runs whenever a teahouse materialises on a pad, which is every claim, every
session. A swept attachment on `RailCap` would survive exactly until the next player claimed that
pad.

So the rule is:

1. **ROJO-OWNED → the builder emits it into the model.json.** Every roof, plus the Overlook and
   SwitchbackDeck: `Hanabiya`, `MachiyaApparel/Accessories/Stats`, `Chaya`, `Overlook`,
   `SwitchbackDeck` are all `RoshamboStage` children built from `assets/*.model.json`. An
   attachment stamped on one in Studio is destroyed by the next sync. `Spec.perch(kind, offset)`
   emits it; `lune run tools/genmodels` regenerates; the committed JSON is drift-checked in CI.
   **This is strictly better than sweeping** — it lives in git and regenerates with the prop.
2. **RUNTIME-BUILDER-OWNED → the builder emits it too.** `PadOps.buildRailing` builds the teahouse
   **engawa railing** and runs on every pad claim, so a swept perch there survives until the next
   player claims that pad. Two per railed edge; the back edge is left open by `PadBuilder` and has
   no rail.
3. **PLACE-ONLY → the sweep.** Canyon path railings, the two hand-built landings, both bridges,
   and the hero trees. Nothing regenerates these.

⚠ **Rojo ownership does NOT preclude perches** — it precludes *sweeping* them. That distinction
was muddled when this spec was first written and cost a round trip. `Chochin.luau` has emitted a
`Tags` property through `genmodels` for months; tagging from a builder was already solved.

Getting this backwards produces the worst kind of bug: it works when tested and silently degrades
in normal play.

## 3. How a perch is represented

An **`Attachment`**, tagged `FamiliarPerch` via `CollectionService`.

- **Invisible by nature** — no transparency to maintain, no part budget, no collision.
- **Rides its parent's CFrame**, so a perch on a railing moves if the railing moves and dies with
  it. A baked world coordinate would not.
- **`CollectionService:GetTagged` is one call**, and `GetInstanceAddedSignal` /
  `GetInstanceRemovedSignal` give arrival and departure for free — the exact idiom
  `DecorationController` already uses for `"Decoration"`.

Attributes on the attachment:

- `PerchKind` — `"rail" | "ridge" | "branch"`. Lets a bird prefer a branch over a rail, and lets a
  future species prefer differently.
- `PerchYaw` — optional facing, so a bird on a ridge faces along it rather than across it.

## 4. How a bird chooses

Client-side, per bird, no server involvement — a perch choice is cosmetic and does not need to
agree between clients.

1. **Look for perches within `PERCH_RADIUS` of the owner.** Not of the bird: the bird follows its
   owner, and the owner is what moves.
2. **Prefer unoccupied.** Each client keeps its own reservation set. Two players' birds may
   double up across clients — nobody can see both screens, and paying for agreement here would
   mean server round-trips for a decoration.
3. **Fly there, land, idle** — small hops and a preen on a timer, so a perched bird is not a
   frozen prop.
4. **Re-pick when the owner leaves the radius**, with hysteresis so a player standing at the
   boundary does not send their bird back and forth.
5. **⚠ Fall back to the orbit when there is no perch in range.** Mid-bridge, out on the water, on
   an unbuilt path. The orbit stays in `BirdFlight` and stops being the default rather than being
   deleted.

⚠ **`StreamingEnabled` IS ON** (`main.server.luau:115` and three client controllers already
account for it). A distant railing may not exist on a given client, and the perch a bird is flying
to can vanish mid-flight. **Never cache a perch CFrame** — re-read the attachment each frame and
fall back to the orbit if it has gone. `FoliageImpostorController`'s header states this rule for
foliage already; it is the same rule.

## 5. What it does not change

- **WIN and LOSS are unaffected.** A bird leaves its perch, performs, and returns — the result
  states already persist until the next reveal and are not perch-aware.
- **SAFE still has no behaviour**, so a safe leaves a bird exactly where it is: perched.
- **Grade plumage is unaffected.**

## 6. Out of scope

- **Bird baths.** Owner named them; there are none in the world. That is new scenery and wants to
  be its own prop with its own gate, not a rider on this.
- **Ground behaviour** — hopping on paths, pecking. Underfoot is explicitly what this is avoiding.
- **Flocking between birds.** Each familiar is its owner's; birds do not notice each other.
- **Species-specific perch preference.** `PerchKind` is recorded so it becomes possible, but there
  is one species today.

## 7. Open questions

- **`PERCH_RADIUS`** — far enough that a bird is not underfoot, near enough that it reads as
  *yours*. Wants the arena square and a look, not a number chosen here.
- **Perch density on a long rail** — every 4 studs is a row of birds on a railing, every 15 is one
  bird per deck. Same: a look, not a guess.
- **Does a bird return to the SAME perch after a result, or pick fresh?** Same reads as ownership;
  fresh reads as alive. Undecided.
- **What happens in the vestibule and the Stats cavern**, where there are no rails, ridges or
  trees at all — orbit fallback, or bore a few authored perches into the rock?

## 8. Raw layer

- The bird: `docs/superpowers/specs/2026-08-18-familiars-and-grades-design.md`
- Code this touches: `roblox/src/shared/BirdFlight.luau`,
  `roblox/src/client/BirdController.client.luau`, `roblox/src/server/PadOps.luau`, a new
  `roblox/tools/studio/sweepFamiliarPerches.luau`, and the `FoliageKit` templates (place state)
- Idiom to follow for tag binding: `roblox/src/client/DecorationController.client.luau`
- Streaming discipline: `roblox/src/client/FoliageImpostorController.client.luau`
