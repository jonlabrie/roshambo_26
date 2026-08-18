# Familiars and Grades — design

**Status:** proposed, 2026-08-18.
**Governs:** friends-&-family item **6 (rewards & flex)**, and the round-result legibility defect
that prompted it.

**This is an ACTIVATION, not a new design.** The familiar system was designed and approved on
2026-07-04 in `docs/superpowers/specs/2026-07-04-roshambo-metagame-design.md` and parked on one
stated blocker — a dusk cycle — which shipped since. Four things this document specifies were
already written there and were independently re-derived in conversation on 2026-08-18, which is
evidence the design is right and that the spec was not being read:

- *"Familiars react to the owner's reveal (rise and circle on WIN, perch on SAFE, scatter-regroup
  on LOSS)."*
- *"The mobile status display complementing the teahouse's static one."*
- *"A familiar flying with you when you bank a milestone pot gains visible plumage/glow —
  creatures carry your history."*
- *"Owner's noren/mon at the entrance"* — the crest as teahouse signalling.

Where this document and the 2026-07-04 spec differ, **this one governs**, and the difference is
scope only: that spec describes the whole system (species rosters, befriending, feed, flocks of
5–7, collection UI). This one specifies the **wedge** that fixes the defect and carries status,
and from which the rest hangs without rework.

---

## 1. The problem this solves first

Round results do not read. Verified in the tree 2026-08-18:

- **WIN** emits 30 pale-gold particles from the head and nothing else. The 1.6× avatar grow the
  owner remembers (`applyGrow`, all four body scales, `c31b943`) was **deleted**;
  `TheaterController`'s comment still claims *"the grow itself is server-side (replicated
  scale)"*, which has been false since. ⚠ Fix that comment.
- **SAFE** draws one anchored cylinder rotated flat, 6×6×0.4, muted red-brown, three studs above
  the head — no ribs, no shaft, no canopy curve. The owner read it as a cloud, which is the
  correct reading of a featureless disc. The bangasa was never drawn.
- **LOSS** has no visual at all: `EffectRegistry.LOSS = {}`, parked 2026-08-03 when the chasing
  fates were withdrawn.

So one outcome is thin, one is unrecognisable, one is absent.

## 2. The rule the visual grammar follows

**Vertical direction carries the outcome.** The space above a player's head is the only region
never occluded by other avatars, and direction survives what colour and detail do not: a small
screen, a crowd of fifty, and a cheap Android phone.

| result | the bird | why |
|---|---|---|
| **WIN** | spirals **up** and circles | the only motion that rises |
| **SAFE** | settles and **perches** on the shoulder | a landed bird is unmistakable, and "nothing changed" is exactly what perching says |
| **LOSS** | startles, **darts off**, returns after a beat | the pot was lost, not the companion |

"Scatter and regroup" in the 2026-07-04 spec assumes a flock; with one bird it becomes
startle-and-return. The flock is the growth path (§9), not the wedge.

## 3. Grades

**Grade is a count of milestones earned.** Owner ruling, 2026-08-18, chosen over time-played and
over skill-rank. The reasoning is load-bearing and must survive into implementation:

- A **rate is an inference** and inference needs sample — which is where item 7's 360-throw floor
  comes from, and why a rate board is empty for a week. A **milestone is an event**: exactly true
  the moment it happens.
- So grading needs **no sample**, is unaffected by `TEST_MODE` (the World Throw is a fixed R→P→S
  cycle in every environment today, so nothing skill-derived can be validated), and **cannot be
  lost by not playing** — which matters because the program's own bar reads *"rounds skippable, no
  penalty — hangout is the product."* A grade you can lose by logging off is a treadmill.

**The ladder:** kyū counting down, then dan counting up, hinged at 初段 as a real event.

```
10th kyu … 1st kyu  │  1st dan … 5th dan
white ────────────► │  ◄──────── black
fast, frequent      │  slow, rare
```

Fifteen grades. Stopping at 5th dan rather than 10th because judo's upper dan are largely
honorary. Thresholds widen as you climb, so 10th kyū lands on a player's first evening — the game
should acknowledge someone before they leave it — and 1st dan is genuinely uncommon.

`gradeFor(milestoneCount) -> grade` is a **pure function**, shared, fixture-tested.

## 4. The milestone catalog

Five families, all computable from rows already written. **No new capture.**

| family | milestones | source |
|---|---|---|
| **Depth** — how far you rode | pot reached 9 · 27 · 81 · 243 · 729 · … | `User.bestPot` |
| **Run** — how long you held | streak of 3 · 5 · 7 · 10 | `StreakEvent` |
| **Career** — what you kept | banked 100 · 1,000 · 10,000 · 100,000 · … | `User.lifetimeBanked` |
| **Presence** — that you showed up | first bank · 360 throws in a week | `BankEvent`, `PlayerRound` |
| **Firsts** — once only | first win · first bank · first appearance on the banzuke | settlement |

**Depth and Career are POWERS, and that is the trick.** They generate new milestones indefinitely
without anyone hand-authoring a hundred achievements, and their spacing gets naturally harder
exactly where the ladder does.

⚠ **Every milestone must be earn-once and monotonic.** `bestPot` is kept via `$max` and
`lifetimeBanked` never decreases, so both are safe bases. **Do not derive a milestone from
`totalPoints`** — it is a wallet and is decremented by purchases, so a milestone built on it would
be *revoked by shopping* (`docs/wiki/world/core-loop.md`).

## 5. Plumage

**Grade has 15 steps; plumage has 5 bands.** Fifteen visually distinct birds is neither achievable
nor legible; five is. The bird shows the band; the exact grade shows where there is room to print
it — the personal slip in the vestibule, and the teahouse banner.

Bands ride on what survives distance: **colour saturation, tail-streamer length, a crest, and a
night glow** driven by the `nightFactor` the day/night system already publishes.

## 6. Architecture

### Server

- **`server/src/engine/Milestones.ts`** — pure. Given a player's stats, returns the set of earned
  milestone ids. Held to a fixture in `shared-fixtures/`, in the same spirit as
  `GameRules`/`game-rules.json`: these are rules that must not drift silently, and a grade that
  changes retroactively is a broken promise rather than a bug.
- **Evaluated at settlement**, after scoring, in `engine/Settlement.ts`. Newly earned ids are
  appended to `User.milestones: string[]`. Append-only; nothing is ever removed.
- **`gradeFor`** is a pure function over the count, exported alongside.
- `grade` and `milestones` join the existing `GET /api/v1/players/:robloxUserId` response — the
  call every Roblox player already makes on join.

### The wire

Plumage is **social** — the point is that other people see it — so every client needs every
present player's band, not just their own. The Roblox server already fetches each player's profile
on join; it broadcasts a small roster (`userId → grade`) on a new `FamiliarRoster` RemoteEvent,
refreshed when a grade changes (rare: at settlement, and most rounds change nobody's).

### Roblox client

- **`roblox/src/shared/BirdFlight.luau`** — pure. Orbit position, rise curve, perch offset,
  startle vector, all as functions of elapsed time and a seed. Testable under Lune; no Roblox
  service, per the standing DI rule.
- **`roblox/src/client/BirdController.client.luau`** — owns one bird per present player, lerps it
  by CFrame (**no Humanoid**, per the 2026-07-04 spec), applies the band, and reacts to reveals.

## 7. Two things that will break this if missed

**⚠ THE DRUM IS AUTHORITATIVE. EVERY REACTION GATES ON `drumRest`.** `RevealTheater` lands ~3.45s
*before* the throw drum finishes turning. A bird that celebrates on arrival announces the round
while the wheel is still spinning — and unlike the petals, which spoil it only for their owner, a
bird visible across the arena spoils it **for everyone watching that player**. `TheaterController`,
`main.client.luau`, `LanternController` and `StatsController` all already hold on this cue; the
bird joins them. See the existing essay in `TheaterController.client.luau` on why the old
`REVEAL_SAFETY = 3` was wrong.

**⚠ THE CONSEQUENCE CUE DOES NOT CARRY THE RESULT, AND MUST.** `ChoreographyMachine` emits a
`consequence` cue for every player in `reveal.results`, but puts only `effect` on it — and
`EffectRegistry.LOSS` is empty, so `selectEffect` returns `nil` for a loss. Inferring the outcome
from which effect was chosen couples the bird to the effect catalog, which is the exact coupling
`EffectRegistry` exists to prevent (an effect is meant to be swappable data). `r.result` is
already in scope one line above the cue's construction. **Add `result` to the cue.**

## 8. Performance

Fifty players, one bird each, once a minute, on a device floor of a Samsung A13.

- **No Humanoid, no physics.** A single anchored part (or MeshPart) per bird, CFrame-lerped from a
  pure function. This is the 2026-07-04 spec's own prescription and it is not negotiable.
- **Distance LOD**, also from that spec: distant birds collapse toward a billboard, then to
  nothing. The threshold is a Studio-gate number, not a guess.
- The A13 walk of the Stats room (2026-08-17) is the calibration point: ~8,400 GUI instances cost
  no more than the arena square. Fifty lerped parts is a far smaller ask, but it must be measured
  on the device rather than assumed, because the arena is where the crowd actually is.

## 9. Out of scope — the rest of the familiar system

Deliberately deferred, all specified in `2026-07-04-roshambo-metagame-design.md` and all hanging
off this wedge without rework:

- **Acquisition by befriending.** Species appearing at specific places and times; the walk *is* the
  acquisition. Needs the species roster and per-valley identity.
- **Feed as a store sink**, and the collection/flight-loadout UI.
- **Flocks of 5–7** displayed at once, with the owned collection unbounded.
- **Species roster and the crane** as top prestige tier.
- **The teahouse half of the status pair** — nobori by the door, scrolls in the alcove, the
  owner's crest on the noren. Item 6's original scope named a banner-pole flag; it belongs with
  the teahouse work, not with the bird.
- **The crest (kamon) itself** — chosen or assigned is undecided (§10), and it is a catalog and a
  UI, not a bird.

**⚠ SO ITEM 6 CANNOT CLOSE ON THIS SPEC ALONE.** Its stated scope is milestone badges *plus*
teahouse flex *plus* avatar flex. This delivers the milestones, the grade and the mobile half. The
static half — the flag, the crest, the alcove — is a second piece of work, and it is the one that
gives a visitor a reason to walk into someone else's teahouse. Plan accordingly rather than
discovering it at the gate.

## 10. Open questions

- **Is the crest chosen or earned?** Children will want to pick one; that is a catalog plus a
  picker plus moderation of the choice space. Assigned-at-first-join is cheaper and still
  identifies a player. Undecided.
- **Plumage band thresholds** — which grades map to which of the five bands. Wants the Studio gate
  and a real look, not a table picked here.
- **LOD distance** — same; measured on the A13.
- **Does the starter bird have a species**, or is it deliberately generic until befriending ships?
  A named species now sets an expectation the roster has to honour later.

## 11. Raw layer

- Prior design: `docs/superpowers/specs/2026-07-04-roshambo-metagame-design.md` (approved
  `4d9b9c6`, amended `2de2b21`, `eb3ef1a`, `ef6ced9`)
- Item 7's measurement basis, which this deliberately does **not** depend on:
  `docs/superpowers/specs/2026-08-18-player-measurement-design.md`
- Code this touches: `server/src/engine/{Milestones,Settlement}.ts`, `server/src/models/User.ts`,
  `server/src/routes/apiV1.ts`, `roblox/src/shared/{BirdFlight,ChoreographyMachine}.luau`,
  `roblox/src/client/{BirdController,TheaterController}.client.luau`,
  `roblox/src/server/main.server.luau`
