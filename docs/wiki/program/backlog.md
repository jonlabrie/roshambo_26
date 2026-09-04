---
shelf: program
status: open
updated: 2026-09-03
---

# Backlog

Future work captured with enough context to restart cold. Nothing here is scheduled; the
active program is [[friends-family-baseline]]. Ordering within this page is arbitrary.

## TOMORROW'S AGENDA (owner, 2026-09-03 close — post-cold-walk)

Owner's own list, verbatim intent, after a walk that was "great, right up to the
teahouse" and left them feeling "I could walk through a demo with a couple of newbies
tomorrow":

1. **Engawa railing tunnel-exit cuts** — "the railings need to be aware of where the
   tunnel exits are, because right now on many pads you exit into a closed railing and
   have to jump over." Railings are procedurally built (`PadOps.luau` deck geometry;
   see [[teahouses]] § deck fall-prevention), so this needs a per-pad CUT: "a one time
   pass where I show you where it's needed and we make it happen, for each pad" —
   owner-guided, pad by pad, likely a per-site cut spec (PadSites data or attributes)
   the builder honours. Interlocks with the 2026-07-05 access decision ("access
   infrastructure is hand-built per site") and its "occupancy-conditional access
   objects" future hook.
2. **⚠ RULING REVERSAL — teahouse railings become unjumpable, "full stop".** This
   supersedes the settled 2026-07-13 fall-prevention design ("stop *accidental*
   walk-offs only — a deliberate leap into the gorge still works... Do not resurrect
   tall imprisoning walls"). The invisible fall-guard's `BARRIER_H` (3.5, "a pure
   physics number") is the lever; fireworks must keep passing (the `EngawaBarrier`
   collision group passes `Projectile`). Update [[teahouses]] when built.
3. **Stats-cave onboarding** — "onboard the player to the stats cave (like Batman's
   bat cave, get it?)... maybe the first time they level up or something." Folds into
   the banked "teahouse/stats beats" item below; the trigger moment (first level-up?)
   is a design question for the pass.
4. **Random familiar assignment** — new players get a familiar randomly assigned "from
   among the three (currently) available familiars. Not the crow, which we need to
   make ambient." See [[familiars]] / [[ambient-birds]] for the current roster (the
   mejiro is today's default; the karasu's ambient conversion was already directed on
   the bird thread). This also finally moves [[friends-family-baseline]] item 6's
   "roster selection is the smallest thing" blocker.

## A spooky area at the WEST END of the canyon — fireflies and fog in the trees

Owner, 2026-08-19, parking the ground-fog question: *"I think we're going to do a little spooky
area up at the west end of the canyon, with fireflies and fog in the trees up there."*

**Atmosphere CANNOT do this and it is worth knowing before anyone tries.** `Lighting.Atmosphere`
is a single global object — no zones — and it has **no height falloff**, so it cannot be dense at
ground level and clear above. The place already runs one (read its values off `Lighting.Atmosphere` in Studio; Density and
Offset were retuned for the [[horizon-backdrop]] on 2026-09-03), and the legacy `FogStart 180` / `FogEnd 900` beside it is **inert**: once an
Atmosphere exists the legacy fog properties are ignored.

Two techniques that DO work, both already proven in this repo:

- **Per-client atmosphere crossfade.** Lighting changes made from a LocalScript are client-only,
  so Density/Haze/Color can be lerped as a player crosses into a region. Caveat: it changes that
  player's WHOLE view, not the region — standing outside looking in, you see your own atmosphere
  painted over the far zone. Fine for enclosed places, wrong where you can see between zones.
- **Ground fog from flat particles.** The waterfall recipe on [[blender-pipeline]] carries the
  trick: `Orientation = VelocityPerpendicular` + `EmissionDirection = Top` + `Speed 0.6-1.0` +
  `Acceleration = 0` + `SpreadAngle = 0` makes a quad lie FLAT instead of billboarding. Two traps
  recorded there apply directly — near-zero Speed goes invisible under `VelocityPerpendicular`
  (it needs a velocity to orient against), and `ParticleEmitter` has no phase offset, so emitters
  pulse in lockstep unless Rate AND Lifetime differ.

⚠ **Treat this as a PERF change that happens to look nice.** Large overlapping transparent quads
near the camera are close to worst case for mobile fill rate, and the A13 gate (item 2.5) is the
constraint, not the technique. In its favour: `StreamingEnabled` means distant emitters never
load, and Workspace already carries 111 ParticleEmitters at an acceptable baseline. Scope it to
specific spots rather than blanket coverage.

Fireflies are the cheap half — few, small, bright, additive — and want the [[day-night]] cycle
to gate them to dusk.

## Teahouse access control — core SHIPPED, extensions remain

Shipped and 2-account-validated 2026-07-19/20 — see [[teahouses]] for the as-built.
Deferred from it: guest passes / portal-to-a-friend's-teahouse (the `canEnter` seam is
ready), block/ban lists, per-decoration/floor/time access, the gate ART pass (noren
perimeter + newel beacons are placeholders), and the optional tunnel-mouth gate survey
(`roblox/tools/studio/surveyAccessGates.luau`). Guest passes and floors are on the F&F
out-of-scope list.

## Spawn-at-teahouse (Piece B candidate — not built)

Deferred by the owner 2026-07-13 ("why am I not starting in my teahouse?"). Central spawn
+ travel-to-perch is current behavior by design. The Home Portal MVP (2026-07-19,
`13a6cb9..c20a822` — a purchased portal linking own deck ↔ arena, including the
DevChannelSpawn cleanup) grew out of this ask, but spawn-at-own-deck itself is unbuilt.
Ingredients exist: `SiteCoordinator`/`playerHouse` know the claimed pad,
`PadSites.deckPlacements` gives the deck, `PivotTo` on spawn. Brainstorm questions:
replace or supplement the arena spawn; what happens on first join before any claim;
interaction with the arena-central round loop and with access gates.

## Piece B — the remaining arc

B1-B4, the deck-decoration framework, the Home Portal MVP and access control all shipped
2026-07-13..20 ([[teahouses]]). Remaining: decoration catalog expansion (swap-skinning — colorScheme / shoji /
tatami / flags / wallArt; teahouse-anchored props needing S/M/L anchor slots; banner /
noren / maku slot content; collidable/sittable props; partial refunds; multi-pad
decoration memory), teahouse floors, the fireworks-battle / valley-as-secondary-arena
flex layer, and spawn-at-teahouse (above). Constraints that still govern: split
Roblox/PWA economies, points-only v1, teahouse ≤ deck, the deck is a yard.
Raw layer: `docs/superpowers/specs/2026-07-05-roshambo-structure-builder-design.md`
(`7e2eca6`) and the 2026-07-13..19 specs/plans (b1/b2/b3/b4, home-portal,
deck-decoration-framework, teahouse-access-control) under `docs/superpowers/`; ledger
`.superpowers/sdd/progress.md`.

## Sliding shoji — deferred from the 2026-08-18 ship

Item 5 of [[friends-family-baseline]] shipped 2026-08-18 (see [[teahouses]]). Its final
whole-branch review ruled five things deferred rather than guessed at; none block the
ship, and none has a design decision pending — they are implementation debt.

- **The client cancels and recreates a `Tween` on every server write** for a moving
  screen, instead of lerping in `RenderStepped`.
- **No one-holder-per-bay latch** — two players holding the same screen at once fight
  each other's writes.
- **The hold loop does not re-check `BayState` mid-hold** — a wall re-applied to
  `solid` while a stranger is mid-slide keeps sliding until they release.
- **The Studio tool (`trackShojiBays.luau`) keeps its own axis tables** rather than
  reading `ShojiRun.runAxis`, the class of drift risk [[duplicated-server-constants]]
  warns about.
- **Two same-tick persist debounces on different screens still cost two PUTs** (the
  second folds the first's value in rather than losing it — correct, not optimal).

## The wiki lint's citation check has a partial-path blind spot

Found 2026-08-18, the day after the check shipped. `world/core-loop.md` carried a live wrong
claim — that the shipped leaderboards rank by `totalPoints` — while citing
`transports/socketAdapter.ts` and `routes/apiV1.ts`. Neither citation was seen, because
`CITE_RE` anchors on a known repo root (`roblox|server|src|tools|docs|shared-fixtures`) and both
are written relative to `server/src/`. The claim was caught by reading the code for another
reason, which is exactly the path the check exists to replace.

**Fix sketch, and the trade it carries.** Broadening the regex to any `dir/file.ext` would match
these, but an unresolvable partial would then raise a *dead code citation* error on prose that
was never a path. The measured version: broaden the pattern, keep ERROR only for paths anchored
on a known root, and emit a WARNING for an unresolvable partial. Adding `server/src/` and
`roblox/src/` to `CITE_PREFIXES` is needed either way.

Not urgent — the check is a floor, not a net, and [[wiki-currency]] says so. Recorded so the
limitation is known rather than assumed away.

## A records display — points earned across every window

Owner, 2026-08-18, after the south-wall inversion: *"we'll need a records display, e.g. lifetime
points earned, points earned in a month, week, day, hour, consecutive rounds played (sounds
dangerous, but...)"*. Not scheduled; captured with what it would cost.

**Most of it is nearly free.** `heatBoard(w, limit, userIds?)` already ranks players by points
earned in an arbitrary `Window`, and `earningsInWindow` already computes one player's. Lifetime is
`User.lifetimeBanked`, monotonic and already on `LEADERBOARD_FIELDS`. So hour / day / week are a
window argument and a board, not new machinery — which is exactly what centralising the window
vocabulary in `server/src/windows.ts` was for.

Two gaps: **there is no month helper** (`calendarMonthUTC` alongside the day and week ones, or a
rolling 30), and **earnings must come from `BankEvent`, never from summing `PlayerRound.pointsDelta`
— that column records the new POT on a win, so a naive sum overstates badly ([[core-loop]]).

**⚠ CONSECUTIVE ROUNDS PLAYED IS THE ONE THAT ISN'T FREE, AND THE OWNER'S OWN "sounds dangerous"
IS THE RIGHT INSTINCT.** Two separate problems:

1. **It is not tracked and would need new capture.** `roundsPresent` counts rounds inside session
   intervals and `throws` counts PlayerRound rows; neither is a *run*. A consecutive counter has to
   be incremented and reset at settlement, like `currentStreak` but keyed on participation rather
   than winning.
2. **It contradicts a stated design principle of the program.** [[friends-family-baseline]]'s bar
   reads: *"Roshambo is an ambient game (~1 throw/min, rounds skippable, no penalty) — hangout is
   the product."* A consecutive-rounds record makes leaving cost something. That is precisely the
   mechanic that converts an ambient game into a compulsive one, and this is a kid-first
   experience.

   Note the game already has a "do not stop" pressure that is about SKILL — the pot, which punishes
   riding too long and rewards reading the room. Consecutive-rounds-played adds a second one that
   is purely about TIME. The first is the game; the second is a treadmill.

   If it is wanted anyway, the safer shape is a **one-off milestone badge** ("played 50 rounds
   without a break") rather than a leaderboard to defend — earn-once cannot be lost, so it never
   punishes leaving. A ranked board would.

**Where it goes is an open problem: the room has no free wall.** After the inversion the cavern
holds `pots`/`runs`/`banzuke` (south), `skill` + `skillFuture` (west), `judgement` (east), `world`
(north), plus the round display; the vestibule holds `fuda` and `summary`. A records display must
displace something or the room needs more surface. `judgement` (east, 8×22) is the closest fit by
subject — it already carries biggest bank and biggest round — but 8 rows will not hold five windows
plus its existing two sections.

## Tournament windows — player- and group-created competitions

Owner, 2026-08-18, while settling the measurement basis: *"I think timed 'tournament windows'
should be a thing for individuals and groups to be able to create and join, but that's beyond
the scope here."* Explicitly out of scope for
`docs/superpowers/specs/2026-08-18-player-measurement-design.md` and recorded so it is not lost.

**What already exists that this would build on.** Every stats query in `server/src/stats.ts`
takes a `Window { from, to }` and nothing else — `qualifiedBoard(w, minThrows, limit)` would
rank a tournament exactly as it ranks a rolling week, with no new aggregation. That is the whole
reason the vocabulary in `server/src/windows.ts` was centralised, and it means a tournament is
mostly a *membership and lifecycle* problem, not a statistics one.

**What it would need.** A tournament record (owner, window, invited/joined set, whether it is
open or private); a way to create and join one in-world; a board that can show a window other
than the room's default; and a decision on qualification — the 360-throw floor is derived for a
7-day window and would be wrong for a 2-hour tournament, where the honest floor is far lower and
the result correspondingly noisier. **A short tournament cannot measure skill** (see the spec's
§2(e): at 60 throws a blind player's win rate lands anywhere between 23% and 43%), so a
tournament is a *contest*, not a ranking, and its copy must not pretend otherwise.

Interacts with teahouse access control (the invite-by-username machinery already resolves and
persists userIds, capped at 50) and with the F&F out-of-scope guest-pass work.

## Meta-game spec (approved — the design ceiling for the economy)

`docs/superpowers/specs/2026-07-04-roshambo-metagame-design.md`, approved `4d9b9c6`,
amended `2de2b21` (pad classes: cliff-perch air vocabulary vs valley-floor ground
vocabulary), `eb3ef1a` (vacant pad states: dark teahouse / pocket garden), `ef6ced9`
(SPLIT Roblox/PWA economies — shared wallet ruled non-viable under Roblox policy).
Locked: personal teahouses = Mongo loadouts materialized on walk-up pads; 50+ pads
eventually via 2 new valleys; points-only v1, Robux-buys-points permanently ruled out;
the bell ring is deliberately NOT a point sink; familiars (befriend-in-world, no gacha)
require a dusk cycle. Deferred by the spec: houses/factions, gacha, ema/omikuji,
statue-of-day, gifting, drone swarms.

## App Runner → ECS Express migration — do before production

Parked 2026-08-01. Premise: App Runner is closed to NEW customers with NO deadline (not
EOL); target is Amazon ECS Express Mode. We skip the migration guide's Route 53
blue/green entirely — no custom domain; cutover = change Amplify's `VITE_SOCKET_URL` and
redeploy, rollback = change it back. `server/Dockerfile` already exists. The one real
design decision: secrets — `MONGODB_URI`/`JWT_SECRET`/`API_KEY` are SSM SecureStrings, so
use the bring-your-own task definition path (`--task-definition-arn`; container named
`Main`, one TCP port mapping, FARGATE). Gotchas: ALB idle timeout is 60s (our 1s `sync`
heartbeat covers Socket.io, set it deliberately); dev's auto-deploy-on-push becomes
GitHub Actions + OIDC + ECR; Atlas already allows 0.0.0.0/0. Cost is the downside:
~$50/mo per service (always-on ALB + Fargate task) × 2 services — decide whether the dev
backend deserves its own ALB. Strategy: dev first (exercises every unknown, risks only
Studio testing), run a week, then prod; keep both App Runner services alive throughout.
Verify before planning: whether AWS's GitHub Action supports BYO task definitions, and
Express Mode's minimum cpu/memory. Reconcile Node pins while in there (Dockerfile
`node:20`, `apprunner.yaml` `nodejs22`, `.nvmrc` 24.x).

## Onboarding content & pacing design pass

Deferred, not done — owner, 2026-08-05: needed work, "just not needed for the
friends/family demo". The bones exist and are wired: four beats (`join`,
`throwsUnlocked`, `win`, `bank`) on `EventBus.Onboard`, `OnboardingController.client.luau`
(471 lines), server-side has-seen flag round-tripping via `OnboardShown` acks. What has
never had a design pass is the content and pacing — whether four beats are the right
four, what they say, whether they land for a child who has never played. The empty-card
layout defect gates any of this: [[parked-defects]] (d). Revisit before any unattended
audience.

## Yamadoro trail lighting — placed; lighting decisions open

Six yamadoro are placed along the river trail with coordinates baked (`0c8f362`,
`roblox/tools/studio/placeYamadoro.luau`; verified 2026-08-15 — 6 models under
`Workspace.CanyonWorld.Paths.PathLanterns.Yamadoro_RiverTrail`, template parts in
`ServerStorage.YamadoroLibrary`), and night has an ambient floor (`17bbb08`). Open: the firebox — the owner chose bind-to-`nightFactor` when this
was still a yukimi question, re-confirm before wiring (no firebox-lighting commit found);
the three-register care-gradient idea (built fixture → set stone → no fixture westward)
was proposed, never decided — stone underlighting, moss glow, and hotaru all remain
unchosen; model compromises to revisit only if it reads machined in place (timid
displacement, no lichen, faceted roof eave).

## PWA throw-drum replica — parked idea

From the F&F baseline: a working replica of the arena's throw drum on the PWA. The PWA is
otherwise out of F&F scope (showable as-is).

## The karasu reads small on a shoulder — parked 2026-08-28

Owner, on the first look at a karasu familiar: *"the karasu seems small, but I'm not sure we
should chase that now."* ⚠ **This is not a measurement error.** The bird is life-size against a
real hashibutogarasu; the question is how it READS at arena distance, which is the same tension
that got the uguisu deliberately upscaled — in the opposite direction ([[familiars]]).

⚠ **Measured in the live place the same day, and it changes the question** ([[familiars]]). The
avatar's head is about **2.5x too wide for its body** against real human proportion, so anything
sized to reality and placed beside it reads at roughly 40% of what a real observer would see.
**The karasu is not small; the head it stands next to is big** — which is the same finding that
got the uguisu deliberately upscaled, and it makes this a design decision with a precedent rather
than a defect.

**Two ways to open it, cheapest first:**

- **Wingspan.** Now VERIFIED off the spread-wing mesh at **1.49x body length** against a live
  crow's ~2.0x (the uguisu is 1.13x, so both ship short-winged). A crow reads as long-winged in
  life and loses most by this. `KARASU["wing_spread"]["span"]` in
  `roblox/tools/blender/karasu_retarget.py` is the dial; the retarget runs end to end
  ([[blender-pipeline]]), so it is asset work that touches no motion.
- **Upscale the body**, accepting stylized proportion over realism. ⚠ This needs an OWNER ruling,
  not a session's judgement — it reverses "life size" (2026-08-26) and the wiki now carries a
  standing warning against re-litigating the uguisu's size in the other direction.

**Cheaper than either:** nothing selects a bird per player yet, so no player can meet a karasu at
all. Selection is upstream of caring how it reads.

## World remainders (carried from the world-shelf migration, 2026-08-15)

- **Bell-engine beauty pass** — owner asked 2026-07-23, deliberately unscheduled:
  toothed gear meshes, textured/chamfered timber, cast-bronze bonshō mesh, smooth
  snail-cam mesh, rope/chain meshes, flume/fall foam-mist; also slimmer gear cogs
  (the −7° mesh phase can never read perfectly clean at current dowel sizes). Do
  after the mechanism stops shifting. See [[bell-engine]].
- **River hydrology** — owner deferral 2026-07-28 ("a problem I won't solve now"):
  the runs are too slight to feed the hero falls. Either build the runs up
  (`upcanyonRiverPOC.luau` is the prototype) or accept them as quiet connective
  tissue. Related walks never done: cascades W14–16 audibility from the east decks;
  a survey pass for silent stretches between features. See [[water-audio]].
- **Fireworks global director at scale** — the concurrent-shell cap has never been
  exercised by a multi-player battle; the A13 bench was one launcher. Test before
  any 50-player event. See [[fireworks]].
- **Dragon-panel reuses** (owner, 2026-07-22): an eye-level back-lit named gallery of
  the 8 dragon kings, and a Robux-only 8-sided "magic lamp" deck item (Piece B
  catalog tie-in). Assets ready in `src/shared/DragonKings.luau`. See [[day-night]].
- **Climbable shōrō belvedere** — parked idea: a railed gallery at the tower crown,
  passing the working machine on the way up; fireworks perch.
- **FoliageDayNight dimming** — jewel canopies read too bright at night; a
  `nightFactor` subscriber lerping SurfaceAppearance tints (GlyphDayNight pattern)
  was sketched, never built.
- **Lantern telegraph tag rollout** — result lanterns are found by `*Lantern` name;
  a CollectionService tag would make the canyon-wide contract explicit. See
  [[viewing-platform]].

## The PWA's sound toggle needs to be on the main page

Owner, 2026-08-17, right after the reveal bell became audible for the first time: "we're
probably going to need to make the sound on/off more prominent — on the main page,
ideally."

Today it is a row in the **Stats view** (`StatsView.tsx`, "Audio Output" with a
`Volume2`/`VolumeX` icon and a volume slider). Defaults to enabled at 0.5. Nothing on the
game screen indicates whether sound is on, which is a good way to lose an hour — a player
who muted it once during testing has no way to notice.

Worth doing together with it: the bell only sounds after a gesture unlocks WebAudio, so
between page load and first tap the game is legitimately silent. A speaker affordance on
the main page could carry both states honestly — muted by choice versus not yet unlocked —
where a bare on/off toggle would show "on" while nothing plays. See
[[misc-engine-traps]] for why that gap exists.

## HUD dismiss/recall, and throwing from the keyboard

Raised by the owner 2026-08-16 while specifying the [[stats-room]], but these are GLOBAL
play concerns, not that room's scope — they change how every player throws, everywhere.

**Throwing from the keyboard.** A laptop player in first person cannot interact with the
HUD at all: the cursor is pinned to screen centre. The [[modal-cursor-grip]] recipe does
NOT transfer — it works because a modal is temporary, and holding the cursor free for an
always-visible HUD would mean never being able to look around. Keyboard binding is the fix.

⚠ **`R`/`P`/`S` cannot be the bindings.** `S` is Roblox's default walk-backward key, so
Scissors would reverse the player. `R` and `P` are both free, but the scheme is not.

**RULED (owner, 2026-08-16): `1` / `2` / `3`.** Verified that the client uses **no Tools or
Backpack**, so the number row is unclaimed. Roblox `KeyCode`s follow physical position, so
letter bindings move under AZERTY/QWERTZ while numbers do not. The HUD teaches the binding
itself — each throw tile carries its numeral in the corner:

```
  ┌─────┐  ┌─────┐  ┌─────┐
  │1    │  │2    │  │3    │
  │  ○  │  │  ─  │  │  ∧  │
  └─────┘  └─────┘  └─────┘
   ROCK    PAPER   SCISSORS
```

Bind via `ContextActionService` so the action sinks correctly and can be released while a
modal or the ledger has focus. Must respect the existing throw gates: the T₀−2s lockout, and
the fate gate that stops fate-bound players throwing (`main.server.luau`).

**HUD dismiss/recall.** The HUD is always visible. Worth a way to put it away — most
valuable exactly where the owner noticed it, in a room built for reading walls. Needs a
recall affordance that cannot itself be lost, and must not break the drum-authoritative
reveal path ([[round-and-hud]]).

## Stats data capture — two follow-ups left open at merge

Plan `docs/superpowers/plans/2026-08-16-stats-data-capture.md` shipped 2026-08-16 (12 commits,
`3f0b39a..4e63eeb`). The final whole-branch review passed it as ready to merge with two items
deliberately not fixed. Both concern PWA presence and they interact — fix them together.

**1. PWA sessions orphaned by a process death stay open forever.** The stale sweep is now
scoped to `instanceId: { $exists: true }` so it can never truncate a non-heartbeated transport
(that was the Critical it fixed). The cost: a PWA session open when the process dies is never
closed, and `roundsPresent` treats an open session as running to the window end — inflating
that player's presence. Note the dev backend auto-deploys on every push, so this fires often.

⚠ Do NOT fix this by closing open PWA sessions at boot — that is only safe single-instance and
would truncate a sibling's live sessions on App Runner. **The safe repair, available now that
PWA sessions heartbeat every 30s: a sweep of `platform: 'pwa'` sessions whose `lastSeenAt` is
older than the grace window.** A live session on a sibling instance carries a fresh
`lastSeenAt` and cannot be selected, so it is instance-independent. It does re-couple the sweep
to the heartbeat, which the Critical's fix deliberately decoupled — a real design call, not an
oversight.

Severity note: this is the *repairable* direction of failure. Rows are left un-closed rather
than wrongly closed, so a backfill can still close them at their last known `lastSeenAt`. The
bug it replaced overwrote correct intervals unrecoverably.

**2. A disconnect racing `sync-player` leaks a self-refreshing heartbeat entry.**
In `socketAdapter.ts`, the `disconnect` handler's `heartbeats.delete(socket.id)` versus
`sync-player`'s `heartbeats.set(socket.id, ...)` after `openSession` — ⚠ the line numbers that
used to be here pointed at reveal broadcasting instead, unrelated code. If the socket drops while
`sync-player` is awaiting
`resolveUser`/`openSession`, the disconnect handler runs first and finds no `sessionId`, then
the sync handler registers a heartbeat for a dead socket. That entry refreshes `lastSeenAt`
forever, so it would defeat follow-up (1) as well as growing the `Map` unbounded over process
lifetime. A `socket.connected` check before `heartbeats.set` closes it.

**Operational note for whoever deploys this:** removing `index: true` from a Mongoose schema
does NOT drop an index already built in a live database. If `roshambo-dev` or `roshambo` has
already created `userId_1` on `sessions`/`bankevents`, it persists until dropped by hand or by
`syncIndexes()`. The write-cost saving is only realised on fresh collections.

## Stats surface (plan 2) — notes carried out of the merge

Plan `docs/superpowers/plans/2026-08-16-stats-surface.md` shipped 2026-08-16. Nothing blocking;
these are things a later reader would otherwise have to rediscover.

- **`/api/v1/stats/records?window=all` emits a `to` 24 hours in the future.** Plan 3 must not
  print that bound verbatim or "All time" will read as ending tomorrow. It is labelled
  `windowKind: 'rolling'` because the bound genuinely moves per request — `'calendar'` would be
  a lie — but the label is imprecise and the echoed `from`/`to` are the honest signal.
- **`window=all` is an unbounded scan** of `StreakEvent`, `BankEvent` and every WIN row of
  `PlayerRound`, with sorts not served by the range indexes. Fine at fifty players; consider
  capping it at a season, or adding sort-key indexes, before it matters.
- **`participationRate` can exceed 1.0** and is deliberately unclamped: `throws` counts
  PlayerRound rows while `roundsPresent` counts rounds inside session intervals, so lagging
  presence reporting from a Roblox instance can invert them. Documented in `stats.ts`; a display
  should decide how to show it rather than be surprised.
- **`User.index({ currentStreak: -1 })`** costs an index write on every settled player every
  round, for `liveStreaks`, which has no consumer until plan 3.
- **The plan doc diverges from the code**: it names a `playerVolume(userId, w)` that was never
  built. Its three figures are folded into `playerRates` instead, which is the better shape.

## Stats room displays (plan 3) — SHIPPED; one thread left open

Plan `docs/superpowers/plans/2026-08-16-stats-room-displays.md` shipped 2026-08-16..17. The
boards are built, the place is saved, and the owner has walked the room on the A13. The
as-built — siting, flap modules, typography, framing, the live-tuning attribute trap — lives on
[[stats-room]], which is the page to read. This entry keeps only what did NOT ship.

Two spec §6.2 items are deferred with reasons in the plan, not dropped: the 番付 as a printed
sheet with rank encoded by calligraphy size (a different renderer; the owner decides whether the
flap sheet suffices), and the top-three avatar plinths — which now have a home, the cavern wall
that `fuda` vacated ([[stats-room]]).

### Carried out of the branch, unfixed and deliberate

The whole-branch review raised these; each was ruled deferred rather than guessed at. (The two
that have since CLOSED — the 49-character wall drum, owner-gated 2026-08-18, and the perf budget,
superseded by measurement 2026-08-17 — are off this page: the drum ladder's reasoning lives on
[[stats-room]] and in `FlapScheduler.luau`'s "WHY SMALLEST-FIRST" comment.)

- **Per-player stats fan-out is unbounded**: one `getStatsPlayer` per player every 60s, all in
  one tick, each triggering four Mongo aggregations. At 40 CCU that is a 40-request burst per
  minute against a 500/min HttpService budget, for a slip visible only inside one room. Gate on
  room presence, or spread the fan-out across the interval.
- **Join-time pushes can be dropped.** `StatsData`/`StatsPersonal` fire from `PlayerAdded`,
  which runs before the joining client's LocalScripts have connected. Worst case the personal
  slip shows zeros for up to 60s.
- **Two pollers both fetch `/leaderboards?scope=world`** (one every 30s, one every 60s), each
  deriving its own payload from it. Two cached GETs a minute — noted so it is not rediscovered.
- **`entryLine` truncates an overlong figure from the LEFT**, so a banked total past the column
  budget would render as a smaller wrong number rather than an overflow marker. Unreachable at
  current widths (needs ~1.2 billion banked).
- **Spec §6.2's "longest current streak" heat item** was substituted for points-earned heat.
  The data exists (`LEADERBOARD_FIELDS` carries `currentStreak`); the substitution is reasonable
  but was unlisted until now.

**What the walls read from** (all merged and live on dev): `/api/v1/stats/records|heat|player`
and the `get-stats-surface` socket event. Layout, visual language and the round band are already
specced in `docs/superpowers/specs/2026-08-16-stats-room-design.md` §6 — plan 3 implements that,
it does not redesign it.

**Constraints carried in:**
- `TextLabel.TextSize` caps at 100px and `TextScaled` does not reliably scale up on a SurfaceGui —
  use `BoardController`'s small-canvas-stretched-large trick or text is unreadable at distance.
- Per-viewer displays need NO new mechanism: a client-built SurfaceGui parented to a world part
  is already private to that client. Signpost personal vs public boards physically.
⚠ Both belong on [[misc-engine-traps]] rather than a status page; left here until someone
moves them, which is the accretion this page is trying to stop.

- **The karasu's two lid collars are welded to nothing** (found 2026-08-28). The body mesh is 8
  connected components; two are 120-vertex rings sitting on the eyes with 48 open edges each — 96
  of the body's 112 open edges. `build_lid_collar` was meant to bridge the eyeball's aperture to
  the head, but the eyeballs became a separate MeshPart, so the ring's inner edge has nothing to
  meet and its outer edge never merged into the skull. ⚠ Not currently visible: the main body is
  closed (0 open edges), so nothing renders see-through, and the balls sit tangent to the skull
  silhouette. Fix in `karasu_retarget.py`, then re-export and re-import all three. See
  [[familiars]] and [[blender-pipeline]].

- ⚠ **OPEN DECISION, OWNER DEFERRED 2026-08-28: how the karasu gets eyes.** Owner: *"I'm thinking
  this approach to eyes is a failure and we have to go back to square one"*, then *"we'll talk
  about this later"*. **Do not re-litigate or act on this without them.** The separate-MeshPart
  eyes are shipped and working as of `bf3591f`; four bugs were found in play, all in the placement
  code and all authored in one session, none of them the architecture.
  ⚠ **The finding worth keeping, because it invalidates the premise the separate part exists for:**
  "no per-texel roughness" is a property of the bird's CURRENT setup, not an engine limit.
  [[material-and-mesh-traps]] §8 records that ColorMap-ONLY SurfaceAppearance renders worse than
  none — and that 21 templates with a FULL PBR set were all correct. A `RoughnessMap` would let the
  eye be wet while the feathers stay matte, on one mesh, with the eye modelled into the body the
  way the uguisu's already is — deleting `KarasuEyes`, `makeEyes`, the offset, the frame-ordered
  write and both teardown paths. Costs: a complete map set (partial trips §8), the eye is 31 texels
  at the 1024 atlas so it may need 2048, and the feather look needs re-verifying.
  Three options were put to the owner: full PBR + eye in the body mesh; keep the part but re-export
  it unskinned; or pull the eye work entirely. See [[familiars]].

## MORNING AGENDA (owner, 2026-09-05 close): promotion worksheets, then Hanabiya shop dressing

Two threads named for the next session:

1. **Promotion worksheets** — get more shells into the shop. Outstanding verdicts from the
   vocabulary wave: wa, yashi, hotaru (with its canyon-sizzle tail), kamuro, ao (the blue
   pick), midori/murasaki (shape picks), dan. The pipeline is FIVE guarded steps now
   (catalog recipe + fixture id + server price/requirement + ShellDisplay + SHELL_MORTAR for
   gear shells — the last two both CI-enforced). Proving range is the audition stage;
   rail-mounted deck tubes are the buyer's experience.

2. **Hanabiya shop dressing** — owner: the shop is "nothing but a table and bare walls";
   wants box art and merchandising mocked up for the shelves. New art/design thread: shell
   packaging (each catalog shell as a boxed product — name, hue, style iconography),
   shelving/wall treatment for the interior ([[hanabiya]] has the as-built), possibly tying
   box art to the ShellDisplay metadata so a promotion dresses its own shelf. Nothing
   designed yet; classify (likely brainstorm -> spec) at session start.

Context that survives the night: rail mounts GATED with wobble+break ("perfect, looks
great"); place save/publish still pending (unlocks the same-server rejoin verification);
parked defects (i)-(k) untouched.

## The onboarding JOURNEY — a crafted path an 8-year-old can walk (owner, 2026-09-05)

**STATUS: IN EXECUTION as of 2026-09-03** — supersedes "queued for AFTER the fireworks
sprint" below. Spec `docs/superpowers/specs/2026-09-03-onboarding-journey-design.md` and
plan `docs/superpowers/plans/2026-09-03-onboarding-journey.md` are written and built: the
8-beat chain, 3-page welcome, TourGuide/TourStep advance-through, inventory-edge events,
TourBeamController, the TourModelPadId model-pad claim, and the starter SKU (20 pts).
Open gates before this closes: the **copy workshop** (the vocabulary rewrite this section
was written to demand — beat copy still leans on "pot"/"ride" gambling terms pending the
kid-legible pass) and the **owner's cold phone walk** (an unrehearsed run-through on a
phone, unscripted).

Owner direction, verbatim intent, originally queued for AFTER the fireworks sprint: the
current beat copy is correct "but only if you know what a 'pot' or a 'ride' is. These are
gambling terms -- fine -- but Roblox is, first and foremost, a kid's environment so we need
to be thoughtful and precise in the journey we're taking them on as we answer the most
important questions: what is this place? How does it work? What can I do? What makes it
special? The onboarding path needs to be so smooth that even an 8-year old can do it."

This extends the standing no-sports-book-language rule into the onboarding voice, and it is
a JOURNEY design (sequence, pacing, vocabulary, the four questions above), not a copy edit.
~~The copy/vocabulary pass itself is still to be crafted~~ **DONE 2026-09-03**: the
copy workshop ran owner+Claude in-session. Owner wrote the four-page welcome, the win
beat (teach-then-use POT — the vocabulary guard narrowed to the wager class
ride/stake/wager/bet, rationale in `tests/OnboardingBeats.spec.luau`), the bank beat
(+ kept clock-gesture sentence) and tour cards 8–10; Claude's drafts stand for the
throw beat, the model-home close and the shop strings ("good for now"). Route rulings
the same session: launch stop = a NEW 4th public site at the **FW11 Switchback Deck**
(with a `FireworkTubeMount` rack), model pad = **T13** (owner stood on it), hanabiya
stays the shop stop for the demo.

## Onboarding: replayable journey + teahouse/stats beats (owner, 2026-09-03, banked mid-cold-walk)

Two extensions the owner named while walking the journey cold:

1. **Optional reset/re-run of the onboarding path** — "an option we'd place somewhere on
   a config screen." Mechanically cheap on the surface (clear the profile's `seenBeats`
   and the tour re-derives from empty — TourGuide has no state of its own), but it needs
   a config-screen HOME first (no settings surface exists in the Roblox client today) and
   a ruling on what reset does NOT touch (points/property stay; the starter prompt won't
   re-offer to an owner, so a replayed tour ends on a pitch the player can't buy —
   acceptable? copy fork?).
2. **The journey never teaches the teahouse panel or the stats surfaces** — no beat
   covers the ledger/stats dialogs or the teahouse management panel (B3), so those ship
   as discovered-not-taught. New beats need their trigger moments chosen (first panel
   open? first pad claim?) and kid-clean copy — a copy-workshop item, owner+Claude.

Both queued behind the demo; neither blocks the walk.

## Rack-as-shop at the Switchback Deck (banked 2026-09-03)

Owner direction, deferred past the F&F demo by the owner's own "hanabiya for the
demo" ruling: *"the launch rack tied to it [the Switchback Deck] will be the
fireworks shop"* — a purchase surface AT the rack, so buying and firing happen at one
dramatic stop and the tour could collapse shop+launch into a single climb. Needs a
buy prompt/panel on the rack wired to the existing `RequestPurchase` flow (today the
hanabiya is the only shell-purchase surface). Shape when taken up: brainstorm → spec
(it interlocks with the shop-dressing/box-art thread — what does a rack SELL, shells
or boxes?).

## Tunnel lighting pass (banked 2026-09-03)

Owner observation at the T13 tunnel branch: "Tunnels seem to be self-lit — is that a
setting? It would be more interesting visually if we actually put lights in them."
Diagnosis: yes, a setting — `Lighting.Ambient`/`OutdoorAmbient` fill enclosed spaces
uniformly (ambient is not occluded; the day/night controller moves ClockTime only and
deliberately never touches Ambient). Making tunnels genuinely dark means lowering
`Ambient` toward black — at which point they need PLACED light, which is the owner's
instinct anyway. Shape when taken up: an art pass — yamadoro/chōchin recipes exist;
tune Ambient + place fixtures per tunnel, judged at the dusk lock (and again against
the natural cycle if the day lock is ever cleared). Interlocks with the parked
firebox/care-gradient thread on the yamadoro item above.

## Fireworks monetization vocabulary: boosts standard, surprises typed, mystery + bundle SKUs (owner, 2026-09-05)

Rulings from the wa worksheet session, shaping everything downstream:

1. **The boost package is the STANDARD shape for most fireworks**: a quality floor with an
   occasional "surprise and delight" (the kiku 30%-class luck design generalizes).
2. **The surprise VARIES BY TYPE** — e.g., a blue ending burst instead of white, or a loud
   bang at the end. Each family's promotion verdict should pick its own surprise.
3. **Salutes are a missing vocabulary class**: "we haven't built any big bright single or
   multiple bangs yet" — big flash+boom shells (single salute, multi-salute finale crackle)
   are a planted wave-2 style, AND the raw material for bang-type surprises.
4. **Mystery shells**: relatively inexpensive, reasonable price, ALWAYS a surprise and NEVER
   a disappointment when consumed. (Design note: "never a disappointment" is a content-floor
   constraint, not just randomness -- the pool must contain only delight.)
5. **Mystery boxes**: purchasable containers holding random firework assortments.
6. **Firework boxes**: clearly identified contents at a bundled price. Interlocks directly
   with the Hanabiya box-art/merchandising pass (the box IS the shelf product).

## Toolbox idea: mid-life color shift (owner, 2026-09-05, from the wa worksheet)

The blue-edge surprise candidate was rejected at the range ("blue is unreadable" as an edge
tint); owner: "you're going to have to do it halfway through" -- i.e., the burst blooms in
its base color and SHIFTS hue partway through the burn. Needs a color-over-life override
knob in the recipe/controller (the current ramp is style-fixed: white ignition -> color ->
ember -> black). A natural surprise flavor for the hue families (ao/midori/murasaki) if
they become colorways, or for any shell whose "different ending color" surprise should read
clearly. Not built; banked.

## Economy tuning, drops, return rewards, Robux (owner, 2026-09-05)

Direction banked from the wa promotion session; none of it is build-now:

1. **Prices and levels are provisional** -- tuned later "when we get a better feel for
   things." Nothing in the current point prices is sacred.
2. **Random shell DROPS for wins** -- winning can gift a shell.
3. **Return rewards**: coming back on subsequent days earns something -- "a different kind
   of streak" from the in-round one. Vocabulary note: keep the two streaks legibly distinct.
4. **Session rewards**: staying long enough matters -- e.g., a reward at 10 throws in a visit.
5. **Everything sells for Robux** ("obviously") -- extends the standing Lens B ruling
   (2026-07-20: points buy everyday shells, Robux buys premium/finale; Developer Products,
   grant only in server ProcessReceipt) from premium-only toward the full catalog.

Interlocks: drops and return rewards are delight-delivery channels for the mystery-pool
rule ("never a disappointment"); all reward framing must clear the onboarding voice ruling
(kid-legible, no gambling vocabulary -- a drop is a GIFT, not a jackpot).

## Firefly swarm shows (banked 2026-09-06)

**Owner ruling:** fireflies are coming as AMBIENCE, and the swarm-display system is an
EXTENSION of that system -- "something we can occasionally turn into a display" -- not a
separate drone machine. The insight that seeded it: a swarm solves what particle bursts
cannot (owner: "there's a different way to skin that cat... a drone swarm" -- per-entity
POSITIONS, so arbitrary imagery becomes a point cloud), and the firefly theming keeps it
native to the canyon where literal drones would not be.

**Shape when taken up (brainstorm -> spec -> plan):**
- One pool serves both modes: ambient drift (the default, always alive) and FORMATION
  (borrowed for shows, returned to drift after). Anchored Neon parts, BulkMoveTo batched
  -- cheaper than particles, no additive pileup; budget/LOD via a director like fireworks.
- The hard system is the FORMATION COMPILER: image/text/shape -> point cloud -> drone
  assignment (nearest-match so morphs look intentional) -> timeline. Formations morph;
  that is the show.
- Face shows: EditableImage samples an avatar headshot into ~200 points -- the workable
  "kao" (the particle face-burst was assessed 2026-09-06 and rejected: emitters cannot
  place individual particles).
- Monetization interlock: the banked "shared show" SKU (buy the whole server a finale)
  is made for this; the personalized face show sits above it as ultra-premium.
- Interlock: hotaru is already the shelf's firefly (蛍); naming/lore should connect.

## Rooftop MC experience (banked 2026-09-06)

**Owner design:** players will "buy or win access" to the Hanabiya rooftop battery and
"a proving-ground-like console that lets them MC some fireworks until they're out of
time or points. It will be a peak experience in the place." Access likely a ladder
climbing through the roof onto the platform -- NOT built yet, deliberately, so access
stays gateable; the platform's back-rail gap (x 5.5..9.1) is the reserved hatch spot.
The platform (assets/HanabiyaRooftop.model.json) is sized for 3 players + a console
footprint + the three-tube battery. The proving panel's mode set (Fire/Ladder/Seq/
Boost, 2026-09-06) is the natural seed for the MC console's verbs.

## Public station access via play queueing (banked 2026-09-06)

**Owner:** the five scattered proving stations ("north arena", "bridge", "upper north",
"mid pool", "hi west") are Studio-only today, but "in future we'll offer some kind of
public access to them, probably involving something like jukebox play queueing" --
players queue shells at a station and the station fires them in order. Interlocks with
the rooftop MC experience (same fire-things-from-a-console family) and the shared-show
SKU. Station orientations are owner-aimed launch headings, already honored by the fire
path.

## Horizon backdrop — trial in Sandbox, promotion open

The mountain ranges outside the terrain box ([[horizon-backdrop]]) are built and owner-approved
as a direction ("pretty good, let's run with that for now", 2026-09-03) but still live in
`Workspace.Sandbox.SkyBackdropTrial`. Open before it is shipped content:

- **Promote out of Sandbox** into a `CanyonWorld` home and retarget the builder's root; the
  Sandbox convention on [[place-state]] says prototypes only.
- **Preload the six range meshes at join** (`ContentProvider:PreloadAsync` on the builder's
  `MESH_IDS`) so the horizon is there before a new player looks up — assets load near-to-far,
  which puts the ranges last.
- **Variety**: the owner found the six strips "a little bit the same". More seeds, or
  mirroring alternate placements, is a one-line change in `backdrop_ranges.py` plus one
  re-import.
- The near ring cannot come closer without its footprint crossing the terrain box; if "too
  far" comes back, the lever is letting the low aprons run under the plateau, which needs a
  height-aware intrusion check instead of the corner check.

## Low-end device tier — PARKED (owner, 2026-09-03: "hold on this for the moment")

Owner's prompt: in its current form Roshambo "absolutely hammers my iPhone 15, hard on the
battery, generates heat". Question was how practical a radically more efficient version is and
how much of it needs the owner.

**Shape ruled in the discussion: a device TIER inside the one place, not a second experience.**
Roblox ships one build per experience; a lite place would split the player base and "you
against the world" needs everyone in one round. The engine's own Graphics Quality (player-chosen
in the escape menu, Automatic or 1–10; readable via `UserGameSettings.SavedQualityLevel`, never
settable by us) already scales rendering. What it cannot touch is what we authored, which is
where the heat is:

- particle emitters: the 135 water VFX objects ([[day-night]]), the fireworks pool, mist
- post effects on `Lighting`: SunRays, two Blooms, DepthOfField, two ColorCorrections
- instance counts: 3,580 foliage MeshParts at the 2026-08-05 audit ([[foliage]]), the
  [[horizon-backdrop]]
- per-frame client loops: birds, day/night subscribers, water dim, glyph neon, HUD

**How a tier would work**: a client-side decision at join about what to enable — emitters,
post effects, bird count, streaming radius, loop tick rates — so the server stays one world.
Default from auto-detect (touch without keyboard, as the HUD's touch tier already does; saved
quality level; total memory; a frame-time sample over the first seconds), with a player
"Performance mode" override in our settings, persisted, because auto-detect misreads tablets
and gaming phones both ways. Precedent: the PWA's LITE/FULL/ULTRA visual tiers ("Data Thrift").
⚠ Tiering hides and disables; it does not un-send. Replicated instances still reach a phone
unless the streaming radius keeps them out — memory wins come from streaming, heat wins from
what stops rendering and ticking.

**What needs no guidance** (a couple of sessions): profile on the phone first (MicroProfiler),
build the tier switch, gate the list above behind it, throttle per-frame loops to 30 Hz.

**What needs owner rulings** — short yes/no gates, not open design: fireworks on a phone (half
the stars vs the full show at a lower rate); water (static + foam vs motion at lower rates);
lanterns and glyphs (glow kept vs flat); backdrop (kept vs a painted skybox on the low tier
only).

**Honest ceiling**: an iPhone 15 warms up on a bare baseplate at 60 fps. The reachable win is
roughly halving what we ask of it, not a cool phone. The biggest battery lever is the frame-rate
cap in Roblox's own settings, which belongs to the player.

