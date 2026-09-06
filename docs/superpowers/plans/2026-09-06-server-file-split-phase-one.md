# Server File Split — Phase One Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Free ~60 of the 199 top-level local registers in `roblox/src/server/main.server.luau` by moving four self-contained regions into modules — the remotes table, the shoji slide controller, the stats-room feed, the teahouse rebuild — with zero behaviour change, one commit and one owner Studio walk per extraction.

**Architecture:** Each extraction is a *move*, not a rewrite: the code that leaves `main.server.luau` reappears in a module verbatim, with the top-level state it read handed in by injection. Two module kinds per the spec: pure modules (no Roblox globals, Lune specs) and runtime adapters (`StructureOps`-style; may use `Instance.new`/`workspace`/`CollectionService`; proven by the gate). Shared mutable tables that several sections touch (`playerEconomy`, `playerHouse`, `handlerQueue`) do NOT move; modules receive them or accessor closures. Because the owner's gate is a Rojo-served Play on `main`, each extraction is merged to `main` (fast-forward) before its walk, and the next extraction starts only after the walk passes.

**Tech Stack:** Luau under Lune (bespoke harness `roblox/tests/harness.luau`), `stylua`, `selene`, Rojo (`default.project.json` maps `src/server` as a directory, so a new file there is a new ModuleScript automatically).

**Spec:** `docs/superpowers/specs/2026-09-06-server-file-split-design.md` — §2 (rules), §4 (the four extractions and their gate walks), §5 (sequencing). Line numbers below are as of `main` at `c61c0e5` (the recon commit); the file has not changed since, but **re-grep every anchor before editing** — the plan names functions, and the functions are the truth.

## Global Constraints

- **Behaviour-preserving, provably.** Same remotes, same payload fields, same order of `PlayerAdded`/`PlayerRemoving` connections, the catch-up sweep after every `PlayerAdded` connect stays, same `WaitForChild` semantics (bare at the top of the file; the three timed fetches inside `Launch` are untouched), same `task.spawn`/`task.wait` cadences. Moved code is copied verbatim except for the injection plumbing.
- **The require convention** (`roblox/tests/RequireConvention.spec.luau`): `main.server.luau` requires a `src/server` module by relative string (`require("./Remotes")` — copy the exact form the file uses for `HandlerQueue` at ~L48); a module under `src/server` reaches `src/shared` via `ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("X")` exactly as `StructureOps.luau:10` does, never by a relative string.
- **Register accounting after every task:** `grep -c '^local ' roblox/src/server/main.server.luau` (the count was 198 at `c61c0e5`; one of those declares two names). Record before/after in the task report. `tests/Compiles.spec.luau` must pass — it is the only guard.
- **Gates before every commit:** `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run 2>&1 | tail -3`. New pure functions get Lune specs in the same commit.
- **One extraction = one task = one commit = one merge = one owner walk.** After the task review passes, the controller fast-forwards `main` (fetch first; the terminal session owns the place, so announce), the owner walks the named feature in Play, and only a passed walk starts the next task. A failed walk is fixed forward on the branch, never reverted, unless the fault is structural.
- **No other server-side change rides along.** Not the melt verb, not C's handlers, not phase-two candidates. Concurrent branch `thread/powder` touches no Luau server file; nothing else is in flight on `main.server.luau`.
- Commit style `type(scope): summary`; trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` after a blank line. Worktree `.worktrees/split`, branch `thread/split`. Stage only the files each task names. `git fetch` before every push; never rebase or reset on a dirty tree.

---

## File map

| file | responsibility |
|---|---|
| `roblox/src/server/Remotes.luau` (new) | `Remotes.NAMES`, `Remotes.bind(folder)` — the 37 handles as one table |
| `roblox/tests/Remotes.spec.luau` (new) | `NAMES` ⊆ `default.project.json`'s `RoshamboRemotes`, and covers every name the server uses |
| `roblox/src/server/ShojiSlideController.luau` (new) | slide/persist state + machinery; `SlideShoji` handler body |
| `roblox/src/shared/ShojiSlideMath.luau` (new, pure) | `slideKey`, `collectRun` (given a bay-lister), `withinReach` (given positions) — the Lune-testable core |
| `roblox/tests/ShojiSlideMath.spec.luau` (new) | specs |
| `roblox/src/server/StatsFeed.luau` (new) | pollers, personal push, join hook; owns `lastStats`/`lastTape` |
| `roblox/src/shared/StatsFilters.luau` (new, pure) | `filterTop/filterRecords/filterBoard/filterHeat` given a name filter |
| `roblox/tests/StatsFilters.spec.luau` (new) | specs |
| `roblox/src/server/PadRender.luau` (new) | `rebuild(uid)`, `deckCFFor(uid)`, `buildTreatment(uid, e, built)` — the one resolve-and-apply |
| `roblox/tests/PadRender.spec.luau` (new) | `buildTreatment` and the pure `resolve` step |
| `roblox/src/server/main.server.luau` | shrinks by each move |
| `docs/wiki/practice/server-modules.md` (new), `docs/wiki/systems/rojo-and-place.md`, `CLAUDE.md`, `docs/wiki/log.md` | the pure/adapter rule, the register ceiling, gate entries |

---

### Task 1: `Remotes` — the 37 handles as one table

**Files:**
- Create: `roblox/src/server/Remotes.luau`
- Create: `roblox/tests/Remotes.spec.luau`
- Modify: `roblox/src/server/main.server.luau` (~L74–112 declarations; every use site)

**Interfaces:**
- Produces: `Remotes.NAMES: { string }` (the 37 names, in the file's current declaration order); `Remotes.bind(folder: Instance): { [string]: RemoteEvent }` — `WaitForChild`s each name (bare, as today) and returns the table. In `main.server.luau`: `local R = Remotes.bind(remotes)`; every former `SubmitPick` becomes `R.SubmitPick`.

- [ ] **Step 1: Write the failing spec**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Remotes = require("../src/server/Remotes")

-- The RemoteEvents contract is default.project.json's RoshamboRemotes block. Every name the server
-- binds must exist there, or the server would hang at boot on a WaitForChild that never resolves.
local project = serde.decode("json", fs.readFile("default.project.json"))
local function findRemotesBlock(node: any): any?
    if type(node) ~= "table" then
        return nil
    end
    if node.RoshamboRemotes ~= nil then
        return node.RoshamboRemotes
    end
    for _, child in node do
        local found = findRemotesBlock(child)
        if found then
            return found
        end
    end
    return nil
end
local contract = findRemotesBlock(project)

describe("Remotes -- the names are the contract", function()
    test("the project declares a RoshamboRemotes block", function()
        expect(contract).toBeTruthy()
    end)
    test("every bound name is declared in the contract as a RemoteEvent", function()
        for _, name in Remotes.NAMES do
            local decl = contract[name]
            expect(decl).toBeTruthy()
            expect(decl["$className"]).toBe("RemoteEvent")
        end
    end)
    test("no name is bound twice", function()
        local seen = {}
        for _, name in Remotes.NAMES do
            expect(seen[name]).toBeNil()
            seen[name] = true
        end
    end)
    test("bind returns one handle per name, from the folder given", function()
        local asked = {}
        local folder = {
            WaitForChild = function(_self, name: string)
                table.insert(asked, name)
                return { Name = name }
            end,
        }
        local R = Remotes.bind(folder :: any)
        expect(#asked).toBe(#Remotes.NAMES)
        for _, name in Remotes.NAMES do
            expect(R[name].Name).toBe(name)
        end
    end)
end)
```

`default.project.json` lives at `roblox/` root, which is the Lune working directory (the fixtures reader relies on the same assumption).

- [ ] **Step 2: Run to verify it fails** — `cd roblox && lune run tests/run 2>&1 | tail -3` → missing module.

- [ ] **Step 3: Write the module**

Take the 37 names from `main.server.luau` L75–L111 in order (each line is `local <Name> = remotes:WaitForChild("<Name>") :: RemoteEvent`; the local and the string are identical for all 37 — verified). Note `TextService` at L112 is a service, not a remote; leave it.

```lua
--!strict
-- THE 37 REMOTE HANDLES AS ONE TABLE. Extracted 2026-09-06 (server-file split, phase one, 4.1):
-- each handle used to be a top-level local in main.server.luau, and that file sits at Luau's
-- 200-register ceiling. Binding is unchanged -- a bare WaitForChild per name, at boot, in this
-- order -- so a missing remote still fails loudly at start rather than silently later.
--
-- Runtime adapter: it yields on WaitForChild, so it has no Lune spec of its own; tests/Remotes.spec
-- asserts NAMES against default.project.json's RoshamboRemotes block instead. The three TIMED
-- fetches inside main.server.luau's Launch table (RequestShowGo, RequestProvingShow, the
-- FireworkShows module) are deliberately NOT here: their timeouts are documented in place.
local Remotes = {}

Remotes.NAMES = {
    -- paste the 37 names here, in the order they appear at main.server.luau L75-L111
}

function Remotes.bind(folder: Instance): { [string]: RemoteEvent }
    local out: { [string]: RemoteEvent } = {}
    for _, name in Remotes.NAMES do
        out[name] = folder:WaitForChild(name) :: RemoteEvent
    end
    return out
end

return Remotes
```

- [ ] **Step 4: Rewrite `main.server.luau`**

Replace L75–L111 with `local R = Remotes.bind(remotes)` (keep L74 `local remotes = …`), add `local Remotes = require("./Remotes")` beside the other `src/server` requires (~L48–52, same relative form), then rewrite every use. Mechanical rule: for each of the 37 names `N`, replace whole-word `N` with `R.N` **only where it refers to the remote** — i.e. `N:FireAllClients`, `N:FireClient`, `N.OnServerEvent`, and bare passes of `N` as an argument. Do it name by name with a word-boundary search and read each hit; `StatsData`, `BoardData`, `ProfileUpdate` etc. also appear inside strings and comments, which must not change. Expect ~90 edits.

- [ ] **Step 5: Gates and register count**

`cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run 2>&1 | tail -3`, then `grep -c '^local ' src/server/main.server.luau` — expected 198 → 162 (−37 handles, +1 for `R`, `Remotes` require +1 = net −36; report the actual).

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/Remotes.luau roblox/tests/Remotes.spec.luau roblox/src/server/main.server.luau
git commit -m "refactor(server): Remotes -- the 37 remote handles become one bound table; 36 top-level registers freed

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 7: GATE 1 (controller + owner).** After the task review: fast-forward `main`, push, confirm CI. Owner walk: join, throw once, bank, open the ledger, slide a shoji, buy a firecracker at the Hanabiya, launch it from the deck. Output shows the normal boot lines and no `WaitForChild` warning. Record the gate on `docs/wiki/log.md` (kind `gate`). **Task 2 does not start until this passes.**

---

### Task 2: `ShojiSlideController` — the slide machinery and its state

**Files:**
- Create: `roblox/src/shared/ShojiSlideMath.luau` (pure)
- Create: `roblox/tests/ShojiSlideMath.spec.luau`
- Create: `roblox/src/server/ShojiSlideController.luau` (adapter)
- Modify: `roblox/src/server/main.server.luau` (state ~L1078–1112, `flushShojiForUid` ~L1230–1305 and `persistShojiNow` just above it, slide section ~L2597–2864, `PlayerRemoving` #2 ~L2457–2484)

**Interfaces:**
- `ShojiSlideMath.slideKey(uid, padId, side, index): string` — verbatim `shojiSlideKey`.
- `ShojiSlideMath.collectRun(bays: { { bayIndex: number, bay: any } })`: the ordering/validation half of `collectShojiRun` once the instance walk is done by the caller (read `collectShojiRun` L2621–2641 and split it: the part that lists children with the `ShojiBay`/side attributes stays in the adapter; the part that sorts and shapes the result moves here).
- `ShojiSlideMath.withinReach(playerPos: {x,y,z}, bayPos: {x,y,z}, reach: number): boolean` — the arithmetic of `withinShojiReach` (L2648–2657) on plain tables.
- `ShojiSlideController.new(deps)` where `deps = { players, sitesFolder, StructureOps, ShojiRun, net, handlerQueue, getHouse: (uid) -> house?, getEconomy: (uid) -> e?, fireShojiState: (player, payload) -> (), task = task, workspace = workspace }`; methods `:onSlideRequest(player, payload)` (the `SlideShoji` handler body, L2750–2864), `:onLeave(uid)` (the fold-in-flight-slide block from `PlayerRemoving` #2 L2459–2473 PLUS `flushShojiForUid(uid)`), `:flushForUid(uid)`, `:pendingCount()` (for a future test hook; returns `#shojiPendingPersist` keys).
- The controller owns `shojiSlides`, `shojiPersistGen`, `shojiPendingPersist`, `SLIDE_RATE`, `SHOJI_REACH`, `SHOJI_PERSIST_QUIET`, `scheduleShojiPersist`, `runShojiSlide`, `persistShojiNow`, `flushShojiForUid`, `shojiReachPosition`, `collectShojiRun`. The `ShojiSlide`/`ShojiPersistTarget` types move with it.

- [ ] **Step 1: Failing specs for the pure math**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local M = require("../src/shared/ShojiSlideMath")

describe("ShojiSlideMath.slideKey", function()
    test("is uid, pad, side, index joined by \\1 -- unique per bay per player", function()
        expect(M.slideKey("77", "T01", "front", 2)).toBe("77\1T01\1front\12")
        expect(M.slideKey("77", "T01", "front", 2) == M.slideKey("77", "T01", "front", 3)).toBe(false)
    end)
end)

describe("ShojiSlideMath.collectRun", function()
    test("orders bays by index and returns the same shape collectShojiRun did", function()
        local run = M.collectRun({ { bayIndex = 3, bay = "c" }, { bayIndex = 1, bay = "a" }, { bayIndex = 2, bay = "b" } })
        expect(#run).toBe(3)
        expect(run[1].bayIndex).toBe(1)
        expect(run[3].bay).toBe("c")
    end)
    test("an empty list is an empty run", function()
        expect(#M.collectRun({})).toBe(0)
    end)
end)

describe("ShojiSlideMath.withinReach", function()
    test("horizontal distance only, inclusive at the reach", function()
        expect(M.withinReach({ x = 0, y = 0, z = 0 }, { x = 3, y = 40, z = 4 }, 5)).toBe(true)
        expect(M.withinReach({ x = 0, y = 0, z = 0 }, { x = 3, y = 0, z = 4.01 }, 5)).toBe(false)
    end)
end)
```

⚠ Before writing these, READ `collectShojiRun` and `withinShojiReach` in the file: if `withinShojiReach` measures full 3-D distance rather than horizontal, or `collectShojiRun` does more than sort, the spec must assert the behaviour the code actually has — the move is verbatim, the spec documents it. Adjust the expectations to the real semantics and say so in the report.

- [ ] **Step 2: Run to verify it fails; write `ShojiSlideMath.luau`** (pure, `--!strict`, no Roblox globals) so the specs pass. Gates.

- [ ] **Step 3: Write the controller**

`roblox/src/server/ShojiSlideController.luau`: a table with `.new(deps)` returning an object whose methods are the moved functions, bodies verbatim, with these substitutions only: `playerHouse[uid]` → `deps.getHouse(uid)` (and the one write `house.loadout = newLoadout` mutates the returned table, which is the same table — verify the file mutates in place at L1275 rather than reassigning `playerHouse[uid]`); `playerEconomy[uid]` → `deps.getEconomy(uid)`; `ShojiState:FireClient` → `deps.fireShojiState`; `net`/`handlerQueue`/`StructureOps`/`ShojiRun`/`sitesFolder`/`Players`/`workspace`/`task` → `deps.*`. `shojiSlideKey`/`collectShojiRun`'s sort/`withinShojiReach`'s arithmetic call into `ShojiSlideMath` (required via `ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("ShojiSlideMath")`, the `StructureOps.luau:10` form).

- [ ] **Step 4: Rewire `main.server.luau`**

Delete the moved declarations and functions; add `local ShojiSlideController = require("./ShojiSlideController")` beside the server requires and, after `sitesFolder`/`applier` exist (~L1985) and after `playerHouse`/`playerEconomy`/`handlerQueue`/`net` exist, `local shoji = ShojiSlideController.new({ … })`. Replace `SlideShoji.OnServerEvent:Connect(function(player, payload) … end)` with `R.SlideShoji.OnServerEvent:Connect(function(player, payload) shoji:onSlideRequest(player, payload) end)`. In `PlayerRemoving` #2 replace L2459–2473 and the `flushShojiForUid(uid)` call with `shoji:onLeave(uid)` **at the same position in the sequence** (before `playerHouse[uid] = nil`). ⚠ `handlerQueue:clear(uid)` sits between the fold and the flush today; preserve that by having `onLeave` take a `clearQueue` step? No — keep `handlerQueue:clear(uid)` in `main.server.luau` between two calls: `shoji:foldActive(uid)`, `handlerQueue:clear(uid)`, `shoji:flushForUid(uid)`. Export both methods rather than one `onLeave` so the order in the file stays exactly as documented at L1222–1239.

- [ ] **Step 5: Gates, register count** (expect ≈ −12), **commit**

```bash
git add roblox/src/shared/ShojiSlideMath.luau roblox/tests/ShojiSlideMath.spec.luau roblox/src/server/ShojiSlideController.luau roblox/src/server/main.server.luau
git commit -m "refactor(server): ShojiSlideController -- slide/persist state and machinery move out; the leave sequence keeps its documented order; pure math specced

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: GATE 2.** Merge, push, CI. Owner walk: as owner, slide a shoji on your teahouse, leave the deck, come back — it stayed; a second account slides it — visible to both, does not persist across their leave; start a slide and disconnect mid-hold — no error, the pad rebuilds clean on rejoin. Log the gate.

---

### Task 3: `StatsFeed` — pollers and personal push

**Files:**
- Create: `roblox/src/shared/StatsFilters.luau` (pure)
- Create: `roblox/tests/StatsFilters.spec.luau`
- Create: `roblox/src/server/StatsFeed.luau` (adapter)
- Modify: `roblox/src/server/main.server.luau` (~L381–389 `lastTape`/`lastTapeId`/`lastStats`, ~L886–1036, the reveal callback that reads `lastStats` ~L437–439 and writes `lastTape`)

**Interfaces:**
- `StatsFilters.new(filterName: (string) -> string)` → `{ top, records, board, heat }` — the four functions verbatim (`filterTop` uses `STATS_BOARD_ROWS = 10` and the injected `filterName` in place of `cachedFilterName`).
- `StatsFeed.new(deps)` where `deps = { net, filters (from StatsFilters.new), fireAll: (payload) -> (), fireTo: (player, payload) -> (), players, task, getRosterEntry: (uid) -> table, setRosterEntry: (uid, entry) -> (), pushRoster: () -> () }`; methods `:start()` (the 47 s poller and the 60 s personal loop, verbatim cadences), `:onJoin(player)`, `:pushPersonal(player)`, `:current(): any?` (returns `lastStats`), `:setTape(tape, id)` (called by the reveal callback where it writes `lastTape`/`lastTapeId` today), `:tape()`.
- `nameFilterCache`/`cachedFilterName` move into the feed (they exist only for it).

- [ ] **Step 1: Failing specs for the filters**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local StatsFilters = require("../src/shared/StatsFilters")

local upper = function(s: string): string
    return string.upper(s)
end
local F = StatsFilters.new(upper)

describe("StatsFilters.top", function()
    test("filters displayName on the first 10 rows only, copying those rows, passing the rest through", function()
        local rows = {}
        for i = 1, 12 do
            table.insert(rows, { displayName = `p{i}`, points = i })
        end
        local out = F.top(rows)
        expect(#out).toBe(12)
        expect(out[1].displayName).toBe("P1")
        expect(out[10].displayName).toBe("P10")
        expect(out[11].displayName).toBe("p11")
        expect(rows[1].displayName).toBe("p1") -- input untouched
    end)
    test("a missing name filters as ?", function()
        expect(F.top({ {} })[1].displayName).toBe("?")
    end)
    test("nil is an empty list", function()
        expect(#F.top(nil)).toBe(0)
    end)
end)

describe("records / board / heat", function()
    test("records filters its three lists and nothing else", function()
        local r = F.records({ longestStreaks = { { displayName = "a" } }, biggestBanks = {}, biggestRounds = {}, other = 1 })
        expect(r.longestStreaks[1].displayName).toBe("A")
        expect(r.other).toBe(1)
    end)
    test("board filters rows; heat filters leaders; nil passes through", function()
        expect(F.board({ rows = { { displayName = "b" } } }).rows[1].displayName).toBe("B")
        expect(F.heat({ leaders = { { displayName = "c" } } }).leaders[1].displayName).toBe("C")
        expect(F.board(nil)).toBeNil()
        expect(F.heat(nil)).toBeNil()
        expect(F.records(nil)).toBeNil()
    end)
end)
```

- [ ] **Step 2: Run to verify it fails; write `StatsFilters.luau`** (verbatim bodies of the four filters from L910–L960, `STATS_BOARD_ROWS = 10` inside). Gates.

- [ ] **Step 3: Write `StatsFeed.luau`**, moving L886–L1036 with substitutions: `net` → `deps.net`; `StatsData:FireAllClients(x)` → `deps.fireAll(x)`; `StatsData:FireClient(p, x)`/`StatsPersonal:FireClient(p, x)` → `deps.fireTo(p, x)` and `deps.firePersonal(p, x)` (two different remotes — add `firePersonal` to deps); `familiarRoster[uid]` read/write → `deps.getRosterEntry(uid)` / `deps.setRosterEntry(uid, entry)`; `pushFamiliarRoster()` → `deps.pushRoster()`; `Players` → `deps.players`; `task` → `deps.task`; `lastStats`/`lastTape` become fields. The `PlayerAdded` connect + catch-up sweep and the two `task.spawn` loops go inside `:start()`, in the same order they run today.

- [ ] **Step 4: Rewire `main.server.luau`**: delete the moved region and the `lastTape`/`lastTapeId`/`lastStats` locals; `local StatsFeed = require("./StatsFeed")` beside the server requires; construct `stats` after `net`, `familiarRoster`, `pushFamiliarRoster`, `filterExternalName` exist (they are all above L886) and call `stats:start()` where the old region ran; in the reveal callback replace the `lastTape = …`/`lastTapeId = …` writes with `stats:setTape(...)`, the `lastStats` re-broadcast with `stats:current()`, and any other `lastTape` reader (the board poller ~L850 reads `lastTape[1]`) with `stats:tape()`.

- [ ] **Step 5: Gates, register count** (expect ≈ −10), **commit**

```bash
git add roblox/src/shared/StatsFilters.luau roblox/tests/StatsFilters.spec.luau roblox/src/server/StatsFeed.luau roblox/src/server/main.server.luau
git commit -m "refactor(server): StatsFeed -- the stats-room pollers and personal push move out; the four name filters are pure and specced

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: GATE 3.** Merge, push, CI. Owner walk: enter the stats cavern — boards populate within a minute; bank once — the personal slip updates within the next minute; the board display at the arena still shows the tape and the hot streak. Log the gate.

---

### Task 4: `PadRender` — one resolve-and-apply

**Files:**
- Create: `roblox/src/server/PadRender.luau` (adapter with a pure core)
- Create: `roblox/tests/PadRender.spec.luau`
- Modify: `roblox/src/server/main.server.luau` (`rebuildClaimedPad`/`deckCFForUid` L2046–2115; the forward declarations L400–L412; the duplicated sites at ~L3017–3054 (purchase: upgrade), ~L3097–3134 (`SetDisplay`), ~L3175–3249 (`SetPlacement`/decoration/mortar), and any other site that builds a `treatment` table itself — `grep -n 'kind = "structure"'` finds them all)

**Interfaces:**
- `PadRender.resolve(e, spec, centered): { built, teahouse, treatment }?` — PURE: the `SizeClasses.resolveBuilt` → `teaLoadout` → `teahouse` → `treatment` construction from `rebuildClaimedPad` L2055–L2084 as a function of `e` (economy state), `spec` (the pad), `centered` (`CENTERED_PLACEMENT`), and `Kamon.forUserId(uid)` (pass `crest` in, computed by the caller, to keep it pure). Returns nil where the original returned early.
- `PadRender.new(deps)` with `deps = { applier, PadSites, getEconomy, setHouse: (uid, house?) -> (), crestFor: (uid) -> any, centered }`; methods `:rebuild(uid)` (verbatim `rebuildClaimedPad` using `resolve`), `:deckCFFor(uid)` (verbatim `deckCFForUid`), `:apply(uid, e, spec, resolved)` (the `applier:apply` + `playerHouse` sync tail, so the duplicated sites can call `resolve` then `apply`).

- [ ] **Step 1: Failing spec for the pure core**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local PadRender = require("../src/server/PadRender")

-- A minimal economy state and pad spec. Sizes follow SizeClasses (S/M/L); the point of the test is
-- that resolve() reproduces rebuildClaimedPad's treatment shape field for field.
local spec = { maxSize = "L", deckPlacements = {} }
local centered = { offset = { 0, 0 }, facing = "N" }

describe("PadRender.resolve", function()
    test("a built teahouse yields teahouse + treatment carrying the economy's decorations and mortars", function()
        local e = {
            maxDeckSize = "L",
            teahouses = { L = { placement = { offset = { 1, 2 }, facing = "E" } } },
            deckDisplay = "L",
            teahouseDisplay = "L",
            portalOwned = true,
            deckDecorations = { "d1" },
            mortarPlacements = { ["mortar:S"] = { offset = { 0, 0 }, mount = "floor", aim = "C" } },
            mortars = { "mortar:S" },
        }
        local r = PadRender.resolve(e, spec, centered, "CREST")
        expect(r).toBeTruthy()
        assert(r)
        expect(r.built.teahouseSize).toBe("L")
        expect(r.teahouse.size).toBe("L")
        expect(r.teahouse.placement.facing).toBe("E")
        expect(r.treatment.kind).toBe("structure")
        expect(r.treatment.crest).toBe("CREST")
        expect(r.treatment.portalOwned).toBe(true)
        expect(r.treatment.mortars[1]).toBe("mortar:S")
        expect(r.treatment.deckDecorations[1]).toBe("d1")
    end)
    test("no teahouse: teahouse is nil, placement defaults to centered, treatment still built", function()
        local e = { maxDeckSize = "M", teahouses = {}, deckDisplay = "M", teahouseDisplay = "none", portalOwned = false, deckDecorations = {}, mortarPlacements = {}, mortars = {} }
        local r = PadRender.resolve(e, spec, centered, nil)
        expect(r).toBeTruthy()
        assert(r)
        expect(r.teahouse).toBeNil()
        expect(r.treatment.kind).toBe("structure")
    end)
    test("nothing built resolves to nil", function()
        local e = { maxDeckSize = nil, teahouses = {}, deckDisplay = nil, teahouseDisplay = nil, deckDecorations = {}, mortarPlacements = {}, mortars = {} }
        expect(PadRender.resolve(e, spec, centered, nil)).toBeNil()
    end)
end)
```

⚠ `SizeClasses.resolveBuilt`'s exact nil conditions decide the third case; read `roblox/src/shared/SizeClasses.luau` and choose inputs that genuinely return nil (e.g. no deck size). `PadRender.luau` requires `SizeClasses`/`DeckPlacement` through `ReplicatedStorage:WaitForChild("RoshamboShared")` at runtime; for Lune, the module must obtain them by injection or by a Lune-safe path. Use the pattern the file's other Lune-tested server modules use (`RoundCoordinator.luau` takes its shared modules in `new(deps)`); make `resolve` a function of injected `sizeClasses`/`deckPlacement` if a Lune-safe require is not available, and construct it in the spec with the real shared modules via relative requires (`require("../src/shared/SizeClasses")` — legal from tests).

- [ ] **Step 2: Run to verify it fails; write `PadRender.luau`; gates.**

- [ ] **Step 3: Rewire `main.server.luau`**: delete `rebuildClaimedPad`/`deckCFForUid` and the two forward declarations `rebuildClaimedPadFn`/`deckCFForUidFn` (L400–L412 region); replace their call sites (`rebuildClaimedPadFn(uid)` → `padRender:rebuild(uid)`, `deckCFForUidFn(uid)` → `padRender:deckCFFor(uid)`; the callers guard with `if fn then` today — the guards go, the calls stay). Construct `padRender` right after `applier` (~L1988), which is before every caller runs. Then, one by one, replace each duplicated resolve-and-apply block with `local r = PadRender.resolve(e, spec, CENTERED_PLACEMENT, Kamon.forUserId(uid)); if r then padRender:apply(uid, e, spec, r) end` — reading each block first: two of them set `playerHouse[uid]` with a comment about bare decks; `apply` must reproduce exactly that (`setHouse(uid, nil)` when no teahouse). If a block differs from the canonical sequence in any field, DO NOT unify it — leave it and say so in the report.

- [ ] **Step 4: Gates, register count** (expect ≈ −2, and ~200 fewer lines), **commit**

```bash
git add roblox/src/server/PadRender.luau roblox/tests/PadRender.spec.luau roblox/src/server/main.server.luau
git commit -m "refactor(server): PadRender -- one resolve-and-apply replaces the copy-pasted rebuild; two forward declarations gone

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 5: GATE 4.** Merge, push, CI. Owner walk, all five triggers: join (pad claims and builds), buy a teahouse upgrade, change the display size, move a decoration, place a mortar — the pad rebuilds correctly after each, and a firework launches muzzle-true from the placed mortar afterward (that exercises `deckCFFor`). Log the gate.

---

### Task 5: Docs — the rule the codebase already follows, and the headroom

**Files:**
- Create: `docs/wiki/practice/server-modules.md`
- Modify: `docs/wiki/systems/rojo-and-place.md` (one pointer), `CLAUDE.md` (the "Roblox client" paragraph's module rule), `docs/wiki/log.md` (ship entry), `docs/wiki/index.md` (practice shelf line)

- [ ] **Step 1: `docs/wiki/practice/server-modules.md`**

```markdown
---
shelf: practice
updated: 2026-09-XX
---

# Server modules: pure or adapter, and the register ceiling

**The ceiling.** Luau allows 200 local registers per scope. `roblox/src/server/main.server.luau`
reached 199 top-level names on 2026-09-05; `tests/Compiles.spec.luau` is the only guard and it
turns red on name 201 with no warning before. Re-measure: `grep -c '^local ' roblox/src/server/main.server.luau`
(one declaration carries two names). Phase one of the split (`docs/superpowers/specs/2026-09-06-server-file-split-design.md`)
moved the remotes table, the shoji slide controller, the stats feed and the pad render out; record
the count after each further change here rather than trusting this line.

**Two kinds of module — the distinction the code already practises:**

- **Pure** — no Roblox globals; services and side effects injected; runs under Lune; has a spec in
  `roblox/tests/`. Lives in `src/shared/` (or `src/server/` when it is server-only but still pure,
  like `HandlerQueue`, `NetworkClient`, `RoundCoordinator`, `ThrowBuffer`).
- **Adapter** — lives in `src/server/`; may use `Instance.new`, `workspace`, `CollectionService`,
  `game:GetService` (`StructureOps`, `PadOps`, `TreatmentApplier`, `PortalController`, `Remotes`,
  `ShojiSlideController`, `StatsFeed`, `PadRender`); has NO Lune spec; is proven by the owner's
  Studio gate. Keep its pure core in a sibling pure module with a spec (`ShojiSlideMath`,
  `StatsFilters`, `PadRender.resolve`).

`CLAUDE.md` used to state the rule as "no `game:GetService` in modules"; that was true of pure
modules only. **The require convention still binds both kinds** (`tests/RequireConvention.spec.luau`):
a relative string never crosses `src/server` ↔ `src/shared`.

**Extraction rules that held (phase one):** verbatim moves; shared mutable tables injected, never
moved; `PlayerAdded` connect + catch-up sweep preserved; the leave sequence's documented order
preserved by exporting two calls rather than one; one commit, one merge, one Studio walk per move.
```

- [ ] **Step 2: `CLAUDE.md`** — in "### Roblox client", replace "Luau modules take their **Roblox services and side effects by dependency injection** — no `game:GetService`, no globals — so the same files run under Lune (tests) and Roblox (runtime)." with a sentence that says pure modules do, adapters may touch services and are Studio-gated, and points at `docs/wiki/practice/server-modules.md`. Leave the rest of the paragraph.

- [ ] **Step 3: `docs/wiki/index.md`** — add the practice line; `rojo-and-place.md` — one sentence under its Rojo-ownership section that `src/server/` new files are ModuleScripts automatically and the split's modules live there.

- [ ] **Step 4: `docs/wiki/log.md`** — one `ship` entry summarising phase one with the four gate dates and the before/after register counts (the four `gate` entries were written as each walk passed).

- [ ] **Step 5: Lint, commit, merge, push.** `node tools/wiki/lint.mjs | tail -1` (count must not rise). Commit the five files; fast-forward `main`; push; confirm CI. STOP: phase two is a new spec.

---

## Self-review against the spec

- §2 rules: verbatim moves (every task), require convention (Task 1 form; adapters use the `StructureOps` form for shared), pure/adapter split named per task with specs for the pure parts (Tasks 2–4), shared state injected not moved (Tasks 2–4 deps), forward declarations removed (Task 4 removes two), gates before every commit, owner walk per extraction (Steps 7/6/6/5). ✔
- §4.1–4.4: each extraction's interface, state, exports and gate walk appear as written; 4.1's contract test against `default.project.json` is Task 1's spec. ✔
- §5 sequencing: merge-before-walk, next task after the walk, fix-forward. ✔ (encoded in each GATE step)
- §9: the pure/adapter rule reaches the wiki and `CLAUDE.md` in Task 5. ✔
- Type consistency: `R` is the remotes table everywhere after Task 1; `shoji:foldActive`/`flushForUid` (Task 2) are the two calls the leave sequence needs; `stats:setTape/current/tape` (Task 3) match the three read/write sites named; `PadRender.resolve` + `padRender:apply/rebuild/deckCFFor` (Task 4) match every call site named.
- Honest gaps: the plan gives line anchors from `c61c0e5` and names functions; implementers must re-grep. Task 4's "if a block differs, do not unify it" is the safety valve for the five sites being less identical than the recon suggested.
