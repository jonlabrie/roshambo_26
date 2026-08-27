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
in [[world-throw]]; the divergence is logged as parked defect (h). `CLAUDE.md` asserted
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

## [2026-08-16] decision | defect (h) scheduled; item 7's siting superseded

(h) — the World Throw is random, not the majority — is scheduled as a **prerequisite of item
7 (Statistics)** and additionally gates any skill-claiming badge in item 6. Flagged on the
entry that it is arguably larger than either, being the core game rule rather than a feature.

Item 7's text was stale: it still sited the Statistics room under the western Overlook at
(73,110,19). Superseded — the room is bored west of the apparel shop ([[stats-room]]) and
specced.

Established while answering "does this affect the PWA too": there is ONE server and one
RoundEngine, so the PWA and Roblox share the same World Throw and the same defect — no client
work is involved. And prod is worse than random: `apprunner.yaml` sets `TEST_MODE: "true"`, so
playroshambo.com runs the deterministic R→P→S cycle. `roshambo_server_dev`'s value is
configured via the App Runner API and is not in git — unverified, needs an AWS check.

## [2026-08-16] ship | the World Throw is the crowd

Defect (h) fixed. `GameRules.deriveWorldThrow` derives the World Throw from the round's own
tally; `RoundEngine` already passed the counts to `pickWorldThrow`, so the composition root
was the only wiring needed. 9 fixture cases in `worldThrowDerivation`; server 262, Luau 1201
and PWA 23 all green.

Decisions taken in the fix: it is **plurality, not majority** (with three options a >50%
majority frequently does not exist); a **tie** picks randomly among the tied only; and below
**`WORLD_THROW_MIN_PARTICIPANTS` (5, env-tunable)** it falls back to random, because at small
N a player's own throw is decisive — joining either side of a 2–2 split creates the plurality
they needed to beat, and a solo player would be permanently SAFE. TEST_MODE keeps the R→P→S
cycle by owner ruling, so dev stays deterministic; defect (e) therefore still stands, and my
earlier claim that (h) would supersede it was wrong.

⚠ Fixed is not active: both environments run TEST_MODE, so nothing exercises the rule yet.

## [2026-08-16] defect | the patent claims MAJORITY, and the game designates by PLURALITY

Read US 8,025,570 B2 at the owner's request, who suspected the patent used "majority" loosely
where "plurality" was meant. It does not read that way. **Both independent claims (1 and 6)
recite "wherein the designated item is the item selected by a majority of players"** as a
limitation, and the specification offers no alternative designation method — none of the usual
opening language appears near that step. "Plurality" occurs in the patent only in its term-of-
art sense ("a plurality of devices"), never meaning "the most votes".

The shipped rule is plurality (argmax), because with three options a >50% majority frequently
does not exist. So a literal claim reading leaves most rounds with nothing to designate — both
a question over coverage of the actual product, and the best argument for a broad construction.

⚠ OPEN, and legal rather than engineering: needs a patent attorney. Recorded on [[world-throw]]
with the claim language verbatim. The code is deliberately NOT being changed to match a guess.

## [2026-08-16] migrate | the working branch is retired; dev deploys from main

`m4b-zendojo-art-pass` served as the long-lived working branch and the dev backend's
auto-deploy source. Both plan 1 and plan 2 merged into `main`, which is now a descendant of
it — the branch held nothing `main` lacked — so it was retired and `roshambo_server_dev`
repointed to `main` (App Runner `update-service`, 2026-08-16). Auto-deploy stays ON, so a
push to `main` now redeploys dev.

Carried out of doing it: `update-service` REPLACES `SourceConfiguration` rather than merging,
so a repoint that omits `RuntimeEnvironmentSecrets` drops all three secrets. The call
round-tripped every field from `describe-service`. Also verified rather than assumed: dev's
`TEST_MODE` really is `"true"`, matching prod's `apprunner.yaml` — so neither environment has
ever exercised the majority rule OR the random branch.

Note the drift this retirement marks: the branch was named for a Roblox art pass and ended up
carrying a statistics backend, a security fix and two server plans. Recorded in
[[friends-family-baseline]] terms — item 4 is still the board's next item, and the work of
2026-08-16 was item 7.

## [2026-08-16] lint | item 4 was recorded as barely started; it is nearly done

[[item-4-merchant-row]] still read "Remaining scope is the row itself — the façade shells around
it", written when only 花火屋 existed. Four shells have since been built. The owner corrected it
directly: "item 4 is nearly complete already, only the tea vendor remains, Apparel and
Accessories are already done."

The page also argued with itself — it stated the machiya brainstorm was DONE and then, three
bullets later, that deriving a street reservation "at the machiya brainstorm" was "now the next
step". Superseded per schema rule 2 rather than appended to.

Consequence worth noting: a stale program page caused a real mis-assessment. Earlier the same
day I read the board and told the owner we had drifted off item 4 onto item 7 — a judgement
built on a page that understated item 4 by four buildings. Accessories and the Stats false front
also carry no recorded owner gate despite being built and signed off verbally; that gap is now
marked on the page rather than left implicit.

## [2026-08-17] drop | Centred escalation panel removed; the ring's digit blinks instead

Owner: "dump the 'choose a throw' alert in the middle of the screen; it's just
annoying" — and asked for the last five (red) digits to flash at a half-second
interval. `RingTimer.flashLit` (pure, tested) drives it off the countdown, so the
blink is phase-locked to the digits. Arming rule unchanged in [[round-and-hud]].
Same session: every Stats board cased in an inch of dark moulding ([[stats-room]]).

## [2026-08-17] audit | Stats room measured on the A13: costs what the arena square costs

Owner walked the finished room on the F&F floor device. Load flat against the arena
square despite ~8,400 GUI instances and no MaxDistance cull — the parked perf budget is
not owed. Physical flaps read ragged at ~30 fps: half-turns (0.055 s / 0.0825 s) are
shorter than two frames. See [[stats-room]].

## [2026-08-17] ship | Riverside chaya + dock shipped — item 4 closed

The merchant row's last shell, owner-gated with the place saved. A pavilion, not a
machiya: round posts, real thatch (ThatchedRoof002A) with rolled edges, a counter
splitting the floor, stools at it and an endai bench at the rail, `ChayaKeeperSlot`
standing empty for an NPC that does not exist yet. Built at the waterline —
`Machiya_2` and `DockDeck` are superseded, not deleted. The chōchin is red by owner
ruling, bounded by the legibility floor rather than by the row's no-red rule.
Five looks, and the frame was rebuilt entirely at the third ("the engineering is
suspect"). See [[chaya]] and [[item-4-merchant-row]].

## [2026-08-18] ship | Socket identity moves to the connection; deviceId stops being a password

The guest-auth gap closed: the server names the device, signs a token for it, and the
token rides the handshake — no socket message names an account any more. Owner ruled a
hard cut rather than migrating existing guests. One rollout crutch left in the PWA, to
delete after the prod server is deployed. See [[backlog]].

## [2026-08-18] defect | Registration has never worked on the deployed site

`AuthView.tsx` posted to `${protocol}//${hostname}:3001` — the laptop's dev port — so on
playroshambo.com every registration died as a network error ("Load Failed" on iOS).
Pre-existing, found while chasing a report of it. It also read
`localStorage.getItem('deviceId')`, a key this app has never written, so guest progress
never migrated into an account either. Both fixed; the migration now travels as the
signed device token. See [[backlog]].

## [2026-08-18] ship | Sliding shoji — item 5 closed

Every shoji bay's leaf now moves in its own channel (`trackShojiBays.luau`, idempotent)
and slides by holding a `ProximityPrompt`, clamped only to its run's ends — a whole run
can stack into one bay, so an N-bay wall opens at most N−1 bays. Server-authoritative
(`ShojiOpen` target / `ShojiApplied` actual, both attributes); the owner's positions
persist through the existing loadout PUT (`shojiOpen`), a visitor's do not. The
swappable variant slot the item asked for was found already wired end to end from a
prior ship — placeholder art only, catalog/UI work stays on [[backlog]].

Two owner gates passed the same day: the channel geometry ("sills on L teahouse look
fine", place saved) and the play loop ("looks good" — prompts, slide, stacking,
direction). Five non-blocking implementation items carried to [[backlog]]. See
[[teahouses]]; spec `2026-08-18-shoji-screens-design.md`, plan
`2026-08-18-shoji-screens.md`, commits `021d745..95375f3`.


## [2026-08-18] lint | The wiki grows currency checks, having gone stale again

An audit prompted by the wiki producing stale advice for the second time in three days: the
backlog described the digits-drum defect as open and its `Opts` blocker as unplumbed, when both
had been fixed the day after that entry was written. Mechanical lint had been clean throughout —
it checks structure, and none of these are structural.

`tools/wiki/lint.mjs` gains three currency checks (details in `schema.md`): `updated:` may not
lag a page's own last commit; a cited repo path must exist; and cited code committed after a
page's `updated:` warns `re-read —`. First run over 50 pages: 5 errors, 13 warnings. All five
errors fixed — `program/backlog.md`'s Plan-3 section rewritten as shipped, `world/arena-square.md`
and `practice/misc-engine-traps.md` re-dated and re-read (the SurfaceGui text recipe rehomed from
the retired `BoardController` to `FlapBoard`), `practice/studio-tooling.md`'s deliberately-absent
citation exempted with `<!-- lint-ok -->`.

The finding worth keeping is in [[wiki-currency]]: a deferred-work note and the event that
expires it live in different files, so no update trigger can fire. Citation dates are what bridge
them. The 12 remaining warnings are advisory and unworked.

## [2026-08-18] decision | The wall boards get a drum ladder, chosen per transition

The clock's 2026-08-17 fix — a drum bolted to each column — does not transfer to the wall boards,
because a clock column has a fixed kind and a leaderboard column does not. Owner's ruling: choose
the drum from the TRANSITION, as a ladder of three, smallest-carrying-both wins —
`DIGITS` (10) → `FIGURES` (17) → `DRUM` (49). `FlapBoard.drums` now takes a table or a function,
so one renderer serves both kinds of display.

The arithmetic that shaped it, and that a first answer got wrong: `maxSteps` caps a roll at 9, and
a smaller drum does not remove the cap, only fires it less. `7 → 3` is 45 steps on the full drum
and still 11 on a 15-character numeric one — capped either way, no gain. At ten characters it is
6, and the greatest distance possible is exactly the cap, so no digit roll is ever truncated.
Hence digits on a rung of their own. `FIGURES` carries what the boards print (`,` `-` `%` `/`
space) plus `+` and `.` as headroom at the owner's call.

Carried alongside: `FlapScheduler.plan` caches each drum's character array and reverse index —
free when callers planned a line at a time, but the ladder plans one cell per call, taking a
10×40 repaint from 10 index builds to 400. 1382 Luau tests. Built, not yet gated: the owner has
not looked at it in Studio. See [[stats-room]].

## [2026-08-18] gate | Drum ladder accepted on the wall boards

Owner looked and passed it ("looks fine"). The pre-gate risk — two adjacent columns rolling on
different drums at once — does not read as a defect. Item 7's drum thread is closed; the
remaining item-7 work is the deferred §6.2 pair (the printed 番付 sheet, the avatar plinths).
See [[stats-room]].

## [2026-08-18] ship | The room learns to say who is playing best

Item 7's measurement basis, built end to end from
`docs/superpowers/specs/2026-08-18-player-measurement-design.md`: READ (wins ÷ throws, baseline
33.3%), YIELD (banked ÷ throws, what the banzuke ranks on) and NERVE (median `streakAtBank`,
never ranked). All three read rows the server already wrote — no schema change.

Qualification is 360 throws in a **rolling** 7 days: six hours exactly, and above the ~356 the
standard error needs. The rolling ruling overrides `windows.ts`'s "RANK uses calendar windows".
The read column is gated on `TEST_MODE` being off and ships blank until it is. `skillFuture`
un-shutters to carry the room's bank-depth histogram; the 札 gains `RANK 14 OF 22`.

The design rests on simulation, and corrected a wrong first pass: staking is +EV at the margin,
but an always-staker realises nothing, so EV never selects a stopping point. Bank-vs-Stake is a
real decision, and the owner was right that points-per-throw measures something batting average
cannot — a blind-but-bold player out-earns a skilled-but-timid one 85% of the time.

422 server tests, 1394 Luau. **Not yet gated** — the owner has not seen it in Studio, and
`skillFuture` opening is a geometry change needing `buildStatsBoards.luau` re-run and the place
saved. See [[stats-room]].

## [2026-08-18] decision | The entrance wall shows what is happening now

Owner, reading the built room: *"winning is something that happens in the moment, not as a summary
at the end of a week... more who is on a roll and less who is the GOAT."*

The south wall — the first surface you face leaving the tunnel — held the qualified ranking, which
needs 360 throws a week and is empty almost always. It now leads with `pots` (live, riding now) and
`runs` (live streaks) side by side, standings demoted to a strip beneath. `livePots` was written for
it; `liveStreaks` already existed, already indexed, and had no consumer at all.

The rule this settles: **a rate is an inference and needs sample; a pot on the table is an event and
needs none.** Every floor in the room applies to the first kind only. See [[stats-room]].

Also corrected the same day, all owner-spotted: the entry rule was captioning the wrong board
(career banked has no entry requirement); "PER THROW" of what; STREAK NOW → CURRENT STREAK; bank
depth came off the personal slip as "a dubious stat"; throw shares now read to a tenth, because
whole percents hide the ties the World Throw is decided by.

## [2026-08-18] gate | Item 7 closed — statistics, with loose ends named

Owner: *"let's close Item 7 for now; we'll revisit in the future with clearer thoughts."*

Built and saved: the three measures (READ / YIELD / NERVE) over rows the server already wrote,
qualification at 360 throws on a rolling week, the drum ladder, the south-wall inversion to live
pots and runs, and a display-name fix that had every Roblox player reading as "Anonymous" on every
board since the client shipped.

Closed deliberately incomplete. The loose end worth naming here rather than burying: **the
standings board ranks on points-per-throw behind a floor derived for win rate**, which the owner
caught and which the form inversion overtook before it was settled. At 360 throws yield separates a
+5-point player at 71–82% where READ manages 90%, and twenty identical blind players produce a
winner earning 2.5× the median on luck alone. Either the ranked column changes or the floor does.
Recorded on [[friends-family-baseline]] as the first thing to pick up.

The board is now items **6 (rewards & flex)** and **8 (world finish/hygiene)**.

## [2026-08-18] ship | Familiars — the bird that reads your round

Item 6's mobile half, built end to end: milestones and a 15-grade ladder on the server, a bird per
player with four states, and 326 perches across the canyon. Not a new design — the metagame spec
approved 2026-07-04 specified familiars as *"the mobile status display complementing the teahouse's
static one"*, with these exact reactions and plumage from milestone banks. Its one blocker, a dusk
cycle, had already shipped. Four things were re-derived in conversation before anyone read it,
which is why [[familiars]] opens by saying so.

Also fixed on the way: round results had no legible visual at all (a loss showed nothing, a safe
drew a disc the owner read as a cloud), the result splash sat over the avatar and the bird, the
chōchin had come untethered from their crosspoles, and every Roblox player was named "Anonymous"
on every board because nothing on that path ever wrote a display name.

Three rulings worth carrying forward, all owner's: grade counts MILESTONES not rates or time (an
event needs no sample and cannot be lost by logging off); SAFE gets no behaviour at all; and birds
rest on the world, not on your head — *"it'll look like a bad cartoon where everyone just got
knocked on the head."*

Item 6 stays OPEN: the static half (nobori, crest, scrolls) is unbuilt and the spec is explicit
that it cannot close without it.

## [2026-08-18] decision | Production App Runner paused — it was idle at 4x the dev size

Asked what a push costs. The builds are pennies (two auto-builds per push: App Runner dev at ~4
minutes, Amplify main), but the question surfaced something larger: `roshambo_server` was RUNNING
at 1 vCPU / 2 GB and serving nothing, since Amplify points `VITE_SOCKET_URL` at the DEV service.
App Runner bills provisioned memory around the clock regardless of traffic, so an idle 2 GB
instance costs several times more per month than a heavy day of pushing.

Paused, not deleted — URL and configuration survive, `resume-service` brings it back, and prod
never had auto-deploy on so the push flow is unchanged. Resume command and the caveat about
repointing the frontend are on [[deploy]].

Cost Explorer is not enabled on the account, so these are estimates reasoned from instance sizes
rather than figures off a bill.

## [2026-08-19] decision | Familiar birds go to bought models, and the skinned-mesh path is verified

The greybox familiar (four parts, procedurally animated) was never going to be a bird. Asked how
far it could go, the answer was that the mesh is the cheap part and the rig, the unwrap and the
textures are not — so a $25 TurboSquid pack ("Rigged Low Poly Bird Collection" 1603819, Standard
License, ~17 birds, 41k faces total) buys more than it costs. Vendor source lives in
`~/Desktop/Roshambo Reference/models/birds/`, never the repo, same as the niwaki.

**Owner rulings this session**, all on the mesh:
- The familiar is a **roster, not one bird** — uguisu first, karasu second.
- **Life size, maybe slightly larger.** The uguisu is 0.583 studs / 7 inches nose to tail.
  ⚠ This invalidates the tuning in `roblox/src/shared/BirdFlight.luau` — `PERCH_RADIUS`, the
  orbit radii and the three hold heights were all set against the old ~1.4-stud bird.
- **The bind pose is FOLDED**, not spread — *"nobody cares what a flying bird's wings look
  like."* Perched is ~90% of viewing time, so perched is the pose that gets modelled accurately
  and flight is what the rig approximates. This inverts the usual convention deliberately.
- Feet are **anisodactyl** (two toes forward, one back); the neck barely pinches; the head sits
  in the back line rather than proud of it.

**The probe passed.** Studio's importer takes a custom non-R15 armature, and `Bone.Transform` is
drivable from Luau — which is the finding that matters, because it means motion stays in code
rather than in uploaded animation assets. Recipe, flags and the bone-drive test on
[[blender-pipeline]]. Probe artefact parked at `Workspace.Sandbox.sparrow_probe` (place-only).

Next is the retarget: the purchased sparrow's rig and unwrap, our uguisu's proportions. The
parametric generator `roblox/tools/blender/bird_familiar.py` survives as the SPEC — six passes of
owner art direction encoded as numbers — rather than as the shipped mesh.

## [2026-08-19] defect | CORRECTION — the familiar's orbit numbers are AVATAR-relative, not bird-relative

The 2026-08-19 entry above says the life-size ruling "invalidates the tuning in
`roblox/src/shared/BirdFlight.luau` — `PERCH_RADIUS`, the orbit radii and the three hold heights
were all set against the old ~1.4-stud bird." **That is wrong in three ways and log entries are
append-only, so it is corrected here rather than edited.**

- **The orbit radii and hold heights do not scale with the bird at all.** `BirdController`
  line ~276 adds `BirdFlight.offsetFor(...)` to the OWNER'S `HumanoidRootPart` position. RESTING
  `r=2.6 y=3.2`, WIN `r=3.4 y=8.2`, LOSS `r=2.0 y=0.9` describe where the bird sits around a
  five-stud avatar. A smaller bird orbits the same place; it is simply smaller.
- **`PERCH_RADIUS` is in `BirdController`, not `BirdFlight`**, and it is how far from its owner a
  bird looks for a perch — also unrelated to bird size.
- **The old bird was ~0.78 studs long**, not 1.4. The 1.4 figure was the first draft of the
  parametric generator, which never shipped.

**What the mesh swap ACTUALLY breaks**, which the wrong claim was hiding:

- **`BAND_COLOR` tinting.** The controller sets `p.Color` on four parts to show grade band. A
  textured MeshPart does not tint that way — a SurfaceAppearance overrides `Color`. Grade bands
  need another mechanism, and the standing design answer is ornament (crest, tail streamer) on
  separate tinted pieces rather than recolouring the bird, which keeps an uguisu an uguisu.
- **Perch seating.** `target = perch.WorldPosition + Vector3.new(0, 0.2, 0)` was set for a body
  part 0.38 studs tall. It depends on where the mesh's ORIGIN sits — keep the origin at the feet
  through export and this goes to ~0.
- **The controller builds four parts at runtime** and must clone a MeshPart template instead.
- LOD (`DRAW_DISTANCE 90` / `DETAIL_DISTANCE 45`) is a judgement call, not arithmetic — a skinned
  mesh costs more per bird than four parts, so if anything these come DOWN.

Four retarget traps found the same day are now written up on [[blender-pipeline]].

## [2026-08-20] ship | The uguisu is in the world — skinned, textured, rigged, drivable

Owner gate: *"it looks right, and it looks good."* The four-part greybox familiar is superseded
by a real bird — `rbxassetid://114444614583565`, 0.148 × 0.315 × 0.552 studs, 2,688 triangles,
19 bones, feet at the origin. As-built on [[familiars]]; pipeline and traps on
[[blender-pipeline]].

Built by retargeting a purchased sparrow rather than modelling from scratch, which was the right
trade twice over: the rig, the leg weighting and the unwrap are most of what a bought model is
worth, and the parametric generator that preceded it survives as the SPEC those changes aimed at
— six passes of owner art direction encoded as numbers.

**Verified in the place, not assumed:** `HasSkinnedMesh` true, and all three new bones drive —
`bill_lower`, `wing_R`, `wing_L` each moved a witness bone 0.0311 studs for a 30° rotation of a
0.06-stud probe, which is exactly 0.06 × 2·sin(15°). A leaf bone's own `TransformedWorldCFrame`
does NOT reflect its own `Transform`, so the first test read 0.0000 and was wrong about the bones
rather than the bones being wrong — hang a temporary child bone off it and watch that instead.

Two things that read as defects and were not. The bird arrived apparently lying on its back: the
geometry was upright and `PivotTo` was at fault (fifth trap, [[blender-pipeline]]). And both
probes sat inside the Hanabiya's upper storey — nothing perched them, they were parked at
coordinates I chose badly. Both now sit in `Workspace.Sandbox` 12 studs above ArenaSpawn with
nothing within 5 studs. Place-only; neither is Rojo-owned and neither belongs in RoshamboStage.

⚠ The mesh is NOT wired into play. `BirdController` still builds four parts.

## [2026-08-22] ship | The familiar flies, folds, sings and looks around

A long build over three days, and the shape of it changed several times under contact with
Roblox's limits. The bird is now a two-part skinned mesh with a real flight model and an idle.
As-built on [[familiars]]; engine limits and importer traps on [[blender-pipeline]].

**What Roblox would not do, each found after being designed around:** `Bone.Transform` discards
scale; a single rigid bone cannot shorten and so cannot fold; and geometry cannot be hidden by
moving it. The wings are therefore a separate MeshPart with `Transparency = 1` — the only
mechanism that satisfies the owner's "completely disappear when perched" — and still skinned, so
they keep a two-bone fold.

**Owner rulings this session:** wings vanish entirely at rest and only unfold for flight; grade
bands are set aside ("birds simply aren't large enough for it to matter, unless we design our own
kind of (presumably larger) bird, like a raven/crow to carry it"); flight needs takeoff/cruise/
landing phases and paths that are not beelines; the victory hop is a weight shift between feet
rather than the whole bird sliding.

**On my own accuracy.** I twice reported a fold "scored zero" and was wrong both times — once
measuring a single vertex, once sampling a body mesh that had already been freed, so every lookup
returned zero. Measured properly, that fold left 84% of the wing outside the body. Separately, a
shipped test asserted a minimum duration against the very constant it was testing, so zeroing the
constant still passed. Mutation testing caught that one. The pattern worth carrying: **a metric
that is satisfiable in a way you did not intend is worse than no metric**, and the way to find out
is to break the code deliberately and check the right test fails.

⚠ Not addressed, and a genuine conflict in the asks: the owner suggested wing flutter while
perched, but the wings are hidden then. `BirdFlight.wingAngle` still computes a perched flutter
nothing can see.

## [2026-08-22] decision | Grade moves off the bird and onto a sashimono — first look is "a bit much"

Grade bands were set aside on the familiar ("birds simply aren't large enough for it to matter,
unless we design our own kind of (presumably larger) bird, like a raven/crow to carry it"). The
owner then proposed bars beside the player, and on recalling the **sashimono** — the back banner
worn in a holder on the armour for battlefield identification — that became the vehicle: a crest
for identity, pips for grade. Built same evening; most of it already existed, since
`Kamon.forUserId` is deterministic and the familiar roster already carries `band`.

⚠ **NOT GATED.** Owner's first look: *"It kinda looks cool but feels like a bit much."* That is a
reaction, not a ruling, and the next session should treat the current proportions (pole 4.2
studs, cloth 1.5 × 2.1, 14° lean) as a starting point to argue down rather than a spec. "A bit
much" most likely means SIZE, but could equally mean that a banner on every player at all times
is too constant a presence — worth asking which before shrinking anything.

Open, and named by the owner: grade display was described as *"(optionally)"* shown, which if it
means a player toggle is a settings surface rather than a rendering change.

Also recorded: `Kamon` is Lune-tested and therefore **must name no Roblox type**. Lifting the
crest renderer into it broke the whole test run at require time; the renderer lives in
`KamonDraw` beside it instead. Same rule as [[familiars]]' BirdFlight and DoomEscalation.

## [2026-08-25] ship | The perch comes alive — flutter, turn — and a fold that had been backwards all along

Three perch motions now, where there was one: the look-around idle, a **flutter**, and a **turn**.
Owner: *"It's really looking good, there's some real life there."* As-built on [[familiars]].

**The flutter had existed since 2026-08-19 and had never once been visible.** It lived in
`wingAngle` — the LIFT channel — while `wingExtension` returns 0 whenever the bird is not flying
and Transparency follows openness. So the wings were transparent for every burst while the lift
rotated something nobody could see: two channels fighting, one hiding the wing and the other
animating it. The owner's fix — *"a quick 'half unfold/refold' cycle a couple of times"* — moves it
onto the fold channel, which is also the visibility channel, so the wing appears BECAUSE it is
unfolding. Then three flexes rather than two, then 0.7s → 0.5s.

**And the first flutter gate found a bug three days older than the flutter.** Holding a partial
fold still and in view revealed that the fold swept the wing FORWARD, past the head — the sign on
both fold constants was inverted. Measured on the live bird rather than guessed: spread rests at
tip z −0.123, the shipped fold reached −0.391, the corrected fold reaches +0.146.

⚠ **The transferable part is why nothing could have caught it.** The only two poses anyone had ever
seen are exactly the two where the sign cannot matter — fully spread is 0° either way, and fully
folded is `Transparency = 1`. Takeoff crosses the wrong region in 0.28s while the bird translates
away. **A bug can live indefinitely in the states you never hold still and look at.** Tests now
state the fold as a direction rather than repeating two magic numbers.

**Owner rulings this session:** wings may be visible while perched after all, since a flutter is a
half-unfold (an amendment to their own 2026-08-22 "completely disappear" ruling, made when asking
for the flutter); three flexes, not two; a turn is a short hop that changes facing.

**A floor, set by the product rather than the animation.** 0.5s is as quick as the flutter goes: a
flex is an up and a down, and at 0.5s each of three gets five frames on a 30fps phone. Below that
the peaks fall between samples and the flexes come out uneven. Pinned by a test, so the next person
to reach for "quicker" is told rather than finding out on a device.

**On my own tests.** Three of the assertions I wrote this session were vacuous and I only found out
by deliberately breaking the code: a spot-checked `wingAngle` that passed against the very
implementation it was replacing (both sampled instants fell between bursts), a transparency test
that passed against the binary version it existed to replace, and — caught before shipping — a
guard that would have stopped biting if it read its own constant on both sides. Same shape as the
`FLIGHT_MIN_TIME` test a week ago. **Mutation testing is not optional on this file.**

## [2026-08-25] defect | A string require killed the whole server, and no test could see it

`TreatmentApplier` carried `require("../shared/KamonDraw")` from `39ad15f` (the sashimono split).
Correct on disk — Lune resolved it, all 1465 tests passed, selene was clean — and nonsense in the
DataModel, where `src/server` is `ServerScriptService.Roshambo` and `src/shared` is
`ReplicatedStorage.RoshamboShared`. There is no `shared` sibling to walk to.

`main.server` threw while loading and **everything after that line never ran**: no round clock, no
server contact, and a trail of "Infinite yield on TeahouseSites" from client controllers waiting on
a folder the server never got far enough to create. Owner found it in play: *"I don't seem to be in
contact with the server."*

Fixed by injecting KamonDraw like every other collaborator that thin adapter uses. Guarded by
`tests/RequireConvention.spec`, which walks `src/` and fails any string require crossing the
shared/client/server roots; relative requires WITHIN a root stay legal. The guard strips comments
before scanning — its first version flagged the note documenting this very bug.

⚠ **The class matters more than the instance.** Three days of play would have caught this; a test
run never would. Cross-runtime path resolution is invisible to a test suite that runs in only one
of the two runtimes.

## [2026-08-25] decision | Nothing auto-deploys any more, and CLAUDE.md stopped claiming to be authoritative

Owner: *"pushing keeps triggering CI builds which I think aren't actually needed?"* Correct, for
the two that cost anything. Both AWS auto-deploys are now **off** ([[deploy]]).

Neither App Runner nor Amplify supports path filters, so both rebuilt on every push to `main`
whatever changed. The push that prompted the question was 15 `roblox/` files and 7 `docs/` — zero
frontend, zero server — and it redeployed the backend and rebuilt the frontend regardless. The
App Runner half was worse than waste: that service **is** the dev backend Studio talks to, so
pushing during a session bounced the thing under test.

GitHub Actions stay on. They are already path-filtered and take 20–60s. Worth knowing: their
filter applies to the whole PUSH RANGE, not per commit, so a batch containing one `roblox/` commit
runs `roblox-ci` once even if everything else is docs — which is right, since it tests the tree
actually pushed.

**The owner's larger correction, and it landed.** Asked which service Studio pointed at, I quoted
CLAUDE.md. Owner: *"CLAUDE.md is not authoritative for repo/system state - the wiki is - and
CLAUDE.md should clearly state that it is not authoritative."* On checking, CLAUDE.md still named
the dev backend's branch as `m4b-zendojo-art-pass` — retired on 2026-08-16, nine days earlier —
and implied the dev service builds from `apprunner.yaml`, which it does not (it is API-configured).

⚠ **This page and [[deploy]] were both already correct.** The wiki had the branch, the retirement,
the API-not-yaml detail, and the `update-service`-replaces-wholesale warning that made today's
change safe. The only stale source was the one file nothing checks. CLAUDE.md now opens by saying
so, and its deploy note carries the `aws` QUERY rather than an answer — a fact that goes stale
silently is worse than a command that cannot.

⚠ **The cost of the change, recorded so it is not discovered the hard way:** pushing server code no
longer makes it live. Testing a `server/` change against Studio now needs an explicit
`start-deployment`, or you test the previous build and believe it is the new one — a silent failure
that looks exactly like "my change did nothing".

## [2026-08-25] gate | The bird flies properly — arc, gear, and a beat with a vertical axis

Owner: *"bird is looking good, let's roll with those settings."* As-built on [[familiars]].

Three findings from the first watched flight, all measured rather than guessed after the fold sign
proved a coin-flip that would have been lost:

**The beat had no vertical component.** It spent its whole amplitude on the same horizontal axis
the fold uses, so the bird sculled — and the wing visibly shortened each stroke, because rotating
in the horizontal plane foreshortens the span. local X moves the tip 0.712 studs vertically and
0.000 fore-aft; local Z the exact reverse; local Y, which runs along the span, moves it not at all.

**The owner's correction changed the fix.** *"In actual flight it's both."* Right — a real beat is
compound, so the answer was to ADD the missing axis 90° out of phase rather than replace the wrong
one. Downstroke sweeps forward as it descends; the upstroke recovers back and up. In phase, the two
would trace a straight diagonal and retrace it — a line, not a loop, and worse than what it
replaced.

**The arc keyed off the wrong clock.** `along` is a speed integral, near zero at launch because the
bird starts at rest on a perch; `rise` was a function of raw time and climbed immediately. At 10%
of a flight: 0.76 studs forward, 1.64 up. Rise now keys off distance covered, which is what an arc
is.

**And the legs stayed down.** +100° at the hip folds the whole leg chain inside the body's bounding
box, so no knee bone is needed; at rest the foot protrudes 0.045, which is correct.

⚠ **A diagnostic had to be built before any of this could be gated**, because flights are on a
10–60s random hold to a random perch — a change to the beat was literally unwatchable.
[[familiars]] carries how to run it, and the short version is RUN IT IN EDIT.

**On three failed handoffs of that tool, because the pattern is the lesson.** It was handed over
three times and failed three times: verified that its pieces existed but not that they composed (a
0..1 fraction spent as studs); verified in one datamodel while the owner ran it in another (server
parts never reach the screen under StreamingEnabled); and finally, a stripped-down probe left
running and described as the tool, carrying two bugs the tool did not have. **Each time the thing
verified was ADJACENT to the thing shipped.** What held was running the real file end to end and
reading coordinates back over a full round trip.

⚠ **And it damaged the place before that was noticed.** FLIGHT borrowed two perches by untagging
them and restoring on cleanup — safe in Play, where the edit dies with the session, but in EDIT it
is a change to the saved place. Four Overlook perches were found untagged (322 of 326) and repaired
by hand. **A tool that mutates shared state needs its failure path designed, not just its happy
path.** It no longer touches tags outside Play, where there are no familiars to exclude anyway.

## [2026-08-25] drop | The worn sashimono is out — "a bit on the nose" for a social experience

Owner: *"I'm not digging the sashimono; it's a bit on the nose for an experience meant to be social
as much as anything else."* The back banner built 2026-08-22 (`39ad15f`) is **dropped as a worn
prop**. Do not re-raise it in that form.

⚠ **The objection is to the MARTIAL FRAMING, not to the proportions.** The 2026-08-22 log recorded
"a bit much" as possibly meaning size, and left that open. It did not: a sashimono is battlefield
identification, and the program bar for this game is *hangout is the product* — so the costume is
what jars, and shrinking it would not have helped. The open question from that entry is now closed
by the harder answer.

**Still true, and still unsolved:** grade has nowhere to live. Bands on the bird were set aside
2026-08-21 (a 7-inch bird cannot carry status at arena distance); the worn banner is now out; and
item 6's REWARD half stays unproven while its display half works. The owner's next proposal is a
HUD treatment — something hovering beside or above the avatar rather than worn.

Also gated this session: **45 degrees of wing beat is final** ("45 degrees of beat is fine").

## [2026-08-25] decision | The avatar must stay culture-neutral — a Chinese-themed area is planned

Owner, 2026-08-25: *"I'm worried about heaping too much Japanese cultural signifiers onto an
avatar, because I'm thinking the next expansion area will be Chinese-themed, and I don't think we
want too much of Japan leaking into the Chinese area."*

⚠ **THIS IS A STANDING CONSTRAINT ON EVERYTHING WORN OR CARRIED, not a note about one prop.** The
avatar TRAVELS between themed areas; the architecture does not. So the two have different rules:

| | lives in | may be culturally specific? |
|---|---|---|
| **architecture** — noren, nobori, teahouse, lanterns | one area | **yes** — that is the point of the area |
| **avatar and anything on or around it** | every area | **no** — it walks into the next theme |

**Consequence for grade, and it is structural:** identity and rank must DECOUPLE. The `kamon` is a
Japanese family crest — culturally located, so it belongs to architecture and should stay there.
Grade travels with the player, so its carrier has to read without Japanese (or Chinese) coding at
all.

**And it cannot depend on owning a teahouse.** Owner: *"let's not assume everyone has a teahouse,
and... linking a teahouse flex or display to a specific player isn't straightforward."* So the
static half of item 6 cannot be the only answer to flex — a mobile channel is required, not
optional.

⚠ This retires a whole class of answers that looked fine an hour ago: worn crests, the sashimono in
any form, and anything else that hangs a Japanese signifier on a body that will shortly walk into
a Chinese-themed area.

## [2026-08-25] decision | Grade's reward is the UNLOCK; auras carry live state instead

Owner rejected grade-as-a-bird-ladder — *"a player may prefer a smaller bird to a larger one,
independent of their actual grade or standing"* — and proposed the better shape: **the five birds
are UNLOCKS**, each becoming available to choose as a player progresses.

⚠ **That resolves the tension the sashimono could not.** Status becomes OPT-IN: you signal it by
flying a rare bird, which you could only have if you earned it, and you are free not to. A badge
everyone must wear is a ranking; a rare thing you may choose is a flex. Same information, opposite
social feel — and it is why every worn answer failed.

**The consequence, stated so nobody treats it as an oversight:** grade has NO guaranteed public
display. A 5th dan flying an uguisu reads as ungraded. That is the deliberate cost of opt-in.

**Auras carry live state instead**, on a different clock — owner's proposal. Specced at
`docs/superpowers/specs/2026-08-25-streak-aura-design.md`; not planned, not built. It shows
`stakingStreak` (the run still at risk — banking resets it, `currentStreak` survives), and rarity
is automatic: a 3-streak is ~1 in 27, a 5-streak ~1 in 240, so the arena is dark most of the time
and the glow is scarce exactly when it is impressive. The banner failed on this axis; the aura wins
on it.

**Measured for the spec:** the Highlight cap is **255 per client**, not the old 31 — 50 players
fits. ⚠ Overflow is **SILENT**: 300 created, zero warnings. And toggling `Enabled` is ~50× cheaper
per operation than creating (0.12ms for 100 flips vs 3.09ms for 50 creates), so an aura that flicks
on and off must POOL its Highlights and never churn them.

⚠ **One real dependency:** the client cannot see anyone else's streak. `familiarRoster` carries
grade/gradeName/band only, so `stakingStreak` has to join the payload and the broadcast becomes
per-round.

⚠ **The leader halo is deferred, and not for effort.** It would crown whoever tops a board that
still ranks on points-per-throw behind a floor derived for win rate — where twenty identical blind
players produce a winner by chance alone. A quiet board showing a noisy ranking is survivable; a
glowing crown broadcasts noise as achievement. Item 7's basis is the prerequisite.

## [2026-08-25] decision | Two kinds of aura — JUICE and SENIORITY — and rarity was a symptom, not a defence

Owner, on seeing the streak aura in play: *"who cares about auras if only 2 or 3 are ever even
visible on your server? We're either measuring the right thing badly, or measuring the wrong
thing."*

⚠ **RARITY WAS ARGUED AS A FEATURE AND IS ACTUALLY A SYMPTOM.** The spec defends the design by
noting a 3-streak is about 1 in 27, so the arena stays dark and the glow is scarce when it matters.
That reasoning is half right and half backwards: scarcity stops clutter, but a signal almost nobody
can display is a lottery rather than a flex — and in a high-turnover server a STAKED streak is
especially fleeting, because banking ends it and leaving ends it.

**Two distinct things are worth showing, and only one is built:**

| | what it measures | shape |
|---|---|---|
| **juice** | points on the line RIGHT NOW (`stakingStreak`) | volatile, rare, ends on any bank or loss |
| **seniority** | personal best win-streak, independent of betting (`bestStreak`) | monotonic, durable, survives logging off |

`bestStreak` already exists on `PlayerProfiles` and in the Mongo model, so seniority is mostly a
display question rather than a data one. It is also the half that answers *"why should a new player
ever see one"* — many more people hold a personal best than are mid-run at any instant.

**Not yet decided:** whether they are two auras, one aura with two channels, or seniority belongs to
a different carrier entirely (it is closer to grade, which the unlock model already handles). Do not
treat the built aura as answering seniority — it does not.

⚠ **Owner ruling on the floor: 2, not 3.** *"Let the kids dress up if they want."* The floor is an
access decision, not a tuning number: it decides who is allowed to be seen at all. That supersedes
the rarity argument in `StreakAura` and its spec, both of which reasoned the other way.

## [2026-08-26] drop | The loss animation is gone, and the victory bird faces forward

Owner: *"no bird animation for a loss or tie."* LOSS now resolves to RESTING immediately, so the
bird never leaves its perch on a loss. Only a WIN moves it.

⚠ **This retires "A LOSS MUST NOT COME HOME"**, a rule that stood from 2026-08-18 on the grounds
that a loss returning to the resting orbit would make "lost" and "has not thrown" identical. The
reasoning was sound; the owner has ruled the distinction is not worth an animation. The bolt-and-
sink was watched the day before and rejected as *"not in the same visual class as a bird dancing on
your shoulder"*. **Do not reinstate the low orbit to restore the distinction** — the old
configuration is kept as a comment precisely so that bringing it back requires a decision rather
than a rediscovery. The four tests that encoded the old behaviour were inverted rather than deleted,
for the same reason.

**The deeper thing this settles.** The vertical grammar that the familiar was designed around — up
means won, down means lost — is now effectively gone. It broke first on 2026-08-21, when WIN moved
from a high orbit to the shoulder because a 7-inch bird at 8.2 studs read as an insect: PROXIMITY
BEAT HEIGHT. LOSS was the last thing still living under the old rule, orbiting where nothing was
legible. Both halves have now been decided the same way, a week apart, and the second only because
the first was watched properly.

**Also gated this session:** the victory bird faces FORWARD with the avatar (superseding a 46-degree
outboard yaw whose two justifications both failed — the owner prefers forward, and forward clears
the tail from the head better than the yaw that claimed to), and its perch moves to the middle of
the shoulder rather than out over the arm.

## [2026-08-26] drop | The sashimono is deleted, and the victory song waits for the landing

`SashimonoController` is **removed from the codebase**, closing the chain that ran 2026-08-22 →
2026-08-25: built, disliked, dropped as a design, and now gone as code. Nothing referenced it.
`KamonDraw` stays — the teahouse nobori still use it, and architecture may be as culturally specific
as it likes. Only the avatar may not.

**Two familiar fixes from the same look:**

⚠ **The bird's feet sank into the shoulder.** Its origin is at the feet, so seating it on
`arm.Position + Size.Y/2` should stand it on the surface — except a part's top FACE is not the
visible shoulder. The R15 arm mesh, and anything layered over it, sits proud of the bounding box.
Lifted by a proportion of the arm rather than a constant, so scaled avatars lift to match.

⚠ **The song could arrive before the bird did.** The stagger fired it 0–2.2s after the cue while
`ENTRY.WIN` is 2.4s, so a win could sing while the bird was still flying in. It now waits the full
entry first, which puts every song over the dance — the moment it was written for.

## [2026-08-26] gate | The streak aura reads — and the victory song finally waits for the bird

Owner: *"Aura is reading fine."* ⚠ **GATED** after two rejected versions, and what changed between
them is the transferable part:

**v1 — a Highlight whose transparency ramped with the streak.** Rejected: *"the differences in color
are not obvious (at least, not in the singular)."* The flaw was the CHANNEL, not the palette. A ramp
is readable only COMPARATIVELY, and with a low floor a lone glowing player is the ordinary case — so
the design picked a channel that fails in the situation it is actually in.

**v2 — particles, emitted from inside the torso.** Rejected: *"only emitted while the avatar is in
motion, and seem to be emitting from the avatar's ass."* Two symptoms, one cause: the attachment sat
INSIDE the body, so particles spawned occluded, and walking left them behind in world space.

**v3, gated:** embers from the FEET, `LockedToPart` so they travel with the player, three times the
size, and rate + pulse tempo carrying the streak because **rate and tempo can be counted off one
body where brightness cannot.**

**And the metric changed underneath it**: `currentStreak`, not `stakingStreak`. Banking resets the
latter, and banking is THE decision in Roshambo — tying the reward to not-banking punished the
action the whole loop is built around.

**Two familiar fixes, both of which had been approximated with constants and are now measured or
event-driven:**

⚠ **The seat lift is arithmetic now.** R15 `RightUpperArm` is 1.213 studs tall, so the 0.10 factor
lifted the bird 1.46 inches — the owner called it an inch high, and 0.031 lands it at 0.45.

⚠ **THE SONG NOW FIRES ON THE LANDING, because no timer can know when that is.** Three attempts:
a random 0–2.2s, then `ENTRY.WIN` (2.4s) plus stagger, then this. Both timers sang early, and the
reason is structural — the bird FLIES to the shoulder and `flightDuration` is 0.85s plus distance
over cruise speed, so a bird twenty studs away needs 2.65s and one across the canyon needs far more.
**Any constant is wrong for every distance but one.** The song is now armed by the cue and fired in
the update loop at the instant the dance begins, where "has it landed" is simply true rather than
estimated.

## [2026-08-26] ship | The karasu is built — second bird of the roster, life size, waiting on import

The crow familiar is modelled, rigged, textured and verified, and stops at the import gate: the
asset thread does not touch Studio ([[parallel-threads]]). Body 0.328 × 1.640 × 0.897 studs and
2,666 triangles, wings 2.446 studs tip to tip and 856, one 19-bone rig shared by both parts, feet
at the origin. As-built and the import instructions on [[familiars]]; the traps on
[[blender-pipeline]].

**Owner ruling this session: life size, 1.64 studs / 19.7 inches** — three times the uguisu. It
follows the two standing rulings rather than inventing one, and it hands the main thread real work:
`SEAT_INBOARD`/`SEAT_LIFT` are proportions of the avatar's arm, not the bird's, so they will not
seat a bird three times longer without retuning.

⚠ **The crow was expected to be cheap for a reason that turned out not to be the reason.** The
brief was that its purchased model already has the wing bones the sparrow lacked — true, and
irrelevant: the uguisu never needed them, because it builds `wing_*`/`wrist_*` itself on a separate
spread-wing part, and what makes those bones work is their AXES rather than their existence. They
are deleted and rebuilt. What the purchase *did* buy, measured rather than assumed, is a body
unwrap with **23 overlapping texels out of 108,504 and zero mirrored** — which is what makes a
shade-as-a-function-of-3D-position bake legal at all — and a crow's head and bill, which no amount
of reshaping turns a sparrow into. The conclusion held; the reasoning did not.

**And it was not a data edit.** `bird_familiar.py` keeps species as a dict of proportions and
`bake_bird_texture.py` keeps palette as named colours, both true — but the generator never shipped
a bird (it survives as the SPEC), the crow ships its wings SPREAD and welded into the body where we
need them folded, its tail is 48 triangles of alpha card against a plain ColorMap, and it has no
jaw. The palette transferred; the shading LAW did not, because an uguisu is defined by two field
marks and a karasu has none — `shade_corvid` is its own function rather than `shade` with two flags
off.

**A crow is not black, and painting it black was wrong.** The first palette ran 28–88 and rendered
as a silhouette — accurate as a photograph, useless as a familiar, which has to stay legible across
a crowded arena on a phone. Lifted ~35%, with countershading carried by HUE (cool blue-violet
mantle over warmer duller underparts) rather than by lightness. Two lines do the rest of the work:
the covert edge, because the folded wing is deliberately low-relief geometry and its edge has to be
drawn, and a catchlight, because a crow's eye is as dark as its head and without one the face is a
blank.

**A wing is not a comb — and neither is a tail, nor a folded wing.** `spread_wing.py` recorded this
for the spread wing in August; the karasu met it twice more in one session. A tail of seven
graduated blades stepped into a visible staircase at 1.64 studs, and a folded wing of one covert
plus three primaries read as loose slats. Same fix both times: one continuous surface whose OUTLINE
identifies it. The uguisu escapes it only by being a third the size.

**On my own accuracy.** The brief said the crow ships "two 465-vertex eyeballs" needing cleanup.
They are 465-vertex FEET — weighted to the leg chains, not the head. The cleanup was still needed
(920 triangles each against a 1,352-triangle body, decimated to 130) but it is a different job than
the one described, and it changed which end of the bird got the attention.

**Also fixed while here:** the uguisu's retarget existed only as a `.blend` on one machine, so
bird #2 had to rediscover every step from prose. `roblox/tools/blender/karasu_retarget.py` is
re-runnable end to end and is the standard for bird #3.

## [2026-08-26] decision | The asset thread is retired after one task — the split half has to be able to ship

Owner: *"let's collapse this thread back to the main one."* Blender work returns to the main thread.
Contract updated on [[parallel-threads]]; nothing is lost, because the pipeline is a re-runnable
script (`roblox/tools/blender/karasu_retarget.py`) rather than a `.blend` on one machine.

It was set up as the best parallel candidate in the project and the reasoning looked sound — a
different tool, a different directory, no Studio, no place file. **Two things broke it, and both
generalise past this repo.**

**A split only pays while the owner is doing something else.** [[parallel-threads]] already said the
constraint is the place file and the owner, and that more threads do not widen the gate. It stopped
one step short: when both halves of a feature must land before anything ships, the owner stops
being a *gate* and becomes the **message bus** — relaying the merge, relaying the import, carrying
context between sessions by hand. The karasu ended in a four-step hand-off of which the owner could
execute none directly.

**And the thread built ahead of the constraint.** Nothing selects a bird per player; the unlock
model was decided 2026-08-25 and is unbuilt. So bird #2 is inventory, not progress on item 6, which
needs roster selection and a public display of grade — both code, both main's. ⚠ An isolated thread
is structurally prone to this: it cannot see the queue it is not blocking on, so "what can this
thread do independently" quietly replaces "what is next". The independence that makes a thread
parallelisable is the same property that lets it work on the wrong thing. I should have said this
at the START of the session rather than at the end of it.

**The test before splitting again:** can the split half SHIP without the other half? The design
thread passes. The asset thread did not.

## [2026-08-26] ship | The karasu is imported and its rig verified in the place

Merged `thread/assets` (`c2ffc27`, `c5dce64`) and imported both halves. Parked in
`Workspace.Sandbox.KarasuProbe`, 12 studs above ArenaSpawn, nothing within 6 studs. ⚠ Not wired
into play — nothing selects a bird per player, so this is inventory rather than progress on item 6,
which the asset thread said plainly when it retired itself.

**The rig drives correctly.** Seven bone-drive pairs, all non-zero on the chain and exactly 0.0000
off it, and the axis contract reproduces the uguisu's — local X moves both tips the same sign and
only vertically, local Z mirrors and only fore-and-aft. That is the pair of facts `BirdController`'s
beat and fold are written against, so the crow will drive under the existing controller unchanged.

⚠ **THE UGUISU IS NOT THE SIZE THIS WIKI SAID IT WAS.** [[familiars]] recorded 0.552 studs, "life
size, ~7 inches". Measured off the committed `.rbxm`: **0.828**, and nothing rescales the clone —
`BirdController` has no `ScaleTo` and no `Size` write. So the shipped bird is ~10 inches and every
ratio derived from 0.552 was out by 1.5×, including the karasu page's "three times the uguisu",
which is really 1.98×. The page had carried the DESIGN figure as an as-built for a week.

⚠ **AND MY FIRST BONE-DRIVE TEST WAS WORTHLESS.** Four of its five rows measured the DRIVEN BONE
AGAINST ITSELF — a bone cannot move under its own rotation, so those rows could only ever read
0.0000, and read as a clean pass. Only the one row that happened to probe a descendant was a real
test. Rebuilt to measure a descendant against a bone on another branch. **A test that can only
return the passing value is not a test**, and this is the fourth instance of that shape in two
days.

**Two importer settings the instructions did not carry**, now added: Anchored TRUE (it IS in the
dialog — the previous note here denied that, wrongly), and vertex colours OFF, which matters more
on a crow than it did on the uguisu because a bird that ships 85% too dark and is already black
does not announce itself.

## [2026-08-26] gate | Both wingtips taper — and watchWingbeat can show either bird

Owner: *"wingbeatwatch looks fine."* The squared-off tips are gated on both birds. Karasu tip chord
0.244 → 0.062 studs, uguisu 0.114 → 0.044, with the angle of attack now scaling with the local
chord so a narrowed tip no longer pitches down (karasu 19.2° → 4.1°, uguisu 45.3° → 23.9°).

Both `.rbxm` assets are committed and all four birds are declared in `default.project.json`.
⚠ The karasu is still INVENTORY — nothing selects a bird per player.

**`watchWingbeat` takes a `SPECIES` now**, and every framing number is DERIVED from the chosen
bird rather than typed: viewing distance is 3× body length, trace beads 1.5% of it. The karasu is
twice the uguisu, so a constant tuned for one is wrong by 2× for the other — the tool would have
parked a crow half in the camera. Verified by running it: 4.92 studs back against the uguisu's
2.48, all four wing bones resolved, 90 trace beads lit.

⚠ **The uguisu's shipped wing was NOT what its generator produces.** Measured during this work:
`spread_wing.py` yields about 8° of angle of attack at the root, the shipped mesh sits at 23.9°
across its whole span, and its chord extent differs from the blend's. The asset had been reshaped
after the script ran by a step nobody recorded — so the script is that wing's ORIGIN, not its
definition, and the tip fix had to be applied to the MESH. `spread_wing.py` now carries a warning
saying so. This is the same failure as the recorded size, one layer down: an artifact drifting from
its record with nothing in place to notice.

## [2026-08-26] defect | The staleness hatch was unusable by construction, and it broke main the day it shipped

`checked:` (rule 10, shipped 7fada0b) could not be used without failing the lint. Adding the field
COMMITS the page; check 7 compared the page's commit date against `updated:` and knew nothing about
`checked:`; so the only way to clear the resulting error was to bump `updated:` — asserting an edit
nobody made, the exact lie the second field exists to avoid. **All seven pages that received
`checked:` in that commit failed the lint it introduced.** Main was red from the moment the feature
landed.

Found by the design thread, which verified rather than assumed: all seven byte-identical to main,
same last-commit date, so provably main's failure and not a rebase artifact. It **declined to bump
the dates** — bumping seven pages it had not re-read would have been the small frontmatter lie rule
2 warns about. That refusal is why the mechanism got fixed instead of papered over.

Fix: check 7 now asks when the page's BODY last moved, read from the diff (`gitContentDateOf`) —
a commit touching only `checked:` does not count, and one touching body *and* `checked:` still
does, which trusting the frontmatter could not tell apart. Schema rule 6 said `updated:` is
"bumped on every edit", the textual half of the same contradiction; corrected in place along with
two other passages that still named `updated:` as the hatch.

⚠ **The first two tests were vacuous and mutation testing caught it.** They injected
`gitContentDate`, so they proved check 7 was WIRED to the helper while never executing it — both
survived mutating its body. A third test drives it against a real temp git repo; all three
mutations fail it now. Second time this session that an injected dependency produced a test which
could only pass.

Also fixed while in there: both git helpers ran with the process's cwd, so any page outside it
returned `''` and silently disabled checks 7-9. They now run from the page's own directory.
