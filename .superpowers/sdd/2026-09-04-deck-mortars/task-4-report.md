# Task 4 Report: Studio server — state carriage, SetMortarPlacement, muzzle-true launches

## What I implemented, per contract point

**1. State carriage.** `playerEconomy[uid]` gains `mortars: {string}` and
`mortarPlacements: {[string]: MortarPlacement.StoredPlacement}?`. Neither rides the `/economy`
GET (only `/fireworks` GET carries them, per Task 1), so the `PlayerAdded` bootstrap
(~line 1724) initializes them empty (`mortars = {}, mortarPlacements = nil`); `pushFireworkState`
(the sole call site of `net:getFireworks`) is the place they get their real values, mirrored from
`res.data.mortars`/`res.data.mortarPlacements` into `playerEconomy[uid]` right before the
existing `FireworkState:FireClient` call.

I extended **every** table that already carries `deckDecorations` to a client or into
`applier:apply`'s `treatment`, not just the two the brief cited as examples (1088/1424 in the
brief's line numbering) — there are 7 such sites in this file, and this codebase has a documented
history of exactly this class of bug (commit `f817607`, "second hardcoded shell table adopts
ShellDisplay"), so I treated the two cited lines as representative, not exhaustive:
- `echoEconomy` (EconomyState FireClient payload)
- `rebuildClaimedPad`'s `treatment` table
- `PlayerAdded`'s `action.treatment.*` assignment
- `RequestPurchase`'s buy-to-claim branch (`action.treatment.*`)
- `RequestPurchase`'s upgrade branch (`treatment` table)
- `SetDisplay`'s `treatment` table
- `SetPlacement`'s `treatment` table

All 7 now carry `mortarPlacements = e.mortarPlacements, mortars = e.mortars` (or the
`action.treatment.*` equivalent) alongside `deckDecorations`.

**2. `SetMortarPlacement` handler** — added after `SetDecorationPlacement`, mirroring its shape:
occupant-only (`e.claimedPadId ~= nil`), validates `payload.mortarId` is a string in
`MortarPlacement.MORTAR_ORDER` **and** in `e.mortars` (owned), `offset` two finite numbers,
`facing` one of N/E/S/W. Clones `e.mortarPlacements` into a new map, sets the entry, persists via
`net:putMortarPlacements(uid, newMap)` (full-map PUT), and on success adopts `e.mortarPlacements
= newMap` and calls `echoEconomy` (failure path also calls `echoEconomy` to resync). No
clamp is applied before persisting — `MortarPlacement.resolve()` clamps at read time and never
mutates a stored placement, so the runtime file doesn't duplicate that decision. Unlike
`SetDecorationPlacement`, there is no `rebuildClaimedPad`/`echoBackDoor` step: mortars are not
server-built props (`TreatmentApplier` never reads `treatment.mortarPlacements`/`mortars` — see
concern below), so `echoEconomy` is the whole reconciliation.

**3. Launch origin.** Refactored `deckSiteFor` to share a new `deckRowFor(uid): (row?, deckSize?)`
helper (reads the identical `spec.deckPlacements[e.maxDeckSize or "S"] or spec.deckPlacements.S`
row deckSiteFor always used) so the muzzle math and the site-validation math can never read two
different rows. Added `muzzleOriginFor(uid, pos, deck, shellId): Vector3?`: returns `nil`
(→ fall back to the eye-level origin) unless the shell requires gear
(`MortarPlacement.SHELL_MORTAR[shellId] ~= nil`), the player is standing within `deck.radius` of
`deck.pos` **specifically** (not merely admitted via some other overlapping site), and
`MortarPlacement.resolve(SizeClasses.deckFootprint(deckSize), e.mortars, e.mortarPlacements, nil)`
has an entry for the required tier (i.e. it's actually owned). When all of that holds, origin =
`MortarPlacement.muzzleWorld(row, spot, requiredMortar)`. `RequestFireworkLaunch` now computes
`origin = muzzleOriginFor(...) or (root.Position + Vector3.new(0, 6, 0))` right after the spend
succeeds. `firecracker` and every public-site launch are unaffected (SHELL_MORTAR has no entry
for firecracker; a public site never matches the deck-radius check).

## REQUIRED: gear-required wiring choice

The Studio server learns a shell needs gear via `MortarPlacement.SHELL_MORTAR[shellId]`
(non-nil → gear id). This is a **minimal hand-mirror** of `REQUIREMENTS` in
`server/src/fireworks.ts` — deliberate, per the brief's point 4 and the backend's own comment
("The client is told PRICES, never requirements"), which rules out fetching the requirement over
the wire. **⚠ Promotion-pipeline flag**: promoting a shell to gear-required (or changing which
tier it needs) now touches **three** places, not two — `server/src/fireworks.ts`'s
`REQUIREMENTS`, `roblox/src/shared/MortarPlacement.luau`'s `SHELL_MORTAR` (added this task), and
whatever client-side display consumes `reason` strings from the fireworks GET. Unlike
`MORTAR_ORDER`/`GameRules`, there is **no shared-fixtures file** enforcing `SHELL_MORTAR` against
`REQUIREMENTS` — drift here fails silently (a promoted shell keeps firing from eye level, not the
mortar) rather than failing CI. I added a spec test that every `SHELL_MORTAR` value is a real
`MORTAR_ORDER` entry, but that only catches a typo'd/removed tier, not a missed shell.

## Test/lint results

```
cd roblox && lune run tests/run
```
`1641 passed, 0 failed, 1641 total` (RED confirmed first: `attempt to iterate over a nil value`
before `SHELL_MORTAR` existed; GREEN after adding it).

```
cd roblox && stylua --check src tests tools
```
No output (clean).

```
cd roblox && selene src tools
```
```
Results:
0 errors
0 warnings
0 parse errors
```

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/default.project.json` — `SetMortarPlacement` RemoteEvent, text-edited beside `SetDecorationPlacement`.
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/src/shared/MortarPlacement.luau` — `SHELL_MORTAR` table + drift-caveat comment.
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/MortarPlacement.spec.luau` — spec test for `SHELL_MORTAR` ⊆ `MORTAR_ORDER`.
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/src/server/main.server.luau` — require, `SetMortarPlacement` remote var, `playerEconomy` type + bootstrap defaults, `echoEconomy`, `pushFireworkState` mirror, `deckRowFor`/`deckSiteFor` refactor, `muzzleOriginFor`, `RequestFireworkLaunch` origin, `SetMortarPlacement` handler, all 7 `treatment`/echo table sites.

Commit: `edadd85` — `feat(mortars): server state carriage, SetMortarPlacement, muzzle-true deck launches`

## Self-review findings; concerns

- **Cross-client visibility gap (flagging, not fixing — out of this task's file list).**
  `TreatmentApplier.luau` (not in my Files list) never reads `treatment.mortarPlacements`/
  `treatment.mortars` — it only builds physical decoration props from `treatment.deckDecorations`.
  So while I extended every treatment table symmetrically with `deckDecorations`, that symmetry is
  currently inert for mortars: `EconomyState` is `FireClient` (owner-only, exactly like it already
  is for `deckDecorations`), and nothing today broadcasts one player's mortar data to a
  *visitor's* client. Task 5's brief ("visitors render every deck's mortars") targets only
  `DecorationController.client.luau`, which itself has no cross-player data channel that I can
  find either (it binds prompts to already-replicated instances; it doesn't fetch other players'
  raw state). Task 5/6 will need to either extend `TreatmentApplier` to set attributes carrying
  this data (mirroring `MountCF`/`DeckSize`/`TeahouseSize`) or introduce some other channel — this
  is a real architectural gap, not something I could close within this task's file list, and I
  did not attempt to.
- **Join-time staleness (accepted, not fixed).** `echoEconomy` fires once at `PlayerAdded` before
  the first `pushFireworkState` completes, so a freshly-joined owner's first `EconomyState` frame
  carries empty `mortars`/`nil` `mortarPlacements`. I deliberately did **not** add an extra
  `echoEconomy` call inside `pushFireworkState` to self-heal this immediately, because
  `pushFireworkState` also fires on every reveal for every player (per its own comment), and that
  would add a full `EconomyState` (catalog included) broadcast per player per round — a
  traffic/perf change outside this task's scope. The gap self-heals on the next econony-mutating
  action (purchase, display change, decoration/placement edit) or the client's existing
  `RequestSync` retry, same as any other multi-endpoint bootstrap ordering in this file.
- Ran `git status` before touching anything; two pre-existing dirty files
  (`art/birds/uguisu/uguisu_authored.blend`, `.superpowers/sdd/.gitignore`) were already modified
  at session start and are unrelated to this task — left untouched, not staged, not committed.
- No enforcement was added at the server for firing a gear-required shell without owning the tier
  (`postFireworkSpend` doesn't check this either — confirmed by reading
  `server/src/routes/apiV1.ts`'s `/spend` route, which only checks held count). That's a
  pre-existing gap outside this task's contract (point 3 only asked for origin computation);
  `muzzleOriginFor` degrades gracefully (falls back to the eye-level origin) if the required tier
  turns out not to be owned.
