---
shelf: program
status: open
updated: 2026-08-16
---

# Backlog

Future work captured with enough context to restart cold. Nothing here is scheduled; the
active program is [[friends-family-baseline]]. Ordering within this page is arbitrary.

## Teahouse access control — core SHIPPED, extensions remain

The core feature shipped and was 2-account-validated on a published server 2026-07-19/20
(`deec13c..7d36e59`, perimeter+beacons `cd4dbfa`, join-race fix `c5bf33c`): per-player
Public / Friends / Private modes, invite-by-username resolved to persisted userIds (cap
50), hybrid enforcement (client-local noren gates + authoritative server region backstop
with eviction). The old "NOT built" backlog note is superseded by that ship. Still
deferred from it: guest passes / portal-to-a-friend's-teahouse (the `canEnter` seam is
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

Shipped 2026-07-13..20: B1 player back door, B2 size economy, B3 management UI, B4
repositioning, per-uid handler serialization (`ce7c34d..0f37e2d`), the deck-decoration
framework (`37e8e12..0d2fc9a`), the Home Portal MVP, and access control (above).
Remaining Piece B: decoration catalog expansion (swap-skinning — colorScheme / shoji /
tatami / flags / wallArt; teahouse-anchored props needing S/M/L anchor slots; banner /
noren / maku slot content; collidable/sittable props; partial refunds; multi-pad
decoration memory), teahouse floors, the fireworks-battle / valley-as-secondary-arena
flex layer, and spawn-at-teahouse (above). Constraints that still govern: split
Roblox/PWA economies, points-only v1, teahouse ≤ deck, the deck is a yard.
Raw layer: `docs/superpowers/specs/2026-07-05-roshambo-structure-builder-design.md`
(`7e2eca6`) and the 2026-07-13..19 specs/plans (b1/b2/b3/b4, home-portal,
deck-decoration-framework, teahouse-access-control) under `docs/superpowers/`; ledger
`.superpowers/sdd/progress.md`.

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
`socketAdapter.ts:169-170` vs `:283-284` — if the socket drops while `sync-player` is awaiting
`resolveUser`/`openSession`, the disconnect handler runs first and finds no `sessionId`, then
the sync handler registers a heartbeat for a dead socket. That entry refreshes `lastSeenAt`
forever, so it would defeat follow-up (1) as well as growing the `Map` unbounded over process
lifetime. A `socket.connected` check before `heartbeats.set` closes it.

**Operational note for whoever deploys this:** removing `index: true` from a Mongoose schema
does NOT drop an index already built in a live database. If `roshambo-dev` or `roshambo` has
already created `userId_1` on `sessions`/`bankevents`, it persists until dropped by hand or by
`syncIndexes()`. The write-cost saving is only realised on fresh collections.

## ~~⚠ SECURITY — the `get-stats` socket handler broadcasts deviceIds~~ FIXED 2026-08-16

Found by the plan-2 whole-branch review, 2026-08-16. **Pre-existing; not introduced by that
plan, and deliberately not fixed by it.**

`server/src/transports/socketAdapter.ts`'s `get-stats` handler emits `topByCareer` with the
default `LEADERBOARD_FIELDS`, which **includes `deviceId`**, and emits unprojected `PlayerRound`
documents as `biggestWins`, which carry it too. A `deviceId` is a **bearer credential** on the
socket path: `sync-player { deviceId }` grants that account with no further auth.

So any connected socket can call `get-stats`, harvest roughly a hundred other players'
deviceIds, and then assume those accounts. No authentication at any step.

This is the exact credential the plan-2 stats surface works hard to contain — `nameUsers`
returns `Map<string,string>` precisely so a future field cannot leak — and that discipline is
moot while the handler beside it hands the same credential to anyone who asks.

**Why it was not fixed inline:** `src/components/StatsView.tsx` uses `deviceId` as a React key,
so removing it from the payload is a cross-tree change to the PWA, not a server-only edit. It
deserves its own decision rather than being smuggled into a stats plan.

**Fix sketch:** give the socket path its own projection without `deviceId` (the API path already
has one, `API_LEADERBOARD_FIELDS`), project `biggestWins` explicitly rather than emitting whole
documents, and switch the PWA's list key to the user id. Do it **before plan 3 ships a room that
advertises these boards** and drives traffic to them.

## Stats surface (plan 2) — notes carried out of the merge

Plan `docs/superpowers/plans/2026-08-16-stats-surface.md` shipped 2026-08-16. Nothing blocking;
these are things a later reader would otherwise have to rediscover.

- **`/api/v1/stats/records?window=all` emits a `to` 24 hours in the future.** Plan 3 must not
  print that bound verbatim or "All time" will read as ending tomorrow. It is labelled
  `windowKind: 'rolling'` because the bound genuinely moves per request — `'calendar'` would be
  a lie — but the label is imprecise and the echoed `from`/`to` are the honest signal.
- **The two transports disagree on shape for the same boards.** REST resolves `displayName`;
  the socket surface still emits raw `userId` ObjectIds. `nameUsers` is private to
  `statsV1.ts` — export or relocate it before plan 3 duplicates the projection in
  `socketAdapter.ts`, which is exactly how deviceId leaked the first time.
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

## ⚠ SECURITY — socket handlers trust a client-supplied `deviceId` as authentication

Split out of the `get-stats` broadcast fix (2026-08-16), which closed the *harvest* but not the
*authentication gap underneath it*.

Four handlers in `server/src/transports/socketAdapter.ts` resolve an account directly from a
`deviceId` in the client's own payload, with no further check:

- `sync-player { deviceId }` — reads the full account
- `submit-throw { deviceId }` — throws as that account
- `bank { deviceId }` — **cashes out that account's pot**
- `update-progress { deviceId, displayName }` — renames that account

So anyone who obtains a `deviceId` by any route has total control of that guest account. The
board no longer hands them out, but a deviceId also travels in localStorage, in support
screenshots, over shoulders, and in any future payload someone adds without thinking.

Contrast `userId`, which is set from a JWT-verified handshake (`socketAdapter.ts:51-55`) and is
NOT client-injectable — that asymmetry is the whole problem: one identity path is authenticated
and the other is a password sent as a parameter.

**Why it was not fixed with the broadcast:** it is a substantially bigger piece of work
(guest-session authentication) and touches every socket handler plus the PWA's connection
lifecycle. Removing the broadcast was the cheap half and stood alone; this does not.

**Fix sketch:** on first `sync-player`, mint a signed session token bound to that deviceId,
return it, and require it on every subsequent mutating event — so the deviceId identifies and
the token authenticates. Guests keep working without an account. Do this before the game is
public; it is currently a total-account-takeover primitive for anyone who learns one string.

## Plan 3 — the Stats room displays (NEXT, not yet specced)

Decided 2026-08-16; the spec and plan do not exist yet. Everything needed to write them:

**Scope, and the owner's ruling on shape:**
- **Fold the `BoardController` retarget INTO plan 3** (owner, 2026-08-16) — do not spec it
  separately. `roblox/src/client/BoardController.client.luau` has no-opped since the jumbotron
  was removed (T23): it early-returns because `Workspace.RoshamboStage.JumbotronBoard` does not
  exist. `FlapScheduler` is intact and ready (drum carries `-:/`, nine-step cap, `0b41f83`).
  The renderer needs a home on the kōsatsu boards before any wall can render.
- **Displays first, data later** — build against seeded fixtures in Studio rather than waiting
  for real play. Layout and legibility are what the owner judges, and known-good fixtures are
  easier to assess than sparse real numbers. ⚠ NOT YET CONFIRMED by the owner; proposed and
  interrupted. Confirm before building.

**What the walls read from** (all merged and live on dev): `/api/v1/stats/records|heat|player`
and the `get-stats-surface` socket event. Layout, visual language and the round band are already
specced in `docs/superpowers/specs/2026-08-16-stats-room-design.md` §6 — plan 3 implements that,
it does not redesign it.

**Constraints carried in:**
- `TextLabel.TextSize` caps at 100px and `TextScaled` does not reliably scale up on a SurfaceGui —
  use `BoardController`'s small-canvas-stretched-large trick or text is unreadable at distance.
- Per-viewer displays need NO new mechanism: a client-built SurfaceGui parented to a world part
  is already private to that client. Signpost personal vs public boards physically.
- The socket surface returns raw `userId` ObjectIds with no names, unlike REST — export
  `nameUsers` from `stats.ts` rather than duplicating the projection in the client path.
- Boards will be EMPTY until people play: `StreakEvent`/`BankEvent` start from deploy, no backfill.
