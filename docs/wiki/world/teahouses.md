---
shelf: world
updated: 2026-08-18
---

# Teahouses

Teahouses are **portable, player-owned loadouts** the server materializes onto
walk-up pads — not fixed buildings (the 2026-07-05 pivot). A player starts as a
wanderer; a place of operations is earned. Customization is curated catalog
components filling named slots — never raw materials, never free-form building. The
runtime spine (sub-projects A–E) is committed under `roblox/src/shared` and
`roblox/src/server`; the prefabs live in the place.

## The runtime spine (as built)

- **A — structure builder**: `StructureCatalog` / `StructurePlanner` (pure) /
  `StructureBuilder` (`47b8057..3f718ad`). Datum contract: structure ends at Y0 =
  floor underside; nothing below; `MirrorX` part tags + `MirrorXRigid` model tags
  replace geometric reflection (roof wedges flip wrong).
- **B — pads**: `PadPlanner` / `PadBuilder` / `PadRegistry` (fit-aware `claimVacantFor`,
  `810fb1f`) / `VacantState` (vacant cliff = dark shuttered shell, chōchin removed;
  valley = garden marker). Deck railing/fall-guard geometry in `src/server/PadOps.luau`.
- **C — persistence**: Mongo via `/api/v1` (`server/src/routes/apiV1.ts`,
  `server/src/loadout.ts`) — players own multiple teahouses keyed by size class;
  co-located with the points economy for atomic spend+grant (DataStores rejected).
- **D — assignment**: ephemeral per-server pool — join → claim a fitting site →
  materialize the persisted loadout → release on leave. `SiteCoordinator` (pure) +
  `TreatmentApplier`; D.4 (`98debd5`) reframed pads as **sites** ({mountCF, maxSize,
  vacantForm}) with **dynamic posts** built per-occupant from ground raycasts —
  perches are cliff shelves set into the hill, so support is never the blocker; size
  is capped by uphill clipping. `SizeClasses` S/M/L; the place now holds **three
  authored per-size prefabs** `ServerStorage.StructurePrefabs.teahouse-1story-s/m/l`
  (verified 2026-08-15 — the earlier single-prefab scale proxy is superseded).
- **E and the rest of Piece B** (management UI, back door, decorations, Home Portal,
  access control) shipped 2026-07-13..20 — statuses and remainder on [[backlog]].
- **Teahouses do not exist in Edit** — they materialize at runtime from loadouts.
  Tools must use `ServerStorage.Sandbox_PARKED.PadRefs` / `PadSites.deckPlacements`.

## Deck fall-prevention (settled 2026-07-13)

- Railings on front/left/right; **back edge open** (path access; `3f95641`).
- Visible railings are **collidable and raised** (+0.5, cap top 2.75); the deck slab
  is collidable including the cantilever (`0d15d27`, `26a9311`).
- A **low (3.5) invisible continuous fall-guard** sits flush behind each railed edge
  (`31ce54b`) — required because spaced balusters let the avatar auto-climb over; a
  smooth wall gives it nothing to mantle. Rationale: no fall damage by default, so
  stop *accidental* walk-offs only — a deliberate leap into the gorge still works,
  decks stay open (fireworks launch from decks, client-side VFX pass through
  regardless). **Do not resurrect tall imprisoning walls**; if the guard feels
  grabby, tune `BARRIER_H` — it is a pure physics number.
- The `EngawaBarrier` collision group (blocks players, passes `Projectile`) is
  registered in the place, not by repo code — verified present 2026-08-15
  ([[place-state]]).

## The design language

Locked kake-zukuri prototype (2026-06-15/20, exhaustively owner-reviewed): irimoya
two-tier roof with mitred trapezoid skirt panels, glowing shoji (translucent ivory +
Neon glow + contained PointLights), 8-stud wrap engawa with flush kōran, black
(45,48,56) understructure and rail caps, hanging chōchin (SpecialMesh-sphere oblong —
the reusable round-lantern primitive), 6-post perimeter frame raycast to terrain.
Recipe script `tools/studio/teahouseUpgrade.luau` (`9e4717f`) was the source the
prefab was captured from (`captureTeahouseBase.luau`).

## Sliding shoji (shipped 2026-08-18)

Every shoji bay's leaf now slides in its own channel, authored onto the place by the
idempotent, re-runnable `roblox/tools/studio/trackShojiBays.luau`: groove `i` of an
N-bay run sits at `wallPlane + (i - (N+1)/2) * 0.20`, centred on the wall's mid-plane —
the panels described under "The design language" below stayed the same width and
shape, they only gained a track to move in. Rails deepen to `N * 0.20 + 0.16` per side
to span the groove stack; on the L (4 bays) that puts the sill about 0.28 studs proud
of each wall face, a threshold the owner accepted by looking at an L teahouse
(2026-08-18, place saved).

A screen slides by holding a `ProximityPrompt` (key `G`; `E`/`F` are the Favorite and
back-door prompts already on the same building) at roughly a bay-width per 1.2s, in a
direction latched when the hold begins. **A screen clamps only to its run's ends** — no
per-screen travel cap — so a whole run can stack into a single bay, and that bay may be
any bay on the wall. The fullest opening is therefore N−1 bays: 18 of the L's 24 feet,
12 of the M's 18, 6 of the S's 12.

The server owns every position: `ShojiOpen` is the target clients tween toward,
`ShojiApplied` records where the server's own collision geometry actually sits (read
once by a joining client to derive that screen's home pose). Both are attributes on the
bay model. Prompts and hold acceptance are gated on a `BayState` attribute stamped by
`applyBays`, so a solid wall or a back door offers no prompt. Run membership and saved
`shojiOpen` indices are a separate count — every bay that COULD hold a screen — so
toggling a bay between solid and shoji never renumbers a player's saved positions.

**The owner's slides persist; a visitor's do not.** The owner's positions ride the
existing loadout PUT into `shojiOpen`, a per-side array of travels validated
server-side (`validateShojiOpen`). A visitor's slide is live for everyone present in
the house and gone at the next materialize.

The swappable variant slot the F&F item asked for was already built before this item
started: `shoji` is in `LOADOUT_KEYS`, `StructureCatalog` carries `shoji.plain` and
`shoji.crane`, and `StructurePlanner`/`StructureOps.setTexture` resolve and apply them.
Both entries still point at placeholder asset ids and nothing in game lets a player
choose between them — that is catalog and management-UI work, tracked on [[backlog]].

All the arithmetic — clamping, groove placement, direction, run axis, ordinal mapping,
quantisation — lives in `roblox/src/shared/ShojiRun.luau`, Lune-tested.

## Legacy

The 14 hand-placed `CanyonTeahouses` froze as legacy at the pivot and have since been
**retired out of Workspace**: `CanyonWorld.Legacy` is empty in the live place and a
`ServerStorage.RetiredLegacyTeahouses` folder exists (both verified 2026-08-15).
CLAUDE.md's "Legacy holds the frozen 14" note is stale against the live place.

## Gates & decisions

- 2026-07-05 owner approval of the pivot; discrete authored tiers (entry tent →
  1-story → multi-story), approach A, not procedural stacking.
- 2026-07-05 access decision: players **walk** to pads; access infrastructure is
  hand-built per site with the existing recipes — no automated access-building
  system. Occupancy-conditional access objects captured as a future hook.
- 2026-07-13 fall-prevention reversal on real testing (visible-railings-only failed —
  walk-through, fall-through, climb-over each forced a change).
- D.6 curation note: a site's real max size = min(terrain-max, spacing-max) — bigger
  footprints can encroach on neighbours' access.
- 2026-08-18 owner gates on sliding shoji: the channel geometry ("sills on L teahouse
  look fine", place saved) and the play loop ("looks good" — prompts, slide, stacking,
  direction).

## Raw layer

- specs: `2026-07-05-roshambo-structure-builder-design.md` (`7e2eca6`) + the pad /
  registry / vacant-state / fit-aware / loadout-persistence specs of 2026-07-05;
  sliding shoji: `2026-08-18-shoji-screens-design.md` +
  `docs/superpowers/plans/2026-08-18-shoji-screens.md`
- key commits: `47b8057..3f718ad` A · `810fb1f` B fit-aware · `c8d53d3..5d9433b` D.1 ·
  `7593a3c` D.2 race fix · `c89221b` D.3 · `98debd5` D.4 sites + dynamic posts ·
  `3f95641`/`0d15d27`/`26a9311`/`31ce54b` deck safety · `021d745..95375f3` sliding shoji
