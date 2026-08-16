# Log

Append-only. `grep "^## \[" log.md | tail -5` for recent entries.

## [2026-08-15] migrate | Wiki created; migration from memory dir begins

Spec: docs/superpowers/specs/2026-08-15-project-wiki-design.md. 80 memory files to
be reconciled in, verified against git, then deleted from the memory dir.

## [2026-08-15] migrate | program/ shelf: board, item-4, parked-defects, backlog

From memory: roshambo-roadmap, world-throw-cycle-phase, teahouse-access-control-backlog,
spawn-at-teahouse-backlog, piece-b-startup-notes, roshambo-metagame-spec (deleted), plus
status fragments of friends-family-baseline, round-structure, play-hud, structure-builder,
apprunner-migration, fw11-switchback-deck, yamadoro (deleted by later tasks). Notable
reconciliations: access-control "NOT built" superseded by the 2026-07-19/20 ship; FW11
railings/chōchin "resume Task 1" superseded by d247a2e/5d1a21e; yamadoro "unplaced"
superseded by 0c8f362/17bbb08.

## [2026-08-15] migrate | world/ shelf: 15 as-built pages

From 28 memory files (arena-amplified, bell-engine, dock-uguisu, fw11-switchback-deck,
viewing-platform, canyon-redesign/clearing-terrain/upcanyon-watercourse/garden-phase1/
canyon-garden/canyon-village/river-path/yamadoro/water-margin/foliage-scatter,
forest-preserve-foliage, water-audio, fireworks, night-first-arena, round-structure,
play-hud-item2, structure-builder, deck-fall-prevention, flume-revisit,
happy-sad-sides, shoro-roof-wip, canyon-compass, friends-family-baseline fragments),
verified against git + a live Studio session (place "Roshambo", Edit). Superseded and
closed with no page of their own: the Phase-1 bowl tier garden (retired by the
2026-06-15 canyon pivot) and the shōrō-roof WIP (its blocker was resolved and the
roof shipped in `dae8f00`/`9503859` — recorded on arena-square). Notable live
reconciliations: the 14 legacy CanyonTeahouses are retired to
ServerStorage.RetiredLegacyTeahouses (CanyonWorld.Legacy is empty);
ServerStorage.FoliageZones holds 35 zone volumes (resolving the "22 of 32" worry);
StructurePrefabs now carries three authored sizes (teahouse-1story-s/m/l);
DayNightLockT is back at 0.19.

## [2026-08-15] migrate | practice/ shelf: rules, recipes, traps, owner rulings

From 35 memory files (the standing rules flush-outside-edges / derive-from-what-it-
touches / one-model / walls-register / placement-discipline / bake-isolation /
destructive-bake-guard / visible-is-not-pixels / perf-harness-contamination /
toolbox-backdoor-scan / duplicated-server-constants; the material/mesh/texturing/
rojo-rbxm/editablemesh references; the three replication-race memories merged;
modal-cursor-grip; image-moderation + the glyph pipeline; the four build-recipe
memories merged (build-recipes index, ishidan, organic cobble, mossy terrain PBR);
studio-ui/mcp/screencapture merged; blender-fbx + procedural-river + glyphs-shared
merged; five misc traps merged; owner rulings compiled from Task 4's world Gates +
this task's files). Notable live reconciliation (Studio, Edit, 2026-08-15): the four
mistyped MaterialVariant names from the 2026-07-28 audit (ZenGravel1, RopeHemp,
ZenMossRock1, ZenCanyonRock2) ALL resolve in the live place now — the outstanding-
defect claims died, the audit recipe survived.

## [2026-08-15] migrate | systems/ shelf + disposition sweep complete (5 migrated, 6 retained)

Systems shelf (3 pages) from `roshambo-deploy-topology`, `roshambo-db-topology`,
`roshambo-apprunner-migration` (deploy.md; ECS status already lives on
[[backlog]], linked not restated), and `roblox-rojo-vs-place-state` (rojo-and-
place.md; live CanyonWorld.Legacy-is-empty correction already carried on
[[place-state]], cited not restated) — 4 files consumed+deleted. Disposition
sweep of the memory dir found one unmigrated straggler beyond the brief's
6-file survivor list: `roblox-waterfall-vfx-recipe` (the official-tutorial
Beam/ParticleEmitter recipe + ZenDojo tuning levers), not superseded by
anything already on [[canyon]]/[[misc-engine-traps]] (which cite the as-built
result and the general Beam-orientation gotcha but not the reusable recipe) —
migrated into [[blender-pipeline]] as a new section, then deleted (5th
migration this task). Final memory dir: `MEMORY.md` + 6 user/feedback files
(`stop-and-ask-after-each-attempt`, `roblox-user-units-feet-inches`,
`roshambo-local-env-quirks`, `blender-mcp-setup`, `blender-show-in-viewport`,
`talk-is-cheap-screenplay`) — matches the brief's expected-survivor list
exactly. `MEMORY.md` rewritten to the slim pointer-only template.

## [2026-08-15] audit | repo audit: 4 findings filed, 1 trivial fix

Tool census (47 previously-uncited `roblox/tools/{studio,builders,textures,
blender,glyphs}` scripts) filed to [[studio-tooling]] as a new "Dormant tools"
section, one line each, split one-shot/baked vs live; flags 2 issues —
`builders/CanopyScatter.luau` cites a Studio mirror (`scatterCanopy.luau`) that
does not exist anywhere in the repo or its history, and `studio/
draftPathMarkers.luau` is self-declared superseded (its target `PathDraft` no
longer exists in the place). TODO/FIXME sweep (`grep TODO\|FIXME\|HACK\|XXX`,
head -50) found 3 hits, all in `upcanyonRiverPOC.luau`, already tracked under
[[backlog]] § River hydrology / [[water-audio]] — no new filing. Docs truth
pass: `README.md` does not exist (not a regression — untracked in git
history); `README_DEPLOY.md` claims check out against `apprunner.yaml`/
[[data]]/[[deploy]]. Config drift: both `.nvmrc` files agree (24.12.0) and
match CI; the Dockerfile/apprunner Node-pin drift is already tracked in
[[backlog]] § ECS migration. Live Studio session (place "Roshambo", Edit):
confirmed `Workspace.PathDraft` no longer exists and no `DevMarker`-tagged
instances remain anywhere — cleared [[place-state]]'s "draft markers presence
unchecked" caution and removed [[backlog]]'s now-fully-resolved "Canyon path
railings & chōchin" residual-thread item; confirmed 6 yamadoro models under
`Workspace.CanyonWorld.Paths.PathLanterns.Yamadoro_RiverTrail` plus the
`ServerStorage.YamadoroLibrary` template, clearing that unverified marker on
[[backlog]]. One trivial-and-safe fix applied per controller ruling:
CLAUDE.md's "Workspace organization" sentence calling `CanyonWorld.Legacy`
"the frozen 14 `CanyonTeahouses`" corrected to match the verified live place
(empty, retired to `ServerStorage.RetiredLegacyTeahouses`).

Review fix (same day): the census grep loop missed 2 tools whose basenames
coincidentally matched unrelated English-word text (`pierce` in "pierce alpha" on
[[arena-square]], `png` in "color.png" on [[rojo-meshpart-rbxm]]) — actually
never cited. Added `glyphs/pierce.cjs` and `glyphs/png.cjs` to
[[studio-tooling]]'s Dormant tools section. Also recorded the Step-4 engines
check that ran but left no trace: `grep -n engines package.json
server/package.json` returns no matches in either root — neither declares an
`engines` field, so there is nothing to drift against `.nvmrc` (24.12.0).

## [2026-08-15] lint | migration complete: 45 pages, 0 lint errors; memory dir reduced 81 → 7 files

Mechanical lint (`tools/wiki/lint.mjs`): 0 errors, 0 warnings across 45 pages.
Manual pass (schema.md checklist): read index.md end to end, the board +
all 4 program pages in full, and 3 world pages (falls-dock, hanabiya,
arena-square) — no contradictions found; statuses and cited commits check out
against today's git log (`cff3d95`/`156d44a`/`399bf14`/`75d7330`/`8d40514`
match [[arena-square]]'s bronze/roof citations exactly). One `⚠ unverified`
marker became checkable with Studio connected: [[item-4-merchant-row]]'s
`MerchantMassing` survival, confirmed live (6 children: `Machiya_1..4`,
`Machiya_East`, `DockDeck`) and upgraded from unverified to fact, matching
[[place-state]]'s existing verification. The two remaining `⚠ unverified`
markers ([[fireworks]]'s untested 50-player concurrent-shell load,
[[place-state]]'s published-vs-Edit-session gap) are not Studio-checkable
facts and were left as-is. Acceptance checks: memory dir is `MEMORY.md` + 6
survivor files (7 total, all user/feedback, well under 20); [[program]]
answers "what's next" cold as item 4 (merchant row); [[falls-dock]] reads as
fully built with no future-work language. Step 5 (push) deferred per
controller instruction — the controller pushes after the whole-branch final
review.

## [2026-08-15] decision | corridor reservations retired, not re-derived

shopCorridor/eastCorridor (and their tests) deleted from ArenaLayout.luau at the
owner's call. Rationale: no runtime or bake code ever read them; their job — keeping
the free 55x30 garden slab out of the square's streets — ended when the panel was
pinned to the pavilion's post faces (17927df). The merchant row builds to Machiya's
owner-surveyed envelope (frontage z36). Item 4's prerequisite dissolves; next step is
the machiya-row brainstorm, where any fresh street reservation would be derived from
the massing.

## [2026-08-15] decision | machiya-row brainstorm complete, spec committed

Item 4's design settled (spec 2026-08-15-machiya-row-design.md): façades with
identity, shallow-enterable; apparel/花火屋/accessories on the south row; sports book
= Machiya_East frontage with the item-7 cavern under the western Overlook (the two
siting options converged on the old statistics-room mark); Machiya_2 becomes a
riverside chaya with a service counter and a named ChayaKeeperSlot anchor for a
future tea-vendor NPC. Build approach: generalize Machiya.luau (snapshot-gated
refactor) + separate Chaya.luau.

## [2026-08-15] gate | apparel machiya accepted; chochin canonicalized

First shell of the merchant row accepted after three rounds. Carried out of it: the machiya
archetype is now parameterized (MachiyaShops.luau spec tables, byte-gated against Hanabiya);
tools/builders/Chochin.luau is the single canonical lantern shared by the kit, drift-guarded by a
text-parsing test against buildHanabiyaChochin.luau (studio tools cannot require modules); and the
owner's rule that paths stay uniform while the merchant row varies by tint.

## [2026-08-15] decision | the Stats room: re-sited, renamed, and "sports book" barred

The merchant row's fourth shell moves off Machiya_East (owner: the Overlook undercroft "is
probably a bad place for it" — and a survey confirmed the old cavern mark at (73,110,19) is open
air under an elevated deck, not rock). It becomes a small two-bay FALSE FRONT west of the apparel
shop, x −33.92..−23.92, backing into the south upslope that climbs 115→130 between z36 and z48 —
real rock for the cavern to be carved at a later item. The room's name is **Stats** (leaderboards
for individuals, groups, countries); its shopfront reads 番付. "Sports book" is barred as product
usage — design discussion only. Machiya_East's massing stays parked, unassigned.

## [2026-08-16] decision | the World Throw is the MAJORITY, and the patent is the owner's

Correcting a premise the repo had backwards. The World Throw is **the majority choice of
players**, not random — "you against the world" is the product, and the shipped random
pick is an unfinished implementation, not the source of truth. Crowd-reading is therefore
skill, and the last-five-rounds HUD exists because that history is predictive. Recorded
in [[world-throw]]; the divergence is logged as parked defect (f). `CLAUDE.md` asserted
the opposite ("not derived from player votes despite the spec") and was corrected in the
same pass. Also recorded: the game implements **US 8,025,570 B2, owned by Jon Labrie**,
giving roughly a year of exclusivity as of 2026-08.

## [2026-08-16] ship | the Stats cavern is bored, doubled, and its ceiling raised

The 番付 hall exists in rock. Tunnel from MachiyaStats' rear doorway (roof pinned to the
lintel top so it meets the door without a step), into a chamber the owner then doubled by
pushing the west wall −38 → −58, then raised 129 → 134. As saved: 40 × 25, floor 114.00,
~19 clear, 17.9 studs of cover, no breaches. Recorded in [[stats-room]]; the bore is
reproducible from `tools/studio/boreStatsCavern.luau`, which defaults to a non-destructive
VERIFY because the owner hand-shaped the mouth after the cut.

There was no rock over the doorway to bore through — natural grade topped out at the door
head exactly — so the hillside had to be RAISED first, threaded under a roof eave whose true
lowest corner is 127.20 (not the 129.3 a naive bbox read gives). Six bore traps carried to
[[misc-engine-traps]], the sharpest being that terrain writes are invisible to raycasts
within the same execution.

## [2026-08-16] decision | throws bind to 1/2/3, and the Stats room is a play space

Two rulings out of the [[stats-room]] spec, both GLOBAL rather than that room's scope, parked
in [[backlog]]:

**Keyboard throws bind to `1`/`2`/`3`.** A laptop player in first person cannot use the HUD at
all — the cursor is pinned to screen centre — and [[modal-cursor-grip]] does not transfer,
because it works only for a temporary modal; holding the cursor free for an always-visible HUD
would mean never looking around. The owner's first instinct, `R`/`P`/`S`, is unavailable: `S`
is Roblox's default walk-backward. Numbers are unclaimed (the client uses no Tools or Backpack)
and, unlike letters, do not move under AZERTY/QWERTZ. The HUD carries the numeral on each tile.

**Players CAN throw from inside the Stats cavern** — the HUD is always visible, so it is a
study-and-play space, not a trade. The round band stays required: it tells a player reading a
wall that a round is closing. Also parked: HUD dismiss/recall.
