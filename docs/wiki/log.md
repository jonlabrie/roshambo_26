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
