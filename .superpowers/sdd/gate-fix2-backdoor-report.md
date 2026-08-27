# B3 gate fix round 2: back-door prompts + economy stash

Two independent bugs fixed, per the diagnosed root causes (no re-diagnosis performed).

## Bug A — door edits never reached the economy stash

**File:** `roblox/src/server/main.server.luau`
**Change site:** `SetBackDoor.OnServerEvent` handler, lines 605-611 (right after `house.loadout =
newLoadout`, before the `net:setTeahouse` persist call).

```lua
house.loadout = newLoadout
-- rebuild paths (RequestPurchase upgrade, SetDisplay, buy-to-claim) render from this stash,
-- not from playerHouse; keep it in sync or the next rebuild reverts this door.
local e = playerEconomy[uid]
if e ~= nil and e.teahouses ~= nil then
    e.teahouses[house.size] = newLoadout
end
```

`playerHouse[uid]` (the occupancy stash used only for occupant-gated live edits) was being kept
current, but every rebuild path (`RequestPurchase` upgrade branch, `SetDisplay`, buy-to-claim)
reads teahouse loadouts from `playerEconomy[uid].teahouses[size]` — confirmed by the existing
read sites at lines ~719, 778 (`e.teahouses[built.teahouseSize]`) used to build the `treatment`
passed into `applier:apply`. Without this write, a door added via `SetBackDoor` lived only in
`house.loadout` (this session) and in the DB (via `net:setTeahouse`), but the very next in-memory
rebuild would re-render from the stale pre-door `e.teahouses[size]` and silently drop the door —
exactly the "doorless after a deck upgrade" symptom. A rejoin healed it because `PlayerAdded`
re-fetches `teahouses` fresh from the DB via `net:getEconomy`.

The nil-guards match the file's established convention (`local e = playerEconomy[uid]; if e ==
nil then return end` used at lines 409, 620, 750) — here relaxed to a non-early-return guard
since a missing `e` or `e.teahouses` must not abort the live re-render/persist that already
happened above it, only skip the stash mirror.

## Bug B — client controller redesigned around geometry arrival

**File:** `roblox/src/client/BackDoorController.client.luau` — full rewrite (159 lines changed),
same public behavior (F key, `MaxActivationDistance = 12`, "Add a door here" / "Remove this door"
labels, one-door-slot `relabel()` logic, `anchorPart` unchanged) but restructured lifecycle.

### New structure

State (module-level upvalues):
- `activeIndex: number?` — last echoed active door bay
- `currentFolder: Instance?`, `currentStructure: Instance?` — what's currently bound
- `folderConn: RBXScriptConnection?`, `structureBaysConn: RBXScriptConnection?` — stored so a
  rebind can disconnect the previous watch before re-arming
- `prompts: { [number]: ProximityPrompt }` — reassigned to `{}` (not mutated) whenever
  `currentStructure` changes, since old prompts belong to the dead structure

Functions:
- `createPromptForBay(bay, i)` — dedupe-then-create for one bay (factored out so both the
  initial sweep and the late-arrival listener share one code path and one dedupe check)
- `bindStructure(structure)` — no-ops past `relabel()` if `structure == currentStructure`;
  otherwise disconnects the old bay watch, clears `prompts`, sweeps existing `Bay_back_<i>`
  children, arms `structure.ChildAdded` for late-arriving bays, then relabels
- `watchFolder(folder)` — no-ops if `folder == currentFolder`; otherwise disconnects the old
  folder watch, arms `folder.ChildAdded` for a future `Structure`, and immediately binds an
  already-present `Structure` (covers the event-before-replication and event-after-replication
  orderings symmetrically)
- `BackDoorState.OnClientEvent` — sets `activeIndex`, resolves the site folder via
  `WaitForChild`, calls `watchFolder`, then unconditionally `relabel()`

### Lifecycle cases covered

1. **Join** — `BackDoorState` fires with the freshly claimed `padId`. The site folder is
   `WaitForChild`'d (bounded 15s, survives the async-replication startup race). `watchFolder`
   arms the folder watch and finds the `Structure` already present (join-time build already
   happened server-side by the time the event lands) → `bindStructure` binds it immediately.

2. **Mid-session acquisition** (buy-to-claim after already playing) — same path as join: new
   `padId`, folder resolved, `Structure` present, bound immediately.

3. **Rebuild with event arriving early** (event fires before the new `Structure` replicates) —
   `watchFolder` is called on the SAME folder (`folder == currentFolder`, no-op there), but the
   folder-level `folderConn` (armed on first bind, never torn down across same-folder rebuilds)
   is still connected and fires `bindStructure(newStructure)` the moment the new `Structure`
   child actually appears — independent of when the event arrived. `bindStructure` sees
   `structure ~= currentStructure`, drops the dead prompt cache, rebinds.

4. **Rebuild with event arriving late** (structure already replicated by the time the event
   lands) — `OnClientEvent`'s `watchFolder` call finds `folder == currentFolder` (no reconnect
   needed) but by then `folderConn`'s `ChildAdded` handler has ALREADY fired and rebound
   `bindStructure` to the new structure before the event even arrived. Either way the structure
   ends up bound; the event's only remaining job is refreshing `activeIndex`, done via the
   trailing unconditional `relabel()`.

5. **Bare-deck rebuild** (display set to "none", no `Structure` child produced) — `watchFolder`'s
   `folderConn` stays armed on the (unchanged) folder; no `Structure` child ever fires it, so
   `currentStructure`/`prompts` are simply left stale-but-inert (their prompts died with the
   destroyed structure and can no longer be triggered). When the teahouse is later restored,
   the display-restore rebuild both re-fires `BackDoorState` (refreshing `activeIndex`) and drops
   a new `Structure` child, which `folderConn` catches and binds normally.

6. **Pad change** (re-claim a different pad) — arrives as a new `padId` → a different
   `MaterializedSite_<padId>` folder → `watchFolder` sees `folder ~= currentFolder`, tears down
   the old `folderConn`, arms a new one on the new folder, and binds its `Structure` (existing or
   future).

7. **Plain edit echo** (`SetBackDoor` round-trip on the same live structure, no rebuild) — same
   `padId` → same folder → `watchFolder` no-ops (folder unchanged) → `bindStructure` is never
   re-invoked (nothing added/changed at the folder or structure level) → `OnClientEvent`'s
   trailing `relabel()` alone updates prompt enabled/label state from the new `activeIndex`,
   using the still-valid `prompts` cache. No duplicate prompts, no duplicate connections.

### Verification

```
$ cd roblox && lune run tests/run
407 passed, 0 failed, 407 total

$ cd roblox && stylua --check src tests
(clean, exit 0)

$ cd roblox && selene src
Results:
0 errors
0 warnings
0 parse errors
```

Neither changed file is covered by the Lune harness (client controller isn't Luau-runnable
outside Roblox; the server file is the composition root) — the 407-test pass is the existing
regression net for everything else in the tree, confirming no collateral breakage.

### Commit

One commit, both files:
`fix(roblox): back-door prompts bind on geometry arrival; door edits update the economy stash (B3 gate)`
