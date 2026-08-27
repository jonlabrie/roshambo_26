# Roshambo Wiki Index

Read this first. Rules and shelf definitions: [schema.md](schema.md).
Chronology: [log.md](log.md).

## program — status & work tracking

- [Friends & Family Baseline](program/friends-family-baseline.md) — the governing 8-item program board: statuses, the bar, out-of-scope, owner gates
- [Item 4 — Merchant Row](program/item-4-merchant-row.md) — machiya row scope, the built fireworks shop, massing + corridor prerequisites
- [Parked Defects](program/parked-defects.md) — known, intentionally-unfixed defects awaiting their items, each with reproduction, fix sketch, and code citations
- [Backlog](program/backlog.md) — future items with restart context: Piece B remainder, spawn-at-teahouse, ECS migration, onboarding pass, lighting threads

## world — as-built

- [Canyon](world/canyon.md) — geography, compass, terrain provenance, the W## watercourse, clearing terrain, water taste rulings
- [Arena Square](world/arena-square.md) — the Shōrō square: karesansui, torii, sōrin, roof mesh, palette, bell sound, drum-caret lore
- [Bell Engine](world/bell-engine.md) — the water-powered bell engine: drive line, gearing, snail cam, drum, round metronome
- [Core Loop](world/core-loop.md) — READ FIRST: what the game is — outcomes, 3ⁿ pot, Bank vs Stake, which points field means what, the pointsDelta trap
- [World Throw](world/world-throw.md) — the majority rule, why crowd-reading is skill, the patent basis, and the random-pick divergence
- [Round & HUD](world/round-and-hud.md) — OPEN/LOCK/REVEAL timing, the drum-is-authoritative rule, ring/undo/payoff recipes, copy rulings
- [Hanabiya](world/hanabiya.md) — the fireworks shop: frontage, stair/attic, noren, chōchin, its gates and drops
- [Riverside Chaya](world/chaya.md) — the tea stand and its dock: the arrangement, the frame, the thatch, the keeper slot standing empty
- [Familiars](world/familiars.md) — the bird that reads your round: four states, grades from milestones, and the 326 perches it rests on
- [Status Display](world/status-display.md) — the three clocks (now / lately / forever), the aura's rules, the five rejected carriers and the three different reasons
- [Fireworks](world/fireworks.md) — the fireworks system, launch sites, perf rules and measured floor, monetization decision
- [Day/Night](world/day-night.md) — cycle foundation, scope ruling, night glyphs, lantern and water-VFX subscribers
- [Viewing Platform](world/viewing-platform.md) — the twin overlook decks, the hand-carved downcanyon vista, the lantern telegraph
- [Stats Room](world/stats-room.md) — the 番付 cavern: tunnel, chamber, the berm that had to be built because there was no rock over the door
- [Switchback Deck](world/switchback-deck.md) — the FW11 hairpin deck, upper-path extension, descent, retaining walls
- [Falls Dock](world/falls-dock.md) — the composed falls-pool site: dock, yukimi lantern, cherry, uguisu, iris
- [Paths](world/paths.md) — the wall path network and river trail: registers, builders, tunnels, bridges, trail lighting
- [Teahouses](world/teahouses.md) — portable loadout structures, pads/sites, deck fall-prevention, the design language, legacy
- [Foliage](world/foliage.md) — the curated floor: care model, zone-scatter system, palette, as-built planting, parked kits
- [Water Audio](world/water-audio.md) — the 17 water emitters, clips, rolloff/stagger rules, coverage survey, hydrology deferral
- [Place State](world/place-state.md) — what git cannot see: workspace convention, publish checklist, verified place inventory

## practice — how we work

- [Wiki Currency](practice/wiki-currency.md) — why a one-day-old wiki went stale: appends land, prose rots, and the lint checks structure not currency
- [Owner Rulings](practice/owner-rulings.md) — the standing taste/copy/process rulings, one line each, with citations
- [Flush Outside Edges](practice/flush-outside-edges.md) — outer faces flush at free edges, tucked where they die into walls, the z-fight scan, barrier gaps
- [Derive From What It Touches](practice/derive-from-what-it-touches.md) — size every member from what it meets; level is never the target where surfaces meet
- [One Model Is Not a Building](practice/one-model-is-not-a-building.md) — measure the composite footprint union, not one model's bbox; document how landmarks were measured
- [Walls Register to Structure](practice/walls-register-to-structure.md) — retaining walls register to the built edge + standoff, never to the excavation; backfill to the wall backs
- [Placement Discipline](practice/placement-discipline.md) — full-footprint 8-point footing ring + terrain-top check at every probe; search or skip, never place anyway
- [Bake Isolation](practice/bake-isolation.md) — a bake aimed at one zone never rewrites another: fixed world lattice, whole-world planning, explicit targets, empirical verification
- [Destructive Bake Guard](practice/destructive-bake-guard.md) — destroy-and-rebuild bakes refuse to run over hand-tuned output; fingerprint in the tool, stop-and-ask when it trips
- [Visible Is Not Pixels](practice/visible-is-not-pixels.md) — property reads are not rendering evidence: the ZIndexBehavior=Global trap, the CanvasGroup that drew nothing, the one-variable probe
- [Perf Harness Contamination](practice/perf-harness-contamination.md) — enumerate what you added before believing a perf regression; park benches immediately; StarterPlayerScripts is the dangerous parent
- [Toolbox Backdoor Scan](practice/toolbox-backdoor-scan.md) — scanning free-toolbox imports for require-backdoors before any publish; the obfuscation shapes to look for
- [Duplicated Server Constants](practice/duplicated-server-constants.md) — the server-number-re-derived-client-side defect class, its diagnostic signature, the fixture-gate mutation check
- [Material and Mesh Traps](practice/material-and-mesh-traps.md) — silent failures: mistyped/duplicate MaterialVariants, global overrides, ColorMap-only SAs, straight-alpha filtering, fetch failures, pivot leftovers
- [Texturing Pack Meshes](practice/texturing-pack-meshes.md) — recoloring imported mesh packs via world-space MaterialVariant; tint-vs-map, StudsPerTile vs part size
- [Rojo MeshPart .rbxm](practice/rojo-meshpart-rbxm.md) — hero meshes ship as committed binary .rbxm via $path; parts-not-mesh for simple shapes; the ambientCG materials pipeline
- [EditableMesh Gotchas](practice/editablemesh-gotchas.md) — normals + local-space verts, runtime restrictions, publish-to-persist recipe, UV-scroll animation
- [Replication Races](practice/replication-races.md) — WaitForChild at startup, RemoteEvents unordered vs instances, Emit() never replicates
- [Modal Cursor Grip](practice/modal-cursor-grip.md) — freeing the cursor for a proximity modal (RenderStep at Camera+1) and the DevEnableMouseLock trap
- [Image Moderation](practice/image-moderation.md) — the green-palmate-leaf takedown, upload URL/approval mechanics, safe recolour rules
- [Build Recipes](practice/build-recipes.md) — CONSULT FIRST for canyon paths/decks/walls/railings/lanterns: the recipe doc, builders, ishidan style, cobble technique, terrain PBR
- [Studio Tooling](practice/studio-tooling.md) — Studio UI locations, Rojo patch-by-name, Studio MCP quirks (return values, camera lock, datamodels)
- [Blender Pipeline](practice/blender-pipeline.md) — FBX unit/pivot/material traps, the SKINNED-mesh recipe (bones are drivable from Luau), the bake recipe, the procedural river technique, the waterfall VFX recipe, the SDF glyph pipeline
- [Parallel Threads](practice/parallel-threads.md) — three Claude sessions, one place file, one reviewer
- [Misc Engine Traps](practice/misc-engine-traps.md) — SurfaceGui TextSize, flat beams, tunnel boring, genmodels arch portability, teahouse floor-vs-pivot

## systems — infra pointers

- [Deploy](systems/deploy.md) — App Runner topology (cloud dev auto-deploy vs prod manual), the never-start-a-local-server rule, the parked ECS migration
- [Data](systems/data.md) — the single Atlas cluster, prod/dev database split, the orphaned `test` db, the economy-split-is-schema-not-database rule
- [Identity](systems/identity.md) — the identity-comes-from-the-connection rule, device tokens, the 2026-08-18 hard cut
- [Rojo & Place](systems/rojo-and-place.md) — the Rojo-vs-place-only ownership split, ship-by-publish rule, the workspace convention
