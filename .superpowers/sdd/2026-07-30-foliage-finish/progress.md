# SDD ledger — plan: docs/superpowers/plans/2026-07-30-foliage-finish.md
Task 5: minor (deferred): integration test narrower than drafted (only asserts x=48 excluded; no control run) — tests/ZoneScatter.spec.luau:96-104
Task 5: minor (deferred): implementer report cited scatterPreserve as a plan() caller; it is a mirror, not a caller (report line ~135)
Task 5: note: plan's original assertion p.x<48 or p.x>56 was unsatisfiable (low side of cliff is sound footing); corrected to p.x ~= 48 — reviewer confirmed by hand-trace
Task 5: complete (commits f46b4d1..d3beb4e, review clean)
Task 6: minor (deferred): no test at the exact depth == submergeMax boundary (code verified correct; a future > → >= refactor would regress silently)
Task 6: complete (commits d3beb4e..d8b885c, review clean)
Task 7: minor (deferred): clump-only keep-out coverage not isolated (parent-path failures alone can satisfy both tests; moot given shared accepts())
Task 7: complete (commits d8b885c..c0f3337, review clean)
Task 8: minor (deferred): CareModel.band returns bare string not a literal union; typo'd careDensity keys no-op silently
Task 8: minor (deferred): ZoneScatter care test RED evidence was the module require error, not an observed assertion failure
Task 8: minor (deferred): no test at the exact 0.35*reach boundary
Task 8: complete (commits c0f3337..4b7e225, review clean)
Task 13: minor (deferred): falloff/cross-seed tests are single-seed samples near the coin-flip line (5v3 margin); could go flaky if RNG draw order changes
Task 13: minor (deferred): radial (not areal) uniform dart sampling — fine per spec formula, note if "density" is ever read as area-density
Task 13: complete (commits 4b7e225..74c342b, review clean)
Task 14 (code half): review Needs fixes — Important: collectFootingSeeds rotation-naive bottomY (line ~276) vs GetBoundingBox pattern; rock-scoping ⚠ deferred to first plan run in Studio
Task 14: minor (deferred): MODE="wipe" runs full seed collection before wiping (wasted Studio time)
Task 14: minor (deferred): plan-mode placement count excludes keep-out refusals (overstates bake)
Task 14: fix round 1/5 (1 Important open — rotation-naive footing bbox; base 78db61a)
Task 14: fix round 1/5 (1 addressed, 0 open — worldAabbBottomY OBB→AABB projection; commits 78db61a..757f462)
Task 14 (code half): complete (commits 74c342b..757f462, review clean after 1 fix round) — Studio plan/bake/gate steps still pending
USER DECISIONS: muhly = path A (bake to crossed-card clumps); accent imports done by user; fern context row green-lit
Task 4 USER GATE VERDICT: fern_06_good KEEPS (low weight in WaterMargin); fern_09_good + fern_10_good PARK (remain ugly in context). Test row removed.
Task 4 lesson: my hand placement raycast IgnoreWater=true and seated a fern 2.6 studs underwater at the dock corner — the exact failure the Task 6 submersion predicate gates at bake time.
Task 1-4 status: T2/T3 accents imported + SA-wired (heights MapleA 14, MapleM 10, KatsuraA 24.6, KatsuraM 16, BambooA 22); T1 muhly = PATH A (bake to crossed cards), bake work starting; T4 complete.
Task 9: complete (commits 757f462..8ed5d46, review clean, zero findings)
Note: inline commit b8b711e (bake_grass_patch.py, Task 1 tooling) interleaved after 8ed5d46 — outside any task review; gets covered by the final whole-branch review
Task 10: review Needs fixes — Critical: FallsDock garden radius routed through generic index; ring made dock footprint PRESERVE (spec inversion)
Task 10: fix round 1/5 (1 addressed, 0 open — hard footprint override via distToFootprint AABB distance; ring cells removed; commits cdda860..664d61d)
Task 10: complete (commits b8b711e..664d61d incl. fix, review clean after 1 round). Note: interleaved controller commit 717e27a (baker grade) excluded from task review, covered at final review.
Task 1 (muhly) USER-CAUGHT BUG in v1/v2 cards: square bake tile mapped onto aspect-ratio quad DOUBLE-APPLIES aspect (squished ~50% vertical, stretched horizontal). Fix: render_view returns tile occupancy fractions; build_clump UV-maps only the occupied sub-rect. v3 baking. Blender-side compare scene (muhly_compare.blend) is the verification rig — original patch vs card, height-matched, in the user's live session.
Task 2/3 REWORK (user-caught: MapleA trunk missing): mode-3 proportional wood drops the bole on multi-stem deciduous Xfrog sources; mode-1 at accent budgets keeps bole but orphans canopy (5/5939 twigs). RESOLUTION: hero treatment — mode 1, wood 45k(A)/30k(M) over 3 trunk parts + split_fbx per mesh (sugi path). All four exported+split at xfrog_import_accents_v3/<Tree>_parts/ w/ manifests. Bamboo unchanged (mode-3 culms correct). Muhly at v5 (grade softened twice: 1.35/1.25 → 1.18/1.12 → 1.08/1.05), awaiting user color verdict in the Blender compare scene.
Task 1 (muhly) COMPLETE: v6 grade approved implicitly by import (brightness 1.13, alpha 1.6, pink 1.085, stem darken 0.8); six crossed-card clumps in FoliageKit, DoubleSided=true, SA alpha wired; pedestal + pool clones refreshed. Six bakes total: the journey = card-cull fix (DoubleSided), 1024 tiles, occupancy-UV aspect fix (user-caught), 3-round color grade.
Task 11 STARTING: zone restore + audit + exemplars + plan counts (non-destructive prep).
Task 2/3 RESOLUTION (user-corrected my import guidance): multi-select Import 3D does NOT self-assemble parts — the sugi path was a SINGLE FBX containing multiple meshes. XfKatsuraA imported from the unsplit 57.5k fbx (importer took it fine — the "file-level budget" fear didn't bite at 57.5k). Final accents: MapleA hero (54k, swapped), KatsuraA hero (57.5k, swapped), MapleM v1 kept (15.3k), KatsuraM v1 kept (29.3k), BambooA v1 (22.8k, verdict pending). Barks wired: maple 96420260663967, katsura 74214937066902.
=== SESSION PAUSE 2026-07-31 (late night) ===
Task 11 complete: zones restored (22, coherent), WaterMap restored (840 markers), exemplars created (ReedClump/WeedStalks/FernClump), plan counts probed.
Task 12 BAKED (551 placements; Core 39 w/ gate config footingMaxDrop=6 pathMargin=5 spacing 10-15, FutureClearing softened; old Preserve+WaterFoliage parked at ParkedFoliage.Replant_2026_07_31) — USER GATE FAILED with two findings:
 (a) floor "looks awful, like random scatter" — proposed GROVE-BASED planning for canopy layers (grove anchors + tight clusters + real meadow gaps; brush/margin stay scatter) vs judging after the Part-4 arrangements pass; USER DECISION PENDING (went to bed on the question).
 (b) muhly cards tint light/dark by camera/sun angle in Play — flat-big-quad lighting; fix = rebuild clump as 10-12 smaller overlapping cards + normals bent outward from clump centre (bake_grass_patch change), rebake v7, re-import.
Gate-config values NOT yet folded back into RECIPES/foliageZoneRecipes (do after gate passes).
Displays cleaned (MuhlyDisplay/AccentDisplay/MuhlyColorTest removed). Bamboo verdict never explicitly given (implicitly OK). http server killed. USER REMINDED TO SAVE PLACE.
PLACE SAVED by user 2026-07-31 (carries: kit swaps, zone/WaterMap restore, exemplars, T12 bake, parked populations)
MUHLY v7-v10 saga (late night 2026-07-31): v7/v8 card-fan REJECTED (ghost-copies of full plant image = chaos; bent normals shade dark on Roblox backface flip); v9 = v6 crossed planes + shells + up-biased stable normals; v10 adds TOP CAPS (2x2 atlas w/ top-down bake tile) for the canyon's high vantage points — USER INSIGHT: star-shaped assets can't fly with this many overlooks. v10 imported, wired DoubleSided=FALSE (shells make it unneeded + kills transmission risk), kit swapped.
LESSON: zone-filtered bakes are NOT isolation-safe (readZones loads wanted+keepouts only → Margin-only bake claimed Core's bank ground, 119 vs 66). Full re-bake reproduced canonical 551 with v10 clumps.
PENDING: user Play check (tint stability + top-down read) = muhly final gate; then fold gate recipe values into committed RECIPES + foliageZoneRecipes; grove-structure decision still open.
=== SESSION PAUSE 2 (2026-07-31 ~1am) ===
MORNING OPENER (user-agreed): angle-fade impostor system — (1) baker exports each clump as TWO meshes (_Vert crossed planes / _Caps horizontal), (2) new FoliageImpostorController.client.luau: tag-driven, ~10Hz, LocalTransparencyModifier fades caps in above ~25° camera elevation and out at ground level, (3) VERIFY LocalTransparencyModifier composes with SurfaceAppearance AlphaMode=Transparency before building on it. Then: muhly Play gate → fold gate recipe values into committed recipes → GROVE-STRUCTURE decision for tree scatter (still open) → T14 moss run → T15/16 composition.
User findings driving this: top caps break the ground-level profile; wished for view-angle transparency — which LocalTransparencyModifier can deliver client-side.
Baker committed through "crossed planes + top caps + stable normals". PLACE SAVE NEEDED AGAIN (v10 kit swap + full re-bake are place-only since the last save).
PLACE SAVED again by user (~1am 2026-07-31): v10 muhly kit + full 551 re-bake + accent hero swaps all safe
ANGLE-FADE IMPOSTORS COMPLETE (2026-07-31 morning, commits 176a26f..40c8d16): LTM+SA verified live; streaming race found+fixed (8ded474 — never cache parts at tag time); v12 = per-plane meshes _Vert1/2/3+_Caps; ImpostorFade pure module (elevation/cap/edge/vert transparency + planeNormal, 724 tests); controller resolves parts live per tick. NUMERIC VERIFICATION in live client: edge-on→plane hides+partners carry; facing→all shown; overhead→verts out, caps in. Template-Model fix: Reed/Weed/Fern exemplars wrapped in Models — waterline stamped ALL 555 for the first time (was silently muhly-only every prior bake). PENDING: user Play gate.
MUHLY PARKED (2026-07-31, user decision after both techniques failed the gate): (1) card impostors v1-v12 incl. the full angle-fade system — user could find no working setting, per-plane fades read wrong; (2) volumetric displaced-mesh quick-try — "pink mushroom", opaque volume cannot do feathered plume edges. Recipe reweighted Reed 45 / WeedStalks 30 / Fern 25 (a8b95a7); kit models parked at ParkedFoliage.MuhlyKit_2026_07_31; world re-baked 555, Margin = Reed 56 + Weed 41 + Fern 35, zero muhly. Impostor code (ImpostorFade + FoliageImpostorController) left committed + dormant (no tags = no-op) — reusable if a future card asset earns it. Pink at the waterline = IRIS (by design), reinforce at composition pass. REVISIT only if a proper game-ready muhly asset is bought.
GROVE SCATTER (gate-fix for "random scatter"): pure planner LANDED 08b0f91, review APPROVED zero findings (732 tests, reviewer re-ran suite independently). 2 deferred minors: double containsXZ in dart loop; attendant exclusion by name not index. Mirror+recipes subagent dispatched (Core grove spacing55/r8-16/members3-8/elder1.25/maxGroves12; Brush groveAffinity r22 in1/out0.25 + three 0.65-scale small-tier pool entries for the uniform-height brush complaint). TallWeeds added earlier (056b71b, Margin now Reed44/Tall32/Fern32/Weed24).
GROVE GATE PASSING (2026-07-31 midday): 12 anchors @ spacing 45 → 6 merged woods (5,6,9,11,18,19) — user: "feeling pretty good". USER-MARKED SPOTS (from Play, captured via character position):
 1. SUGI STAND (dense/dark, new SugiStand recipe: pure XfSugi25T, 1 grove, members 5-8, radius 6-12, memberSpacing 5, saplings XfSugiYb 0.35): zone at (-282, -30)
 2. HERO PAIR (hand-placed at composition pass T15, maple/katsura candidates): (-343, 203, -55) high ground S of falls pool
 3. BIG MIXED GROVE (standard palette): zone at (-335, 39) south bench
PENDING when user next in Edit: add SugiStand recipe zones (small circles r~20 named Grove_Sugi / Grove_SouthBench w/ Recipe attrs), re-bake, gate. Then: fold ALL gate-tuned values into committed recipe defaults (footingMaxDrop 6, pathMargin 5 etc. still passed as overrides each bake!), T14 moss run, T15/16 composition.
Day lock 0.19 SET in Edit (clear before publish). PLACE SAVE NEEDED (everything since yesterday's save is place-only).
=== CONTEXT-SAFE STATE (2026-07-31 afternoon, pre-compaction) ===
GROVE ARC nearly closed. Landed & committed: grove scatter (08b0f91), keep-out fix (1074bdc), saplings (75333be), member retries (789c70b), free-mix (0b2cf5d), centre-seek for maxGroves==1 (19b0fcf); mirrors/recipes through f5f418b + 12-groves tune (ee5d664) + SugiStand recipe (f7dec34) + hero-sugi pool (d87e2d8). 751 tests green.
CURRENT WORLD: 68 Core in 6 woods + Grove_SouthBench 7 + Grove_Sugi 5 (SugiB/D/F + 2 XfSugiYb saplings, but anchored at zone EDGE — centre-seek fixes on next bake) + brush 148 + Margin 132 (Reed/Tall/Weed/Fern + IrisA 10/IrisB 4 upright).
IN FLIGHT: mirror agent finishing centre-seek mirror + SugiStand membersMin 7/max 10/saplings 0.25 → then: push tool (localhost:8765 server running, cp to scratchpad first), BAKE with the standing overrides (PreserveCore footingMaxDrop=6 pathMargin=5; FutureClearing footingMaxDrop=6 pathMargin=4), verify Grove_Sugi anchors near (-282,-30).
STILL OPEN AFTER: (1) FOLD gate overrides + all tuned values into committed recipe DEFAULTS (they're still passed per-bake!); (2) T14 moss run (collector committed, needs Studio run + park 829 + gate); (3) T15/16 composition: hero pair at (-343,203,-55), bamboo grove siting, arrangements; (4) final walk-through + as-built + fold ledger minors into final review; (5) PLACE SAVE (nothing saved since last night!); (6) push branch (many local commits).
LESSON (user-caught): I diagnosed pathMargin rejection without probing — the ground was clean; cause was first-dart-wins. Probe before asserting.
=== PRE-COMPACT CHECKPOINT (2026-07-31 pm) ===
GROVE ARC COMPLETE & USER-SATISFIED. Exhaustive placer (3fdbbff + mirror d26c514) shipped. World: 590 placements — 6 procedural woods (Core 77) + 4 placed stands: Grove_Sugi 6 (hero sugi @ -282,-30), Grove_Maple 7 (MapleStand @ -351,-48), Grove_HighShoulder 7 (PreserveCore @ -380,34), Grove_SouthBench 9; brush 171; Margin 132 (Reed/Tall/Weed/Fern/Iris upright). All 26 zone parts set Transparency=1 (kept for future bakes). PLACE SAVED TWICE by user. 754 tests green. Local commits many, branch UNPUSHED.
NEXT (in order): (1) fold per-bake overrides (PreserveCore footingMaxDrop=6 pathMargin=5; FutureClearing footingMaxDrop=6 pathMargin=4) into committed recipe defaults; (2) T14 moss engine Studio run (park 829 MossScatter → bake MossTransitions → gate); (3) T15/16 composition: hero pair @ (-343,203,-55), bamboo grove siting, arrangements pass, final day+night walk-through, as-built section, fold-back + push; (4) whole-branch final review per SDD; (5) clear DayNightLockT before any publish.
=== POST-COMPACT SESSION (2026-07-31 evening) ===
Fold-back DONE (6a5e66e): PreserveCore pathMargin 5/footingMaxDrop 6, FutureClearing pathMargin 4/footingMaxDrop 6 now committed defaults — bare bake reproduces the approved world.
T14a SHORE ROCKS (user-inserted before moss: "pools have no rocks at their waterlines"): ShoreRocks pure planner (4e6c01d, review PASS, 2 minors deferred: Candidate lacks y tiebreak at stacked seams; 4-vs-5 retry reading) + buildShoreRocks Studio tool (86e94ad + fixes). Ishigumi register: anchor/attendant/wader roles, lip-score density, exhaustive anchor selection. BUGS FIXED EN ROUTE: wader step floor at memberSpacing (96611c4 — first plan placed 0 waders, starved by own anchor's spacing bubble; regression-tested); clone dressing (c094a12 — RockLibrary templates are raw Plastic+TextureID imports); Moss Kit stones added to tiers keeping their SA (a10991d); self-standoff from previous bake (0788e9b); bake white Color (d0d4174 — template grey darkened the maps). CANONICAL ROCK LOOK (user): base-Rock ZenCanyonRock variant, ColorMap rbxassetid://132831870698274; the Basalt-based namesake was DISCARDED — renamed ZenCanyonRock_RETIRED in place (0 users). MATERIALS CLEANUP backlogged to F&F item 8 (duplicate names, ZenGravel1 broken on 356 parts).
T14a GATE PASSED: 99 rocks (18/20 spacing after "denser + wander from lips" feedback; 26 anchor/66 attendant/7 wader; Moss Kit stones mixed in; all white).
FoliageZones MOVED Workspace.Sandbox → ServerStorage (de7196f; user: hover-highlight clutter in Edit). Readers check ServerStorage first, Sandbox fallback. Zone parts remain editable data.
T14 MOSS COMPLETE, GATE PASSED: old 825 MossScatter parked (ParkedFoliage.MossScatter_2026_07_31). Collector fixes: per-part stone seeds never container bbox (89a4e86); pvFooting BasePart branch (745694c); overrides option (d5fc205). Bake values: dartsPerSeed 4, spacing 3, densities stone .45/footing .15/waterline .45/crevice .2 → 1247 clumps. Gate fixes: TERRAIN-ONLY seating (53344f3 — 365 clumps had sat on paths/decks/rock tops; ray now refuses non-terrain top surface) + tint RGB(150,152,128) on SurfaceAppearance.Color (f5f4988 — AlphaMode=Transparency IGNORES part.Color; two invisible "recolors" before user caught it; value tuned live: 118 too dark, 150 approved). NOTE: bake overrides NOT yet folded into PARAMS defaults — fold with the T15/16 close-out.
PLACE SAVED (carries shore rocks + moss + zone move + variant rename).
NOW: T15/16 composition — hero pair @ (-343,203,-55) maple/katsura; bamboo contrast grove siting; arrangements; day+night walk-through; as-built; fold moss bake values; final review; push.
T15 PROGRESS (2026-07-31 eve): HERO PAIR placed & accepted "works for now" — RimHero_Katsura (dominant, up-slope) + RimHero_Maple (companion) at the (-343,-55) mark, bake-style seating. BAMBOO GROVE placed & tuned: user compared XfBambooA (22.8k tris, single plant, golden culms) vs parked RealisticBamboo (10.2k tris, WHOLE multi-culm clump, script-clean) — B WON (deviation from plan's XfBambooA; XfBambooA stays the single-accent option, would need green culm tint RGB(140,190,125)-ish). Grove = 3 clumps at the NS pool retaining wall foot (-209/-207/-206, z -31/-23/-15), scales 4.93/4.34/4.68 (TEMPLATE BASE SCALE IS 4.93 — ScaleTo is ABSOLUTE, relative scaling must multiply the base; two clumps baked tiny before this was caught), shifted 4E off the face, SA tint RGB(195,200,180) approved + applied to FoliageKit.RealisticBamboo template (PlantDepth 0.8). Site clears the reserved pad keep-out's west edge (user confirmed intent: "occupant would be proud"). Moss PARAMS defaults folded (01e7a9b). BambooCompare display removed.
REMAINING: T15 step 4 arrangements pass (site grammar: bridge ends, path gates, pool mirror, stair companions, tunnel mouths — one pass then gate); T16 day+night walk-through, as-built (record the RealisticBamboo deviation), place save, push; final whole-branch review; clear DayNightLockT (0.19) before publish. PLACE SAVE PENDING (hero pair + bamboo + moss + shore rocks tint fixes since last save).
=== SESSION CLOSE (2026-07-31 night) ===
PLACE SAVED by user (carries: shore rocks 99 white + moss 1247 tinted terrain-only + FoliageZones->ServerStorage + ZenCanyonRock_RETIRED rename + hero pair + bamboo grove 3 clumps + template tints + display cleanups). User beat; clean close.
RESUME AT: T15 step 4 arrangements pass (site grammar sweep via foliageArrangements.luau: bridge ends, path gates, pool mirror, stair companions, tunnel mouths — ONE pass then user hand-tunes) → T16 day+night walk-through gate → as-built (record RealisticBamboo-not-XfBambooA deviation + all tuned values) → push branch (many unpushed commits) → SDD final whole-branch review (most capable model; point at ledger deferred minors) → finishing-a-development-branch. Clear DayNightLockT=0.19 before any publish. Materials cleanup (duplicate variant names, ZenGravel1 broken on 356 parts) parked to F&F item 8.
=== 2026-08-01 SESSION ===
PAD BAMBOO PASS (user-directed): 52 RealisticBamboo clumps along the terrain walls of all 14 teahouse pad slots (PadRefs at ServerStorage.Sandbox_PARKED.PadRefs; empirical wall detection = ground rise >=6 over pad top within 12 studs of edge; 2 clumps on 15+ walls, 1 on minor; wall-base seating; legacy-teahouse guard). CanyonWorld.Foliage.Heroes.PadBamboo. ~530k tris ceiling, occluded-by-design per user. GATE effectively passed via perf session (visuals not yet formally walked — check at final walk-through).
PERF A/B (Samsung emulation, T01 pad): full scene = LOCKED 60fps p95 17.4ms in steady state; two 44fps readings did NOT track the toggles (transient streaming/replication noise — the toggle-off phases replicate 52 models each way). Neither bamboo nor moss has measurable steady-state cost on this profile. Real-device test via dev place still the truth test.
MOSS SCATTER CUT (user decision after visual A/B at the river: "nothing is lost"): 1247 clumps PARKED at ServerStorage.ParkedFoliage.MossTransitions_2026_08_01. MossTransitions planner + buildMossTransitions tool stay COMMITTED + DORMANT (like the impostor system) — the seed logic (rock feet/crevices/waterline) is the siting guide for future hero moss. NEW DIRECTION: hero mossy ROCK PILES sculpted in Blender, 1-2 discoverable placements — future composition work, not started.
REMAINING unchanged: arrangements sweep, day+night walk-through, as-built (now also records: moss-scatter cut + pad bamboo + hero-pile idea), place save, push, final review, DayNightLockT clear.
WATERLINE PASS 2 (2026-08-01): user survey found the downstream HALF of the shoreline (159 of 358 edge cells, x > -90) had ZERO planting — the single Margin zone only spanned x -420..-90, so the planner was never asked. Also: the 0-2 stud band never existed (muhly parked, kit has nothing under 2.4 studs).
USER INSIGHT (the fix): the shoreline that reads well has ROBLOX TERRAIN GRASS painted into the bank with reeds standing in it — free to render, no instances. Grass paint extends a stud INTO the shallows (user: "a bit can be washing in the shallows").
Planner (982a52e, review APPROVED): per-species submergeMax (ferns 0 = dry feet; reeds 1.2 wade) with 4-attempt re-pick then skip; rockAffinity (compounds with careDensity) gathering plants at the ShoreRocks. 2 deferred minors: (a) grove member that fails all 4 submergence attempts still reserves memberSpacing = phantom crowding; (b) grove-path submergence has no automated test (reviewer probed it manually, found it sound).
Recipes: WaterMargin (wild) reweighted iris up / fern down + low tier at 0.5 scale + careDensity {0.5,0.7} + rockAffinity {5,1.4,0.9} + grassPaint {below 1, above 6}. NEW WaterMarginTended (zone MarginTended, x -90..220, 389 water cells) iris-led, spacing 6-11, careDensity {0.25,0.5}, rockAffinity {6,1.6,0.7}, grassPaint {below 1, above 4}.
HandTuned attribute added + stamped false on all baked output (99 rocks, 585 plants) so the checkbox is discoverable; wipe parks tagged instances, bake yields clearance, restores after.
BAKED: 592 placements (Margin 102, MarginTended 32) + 325 grass voxels over 551 columns, terrain snapshot at ServerStorage.TerrainBackup_Grass. AWAITING USER GATE. Watch: MarginTended 32 may read too sparse (careDensity 0.25 x rockAffinity 0.7 compounds hard).
WATERLINE REV 1 ACCEPTED (2026-08-01, user: "looks great"; earlier "really pleased with the overall look of the upper canyon"). Final: 605 placements (Margin 107, MarginTended 40) + 248 grass voxels / 442 columns, karesansui scrubbed (18 voxels back to sand), landward band wild 4 / tended 3, a stud into the shallows.
GRASS LOOK: Terrain.Decoration and Terrain.GrassLength are NOT scriptable in this Roblox version (not valid members) — Decoration may still exist in the Studio Properties panel as the blade on/off. Scriptable levers: Terrain:SetMaterialColor(Enum.Material.Grass, c) for tint, and a MaterialVariant base=Grass MaterialPattern=Organic for the ground texture under the blades. User flagged blades read "sharp and scattered" — UNRESOLVED, parked (engine owns the blade geometry).
PLACE SAVE NEEDED: re-bake + terrain paint + MarginTended zone + HandTuned stamps are all place-only. ServerStorage.TerrainBackup_Grass can be deleted once satisfied (it bloats the place).
LOD PASS (2026-08-01, user-approved "all-in at 33k"): poly census exposed that the expensive trees are expensive for DIFFERENT reasons, so two recipes:
 (A) lod_drop_duplicate.py — for assets shipping TWO near-identical foliage meshes (both sugi families: same card count, same material, same UV range, centroids 0.001 apart; only 5-10% of faces oppose so it is NOT backface double-siding, it is a jittered density double). Drop the dupe, GROW surviving cards 1.35x to put the leaf mass back, decimate trunk. Hero sugi 68k -> 32.5k.
 (B) lod_cards.py — for trunk-heavy assets with no duplicate (maple, katsura: trunk is 72-74% of cost). Halve cards with a SPATIAL hash (not index order), grow survivors 1.41x (area-preserving), decimate trunk 0.35. Maple 54k -> 21.1k, Katsura 57.5k -> 22.3k.
FBXs written to "Roshambo Reference/foliage/lod_2026-08-01/" (10 files) — AWAITING USER IMPORT into Studio, then kit swap + arrangement/recipe re-point.
Totals: 6 hero sugi 407k -> 195k; XfSugi40 58.8->30k; XfSugi25T 39->20.2k; maple 54->21.1k; katsura 57.5->22.3k.
GOTCHA: FBX round-trip re-imports at scale 0.01 vs the originals' 0.249 — normalise on import or the LOD is knee-high and reads as "invisible".
FRINGE LOD (2026-08-01) — the payoff of measuring PLACED cost instead of unit cost. Census of the built world: 7,524,827 tris of foliage, of which the WALL FRINGE is 64% (XfHinokiM 66 trees/19.5%, XfSugi40 20/15.6%, XfSpruceM 48/14.9%, XfFirM 45/13.7% = 4.79M across 179 trees). The heroes we optimised first are rounding error by comparison (6 hero sugi = 2.7%, XfMapleA = 1.4%, cherries not in the top 14). Fringe trees are also the BEST LOD candidates — backdrop mass against the canyon wall, never walked among — so ratios pushed harder than heroes: keep 0.40 of cards, grow 1.58 (= 1/sqrt(0.40), area-preserving), trunk 0.30. XfSugi40 needed BOTH tools chained (drop its duplicate foliage first, then halve what remains).
RESULT: fringe 4.79M -> 1.84M, saving 2,954,322 tris = 39% OF THE ENTIRE FOLIAGE BUDGET. Per tree: XfHinokiM 22,287->8,431; XfSpruceM 23,280->10,778; XfFirM 22,863->8,929; XfSugi40 58,760->18,125.
FBXs in "Roshambo Reference/foliage/lod_2026-08-01/" (14 files now) — AWAITING USER IMPORT.
LESSON: unit tri-count ranks assets wrong. Rank by (unit cost x placed count); a cheap tree planted 66 times outweighs a hero planted twice.
FRINGE EXTENT FIX (2026-08-01): user "there still aren't enough trees up there, especially at higher elevations". Diagnosis by histogram: density was NOT the problem — 20-28 trees per 100 ground cells at y 250-300 vs 5-8 at y 200-224. The problem was EXTENT: fringe zones stopped at z +-137 while the ground there is still climbing (y 284), and the plateau levels at y~300 from z +-200 out to at least z +-320. Everything past z +-137 — most of the visible skyline — was in no zone at all. Same class of bug as the waterline gap: a zone footprint that stops short.
KEY CORRECTION LEARNED THIS SESSION: a zone part's Y EXTENT IS IGNORED unless the part carries a `Vertical = true` attribute (readZones only then sets yMin/yMax). A zone is a 2D XZ FOOTPRINT and planting follows terrain to any elevation — FringeSouth's nominal 30-stud slab actually spans 131 studs of real ground. My first ghost display drew the part geometry and misled the user into thinking the zone was tiny.
Zones extended to z +-67..220 (area 23,100 -> 50,490 each); testing maxGroves 24/55/80 to hold density over the larger area.

=== RESUME POINT (2026-08-01 late, context exhausted; PLACE SAVED by user) ===

TWO BAKE-SAFETY DEFECTS FIXED TODAY — read these before running anything:
 1. GRID LATTICE (56367a0): the sample grid started at min-of-zone-bounds, so editing ANY
    zone moved the origin by a non-multiple of the 4-stud pitch and shifted EVERY sample in
    the canyon, silently re-rolling approved zones. Origin is now snapped to a fixed lattice.
 2. BAKE ISOLATION (2afde87): readZones SKIPPED unfiltered zones, so a filtered bake planned
    against a different world and produced different trees. Planning is now ALWAYS whole-world;
    the filter gates only wipe+stamp. Destructive modes REFUSE without an explicit target:
    zones = {"Margin"} for one, zones = {"ALL"} for everything. Verified: planning with ALL vs
    {fringe} vs {Margin} gives identical per-zone counts, 0 mismatches.
 PROCESS: the user approves RESULTS, not algorithms. Never treat a past "go" as standing
 permission. Name what a bake will change BEFORE running it. Plan-first caught a stationBand=2
 bug that would have emptied the waterline to zero.

WATERLINE = DONE for now (Margin 232, MarginTended 59, isolation verified each bake):
 shoreline stations ("a line of shuffled mixes marching along the shore" — the user's model,
 replacing area-scatter + monospecific clumps). stationBand 5 (stations hug water; NOTE the
 4-stud sample grid means any band <3 matches nothing and 3..6 are identical), spread 4,
 inland 0, stationSpacing 8 wild / 12 tended, members 4-7 / 3-5. Per-species nearWater (iris 4)
 and submergeMax (reed 1.2, fern 0) sort each handful wet-to-dry. Grass: own reach 5 +
 pathMargin 3, and repairPathGrass scrubs grass off built geometry retroactively (69 voxels).
 Iris: 23 north / 18 south, evenly spread — the "no iris on the north shore" was small-number
 gapping (one iris across 179 studs), NOT a bias; density cured it.

>>> NEXT: THE FRINGE (where we were interrupted) <<<
 State: WallFringe is per-sample scatter + clumping (clumpChance 0.55, clumpSize 4, spacing
 16-26). NOT a grove — a grove caps output at maxGroves x members and skipped plantable ground
 (user found 163/441 samples passing gates with 18 trees on them). Zones FringeNorth/South are
 x -460..-90, z +-67..220, 463 trees. A zone part's Y EXTENT IS IGNORED unless it carries a
 `Vertical = true` attribute — zones are 2D XZ footprints and planting follows terrain (these
 span ~140 studs of elevation, wall AND plateau).
 OPEN QUESTION the user wants to resume: fringe density/quality diagnosis.
 WESTERN END: terrain runs to about x -470 (nothing at -480). The FRINGE now reaches -460, but
 Core / CoreUnder / Margin all still stop at x -420, so the canyon head is unzoned for
 everything except the fringe. That is the gap the user means. East of the arena is a
 separate, known gap they intend to take later.

ALSO OPEN:
 - CLUMP CHILDREN INHERIT SPECIES WITHOUT RE-TESTING GATES (a fern was standing in water
   despite submergeMax 0). Real bug, small blast radius, not yet fixed.
 - LOD swap shipped: world foliage 7.52M -> ~4.9M tris. 13 models swapped, originals parked at
   ServerStorage.ParkedFoliage.PreLOD_2026_08_01. Two LOD tools in roblox/tools/blender/.
 - Arrangements rebuilt on the current palette (11, gallery at Sandbox.ArrangementGallery
   y=520); XfMapleGold/Red rebuilt on LOD geometry. Cliff dressing still NOT started.
 - Branch is far ahead of origin and UNPUSHED. As-built section still unwritten.

=== PERF/LOD AUDIT (2026-08-01, after the crevice-density question) ===
FLAG FIX APPLIED (Edit, place-only — needs a place save): 10 hero-sugi FOLIAGE cards had
 CastShadow+CanCollide+CanQuery+CanTouch ON (you could bump into invisible leaf cards, and
 alpha-tested shadow casting is the expensive kind). All four now OFF. The 10 hero-sugi
 TRUNKS keep CastShadow+CanCollide deliberately — opaque, solid, and you should not walk
 through a tree; only CanTouch was cleared.
NOT A DEFECT — 99 ShoreRocks with Shadow/Collide/Query ON are CORRECT and were left alone.
 Framing them as violations was wrong: the whole canyon casts shadows (Paths 7,284 casters,
 Structures 1,225, Arena 174). The blanket "all foliage flags off" rule is for CARDS you walk
 through, not for rock. Do not blanket-apply it again.
STREAMING: StreamingEnabled = true, but StreamingMinRadius / StreamingTargetRadius /
 StreamingIntegrityMode / ModelStreamingBehavior all read as "not a valid member of Workspace"
 from the MCP executor in BOTH Edit and Server datamodels. Read them off the Studio Properties
 panel instead. WHY IT MATTERS: CanyonWorld spans 677 studs in X, 451 in Z. Roblox's default
 target radius is 1024, so on defaults the ENTIRE canyon sits inside one streaming bubble from
 anywhere in it — nothing ever streams out and every tree is resident everywhere. Tuning the
 radius down would be a bigger win than any planting decision.
LOD STALENESS RESULT:
 - All 1024 Preserve (scatter-baked) clones MATCH the current FoliageKit. Nothing stale there.
 - *** ALL 6 HERO SUGI IN WORKSPACE ARE STILL PRE-LOD *** SugiB/C/D/E/F/Smart share ZERO
   meshes with the LOD kit and all 4 with ServerStorage.ParkedFoliage.PreLOD_2026_08_01.
   Cause: they are HAND-PLACED under Foliage/Heroes, so the re-bake that re-pointed every
   scattered tree never touched them. Kit LOD = 3 meshparts (dupe foliage dropped); placed = 4.
   Worth ~212k tris (ledger: 6 hero sugi 407k -> 195k) on the trees you walk right past.
   SWAP CAUTION: kit part count differs (3 vs 4), so re-point by cloning the kit template and
   matching pivot + visual size — ScaleTo is ABSOLUTE, and the LOD FBXs re-imported at scale
   0.01 vs the originals' 0.249.
 - 627 of 1024 Preserve plants sit on geometry with NO LOD version. ~291 of those are cheap
   ground cover (ReedClump 125, TallWeeds 62, WeedStalks 43, FernClump 20, IrisA/B 41).
   The real remaining target is the xFrog conifer AGE/SEASON VARIANTS, never LOD'd:
   XfSpruceYb 63, XfHinokiYb 61, XfFirYb 48, XfFirYr 25, XfHinokiMT 24, XfFirMT 21,
   XfSpruceMT 17, XfSugiYb 17, XfHinokiYr 9, XfHinokiT 4, XfMapleM 5 = ~294 trees.
   Only the M-size parents (XfHinokiM/XfSpruceM/XfFirM/XfSugi40) were ever LOD'd.
   XfMapleGold 24 + XfMapleRed 18 are already built ON LOD geometry (derived variants).
HERO SUGI LOD SWAP DONE (2026-08-01, user gate: side-by-side LODTEST_SugiF -> "that tree
 looks fine. swap the others as well"). All 6 (SugiB/C/D/E/F/Smart) re-pointed to the
 FoliageKit LOD templates. Verified: each now 3 meshparts (was 4), MeshIds match the kit,
 XZ drift 0.00, base drift 0.00, heights preserved (25.8/30.7/34.8/40.2/44.1/26.1).
 ~212k tris recovered on the six trees closest to ArenaSpawn (34-88 studs).
 Originals parked at ServerStorage.ParkedFoliage.PlacedHeroSugi_PreLOD_2026_08_01 (reversible).
 The scale gotcha did NOT bite: kit templates measure 44.3 vs the placed 44.1 (factor 0.995),
 so the LOD FBXs were already normalised at import time.
 METHOD for any future hand-placed re-point: align by BOUNDING BOX (same XZ centre, same base
 Y) rather than by pivot -- the FBX round-trip moves the model origin. Apply the original's
 yaw, ScaleTo(GetScale() * targetH/currentH) since ScaleTo is ABSOLUTE.
 GOTCHA: copying attributes from an imported model throws "Attempt to assign attribute
 RBX_ReimportId. CoreScript permission required" -- skip any attribute matching ^RBX_.
 That error aborted a first run mid-loop and left an orphan LOD clone in Heroes; the retry
 script detects orphans by kit-signature match and removes them first.
PLACE SAVE NEEDED for the flag fix + the hero swap (both place-only).
SANDBOX SCAFFOLDING PARKED (2026-08-01): Workspace.Sandbox was 9,815 parts = 38% of the
 loaded workspace, dominated by PadOccupancyPreview (8,845 parts / 14 materialized teahouse
 sites / 4,477 VISIBLE / all inside Persistent models so NO streaming setting could evict
 them). Moved whole to ServerStorage.Sandbox_PARKED_2026_08_01 (not replicated; reversible).
 Workspace 25,703 -> 12,422 parts. All of it regenerates from committed tools.
 LESSON: my own diagnostic rigs were half the world and were polluting every perf reading.
PERF BASELINE (desktop Studio, 2026-08-01, AFTER parking, at FallsLanding x-425 y250 z-48
 looking E = the longest view in the canyon): render 16.7 ms PINNED across 6 samples (= vsync
 60fps), CPU 16.6, GPU 10.2, 887 draw calls, 10.2M triangles, 11,532 canyon parts.
 So desktop has ~40% GPU headroom at the worst vantage. TABLETS UNTESTED - user has two.
 MEASUREMENT TRAPS HIT: (a) a 92.5 ms render reading was a stream-IN transient caught in a
 rolling average, not steady state - always let it settle and sample repeatedly; (b)
 FrameRateManager/AverageFPS is a very long-window average (sat at 24-25 across wildly
 different scenes) - USE RenderAverage / CPU / GPU / Batches instead.
STREAMING CONCLUSION: leave StreamingTargetRadius at 1024. Lowering it does nothing --
 content already loaded is never evicted on desktop (1024 -> 400 changed loaded parts by 21),
 and at 400 the user saw draw-in at the east end on a re-join. The 814-stud diagonal I sized
 it from was wrong-headed: what matters is distance from where a player STANDS, and the
 farthest part from spawn is only 549 studs.
LOD BATCH 2 BUILT (2026-08-01, user-approved): the xFrog age/season VARIANTS were never
 LOD'd -- only the M-size parents. Census of all 11 un-LOD'd variants = 2,274,461 placed tris
 across 294 trees (~half of all remaining foliage). Cost is CONCENTRATED: 5 trunk-heavy
 species carry 63% on just 71 trees. Built those 5 with lod_cards.py at the fringe ratio
 (keep 0.40 / grow 1.58 / trunk 0.30); none had duplicate foliage meshes so no chaining.
 RESULT 1,439,269 -> 529,414 placed tris = 909,855 saved (63%).
   XfHinokiMT 18,354->6,387 x24 | XfFirMT 20,665->7,381 x21 | XfSpruceMT 16,567->6,965 x17
   XfMapleM 38,001->12,584 x5 (THREE trunk meshes) | XfHinokiT 23,291->9,950 x4
 DELIBERATELY SKIPPED the 6 young/small variants (XfSpruceYb 63, XfHinokiYb 61, XfFirYb 48,
 XfFirYr 25, XfSugiYb 17, XfHinokiYr 9 = 223 trees, 835k tris): 2.6-7k tris each, and card
 culling is exactly where a small tree goes thin. Poor ratio of risk to reward.
 FBXs in "Roshambo Reference/foliage/lod_2026-08-01_batch2/" -- AWAITING USER IMPORT, then
 kit swap + re-bake of the affected zones (explicit zones = {...} target, per bake isolation).

=== LOD CORRECTION PASS (2026-08-01, after the crevice-density question) ===
THE HEADLINE: the "LOD" work done earlier today and on 2026-08-01 morning was the WRONG
 TOOL. roblox/tools/blender/export_tree.py already does all of it properly, from the
 vendor OBJ, and its comments describe the exact failure we hit as a solved problem:
   "wood mode 3 (PROPORTIONAL): bole, branches and root flare each get their OWN
    decimation budget. Sharing one budget starves whichever the source happens to be
    heavy in -- it cost the sugi half its canopy once."
 lod_cards.py / lod_drop_duplicate.py throw ONE Decimate at the whole trunk, so the bole
 starves. RULE: to make a kit tree cheaper, LOWER ITS BUDGETS IN export_forest_kit.sh AND
 REGENERATE. Never post-process a finished FBX.
DAMAGE ACTUALLY FOUND (measured, not assumed -- I twice generalised from a small sample
 and was twice wrong; the user caught both):
   XfHinokiM  bole 1321v/83% -> 7v      | XfSpruceM 1761v/90% -> 10v | XfFirM 1758v/80% -> 4v
   ALL THREE REBUILT and user-gated ("the rebuilt ones look good").
 NOT damaged, confirmed against their own originals: the 6 hero sugi (Trunk1 96-99%),
 XfSugi25T (95%), XfMapleA + XfKatsuraA (every trunk within 0.1% of the original).
 XfSugi40: the bole METRIC failed it (2341v -> 46v) but the user looked and kept it --
 "It has a full trunk... at 18.1K it's a keeper". The bole was FRAGMENTED into several
 components, not collapsed. LESSON: "largest component spans the tree" cannot tell
 fragmentation from destruction. Look before condemning.
FRINGE REBUILD SHIPPED IN THE SCRIPT: export_forest_kit.sh gained a FRINGE section
 (XfHinokiM/XfSpruceM/XfFirM were exported ad hoc long ago and were missing from it) at
 7000 fol / 7000 wood / spray 1.36, down from 13000/10000. Per tree 22,287->14,243,
 23,280->12,636, 22,863->13,013. vs the 332 placed BROKEN LODs this ADDS ~1.22M tris;
 vs the pre-LOD originals it still saves ~3.2M. AWAITING USER IMPORT of 3 models.
 XfFirM incidentally gained detail: the vendor has 11,680 cards, the old ad-hoc export
 only ever had 6,432.
BATCH 2 (XfHinokiMT/XfFirMT/XfSpruceMT/XfMapleM/XfHinokiT) DROPPED. Why: …T/…MT means
 SKIRT-TRIMMED (export_forest_kit.sh, skirt fraction A=0.26 M=0.32, canopy floor 5.5-6.5
 studs vs player eye ~5). They are ALREADY reduced once, for sightlines in PreserveCore.
 Culling them again compounds the thinning, and what cost remains is trunk, which on a
 conifer cannot be cut. Untrimmed M models go in WallFringe; trimmed MT/T in PreserveCore.
CROSSED CARDS -- DO NOT "DEDUPE" FOLIAGE. XfHinokiM is 100% crossed pairs, XfHinokiMT 98%:
 coincident cards with PERPENDICULAR normals (median dot 0.0), i.e. X-billboards so a
 needle spray reads from any angle. NOT duplicates, NOT backfaces. Dropping one of each
 would gut every tree side-on. (The sugi's double IS real but JITTERED ~0.001 apart, which
 is why a strict coincidence test scores it 0%.)
 CONSEQUENCE: culling by loose part splits crosses and leaves LONE FLAT QUADS.
 Measured on XfHinokiM: shipped lod_cards output 50.8% lone arms; export_tree.py output
 100% lone arms; cross-aware culling 0% at the SAME triangle budget. lod_cards.py is now
 cross-aware (groups coincident cards, keeps/drops whole crosses, grows about the cross
 centre; 6th arg 0 restores the old behaviour for A/B). export_tree.py is NOT yet
 cross-aware -- OPEN, and the single biggest remaining lever on how the trees LOOK.
NEW SHARED MODULE roblox/tools/blender/lod_trunk.py (bole-preserving decimation +
 bole_health diagnostic), used by lod_cards.py and lod_drop_duplicate.py. Both of those
 are now second-choice tools; prefer regenerating from export_forest_kit.sh.
KIT SCRIPT VERIFIED (2026-08-01): export_forest_kit.sh had a STALE XFROG default -- the
 library moved into Roshambo Reference/foliage/, so the script would die on model 1 unless
 XFROG was exported by hand. Fixed. Full run then completed clean (17 models, exit 0) and
 REPRODUCES the 3 approved fringe rebuilds exactly (7002/7241, 7002/5634, 6918/6095) and
 the canopy+brush models identically to the assets already in the world (XfHinokiMT
 8828/9526, XfSpruceMT 7452/9115, XfFirMT 10846/9819, XfHinokiT 11888/11403).
 *** CAVEAT: THE DECIDUOUS ACCENTS DO NOT MATCH. *** Script gives XfMapleM a 3,286-tri
 trunk; the file in the world has 26,021 across THREE trunk meshes (foliage matches exactly
 at 11,980). Same suspicion for XfMapleA / XfKatsuraA / XfKatsuraM. They were built with
 different wood settings, probably pre-mode-3. DO NOT regenerate the accents from this
 script until that is reconciled. (It also explains why my broken trunk decimation did no
 harm to XfMapleM this morning: its trunk was never processed like the conifers'.)
 Verification output left at Roshambo Reference/foliage/kit_verify_2026-08-01/ -- safe to
 delete; it is a full regeneration, not the shipping kit.
CROSS-AWARE CULLING SHIPPED IN export_tree.py (2026-08-01, user-gated "crosses look fine").
 The card-thinning loop rolled its LCG PER ISLAND; a cross is two coincident-but-
 unconnected islands, so ~half of all crosses were split, leaving lone flat quads that
 vanish edge-on. Now: group coincident islands into crosses, roll ONCE per cross. Budget
 unaffected (keeping `frac` of crosses keeps `frac` of cards). Every conifer reports a
 clean avg 2.00 arms/cross, so the construction is uniform across the kit.
 MEASURED on XfHinokiM at 7k, SPRAY 1.0 (spray must be OFF to measure: it anchors cards
 at their INNER vertex, which moves centroids and breaks any coincidence test -- that
 artifact is why I first reported 100% lone arms; the true figure was 46%):
   before 3501 cards / 1613 lone (46.1%)  ->  after 3458 cards / 0 lone (0.0%)
 Shipping fringe FBXs are now *_x.fbx in Roshambo Reference/foliage/fringe_rebuild_2026-08-01/
   XfHinokiM_x 14,157 | XfSpruceM_x 12,562 | XfFirM_x 13,011  (the _lite files are the
   superseded split-arm versions -- do not import those).
 OPEN/OPTIONAL: every OTHER kit model in the world was also built with split crosses
 (XfHinokiT, XfHinokiMT, XfSpruceMT, XfFirMT, XfSugi25T, the Yb brush, the accents).
 Regenerating them cross-aware is a pure quality win at equal triangle cost, but it means
 re-importing ~13 more models. Not proposed yet; the fringe was the damaged set.
FRINGE SWAP EXECUTED (2026-08-01, place-only, needs a place save). User imported
 XfHinokiM_x / XfSpruceM_x / XfFirM_x with foliage DoubleSided=true, wood false.
 DELIBERATELY *NOT* A RE-BAKE: a bake of FringeNorth/South would have re-rolled all 463
 plants in them, including the 131 (XfSugi40 55, XfFirYr 25, XfMapleGold 24, XfMapleRed 18,
 XfHinokiYr 9) we had no reason to touch, and those positions were approved. Instead the
 332 placed clones were swapped IN PLACE, bbox-aligned, exactly like the hero sugi.
 RESULT: 332 swapped, worst XZ drift 0.0000; 0 mesh mismatches vs the new kit; 0
 DoubleSided errors; 0 engine-flag violations; zone populations unchanged (FringeNorth 228,
 FringeSouth 235, Core 77, CoreUnder 160, Margin 232). Foliage parts 2322 -> 2316 (the
 duplicate arm geometry). Old templates parked at ServerStorage.ParkedFoliage.
 FringePreCross_2026_08_01.
 DOUBLE-SIDED CONVENTION (surveyed, already consistent across the canyon, keep it):
 foliage MeshPart DoubleSided = TRUE, wood = FALSE. Preserve was already 100% compliant
 (FringeNorth 228/318, FringeSouth 235/284, Core 77/77, CoreUnder 160/160). Setting it on
 the KIT TEMPLATE is what propagates it, since a bake clones the template.
 MINOR/DEFERRED: Foliage.Heroes is untidy - 1 foliage part with DS off, and wood 114 on /
 51 off where every other layer keeps wood false. Hand-placed drift, not the bake.
 Also prep_foliage.py cites CanyonWorld.WaterFoliage as its example path; no such folder
 exists any more.
>>> AWAITING USER LOOK at the fringe in Studio (north side, south side, and from
    FallsLanding looking east = the longest sightline onto it).

*** TREE IMPORT FINISHING CHECKLIST — DO ALL OF IT, EVERY TIME ***
 (2026-08-01: I did step 2 only, because that was the step the user happened to ask
  about, and shipped 332 trees whose leaf cards rendered as SOLID OPAQUE RECTANGLES.
  Geometry/flags/positions all verified clean — none of those checks can see a material
  binding. The checklist is in export_tree.py's header; READ IT, do not recall it.)
 For each MeshPart of a freshly imported tree:
  1. SurfaceAppearance with ColorMap = the importer's TextureID, then CLEAR TextureID
     (a live TextureID overrides the SurfaceAppearance and washes the mesh out).
       foliage -> AlphaMode = Transparency   (this is what cuts the leaf cards out;
                                              without it the alpha is ignored entirely)
       wood    -> AlphaMode = Overlay        (part.Color TINTS under Overlay, so carry
                                              the old Colour across; under Transparency
                                              part.Color is INERT)
  2. DoubleSided = TRUE on foliage, FALSE on wood. Cards are single-sided planes.
     CAVEAT: DoubleSided also enables transmission shading — right for dark needles,
     blows out PALE foliage (the sakura incident). Dark conifers: true.
  3. RenderFidelity = Automatic; CastShadow/CanCollide/CanQuery/CanTouch = false.
  4. Normalise height against the template it replaces (ScaleTo is ABSOLUTE).
 VERIFY BY COMPARING TO AN UNTOUCHED NEIGHBOUR, not to a rule I remember: read a tree
 from a zone that was not part of the change and diff the material setup against it.
CREVICE FIX SHIPPED (2026-08-01, user-gated "crevices looking better", place saved).
 COMPLAINT: "northern crevices are still pretty empty; so are some of the SE ones. And
 the West end really needs some work." — THREE complaints, THREE different causes:
  1. NORTHERN CREVICES = a GATE, not density. Measured at 20-stud cells inside the fringe
     zones: relief <8 studs -> 1.81 trees/cell, 8-20 -> 1.96, >=20 (crevice) -> 1.20, with
     58 crevice cells empty outright. Not slope (theirs run 0.12-0.74 vs maxSteep 0.9) and
     not missing terrain (ring probes 8/8). It was footingMaxDrop=6: gully walls fall 2-3
     studs per stud, so at footingRadius 3 the drop underfoot is 6-9 and the gate refused.
     PLAN SWEEP (mode="plan", stamps nothing) 6->426 fringe trees, 10->548, 14->579,
     20->563, 30->562. SATURATES at 14 -> chose 14. Baked zones={FringeNorth,FringeSouth}:
     228->284 and 235->295 (579 total), 147 untargeted zone folders BYTE-IDENTICAL.
     NOTE the tool takes a `recipes` override (opts.recipes.WallFringe = {...}) — plan
     variants WITHOUT editing any file. Use that, not string replacement.
  2. SE CREVICES = NO ZONE AT ALL. FringeNorth/South stop at x -90; the canyon runs east
     to about +220. 59 empty out-of-zone cells north, 56 south. This is the known
     east-of-arena gap; it needs NEW zone geometry, not a fix. Not started.
  3. WEST END = the centre band is unzoned. Zone coverage begins at x -410; terrain runs
     to about -470. The FALLS HEAD is a 40-stud strip x -450..-410, z +-60, climbing
     y 208 (pool) -> 291 (head), touched by nothing. User's own point, confirmed: a plain
     rectangle extension of Core/CoreUnder/Margin WOULD cover it geographically but with
     the WRONG RECIPES — slopes there hit 0.80 and Margin is a waterline recipe that would
     run shoreline stations 80 studs up a headwall. The headwall probably wants its own
     recipe. NOT DONE.
*** BLOCKER FOUND — water=0 *** Every plan/bake now reports `water=0` and Margin +
 MarginTended produce ZERO placements, though 105 terrain water voxels sit at y~206,
 x -416..-424, z -24..-40 (the falls pool) and the river obviously exists. readWaterCells()
 is finding nothing. CONSEQUENCE: a bake naming Margin/MarginTended would WIPE the approved
 waterline. Isolation protects us (destructive modes refuse without an explicit target and
 only touch what is named) but DO NOT run zones={"ALL"} until this is understood.
 Diagnose this BEFORE any west-end work, since the falls-head margin depends on it.
water=0 SOLVED (2026-08-01) — AND IT WAS SELF-INFLICTED. readWaterCells() reads
 Sandbox.WaterMap.WaterMarkers, and I had parked Workspace.Sandbox wholesale into
 ServerStorage during the perf clean-up. 840 of those 9,776 "diagnostic rig" parts WERE
 the water index that scatterPreserve (x2: water cells + grass), buildShoreRocks and
 buildMossTransitions all depend on. I audited the part COUNT and never asked what READ
 from them. The tool even warns "[preserve] no Sandbox.WaterMap.WaterMarkers — water rules
 inert"; the warning never surfaced in what I read back.
 FIX: WaterMap now lives at ServerStorage.WaterMap beside FoliageZones (authoring data,
 not viewport geometry — and its 840 markers were already Transparency=1 + CanCollide off,
 so parking them saved NOTHING on render). All FOUR lookup sites now check ServerStorage
 first and fall back to the legacy Workspace.Sandbox path.
 VERIFIED: plan now reports water=840; Margin planned 218 vs 232 placed, MarginTended 58
 vs 59 — the approved waterline is essentially reproducible again.
 LESSON: before parking/deleting anything, grep for what READS it. "It's only diagnostics"
 is a claim to verify, not assume.
 RESIDUE: the fringe bake ran while water was missing, so FringeSouth (283 planned vs 295
 placed) has trees standing closer to the river than waterMargin=4 intends. Cosmetic;
 FringeNorth is exact (284/284). Re-bake zones={"FringeSouth"} if it shows.

=== RESUME POINT (2026-08-01 end of day; PLACE SAVED by user) ===
TODAY, in order: hero-sugi LOD swap -> perf measurement -> the LOD disaster and its repair
 -> fringe crevice fix -> water=0. Five commits: e4f3e54, a8aa656, 3ed82a6, 223aa07, 2dcd967.
STATE OF THE FOLIAGE: fringe rebuilt at 579 trees (FringeNorth 284 / FringeSouth 295) on
 regenerated XfHinokiM/XfSpruceM/XfFirM with real boles and whole crosses; 6 hero sugi on
 LOD; waterline untouched and reproducible again; Sandbox scaffolding parked (WaterMap
 rescued back out); all 332 fringe clones + 3 kit templates pass the material/flag audit.
>>> NEXT, in the order the evidence points:
 1. WEST END / FALLS HEAD. 40-stud strip x -450..-410, z +-60, y 208->291, in NO zone.
    User's own point: a plain rectangle extension of Core/CoreUnder/Margin covers it
    geographically but with the wrong recipes (slopes to 0.80; Margin is a waterline
    recipe). Probably wants its OWN headwall recipe. Water at the pool is now visible to
    the planner again (105 voxels ~y206, x -416..-424), so a falls-pool margin is possible.
 2. FringeSouth re-bake (283 planned vs 295 placed) — that bake ran while water=0, so
    waterMargin=4 was not enforced. Cosmetic. zones={"FringeSouth"} only.
 3. EAST OF ARENA / SE crevices: needs NEW zone geometry from x -90 to +220 on both walls.
    115 empty out-of-zone cells. A pass of its own.
 4. TABLET PERF MEASUREMENT — never done, and it is the thing that actually decides
    crevice density. Desktop at the longest view (FallsLanding looking E) sits at 60fps
    with GPU 10.2ms of a 16.7ms budget. User has two tablets. Scaffolding is out of the
    world now so the numbers would finally be honest.
 5. Optional: regenerate the REST of the kit cross-aware (canopy MT/T, Yb brush,
    XfSugi25T, accents). Free in triangles, ~13 imports for the user. Pure upside.
STILL OPEN FROM BEFORE: clump children inherit species without re-testing gates (a fern
 stood in water); cliff dressing never started; Foliage.Heroes flag untidiness (1 foliage
 part DS off, wood 114 on / 51 off); deciduous accents do NOT reproduce from
 export_forest_kit.sh (trunks differ) so do not regenerate them without reconciling.
BRANCH IS STILL UNPUSHED and far ahead of origin. As-built section still unwritten.

USER NOTES FROM A WALK-THROUGH (2026-08-01 evening, captured, NOT yet acted on):
 A. CULL THE PLATEAU TREES. "a lot of trees on the top of the terrain, well back from the
    view from the canyon, that we should cull. We might get rid of a hundred that way."
    LIKELY CAUSE: the fringe zones were extended z +-137 -> +-220 on 2026-08-01 to reach
    "higher elevations", and z ~200+ is the dead-flat PLATEAU TOP (measured y 296-303,
    slope 0.01-0.05). Those trees sit behind the rim and are never seen from inside the
    canyon, so they are pure cost. Two possible fixes: pull the zone Z extents back in, or
    add a visibility/rim rule that culls anything more than N studs beyond the rim break.
    The second is better — the rim meanders, a rectangle does not. Measure first: how many
    of the 579 fringe trees stand on plateau-flat ground beyond the rim?
 B. SKYBOX — user wants to discuss finding or creating one. Constraints to bring to that
    conversation: the arena is NIGHT-FIRST (see [[roshambo-night-first-arena]]) with day as
    a short interlude, so any sky has to carry BOTH and work with the nightFactor day/night
    cycle; a Roblox Sky object takes 6 face images (upload moderation applies — see the
    green-palmate-foliage takedown); and the canyon is a deep gorge, so the sky is mostly
    seen as a strip between rims plus whatever the downcanyon overlook frames.

=== PLATEAU CULL + SKYLINE IMPOSTOR CANDIDATES (2026-08-02) ===
72 OFFSTAGE TREES PARKED. Visibility-tested against 134 viewpoints (canyon floor at
 z -40/0/+40 every 30 studs, plus every level standable Paths/Structures surface at eye
 height). 72 of 579 fringe trees are visible from NOWHERE a player stands, ~1.11M tris,
 86% at |z| 160+ and 96% at y 280+ — i.e. the plateau top behind the rim, exactly as the
 user reported from their walk. Parked (NOT deleted) to
 ServerStorage.ParkedFoliage.OffstagePlateau_2026_08_02, FringeNorth 44 / FringeSouth 28,
 each carrying ParkedFromZone + ParkedPivot so a restore is exact. Fringe 579 -> 507.
 *** MEASUREMENT TRAP, cost me two wrong answers: stray parts parked at the WORLD ORIGIN
 (Paths/Flags_7 at 0,0,0) became "viewpoints" underground, and a Roblox raycast STARTING
 INSIDE terrain reports NO HIT — so they "saw" plateau trees through solid rock and the
 count came out 19 instead of 72. Filter viewpoints by Position.Magnitude > 40. Also my
 first walkable filter found 3 usable surfaces out of 9,000 parts; check the sample size
 before trusting a visibility result. ***
SKYLINE vs AGAINST-ROCK — the split that actually matters. For each visible tree, continue
 the sightline PAST it: open sky behind = skyline, terrain behind = against-rock.
   SKYLINE      362 trees, 5.22M tris — small and high (263 at y 280+), IS the wooded rim
   AGAINST ROCK 145 trees, 2.07M tris — large and low (129 at y 160-260), walked past
 CONCLUSION: do NOT cull the horizon, DOWNGRADE it. 72% of fringe cost is 362 full-detail
 trees never seen closer than a couple of hundred studs.
IMPOSTOR PLAN (bake_clump_tree.py — clusters sprays, bakes an RGBA atlas, rebuilds the
 canopy as 3 CROSSED PLANES per clump at ~6 tris each; crossed because a MeshPart cannot
 billboard). Marked with attribute + CollectionService tag "SkylineImpostorCandidate";
 re-select any time via CollectionService:GetTagged.
 NEAREST-APPROACH FILTER at 80 studs (impostor planes betray themselves close up):
   105 held back, tagged "SkylineNearTrail", stay full detail
   257 impostor set, 3.71M tris -> ~771k at 3k each = ~2.94M saved
 RECOMMENDED SCOPE: the 4 conifers carry 234 of 257 (XfSpruceM 70, XfHinokiM 70,
 XfFirM 67, XfSugi40 27) = ~2.6M saved from FOUR builds. Skip the 23-tree tail of maples
 and Yr variants — not worth a bespoke atlas upload each.
 BUILD NOTE: bake from a FULL-DETAIL export, never from the placed _x models — those keep
 only 40% of crosses and the atlas tiles would come out sparse. Impostor density lives in
 the IMAGES, not in surviving geometry.
 THE 80-STUD CUT IS A JUDGEMENT, NOT A MEASUREMENT — user gate it. Distribution: <40 studs
 29 trees, <60 59, <80 105, <100 154, <150 267, <200 358.

=== cullOffstage: THE CURATION IS NOW REPRODUCIBLE, NOT PROTECTED (2026-08-02) ===
PROBLEM: a bake owns its zone folders and rebuilds them wholesale, so the 72 parked trees
 would be re-planted and all 362 tags lost on the next FringeNorth/FringeSouth bake.
 HandTuned exempts hand-ADJUSTED instances, which is not our case (we removed trees and
 applied derived tags). KeepOut zones cannot help: the trees we keep and the ones we drop
 sit at the SAME elevation and the SAME |z| — only visibility separates them.
SOLUTION, following the cullWaterMargin precedent: re-derive instead of defend.
  roblox/tools/builders/OffstageCull.luau  — pure, raycasting INJECTED, 9 Lune tests
  roblox/tools/studio/cullOffstage.luau    — Studio shell, dryRun by default
 *** RULE: A FRINGE BAKE IS NOT FINISHED UNTIL cullOffstage HAS RUN. *** Same as the
 waterline, where the bake and cullWaterMargin are two halves of one operation.
VALIDATED AGAINST A HUMAN-GATED ANSWER, which is the whole reason this was testable
 without any impostor existing: restored the 72 parked trees, cleared all 362 tags, ran
 the tool on a world it had never seen -> OFFSTAGE 72 (exact) and SKYLINE 257 (exact).
 Held/rock came out 106/144 against the manual 105/145: ONE borderline tree crosses the
 sky/rock line because the tool picks its best viewpoint by distance-to-BASE where the
 ad-hoc script used distance-to-TARGET. Two dry runs byte-identical.
 BUG THE TEST CAUGHT: my shell aimed the sightline at base + height*0.15 (the lower
 TRUNK) where the ad-hoc script had used boundingBox.Position + height*0.15 = base +
 height*0.65 (the upper CANOPY). Same constant, different origin. It reported 210
 offstage instead of 72 — the trunk is occluded long before the crown is. targetFrac is
 now 0.65, measured explicitly from the base, with the reason in the file.

=== SKYLINE: IMPOSTORS TRIED AND REJECTED; CHEAP ADULTS CHOSEN (2026-08-02) ===
IMPOSTORS (bake_clump_tree.py) got as far as four built assets and were rejected by eye.
 FOUR BUGS FIXED ALONG THE WAY, all from the script being written for one asset at one
 scale and never run on Roblox-scale input (1 stud = 0.01):
  1. CAMERA NEAR CLIP. Bake cam sits at rad*8 = ~0.08 units; Blender's default near plane
     is 0.1, so the clump was clipped away and THREE OF FOUR ATLASES BAKED 100% EMPTY
     (impostors rendered as blank cards). Only the sugi escaped, its coarser cell putting
     the cam at 0.16. Clip planes are now derived from clump radius.
  2. AgX VIEW TRANSFORM applied on save — a film tone-mapper, not what a texture bake
     wants. Sugi atlas came out [84,80,14] against the source's [102,107,32]. Now
     view_transform = "Standard"; every atlas lands within a couple of points of source.
  3. CARD/FRAME MISMATCH. Tile rendered at ortho_scale rad*2.2 (half-width 1.1*rad) but
     cards built at 1.5*rad -> every clump image drawn 1.36x oversized. CARD_FRAME is now
     derived from CAM_FRAME.
  4. (DIAGNOSED, NOT FIXED) CLUMP RADIUS IS FLOORED BY THE GRID: rad = max(actual spread,
     cell*0.35), so sparse buckets get an inflated radius, the camera frames mostly empty
     space, and the needles come out magnified. User: "during the process the size of
     actual needles on the cards is growing". Root cause of the look, unfixed.
 WHY REJECTED even after 1-3: user judged them "much brighter and fuller than the
 references". Structural reasons, none of them a dial: only 4 baked photos shared across
 373 clumps (~90 reuses each); a flat white world bakes NO self-shadowing so clumps have
 no shaded side; and ONE SNOWFLAKE IS 12.6% OF TREE HEIGHT (1.5 units on a 12-unit tree),
 three planes deep and overlapping its neighbours.
 KEY INSIGHT that settled it: the user accepted spray 1.94 on a cheap adult, which
 ENLARGES each spray card — so enlarged cards are NOT the problem. A spray is 1-2% of
 tree height; an impostor card is 12.6%. It is card SIZE, not card enlargement.
CHOSEN INSTEAD — CHEAP ADULTS, same pipeline, no new technique:
   export_tree.py at foliage 3500 / wood 3000 / spray sqrt(total/kept), height 20
   XfHinokiM 14,157 -> 5,429 | XfSpruceM 12,562 -> 5,016 | XfFirM 13,011 -> 5,157
   (38-40% of current cost; keeps ~26% of cards, each grown ~1.94-2.58x)
 FBXs in "Roshambo Reference/foliage/skyline_2026-08-02/" — AWAITING USER IMPORT of 3.
 XfSugi40 REFUSED TO CHEAPEN: a 12,000-budget export came out 126 tris HEAVIER (18,251 vs
 18,125) because its 38,780 sprays need most of that budget to avoid going bald. User:
 "why bother with Sugi if it's larger? Let's just remove Sugi from the skyline entirely."
 Now enforced REPRODUCIBLY via cullOffstage CONFIG.skylineExclude = { XfSugi40 = true } —
 a re-bake cannot reintroduce them. Barred 40 (all skyline sugi, near-trail included).
 STATE: fringe 507 -> 467, parked 112 (72 offstage + 40 sugi), skyline set 230 tagged,
 93 held near trail. Expected saving once swapped ~2.39M (611k + 528k + 526k + 725k).
SKYLINE SWAP SHIPPED + MADE REPRODUCIBLE (2026-08-02, user: "they look fine").
 207 tagged skyline trees swapped in place onto the cheap variants (XfHinokiM 70,
 XfSpruceM 70, XfFirM 67). Worst XZ drift 0.0000; audit of all 207 against the import
 checklist: 0 problems (meshes, SurfaceAppearance, AlphaMode, ColorMap, cleared
 TextureID, DoubleSided, engine flags, RenderFidelity).
 IMPORTS ARRIVED WITH SurfaceAppearance = NONE AND TextureID SET — the same state that
 shipped opaque cards on 2026-08-01. The swap applies the checklist itself now rather
 than trusting the import.
 KIT: the cheap variants are SEPARATE templates (XfHinokiM_sky etc). The full-detail
 templates are untouched and are still what a bake plants — verified different.
 REPRODUCIBILITY CLOSED: cullOffstage gained CONFIG.skylineSwap mapping species -> cheap
 template, applied after tagging, guarded by the SkylineVariant attribute. Verified
 IDEMPOTENT: two consecutive full applies on the finished world both reported 0 parked /
 0 swapped and left it BYTE-IDENTICAL. (Skyline 230 -> 229 on the first run: one tree
 crossed the sky/rock line because the swapped geometry has a slightly different bbox
 and therefore a different aim point. It settles immediately.)
 SO THE FRINGE PROCEDURE IS NOW: bake FringeNorth/FringeSouth -> run cullOffstage. The
 second half is not optional; without it the skyline reverts to full-detail trees.
 FINAL STATE: fringe 467 trees (207 cheap skyline, 93 near-trail full, 145 against-rock
 full), 112 parked (72 offstage + 40 sugi). ~2.39M triangles recovered today.

=== WEST END / FALLS HEAD DONE (2026-08-02, user: "pretty good... let's run with it") ===
SURVEY FIRST — the west end is NOT empty. It carries NW80FallsStair (117 parts + 325 of
 railing), NWFallsWall (114), FarWallBridge2, a swing, chochin poles, HeroFall rocks/VFX,
 FallsAudio, and Arena.FallsLanding at (-432, 252, -26) — the overlook — plus 90 plants
 already west of x -400. The real gap was only the HEAD BOWL: x -460..-420, z +-62,
 y 243..307, where Core/CoreUnder/Margin all stopped at -420.
 Corrections to my earlier reading: it is NOT uniformly steep (only 10 of 45 probes exceed
 PreserveCore's maxSteep 0.55), and MARGIN WOULD BE A NO-OP out there — water reaches only
 x -422, so the shoreline pre-pass finds no shore. The `--` holes in the probe grid at
 x -434..-428 are the falls gorge: no terrain, so nothing could plant there anyway.
 *** readBuiltCells SCANS ONLY Paths + Structures. FallsLanding lives under ARENA, so the
 planner is BLIND to it and would have planted trees through the overlook platform.
 Fixed with an explicit KO_FallsLanding keep-out (bbox + 6 stud pad). Anything built under
 Arena has this problem — check before baking near it. ***
APPROACH: created NEW zones rather than extending Core/CoreUnder west. Extending would
 have re-baked all 77 existing Core trees for the sake of 40 studs of new ground; two new
 zones touch nothing. HeadBowl (PreserveCore) + HeadBowlUnder (PreserveBrush), both
 x -460..-420, z +-62, plus KO_FallsLanding.
 PLAN CONFIRMED THE LATTICE FIX: with the new zones added, Core still planned 77 against
 77 placed and all four groves matched exactly — new zones do not perturb the old plan.
RESULT: 56 plants (HeadBowl 14 canopy, HeadBowlUnder 42 brush), y 220..306, 149 untargeted
 zone folders byte-identical. Canopy drew the TRIMMED models (XfHinokiMT 4, XfHinokiT 3,
 XfSugi25T 2, XfSpruceMT 1) which is correct for ground a player walks to reach the
 overlook; brush filled below the eyeline (XfHinokiYb 16, XfFirYb 12, XfSpruceYb 12,
 XfSugiYb 6).
 USER NOTED it needs clean-up later, accepted as is for now.
 NOT DONE: cullOffstage is scoped to FringeNorth/FringeSouth, so these 56 are NOT under
 the offstage/skyline rules. Some sit at y 306 = rim height. Adding HeadBowl to
 CONFIG.zones would bring them in.

=== EAST END DONE (2026-08-02, user: "looks pretty good") ===
SURVEY: east of x -90 the canyon was zoned ONLY by MarginTended (waterline) plus keep-outs
 — no canopy, no understory, no wall fringe, despite being the most-seen part of the
 experience (ArenaSpawn is at x 40). It is also heavily BUILT: Swing 1276 parts, rails,
 PathSteps, NW1012West, Bridge3, RiverSquareStair, DescentPath, TimberWall.
 Also learned: the sample grid covers the WHOLE canyon regardless of zones (18,852 samples
 at 27/30/34/35 zones alike). Zones only decide what gets ASSIGNED — the east had always
 been sampled, nothing claimed it.
*** THE ARENA SQUARE IS UNTOUCHABLE (user, said twice). *** X -32..100, Z -36..52 = the
 union of 11 RoshamboStage props (Karesansui, Shoro, ShoroRoof, BellDrive, BonshoRig,
 BonshoBell, ThrowDrum, RanmaCarvings, Waterwheel, ArenaSpawn, Overlook) + 8 studs, which
 also clears half the widest Core-pool canopy so nothing overhangs.
 *** A ZONE PART WITH Recipe="KeepOut" IS NOT A GATE. *** It only competes for zone
 ASSIGNMENT, so a sample claimed by another zone still plants — measured, 16 trees landed
 inside the square with the zone part alone. The hard gate is KEEPOUT_ZONES, a hardcoded
 list in scatterPreserve.luau checked per sample. ArenaSquare added there; re-bake gave
 0 inside, nearest plant 3.5 studs outside the boundary. Prefer the list: it is versioned
 in git, where a zone part lives only in the place.
BAKED IN TWO STAGES, isolation verified each time (151 then 153 untargeted zone folders
 byte-identical):
   centre band  EastCore 76 + EastUnder 183 = 259
   walls        EastFringeNorth 225 + EastFringeSouth 198 = 423
 The walls were then culled IN THE SAME PASS rather than left full-detail: cullOffstage
 CONFIG.zones now includes the east fringe, and its floor sampling spans x -450..240 (it
 stopped at 210, which would have judged the far east with no viewpoint near it).
 CULL RESULT across all four fringe zones: 890 trees -> 57 parked (36 offstage + 21 sugi
 barred), 137 swapped to cheap variants, 408 skyline / 113 near-trail / 312 against-rock.
FINAL: fringe 833 trees; canyon foliage 1,841 plants (from 1,216). 344 skyline trees carry
 cheap geometry; 64 do not — maples and Yr variants have no cheap variant built, and at
 ~21k each the maples are the obvious next target if the east reads expensive.
STILL OUTSIDE THE CULL: HeadBowl/HeadBowlUnder (56 plants from the west end), some at rim
 height. Adding them to cullOffstage CONFIG.zones would bring them under the same rules.

=== CHEAP MAPLES (2026-08-02, user gate: "skyA is fine") ===
XfMapleGold/Red are the SAME GEOMETRY as XfMapleA (identical MeshIds), differing only in
 foliage ColorMap: green 140172233879343, gold 111846883522531, red 138457704702807.
 So ONE import covers all three — and the new export's leaf atlas is BYTE-IDENTICAL to the
 one gold/red were recoloured from, so the existing uploads map correctly. No new texture
 uploads, no moderation exposure.
*** THE MAPLE TRUNK WOULD NOT DECIMATE, AND THE ANATOMY EXPLAINS WHY. *** Measured:
 Trunk1 = 9,947 tris in 883 ISLANDS (largest 3,285, then 705 islands of 1-10 tris);
 Trunk2 = 9,949 tris in 920 islands, largest only 189 — no bole at all. Collapse
 decimation cannot reduce a 4-tri island, so the trunk floored at ~14k however hard it was
 pushed: a hard lod_cards pass gave 21,121 -> 19,709, a 7% saving. Not worth an import.
 THE FIX WAS A MODE WE HAD NEVER TRIED. export_tree wood MODE 0 culls WHOLE TWIG ISLANDS
 instead of decimating them, and hit its budget exactly: trunk 16,995 -> 4,000.
   XfMaple_skyA = foliage 6000 / wood 4000 / spray 2.52, wood mode 0 -> 21,121 -> 10,014.
 We had been passing mode 3 (PROPORTIONAL) everywhere because it is right for the
 CONIFERS, and never questioned it for a broadleaf. Mode 0's documented risk is orphaned
 foliage where a culled twig carried it — real for the sugi, fine for the maple; the user
 checked and accepted.
 CREDIT WHERE DUE: the user brought Gemini's advice — stop fighting dense organic meshes,
 use a proxy bake or voxel remesh. Those SPECIFIC recipes do not fit this mesh (a
 shrinkwrap proxy addresses 1 island of 883; remeshing 1,800 disconnected twigs would fuse
 or explode, and discards the UVs carrying the bark). But its PRINCIPLE — stop decimating,
 remove instead — was exactly right and was the thing I had stopped short of.
 DIAGNOSTIC TO REUSE: COUNT THE ISLANDS before choosing a reduction strategy. Dense
 surface -> decimate or proxy-bake. Fragmented twig system -> cull whole islands.
RESULT: cullOffstage CONFIG.skylineSwap gained XfMapleGold/XfMapleRed; the cull swapped
 30 skyline maples (16 gold, 14 red), ~333k saved, and the rim keeps its colour. Skyline
 is now 374 on cheap variants / 34 full detail (the 34 are Yr variants, already 4-7k, so
 nothing left worth chasing). Canyon foliage 1,841 plants.
OLD-LIBRARY MAPLES REPLACED (2026-08-02, user: "replace all the existing MapleRed and
 MapleGold trees with their Xfrog equivalents" -> "they're fine for now").
 TWO MAPLE FAMILIES existed in the world and only measurement told them apart:
   OLD  rbxassetid://8989690422 / 8989691572 / 8989730454 — short Roblox-library IDs,
        2 meshparts, kit templates MapleGreen/MapleGold/MapleRed (h18.1). This is the
        "garish knock off" the user compared unfavourably to XfMapleA back in July.
        TEN instances, ALL hand-placed under Foliage.Heroes.
   xFROG everything in the Preserve zones + RimHero_Maple.
 Swapped in place, bbox-aligned, worst XZ drift 0.0000: 4 red -> XfMapleRed, 3 gold ->
 XfMapleGold, 3 green -> XfMapleA. FULL-detail templates (21,121), not the _sky ones —
 these are hand-placed heroes seen close. Colour intent read from each hero's own NAME.
 Originals parked at ServerStorage.ParkedFoliage.OldLibraryMaples_2026_08_02.
 Verified 0 old-library maple meshparts remain anywhere in CanyonWorld.
 *** SCALE CAVEAT the user accepted for now: heights were matched to preserve the
 composition, so trees in tall slots are stretched — Hero_new_MapleGreen x2.02 (a 28-stud
 slot holding a 14-stud xFrog tree, so its leaves are DOUBLE size), Hero_4_MapleRed x1.58,
 Hero_5_MapleRed x1.48. Five others sit at 0.87-1.03 and are fine. If the stretched ones
 ever read wrong, the honest fix for a tall slot is XfKatsuraA (a real 26-stud broadleaf)
 rather than scaling a maple. ***
 SEPARATE, NOT DONE: Heroes/RimHero_Maple is xFrog but sits on PRE-LOD meshes
 (119424693673590 etc.) that match no kit template — it was never re-pointed in the
 2026-08-01 LOD swap because, like the hero sugi, it is hand-placed and no bake touches it.

*** A ColorMap-ONLY SurfaceAppearance IS WORSE THAN NO SurfaceAppearance (2026-08-02) ***
 USER: "all the other trunks/bark are rendering chestnut brown", while the hero sugi
 "render fine". Isolated on a 6-tree rig above ArenaSpawn — identical XfSugi40, same
 light, 22 studs apart (a first attempt used trees scattered across the canyon, which the
 user correctly called "a terrible test"). Variants: control / no tint / hero bark image /
 hero PATH (TextureID, no SA) / SA kept but AlphaMode=Transparency / Overlay + white tint.
 ONLY the TextureID variant read correctly. Not the tint, not the AlphaMode, not the image.
 CAUSE: a SurfaceAppearance with a ColorMap and NO NormalMap/RoughnessMap/MetalnessMap
 makes Roblox substitute its OWN defaults for the missing channels instead of deferring to
 the part's Material — the result reads warm and shiny. TextureID uses the Material.
 THE SPLIT WAS EXACT and diagnostic: 21 templates with FULL PBR (CedarM/S, ConiferA/B/C,
 PineNiwaki*, FernClump, IrisA/B, ReedClump, RealisticBamboo, old MapleRed/FirM) = assets
 BOUGHT WHOLE, and they looked right. 49 templates ColorMap-only = every Xf* plus
 SugiHero/SugiMid, i.e. EVERYTHING WE EXPORTED OURSELVES, because export_tree.py writes a
 colour map and nothing else. The chestnut trees were exactly the trees we built.
 FIX APPLIED: 1,657 wood parts (62 kit templates + 1,595 placed) converted from
 ColorMap-only SurfaceAppearance to TextureID, keeping part.Color. The 589 with full PBR
 left untouched. Verified 0 ColorMap-only wood remains. User: "vast improvement".
 *** CORRECTION TO THE IMPORT CHECKLIST WRITTEN 2026-08-01. *** It said to give every
 MeshPart a SurfaceAppearance. That is right for FOLIAGE, which needs AlphaMode =
 Transparency to cut the cards out. It is WRONG FOR WOOD: opaque wood wants TextureID
 unless a genuine full PBR set exists. The corrected rule:
   foliage -> SurfaceAppearance, ColorMap, AlphaMode = Transparency, DoubleSided = true
   wood    -> TextureID (NOT a SurfaceAppearance), DoubleSided = false, keep part.Color
   wood WITH real Normal/Roughness/Metalness maps -> keep the SurfaceAppearance
BARK NORMAL-MAP TEST — CLOSED, NO CHANGE (2026-08-02). XfrogPlants DOES ship bark bump
 maps (18 `brk_b.tif`; spruce's is real relief, range 7-255 std 20.4) and export_tree.py
 never used them — it composites diffuse + leaf opacity into one ColorMap and stops.
 New tool roblox/tools/textures/bump_to_normal.py converts them (and writes flat constant
 maps for filling a channel). Rig on XfSpruceM — 240 placed, warmest bark in the library
 (warmth R-B 62) — compared TextureID / +Normal / +Normal+Rough+Metal / +Rough+Metal.
 USER: "I honestly can't tell them apart." TWO CONCLUSIONS:
  1. The trigger is COLORMAP-AND-NOTHING-ELSE, not "a channel is missing" — variant 2
     still lacked roughness and metalness and looked fine. Any second map suffices.
  2. Bark relief is invisible at the distances these trees are viewed from. DECISION:
     keep TextureID everywhere, do NOT upload the other 17 normals. Closed, not deferred.
 WHY THE MAPLES ESCAPED THE ORIGINAL BUG: the defaults warm and brighten whatever they are
 given, and maple bark is the most NEUTRAL texture in the library — RGB [117,118,114],
 warmth (R-B) of 3. Spruce is 62 and hinoki 44, so those tipped into chestnut while the
 maple had nothing warm to exaggerate. The effect was always on the maples; it just did
 not show.
 FINAL WOOD STATE: 1,682 parts on TextureID (everything we exported), 589 on full-PBR
 SurfaceAppearance (bought assets, untouched), 0 ColorMap-only. Canyon foliage 1,871.
SUGI BARK UNIFIED (2026-08-02, user: the hero bark "is superior to my eyes"). Applied the
 hero sugi's bark TextureID 136802338266809 to every Xf* sugi — 161 wood parts (11 kit
 templates + 150 placed). Replaced 116090828111787 (85 parts: XfSugi40/XfSugi25/XfSugiYr)
 and 133940238829908 (76: XfSugi25T/XfSugiYb). User checked grain scale on both the
 26-stud fringe trees and the 4-stud XfSugiYb: fine at both. 185 sugi wood parts now share
 it; SugiSmart/SugiMid keep 109397671791816 (13 parts).
 THEN a false alarm worth recording. User: the xFrog sugi "reads as slightly warmer brown
 than the cool grey of the Hero sugis" — same texture. Ruled out, in order: every material
 property byte-identical (TextureID, Color 163/162/165, Material Plastic, no
 MaterialVariant, no SurfaceAppearance, Reflectance 0); the bark image is UNIFORM (warmth
 R-B +21 in every quarter row and column, so UV region cannot matter); and NEITHER MESH
 CARRIES VERTEX COLOURS (checked both FBXs in Blender — no colour_attributes at all).
 Put a hero and three xFrog sugi on one platform, same light: "I put them right next to
 each other, they're identical."
 => IT WAS POSITION AND LIGHTING. The heroes stand on the shaded canyon floor at y113-158
 under cool skylight; the xFrog sugi are in the fringe and groves up to y300 in direct
 sun. NOTHING TO FIX. Worth the chase: the alternative was tinting the xFrog sugi cooler
 to compensate, which would have been wrong wherever the light changed, and wrong at night
 (and this arena is NIGHT-FIRST).
 LESSON, now twice in one day: when two things look different, put them ON ONE PLATFORM
 under ONE LIGHT before changing anything. Comparing across locations is not a test.

Task 15: complete (arrangements sweep) — 2026-08-02, USER GATED ("I can work with
this"). 40 arrangements / 94 trees into CanyonWorld.Foliage.ArrangementsDraft via the
new committed tool roblox/tools/studio/bakeArrangements.luau (82313a4). Sites derived
from the world: pad-slot tunnel mouths (voxel occupancy — tunnels are carved VOIDS with
no Instance), bridge abutments, shore-rock pool clusters, path feet/heads with 20+ stud
rise, two promontories. Audit: 94 seated, 0 floating, 0 buried, 0 flag violations, 0 in
the Arena square.
Task 15: deferred (hand-tune, user's) — suspension-bridge abutments placed NOTHING (both
ends already densely planted; needs trees moved, not a gate loosened); Pool_3, Pool_5,
RiverUpperClimb_head unplaceable within 52 studs; stair-end arrangement assignment is
round-robin and therefore arbitrary per site.

Task 15b: complete (east backdrop) — 2026-08-02, USER GATED ("looks good"). The ad-hoc
terrain east of the canyon (x 205..470, curving north) had never been planted. Treated as
BACKDROP not place: nobody walks it (easternmost path marker x 149; 72 of 74 samples >120
studs from a path) but every vantage sees it, FallsLanding at 686 studs. 35 skyline-variant
trees / 73 MeshParts into CanyonWorld.Foliage.EastBackdrop via the new committed
roblox/tools/studio/bakeEastBackdrop.luau (0c8609a). Siting by SLOPE — the user read it off
the moss before I measured it; 618 of 719 samples exceed 32 deg, only 14% plantable.
16 pockets staked in-world with neon poles, user chose 2,3,6,7,8,9,12 (recorded as CHOSEN).
Audit: 35 seated, 0 floating, 0 buried, 0 flag violations.
Both bake tools now carry a BakeFingerprint guard (ceac915) that refuses to destroy
hand-tuned output — the user's tuning will be ad hoc over months as teahouse areas become
curated places.

Task 16: complete (walk-through gate) — 2026-08-02. Owner declined a formal walk ("I've
seen this place plenty") and gave the punch list directly: half-buried and precarious trees.
Cleanup audit built, 190 of 1,915 flagged; BURIED and PERCH tiers parked except at the
waterline (99 parked), HALF_BURIED 63 deliberately left for the eye.
As-built: complete, appended to the spec (a294e59, 687ccab, 5357c2b, 4a82491).
Final review: complete — gates green (stylua/selene, 816 Luau, 191 server, tsc, eslint
--max-warnings 0, vite build; no place files or secrets tracked). Two economy-API defects
found and LOGGED TO ITEM 6 at the owner's direction, not fixed here: purchase is a
read-modify-write race, PUT /decorations never checks ownership.
PAD KEEP-OUT DEFECT (owner-found, fixed 2b07380 + 4a82491): 21 of 40 arrangements sat
inside KO_Pad volumes that already existed in FoliageZones. Cause structural — tunnel sites
are seeded FROM pad slots. bakeArrangements now READS the KO_* volumes. Fixed surgically to
avoid tripping the fingerprint guard. 23 arrangements stand, 0 in any keep-out, 16 parked.
Snapshot: ServerStorage.FoliageSnapshot_2026_08_02 (1,828 models) + text manifest in git at
docs/superpowers/canyon/foliage-manifest-2026-08-02.csv (1,870 rows).
ITEM 1 IS CLOSED apart from finishing-a-development-branch.
