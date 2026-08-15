---
shelf: program
status: open
updated: 2026-08-15
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

## Canyon path railings & chōchin — superseded as a to-do

A stale "resume Task 1" note survived in memory; git shows the work done: bamboo railings
deployed on all canyon paths (`d247a2e`) and chōchin poles per-path including DescentPath
(`5d1a21e`), confirmed 2026-06-29..07-01. Residual open thread only: the remaining
`Bridge*` markers in `PathDraft` (⚠ unverified — place-state).

## Yamadoro trail lighting — placed; lighting decisions open

Six yamadoro are placed along the river trail with coordinates baked (`0c8f362`,
`roblox/tools/studio/placeYamadoro.luau`; models re-homed to
`ServerStorage.YamadoroLibrary` — ⚠ unverified, place-state), and night has an ambient
floor (`17bbb08`). Open: the firebox — the owner chose bind-to-`nightFactor` when this
was still a yukimi question, re-confirm before wiring (no firebox-lighting commit found);
the three-register care-gradient idea (built fixture → set stone → no fixture westward)
was proposed, never decided — stone underlighting, moss glow, and hotaru all remain
unchosen; model compromises to revisit only if it reads machined in place (timid
displacement, no lichen, faceted roof eave).

## PWA throw-drum replica — parked idea

From the F&F baseline: a working replica of the arena's throw drum on the PWA. The PWA is
otherwise out of F&F scope (showable as-is).
