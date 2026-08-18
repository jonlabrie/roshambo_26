---
shelf: world
updated: 2026-08-17
---

# Place State

The page for what git cannot see. Rojo manages exactly what `default.project.json`
names — everything under `Workspace.RoshamboStage` — and nothing else; all other
Workspace content is place-only, organized by lifecycle (`CanyonWorld` shipped,
`Sandbox` throwaway). Ship by **publishing/saving the place, never `rojo build`**
(a build emits only the declared stage children and drops all place-only content).
CI fails on any committed `.rbxl(x)`. Authority: CLAUDE.md §Workspace organization,
[[rojo-and-place]].

Everything below marked *verified* was checked live via the Studio MCP on 2026-08-15
(Edit mode, place "Roshambo").

## Publish checklist

1. `Workspace.DayNightLockT` must be at 0.19 (the daytime working value) or cleared —
   never publish a dusk/night lock. Verified 2026-08-15: `DayNightLockT = 0.19`,
   `PreNightTestLockT = 0.19`, `DayNightStartT` cleared — currently satisfied.
2. Run `roblox/tools/studio/verifyWorkspaceConvention.luau` in Studio.
3. Save/publish the place after ANY place-only work — a session's live edits are
   worthless until saved.

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
  `ServerStorage.RetiredLegacyTeahouses`; CLAUDE.md's "frozen 14" note is stale)**,
  Foliage (Heroes, Preserve, ShoreRocks, ArrangementsDraft ×22, EastBackdrop), Water
  (runs + `FallsAudio` with 17 emitters), Ambience (`Audio_Dock_Uguisu` +
  `UguisuScheduler`), LaunchSites (3 tagged `FireworkLaunchSite` parts).
- `Sandbox` present (throwaway prototypes; also `PlantDepthRig`).
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

## Standing cautions

- ⚠ unverified: whether the place as **published** matches this Edit-session state —
  publishing history is not inspectable from here; the owner saves/publishes.
- Draft markers: `Workspace.PathDraft` no longer exists (verified 2026-08-15, audit
  sweep — searched the full Workspace tree and `CollectionService:GetTagged
  ("DevMarker")`, both empty). The River/T07Spur/Bridge* markers noted earlier are
  gone; the remaining `Bridge*`-marker thread on [[backlog]] (canyon path railings
  item) is resolved by their absence, not by a bake.
- The place-only `UguisuScheduler` Script has an out-of-place backup at
  `~/Desktop/Roshambo Reference/sound/UguisuScheduler.server.luau`; several audio
  masters and Blender sources live under `~/Desktop/Roshambo Reference/` — outside
  both git and the place.
