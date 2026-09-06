# Splitting `main.server.luau` — Phase One Design

**Date:** 2026-09-06
**Status:** Approved (owner, 2026-09-06: "phase one, one gate per extraction"; "write the split spec plan").
**Program context:** Prerequisite for every further server-side feature. `roblox/src/server/main.server.luau` is 3,703 lines and uses 199 of Luau's 200 top-level local registers; sub-project B had to hang all of its server code off a `Launch` namespace table to compile, and the next handler added to the file will not. The split is not a cleanup for its own sake: it is the headroom sub-project C (consoles, tickets) and the Hanabiya melt verb need. Map: the 2026-09-06 recon of the file (35 sections, 8 extraction candidates), summarised below.

**Question** (owner): the file is at the ceiling; how far do we split now, and how is each step proven?

**Short answers:**

1. **Phase one, four extractions, in this order:** the remotes table, the shoji slide controller, the stats-room feed, the teahouse rebuild. Together they free roughly sixty top-level names and remove the file's worst duplication. The other four candidates are named and deferred (§8).
2. **Every extraction is a behaviour-preserving move, landed as its own commit, and gated by its own Studio walk** before the next begins. No harness loads the server file, so the owner pressing Play is the proof; per-extraction gates keep a fault attributable.
3. **Two kinds of module, by an existing house distinction:** pure modules (Lune-tested, services injected) and runtime adapters (`StructureOps`-style, may touch services, proven by the gate). Each extraction says which parts are which.
4. **Nothing changes on the wire, in the place, or in behaviour.** Same remotes, same payloads, same connection order, same yields.

---

## 1. The constraint being lifted

- **The ceiling.** Luau allows 200 local registers at a scope; the file's top level holds 199 names (198 `local` statements, one declaring two names). `roblox/tests/Compiles.spec.luau` compiles every `src` file at O0 and O2 and is the only guard: it goes red the moment name 201 appears, with no warning before.
- **What costs nothing:** `type` aliases; fields on an existing table (the `Launch` workaround); locals inside functions.
- **What the split buys:** each name moved into a module is a register freed. The phase-one set frees ~60 (§4), which is enough headroom for C and the melt verb without further namespacing.

## 2. Rules every extraction obeys

1. **Behaviour-preserving.** Same remotes, same payload fields and types, same order of `PlayerAdded`/`PlayerRemoving` connections, same catch-up sweeps after each `PlayerAdded` connect (the file's documented rule: a join during a bootstrap yield must not be missed), same `WaitForChild` semantics (bare at the top of the file, timed where the file already times them).
2. **The require convention** (`roblox/tests/RequireConvention.spec.luau`): a module under `src/server/` is required from `main.server.luau` by relative string path; anything under `src/shared/` is reached as `require(shared:WaitForChild("Name"))`. A cross-root relative string compiles under Lune and kills the server at load — the spec exists because it happened.
3. **Two module kinds.** *Pure*: no Roblox globals, services and side effects injected, a Lune spec in `roblox/tests/`. *Adapter*: lives in `src/server/`, may use `Instance.new`, `workspace`, `CollectionService` as `StructureOps`/`PadOps`/`TreatmentApplier` already do, has no Lune spec, and is proven by the Studio gate. An extraction names which of its functions are which, and the pure ones get specs.
4. **State moves with its owner.** A table the file mutates from several sections (`playerEconomy`, `playerHouse`, `handlerQueue`) is NOT moved in phase one; the extracted module receives it, or accessor closures over it, by injection. Only state used by one section moves into that section's module.
5. **Forward declarations are removed when their reason disappears.** Four exist purely for textual order (`pushFireworkState`, `syncEconomyPoints`, `rebuildClaimedPadFn`, `deckCFForUidFn`); phase one removes two (§4.4).
6. **No new `game:GetService` in a pure module; adapters may.** The house rule in `CLAUDE.md` is stated as absolute; the codebase's own adapters show the working distinction, and this spec records it rather than pretending.
7. **Gates:** `stylua --check src tests tools && selene src tools`, `lune run tests/run` (Compiles.spec included) before every commit; the owner's Studio walk after every extraction.

## 3. The file today, in one table

| region | lines | what it holds | top-level names |
|---|---|---|---|
| boot | 1–224 | services, day/night config, 23 requires, 37 remote handles, theme validation, `deps`/`net`/`clock`/`profiles`/`fates` | ~87 |
| profiles & round | 225–884 | name filtering, leaderstats, familiar roster, HUD prefs, `RoundCoordinator` wiring, `SubmitPick`, bank/ledger/HUD handlers, `PlayerRemoving` #1, board poller | ~30 |
| stats feed | 886–1036 | filter helpers (pure), pollers, per-player push | 9 |
| teahouse state | 1038–1305 | 16 requires, prefs, `playerHouse`, shoji slide/persist state, `playerEconomy`, `syncEconomyPoints`, shoji persistence | ~32 |
| fireworks | 1307–1967 | referee helpers, `Launch` (shows, proving, console door) | 10 |
| pads & access | 1969–2455 | `applier`, `rebuildClaimedPad`/`deckCFForUid`, friends/gates/nav lights/access recompute/access state, pad registration, economy join, `RequestSync` | ~19 |
| handlers | 2457–3624 | `PlayerRemoving` #2, prefs, back door, shoji slide, purchase, display/placement/decoration/mortar, access/invite/revoke, portal | ~11 |
| main loop | 3626–3703 | boot print, round poll, eviction backstop | 1 |

## 4. Phase one — the four extractions

### 4.1 `Remotes` (adapter) — frees 38 names

Today 37 `RemoteEvent` handles plus the `remotes` folder are top-level locals. A module `src/server/Remotes.luau` exports `Remotes.bind(folder: Instance): { [string]: RemoteEvent }` that `WaitForChild`s a fixed list of names and returns them keyed by name. `main.server.luau` keeps the folder handle and does `local R = Remotes.bind(remotes)`; every use becomes `R.SubmitPick`. The three timed fetches inside `Launch` (`RequestShowGo`, `RequestProvingShow`, the `FireworkShows` module) stay exactly as they are, because their timeout semantics are deliberate and documented in place.

- Kind: adapter (it yields on `WaitForChild`). No Lune spec; the list of names is asserted against `default.project.json`'s `RoshamboRemotes` block by a Lune test that reads the JSON, so a remote added to the contract but not the table fails CI.
- Risk: purely mechanical, ~37 call-site rewrites. Zero behaviour change.
- **Gate walk:** join, throw once, bank, open the ledger, slide a shoji, buy a firecracker, launch it. If any remote were missing the failure is loud at boot.

### 4.2 `ShojiSlideController` (adapter with pure parts) — frees ~12 names

The slide machinery (`SLIDE_RATE`, `SHOJI_REACH`, `SHOJI_PERSIST_QUIET`, `collectShojiRun`, `shojiReachPosition`, `withinShojiReach`, `scheduleShojiPersist`, `runShojiSlide`, the `SlideShoji` handler) plus the shoji state that only it touches (`shojiSlides`, `shojiPersistGen`, `shojiPendingPersist`, `shojiSlideKey`, `persistShojiNow`, `flushShojiForUid`). Constructed with what it reads: `players`, `sitesFolder`, `StructureOps`, `ShojiRun`, `net`, `handlerQueue`, `getHouse(uid)`, `getEconomy(uid)`, `fireShojiState(player, payload)`, `now`, `wait`. Exports `onSlideRequest(player, payload)`, `flushForUid(uid)`, `killActive(uid)`, `pendingCount()`.

- Pure parts with specs: `collectShojiRun` and `shojiSlideKey` (tested with a fake model table); `withinShojiReach` given plain positions.
- Ordering preserved: `PlayerRemoving` #2's sequence (fold the in-flight slide → clear the queue → flush persists → null house/economy → recompute access → site leave) is documented in the file as non-reorderable; the controller exposes the two calls that sequence needs and the handler keeps the order.
- **Gate walk:** slide a shoji on your teahouse as owner (persists), have a second account slide it (does not persist), leave mid-slide and rejoin.

### 4.3 `StatsFeed` (pure core + thin adapter) — frees 9–11 names

The stats-room feed: `filterTop`/`filterRecords`/`filterBoard`/`filterHeat` (pure today), the 47 s poller, `pushStatsPersonal`, `onPlayerJoinStats` + the 60 s loop, and `lastTape`/`lastStats`. `lastStats` is also read by the round coordinator's reveal callback to re-broadcast, so the module exposes `current()` and the callback reads it. Constructed with `net`, `filterName`, `roster`, `fireAll`, `fireTo`, `spawn`, `wait`, `players`. Exports the four filters (pure), `start()`, `pushPersonal(player)`, `onJoin(player)`, `setTape(tape)`, `current()`.

- Pure parts with specs: the four filters, on hand-built board/records tables.
- **Gate walk:** enter the stats cavern, confirm the boards fill within a minute, confirm the personal slip updates after a bank.

### 4.4 `PadRender` (adapter) — frees 2 names, removes ~200 lines

The resolve-and-apply sequence (`resolveBuilt` → tea loadout → treatment → `applier:apply` → sync `playerHouse`) is copy-pasted five times: the claimed-pad rebuild, the economy join, purchase, display change, placement/decoration change. One module `src/server/PadRender.luau` with `rebuild(uid)`, `deckCFFor(uid)`, `buildTreatment(e, built)`; the five sites call it. This removes the forward declarations `rebuildClaimedPadFn` and `deckCFForUidFn`. Constructed with `applier`, `PadSites`, `SizeClasses`, `DeckPlacement`, `Kamon`, `getEconomy(uid)`, `setHouse(uid, h)`, `CENTERED_PLACEMENT`.

- Pure parts: `buildTreatment` (given `e` and `built`) — spec it.
- Risk: the highest of the four because five call sites are unified; the gate walk covers all five triggers.
- **Gate walk:** claim a pad (join), buy a teahouse upgrade, change the display size, move a decoration, place a mortar — the teahouse rebuilds correctly after each.

### 4.5 Headroom accounting

| after | names freed (cumulative) | top-level names left |
|---|---|---|
| 4.1 Remotes | 38 | ~161 |
| 4.2 Shoji | ~50 | ~149 |
| 4.3 Stats | ~60 | ~139 |
| 4.4 PadRender | ~62 | ~137 |

Re-measure with `grep -c '^local ' roblox/src/server/main.server.luau` (plus one for the two-name declaration) rather than trusting this table; Compiles.spec is the authority.

## 5. Sequencing and coordination

- Branch `thread/split`, fresh worktree. One extraction = one commit + one owner gate; the next extraction starts only after the previous gate passes, so a regression is one diff wide.
- **The owner gate is a Rojo-served Play on `main`.** Each extraction is therefore merged to `main` (fast-forward, main thread quiet) BEFORE its walk, since Studio serves the main checkout. If a walk fails, the fix lands as a follow-up commit on the same branch, not a revert, unless the fault is structural.
- Concurrent branches: sub-project A never touches this file (by its plan's constraint). The console trigger (`PlayProvingShow`) is already merged and lives inside `Launch`, which phase one does not move. Sub-project C and the melt verb wait for phase one to finish.
- Dev backend: unaffected (no server-side TypeScript changes). The place must be published for players to receive any of it; the walks happen in Studio.

## 6. Testing

- Lune: new specs for every pure function named above; `Compiles.spec` after every extraction (headroom actually increased); `RequireConvention.spec` (no cross-root strings); the remotes-list-vs-contract test (4.1).
- Studio: the four walks above, owner-run, each recorded on the wiki as a gate.
- No Roblox-side behaviour test exists for the adapters; that is why the walks are per extraction.

## 7. What players see

Nothing. If anything is visible, the extraction was not behaviour-preserving and the gate has failed.

## 8. Deferred to phase two (named so they are not lost)

- `AccessEnforcement` (friends, gates, nav lights, access recompute/state, portal gating, eviction loop) — ~12 names, one-directional coupling.
- `FireworkReferee` (sites, deck row, muzzle origin, fingerprint, `pushFireworkState`, `Launch`) — ~11 names; highest coupling; `mortarFingerprint` is pure today. This is where the melt verb's handler and C's console handlers will live, so it is the first phase-two candidate.
- `BootWorld` (day/night config, theme validation, persistence marking, spawn sweep) — ~13 names, must stay first.
- `ProfileSync` (profiles, leaderstats, roster, HUD prefs, bank/ledger handlers) — ~20 names, entangled with the round coordinator's callbacks.

## 9. Open items

- None blocking. One observation for the wiki: `CLAUDE.md`'s "no `game:GetService`" rule for modules is contradicted by the shipped adapters; this spec records the pure/adapter distinction and the wiki practice page should say the same after phase one lands.

## Raw layer

- `roblox/src/server/main.server.luau` (line ranges above are as of `c61c0e5`); `roblox/tests/Compiles.spec.luau`; `roblox/tests/RequireConvention.spec.luau`; `roblox/default.project.json` (`RoshamboRemotes`); existing adapters `roblox/src/server/{StructureOps,PadOps,TreatmentApplier,PortalController}.luau`; existing pure server modules with specs `{HandlerQueue,NetworkClient,RoundCoordinator,ThrowBuffer}`.
- Recon: the 2026-09-06 section map (agent output, summarised in §3–§4; re-derive from the file, not from this page).
