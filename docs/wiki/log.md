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
## [2026-08-26] decision | Seniority gets no carrier — and the owner named the three clocks that say why

Owner, on the gated aura: *"who cares about auras if only 2 or 3 are ever even visible on your
server? We're either measuring the right thing badly, or measuring the wrong thing."* They named
two candidates — juice and seniority. **Seniority is out**, and the count was exact rather than
impressionistic: at p(win) ≈ 0.30 under plurality, P(streak ≥ 2) = 0.09, so a 30-player server
yields 2.7 glowing. The design's own arithmetic produced the complaint.

⚠ **Seniority is not "closer to grade" — it IS grade.** `bestStreak` already drives the
`run.3/5/7/10` milestone family in `Milestones.ts`, so it already feeds grade → band → the familiar
unlocks. A second carrier would render overlapping inputs as two disagreeing rankings on one body.
It also fails on durability — a durable rank worn by everyone is exactly what killed the sashimono,
and the visibility toggle does not rescue it, because opt-out is not opt-in. And on density from
the other side: `bestStreak ≥ 3` is ~50 minutes of play (nearly everyone) while `≥ 5` is ~10 hours
(almost nobody), with nothing usable between — the two thresholds bracketing that gap being `run.3`
and `run.5`, which already exist.

**Then the owner settled the whole architecture in one line:** *"the Aura/grades/whatever need to
show current skill/luck, longer-term success, and levels earned and held forever."* Three clocks,
now on [[status-display]]. ⚠ **The middle one has no carrier and nobody was designing it** — every
rejected proposal was trying to put *forever* on a body, and forever already belongs to the
unlocks, while *lately* sat unclaimed. Its data is already computed (`stats.heatBoard`), as a board
with no presence on or around the player. And *forever* is settled but **silent**: nothing
announces a grade-up and nothing prints the grade, so the private half is owed before anyone
designs where strangers read it.

## [2026-08-26] decision | The aura must be neutral on Bank vs Stake — three metrics fail it

⚠ **THE STANDING RULE, arrived at by getting it wrong twice.** Bank-or-Stake is the only real
decision in Roshambo, so any metric either branch changes puts a thumb on the scale of the choice
the game exists to pose — **and it must never reward being present without playing.**

I proposed re-keying the aura to `pointsAtStake` on density grounds. Owner: *"pointsAtStake is NOT
the number; I don't want to lean into 'current risk level' being what kids are relying on for flex
because it DISCOURAGES PLAY. If you get to an impressive AURA level, why risk it, and why bank
it?"* Correct, and worse than stated: `settleRound` iterates `data.throws` only, so an unthrown
player is never settled and keeps pot, streak and aura indefinitely. The glow-optimal strategy
becomes **reach a deep pot and stop playing.** Third instance of one error — `stakingStreak` paid
you never to bank; `pointsAtStake` pays you never to bank *and* never to throw; and the shipped
`currentStreak` carries the same trap weakly, since a 6-streak is preserved forever by not playing.

⚠ **And a correction to my own over-reach, which the owner supplied.** *"I don't mind 'paying'
players to be online — given Roblox's incentive structures… paying players to stay in the game,
return to it often, is a core Roblox game development strategy."* Rewarding **presence** is the
business model; rewarding **presence without play** is the failure. RPS here is the **ambient**
game — players socialise and throw occasionally.

**Proposed replacement, not yet ruled on: a decaying peak** — the highest pot you have *reached*
recently, fading. Banking and losing both leave it alone; only winning raises it; only time lowers
it. ⚠ It is **not a "session" peak** — a `Session` is scoped by platform AND instanceId, so a
boundary would zero the glow on a server hop, a PWA→Roblox walk or a dropped connection, and would
pay players not to log off. Rules ruled since: `>=` not `>` (matching your value resets the clock —
*"obviously"*), comparing the **decayed** values not the raw ones, wall-clock decay at one rung per
2 hours, and **a win buys back time** — which is what carries the ambient player without the
per-throw decay that would pay them to stop throwing. ⚠ It needs **no new storage**:
`PlayerRound.pointsDelta` on a WIN records the new pot value, so the documented trap that makes
summing the column wrong is exactly what makes `$max` over it right.

**Also surveyed, since the owner asked whether decay is a general unlock:** it largely already is.
`windows.ts` + `stats.heatBoard` are windowed leaderboards with the period as an argument. ⚠ Not on
`totalPoints` — no timestamps, and it is a wallet purchases decrement. **General rule: to window a
quantity you need an EVENT ROW, not a counter**, which makes it a checklist rather than an
architecture — and the gap is retroactive. One quantity is missing: purchases write nothing
(`store.ts:49`), so **spending is unanswerable until a `PurchaseEvent` exists**, and that wants
landing before the fireworks catalog, not after.

## [2026-08-26] drop | Multi-hand splitting set aside — parking is a free option

Owner proposed up to 3 working hands, blackjack-split style: park a good streak unexposed, build a
new one, choose in advance which hand is at risk each round. Asked for brutal honesty rather than
support. **Set aside** — *"impractical for now. I'll give it more thought."*

⚠ **The finding worth keeping: parking dominates both Bank and Stake at no cost** — it keeps the
pot, risks nothing, and can still grow. Bank-or-Stake is a dilemma *only* because there is no third
choice, so this removes the game's only decision. Predicted equilibrium: build to the depth that
feels frightening, park, repeat until slots are full, bank one to free a slot — press-your-luck
becomes accumulation. Concrete casualty: **`stats.livePots` goes permanently quiet**, and that
board exists for exactly one reason, *"someone is holding 243 points right now and has to decide"*.

The blackjack analogy breaks on four properties, deepest being that a split draws independent cards
while every hand here resolves against the **same World Throw** — so which hand you aim at carries
no information, and the risk-neutral answer is always "the biggest".

⚠ **One correction owed to the owner:** my "throwing at all three hands is catastrophic" note was
my own extrapolation, never their proposal. It stands as a guard-rail, not a rebuttal.

**And it produced the better door.** Partial banking — bank down to a lower rung, pocketing the
difference — was named as the cheaper way to get the risk-granularity the owner wanted, and the
owner took it up. ⚠ The math does not break: nothing requires a pot to be a power of three. An
ideal strategy does fall out, and **its shape is what saves it: `f* = (bank ÷ pot + 1)/4` is a
RATIO, not a constant.** A single publishable number would have solved a decision that today has no
correct answer; a ratio moves with the player's own position every round. The optimum is also flat
near the top (riding a third scores 89% of optimal at zero bank), so play does not reward
calculator work — and ⚠ **at bank ≥ 3× pot, riding the whole pot is optimal**, so the dramatic play
is not made wrong, it is made *earned*. Recommended shape: drop to a lower rung, which keeps every
pot a power of three by construction and every difference an integer, so *"never 13.5"* holds
without rounding. Not ruled on.

## [2026-08-26] decision | TEST_MODE is a test affordance, and citing it as a blocker was an error

⚠ **I called TEST_MODE a reason not to build things, four times, across four documents.** Owner:
*"I don't know why I keep getting the R-P-S test loop thrown back in my face as a condition that
makes something 'untestable'; how am I meant to test functionality of win-streaks in a
non-deterministic system without having to wait for said streaks to fall out of the randomized
sky?"*

Correct, and it inverts the claim. **Two questions were being collapsed into one:**

| question | needs | verdict |
|---|---|---|
| **does it work?** — pot math, streak rules, row writes | **DETERMINISTIC outcomes**, so any streak can be constructed on demand | ⚠ TEST_MODE is the RIGHT tool |
| **is it tuned right?** — is p(win) really 0.30 | real crowds, 10+ players | not ready, and rarely the question |
| **do players use it?** | shipping to friends & family | a product question, not a test |

**A randomised World Throw makes the first question HARDER** — testing a 4-streak would mean waiting
for one to occur by chance. That is already the repo's own position everywhere else:
`shared-fixtures/game-rules.json` gates three implementations against **constructed cases, never
sampled play** ([[core-loop]]). The correct statement is narrow — derived RATES are unvalidated
until the plurality rule is live and crowds are real; the MECHANICS are testable today, TDD as
usual. Corrected in the juice/seniority and partial-banking specs.

**Also ruled this session, on partial banking's first open question.** Owner: *"we don't zero
stakingStreak if the pot isn't zeroed."* The condition moves from *"a bank happened"* to *"the pot
reached zero"*, so a full bank behaves exactly as today and the partial case needs no special code.
`currentStreak` stays untouched either way.

**And the other two open questions were traced rather than guessed.** ⚠ **`bankDepths` is the one
real casualty**, and it is a shipped display: the NERVE histogram on the 番付 room wall
(`statsV1.ts:170`) plus a personal median (`:193`). A partial bank writes `streakAtBank` too, so a
player who drops one rung at streak 6 records the same `6` as one who cashed out at 6 — blending
*"when do players stop"* with *"when do players hedge"*. No error, no failing test, just a stat that
quietly becomes about something else. **Fix is one boolean** (`BankEvent.partial`, filtered out of
`bankDepths`), cheap now and impossible to reconstruct later — the same retroactive shape as the
missing `PurchaseEvent`.

⚠ **`pointsDelta` needs nothing, and I had overstated it.** A partial bank is a WALLET action and
writes no `PlayerRound` row, exactly like a full bank today — so `biggestRounds`, the forfeits sum,
the PWA per-round banner and the big-wins feed all keep working. One coupling worth knowing before
either feature is ruled on: a hedger reaches smaller pots, so their peaks are smaller, so **partial
banking dims the proposed aura**. That does not violate the Bank-vs-Stake neutrality rule — nothing
already achieved is removed — but the two features now touch.

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

## [2026-08-27] ship | Partial banking, server half — a pot may be dropped to a lower rung

Six tasks from `docs/superpowers/plans/2026-08-26-partial-banking-server.md`, written by the
design thread. `keepOptions(pot)` returns the rungs a pot may be dropped to; `bankPot` takes a
`keep` that defaults to 0, so a full bank is the zero case and **every shipped client is
unchanged**. Both transports accept `keep`; the Luau mirror has it; the fixture gates both.

⚠ **NOTHING CAN ASK FOR IT YET, by design.** The client affordance was deliberately excluded —
the control has not been specified and the Roblox HUD needs the owner's eyes in Studio. The
server half ships alone precisely because it is backward compatible.

Two rulings made during execution:

1. ⚠ **The plan's task order could not work.** Task 2's tests assert `BankEvent.partial` but the
   field arrived in Task 3, and mongoose runs strict by default — an undeclared field is
   silently dropped, so the tests would have failed with nothing pointing at why. The field
   moved into Task 2. Caught by the pre-flight scan, before any code was written.
2. **`stakingStreak` zeroes on the pot reaching zero**, not on a bank happening (owner ruling
   2026-08-26). Full banks behave exactly as before; no special case was needed.

⚠ **Mutation testing found one overstated fixture row.** `partialBankRejects`' 13.5 case claims
to prove no-fractional-points, but 13.5 is already rejected for not being a rung — the row
passes with `Number.isInteger` deleted. The guard stays as defence; the row's `why` and the
code comment now say what they actually prove. Every other row is load-bearing: `<` to `<=`
fails 7, allowing pot 0 fails 2, on both the TS and Luau sides identically.

`bankDepths` now filters to full banks so NERVE keeps measuring where players *stop* rather
than blending that with where they *hedge*. The invariant is recorded on the model: **the
filter follows the COLUMN, not the collection** — every consumer of `amount` counts partial
banks, because hedged points are real points.

475 server tests, 1515 Luau, 30 PWA. tsc, stylua and selene clean.

## [2026-08-27] audit | backlog.md condensed by hand — the experiment, and what it measured

Ran one page as a test of whether supersede-don't-append is affordable without new tooling,
after the owner rejected a length check as "appending a check instead of addressing the
problem head on". **545 → 423 lines. 23 insertions against 134 deletions** — the inverse of
the 14:1 insert-to-delete ratio the wiki had been running.

⚠ **Reading was never the expensive part.** All 545 lines cost about 7k tokens. The cost was
in four verifications, and every one of them changed the answer:

1. `~~get-stats broadcasts deviceIds~~ FIXED` — the header said fixed, the body said "why it
   was not fixed inline" and gave a fix sketch. **The page was arguing with itself.** Checked
   the code: genuinely fixed. `LEADERBOARD_FIELDS` no longer carries `deviceId`, `biggestWins`
   is explicitly projected, `StatsView.tsx` no longer references it. Section deleted; the
   lesson already lives at the point of use in `leaderboards.ts`.
2. The 45-line drum-ladder writeup was a **third copy** — `stats-room.md` and
   `FlapScheduler.luau`'s "WHY SMALLEST-FIRST" comment both carry it, on the right shelves.
3. `~~The two transports disagree on shape~~ SUPERSEDED` — a struck paragraph that
   **described its own failure**: "the fix appended its own note and left this paragraph
   standing". It then stood for another nine days.
4. The identity fix was 45 lines of **standing rule sitting on a status shelf**.

⚠ **THE REAL FINDING IS NOT AGE, IT IS SHELF.** Very little on that page was stale. Most of
what came off was live knowledge filed in the wrong place — a `program/` page holding practice
rules, as-built technique and engine constraints. Accretion here is not "old text stayed"; it
is **"text landed wherever the work happened and nobody moved it"**, and a length or staleness
check cannot see that at all. Both would have passed this page every day.

Created [[identity]] to receive the standing rule (identity comes from the CONNECTION, never
from a payload) plus the device-token as-built and the hard-cut ruling. Two rulings that
existed only as prose are now one-liners on [[owner-rulings]]: the 2026-08-18 hard cut, and
`1`/`2`/`3` for throw keybindings.

**Left undone and flagged in place:** two engine constraints (the 100px `TextSize` cap, the
per-viewer SurfaceGui trick) still sit in `backlog.md` carrying a note that they belong on
[[misc-engine-traps]]. Recorded rather than moved so the next pass has a start, and so this
entry does not claim a clean sweep it did not do.

## [2026-08-27] audit | The other two long pages — and the pass found the opposite problem

Ran the backlog.md method on [[blender-pipeline]] (449) and [[familiars]] (440), the two other
pages past the schema's own 439-line mark. ⚠ **Neither was accreted, and forcing them to shrink
would have destroyed the thing worth keeping.**

**blender-pipeline.md: 0 dead markers, 0 duplication, all live technique on the right shelf.**
Verified rather than assumed — checked the transcribed FBX flags against the shipped script and
found the page CORRECT where it looked wrong: it prints `use_mesh_modifiers=True` in the static
block and `False` in the skinned block, which is exactly right, and the `⚠ True silently destroys
the rig` warning sits beside the second. Checked the two rig sections for overlap: none, they are
import-a-vendor-rig versus author-new-geometry. One real defect, and it was a SCOPE statement, not
stale content — the intro said "pipelines that feed Roblox from OUTSIDE the engine" while its own
contents list an IN-engine river. Corrected in place; the page grew by 8 lines and is better.

**familiars.md: net +12 lines, and the pass was still worth it.** The import-instructions section
was a hand-off to a thread that no longer exists, and steps 2/3/5 were third copies of traps
canonical on the pages they cite — collapsed to a checklist that points instead of restating. One
transcribed constant (`+100°` at the hip) now names `BirdFlight.LEG_TUCK_DEG` so it cannot drift.

⚠ **BUT THE REAL FIND WAS A MISSING FACT, NOT A SURPLUS ONE.** The shipped uguisu wing cannot be
regenerated from any script — it was reshaped after `spread_wing.py` ran, by a step nobody wrote
down, and sits at 23.9° angle of attack where the script yields 8°. **That warning existed only in
the script's own header**, where only somebody already editing it would meet it. The as-built page
for the birds said nothing. Now recorded on [[familiars]].

**What the three pages together say.** Length is a bad proxy twice over: backlog.md was 545 lines
and genuinely accreted; these two are the same length and are not. The signal was never size, and
it was never age either — of everything removed across all three, almost nothing was WRONG. It was
**correct material on the wrong shelf**, plus one fact filed somewhere nobody would look. A length
check, a staleness check and a decay score would each have passed all three pages every day.

## [2026-08-27] audit | Full-wiki audit — all 54 pages read against the code, 11 defects

Run because the owner rejected my claim that the wiki was in reasonable shape, correctly:
I had audited 3 pages, chosen by LENGTH — a proxy I had just finished disproving — and
generalised "1 in 3" from a sample selected on the wrong axis. **27 of 54 pages had exactly
one commit ever.** The wiki was not fine; it was UNAUDITED, which is a different claim.

### Mechanical sweeps (all 54 pages) — the citation layer is sound

| check | result |
|---|---|
| cited commit hashes resolve | **105 / 105** |
| code symbols cited in backticks exist | **0 unresolvable** |
| constants asserted vs their value in code | **0 real mismatches** |
| line-number citations | **13 removed; 0 remain wiki-wide** |
| cited repo paths exist | 0 dead (lint) |

### The 11 defects, and what they have in common

1. ⚠ [[friends-family-baseline]] item 6 **contradicted itself** — "wired into play and
   owner-gated" four lines above "NOT yet wired, nothing in play uses it", listing three
   changes all long done. On the GOVERNING program page.
2. ⚠ [[parked-defects]] — **8 of 9 line citations wrong**, under a `checked:` stamp I had
   written the day before. Every defect still real; every pointer rotten.
3. ⚠ [[place-state]] named **`CLAUDE.md` as its Authority**, inverting the hierarchy the owner
   set — and CLAUDE.md was wrong about that very subject ("7 hero-prop models"; actually 19).
4. ⚠ [[place-state]]'s pre-publish checklist **omitted the toolbox backdoor scan**, which
   [[toolbox-backdoor-scan]] has always said belongs there. The payload early-returns in
   Studio and fires only on a published server: that checklist is the ONLY place it is
   catchable.
5. [[rojo-and-place]] and [[place-state]] both missed `ReplicatedStorage.RoshamboBirds` —
   a whole Rojo-managed subtree added the previous day.
6. [[parked-defects]] contradicted [[deploy]]: "every push auto-deploys dev" has been false
   since 2026-08-25.
7. [[deploy]]'s CI path filters omitted `shared-fixtures/**` (in TWO workflows) and `public/**`.
8. [[status-display]] listed partial banking as unruled hours after its server half shipped.
9. [[wiki-currency]] — the page ABOUT this failure mode did not record that the `checked:`
   hatch shipped unusable.
10. [[familiars]] — the shipped uguisu wing cannot be regenerated from any script, and that
    lived only in a Python comment.
11. `backlog.md` — 134 lines of superseded, duplicated and misfiled content.

⚠ **NINE OF ELEVEN ARE "CORRECT, BUT NOT HERE" OR "TRUE ONCE".** Almost nothing was invented
or sloppy. It was live knowledge on the wrong shelf, a pointer that rotted while its claim
stayed true, or a page that never re-read its own opening. **Length, staleness and decay
scoring would each have passed most of these every day** — the lint was green on all 54 the
whole time.

### What the audit CANNOT settle

**13 of 21 `world/` pages rest on a live Studio verification dated 2026-08-15.** Neither I nor
the lint can re-check terrain, collision groups, prefabs or place-only folders from git. That
is a permanent limit of this method, not a backlog item.

### Cost

Reading the whole wiki: **~95k tokens, one sitting.** Reading was never the expense. Every
defect above came out of a VERIFICATION — querying AWS, grepping for a symbol, diffing a
declaration — and each one changed the verdict I would otherwise have written.

## [2026-08-27] lint | Prose lint — the lint's own test file was disarming two of its checks

First scheduled prose-lint run. Three defects, two of them in the checker rather than the wiki.

**1. `lint.test.mjs` was being read as repo source, and it silently disarmed checks 11 and 12.**
`sourceTextOf` walks the repo for `.mjs` and slurped the lint's own test file, so every fixture
string and explanatory comment in it counted as code. The test *"a constant the wiki NARRATES as
retired is exempt on its line"* quotes `MIN_SHORO_GAP = 5.0` in its comment — the real defect it
was written from. Check 12 then found a `5.0` for that constant, matched
`one-model-is-not-a-building.md`'s value, and passed the page, whose real code value is `9.0`.
**The test defeated the check it was written to guard, and the page it was written about never
needed its exemption.** Excluding the one file turns check 12 back on with exactly one hit — the
hit the test predicted. Only the test is excluded; `lint.mjs` is real source and `backlog.md`
legitimately cites `CITE_RE`/`CITE_PREFIXES` from it. Regression test added, and verified to fail
without the fix.

**2. The lint reports 231 phantom errors in a shallow clone, which is what it runs in.** This
routine's container clones `--depth`. Every commit before the boundary is absent, so all 200 cited
hashes "do not resolve"; and the boundary commit is one synthetic squash of the whole tree (755
files, one date), so every cited file appears to have changed that day. Measured: **231 errors at
depth 61, 0 after `git fetch --unshallow`.** The CLI now detects a shallow clone and refuses to
render a verdict rather than render a false one — the same reasoning as the gitignored-citation
note beside check 8.

**3. `world/teahouses.md` cited a symbol deleted seven weeks earlier.** Sub-project B was
described as `PadRegistry` *(fit-aware `claimVacantFor`)*. That helper — with `fits`, `findVacant`
and `claimVacant` — was removed as **confirmed-dead code** on 2026-07-07 (`b8db9bd`). `PadRegistry`
is occupancy only; fit matching is D's, in `SiteCoordinator`, which the same page already says.
The page carried `checked: 2026-08-26` — stamped the day before, over a dead symbol.

### Reported, not fixed — these need the owner

- **`.superpowers/` is gitignored and was never committed, and 12 wiki citations point into it**
  across 7 pages, `friends-family-baseline.md` (the governing board) among them. No fresh clone or
  CI run can resolve an SDD ledger. Invisible to check 8, whose `CITE_RE` only matches
  `roblox|server|src|tools|docs|shared-fixtures`. Schema rule 4 names `docs/superpowers/` as the
  raw layer; the ledgers are not there.
- **`systems/data.md` states the Roblox/PWA economy split as enforced as-built** — "per-platform
  wallet fields". `User.ts` has one shared wallet (`totalPoints`, `lifetimeBanked`,
  `pointsAtStake`). Rounds and bank events *are* platform-tagged; the wallet is not. `backlog.md`
  files the split under the **approved** meta-game spec, i.e. design, not built.
- **`one-model-is-not-a-building.md`'s tower table is stale and short a model.** It tops the stack
  at 153.54; `ArenaLayout.towerTopY` has been **174.17 since 2026-08-14** (`8d40514`, the sōrin),
  the day before the page was last updated. It also says SEVEN models and lists six — the missing
  one is `BonshoBell`, per `WorkspaceConvention`. Both numbers are schema-rule-9 transcriptions;
  re-measuring needs Studio.
- **`core-loop.md` says three implementations are fixture-gated "so drift fails the build".** True
  per-implementation, but the PWA fallback runs 3 of the fixture's 6 keys and has no `keepOptions`,
  so a new rule can be added to the fixture and the PWA will silently not run it.

### Coverage

Read end to end and verified against code: `core-loop`, `world-throw`, `teahouses`,
`parallel-threads` (the pages whose cited code moved), plus the rotation `systems/data`,
`day-night`, `one-model-is-not-a-building`, `replication-races`, `modal-cursor-grip`, `fireworks`,
`canyon` — 11 pages, plus `index` and `schema`. **Not read this run: the other 43**, including all
of `program/`, `familiars`, `status-display`, `round-and-hud`, `place-state`, `blender-pipeline`
and the remaining `practice/` shelf.

Studio-dependent and NOT verified: the W## watercourse inventory and pool chain (`canyon`), the
135 `VfxNightDim` objects and the `DayNightLockT` values (`day-night`), the three tagged launch
sites and `FireworkBench_PARKED` (`fireworks`), the per-size prefabs and `EngawaBarrier`
(`teahouses`), and the bell-tower model extents above.

A symbol sweep over every backticked `Module.method` in the wiki (60 distinct) found no phantoms
beyond the one fixed; `DrumStep.glideResidual` and `CanyonLayout.luau` fired and are both correct
writing — the first names a phantom in order to bury it and is already exempted.

## [2026-08-27] lint | R3 and R4 from the first prose-lint run — a page that could not count its own rows

Two of the four findings the scheduled prose lint left for a ruling. Both were settleable
without the owner; R1 (`.superpowers/` citations) and R2 (the economy split) are not.

**R3 — [[one-model-is-not-a-building]] said SEVEN models and listed six.** The missing one is
`BonshoBell`, and *why* it was missing is worth more than the row: the bell hangs INSIDE
`BonshoRig`'s span, so it moves the union not at all. ⚠ **A model that changes no answer is
exactly the one an inventory forgets** — and "it wouldn't have mattered" is a conclusion only
available after looking, which is the page's whole thesis turned on the page itself.

Its numbers are also a 2026-08-13 snapshot: the drum grew a sōrin on 2026-08-14 and
`ArenaLayout.towerTopY` has been 174.17 since, held by a rebuild-and-compare test. The
snapshot is KEPT — it is the evidence for the 17-stud error — but now says so, so nobody
reads 153.54 as the tower's height. Correcting it away would have destroyed the lesson.

**R4 — [[core-loop]] claimed "three implementations are gated against that fixture in CI".**
True in outline, too coarse in fact. Measured: the fixture has six sections and each harness
reads a different subset — server 6, Luau 5, PWA 3. The three OUTCOMES are gated in all three;
`worldThrowDerivation` is server-only (the World Throw is decided server-side, so no client
derives it) and `partialBank` skips the PWA. Both gaps are by design ([[duplicated-server-constants]]),
which is exactly why a coarse claim was dangerous: it made a deliberate divergence read as drift.

Replaced with a per-section table and the `grep` that regenerates it — a claim about coverage
should carry the command that checks it (schema rule 9).

## [2026-08-27] migrate | R1 — the SDD ledgers were gitignored, so the wiki's raw layer did not exist

Schema rule 4 says the wiki cites the immutable raw layer rather than duplicating it, and names
SDD ledgers as part of it. **That layer was in `.gitignore` and had never been committed** — 11
citations across 7 pages, four on [[friends-family-baseline]] itself, resolvable on exactly one
laptop. A fresh clone, the cloud lint routine, or the owner on a new machine would find nothing.

⚠ **TWO ignores were hiding it, and the second is why nobody noticed.** The top-level
`.superpowers/` line was visible in `.gitignore`; a NESTED `.superpowers/sdd/.gitignore`
containing a bare `*` was not. Both narrowed.

**What is committed: the 238 markdown ledgers (2.3MB).** What stays ignored is what git already
holds or nobody needs — the 263 `.diff` review packages (5.6MB, and each is `git diff BASE..HEAD`
output), plus `brainstorm/` html and the `.pid`/`.log`/server-state scratch. Committing all 8.3MB
would have added five megabytes of the repository to the repository.

⚠ **Scanned before pushing, because git history is not reversible.** No credentials: no
`mongodb+srv` URI with a password, no AWS key, no token, no private key — plus a targeted sweep
for this repo's own known secrets. Clean.

**And the lint could not have caught any of it.** `CITE_RE` anchored on
`roblox|server|src|tools|docs|shared-fixtures`, so `.superpowers/` paths matched nothing —
a citation the checker cannot see is exactly as good as no citation. `.superpowers` is now a
known root, with a test, and it immediately found a dead one:
`friends-family-baseline` cited `.superpowers/sdd/2026-08-18-shoji-screens/` and **no such ledger
was ever created** — item 5 ran without one. Corrected in place, pointing at the spec and plan
that do exist.

## [2026-08-27] decision | R2 — the economy split is enforced by IDENTITY, and Roblox OAuth is the gate on it

[[data]] claimed the Roblox/PWA split was "enforced in the schema — per-platform wallet fields".
**There are no such fields.** `User` has one `totalPoints` and one `pointsAtStake`. Traced
rather than assumed:

- `resolveUser` **returns on its first branch** for a `robloxUserId`, before any merge logic.
- `robloxId` is written in **exactly one place** in the entire server, that branch.
- `auth.ts` and `store.ts` never mention it; **no linking flow exists**.

So the two platforms always resolve to different documents, and a Roblox-earned point cannot
reach the PWA store because that store works on a document the Roblox player does not have. The
split is real and STRONGER than described — separate documents, not separate columns. It simply
is not the schema doing it.

⚠ **AND IT IS CONTINGENT, NOT STRUCTURAL.** `/auth/sso` is already a linking route for four
providers: it finds a user by email or deviceId and writes the provider id onto THAT document.
A fifth named `roblox` would write `robloxId` onto the PWA's document while the game server's
already holds it. The `unique, sparse` index turns that into an unhandled E11000 at login — an
accidental guard. ⚠ **The obvious repair, "resolve to the existing Roblox document instead", IS
the silent merge**, and would ship as a bugfix. Parked as [[parked-defects]] (i).

### The owner's Roblox-OAuth idea, and the fact that bounds it

Owner, 2026-08-27: Roblox is being pushed into serious anti-bot and age-verification work, and
runs proof-of-human infrastructure far beyond what this project could build — so require a
Roblox account for the PWA and lean on it.

**The reasoning is sound and the problem is real.** Everything on [[stats-room]] is measurement,
and measurement is worthless against a sybil farm; the 360-throw qualification floor does not
help if the throws are bots.

⚠ **But Roblox's own docs say "You must have a 13+ account to authorize OAuth 2.0 apps."** This
is a kid-first product. Requiring Roblox sign-in locks under-13s out of the PWA — not a friction
cost, an exclusion of the audience the product is for. The 13+ gate reads like Roblox having
already drawn this line. (App registration also requires the developer to be ID-verified.)

**Offered rather than required survives it**: a verified badge, or leaderboard ELIGIBILITY
gated on a link while anyone may play — sybil resistance where it matters, no age wall on the
door. Either way **the wallet must be ruled before any OAuth code**: per-platform balances on
one document (`identityTier` is the seam), or one-human-one-wallet and Robux never buys points.
Handed to the design thread.

⚠ Two pages got `checked: 2026-08-27` for an unusual reason: committing the SDD ledgers gave
them today's commit date, so the currency check saw [[fireworks]] and [[foliage]] lagging
citations that had not changed — they were IMPORTED. Both were read end to end before stamping.

## [2026-08-27] defect | The World Throw is a vote, PWA identity is free, and the signing key was a placeholder

Came out of the owner's Roblox-OAuth question, which turned out to be pointing at something
larger than it asked.

**1. PWA throws vote in the World Throw.** Both platforms submit into one `Map` on `RoundEngine`;
`countThrows()` ignores platform; `deriveWorldThrow` takes the argmax. A PWA identity costs
nothing — `claim-device` mints a `randomUUID()` and upserts a User, unauthenticated. ⚠ **It is
not a device id**: no hardware binding, no fingerprint, just localStorage and a token; a
`socket.io-client` loop mints them with no browser at all.

⚠ **The plurality math inverts the usual assumption.** Argmax, not majority — a farm needs ~N/3
of the round. Two bots at the five-participant floor. **Cheapest when the population is smallest,
which is launch.**

⚠ **Owner ruling 2026-08-27: NOT built now.** Roblox launches first with the PWA disabled and
TEST_MODE on, so the exposure is inert. Designing a defence for a population that does not exist,
against a rule that is not running, for a client that is not enabled, is the karasu mistake
([[parallel-threads]]). Parked as [[parked-defects]] (j) with an explicit GATE on enabling the
PWA. Shipped only `CLAIM_LIMIT = 3`, and its comment says plainly it is a floor, not a defence.

**2. ⚠ `/roshambo/dev/JWT_SECRET` was 26 characters — the `.env` placeholder, in SSM.** That key
signs device tokens AND user JWTs, so a guessable key means forged identities: read any account,
throw as it, bank its pot. **This is exactly what the 2026-08-18 hard cut closed, reopened by a
weak key** — the mechanism was right, and a signature is only worth its secret. Owner rotating;
prod still to check. Parked as (k).

⚠ **Two corrections I made to my own reasoning during this**, recorded because the design would
have rested on them: earned enfranchisement does NOT price out a farm (identities enfranchise in
parallel, one wait for the whole cohort — what it buys is a detectable SHAPE); and proof-of-work
is REGRESSIVE here, taxing a kid's A13 harder than an attacker's server, in a game gated on that
exact device.

## [2026-08-27] ship | The live backend's signing key is rotated, and the claim cap went with it

`/roshambo/dev/JWT_SECRET` rotated by the owner and redeployed; service RUNNING and verified
live — socket.io handshake 200, `/api/v1/stats/records` returning real rows. Prod needed
nothing (64 chars, properly generated). [[parked-defects]] (k) closed.

⚠ **The graceful-degradation question was the one worth checking, and it was checked before
celebrating.** Rotating a signing key invalidates every device token in the wild, and the live
demo is full of them. The handshake middleware `catch`es an unverifiable token, logs, and calls
`next()` — the socket connects device-less rather than being refused — then `device-required`
goes out and the client re-claims. So a returning player sees a working app. **The only cost is
the intended one**: their guest points and streaks are orphaned, exactly as on 2026-08-18.

The same deployment carried `CLAIM_LIMIT`, so the live service now also refuses a fourth
`claim-device` on one connection.

## [2026-08-27] decision | The karasu is life-size, the uguisu is deliberately not — measured, not argued

Owner, watching the karasu fly: *"I'm wondering if it's too small — certainly smaller than
reality, but not that much bigger than the uguisu?"* Measured in the live place via the Studio
MCP rather than reasoned about:

| | shipped | real | verdict |
|---|---|---|---|
| uguisu | 9.9 in | ~6 in | **~65% oversized** |
| karasu | 19.7 in | 19.7-23 in | **life-size** |
| ratio | **1.98x** | ~3.2x | |

**The eye was right and the obvious fix was wrong.** Growing the crow would have broken the
life-size decision made the previous day AND left the warbler inflated. ⚠ **Owner ruling: leave
both** — *"I deliberately chose to upscale it because it was hard to see."* Recorded on
[[owner-rulings]] because a future session will measure this pair, find the uguisu oversized, and
be tempted to correct it. That is the fix to NOT make.

⚠ **Two of our own records were wrong, and they disagreed with each other.**
`karasu_retarget.py` claimed the uguisu "was exported at 0.828 and rescaled to 0.552 inside
Studio"; `measureBirds.luau` said it ships at 0.828 with nothing rescaling it. The second was
right — `BirdController` performs no rescale. **0.552 was an invented number that propagated
between two records because neither was ever checked against the artifact**, which is the exact
failure schema rule 9 exists for, appearing again in the same file that documents it.

⚠ **AND `measureBirds.luau` DID NOT WORK.** It ended in `return table.concat(rows, "\\n")`, and
the Studio command bar discards a chunk's return value — so it printed nothing, and had never
been run by anyone. **[[familiars]] had been pointed at it as the authority for bird sizes on
the strength of it existing.** A citation to a silent tool still reads as "measured". Fixed to
print; found only because the owner tried to use it.

Also noted ⚠ unverified: the karasu's wingspan measures ~75% of life while its body is 100%
(~1.5x body length against a real crow's ~2.0x), which may be why it reads small.

## [2026-08-27] ship | The karasu has a voice — per species, weighted, and unreachable until selection

Three clips cut from a source recording, uploaded by the owner, moderation cleared and verified
loading in the place (0.52 / 1.30 / 2.08s, ids in `shared/BirdVoice.luau`).

**Clips and levels are now PER SPECIES.** A crow is not a loud warbler, and volume and rolloff
belong to the bird as much as its calls do. The uguisu's values moved across unchanged, carrying
the reasoning that earned them.

⚠ **The pick is WEIGHTED because the karasu's clips are not substitutable.** The uguisu's three
are three ways of saying one thing. The karasu's are ONE, TWO and THREE caws — uniform selection
would make the two-second declaration a third of every song, and a thing heard every third time
is not a declaration. Weights are reasoned, not heard; tune them in one play session.

**Two things measured rather than guessed.** The owner judged the source's second phrase noisier;
measured, its background sits **9.3 dB** above the first (−37.7 vs −47.0), so all three clips
come from phrase one. And the karasu plays at volume 1.0 against the uguisu's 0.85 because its
source clips peak **2–4.5 dB quieter** — equal Volume would have made the crow quieter than the
warbler, which is backwards.

⚠ **Composition verified and deliberately not wired.** A 3+2 built from the three-caw and two-caw
clips is SAMPLE-IDENTICAL to a baked recording except for 0.48s of room tone at −56 dBFS —
established by diffing the two files, not by listening. The delay is 0.48s, **not** the 0.76s gap
you would measure off the source, because the clips carry their own padding. Both constants live
in the module so nobody re-derives them.

⚠ **A scope correction I had to make mid-task.** I classified this as bounded and designed for the
familiar's win-song. The owner: birds will be found all around the experience, flying and perching
and calling. **That system does not exist** — no world population, no perching, and the dock
uguisu is a Sound emitter with no visible bird. It also reverses the ruling that the familiar
sings only on a win, which exists to keep the dock bird special. Stepped the path back up and
built only the piece that is genuinely bounded and serves both futures.

**Still unreachable.** `SPECIES` is hardcoded to Uguisu; nothing selects a bird per player. Same
shape as the mesh — built, correct, waiting on item 6.

## [2026-08-28] defect | "There is no perching" — a stale code comment was believed and repeated

⚠ **Correcting yesterday's entry above.** The 2026-08-27 ambient-birds note claimed "no world
population, no perching, and the dock uguisu is a Sound emitter with no visible bird". **The last
clause is true; "no perching" is false and was told to the owner as fact.**

The familiar perches on tagged `FamiliarPerch` attachments swept across path railings, hero
trees, chōchin poles, the descent stair and the Rojo builders' output. The resting ORBIT is only
the fallback for when none is in range — which is also what keeps birds out of buildings, since
indoors has no perches. Owner numbers from 2026-08-18: a 20-stud search radius, a 10–60s hold,
a 70-stud leash, and a deliberately random re-pick so it sometimes returns to the perch it just
left, "which is what a real bird does and what stops the movement reading as a patrol."

**Why it was believed:** `BirdFlight.luau` carried a comment reading *"RESTING IS A PLACEHOLDER
ORBIT, AND IT IS THE NEXT THING TO BUILD"*. It was true for part of one morning. Perching shipped
the same day and the comment never caught up — so for ten days a pure module described finished
work as pending, and a session read it, grepped for the wrong word, and told the owner the feature
did not exist. ⚠ **This is [[wiki-currency]]'s mechanism operating in CODE COMMENTS rather than
wiki prose, and nothing lints those.** The wiki's currency checks cannot see a stale `--`.

Corrected in both places, and the owner caught it — from playing the game, which is the only
instrument that had the right answer.

## [2026-08-28] decision | Birds are ONE architecture, not two — the split is authority, not rendering

Written up as [[ambient-birds]] after the owner asked to classify what exists. Three corrections
came out of the classification, two of them to things said earlier in the same session.

**1. "Familiars client-side, ambient server-side" is the wrong axis.** Both are client-RENDERED;
[[fireworks]] states it as binding — *"client-side VFX only; the server sends a tiny launch
event."* A server-rendered bird would be the only thing in the game replicating a CFrame per
frame, against the A13 budget. What differs is what the server is AUTHORITATIVE for: the familiar's
roster and results, an ambient bird's placement and call timing. Same shape as fireworks.

⚠ **This matters because it solves the divergence problem WITHOUT the replication cost.** The
familiar tolerates two clients disagreeing about which railing it sits on — a recorded trade —
because it is anchored to a player and stays "Bob's bird near Bob". An ambient bird has no such
anchor, so two players on one dock would see different birds. Server authority over placement
fixes that; server rendering was never needed for it.

**2. Territory is a property of the BIRD, not a mode.** `pickPerch(anchor)` already takes a
position; only the radius is a constant. The familiar is already a territorial bird whose
territory follows a player. A static anchor is the entire difference. And the uguisu's territory
is already RULED, not open — *"this bird lives here"* ([[falls-dock]]) — which is also authentic.

**3. ⚠ Long flights are nearly free, because nobody can watch them.** StreamingEnabled means a
client holds only nearby geometry, so it cannot see a perch across the canyon — it does not exist
locally. A long flight is therefore unobservable for most of its length by definition, and reads
from a fixed vantage point as a bird leaving and later arriving, which is what a real bird looks
like. Only the TRANSITION needs care.

**And the dock uguisu is a PRECEDENT, not a platform.** One hand-built Part + three Sounds + a
Script, place-only: no registry, no spawner, no module. It is server-rendered today only because
it renders nothing — it is audible and invisible. A visible dock uguisu is the FAMILIAR's
renderer with a static anchor, plus a small server voice. Its schedule design and its owner ruling
are what carry forward; its implementation is not.

Recorded alongside: the two systems already duplicate pitch jitter, timing band and clip set
between a place-only Script and committed code — [[duplicated-server-constants]]'s exact class,
and making the dock bird visible is the moment to collapse it.

## [2026-08-28] ship | Bird motion scales with the species; BirdVoice becomes BirdSpecies

Every motion constant in `BirdFlight` was tuned against the uguisu, and the karasu is about twice
as long — so studs and seconds were wrong on it while degrees were fine. `BirdVoice` is renamed
`BirdSpecies` and now carries a measured `bodyLength` beside the voice in ONE record per bird
(two parallel tables keyed by species name would have been [[duplicated-server-constants]] with a
different subject). `BirdSpecies.scaleOf` divides by the reference bird; `BirdFlight.profile`
turns that into two multipliers; eight functions take it as a trailing argument. **Angles
unchanged, distances × scale, durations × √scale.**

`FLAP_RATE` and `CRUISE_SPEED` were both missing from the 2026-08-27 constant audit and are
included here: a rate is a reciprocal time, so it is divided. Left alone, a crow flaps at a
warbler's 2.5 beats a second — which presents as "the animation is wrong" rather than "a constant
was absolute".

⚠ **The uguisu at scale 1 is bit-identical**, asserted output-for-output across the whole
surface — the property that made this safe to land before anyone has watched a karasu perch. The
karasu's numbers are reasoned, not gated; they want the owner's eye.

Eight mutations on the arithmetic and four on the controller, all caught. The controller guard is
a source-scanning spec (`BirdScaleConvention`), because `BirdController` is a Roblox-runtime file
Lune cannot execute and forgetting the argument compiles and looks almost right. ⚠ The list of
functions it polices is derived from `BirdFlight`'s signatures rather than typed, and
`stripComments` moved into `harness` rather than being copied a second time.

`SPECIES` now also selects the mesh (`{SPECIES}Body`/`{SPECIES}Wings`, already declared in
`default.project.json`), so one name drives assets, voice and proportion. Flipping it to Karasu is
a one-line change; nothing selects a bird per player yet. 1545 Luau tests.

## [2026-08-28] gate | First look at a karasu familiar: hop and wings pass, seat corrected, size parked

`SPECIES` flipped to Karasu for a look. Owner: hop **fine**, wings **fine for now**, shoulder seat
*"a little tight to the head"*, and *"the karasu seems small, but I'm not sure we should chase that
now."*

**The seat was a real gap in the scaling pass and the reason is worth keeping.** `SEAT_INBOARD`
places the bird's FEET and is a proportion of the AVATAR's arm — correctly untouched by bird size,
which is what the 2026-08-28 scaling commit argued. But a bird is CENTRED on its feet, so a wider
bird reaches half a width further inboard from an identical footprint. Feet position is avatar
geometry; body clearance is bird geometry, and only the first of those was reasoned about.
`BirdFlight.seatRelief` gives back exactly the half-width this bird has that the reference one did
not — no tuning constant, exactly zero at scale 1 so the gated uguisu seat is untouched, ~1 inch on
the karasu. Three mutations, all caught.

⚠ **Also found by flipping**: two `warn` calls still had `UguisuBody`/`UguisuWings` in their
MESSAGE TEXT, so a missing karasu asset would have named the wrong bird in the one line meant to
diagnose it. The convention guard had banned the quoted literal and sailed past prose. It now bans
a species name anywhere in the controller except the single declaration line.

**Size is parked, not dismissed** ([[backlog]]). The bird is life-size against a real
hashibutogarasu, so "seems small" is about how it READS — the same tension that got the uguisu
deliberately upscaled, in the opposite direction. The lead already on record is the wingspan
(~1.49x body length against a live crow's ~2.0x, and `⚠ unverified`), which would make it asset
work rather than a rescale. Cheaper than either: nothing selects a bird per player, so no player
can meet a karasu at all.

## [2026-08-28] audit | Measured the karasu in the live place: it is not a scaled uguisu, and the avatar's head is why it reads small

Owner asked how large the karasu is. Measured against `ReplicatedStorage.RoshamboBirds` and a live
character rather than answered from the page, and two facts came out that nothing had predicted.

⚠ **THE KARASU IS NOT A SCALED UGUISU.** Length 1.98x, height 1.90x, **width only 1.47x**. That
invalidated a line committed an hour earlier: `seatRelief` inferred the reference bird's width as
`width / scale`, which over-relieved by about a third of an inch. Both templates are loaded at
once, so the fix removes the inference rather than correcting it — `seatRelief(bodyWidth,
referenceWidth)` is now the difference of two MEASURED half-widths, still exactly zero for the
reference bird. Three mutations, all caught. **The rule this earns: never derive one of a mesh's
dimensions from another across species.** `BirdFlight`'s motion scale is unaffected — it keys off
`bodyLength` and applies to time and distance, not to geometry.

⚠ **THE AVATAR'S HEAD IS WHY A LIFE-SIZE BIRD READS SMALL.** A stock R15 head is 1.196 studs wide
on a 5.88-stud body — 20% of height, where a real human head is about 8%. The avatar's head is
roughly 2.5x too wide for its body, so anything sized to reality and placed beside it reads at
about 40% of what a real observer would see. This is the same finding that got the uguisu
deliberately upscaled, arriving from the other direction. It reframes the owner's "seems small"
from a possible measurement error (it is not one) to a design question with a precedent.

⚠ **The wingspan is now VERIFIED**, previously `⚠ unverified` from a rest-pose bounding box:
1.49x body length off the spread-wing MeshPart, against a live large-billed crow's ~2.0x. The
uguisu is 1.13x. Both ship short-winged and the crow loses more by it. Still the cheapest lead.

## [2026-08-28] defect | The karasu's eye: 31 texels, all of them spent on black

Owner in play: "nothing reads as an eye on the existing model", rejecting an earlier session's
"black on black so it cannot read" as an oversimplification, with a reference photograph.

Two measurements, both of which contradicted the standing explanation. The eye has **31 texels
across** at the shipped 1024 atlas (from the UV area of the faces around it), so resolution was
never the limit. And sampled off the reference as ratios to the adjacent head feather: highlight
3.08x, ear-covert stipple 1.37x, lid 0.72-0.50x, **iris 0.66x**, pupil 0.14x.

⚠ **The iris is DARKER than the feathers.** Two sessions had reasoned that a bird's eye reads
because a pale warm iris sits against black; the photograph says every part of the eye except the
glint is darker than the head around it. A crow's eye reads by contrast with its OWN surround.

⚠ **And the catchlight's brightness was right all along** — 3.4x the crown against a measured
3.08. Its SIZE was the bug: 38% of the eye's radius, ~15% of its area, against a real reflection
covering about a third of the eyeball. "Add a catchlight" looked done because the failing
dimension was not the one anyone had checked.

Five layers now: pale ear-covert frame, dark socket rim, iris, pupil, broad elliptical glint. The
frame was missing entirely rather than mis-tuned. Baked and exported; awaiting the owner's look.
Modelling the eye stays the fallback if paint proves insufficient in play ([[familiars]]).

## [2026-08-28] defect | The karasu's eye is modelled — and gloss turns out to be unavailable

Owner rejected the five-layer paint as "cataracts and/or possessed", and their own repaint of the
same map too: "we're going to need to model the eye - simply, if possible."

**Built.** `build_eyes` makes one UV sphere per eye with the uguisu's own builder, sunk so a
shallow cap stands proud. 192 tris (+6%), its own UV block, x RAYCAST off the skull rather than
typed, bound explicitly to `joint4` — named rather than nearest, because the orphan catch-all
would plausibly hand a low-set eye to the neck and leave the eyes swimming behind every head turn.
Zero orphans, rig verification unchanged.

⚠ **AND THE PLAN IT WAS BUILT FOR DOES NOT WORK.** "Model it and let the engine light it" assumed
a dome earns a specular highlight. It cannot here: the bird is ONE MeshPart with ONE plain
ColorMap and no SurfaceAppearance, so there is no per-texel roughness — **the eye cannot be made
wet without making the whole bird wet.** Tested at roughness 0.10: glossy black plastic crow, and
the eye still did not read. The highlight has to be painted whatever the geometry does.

What the dome buys is that a painted dot sits on curvature that shades away from it — a specular
point rather than a marking. Five attempts have now bracketed the range without landing it, and
the useful next input is the owner's eye, not another guess ([[familiars]]).

## [2026-08-28] ship | The karasu's eye becomes a separate part — gloss cannot be localised on one MeshPart

Owner, after rejecting three painted eyes: "wouldn't you put a separate sphere in that space and
give it a material like an eyeball?" Yes — and a session had asserted the opposite an hour
earlier, that the highlight must be painted because the bird is one MeshPart. ⚠ **The wings have
always been a separate part**, CFramed onto the body every frame. The constraint was self-imposed
and the architecture already had the pattern.

The real one, measured: one plain ColorMap and no SurfaceAppearance means no per-texel roughness,
so an eye inside the body cannot be wet unless the whole bird is. At roughness 0.10 the crow came
out as glossy black plastic and the eye still did not read.

⚠ **Which explains all three failures at once.** A painted highlight is a bright shape at a FIXED
PLACE — it reads as a marking rather than as wetness, and making it more visible only makes it
more obviously a marking. No amount of colour accuracy fixes that; the colours had been sampled
off a photograph.

Built: two Ball parts per bird with their own Material/Color/Reflectance, parked on new
`eye_R`/`eye_L` bones parented to the HEAD in the exported rig — so position lives in the asset,
nothing is transcribed, and the eyes follow every head turn for free. ⚠ Bone LENGTH does not
survive import (a Roblox Bone is an Attachment, a point), so the radius is the one number that had
to move to `BirdSpecies`. The uguisu deliberately has no eye entry: it models its own.

⚠ Caught by the tests immediately: the first `BirdSpecies` draft named `Color3` and `Enum.Material`
and broke the src/shared purity rule — a pure module names no Roblox type or it fails to load
under Lune, taking all 1546 tests with it. Plain RGB triple and a material NAME now; the
controller converts at the boundary, same as BirdFlight's {x, y, z}.

## [2026-08-28] gate | Standing ruling: model in Blender, approve in Studio

Owner: "I don't understand your pipeline at all; it presumes that tuning is more important than
accuracy, and the Studio is the preferred tuning environment. Is a Ball part in Roblox
better-performing than a ball mesh exported from Blender?"

**No, not meaningfully** — both are one Instance per eye and instance count is what costs. And the
trade the Part was chosen for does not exist: measured in Studio, a MeshPart keeps Color, Material
AND Reflectance at runtime, plus TextureID which a Part lacks. The ball gave up the iris and gave
up being visible while authoring, and bought nothing back.

⚠ **Standing ruling ([[owner-rulings]]): model in Blender, approve in Studio.** Build and
conditionally approve in Blender, then play and give final approval in Studio; manual imports are
not a cost worth designing around. The corollary is the thing actually being got wrong — do not
trade authoring control for iteration speed.

**Then the first build was visibly wrong on one side**, and it found a trap worth its own section
on [[blender-pipeline]]: the eye surface was measured on ONE side and mirrored, and the head is not
symmetric — 0.0514 proud on the right against 0.0610 on the left, 120 vertices one side against
163 the other. Compounded by a single raycast standing in for the surface: it struck 0.0379 where
vertices in the same footprint reached 0.0514, so the ball sat inside the skull at every zoom.
Each eye is now seated per side and against its whole footprint, with both protrusions ASSERTED
equal (0.0108) rather than eyeballed.

⚠ **THE EYEBALL ITSELF IS NOT APPROVED.** Owner, 2026-08-28: *"these eyes are still not correct,
so hopefully you're not proceeding as if they are."* Three FBXs are exported (body, wings, eyes)
and the geometry seats correctly on both sides, but seating correctly is not the same as looking
right, and this session had begun wiring Rojo and the controller as though it were settled. The
GATE recorded above is the workflow ruling, not the eye.

## [2026-08-28] ship | The karasu's eye is modelled and lidded; the beak work is reverted

Kept, on the owner's call: girth 1.15 and belly 0.060 through the torso, and the whole eye — a
`KarasuEyes` MeshPart, a lofted lid ring, and `eye_R`/`eye_L` bones parented to the head so the
position travels inside the asset. ⚠ The Roblox side is NOT wired: no Rojo entry, no controller
code, no species record. Geometry and bones ship; nothing consumes them.

**Reverted, all of it**: culmen arch, forehead lift, tip hook, tip blunt, tomium retraction, the
bill-depth profile, the moved hinge and the steepened gape plane. Owner: "revert all the beak
work." ⚠ The cause was structural rather than any bad number — every attempt displaced a vendor
bill only a few vertex rings long, so each fix bought the next defect, and the steepened plane
(tilted purely to satisfy the upper/lower classifier) took the cut off the anatomy and produced a
wedge-shaped jaw that swung through the upper mandible.

⚠ **AND THE OPEN BEAK WEBS, which nothing was measuring.** The cut deliberately stops short of the
hinge so the mandibles stay joined, so their two boundary loops SHARE vertices — topologically one
loop, which `holes_fill` closes as one membrane down the whole mouth, welded to both halves. 13
such faces. Filling the two sides separately does NOT fix it (neither is a closed loop; the bill
comes out 24-edge open) and that failed attempt is recorded in the code.
**This shipped for two days behind `boundary_after: 0, non_manifold: 0` — both of which a webbed
jaw satisfies perfectly.** Watertight is not correct. `split_bill` now reports
`faces_bridging_joint`, which is the number that says whether a jaw can actually move.

⚠ **The open direction is NEGATIVE X**, and a session asserted the opposite for two messages
because it measured `norm()` — a magnitude, which cannot tell opening from closing into the skull.

A modelled mouth cavity is the remaining work, and it is the same conclusion the bill profile
reached independently: this bill wants LOFTING from station data, not displacement ([[familiars]]).

## [2026-08-28] defect | The karasu's eyes imported unrigged, and the eye bones can never reach Roblox

Owner imported all three FBXs and asked for the bones. `KarasuEyes` came in with **zero** bones and
`KarasuBody` with 15 — no `eye_R`/`eye_L`, on the third import in a row.

Two independent filters, neither of which reports anything. **On export**,
`use_armature_deform_only=True` drops bones with no weights *on the mesh being exported*, not
merely non-deform bones — it had been culling the eye bones silently. **On import, Roblox strips
any bone that influences nothing**, and no flag changes that. The proof was the asset id: the
re-imported body and wings returned the *same* `rbxassetid` as the previous import, so the upload
was byte-identical and the extra bone added nothing the importer records. Fixing the exporter was
necessary and could never have been sufficient. See [[blender-pipeline]].

Underneath both, the actual defect: **`KarasuEyes` had a `joint4` vertex group but no armature
modifier and no parent.** `run()`'s reparent loop named only `("KarasuBody", "KarasuWings")`. A
vertex group without a modifier is inert — Blender writes no `Skin` deformer — so the eyes exported
static and would have hung in world space ignoring every head turn. Fixed by adding the eyes to
that loop; the file now carries a `Skin` with `joint4` weighting all 84 vertices.

⚠ **The eye BONES are not needed and were never the fix.** They exist as position anchors for the
runtime `Part` eyeball the owner retired on 2026-08-28 ([[owner-rulings]]). Modelled eyeballs need
exactly one bone — the head — and `joint4` already is one. `BirdController`'s `makeEye`/`eyeBoneR`
path and the `eye` record in `BirdSpecies` are now dead code awaiting removal; because Roblox
strips the eye bones on import, `bone("eye_R")` already returns nil and the parts are never placed.
A session proposed rescuing the bones instead — sunk cost dressed as a design.

## [2026-08-28] ship | The karasu's eyes are wired — one write per frame, off the head bone

Owner, on being shown the wings pattern: *"cFrames for the eyes? isn't that a performance hit?"* —
and the push was right. The proposal was the **more** expensive design. Two MeshParts do not share
a skeleton: the body's `joint4` and the eyes part's `joint4` are different instances, so making the
eyes' own bones track the head means mirroring `joint1`, `joint3` and `joint4` every frame on top
of the part CFrame. Four writes per bird per frame, against two for the runtime `Part` it replaced.

Eyeballs are **rigid relative to the skull**, so the correct amount of work is one rigid transform:
`eyes.CFrame = head.TransformedWorldCFrame * eyeOffset`, the offset measured once at spawn from the
two rest poses. **One write, one instance** — half what the retired two-Part design cost.

⚠ **A CORRECTION THAT CHANGED THE DESIGN.** A session had reported the 0.00000-stud bone agreement
between body and eyes as proof that "a head turn carries the eyes." It is not: it proves the two
parts share a COORDINATE FRAME, which is what makes the offset exact. Head turns do not propagate
across MeshParts. Conflating "same skeleton geometry" with "same skeleton" is what produced the
four-write proposal.

Retired with it: `makeEye`, the two `Part` fields, the `eyeBoneR`/`eyeBoneL` lookups, and the
`radius` in `BirdSpecies.eye` — which had sized the ball and outlived it by long enough to drift to
0.024 against a mesh measuring 0.0188. Appearance stays in the module, size stays in the asset.

`tests/BirdEyeConvention.spec.luau` guards all of it by reading the controller's source, because
nothing at runtime distinguishes a one-write placement from a four-write one — both put the eyes in
the right place. Five mutations, each caught by exactly one test: rest pose for driven pose, the
offset rebuilt per frame, the eyes dropped from the cull path, `radius` creeping back, and a `Part`
ball returning. See [[familiars]].

## [2026-08-28] defect | The karasu's eyes shipped floating behind the tail — a rest pose seated by the part centre

Owner, in play: *"there are two blue-ish balls floating in space behind the back of the bird — not
sure if those are meant to be the eyes, but they're nearer the tail than the head, and seem to be
moving more than eyes would."*

`eyes.CFrame = part.CFrame` seats the eyes' BOUNDING-BOX CENTRE where the body's centre is, and the
two centres are far apart: body `PivotOffset` (0.0010, -0.4485, 0.0000) against eyes
(0.0065, -0.8329, 0.5900). The error is (-0.0055, +0.3844, -0.5900), and Z is nose-to-tail — 0.59
studs toward the tail, which is exactly what was reported.

⚠ **THE MOTION SYMPTOM WAS THE SAME BUG, NOT A SECOND ONE.** The bad rest pose is MEASURED into
`eyeOffset`, so the constant carries a ~0.7-stud lever arm in place of 0.038 and every head turn
swings the eyes through an arc eighteen times too large. A seating error that presents as wrong
motion is worth naming, because motion is not where anyone looks for it.

Fixed by routing through the shared authored origin, which is how the render loop already seats the
body and the wings — and the file's own ⚠ against seating by the part centre sits three lines below
where this was written. Reading a warning is not obeying it.

`tests/BirdEyeConvention.spec.luau` now scans the seating BLOCK rather than the line: the first
version of the guard was line-bounded and failed on the correct two-statement fix, which is the
trap [[blender-pipeline]] and BirdScaleConvention both already record — bound a source scan by the
structure it lives in. Three mutations caught, including the shipped bug verbatim. See [[familiars]].

## [2026-08-28] defect | The karasu's eyes read last frame's skull — placed 135 lines before the head was posed

Owner, in play: *"they don't seem to turn accurately with the head, and they seem to be popping in
and out of the geometry."* One defect, not two.

`Bone.TransformedWorldCFrame` reports where a bone IS, which is whatever `Transform` last said. The
eyes were placed at the top of the per-frame block; `b.head.Transform` and `b.neck.Transform` are
written 135 lines further down, at the end of the detail block. So every frame the eyes were seated
on the PREVIOUS frame's skull.

⚠ **A ONE-FRAME LAG IS INVISIBLE AT REST**, because the pose is unchanged and a frame late is
indistinguishable from on time. It shows only while the head is MOVING, and it shows in exactly the
two ways reported: the eyes trail the turn, and the skull moves out from under them and back, so
they sink into the head and re-emerge. Neither symptom names its cause.

⚠ **ORDERING HAS NO RUNTIME SIGNAL.** Both orders compile, run, and place the eyes on the head. The
guard is source POSITION — the eyes' CFrame write must appear after the last `head.Transform` write
— which is the same class of test as BirdScaleConvention and for the same reason.

Found beside it and fixed: **`Players.PlayerRemoving` destroyed the body and the wings but not the
eyes.** Two teardown paths exist and only the roster sweep had been updated. An orphaned eyes part
is ANCHORED, so it does not fall, fade or expire — it hangs over the canyon until the session ends.
Now guarded by counting `part:Destroy()` against `eyes:Destroy()`. See [[familiars]].

## [2026-08-28] defect | The karasu's eyes rendered through its head — a skinned mesh shipped with its bones deleted

Owner, in play: *"I seem to be able to see the eyes through the bird's head?"*

⚠ **THE MESH WAS MEASURED AND CLEARED FIRST**, which is the part worth keeping. At the eye station
the skull spans x −0.0537 .. +0.0396 and the eyeballs reach +0.0404 and −0.0535 — tangent to the
silhouette, 0.0008 proud on one side and 0.0002 inside on the other. A ray from a viewer abeam the
head crosses a closed shell to reach the far eye, so the far eyeball is geometrically occluded.
Guessing would have sent a session into Blender to fix a mesh that was correct.

The cause was the clone. `makeEyes` stripped **every** child including the `Bone` instances, making
these the only part in the game shipped as a **skinned MeshPart with no bones** — `KarasuEyes`
carries a real Skin deformer with `joint4` weighting all 84 vertices, so the mesh still declares
skinning with nothing to skin to. The wings clone, which renders correctly, guards its strip with
`IsA("Bone")`; the eyes did not. Now they match. The bones stay inert either way — the part is
placed rigidly off the BODY's head bone and never deformed — so the cost is a few Attachments.

⚠ **FOUND BESIDE IT, NOT THE CAUSE, AND STILL A DEFECT: the two lid collars are welded to nothing.**
The body mesh is 8 connected components, and two of them are 120-vertex rings sitting on the eyes
with 48 open edges each — 96 of the body's 112 open edges, previously logged as "84 explained, 28
unverified". That accounting was wrong: the collars are not open by design, they are FLOATING. The
main body is closed (0 open edges), so nothing is see-through, but a ring welded to neither the
skull nor the eyeball is not what `build_lid_collar` was supposed to produce. Backlogged, not fixed
here. See [[familiars]].

⚠ **AND A PROCESS NOTE.** Three source-scan guards in `BirdEyeConvention.spec.luau` were written
line-bounded or expression-bounded and failed on CORRECT code — once on a two-statement fix, once
on a `:: BasePart` cast. Bind a source scan to a declaration or a block, never to the shape of an
expression. [[blender-pipeline]] and BirdScaleConvention both already record this.

## [2026-08-29] ship | The karasu's eye is painted after all — the modelled eye and its part are withdrawn

⚠ **THE PREMISE THE WHOLE MODELLED EYE RESTED ON WAS FALSE.** "A painted eye cannot read" came
from three bakes, **all of them our own procedural output**. The vendor's hand-painted eye — iris,
pupil, catchlight, lid line — was never in that sample and was packed inside `crow.blend` the whole
time. The owner said so on Thursday (*"is that the original colormap? That eye is vastly better"*)
and the session treated it as an observation instead of a question. Six hours followed.

**What ships:** the vendor's `crow_mesh_diffuse` **graded** to the corvid palette rather than
repainted over — luminance keeps the detail, the tint carries the identity — then hand-graded by
the owner in Photoshop for black level and contrast. That file, `karasu_colormap_graded_2.png`, is
now `COLORMAP_AUTHORITY`: the bake writes `karasu_colormap_baked.png` instead and **raises rather
than overwrites** if the authority is missing, because it cannot regenerate a Photoshop curve.
Procedural paint survives only on the 855 faces the vendor never had (tail, folded wings, feet,
gape), tagged `newgeo` by `join_all`.

⚠ **A ROUGHNESS MAP, BECAUSE ONE SCALAR CANNOT SERVE BOTH ENDS.** Measured on this bird: at 0.10 it
was glossy black plastic, at 0.78 the feathers were right and the eye died — a tight specular is
what makes an eye look wet, and roughness is exactly what broadens it away. That trade, not the eye
alone, is what buys per-texel roughness. Derived from local luminance variance (feathers are fine
structure → rough; eyeball and bill are broad and smooth → glossy), with luminance clipped at 0.45
first so the catchlight cannot invert the result in the one place that must be glossiest.
⚠ **It is inference, not recovery**: the vendor shipped no surface maps at all — `uv_crow_alpha` is
a binary cutout mask, 99.3% pure 0 or 1 — and diffuse luminance mixes albedo with baked lighting.
Normal and metalness are derived too, because [[material-and-mesh-traps]] §8: a partial PBR set
renders WORSE than none.

**Withdrawn:** `KarasuEyes` (mesh, `.rbxm`, Rojo entry), `makeEyes`, the eye fields and the
per-frame placement in `BirdController`, and the `Eye` type, `eye` records and `eyeOf` in
`BirdSpecies`. The mesh is rebuilt with `run(eyes=False)` — a plain skull that keeps the girth and
belly, 1591 → 1351 verts, and **open edges 112 → 16**, which retires the floating-lid-collar defect
outright.

⚠ **THE MESH AND THE TEXTURE ARE A MATCHED PAIR.** `join_all` packs new geometry into free UV blocks
in sequence, so dropping the lids shifted every block allocated after them. The new ColorMap is
meaningless on the shipped meshes. All of it re-imports together or the atlas is scrambled.

⚠ **AND THE FIFTH DEFECT WAS UNFIXABLE, WHICH IS THE REAL LESSON.** Four bugs in the modelled eye
were mine (a rest pose seated against the wrong reference, a one-frame ordering lag, a skinned mesh
with its bones deleted, a leak on the second teardown path). The fifth was not: **a rigid eyeball
cannot track a smooth-skinned socket.** At a 30° head yaw parts of the rim land 0.57 of an eyeball
radius from where a rigid follow puts them, so the ball escapes on whichever side lags. No amount
of care fixes that; the architecture was wrong. See [[familiars]].

## [2026-08-29] defect | Every familiar rendered grey in Play — the clone strip deleted the SurfaceAppearance

Owner: *"the bird is black in edit and grey in play."* That one sentence located it after two wrong
guesses at the asset itself, because the split is the whole diagnosis: the TEMPLATE was fine and
the CLONE was not.

`BirdController` strips children off a cloned template — the importer leaves an `AnimationController`
and an `InitialPoses` folder on every mesh and we drive `Bone.Transform` directly. It was written as
an **allowlist**, `if not c:IsA("Bone") then c:Destroy()`, which was correct only while a bird's
appearance lived on `TextureID`. That is a **property**, and properties survive a clone. The karasu
now carries a `SurfaceAppearance` — ColorMap, Normal, Roughness, Metalness — and that is a **child
instance**, so the strip deleted the bird's entire appearance and every familiar rendered in the
MeshPart's default grey.

⚠ **THE SHAPE WAS THE DEFECT, not the list.** Over-keeping costs a few dead instances; over-deleting
costs an invisible appearance bug that only appears at runtime. `stripImporterJunk` is now a
denylist — name what is dead, keep everything else — and `tests/BirdTemplateClone.spec.luau` asserts
the destroy condition never mentions a class that carries appearance (`SurfaceAppearance`,
`MaterialVariant`, `Decal`, `Texture`, `Highlight`).

⚠ **TWO WRONG GUESSES ARE WORTH RECORDING**, because both were plausible and both cost a look.
`AlphaMode = Overlay` with an alpha-less ColorMap was blamed first — changed to `Transparency`, no
effect. Then the three derived maps being 16-bit PNGs, reasoned to break the packaged `TexturePack`
— also not it. ⚠ **The 16-bit files are still a real defect and still want fixing**; they simply were
not this. And a diagnostic A/B built on setting a packaged map as a plain `TextureID` proved nothing,
because a TexturePack member need not be usable standalone. See [[familiars]].

## [2026-08-30] defect | 148 faces had zero-area UVs, and the roughness map made the flattest paint the shiniest

Two defects the owner found in Studio, both from the same habit — inferring a per-face answer from
a per-piece rule.

⚠ **ZERO-AREA UVs: `_project_faces` unwraps a whole piece down ONE axis**, so any face lying edge-on
to that axis collapses to a LINE. 60 faces on the body, 88 on the wings — a membrane is worse
because its rim faces are edge-on to any projection. A zero-area face samples a single texel row and
renders as a streak or untextured, showing the MeshPart's flat `Color`.
`thicken_degenerate_uvs` gives each one a ~3-texel footprint built in the face's own plane.
⚠ **THICKENED IN PLACE, NOT RE-PROJECTED**, and that constraint comes from the ColorMap being a
hand-graded file we cannot regenerate: moving these faces to a fresh atlas block would put them
where that file has no paint for them. Thickening keeps each face where it is, so it samples its own
piece's existing paint. ⚠ The first attempt preserved each face's aspect ratio, which sounds
respectful and defeats the purpose — a 3D sliver stays a UV sliver, and 7 came back still under a
texel. The axes are normalised INDEPENDENTLY now: shape fidelity is worthless on a face with no area.

⚠ **THE ROUGHNESS MAP WAS INFERENCE AND INFERRED BACKWARDS.** `derive_roughness` read local
luminance variance as surface roughness — fine detail rough, broad smooth areas glossy, on the
theory that an eyeball and a bill are smooth and feathers are not. But paint is flat for reasons
that have nothing to do with surface, and a crow's belly, thighs and tail are the largest
flat-painted areas on the bird. Measured: **21.3% of the atlas at the glossy floor**, including 21%
of the thigh faces. Owner: *"still bright on belly/legs"*.
Replaced by `roughness_map`: matte everywhere, glossy only within ~2.2 eye radii of the seats
`eye_site` MEASURED. Glossy texels 21.3% → **0.27%**. The asymmetry is the argument — feathers
slightly too matte is invisible, a chrome-sheened belly is the first thing anyone sees — and the eye
was always the entire reason a roughness map exists here. A two-value mask was the answer from the
start; a general signal was reached for because it felt more principled.

Also fixed: the three derived maps were **16-bit** PNGs (`float_buffer=True` on the Blender image);
all four are 8-bit now. See [[familiars]].

## [2026-08-30] defect | 539 body vertices under-deformed — skin weights that did not sum to 1

Backlogged since 2026-08-28, fixed now. Measured before: **539 of 1351 body vertices** summed to
anything from **0.046 to 1.5079**, while the wings were clean at exactly 1.000 — which is what makes
it a defect rather than a style. The vendor's weights arrive un-normalised and every operation that
merges or appends geometry carried them along unchanged.

⚠ **A VERTEX SUMMING TO LESS THAN 1 UNDER-DEFORMS**: it travels only that fraction of the way with
its bones, so it lags the geometry around it and the surface creases or tears as the rig moves.
⚠ **AND IT IS INVISIBLE AT REST.** Weights only express themselves under motion, so no still
image — Blender, Studio Edit, any screenshot — can show it. Blender does not normalise on the fly
either: measured, a vertex totalling 0.502 moved 69% as far as a fully weighted one.

`normalise_weights` trims to Roblox's **four influences per vertex** and then normalises. ⚠ The
order matters: a skinned mesh stores four, a fifth is dropped at import, and dropping one from a set
that summed to 1 leaves the remainder summing to less — re-introducing the defect at the point
nobody is looking. Trim first, normalise second, and the exported file already satisfies the
constraint the importer would otherwise enforce silently.

⚠ **ONE VERTEX LANDS AT 0.997509 AND THAT IS LEFT ALONE.** Roblox quantises skin weights to 8 bits,
so its resolution is 1/255 ≈ 0.0039; a 0.0025 residue is below what the format can represent and
cannot survive import as a difference. Chasing it would cost a rebuild to change nothing.
See [[familiars]].

## [2026-08-30] ship | The beak opens on the caw, not near it

The gape shipped as `math.sin(now * 9 + b.seed) ^ 2` gated on the WIN state — a fixed chatter with
no relationship to any sound. Two failures in one: a bird that never sang still sat there mouthing
(and most do not sing — `sing` is gated by MAX_CONCURRENT_SONGS and a chance roll so a crowd is not
a wall of noise), and a bird that DID caw opened on a rhythm unrelated to its own clip.

⚠ **THE CLIPS ARE FIXED RECORDINGS, and that constraint decides the whole design.** karasu-1 is one
caw, karasu-2 two, karasu-3 three, at 0.52 / 1.30 / 2.08 seconds. Their internal timing cannot be
jittered — the mouth would drift off the sound. **Randomness belongs to which clip plays and when,
never to the envelope.**

`Clip` now carries `seconds` and `caws` (onset times); `BirdFlight.gapeAt` turns elapsed clip time
into a 0-1 gape, peaking at 30% of the window so the bill snaps open and lingers rather than
yawning. `BirdSpecies.clipById` reunites the id `pick` returns with the record the beak needs —
additive, because widening `pick` would have changed every caller and its tests for one new need.

⚠ **CLIP TIME, NOT WALL TIME.** Each bird plays at a PlaybackSpeed of 0.97–1.03 (the dock
scheduler's jitter), so a caw recorded at 0.62s arrives up to 3% early or late. Elapsed is
multiplied by that speed. ⚠ **And `gapeAt` takes no scale profile**, alone among durations in
`BirdFlight`: a caw's timing belongs to the recording, not the bird, so a scaled bird must not caw
more slowly.

⚠ **THE ONSETS ARE MODELLED, NOT MEASURED** — derived from the recorded structure (karasu-2 opens
with 0.08s of room tone, karasu-3 ends with 0.20s, gaps 0.48–0.60). They are the one number here
nobody has checked by ear, and a beak a tenth of a second late is visible. Tune in one play session.

⚠ **AMBIENT CALLING IS NOT THIS.** Owner: the karasu is to be the first ambient bird *with a model*
(the falls-dock uguisu is the first, and is audible and invisible). Randomised call timing for an
ambient bird is **server-owned** per [[ambient-birds]] — *"which bird, where, when it calls"* — and
that system does not exist yet. The phrase composition it would use is designed and unwired:
GROUP_GAP_SECONDS 0.48 is already measured for composing a 3+2 from the baked clips. Also still
open on that page: an ambient karasu must not read as somebody's familiar.

## [2026-08-30] defect | The caw onsets were modelled, the WAVs were on disk, and every number was wrong

Owner: *"what do you mean you have no way to open the audio? You created the clips"*. Correct — the
source WAVs are in `Roshambo Reference/sound/birds/` and a session shipped MODELLED onsets while
claiming they could not be measured. They are now measured, by
`roblox/tools/audio/measure_caws.py`, re-derivable in one command.

| clip | measured | had been modelled |
|---|---|---|
| karasu-1 | `{0.090}` | `{0.00}` |
| karasu-2 | `{0.090, 0.865}` | `{0.08, 0.62}` |
| karasu-3 | `{0.100, 0.920, 1.635}` | `{0.00, 0.54, 1.08}` |

karasu-2's second caw was out by **0.245s** — a quarter of a second, which on a beak is not subtle.

⚠ **A CAW IS AN EVENT WITH A DURATION, not a threshold crossing.** karasu-3 carries a 25ms blip at
1.245s, 16% of peak, which a plain envelope threshold counts as a fourth caw — the beak would snap
at nothing. Real caws run 0.18-0.24s, so the tool rejects events under 0.10s.
⚠ **AND ONSETS ARE READ AT A LOW THRESHOLD**: 12% vs 20% of peak moves karasu-3's third onset from
1.635 to 1.655, because a higher threshold triggers after the sound has already started.

`CAW_GAPE_SECONDS` is now 0.23, measured — four of the six caws land on it exactly.

⚠ **`CAW_GAP_RANGE` WAS WRONG AND IS CORRECTED**, `{0.48, 0.60}` → `{0.70, 0.82}`. Measured across
all three clips and the original `japanese_raven_corbeau.wav`, every onset gap falls in 0.695-0.82
(mean 0.75); the single 1.005 is a phrase break. The old value carried the comment *"MEASURED FROM
THE SOURCE RECORDING, kept so it is never re-derived by ear"* — an unmeasured number wearing a
measured label, which is worse than an admitted guess because it stops anyone checking.
⚠ **`GROUP_GAP_SECONDS = 0.48` SURVIVED** the same re-measurement and is kept: its derivation was
0.76 between groups minus a 0.20 tail minus a 0.08 lead, and measured those are 0.775, 0.205 and
0.090. See [[familiars]].

## [2026-08-30] defect | The beak WAS opening — 1.2% of the bird's length, on a jaw welded to the skull

Owner: *"I heard a different caw on both wins, but I saw no beak opening."* The two clips being
different is the weighted pick working, so the song, the gate and the audio were all fine. Verified
by `script_grep` that the gape wiring was live in the running client. It was opening; it was
invisible.

⚠ **THE JAW WAS WELDED TO THE SKULL BY WEIGHTS.** `split_bill` sets `bill_lower = 1.0` on the
mandible's 30 vertices with `add(..., 'REPLACE')` — which replaces the bill_lower weight and leaves
the vendor's `joint4` weight sitting on the same vertices at 1.0. Normalisation then splits them
50/50, so **the mandible moved half as far as the bone driving it.** Measured, the jaw tip carried a
mean bill_lower weight of **0.167** — 83% of the lower bill was held by the head. It now claims
those vertices exclusively, which took a 16° gape from 0.0199 to 0.0299 studs.
⚠ **A JAW IS RIGID.** Blending it with the skull is not a softer hinge, it is a jaw that only partly
opens; the hinge is handled by the cut stopping short of it, not by weights.

⚠ **AND 16° WAS NEVER ENOUGH ANYWAY.** The jaw bone is 0.155 studs and the mandible tapers to meet
the upper bill — at the tip only 5 of 37 vertices sit below the gape plane — so there is very little
lever. At 16° the tip travels **1.2% of the bird's own length** (1.8% after the weight fix), which
is a pixel or two at play distance. `BirdFlight.GAPE_DEG` is now **30**, giving ~3.4%, with the
measurement table in the comment so it is re-derivable rather than re-guessed.

⚠ **A NOTE ON THE DIAGNOSTIC.** The first one was ONE-SHOT and fired 1s after the win, catching the
bird mid-flight at k=0.39 where `flying=true` is simply correct — it proved nothing and cost a play
round. The second never reached Studio at all, which `script_grep` showed in one call. **Check that
the instrumentation is actually running before asking anyone to play a round for it.**

## [2026-08-30] gate | The plane bisect of the beak is retired — a tomium is a curve

Owner, looking at the open beak in Blender: *"the beak split is lower than the actual split implied
by the model, and there are vertices connecting the upper and lower beak"*, then the ruling — the
bisect *"was too simple to be used, and should be retired... the beak should not be split by a
plane, there's an actual curve to it"*.

Both symptoms measured before the ruling, and both are the plane:

- **The split sits low.** The typed plane's point converts to final z 0.7992; `measure_gape_plane`
  fits the mesh's own mouth line at 0.8099. The cut is **0.0107 studs below** where the model says
  the mandibles meet, so part of the true lower bill stays with the upper.
- **13 faces own vertices from both mandibles.** Twelve are at the hinge, where the cut deliberately
  stops and bridging is correct. One is **44% of the way along the bill** and is not a hinge face —
  it is a web, and it stretches when the jaw opens.

⚠ **A BETTER PLANE IS NOT THE FIX.** `measure_gape_plane` exists, is unwired, and would move the cut
0.0107 studs and change its tilt — it reduces the error without changing its class. A plane cannot
follow a curve.

⚠ **AND THE CURVE IS NOT IN THE MESH TO FOLLOW.** Measured across the bill's 99 vertices in 14
stations: the widest-point z (where the mandibles meet) runs 0.821, 0.813, 0.820, 0.811, 0.798,
0.808, 0.812, 0.818, 0.803, 0.799 — non-monotonic — and at the hinge station the two sides disagree
by 0.025 studs. Station counts are 5, 14, 14, 13, 6, 11, 5, 8, 3, 13. There is no tomium edge loop
to cut along, so the replacement cannot be a cleverer cut on this geometry. **The curve has to be
authored**, which is the lofted bill on `bill-loft-wip` — the same conclusion the bill work reached
independently on 2026-08-28. See [[owner-rulings]].

## [2026-08-30] gate | The beak split and the jaw bone are reverted entirely

Owner: *"revert the beak split entirely, we're going to re-attempt it in a more thoughtful way. If
that means you need to revert the bone as well, do that."*

⚠ **THE SPLIT WAS NEVER THE VENDOR'S.** The purchased crow ships one closed bill with no mandible
separation and no jaw bone; `split_bill`, the `bill_lower` bone and the plane that cut them were all
authored here in `c2ffc27`. So the web between the mandibles and the split sitting below the mouth
line were not inherited defects — they were the residue of that cut.

Gone: `split_bill`, the `bill_lower` bone, its vertex group, `BirdController`'s `billLower` lookup
and gape drive, and `BirdFlight.GAPE_DEG`. Body 1351 → **1325 verts** (the cut's 26 extra vertices),
open edges unchanged at 16, size unchanged at 1.64 studs. The beak does not open.

⚠ **THE BONE HAD TO GO WITH THE SPLIT.** A `bill_lower` driving nothing is worse than no bone: it
reads as a working feature to anyone scanning the rig, and it would come back to life the moment a
bone of that name reappeared — driving a bill that no longer separates, which is a bill that
stretches. Guarded in `tests/BirdGape.spec.luau`.

**KEPT, deliberately:** `BirdFlight.gapeAt` and the per-clip `caws` onsets. The onsets are MEASURED
off the source WAVs by `tools/audio/measure_caws.py` and the envelope is tested; both are inputs the
next attempt needs and neither depends on how the geometry splits. They are the one part of the beak
work that was measured rather than guessed.

⚠ **AND `assert_bill_invariants` WENT TOO**, one commit after it was written. It was built to gate an
assembly that is not happening. Its idea was right and is worth rebuilding with the re-attempt: five
facts about the BIRD rather than about the code, because four green checks — Luau tests, stylua,
selene, wiki lint — once passed on a bird whose face was torn open, and none of them look at geometry.

⚠ **THREE THINGS HAVE NOW BEEN BUILT ON THIS HEAD AND WITHDRAWN**: the modelled eye, the lid collar,
and the jaw. See [[owner-rulings]] for the ruling that retired the plane, and [[familiars]].

## [2026-08-30] gate | Blender gets working rules, because it had none

Owner: *"blender is going to be a significant ongoing part of the Roshambo development pipeline.
It's as important as Studio, frankly, not an ad-hoc sort of thing."*

⚠ **THE GAP WAS REAL AND VISIBLE IN THE DAY'S WORK.** [[blender-pipeline]] is ~500 lines and every
section is a trap or a technique — FBX scale, PBR set completeness, bone survival, importer
artefacts. Nothing anywhere said what one step is, who decides a step is done, or when to stop. So
each operation looked locally safe and twenty were chained.

[[blender-working-rules]] now carries nine, each earned in this session. Two are owner rulings:
**no Studio until something can only be seen there**, and **an approach is abandoned when the owner
says it is**. The rest were proposed and accepted: a step is one operation that changes what the
bird looks like; defects are ours to judge and shape is the owner's, never inferred from each other;
geometry commits need the owner's eyes and tool code does not; explore in the live scene and codify
into `run()` only after approval; a number is measured only if a committed script re-derives it; a
script never overwrites what the owner authored; verify instrumentation is live before spending a
play round on it.

⚠ **THE MOST USEFUL FINDING IS RULE 1's COROLLARY.** `run()` rebuilds the bird from the vendor
blend, so the smallest executable unit is a full pipeline pass — and the response to that cost was
to batch changes. **Step size was large because the tooling made small steps expensive, and the
tooling is ours.** Rule 6 is the fix: sculpt in the live scene, codify the settled operation after.

## [2026-08-30] gate | In Blender: place the camera, do not look

Owner: *"you're pretty good at placing the camera, and pretty bad at deciding what it is you're
'seeing'... place the camera and ask me to look, don't iterate."*

⚠ **THE CASE THAT EARNED IT.** The beak was posed open at 30°, rendered, examined and reported as
working. The owner looked at the same geometry and immediately named two defects that were in
frame: the split sitting below the model's own mouth line, and vertices connecting the mandibles.
Measurement afterwards confirmed both — 0.0107 studs low, 13 bridging faces. **The information was
recoverable by measuring and was not recoverable by looking**, which is the whole rule.

Capability confirmed while settling this: `bpy.ops.render.opengl(view_context=True)` captures the
viewport (900×700 JPEG, 14KB) and `bpy.ops.screen.screenshot()` the whole window;
`screen.screenshot_area` does not work in this build. So the constraint is judgment, not capture.

⚠ **A HALF-MEASURE WAS PROPOSED AND REJECTED**, recorded so it is not re-proposed: one capture purely
to confirm framing, after two that day wasted the owner's attention on a macro shot and a black PNG.
Ruled against — "checking the framing" degrades into "having a look and adjusting", which is
self-approval by another name, and an occasional badly framed shot is cheaper. See
[[blender-working-rules]] rule 10.

## [2026-08-30] ship | The karasu's beak opens — there was never a cut to make

Owner, on the working jaw: *"that is pretty awesome"*.

⚠ **ONE VERTEX WAS WELDING THE MANDIBLES SHUT.** A 46-edge fan on the mouth's midline — average
valence on this mesh is 4.13, next-highest anything else is 12 — left behind by a `holes_fill(sides=0)`,
which triangulates a boundary loop as a star from a single point. **Delete it and the mandibles are
already two separate surfaces** from the rictus forward to the tip, joined only where the bill runs
into the face, which is exactly where a real mandible articulates.

Everything built against it was work on a problem that stopped existing the moment it went: the
plane bisect (retired by owner ruling — a tomium is a curve), a lofted bill grafted onto the head,
four hand-constructed cut paths, and three failed split attempts. The fan was found because the
owner asked *"what happens if we just get rid of it?"*

**`open_the_mouth`** is now in `run()`, and **everything in it is derived, never indexed** — `run()`
renumbers every vertex, so a hardcoded index is wrong on the next build and wrong SILENTLY:
- **the fan, by valence** — the single vertex above 4× the mesh average; raises rather than guessing
  if two ever trip it
- **the lower mandible, by component** — forward of the rictus the surface falls into exactly two
  pieces, and the lower is the one with the lower mean z. ⚠ NOT "below the mouth line": the upper
  mandible OVERHANGS, so its tip dips below the lower's and that test picks the wrong piece at
  exactly the wrong place. It was tried and it failed that way.

Verified on a full rebuild from the vendor blend, with different numbering throughout: 1324 verts,
1402 faces, 62 open edges. At a 25° gape the jaw moves **5.48% of body length** and **everything else
moves 0.00000**. The retired plane-cut jaw managed 3.4% at 30° while dragging the skull with it,
because its mandible tip carried a mean `bill_lower` weight of 0.167.

⚠ **THE `ROI_*` GROUPS DID NOT SURVIVE**, as predicted — they encode owner judgement as vertex
indices and a rebuild renumbers underneath them. `ROI_lower_beak_tip` read 0/0 on the very check
that confirmed the new derivation. Nothing now depends on them.

## [2026-08-30] defect | The jaw bone was slung 0.088 studs under the mandible it drives

Owner, looking at the rig: *"why does your new lower mandible bone on the rig appear so much lower
than the part it drives?"*

`JAW_HEAD` was typed as (0, 0.615, 0.806) — measured in a prototype scene that had ALREADY been
through `normalise_size`. `open_the_mouth` runs BEFORE that scaling, so the constant landed in BUILD
coords and was then scaled again, ending at final z 0.674 against a mandible spanning 0.7618..0.8134.

⚠ **THE GAPE STILL MEASURED CORRECTLY**, which is why every check passed. Rotating a bone pivots its
weighted vertices wherever the bone sits — only the ARC was wrong. A displacement test cannot see a
wrong pivot; an eye can, and did. The reported 5.48% was inflated BY the error: a bone 0.088 studs
low swings the mandible on a longer lever. The honest figure on a correct pivot is **4.38%**, still
well above the 3.4% the retired plane-cut jaw managed while dragging the skull with it.

The hinge is now DERIVED — the centroid of the mandible's own rear-most vertices — so it lands
correctly in whatever coordinate space the function runs in. ⚠ A corrected constant would have been
the same trap one coordinate space over.

## [2026-08-30] ship | The karasu's bill: traced from the photograph, and the pipeline hands it over

The culmen was **fitted to a profile traced from the reference photograph** rather than to typed
control points. The bird is black on blurred green, so the dorsal silhouette is a colour boundary,
and the feather line — the one genuinely ambiguous anchor — is *measurable*: brightness sampled
under the dorsal edge ramps 40 → 175 between x=2320 and x=2740 as matte feathers give way to glossy
bill, midpoint ≈ x2510. The owner picked that anchor from three candidates placed in the scene.

⚠ **TAKE THE CURVE'S SHAPE, DISCARD ITS SCALE.** The head is yawed slightly toward the camera,
which foreshortens the bill along its length and leaves the vertical alone. Normalising both axes
to the endpoints cancels a uniform foreshortening exactly, so curvature survives; absolute
depth-over-length does not (photo 0.75 against the model's 0.51 — unusable). Drop-over-length
*was* usable: photo 0.330 against the model's 0.305, inside the error, so the bill already fell the
right total amount and only the distribution was wrong.

Three defects found and fixed along the way, none visible in the closed silhouette:
- **The upper mandible had NO vertices between y=0.779 and y=0.817** — one unsupported span across
  the forward 20%, which was simultaneously the faceting, the straight drop and the sharp tip.
  Depth measured 0.0000 from 84% forward: the last sixth was a zero-thickness blade.
- **One asymmetric quad webbed the gape shut on the right.** Face 237 spanned y 0.6252→0.6815
  where its left-side mirror (face 41) stopped at 0.648. Invisible closed; it stretched from lower
  bill to upper the moment the jaw opened. Deleting it left wire edges behind, which then
  subdivided into 7 fractional-weight vertices — `FACES_ONLY` is not a cleanup.
- **The jaw hinge sat 0.025 BELOW the gape line.** Moved back behind the rictus and up to gape
  level; tip drop at 25° went 0.0689 → 0.0874.

**The mouth is now lined and the bird is watertight.** Ray tests, not edge counts, are the proof: a
vertical ray through the closed bill hits four surfaces (culmen, palate, floor, gonys) in
front/back/front/back order, and with the jaw open at 25°, 428 of 960 cast rays hit the mesh and
**none hit a backface first**. Before, a ray fired forward from the throat ran all the way to the
tip: head and bill were one empty cavity, and Roblox culls backfaces, so an open beak would have
shown sky through the head. The gape boundary was a single 156-vertex manifold loop — 84 upper, 72
lower, joined at the two rictus corners — which is what let each arc be zipped shut independently,
so the palate rides the skull and the floor rides `bill_lower` and only two throat quads span both.

**`run()` no longer produces the shipping bird, and now says so.** See rule 8 of
`practice/blender-working-rules.md`: `assert_authored_bill_absent()` is the first statement in
`run()`, and `karasu_authored.blend` and `karasu_body.fbx` joined `OWNER_AUTHORED`.

⚠ **STILL OWED:** the deliverable `.rbxm` and `karasu_body.fbx` predate all of this, and
`BirdController` has no gape wiring at all — `BirdFlight.gapeAt` returns 0–1 with no caller and no
degrees multiplier, so the gape angle is still unchosen (25° was a test value). The mouth interior's
UVs are one tiny disc per face, not a real island. `BirdFlight.luau:200` still cites a stale 0.30
`CAW_GAPE_SECONDS` against a 0.48 gap; both numbers are wrong.

## [2026-08-30] decision | `art/`: a formal in-repo home for what no script can reproduce

`karasu_authored.blend` was irreplaceable and lived in exactly one place on one disk, outside the
repo. It and `karasu_colormap_graded_2.png` now live in `art/birds/karasu/`, and Blender saves
there directly rather than to scratch — the pipeline reads authored inputs from `ART_DIR`, never
from `OUT_DIR`, so an owner edit cannot land in a file the pipeline no longer reads.

The admission rule is in `art/README.md` and is **checked, not merely written**: a new CI step
rejects derived files under `art/` (`*.fbx`, `*_baked.*`, `karasu_retarget.blend`, mesh formats)
and fails if any `ART_SOURCES` name is not stored there. Both branches were proved by mutation —
planting a `karasu_body.fbx` under `art/` fails the first, un-tracking the colormap fails the
second, and removing each restores the pass.

⚠ **THE FIRST DRAFT OF THAT CHECK WAS SELF-CONTRADICTORY** and would have failed on a correct
tree: it demanded every `OWNER_AUTHORED` name be stored in `art/` while separately rejecting
`.fbx` there — and `karasu_body.fbx` is in that set. The two categories are genuinely different,
so the script now names them separately (`ART_SOURCES` vs `OWNER_AUTHORED`).

**Git LFS was considered and declined**, with numbers: 57 MB of history across 1652 commits, and
the existing multi-megabyte binaries (a 5.9 MB mp4, a 5.5 MB normal map) were committed once and
never re-saved, so the repo has no churn problem. LFS costs a tool every contributor and CI job
must install plus a metered GitHub quota. The mitigation is instead a stated rule — **`art/`
receives deliberate saves at approved milestones, not every tweak.** Retrofitting LFS is not
blocked by this layout; `.git` outgrowing the working tree is the trigger.

**The blend is self-contained: every image in it is PACKED.** An initial note here claimed the
committed blend would open with `karasu_normal.png` and `karasu_roughness.png` missing on a
machine that had not run the bake. That was wrong — Blender had packed them, so the derived maps
travel inside the file while staying correctly out of `art/` as separate assets. Checking
`image.packed_file` is the answer to "will this open elsewhere", not whether the path resolves.

Auditing that claim turned up three real problems the wrong one had masked:
- **`KarasuWings` had no material at all.** Now shares `KarasuPBR` with the body — verified rather
  than assumed: both use UV layer `map1`, the body occupies 153 atlas cells and the wings 12,
  with **zero overlap**. One atlas, disjoint islands.
- **Three unused vendor textures were packed inside** (`crow_mesh_diffuse`, `uv_crow_alpha`,
  `wing_diffuse02`) with the materials that referenced them. Purging them took the blend from
  **7.22 MB to 2.75 MB** — 62% of the file we had just committed as irreplaceable source was dead
  vendor weight. ⚠ Packing makes a blend self-contained; it also silently commits everything the
  scene ever loaded. Purge before promoting to `art/`.
- Their relative paths had broken when the file moved into the repo, which is what made them
  visible at all.

### Conditioning the authored blend for export — and a blind spot in the guard that exists to prevent it

`run()` ends with `normalise_weights` and `thicken_degenerate_uvs`; a blend built by hand never
passes through them, so the authored master was out of spec on both counts. Fixed in place, but
the interesting part is *why the audit disagreed with the pipeline's own report*.

⚠ **`thicken_degenerate_uvs` TESTED THE UV BOUNDING BOX, WHICH CANNOT SEE A DIAGONAL COLLAPSE.**
It reported 0 problems on the wings while 84 faces had exactly zero UV area — every zero-area face
on that mesh, missed. They are quads whose UVs read `[A, B, B, A]`: folded onto a line running
diagonally, so the box around them spans 2.5 × 1.6 texels and passes. All 84 have real 3D area
(~0.0005) and no coincident vertices, so they are genuine geometry — thin strips along the wing
edge, ~0.015 wide — sampling a UV line. The function now measures **area**, keeping the box test
alongside it for faces that have area but are thinner than a texel. Body 24 thickened by the box
test, wings 84 by the new area test; neither would have caught the other's.

⚠ **A VERTEX GROUP MATCHING NO BONE INFLATES EVERY WEIGHT AUDIT.** `joint8.001` carried real
weight on the karasu body but had no corresponding bone, so nothing read it — while it made 43
vertices look like they had 5 influences and pushed weight sums to 1.9505. `normalise_weights`
filters to deform bones and so correctly reported 1.0; a naive audit over *all* groups did not.
When two measurements of the same mesh disagree, the definition is usually the difference. Group
removed; body 16 → 15 groups, all bones.

State after: body and wings both at 0 over-influence, 0 un-normalised, 0 zero-area UV faces.

### Correction: the guard was protecting the wrong thing

`karasu_body.fbx` was briefly added to `OWNER_AUTHORED`, and that single wrong entry generated
every tangle that followed — a self-contradictory CI check (it demanded the FBX be stored under
`art/` while another rule rejected `.fbx` there), an `ART_SOURCES`/`OWNER_AUTHORED` split invented
to paper over the contradiction, and finally a guard that refused the very export the authored
blend exists to produce. Removed, and the split and the second CI check collapsed with it.

⚠ **PROTECT THE SOURCE, AND ONLY THE SOURCE.** A derivative can always be re-exported, so guarding
one buys nothing and costs the legitimate path. The correct model is **one source of truth per
asset, changing hands exactly once**: `run()` owns a bird until a human makes an edit the script
cannot reproduce, and from that moment the `.blend` owns it and `run()` has no jurisdiction. The
one-way door is `assert_authored_bill_absent()`; nothing else needs guarding.

⚠ **WHEN A GUARD BLOCKS A LEGITIMATE ACTION, THE GUARD IS MODELLING THE WRONG THING.** That is the
signal to delete, not to add an exemption. Three mechanisms were added here before that was seen.

**The door has a cost worth planning around:** after it closes, upstream fixes can never reach that
bird. Do the procedural work first, hand-finish last, hand-finish once — and codify every edit you
can, because the door closes on the first one you cannot. On the karasu the loft, the mouth lining
and the tip merge are all reproducible; only the owner's vertex nudges at the tip closed it.

Both FBXs exported from the authored blend at rest pose. Each `.fbm` carries the complete PBR set
(ColorMap/Normal/Roughness/Metalness — partial is worse than none), and the exported ColorMap is
byte-identical to `art/`. ⚠ `eye_L`/`eye_R` carry no weights and Roblox will strip them on import;
that is expected since modelled eyes were abandoned.

### `eye_R`/`eye_L` deleted — the rig no longer advertises a forbidden mechanism

They existed to carry the eye POSITION inside the asset, so a runtime sphere could be CFramed off
`Bone.TransformedWorldCFrame` with no coordinates transcribed into Luau. `rebuild_rig` even set
`use_deform = True` on them specifically so `export()`'s `use_armature_deform_only=True` would not
drop them. Both halves of that are now dead: Roblox strips any bone influencing no vertex so it
never reached the game, and the runtime eye it served is forbidden outright — the karasu's eye is
the vendor's PAINTED eye in the ColorMap (`BirdController.client.luau:184` "NO EYE CODE, AND THAT
IS THE POINT"; `BirdSpecies.luau:26` records both shipped attempts failing).

⚠ **UNUSED SCAFFOLDING FOR A FORBIDDEN APPROACH IS WORSE THAN CLUTTER.** A rig carrying eye bones
invites exactly the reintroduction two Luau files warn against. That, not the two wasted bones, is
why they had to go.

Rig 21 → 19 bones, no orphaned vertex groups on either mesh, both FBXs re-exported. ⚠ The imported
result is unchanged — Roblox was stripping them anyway — so nothing already in Studio is stale.
`eye_site()` is untouched: it only MEASURES, and `landmarks_final` still emits `eye`/`eye_r` for
the bake. The seat was always data; it was never the bones.

Four comments describing the removed code were corrected in the same pass (`eye_site`'s docstring
claimed "SO THIS SHIPS A BONE", `build_eye_mesh`, the roster assert, and the `add_leaf_bones`
block). The `use_armature_deform_only=False` setting stays despite having no live reason left,
because the failure it causes is silent and the next bird's rig is not written yet.

### The beak opens on the caw — gape wiring, driven off the audio's playhead

`BirdFlight.gapeAt` had been tested, fed with measured onsets, and called by nothing since the
plane-cut jaw was retired. It has a caller now. `bill_lower` ships on `KarasuBody`, `sing()` keeps
the clip record and the `Sound` instead of throwing both away, and `RenderStepped` writes the jaw.

⚠ **THE GAPE READS `Sound.TimePosition`, NOT AN ELAPSED CLOCK.** `:Play()` on a sound that has not
loaded does not start the audio — it starts it when the load finishes — so a timer taken at the
call runs ahead of the caw and the beak opens before the sound, precisely on a cold load, which is
the first time anyone sees the bird. The onsets were measured off the source WAVs by
`tools/audio/measure_caws.py`; comparing them against a guessed playhead throws away the only
reason they were measured.

⚠ **THE HINGE IS LOCAL +X, POSITIVE — OPPOSITE TO BLENDER'S SIGN, WHERE THE SAME MOTION IS −25°.**
Measured in Studio on the shipped asset rather than derived: a probe rigidly attached one jaw-length
out along the bone's local **+Y** (the jaw direction — local +Z points at the *floor*) drops
**0.0641 studs** and swings 0.0156 back toward the tail under `CFrame.Angles(rad(+20), 0, 0)`.
Local Z rotation is lateral yaw and does nothing useful. A first probe run measured the wrong axis
because it assumed +Z was forward.

`BirdSpecies.CAW_GAPE_DEGREES = 20` (owner's starting value, to judge in Play). Shared rather than
per-species on the same argument as `CAW_GAPE_SECONDS`: an angle is scale-free, so a bigger crow
does not open wider. Every other bird constant scales by sqrt(length) and this one must not.

**The old test asserted the opposite and was inverted, not deleted** — it guarded against a
`bill_lower` lookup that silently returned nil, and now requires the lookup to exist and the source
to read `TimePosition`. Two invariants added: the gape angle is a real angle, and consecutive
onsets never sit closer than the gape window (the karasu's own gap is 0.775s against 0.23s, so a
two-caw clip cannot merge into one held croak). 1562 tests green, stylua and selene clean.

⚠ **THE UGUISU IS WIRED BUT SILENT.** `UguisuBody` carries a `bill_lower` bone, but none of its
clips have measured `caws`, so its beak stays shut — correct, not a bug. `measure_caws.py` is what
would change that.

Two stale comments in `BirdFlight` corrected in the same pass: `CAW_GAPE_SECONDS` was cited as 0.30
against a 0.48 gap (it is 0.23 against 0.70), and the module still announced "NOTHING CALLS THIS
TODAY".

### `watchWingbeat` gains a PERCH mode — a bird you can stand in front of and watch sing

The shoulder landing is not yet good enough to use as a viewing platform, and FLIGHT mode only
answers questions about travel. PERCH parks a bird three body-lengths in front of the camera,
facing the lens (a gape is a front-on read, unlike the wingbeat, which ISOLATED shows side-on),
and loops the ambient behaviours far tighter than the game does: singing every ~3.5s instead of
waiting on a chance roll, plus flutter and the idle head/tail. `PERCH_AT = "TORII"` stands it on
the gate's top rail (y 128.5) for the prettier shot.

⚠ **PERCH REFUSES TO RUN IN EDIT, AND THE REASON IS MEASURED.** In Edit a Sound loads properly
(`IsLoaded` true, `TimeLength` 0.520) and reports `IsPlaying` true, but **`TimePosition` never
advances** — six samples over half a second all read 0.000. The gape is driven off `TimePosition`,
so in Edit the beak hangs shut and the tool looks broken rather than unsupported. It asserts with
an explanation instead. This is the first mode in that file that cannot use the Edit path the
header otherwise recommends.

⚠ **`SONG_SPEED` SLOWS THE AUDIO AND THE JAW TOGETHER, WHICH IS WHY IT IS SAFE TO USE.**
`gapeAt` consumes `Sound.TimePosition`, and TimePosition is measured in CLIP time — it advances at
`PlaybackSpeed`. So the measured onsets still line up and the whole envelope simply plays slower.
0.35 makes a 0.23s gape something the eye can follow. A tool that slowed the jaw by any other means
would be showing a motion the game never performs.

The mode calls the same shared functions with the same arguments the controller does, so it proves
the ENVELOPE, THE DATA AND THE ASSET. It does not prove `BirdController`'s own wiring — the tool
reimplements that, and could show a perfect gape while the shipped controller is broken. The
inverted test in `BirdGape.spec` is what guards the wiring; this guards the look.

It reports after 12s and warns specifically: no `bill_lower` bone, versus songs playing with no
measured `caws` (correct for the uguisu, not a bug), versus nothing playing at all. A clip that
fails to load never fires `Ended`, so the song also carries an 8s deadline — the same guard
`BirdController` has, for the same reason.

### The species list opens, and a recollection checked against the source

Ambient and familiar birds will be **different species**, and the distinction is ecological rather
than enforced: **familiars are birds that come to people; ambient birds keep their distance.** That
answers the distinguishability question `world/ambient-birds.md` had left open, without a size
clamp or a behavioural exception. First slice is four perching birds — yamagara, mejiro, hiyodori,
sekirei — which are one body plan and therefore one retarget with four palettes.

⚠ **THE UGUISU IS THE SPARROW, AND THE SPARROW WAS NEVER DISCARDED.** Checked against an owner
recollection that it had been rejected as a base. It had not: `bake_bird_texture.py` describes
repainting *"a photoreal SPARROW"* into *"a plain olive uguisu"* while keeping the vendor unwrap,
and `BirdController` drives **the sparrow's bone names** — the crow arrived as a Maya QuickRig
humanoid and every bone was renamed into the sparrow's scheme. What was rejected is the sparrow as
a base for the KARASU, for one stated reason: *"a real crow head and bill... is the half of the
silhouette a sparrow cannot be reshaped into."* That objection is about a head and bill and is
silent for small birds, so the sparrow is the right base for all four of the first slice. Had this
gone unchecked, four birds would have been built on the wrong base or not at all.

**The zebra dove is an owner ruling** (`dove.blend` → *Geopelia striata*), chosen for its call and
knowingly not a Japanese bird — recorded so nobody corrects it toward a kijibato later. ⚠ Its
`caws` must be nil: doves coo with the bill closed, so a silent beak is authentic, and
`watchWingbeat`'s no-caws warning is wrong for this one species.

Two findings recorded against the ambient design, neither built:
- **Anchors want to be committed data, not place tags.** `GetTagged` returns a different set per
  client under streaming, so a tag sweep cannot be derived deterministically. A committed
  territory table is identical everywhere by construction, which makes placement derivable from a
  shared clock with **zero server traffic** — closing the divergence problem that page opens with.
- ⚠ **The bell startle is already free.** `RoundMetronome.Schedule` carries `strikeAt`, published
  as a schedule rather than an event, so a startle is `f(strikeAt, now, seed)` with no remote at
  all. A round is 60s, so it must belong to the TERRITORY rather than the world.

⚠ **COVERAGE, COUNTED RATHER THAN ASSUMED:** 326 `FamiliarPerch` attachments in 20 clusters — but
**71% are path lanterns and railings**, 16% bridges, 7% the falls landing, and only **15 perches
in the whole canyon are on a tree**. The perch graph is a ROAD MAP, not a habitat map; it is
correct for familiars, which follow players who walk on paths, and wrong for territories.

### Contract tests — the gap conventional testing still fills

⚠ **ELEVEN REAL DEFECTS WERE FOUND ACROSS THIS SESSION AND A UNIT TEST CAUGHT NONE OF THEM.**
Five came from measuring geometry (vertex valence, signed volume, ray casts, texel run lengths),
three from assertions embedded in the doing, two from reading a code path before running it, and
three from the owner's eye. That is the honest case against writing tests for generative work: no
assertion substitutes for "does this read as a crow".

But there is one class conventional testing still owns — **the contract between DATA and the code
that reads it** — and it was going unchecked. Both halves now exist and both were mutation-proven
rather than merely written.

**`tools/blender/test_bake_contracts.py`** runs the real shaders over the real palettes with
`bpy` stubbed (they are pure numpy). ⚠ **IT RUNS THEM RATHER THAN PARSING THEM**: grepping the
source for `C["..."]` would be guessing, and a key read inside a conditional is only checked if
the condition is true — `shade` looks up `eyeline` and `supercilium` inside `if head.any()`, so
the probe points deliberately include the head band 0.082 < y < 0.168. Seven planted defects, all
caught: a missing palette key, a species naming a shader that does not exist, an inverted eye-ring
stack, roughening that dies before the ring's outer edge, a lore that stops reading off `EYE`,
colour leaking into a scalar roughness channel, and a throat running past the bill line. Wired
into `roblox-ci.yml`.

**`tests/BirdSpeciesContract.spec.luau`** tests the SHAPE every species must have, where
`BirdGape.spec` tests the karasu's measured onsets specifically. Six planted defects, all caught:
a duplicate clip id inside one voice (which errors nowhere and merely makes one call twice as
likely as the weights say), an onset that leaves the beak open after the sound stops, two onsets
closer together than the gape window, a reversed rolloff pair, a zero clip weight, and a
`bodyLength` of 0 — which would otherwise surface at spawn as NaN positions and "the bird
vanished". 1562 tests -> 1568.

⚠ **A GUARD THAT HAS NEVER FIRED IS NOT KNOWN TO WORK.** Every check added here was made to fail
once, deliberately, before being trusted. That is cheaper than the check itself and worth more.

### The beak learns to warble — an envelope alongside the onsets

⚠ **ONSETS ARE THE WRONG MODEL FOR A CONTINUOUS SINGER, AND THE MEJIRO PROVED IT.** `gapeAt` takes
a list of onsets and opens the beak for a fixed window at each, which describes a karasu exactly:
two or three caws of 0.18–0.24s separated by 0.775s of silence. A mejiro's 5.3s clip is **voiced
46% of its own length** in an unbroken warble — asked for onsets you would be picking arbitrary
points in a run of sound. So a clip now carries **either** `caws` **or** `env`, and the choice
belongs to the bird rather than to us. Neither leaves the beak shut, which is correct for a dove.

⚠ **NORMALISE THE ENVELOPE BY A HIGH PERCENTILE, NOT THE PEAK.** The peak of a warble is one
transient; dividing by it left the mejiro's mean gape at **0.25 with 12% of frames above half** —
a bird mumbling through its own song. At p85 it is **0.53 with 52% above half and 10% shut**: a
beak that sits open, modulates, and closes in the breaths. Same class of error as peak-normalising
a colour palette.

⚠ **SMOOTH BEFORE SAMPLING, AND STORE SLOWER THAN YOU MEASURE.** A jaw has mass and cannot track
syllables; 150 ms smoothing at a 12 Hz storage rate costs **106 numbers for all four mejiro
clips**, and `gapeFromEnvelope` interpolates so the jaw does not tick at the storage rate.

**Clip selection, measured not guessed.** Whole-file SNR picked mejiro_3 at 56 dB — and that was
the WRONG STATISTIC: the file is clean because most of it is quiet, containing a *second, distant
bird*. Only 2 of its 8 phrases are usable; the rest run 21–36 dB down. Per-phrase SNR is the right
measure, and by it mejiro_3's two loud phrases (59–62 dB) still beat everything in the other files
(36–45 dB) by 15 dB. The short "remark" came from inside the 1.64s song, which turned out to be
three motifs separated by >60 ms of near-silence. ⚠ The long clip is capped at 5.3s by the **8s
leak guard in `sing()`** — the two best long passages are 7.75s and 8.40s and would be truncated
mid-song by a safety net meant for failed loads.

`tools/audio/measure_envelope.py` is the sibling of `measure_caws.py` and shares its WAV reader.
Its `--check` mode and a new contract test both catch the same defect: **an edited `seconds` with
a stale `env`**, which slides the beak out of sync with its own audio, silently and worse the
further into the clip you get.

Mutation-proven: a clip carrying both onsets and an envelope, an envelope too short for its
duration, and a value outside 0–1 all fail. 1571 → 1573 tests.

⚠ **NOT YET SHIPPED:** no species carries an `env`, because the mejiro has no uploaded clip ids.
The two new contracts are therefore vacuous until it does — which is why they were mutation-tested
against a temporarily-envelope'd karasu rather than trusted.

### The mejiro is a species — and the contract caught a defect on its first real use

Four clips shipped with measured envelopes and ids. Weights follow the karasu's rhetoric rather
than being uniform — 40/30/20/10 from the 0.46s remark to the 5.3s full warble — because a thing
heard every fourth time is not a declaration. `volume = 0.85`, the uguisu's rather than the
karasu's, and for the same measured reason: these clips peak −3.3 to −7.8 dBFS (mean ≈ −5.5)
against the uguisu's −5.4 and the karasu's −7.4 to −9.9. `bodyLength = 0.640`, measured off the
shipped asset, sharing the uguisu's mesh scaled 0.7729 on **both** halves.

⚠ **THE ENVELOPE CONTRACT FIRED THE MOMENT IT STOPPED BEING VACUOUS, AND IT WAS RIGHT.**
`measure_envelope` computed its frame count as `(len - hop) // hop`, dropping the trailing partial
frame — mejiro-4's 62 samples spanned **5.167s of a 5.30s clip**, so the beak would have shut
0.13s before the song ended. Every clip was short by a frame or two. The fix is `ceil` with the
final frame taking whatever samples remain; the test's ±1.5-sample tolerance is what made it
visible, and a looser one would have hidden it.

⚠ **THAT IS THE ARGUMENT FOR CONTRACT TESTS IN ONE EXAMPLE.** It is not a defect anybody would
report — nobody watches a beak for the last eighth of a second of a song — and no amount of
looking at the bird would have found it. It is exactly the mechanical, invisible class that
conventional testing still owns.

Proven live rather than assumed: editing `seconds` to 7.0 while leaving `env` stale fails both the
Luau contract and `measure_envelope.py --check`, which report the same defect from two directions.
1573 tests green.

⚠ **STILL PLACE-ONLY:** `MejiroBody`/`MejiroWings` exist in the place with their SurfaceAppearances
but are not saved to `assets/meshes/` and not declared in `default.project.json`. `SPECIES =
"Mejiro"` therefore works in the owner's session and nowhere else until they are.

### The export stops naming its rig, and finds a second bird's defect on first use

`export()` hardcoded `Karasu_Rig`, one of nine places in the pipeline that did, which is why the
uguisu — whose retarget was never a script — could use none of it. It now derives the armature
from the mesh's own modifier (`rig_of`). ⚠ **A RIG NAME IS THE WRONG THING TO PASS:** the object
already knows what deforms it, and a derived value cannot be typed wrong. An unrigged mesh now
raises instead of exporting a static one, which imports successfully with no bones.

⚠ **AND THE FIRST USE ON A SECOND BIRD FOUND A DEFECT.** `UguisuWings` carried every weight
**twice** — once at its own group indices 0–3 and once at 17–20, which is where those four bones
sit in `Uguisu_R`, the object it was separated from. **832 stale entries across all 416 vertices**,
summing every vertex to 2.0. `normalise_weights` had reported it clean, correctly: it filters to
groups NAMED after deform bones, and a stale index names nothing. Only summing the raw entries
showed it. Cleaned by rebuilding the deform layer against the declared groups.

⚠ **THE LESSON IS ABOUT THE CHECK, NOT THE BUG.** Three separate measures disagreed about the same
mesh — `normalise_weights` said 1.0, a naive sum said 2.0, and the truth was that both were right
about different sets. When two measurements of one thing disagree, the definitions are the
difference; that is the second time this session that has been the answer.

Both uguisu FBXs re-exported with the rigid bill, normalised weights, no `bill_lower`, and no
stale entries.

### The uguisu and mejiro re-ship on a repaired mesh

Both birds now share mesh `125989270453965` (body) and `122044327250866` (wings): 16 bones, no
`bill_lower`, weights normalised, bill rigid to `joint4`. The karasu keeps its 15 bones INCLUDING
`bill_lower` — its bill is genuinely cut, so it is the one bird that should have a jaw.

⚠ **A SHARED MESH MUST EXPORT WITHOUT EITHER BIRD'S PAINT.** `export()` uses `path_mode='COPY'`,
which copies whatever material the object is wearing into the FBX's `.fbm` for the Studio importer
to offer as a TextureID. The uguisu FBX shipped the MEJIRO's colormap — `MejiroPreview` had been
left on the uguisu meshes after the bake — and the owner caught it in the import dialog. `export()`
now takes `textures=False`, which strips the slots for the duration and restores them after.

⚠ **DO NOT SWAP `MeshId` TO KEEP A SurfaceAppearance.** `Bone` instances are CHILDREN of the
MeshPart, created by the importer; changing `MeshId` swaps the geometry and leaves the old skeleton,
so new weights would bind to a stale rig. Import fresh and transfer the SurfaceAppearance, the
size and the name onto the new part instead.

⚠ **THREE MEASUREMENTS WERE WRONG TODAY AND THE DATA WAS RIGHT EVERY TIME.** `strings` on a
compressed `.rbxl` said a mesh id was missing; a regex for `MeshId`/`<url>` said every MeshPart was
blank, when the modern serialisation is **`MeshContent`/`<uri>`**; and a per-part regex bounded by
lookahead swept to end-of-file and reported `bill_lower` on the wings. Each nearly became a bug
report. **Verify the instrument before trusting a surprising reading** — see also
`practice/blender-working-rules.md` rule 9.

The Rojo round-trip is sound: a `rojo build` carries every bird's `MeshContent` and the uguisu's
`TextureContent`. The blank duplicates that appeared under `RoshamboBirds` were a LIVE-SYNC
artifact — Rojo created the newly declared Mejiro children before their `.rbxm`s had content —
not a defect in the committed files.

### "Only the mejiro" — one observation that falsified a whole diagnosis

The owner saw flat polygonal blobs on the toes and I traced it to an asymmetric rig: the uguisu's
RIGHT leg chain sat **0.049 studs outboard of its own geometry**, so posing it swung the leg about
a pivot outside the limb. Mirroring the chain took toe-deformation asymmetry from **0.042 to
0.0119 studs** and mismatched mirror pairs from **197 to 1**. Real defect, worth keeping — the
mesh is symmetric to 0.0012 and the rig was not.

⚠ **AND IT WAS NOT THE CAUSE.** The owner then said *"only the mejiro"*. The two birds share the
mesh AND the rig, so anything in either must show on both. That single sentence falsified the
whole line of investigation, and I would have gone on believing it.

What differs between them is **Size and paint**, and the scaling is uniform to six decimal places
(x = y = z = 0.772899, spread 0.000000). So it was the SurfaceAppearance — and specifically the
roughness map, which the uguisu does not have at all.

⚠ **GLOSS REVEALS FACETS, AND LOW-POLY GEOMETRY HAS NOTHING TO SPARE.** `shade_roughness` gave
legs **0.42** against plumage's 0.88 — the toes were twice as glossy as the feathers, and a
specular that tight picks out each facet's normal. The geometry was blameless: all **324 toe faces
are smooth-shaded**, no custom normals, no sharp edges. Legs raised to 0.70 and the bill from 0.34
to 0.55 — the bill is the same mechanism on the same mesh with 66 vertices carrying the whole
thing, so it was raised pre-emptively rather than after another cycle.

⚠ **A BIRD WITH NO ROUGHNESS MAP IS A CONTROL GROUP.** The uguisu could not show this defect, and
that is what identified the cause. Two assets differing in exactly one property is worth more than
any amount of staring at the one that is broken.

The mirrored rig and the new roughness map ship together, so it is one import cycle rather than
two. `joint15` now carries 355 vertices where it had none — it was the only deform bone in the rig
with nothing bound to it, which is why the left front toe rode the ankle while the right rode its
own toe bone.

## [2026-08-31] defect | the birds' heads never pitched, and their feet never touched the perch

Two silent faults under one session, both surfaced by the owner looking rather than by
any check. **`CFrame.Angles(pitch, yaw, 0)` assumed the bone's local axes were the
body's.** Measured on `MejiroBody`, pitch is slot **Z** on both neck bones: the pitch we
wrote yawed the neck and rolled the head, the yaw rolled the neck, and the song's
head-lift had never fired on any bird since they shipped. The two neck bones also yawed
against each other (−body Y against +body Y), an S-bend that read as a side-to-side
wobble — which I had spent a commit tuning `SING_STILLNESS` against, treating a broken
axis as a damping problem. Owner: *"the head rotates (yaw) and tilts side to side (roll)
but does NOT lift up it's beak (pitch) at all."* Nothing flagged it because a head that
yaws when asked to pitch is still a moving head.

**And `PivotOffset` is not the feet once a mesh is resized.** The mejiro is the uguisu's
mesh scaled to 0.773; the mesh scaled, the pivot did not, and the two now seat 0.054
studs apart on a byte-identical pivot — 15% of the mejiro's height. The comment
justifying the pivot cited "feet land within 0.021 of the target", which was the uguisu's
own residual accepted once and then generalised to every bird.

⚠ **And the seat was still wrong after that.** The box bottom is the lowest toe *tip*, and the
toes are modelled curled, so the pad the bird stands on is above them. Two seating models both
measured correct — the second to within 0.004 studs — and both read as a sunk bird to the owner,
because neither was solving for the pad. Settled the only way it could be: three identical mejiros
on the rail at +0.00 / +0.05 / +0.10 studs, owner picked +0.05, giving
`PERCH_CLEARANCE_FRAC = 0.078` of body length. Recorded in the source as the owner's eye, not a
derivation. The owner also challenged the perch height itself, which was worth checking and turned
out sound — a probe cube on the same raycast sat correctly, and the rail's profile is flat at
127.598 across the bird's whole footprint, rising to 128.480 only at the curved tips.

Both faults now read from the rig instead of assuming it: `BirdFlight.toBoneSpace` and
`BirdFlight.footOffset` are pure (Lune has no `CFrame`), with `BirdRig` the Roblox half
that resolves each bone's axes at spawn and seats by the rendered box bottom. Recorded in
[[blender-pipeline]], including the trap that `Bone.WorldCFrame` reads back **unscaled**
on a resized MeshPart and so cannot be used to find the feet. 1579 → 1588 tests.

## [2026-08-31] ship | the mejiro is exported at its own size, and stops being a special case

The perch seat was chased through three models in one session and the owner's eye rejected two
that measured correct. What settled it was putting all three species on one plank at once:
pivot-seating is exact on the karasu and 0.002 out on the uguisu, and **only the mejiro missed**,
because it was the uguisu's MeshPart resized inside Studio — which scales the mesh and leaves the
pivot data behind. It had been carrying a 0.0164 correction no other bird needed.

Re-exported from `uguisu_authored.blend` at its own 0.640 nose-to-tail: data-level scale on meshes
and armature, no re-centring, `textures=False`. Verified round-tripping with 21 bones on both
halves and no materials. Its `seatNudge` is now the uguisu's −0.002, because it *is* the uguisu at
0.773 — two birds, one measured number, no hack. A test now fails if any bird's nudge grows past a
hair, which the old 0.0164 does.

⚠ Owner ruling that drove this: *"we don't want one bird to be a hack."* Recipe for scaled siblings
recorded in [[blender-pipeline]], along with the MCP trap that `import_scene.fbx` needs a full
window override.


## [2026-09-01] decision | Fireworks proving range spec approved; in-Play only, at FallsLanding

Spec: docs/superpowers/specs/2026-09-01-proving-range-design.md. First of four
fireworks sub-projects (range → vocabulary → handheld → distribution). Owner rulings
folded in: review loop is IN-PLAY ONLY (an edit-mode/MCP proofing tier was offered and
declined — the true runtime path every time); the yard sits on FallsLanding; rack
labels are physical plaques, never BillboardGuis ("always floating strangely in
screen space"). Drafts live in src/shared/FireworkDrafts.luau as families of
variants, namespaced draft:family/variant, absent from the shared fixture so CI
never prices a draft.

## [2026-09-01] ship | Proving range working in Play; first session catches a shipped VFX bug

Branch `proving-range` (12 commits, base 8ed22e5): drafts/schema/plan modules,
Studio-gated remote, bridge racks (surveyed catenary: per-station dy + inward tilt),
open-anywhere panel, night attribute gate. Owner rulings during the gate: 2"/4"/6"
mortars (yonshakudama parked for later), racks on the suspension bridge + judging from
FallsLanding, FiringPost/location-bound panel killed ("what's the point of a panel
location…"). THE RANGE PAID FOR ITSELF IMMEDIATELY: every shipped burst since
2026-08-05 was a flat vertical line (SpreadAngle/drag/fade lost between bench and
controller) — caught at the range's first eye-level look, fixed in adaa1fe. Owner,
end of session: night toggle works, ladder looks right, "a lot of comments in the
morning… well done." NOT merged; comments pending. Place not yet saved/published.

## [2026-09-02] gate | Proving range merged to main -- owner: "good for now"

Fast-forward 8ed22e5..4967872 (13 commits), suite green on the merged result
(1611). Range is live in the place (saved 2026-09-01). Next per program order:
the VOCABULARY sub-project (new phase kinds; multi-break/sub-bursts, break
geometries, the crisp round-dot texture upload the 2026-07-20 bench left open).

## [2026-09-02] decision | Vocabulary wave-one spec approved: style-on-burst, glow stack, staged shells now

Spec: docs/superpowers/specs/2026-09-02-fireworks-vocabulary-design.md. Owner
decisions: styles ring/palm/strobe/kamuro (+peony default); both textures; done =
styles + seed drafts (promotion stays per-shell); vibrancy in scope (LightInfluence
0, per-style Brightness through the one Bloom, saturated authoring); audio in scope
(87 files/573MB in Roshambo Reference/sound/fireworks, titles untrusted -> manifest
triage, composite boom+tail clips per style). Load-bearing find: the schedule
compiler already supports staged shells (points/scatter/share) -- staging is wave
one via validation + seed drafts, no compiler change. Style is a burst FIELD, not a
new kind; budget logic untouched.

## [2026-09-04] gate | Vocabulary wave one gated live and merged -- the range did its job all week

Owner iterated the whole vocabulary AT the range across 2026-09-03/04: caught the
unreachable sprite textures (recipes pinned SPARKLE over the roles), the 15Hz
TweenService chunking (fixed with per-frame bezier), upside-down and perpendicular
streaks (VelocityParallel + rotation -90), launch-read failures (2s->3s flights,
apex 60, trail 2.4s, muzzle flash), the glow stack (brightness vs color-over-life
vs lightEmission-as-stacking-law), sound physics (preload, speed-of-sound delay,
volume/rolloff), and hotaru's bespoke tail voice from the owner's OWN recording
(cut, slowed by resample, canyon-echoed, low-shaved, phase-bound). Green/violet
shape-trio families added on request. Owner: "pretty awesome. Let's merge."
Next named: variation in the aerial burst sounds (the 4-clip pool is one recording).

## [2026-09-04] ship | The kiku ships -- first shell promoted through the proving range

Owner gate: "that's the one, ship v2 kiku." v2 (spread 38, glow 1.5) with the 30%
boost distribution is now catalog id `kiku`, fixture-listed, priced 4 points behind
a mortar S. v1/v3 pruned from drafts (this commit is their archive). The promotion
pipeline worked exactly as the 2026-09-01 spec drew it: recipe move + one fixture
line + one server ledger row, CI holding both sides.

## [2026-09-04] defect | The promotion pipeline had an unguarded fourth step -- the shop's display tables

The kiku shipped server-side (deployed, CI green) and silently missed the Hanabiya
counter: ShopController hardcoded SHELL_ORDER/SHELL_NAME and renders only shells it
can name. Display metadata moved to shared/ShellDisplay.luau with a spec holding it
to the fixture -- the next forgotten shell is a CI failure, not an empty counter.
The proving-range spec's "no new machinery" promotion claim corrected in place.

## [2026-09-04] decision | Deck mortars spec approved -- default-first placeable gear

Spec: docs/superpowers/specs/2026-09-04-deck-mortars-design.md. Owner rulings: owning
a mortar puts it on the deck at a front-edge default immediately ("players shouldn't
have to know how to place a mortar before they can use it"); one tube per owned tier
(S/M/L staggered -- the deck shows the arsenal); gear exempt from the 24-decoration
cap. Gear-requiring shells launch from the required tier's muzzle; firecracker stays
hand-launched. Root cause it fixes: deck launches originated 6 studs above the
player's head since the August build.

## [2026-09-04] ship | Deck mortars merged and dev-deployed -- owner Play gate pending

`bc82000..31dcd6f` (9 commits, fast-forward to main), SDD-executed from
docs/superpowers/plans/2026-09-04-deck-mortars.md, ledger
`.superpowers/sdd/2026-09-04-deck-mortars/progress.md`. Backend `mortarPlacements`
(Mixed + markModified, validated PUT mirroring decorations), pure
`MortarPlacement.luau` (front-edge defaults, clamp, teahouse nudge, muzzle math),
server-built tubes in `TreatmentApplier:_buildMortars`, muzzle-true launches via
shared `BuildingPlacer.resolveFit`, move-only editor flow. Two plan/reality
corrections mid-execution: decorations render SERVER-side (plan's Task 5 assumed
client-side; spec's visitor-visibility won) and the editor lives in
DecorationController+MoveController (not BackDoorController). Final review caught
pre-ship: stale rejoin fingerprint (invisible mortars on same-server rejoin -- the
Play gate MUST include a same-server rejoin; fresh sessions can't surface it) and a
muzzle deck-size mismatch on display-shrunk decks. SHELL_MORTAR joined the fixture
CI gate -- gear-shell promotion is now a guarded FIFTH step (proving-range spec §5
amended). Suites at merge: Lune 1649, Vitest 486, lint clean.

## [2026-09-04] gate | Deck mortars gated -- six finds in one Play session, all fixed same-day

Gate fixes `9d3cd3c..9aa660a` on main. The finds, in order of discovery: (1) tubes
shipped onto the BACK edge -- the plan asserted front = local +Z; the live place says
-Z (Nobori canyon-side, PortalControl back-side); (2) PivotTo un-rolled the stood-up
cylinder (rolled PrimaryPart pivot) -- tubes lay flat at deck level, near-invisible;
(3) tubes drew 3x fat (plan's bore*3) -- bore is the INNER diameter, owner ruling;
(4) a mortar is an EMPTY tube: two faked bore-disc attempts rejected ("filled",
"overfilled"), replaced with real CSG hollow -- one SubtractAsync per tier, cached at
boot, cloned per rebuild; (5) the boot CSG yield let the player join BEFORE
PlayerAdded connected (no catch-up loop) -- dead session, no claim; deferred via
task.spawn; (6) join-time tag signals beat the padId attribute so NO Move prompts
bound at session start -- decorations included, a LATENT SHIPPED BUG (mid-session
rebuilds always bound, masking it). Bonus: firecracker now fires from hand height,
not the 6-studs-overhead placeholder. Gate steps passed: front-edge defaults, kiku
from the S muzzle, move-persist across Plays, hand firecracker, no phantom tubes.
NOT passed (untestable in solo Studio): same-server rejoin -- the fingerprint fix is
re-review-verified only; VERIFY ON THE PUBLISHED PLACE. Next: rail-mounts spec
(tubes clamp to the engawa's front rail, aimed out over the canyon; launch heading
follows the visible tilt -- owner direction, 2026-09-04).

## [2026-09-04] defect | Parked from the mortar gate: tsukubai lies down, proving bores undersized, bootstrap races

Three pre-existing issues surfaced by the gate, parked not fixed: (a)
DecorationCatalog's tsukubai builder has the same rolled-PrimaryPart PivotTo bug --
any placed tsukubai renders on its side (one-line fix, same shape as the mortar
one); (b) the proving-range racks draw outer diameter = bore, a hair undersized
under the bore-is-inner ruling; (c) main.server.luau's PlayerAdded handlers have no
catch-up for players already present -- any future yield added to bootstrap
re-opens the missed-join window (the mortar CSG was the first to hit it).

## [2026-09-05] ship | Rail mounts gated -- aimable mortars, ballistic arcs over the canyon, rail is the default

Branch `24c6da9..8e1a61b` (SDD, 8 commits) + gate fixes `27b410d..dcdffed`. Records
became {mount, offset, aim} (legacy floor/C, never relocated); three aims in a 60°
deck-front arc; elevations rail 25/floor 12; one pose (axisLocal/pose/launch) feeds
render + heading + ghost so nothing can drift; drop-decides-mount editor with a
1.25-stud rail snap band; DEFAULT_MOUNT = rail (owner lever pulled at gate -- absent
records only, the fall-through that would have swept legacy records was guarded).
Flight: ballistic apex 2h*tan(theta) downrange, control at apex height on the tube
axis; nil heading byte-identical (public/proving/firecracker untouched).

Two gate sagas worth remembering: (1) deck trails read as "exactly the old ones we
discarded" -- the owner's elimination set (public fine, proving fine POINT-BLANK,
deck wrong) survived two wrong diagnoses (path shape, then range) and pinned the
truth: the comet Trail's attachment pair is only thin when its local-Y offset lies
along the motion; tilted flights unfolded it into the old wide band. Shell now
orients local Y along the heading. (2) The missing-prompts hunt ended after FIVE
event-ordering belts when live instrumentation (a Play session run over MCP) showed
the join echo simply never arrives for a late listener (RemoteEvents don't queue;
the reveal push is gated on having picked) -- DecorationController now pulls its own
RequestSync re-echo AND runs a 3s rescan heartbeat: convergence, not cleverness.
Lesson logged for the wiki's standing rules: when event-ordering fixes stack past
two, instrument the live system before writing a third.

Same-server rejoin verification (deck-mortars carryover) STILL awaits the published
place. Suites at close: Lune 1653, Vitest 489, lint clean, CI green.

## [2026-09-05] gate | Wobble and break gated -- "perfect, looks great"

Post-gate owner direction ("we're currently just throwing fastballs from a pitching
machine on the deck") shipped and gated same-session (`d7eb85f`): heading launches
draw a seeded +-2.5-degree exit-axis wobble (angle/curve/reach cascade together
through the ballistics) and a +-12-stud late-arc break perpendicular to the flight
(zero at the muzzle, emerging near the peak). Drawn after the base scatter, so the
nil-heading rng stream -- public sites, proving range, firecrackers -- stays
byte-identical. Both numbers are one-line tunables in FireworkController.

## [2026-09-05] ship | Defect-sweep day -- eleven closed, one overturned, the drum never lies

Owner ruling: "let's work them, one at a time." Closed: (l) tsukubai PivotTo; (a)
atomic purchase (balance + uniqueness in one findOneAndUpdate; portal double-sale
was deterministically red); (b) decoration ownership (rearrange/remove only, never
mint); (c) RESOLVE_FAILED -> 404 (branch defensively dead on robloxUserId routes);
(o) NEW same-day find+fix: garbage path ids minted junk users -- digits-only
router.param guard; (e) TEST_MODE phase continues from the last persisted face,
deploys no longer re-roll the cycle; (n) all four PlayerAdded sites sweep players
already present (the CSG-yield window class, closed structurally); (d) the
empty onboarding cards -- the recorded AutomaticSize diagnosis was WRONG; the truth
(found live: seenBeats cleared on dev, probes + the owner's eyes) was
ZIndexBehavior.Global ranking the opaque card above its own labels, completed by
the round-2 opacity fix; every F&F guest would have hit it; (m) proving bores
rebaked to bore-is-inner; the (g)-adjacent bare pollOnce loop (one throw used to
kill a server's rounds). OVERTURNED: the (g) reveal residual -- owner: "the drum
should be authoritative" -- the drum now lands late rather than wrong, rests
between windows on a true miss (drumMiss cue; record releases, celebrations stay
silent). Backend fixes deployed to dev same-morning. Owner direction banked in
backlog: the onboarding JOURNEY pass (kid-legible, no gambling vocabulary, the
four questions), queued after the fireworks sprint. Suites at close: Lune 1654,
Vitest 498. Still parked: (f) undetermined, (i)/(j) identity gates (decision-gated,
not code-gated).

## [2026-09-05] ship | PLACE PUBLISHED -- the whole fireworks arc reaches players

Owner published the place. Everything since the last publish goes live at once: the
vertical-line burst fix (adaa1fe -- shipped broken 2026-08-05 to 2026-09-01), the
full vocabulary wave (five styles, staged shells, sound physics, hotaru's sizzle),
kiku, deck mortars, rail mounts with wobble/break and DEFAULT_MOUNT=rail, the
onboarding-card fix, the drum-never-lies build, and the day's defect sweep.
Verified at publish time: the published place targets the DEV backend
(SecretsLocal -> zzaw22ugpq / roshambo-dev) -- the service that carries every
route and fix; prod (the PWA's backend) is untouched by this arc, by design.
UNLOCKED: the same-server rejoin verification (deck-mortars fingerprint fix) --
recipe: two sessions hold the server open, leave+rejoin on one.

## [2026-09-05] gate | Live verifications on the published place -- rejoin PASSES, shop heals

Minutes after publish the owner found the shop showing zero holdings while the
picker was accurate -- the late-listener class's third victim (FireworkState was
the one payload RequestSync never re-echoed). Fixed same-hour (`a3c4c74`):
RequestSync now re-delivers the COMPLETE join state and ShopController pulls until
fed. Owner republished and verified live: shop totals correct, AND the two-device
same-server rejoin recipe (hold the instance open on Android, leave/rejoin on
desktop) proved the deck-mortars fingerprint fix -- tubes present at their
placements on rejoin. The deck-mortars arc has no open verifications left.

## [2026-09-05] fix | The iOS flaky bell cornered -- and the frontend's hosting is not what the wiki says

Owner: "the bell is missing from the PWA on my iPhone again. Didn't we already fix
that?" We had (2026-08-17) -- and the fix was live -- but it disarmed itself: the
unlock removed its gesture listeners after the first successful resume, iOS
re-suspends/interrupts the context on lock/background, the return-nudge's resume()
is refused outside a gesture, and no tap could repair it. Sticky audio death until
a lucky reload = reads as random regression. Fixed (`d5187da`): the listeners never
disarm; a healthy context makes the handler a no-op.

⚠ DISCOVERED WHILE DIAGNOSING, correcting the wiki's own hosting claim:
**playroshambo.com is S3 + CloudFront, not Amplify**, since ~2026-08-25
(index.html last-modified 2026-08-25 21:10; response header `server: AmazonS3`),
and the bucket/distribution are NOT in this machine's AWS account (198886313292 --
zero buckets, zero distributions; the only Amplify app in reach is an unrelated
2023 project). Frontend deploys are therefore manual AND undocumented: nothing in
README_DEPLOY.md or the wiki describes the S3/CF path. The unlock fix is committed
but NOT live until whoever owns that account syncs a fresh build. Also stale:
CLAUDE.md's "dist/ is committed build output" -- dist/ is gitignored.

## [2026-09-05] correction | The "S3+CF migration" claim two entries up is RETRACTED -- overreach, owner caught it

Amplify Hosting serves `server: AmazonS3` + `via: cloudfront` headers -- they cannot
distinguish Amplify from hand-rolled S3+CF, and the `last-modified: 2026-08-25` I
read as a migration date is better explained as the LAST AUTO-BUILD, made minutes
before auto-deploy was switched off that same day (the 08-25 entry, written from
live console observation, which necessarily had the Amplify app in hand). The wiki's
hosting claim STANDS: playroshambo.com is Amplify, frozen since 08-25. What remains
true and unresolved from the retracted entry: (1) the Amplify app is not visible to
this machine's AWS credentials (account 198886313292, us-east-1/2, us-west-1/2) --
it lives in another region or another account, and the frontend deploy path is
undocumented from this repo's seat; (2) CLAUDE.md's "dist/ is committed" is stale
(gitignored); (3) the iOS bell fix (`d5187da`) is committed but not live until an
Amplify build runs from wherever the app lives.

## [2026-09-05] correction | Second retraction on the same thread: the Amplify app was HERE all along

The retraction above kept one false residue: "not visible to this machine's AWS
credentials." Owner, looking at the console: "the roshambo_26 Amplify app is
sitting right there, in us-east-1, under that account." Correct. The region scan
omitted exactly us-east-1 (the default profile region is us-west-1; the loop
checked us-west-2/us-west-1/us-east-2). App: roshambo_26, appId dnlwlh7md4i46,
us-east-1, account 198886313292. Frontend deploy procedure, now DOCUMENTED:
`aws amplify start-job --region us-east-1 --app-id dnlwlh7md4i46 --branch-name
main --job-type RELEASE` (auto-deploy stays off per the 2026-08-25 ruling). The
iOS bell fix (`d5187da`) shipped via job 53. Lesson, same family as the headers
overreach: an absence claim is only as good as the completeness of the search --
name the regions you scanned when you claim "not found".

## [2026-09-05] fix | The PWA bell saga closes -- and the fake ad dies

Three acts: (1) the flake diagnosis stood -- the unlock disarmed after first
success and iOS interruptions made audio death sticky (`d5187da`); (2) that fix
shipped its own regression -- loadBell lived ONLY behind the resume(), so a
desktop context born 'running' never loaded the buffer at all; the owner caught it
within minutes and the console's own [SFX] instrumentation cornered it
(`6f8e2c0`: load on any gesture, unconditionally); (3) verified live by the owner:
one touch of the Arena, bell rings -- and the touch-first requirement is the web
platform's autoplay rule, invisible in real play where the first throw IS the
first touch. Deploys: Amplify jobs 53-55 via the newly-documented start-job
procedure. Also gone at owner request (`aa813c8`, job 55): the Antigravity-era
"Sponsored Intelligence" mock ad squatting on the Arena.

## [2026-09-05] correction | The proving range's real vantage -- and yashi v3 rejected

Owner: "I'm not using FallsLanding AT ALL for proving range, I'm standing on the
south terminus of the suspension bridge and looking at the 5 mortar racks edge on."
The recorded ~190-stud FallsLanding sightline was design assumption, not practice;
fireworks.md corrected. It also explains why the launch-thump pre-roll registered
at the range (close vantage, no physics-delay mask; fixed same day, SOUND_TRIMS).
Worksheet note: yashi v3 (6 arms) "particularly bad" -- consistent with the budget
law (points DIVIDE the budget; six ways is where the palm goes wispy, worse under
the longer rain). Floor stands at v1 (4 arms).

## [2026-09-06] fixed | Launch-thump lag: frame-hops, not just the clip head

The 0.12 head trim helped but "not fixed" (owner). Per-stage measurement in
Studio found no single culprit -- a STACK: the report's task.delay(0) parks a
Heartbeat, playSound's distance delay parks another, the trimmed clip still
ramped 68ms to peak, plus ~30ms SoundId swap: ~150ms+ at the tube. Fixed
`0e8433e`: zero-delay dispatch runs inline (at=0 phases and sub-frame sound
delays), trim deepened to 0.15 (peak ~38ms post-Play, thump not click). The
"settles after start" residue was preload order -- hash iteration left the
thump's queue position to luck; `00d4ebe` warms it first. Owner: "thump timing
pretty good now." Lesson twice-earned this sprint: measure each stage of the
real path; components that are individually fine can sum to a defect.
Also confirmed: RequestProvingFire is Studio-only by design (main.server.luau
IsStudio gate) -- live-place testing means deck launches with owned shells.

## [2026-09-06] shipped | Launch thumps pool; deck-4 reserved as the L tube's grunt

Owner uploaded launch-deck-1/3/4. 1 and 3 join deck-2 in a seeded rotation
(`292e978`, verified by ear); deck-4 ("heavier/gruntier and much more close
range... like from a bigger tube") is the L tube's voice via SHELL_MORTAR --
dormant until the first L SKU ships. Recipes no longer hardcode the report
sound; the controller resolves it, explicit phase sound still overrides. Trims
measured from source WAVs (peak minus ~35ms; offline envelope matched
in-engine within 3ms -- future clips can be trimmed before upload).

## [2026-09-06] shipped | Yashi promoted; colorway ruling lands

Owner rulings: yashi M tube at 10; "signature hues in shop, colorways in
collections." Yashi ran the five guarded steps (`e791ebd`: catalog 4-arm palm
with 30% fifth-arm boost + violet streak-rain kicker, fixture, server,
ShellDisplay, SHELL_MORTAR) and its draft family pruned behind it. The
colorway ruling reframes ao/midori/murasaki as collection palette material --
families pruned, archived at `2cd90b4`. Worksheet remainder: hotaru, kamuro,
dan. Dev backend redeployed (App Runner op 6032e84c). Server suite green
(one socketAdapter identity-claim flake observed, passed on rerun).

## [2026-09-06] built | The salute class, first-class -- and the L budget weight

A day of owner-driven iteration on kamuro ("not flashy enough"):
(1) boost.salvo machinery -- N flash-and-bang salutes, variable grouping, each
its own eagerly-pooled voice (count 1..8 validated; 3-4 kamuro, 5-8 reserved
for standalone salute shells); eardeer explosion cuts as the voices (3.5s
slap-echo single = every kamuro break's boom, 3s rolloff = salvo voice).
(2) Purpose-made flare art ("salutes are a first class effect") -- four
seeded-numpy star textures (make_salute_flares.py), noisy-edged at owner
request, uploaded via the Studio MCP's upload_image (images only -- audio/mesh
stay owner uploads), shuffled+rotated per shot from the seeded stream.
(3) First-salvo pileup fixed: lazy voices played before their clip bound and
the engine released all booms at once, late (owner reproduced 6x); voices now
eager with preassigned clip, IsLoaded guard, deduped priority preloader.
(4) THE L CLASS: recipe.heavy doubles the particle budget under WEIGHTED
ADMISSION (2 concurrency slots) -- sky total capped at the measured floor;
heavy-must-be-mortar:L fixture-enforced. Kamuro: heavy, spread 60, streaks
+50%, salvo in the falling crown. Owner: "looking and sounding good."
Also: proving panel now opens at night (owner default), drive-by rng lockstep
fix (double-tap draw was inside the per-client audio gate).

## [2026-09-06] shipped | Kamuro: the L tube's cheap round

Owner: "an inexpensive shell for the large tube -- a cheap round to show off
the big gun." Price 10, mortar:L, five guarded steps run (`3115d8d`), kamuro
draft family pruned. First shell of the heavy class -- weighted-admission
budget, L grunt launch, always-boom break, salvo kicker -- all live in one
SKU. Dev backend redeployed (op 962b864b). Worksheet remainder: hotaru, dan.

## [2026-09-06] shipped | The pity ramp -- bounded droughts on every boosted shell

The owner lived the flat-30% failure mode (0 boosts in 10 kamuro, filed as a
bug; a live rng tap proved the math healthy -- 3 boosted in the next 13,
matching 3 kickers seen) and ruled: add a pity ramp. `c92a6ee`: each miss
adds half the base chance (30 -> 45/60/75/90/100; worst drought 5), hit
resets to the recipe's floor. Pure BoostLuck.luau; server-side per-player
per-shell streaks (session-lived); verdict in the launch payload -- all
clients render the same luck; proving range deliberately stays on the raw
floor. Applies to every boosted shell automatically (kiku, wa, yashi, kamuro).
