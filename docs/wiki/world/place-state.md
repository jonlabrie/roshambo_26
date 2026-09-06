---
shelf: world
updated: 2026-09-05
---

# Place State

The page for what git cannot see. Rojo manages exactly what `default.project.json`
names — `Workspace.RoshamboStage`, **and since 2026-08-26 `ReplicatedStorage.RoshamboBirds`
too** ([[familiars]]) — and nothing else; all other Workspace content is place-only,
organized by lifecycle (`CanyonWorld` shipped, `Sandbox` throwaway). Ship by
**publishing/saving the place, never `rojo build`** (a build emits only the declared
children and drops all place-only content). CI fails on any committed `.rbxl(x)`.

⚠ **Authority is [[rojo-and-place]], NOT `CLAUDE.md`.** This line used to name CLAUDE.md
first, which inverts the hierarchy: CLAUDE.md's own banner says it is orientation and not
authoritative for repo or system state, and it has been wrong about this very subject — it
still said "7 hero-prop models" when the declaration held 19 children. Corrected 2026-08-27.

Everything below marked *verified* was checked live via the Studio MCP on 2026-08-15
(Edit mode, place "Roshambo").

## Publish checklist

0. **Ambient tuning attributes: all four must stay UNSET for a normal publish.**
   `AmbientRadius`, `ArenaRadius`, `AmbientHz`, `AmbientBehindDot` — unset means the code
   defaults (180 / 450 / 30 Hz / −0.15) apply. Set values are for live tuning during a walk
   only, and a stale one silently reverts part of the load-reduction work while the wiki
   claims it shipped. **Verified all four unset 2026-09-05** after the A/B below was parked.
   The 2026-09-05 A/B (`AmbientRadius`/`ArenaRadius` 100000, `AmbientHz` 240, plus a
   `PerfABActive` marker) disabled culling and throttling to test whether they caused the
   A13 regression; it was cleared the moment its reading was taken
   ([[perf-harness-contamination]] rule 1).

1. **For the demo window** (F&F-demo exception, owner ruling 2026-09-03, spec
   `docs/superpowers/specs/2026-09-03-onboarding-journey-design.md` §7): publish with
   **`Workspace.DayNightLockT = 0.40`** — the documented dusk knob (see
   `docs/wiki/world/day-night.md` for the dawn/day/dusk/night bands; 0.40 is the
   sanctioned dusk value) — because the onboarding journey ends on a firework, and a
   noon sky kills the payoff. **Post-demo default**: `DayNightLockT` must be at 0.19
   (the daytime working value) or cleared — never publish a dusk/night lock outside
   the demo window. This resolves the ⚠ OPEN QUESTION below **for the demo period
   only**; the post-demo default remains open.
   **Set 2026-09-03 via MCP: `DayNightLockT = 0.40`** (was 1.19; superseded that day's
   earlier verification), `DayNightStartT` cleared. ⚠ OPEN QUESTION (owner, 2026-09-03, deferred:
   "leave it for the moment, we'll discuss in a bit"): whether the published game
   should keep a day lock at all past the demo — the owner noticed "the day night
   cycle doesn't run, even in play" as a surprise, and fireworks/hotaru/the whole
   shell shelf are judged against a dark sky. Clearing the attribute restores the
   epoch-anchored 10-minute global cycle.
2. Run `roblox/tools/studio/verifyWorkspaceConvention.luau` in Studio.
3. ⚠ **Scan any newly imported toolbox/marketplace model for a require-backdoor** —
   [[toolbox-backdoor-scan]]. **This checklist is the ONLY place that can catch one**: the
   2026-07-08 `VibrantNature` payload carried `if RunService:IsStudio() then return end`, so it
   is dormant in Studio and in Play-test and fires only on a live published server. That page
   has said since it was written that the scan "belongs in the pre-publish checklist on
   place-state"; it was not here until 2026-08-27, which is the whole reason to write a
   cross-reference down on BOTH ends.
4. Save/publish the place after ANY place-only work — a session's live edits are
   worthless until saved.
5. Onboarding tour stops (spec `docs/superpowers/specs/2026-09-03-onboarding-journey-design.md`):
   the markers are built by `roblox/tools/studio/tagTourStops.luau` (dedicated invisible
   parts under `Workspace.CanyonWorld.TourStops` — never a tag on rebuilt or Rojo-managed
   geometry, same rule as `tagLaunchSites.luau`'s header). **Done 2026-09-03 via MCP**:
   `TourStop_Shop` at the hanabiya, `TourStop_Launch` at the FW11 Switchback Deck (the
   owner's pick over the Overlook — the tour's launch stop, a new 4th public launch site
   `Site_SwitchbackDeck` added to `tagLaunchSites.luau` the same day, with a
   `FireworkTubeMount` rack from `buildSwitchbackRack.luau` under
   `Workspace.CanyonWorld.SwitchbackRack`). `TourStop_Model` is **not** a hand-tag —
   the server tags the runtime-built model pad's `PadDeck` itself at boot (the
   `TourModelPadId` block in `main.server.luau`), because that site is also
   runtime-built and the same rule forbids tagging it by hand.
6. Set the `Workspace.TourModelPadId` attribute to the model pad's `T##` id — this is
   what lets the server find and tag that pad's `TourStop_Model` automatically at
   boot; there is nothing further to do for that stop. **Set 2026-09-03: `T13`**
   (owner stood on it in Play and chose it — "a logical progression up the path from
   the Switchback Deck where they'll be launching their first firework").

## Workspace (verified 2026-08-15)

- `RoshamboStage`: Waterwheel, Overlook, ThrowDrum, Hanabiya, Karesansui, BonshoRig,
  SwitchbackDeck, BellDrive, FallsDock, BonshoBell, Torii, Shoro, ArenaSpawn,
  ShoroRoof, RanmaCarvings — matches the Rojo declaration; the once-noted stray
  top-level ShoroRoof/BonshoBell dupes are gone (0 found). Since 2026-08-15 the
  declaration has also gained MachiyaApparel, MachiyaAccessories, MachiyaStats and
  **Chaya** ([[chaya]], saved 2026-08-17) — a new stage child needs a Rojo RESTART, not
  just a plugin reconnect, because `rojo serve` reads the project file once at startup.
- `CanyonWorld`: Arena (incl. `W##_*_Rocks/_VFX`, `FallsLanding`), Paths
  (`PathRailings` 5,186 descendants, `PathLanterns` 2,599), Structures (incl.
  `Chochin_Hanabiya`), **Legacy (empty — the 14 legacy teahouses were retired to
  `ServerStorage.RetiredLegacyTeahouses`)**,
  Foliage (Heroes, Preserve, ShoreRocks, ArrangementsDraft ×22, EastBackdrop), Water
  (runs + `FallsAudio` with 17 emitters), Ambience (`Audio_Dock_Uguisu` +
  `UguisuScheduler`), LaunchSites (**4** tagged `FireworkLaunchSite` parts since
  2026-09-03 — `Site_SwitchbackDeck` joined the original three; recipe
  `tagLaunchSites.luau`), TourStops (2 `TourStop_*` markers, recipe
  `tagTourStops.luau`), SwitchbackRack (3 `FireworkTubeMount` plates, recipe
  `buildSwitchbackRack.luau` — the public battery stands tubes on them at boot).
- `Sandbox` present (throwaway prototypes; also `PlantDepthRig`, and since 2026-09-03
  `SkyBackdropTrial` — the [[horizon-backdrop]] rings and ground plane, promotion open).
- Attributes/registrations that exist only in the place: the **`EngawaBarrier`
  collision group** (verified registered; blocks players, passes `Projectile` — if
  barriers ever stop working, check this first), stage live-tune attributes
  (`CamPhaseDeg`, `DrawStuds`, `BellVolume`, `DrumKick`, …), `BellRingAnchor` at
  (−2,0) (verified).
- MaterialService variants (verified): `NorenCloth`, `BronzePatinaFine` — plus the
  RakedSand/RakedGravelRings/ZenGardenStone/CypressWeathered/CypressVertical family
  referenced by builders, and **`Thatch`** (ThatchedRoof002A, added and saved 2026-08-17
  for [[chaya]]; BaseMaterial Grass, StudsPerTile 4.0). A mistyped or duplicate variant
  name fails SILENTLY. Every one of them is rebuilt by
  `tools/studio/setupCenterpieceMaterials.luau`, which bakes the uploaded asset ids.

## ServerStorage inventory (verified 2026-08-15)

- **Parked, restorable**: `Sandbox_PARKED` (incl. `MerchantMassing` ×6 — the
  [[item-4-merchant-row]] massing reference, of which `Machiya_2` and `DockDeck` are now
  SUPERSEDED history rather than instructions: the ground under them could not carry what
  they described, and the chaya was built at the waterline instead ([[chaya]]) — and
  `PadRefs`),
  `Sandbox_PARKED_2026_08_01`, `Scaffolding_PARKED`, `WorkspaceStrays_PARKED`,
  `FireworkBench_PARKED` ([[fireworks]]), `ParkedFoliage`
  (`MossTransitions_2026_08_01`, `MuhlyKit_2026_07_31`, `MarginCull_2026_07_30`).
- **Import records**: `BackdropImports` — the 3D Importer originals of the [[horizon-backdrop]]
  range strips (v1 and v2 sets, 2026-09-03); not scenery.
- **Libraries/tools**: `FoliageZones` (35 zone volumes), `FoliageKit`, `MossLibrary`,
  `IrisLibrary`, `TrailStoneLibrary`, `RockLibrary`, `YamadoroLibrary`,
  `StructurePrefabs` (**teahouse-1story-s/m/l — three authored sizes**),
  `TeahousePrototypeL`, `WaterMap`, `PreserveScatterTool`, `ArrangementsTool`,
  `MossRunner`/`CullRunner`/`ShoreRocksTool`/`MossTransitionsTool`,
  `PadOccupancyPreviewTool`, `AuthoringSources`.
- **State snapshot**: `FoliageSnapshot_2026_08_02` (the planted world as models; its
  text twin is `docs/superpowers/canyon/foliage-manifest-2026-08-02.csv` in git).
- **Terrain backups** (dozens: `Tunnel_*_Backup`, `PathCarve_*`, `TrailBench_*`,
  `T*PadBackup`, `GreenCanyon*`, …). Two carry standing warnings:
  `ClearingTerrainBackup` is the RAW PRE-CARVE canyon — pasting it buries the
  clearing; `UpHeadBackup` predates the owner's hand-sculpted headwall — never
  paste. Snapshots must store their paste corner as attributes or `PasteRegion`
  cannot restore them; roll back added terrain with `pasteEmptyCells = true`.
- `RetiredLegacyTeahouses`, `RetiredTeahouse3Access`, `NW1012Retired` — retired
  geometry kept out of Workspace.

## Streaming (place data — code cannot set it)

`StreamingEnabled` is **on** (read from the live place 2026-09-05). The radii —
`StreamingMinRadius` and `StreamingTargetRadius` — are **not scriptable** and are editable
only in Studio's Properties panel on `Workspace`, so they are place data and their values
belong here rather than in `main.server.luau`. A 2026-09-04 attempt to own them in code
(`34c3ded`) was inert for a day before being removed; see [[misc-engine-traps]].

⚠ **Their current values are unrecorded.** Nothing in git has ever set them and nobody has
read them off the Properties panel, so the place is running whatever it has always run —
possibly the engine defaults (min 64, target 1024), possibly not. Read them in Studio and
record them here; until then, any claim about this place's streaming radii is a guess.

## Standing cautions

- ⚠ unverified: whether the place as **published** matches this Edit-session state —
  publishing history is not inspectable from here; the owner saves/publishes.
- Draft markers: `Workspace.PathDraft` no longer exists (verified 2026-08-15, audit
  sweep — searched the full Workspace tree and `CollectionService:GetTagged
  ("DevMarker")`, both empty). The River/T07Spur/Bridge* markers noted earlier are
  gone; the remaining `Bridge*`-marker thread on [[backlog]] (canyon path railings
  item) is resolved by their absence, not by a bake.
- ⚠ **UNSAVED PLACE EDIT (2026-09-06): `CanyonWorld.Structures.Chochin_Hanabiya` was retired**
  to `ServerStorage.RetiredPlaceOnly.Chochin_Hanabiya_RETIRED_2026_09_06` (4 sub-models, 106
  parts), because 花火屋 now emits its own lanterns from the builder like every other shop —
  leaving both would hang two lanterns in each corner. Parked, not deleted, same convention as
  `RetiredLegacyTeahouses`. **The place must be SAVED for this to persist, and Rojo synced for
  the builder pair to appear**; until both happen the shop's corners are bare in Edit.
- The place-only `UguisuScheduler` Script has an out-of-place backup at
  `~/Desktop/Roshambo Reference/sound/UguisuScheduler.server.luau`; several audio
  masters and Blender sources live under `~/Desktop/Roshambo Reference/` — outside
  both git and the place.
