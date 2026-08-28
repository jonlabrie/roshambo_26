---
shelf: world
updated: 2026-08-28
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

## Open, not decided

- **Distinguishability.** An ambient karasu on a railing must not read as somebody's familiar.
  If they are the same species at the same size, the familiar stops being special in exactly the
  way the sings-only-on-a-win rule was protecting ([[familiars]]).
- **A species list** for the setting — desirable and authentic — is wanted and unwritten. It
  bears on both roles at once, which is part of why it is worth doing deliberately.
- **Population and lifecycle**: how many, spawned by what, retired when.
