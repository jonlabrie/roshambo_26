---
shelf: world
updated: 2026-08-18
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
`roblox/src/shared/ChoreographyMachine.luau`, `server/src/engine/Milestones.ts`,
`roblox/tools/studio/sweepFamiliarPerches.luau`, `roblox/tools/builders/Spec.luau`
