# Shoji Screens — Design

Item 5 of the friends-and-family baseline: *"Teahouses come in three sizes but the shoji
are static panels. Make them real."* Open, half-open and closed per screen, ideally by
grabbing and sliding; and a swappable variant slot in the loadout from day one, so better
screens can become an earnable item later.

**Owner decisions, 2026-08-18** (each one settled in conversation before this was written):

- Screen positions are **shared world state** on a materialized teahouse; **the owner's
  slides persist, a visitor's do not**.
- Movement is **hold-to-slide** on a proximity prompt, not grab-drag and not a state cycle.
- Side bays get the same treatment as front and back.
- **Every screen gets its own channel**, so a whole run can tuck into one bay — and that
  bay may be any bay on the wall, not just an end. No pocket (tobukuro): the stack stays
  visible, parked wherever the player left it.
- The variant slot ships as the F&F spec asks — but the survey below found it already
  built, so this item proves it works rather than building it again.

## 1. What already exists — and why this item is smaller than it reads

Surveyed from the live place, 2026-08-18 (`ServerStorage.StructurePrefabs`, Studio MCP):

| prefab | shoji bays | pitch (x) | panel width | panel depths |
|---|---|---|---|---|
| `teahouse-1story-s` | 2 front, 2 back | 6.00 | 5.90 | −3.20 / −3.00 |
| `teahouse-1story-m` | 3 front, 3 back, 2 per side | 6.00 | 5.90 | −5.88 / −5.68 / −5.48 |
| `teahouse-1story-l` | 4 front, 4 back, 3 per side | 6.00 | 5.90 | −9.20 / −9.00 / −8.80 / −9.20 |

**The panels are NOT yet a sliding run, though they look like one from the numbers.** A
first read of the depths (−9.20 / −9.00 / −8.80 / −9.20 across the L's front) suggested a
track per panel. A closer look says otherwise: *within* a bay every part shares one plane —
paper, kumiko, rails, stiles and glow all at −9.20 for `Bay_front_1` — and the variation
between bays is 0.20 of inconsistent authoring against a 0.40-thick wall, which puts bay 1
on the wall's outer face, bay 2 at its centre, bay 3 on its inner face and bay 4 back on the
outer. Two of the L's four panels share a plane and would collide if slid past each other.

Channels have to be authored deliberately, and that is the one piece of geometry work this
item carries (§2.1). Everything else about the panels — width, pitch, the parts that make up
a leaf — is finished and correct.

Each bay is `Bay_<side>_<index>`, a Model holding three variant Models (`Solid`, `Shoji`,
`Door`); `StructureOps.applyBays` shows one and hides the other two by transparency, driven
by the loadout's `wallBays` map (`solid | shoji | door` per bay). The `Shoji` variant is 13
parts — paper, kumiko, two stiles, two rails, and a neon `ShojiGlow`. Sliding moves that
whole Model, so `ShownTransparency`, collision and `TreatmentApplier`'s night pass ride
along untouched.

**The variant slot is not merely in the schema — it is wired end to end.** `LOADOUT_KEYS`
carries `shoji`; `StructureCatalog` carries two entries with `slot = "shoji"`
(`shoji.plain`, `shoji.crane`, both `type = "texture"`); `StructurePlanner.resolveTextures`
turns the loadout's `shoji` value into a texture operation; `StructureOps.setTexture`
applies it. What is missing is **art** — both entries point at placeholder asset ids
(`rbxassetid://0` and a fabricated `102000000001`) — and any way for a player to choose one.
So the F&F line *"the slot ships now; the catalog can wait"* describes something already
built. This item does not have to build it, and should not pretend to.

## 2. The model

One number per shoji bay: **`open`, the panel's travel in bay-widths**, positive toward
increasing local X.

- **The only limit is the run itself.** A screen may slide anywhere between the first and
  last bay positions of its wall — for a four-bay run, that is three bay-widths of travel in
  one direction if it starts at an end. There is no per-screen cap: a cap would say "park
  over your neighbour and no further", and the owner's ruling is that a whole run may tuck
  into a single bay (2026-08-18).
- **That bay may be any bay on the wall.** The stack is wherever the players put it, which
  is why no bay is special and no end is privileged.
- **No panel-vs-panel collision exists to model** — once §2.1's channels are authored, every
  panel in a run has its own, so any number of them sharing a bay position is a legal stack.
- **An N-bay run opens at most N−1 bays.** The panels have to be somewhere, and with no
  pocket to hide them the fullest opening is every screen stacked in one bay: 18 of the L's
  24 feet, 12 of the M's 18, 6 of the S's 12. "Open the whole wall" is not a state, and
  nothing in the UI should imply it is.

### 2.1 Channels — the one piece of geometry work

Each bay's leaf moves to a deliberate track: **groove `i` of an N-bay run sits at
`wallCentre + (i - (N+1)/2) * 0.20`**, so the stack is centred on the wall's mid-plane and a
0.16-deep stile has 0.04 of clearance from its neighbour.

| run | grooves | span | vs the 0.40 wall |
|---|---|---|---|
| S (2 bays) | 2 | 0.40 | flush |
| M (3 bays) | 3 | 0.60 | 0.10 proud each face |
| L (4 bays) | 4 | 0.80 | 0.20 proud each face |

0.20 is kept as the pitch because it is what the prefabs already use, so no leaf changes
size or shape — each one only moves in z. The **rails deepen** to span their run's groove
stack (0.16 → 0.40/0.60/0.80 in z), which is what makes a multi-track sill read as joinery
rather than as a panel floating off the wall. On the L that sill stands two inches proud of
each face; that is a threshold you step over, and it is correct for a wide run.

Rails become **one sill per side**, not one per bay: a continuous member is what the eye
expects along a run, and it stops four abutting rails from disagreeing at their joins.

## 3. Authority and replication

The **server owns every offset.** It writes each one as a number attribute `ShojiOpen` on
the bay Model; a client controller tweens that bay's `Shoji` model to match.

This is the attribute-plus-controller pattern already used by the day/night and lantern
systems, and it is chosen over replicating the Model's CFrame directly: a server that moves
an anchored model at tick rate gives every client stepped motion, while an attribute plus a
local tween is smooth on any framerate and costs one replicated number per moving screen.

Consequences that make this the cheap path:

- A player who joins mid-session sees the current positions, because attributes replicate
  with the instance.
- The controller needs no knowledge of who moved what — it renders a number.
- Server-side collision follows the model, so an opened bay is walkable and a closed one is
  not, with no extra work.

## 4. Interaction — hold to slide

Each shown `Shoji` variant carries a `ProximityPrompt`:

- `HoldDuration` is set high enough never to complete; the prompt is driven from
  `PromptButtonHoldBegan` and `PromptButtonHoldEnded`, so holding is the gesture and the
  prompt never "fires".
- While held, the server advances that bay's offset at `SLIDE_RATE` (one bay-width in
  ~1.2 s), clamped by section 2. Release stops the panel wherever it is.
- **Direction is implied, not chosen**: a screen less than half open (|open| < 0.5) slides
  toward open, and one at or past half slides toward closed. One prompt does both jobs, so
  touch never has to aim at anything smaller than a wall panel, and a screen abandoned
  mid-travel resumes in the direction it was already going.

Grab-drag was considered and rejected: on touch it competes with the camera drag, and in
first person on a laptop the cursor is pinned to screen centre and cannot be aimed at a
screen at all — the same wall the HUD hit (`docs/wiki/program/backlog.md`, keyboard throws).
A state cycle was rejected for losing the sense of pushing something, which is the whole
point of the item.

## 5. Persistence — the owner's slides stick, a visitor's do not

- Offsets live on the materialized teahouse and are shared by everyone inside it. Any
  player who can be in the house can slide a screen, and everyone sees it move. Access
  control already decides who can be inside; this adds no permission of its own.
- When the **owner** releases a slide, a debounced write (≈2 s of quiet) puts that side's
  offsets into the loadout under a new key, `shojiOpen`, and PUTs the whole loadout through
  the existing `PUT /api/v1/players/:robloxUserId/teahouses/:sizeClass`. The server holds
  the owner's loadout in `playerHouse[uid].loadout` already, which is what makes this a
  small edit rather than a new save path.
- When a **visitor** releases a slide, nothing is written. Their change is live for everyone
  present and gone when the house next materializes.
- On materialize, saved offsets are applied **before the house is revealed**, so a returning
  owner never sees their screens snap.

`shojiOpen` is a per-side array of numbers, mirroring `wallBays`' shape:

```
shojiOpen = { front = { 0, 1 }, back = { 0, 0 }, left = { 0 }, right = { 0.5 } }
```

Validated server-side beside `validateWallBays`, by the same rules: known sides only, at
most `MAX_BAYS_PER_SIDE` entries, every entry a finite number within
`[-(MAX_BAYS_PER_SIDE - 1), MAX_BAYS_PER_SIDE - 1]` — the widest a run could ever be. The
real limit is the run's own length and belongs in `ShojiRun`, which knows how many bays the
wall has; the validator's job is only to refuse nonsense before it is stored. A malformed
map is rejected whole, and a rejected map leaves the house at its defaults rather than half
applied — the failure mode `validateWallBays` already chose.

## 6. The variant slot — already built, so this item only proves it

Section 1 found the slot working from loadout to texture. The F&F bar asks for it to
*exist*, and it does. This item therefore does two small things and stops:

- **Prove the path** with a test that a loadout carrying `shoji = "shoji.plain"` produces a
  texture operation for the shoji target, so the slot cannot rot unnoticed while it has no
  art in it.
- **Record the truth** on the wiki: the slot is live, the two catalog entries are
  placeholders, and nothing in game lets a player pick between them. Picking is a
  management-UI question and belongs with the decoration catalog work in [[backlog]], not
  here.

Real paper art and a second variant a player can earn are catalog and UI work, and neither
is blocked by anything in this design.

## 7. Files

**New**
- `roblox/src/shared/ShojiRun.luau` — pure: clamping, travel limits, the run-extent rule,
  offset → local-X displacement. No Roblox globals; runs under Lune.
- `roblox/src/client/ShojiController.client.luau` — binds prompts, tweens panels from the
  `ShojiOpen` attribute.
- `roblox/tests/ShojiRun.spec.luau`.

**New (Studio, place-only work)**
- `roblox/tools/studio/trackShojiBays.luau` — re-tracks each run's leaves onto the §2.1
  grooves and deepens each side's sill into one continuous member. Idempotent: it computes
  every z from the run's bay count rather than nudging what it finds, so running it twice
  changes nothing. Place must be SAVED afterwards.

**Modified**
- `roblox/src/server/StructureOps.luau` — apply saved offsets when showing a `Shoji`
  variant; expose the bay models the prompt binder needs. No change to the texture path —
  the variant slot already works.
- `roblox/src/server/main.server.luau` — the `SlideShoji` remote, the hold loop, the
  owner-only debounced write.
- `roblox/default.project.json` — `SlideShoji` RemoteEvent under `RoshamboRemotes`.
- `server/src/loadout.ts` — `shojiOpen` in `LOADOUT_KEYS`, `validateShojiOpen`, wired into
  `validateLoadout`.
- `server/src/loadout.test.ts` — bounds, shape and rejection cases.

## 8. Testing

Most of this is testable without Roblox, and the parts that are not are deliberately thin.

- **`ShojiRun` (Lune)**: a screen clamps to its run's ends and no tighter — the third bay
  of a four-bay run can travel −2 and +1; every screen in a run may occupy one bay position
  at once, from any starting arrangement; the stacked bay may be any bay, including an
  interior one; offset → displacement is exactly `open * 6.00`; a malformed or missing
  offset resolves to closed rather than erroring; and the channel formula in §2.1 puts N
  grooves symmetrically about the wall's mid-plane for N of 2, 3 and 4.
- **The variant slot (Lune)**: a loadout with `shoji = "shoji.plain"` resolves to a texture
  operation on the shoji target — a guard on a path that has no art in it yet and would
  otherwise rot silently.
- **`validateShojiOpen` (vitest)**: unknown side rejected, over-long array rejected,
  non-finite and out-of-range numbers rejected, a valid map accepted, and — the case that
  matters — a loadout carrying a bad `shojiOpen` is rejected whole.
- **Not covered by tests, by nature**: that the prompt reads well on a phone, and that the
  slide rate feels like pushing a screen rather than driving one. Both are owner looks.

## 9. Out of scope

- No paper flex, no shadow cast through the paper, no sound. Cheap to add later; none of it
  is load-bearing for "make them real".
- No art for the two catalog variants, and no UI to choose between them. The slot works;
  filling it is catalog and management-UI work.
- No per-visitor screen state (everyone in a house sees the same screens).
- No new access rule: if you can be inside, you can slide.
- Screens are not doors. Nothing gates entry on a screen's position, and `wallBays`' `door`
  state is untouched by this item.

## 10. Risks

- **A visitor can shut every screen in someone's house.** It is ambient and reverts on
  rematerialize, and the owner can reopen them, but it is a griefing surface. Accepted for
  this bar; the fix, if it ever bites, is to restrict sliding to the owner and their
  friends, which the access spine can already answer.
- **Prompt density.** A large teahouse has 14 shoji bays, so a player standing inside sees
  several prompts at once. `MaxActivationDistance` and `RequiresLineOfSight` need tuning at
  the owner look; if it stays noisy, one prompt per *run* rather than per bay is the
  fallback.
- **The L's sill stands 0.20 proud of each wall face**, because four grooves need 0.80 and
  the wall is 0.40. That is the design working as intended — a wide run has a deep
  threshold — but it is the one place this item changes a teahouse's silhouette, and it
  wants an owner look on the L specifically rather than on the S.
- **Re-tracking the prefabs is place-only work.** `StructurePrefabs` lives in ServerStorage,
  not in git, so the channel edit must be a committed Studio tool that is idempotent and
  re-runnable, and the place must be saved after it runs. An unsaved re-track looks exactly
  like a successful one until the next session.
