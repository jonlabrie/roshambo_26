# Per-UID Handler Serialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serialize a single player's mutating server handlers through a per-uid FIFO queue so they never interleave across their mid-body HTTP yield, retiring the whole race family (and the raced-PUT DB residual) at once.

**Architecture:** A new pure `HandlerQueue` module (thread-spawn primitive injected, so it's Lune-testable) maintains one FIFO lane per uid; each of the six mutating handlers wraps its existing body in a thunk passed to `queue:run(uid, thunk)`. One worker drains a lane sequentially — a thunk's HTTP yield suspends the worker, so the next thunk cannot start until it returns. Spec: `docs/superpowers/specs/2026-07-19-per-uid-handler-serialization-design.md`.

**Tech Stack:** Roblox Luau + Rojo, bespoke Lune harness (`roblox/`). No server (TypeScript) changes.

## Global Constraints

- **`MAX_PENDING = 8`**, drop-newest + warn on overflow (`run` returns `false`).
- **All six** mutating handlers wrapped: `SetBackDoor`, `SetDisplay`, `SetPlacement`, `RequestPurchase`, `SetPadPreference`, `BankRequest`. No others.
- **One worker per lane, looping sequentially** — never one spawn per thunk (that would defeat serialization).
- **Handler bodies move into the thunk verbatim** — keep their own `local uid = …` line and their synchronous validation guards; do not refactor them.
- **`BankRequest`** currently wraps its body in `task.spawn(function() … end)`; replace that `task.spawn` with `handlerQueue:run(…)` — do not double-spawn.
- **`clear(uid)`** is called from the economy `PlayerRemoving` handler; a mid-flight thunk still completes (its own post-yield `IsDescendantOf` guards make it a safe no-op).
- **Cheap no-op skips only on SetDisplay and SetPlacement** (idempotent-detectable); the other four get none.
- **Lune has no `warn` global** — the module falls back to `print` off-Roblox.
- Roblox tests: `cd roblox && lune run tests/run`. Lint: `cd roblox && stylua --check src tests && selene src`.

---

## File Structure

- `roblox/src/server/HandlerQueue.luau` (create) — the per-uid FIFO queue. One responsibility.
- `roblox/tests/HandlerQueue.spec.luau` (create) — Lune tests (auto-discovered by `tests/run.luau`).
- `roblox/src/server/main.server.luau` (modify) — require + instantiate the queue; wrap the six handlers; `clear` on PlayerRemoving; two no-op skips.

---

## Task 1: `HandlerQueue` module + Lune tests

**Files:**
- Create: `roblox/src/server/HandlerQueue.luau`
- Test: `roblox/tests/HandlerQueue.spec.luau`

**Interfaces:**
- Consumes: an injected `spawn: (() -> ()) -> ()` (production `task.spawn`; tests a fake).
- Produces:
  - `HandlerQueue.new(spawn: (() -> ()) -> ()): HandlerQueue`
  - `HandlerQueue.run(self, uid: string, thunk: () -> ()): boolean` — appends `thunk` to uid's lane and drains if idle; returns `false` (dropped) when the lane already has `MAX_PENDING` pending. Called `queue:run(uid, thunk)`.
  - `HandlerQueue.clear(self, uid: string)` — drops uid's not-yet-run pending thunks and retires the lane. Called `queue:clear(uid)`.
  - `HandlerQueue.MAX_PENDING` (= 8).

- [ ] **Step 1: Write the failing tests** (`roblox/tests/HandlerQueue.spec.luau`)

```lua
--!strict
local harness = require("./harness")
local HandlerQueue = require("../src/server/HandlerQueue")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- A fake spawn that runs the worker in a coroutine and records it, so a thunk can `coroutine.yield()`
-- mid-run (simulating an HTTP round-trip) and the test resumes it deterministically.
local function coScheduler()
    local threads: { thread } = {}
    local function spawn(fn: () -> ())
        local co = coroutine.create(fn)
        table.insert(threads, co)
        coroutine.resume(co)
    end
    return spawn, threads
end

-- A fake spawn that DEFERS the worker (never runs it) so `pending` accumulates for cap/clear tests.
local function deferScheduler()
    local workers: { () -> () } = {}
    local function spawn(fn: () -> ())
        table.insert(workers, fn)
    end
    return spawn, workers
end

describe("HandlerQueue", function()
    test("serializes a lane's thunks in FIFO order across a yield", function()
        local spawn, threads = coScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u", function()
            table.insert(log, "A-start")
            coroutine.yield() -- suspend mid-"HTTP"
            table.insert(log, "A-end")
        end)
        -- B is enqueued while A is suspended: it must NOT run yet, and must NOT spawn a 2nd worker
        q:run("u", function()
            table.insert(log, "B")
        end)
        expect(#log).toBe(1) -- only "A-start"
        expect(#threads).toBe(1) -- single worker for the lane
        coroutine.resume(threads[1]) -- A finishes, then B runs
        expect(log[1]).toBe("A-start")
        expect(log[2]).toBe("A-end")
        expect(log[3]).toBe("B")
    end)

    test("different uids run on independent lanes", function()
        local spawn = coScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u1", function()
            table.insert(log, "u1")
        end)
        q:run("u2", function()
            table.insert(log, "u2")
        end)
        expect(log).toEqual({ "u1", "u2" })
    end)

    test("drops the 9th concurrent request and returns false", function()
        local spawn = deferScheduler() -- workers deferred, so pending accumulates
        local q = HandlerQueue.new(spawn)
        local results: { boolean } = {}
        for i = 1, 9 do
            results[i] = q:run("u", function() end)
        end
        for i = 1, 8 do
            expect(results[i]).toBe(true)
        end
        expect(results[9]).toBe(false)
    end)

    test("an erroring thunk does not block its successors", function()
        local spawn, workers = deferScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u", function()
            error("boom")
        end)
        q:run("u", function()
            table.insert(log, "after")
        end)
        workers[1]() -- the single worker drains both
        expect(log).toEqual({ "after" })
    end)

    test("clear drops not-yet-run pending thunks", function()
        local spawn, workers = deferScheduler()
        local q = HandlerQueue.new(spawn)
        local log: { string } = {}
        q:run("u", function()
            table.insert(log, "A")
        end)
        q:run("u", function()
            table.insert(log, "B")
        end)
        q:clear("u")
        workers[1]() -- worker runs but pending was cleared
        expect(log).toEqual({})
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `HandlerQueue.spec` errors requiring a non-existent module / `run` nil.

- [ ] **Step 3: Implement** (`roblox/src/server/HandlerQueue.luau`)

```lua
--!strict
-- Per-uid FIFO serialization for the mutating server handlers (2026-07-19 spec). Each handler
-- body is a thunk that may yield on HTTP; run(uid, thunk) guarantees one player's thunks run
-- strictly one at a time — no mid-yield interleaving, no overlapping PUTs. The thread-spawn
-- primitive is injected so the module is pure and Lune-testable. One worker drains a lane
-- sequentially; a thunk's yield suspends the whole worker, so the next thunk cannot start until
-- the current one returns.
local HandlerQueue = {}
HandlerQueue.__index = HandlerQueue

-- Lune has no `warn` global; fall back to `print` off-Roblox.
local logWarn: (...any) -> () = (warn :: any) or print

local MAX_PENDING = 8
HandlerQueue.MAX_PENDING = MAX_PENDING

type Lane = { running: boolean, pending: { () -> () } }
export type HandlerQueue = typeof(setmetatable(
    {} :: { _spawn: (() -> ()) -> (), _lanes: { [string]: Lane } },
    HandlerQueue
))

function HandlerQueue.new(spawn: (() -> ()) -> ()): HandlerQueue
    return setmetatable({ _spawn = spawn, _lanes = {} }, HandlerQueue)
end

function HandlerQueue._drain(self: HandlerQueue, uid: string)
    local lane = self._lanes[uid]
    if lane == nil then
        return
    end
    lane.running = true
    -- exactly one worker for this lane; it closes over `lane` so a concurrent clear+new-run that
    -- installs a fresh lane never gets drained by this worker (identity guard on retire, below).
    self._spawn(function()
        while #lane.pending > 0 do
            local thunk = table.remove(lane.pending, 1) :: () -> ()
            local ok, err = pcall(thunk)
            if not ok then
                logWarn(`[QUEUE] handler error for {uid}: {tostring(err)}`)
            end
        end
        lane.running = false
        if self._lanes[uid] == lane and #lane.pending == 0 then
            self._lanes[uid] = nil
        end
    end)
end

function HandlerQueue.run(self: HandlerQueue, uid: string, thunk: () -> ()): boolean
    local lane = self._lanes[uid]
    if lane == nil then
        lane = { running = false, pending = {} }
        self._lanes[uid] = lane
    end
    if #lane.pending >= MAX_PENDING then
        logWarn(`[QUEUE] dropping request for {uid}: queue full ({MAX_PENDING})`)
        return false
    end
    table.insert(lane.pending, thunk)
    if not lane.running then
        self:_drain(uid)
    end
    return true
end

function HandlerQueue.clear(self: HandlerQueue, uid: string)
    local lane = self._lanes[uid]
    if lane ~= nil then
        table.clear(lane.pending) -- drop not-yet-run thunks
        self._lanes[uid] = nil
    end
end

return HandlerQueue
```

- [ ] **Step 4: Run to verify pass + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all PASS/clean. (If stylua reports formatting, run `stylua src tests` and re-check.)

- [ ] **Step 5: Commit**

```bash
git add roblox/src/server/HandlerQueue.luau roblox/tests/HandlerQueue.spec.luau
git commit -m "feat(roblox): HandlerQueue — per-uid FIFO serialization for mutating handlers"
```

---

## Task 2: Wire the six handlers, PlayerRemoving clear, and the two no-op skips

**Files:**
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `HandlerQueue.new` / `queue:run` / `queue:clear` (Task 1).
- Produces: no new module surface; the six handlers now serialize per uid.

This task is Roblox-runtime wiring — `main.server.luau` is not Lune-covered, so verification is: the Lune suite stays green, `rojo build` succeeds, and stylua/selene are clean. No new automated test.

- [ ] **Step 1: Require + instantiate the queue** — add the require alongside the other `script.Parent` server requires near the top (next to `local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))`, ~line 8):

```lua
local HandlerQueue = require(script.Parent:WaitForChild("HandlerQueue"))
```

Then instantiate it once, on the line immediately before the `BankRequest.OnServerEvent:Connect(` handler (~line 303):

```lua
local handlerQueue = HandlerQueue.new(task.spawn)
```

- [ ] **Step 2: Wrap `BankRequest`** (replace its `task.spawn`) — the handler currently reads:

```lua
BankRequest.OnServerEvent:Connect(function(player)
    task.spawn(function()
        <existing body>
    end)
end)
```

Change only the `task.spawn(function()` line to route through the queue (keep the body and its closing `end)` exactly as-is):

```lua
BankRequest.OnServerEvent:Connect(function(player)
    handlerQueue:run(tostring(player.UserId), function()
        <existing body, unchanged>
    end)
end)
```

- [ ] **Step 3: Wrap the other five handlers** — for each of `SetPadPreference`, `SetBackDoor`, `RequestPurchase`, `SetDisplay`, `SetPlacement`, apply the identical mechanical transform. Each currently reads:

```lua
Remote.OnServerEvent:Connect(function(player, ARG)
    <existing body>
end)
```

Becomes (compute the uid for the lane key in the outer wrapper; move the entire existing body — including its own `local uid = tostring(player.UserId)` first line — verbatim into the thunk):

```lua
Remote.OnServerEvent:Connect(function(player, ARG)
    handlerQueue:run(tostring(player.UserId), function()
        <existing body, unchanged>
    end)
end)
```

Concretely: `SetPadPreference` has `ARG = siteId`; `SetBackDoor`, `RequestPurchase`, `SetDisplay`, `SetPlacement` have `ARG = payload`. The thunk closes over `player` and `ARG` directly — no `table.pack` needed. Do not alter any line inside the body.

- [ ] **Step 4: Clear the lane on player leave** — in the economy-cleanup `Players.PlayerRemoving` handler (the one that nils `playerPrefs`/`playerHouse`/`playerEconomy`, ~lines 557-560), add `handlerQueue:clear` alongside the existing nils:

```lua
Players.PlayerRemoving:Connect(function(player)
    playerPrefs[tostring(player.UserId)] = nil
    playerHouse[tostring(player.UserId)] = nil
    playerEconomy[tostring(player.UserId)] = nil
    handlerQueue:clear(tostring(player.UserId))
```

(Leave the rest of that handler unchanged.)

- [ ] **Step 5: SetDisplay no-op skip** — in the `SetDisplay` handler body, between the two `deckDisplay`/`teahouseDisplay` parse lines and the `net:postDisplay` call, insert an early return when both already match the current stashed values. The body currently reads:

```lua
    local deckDisplay = if typeof(payload) == "table" then payload.deckDisplay else nil
    local teahouseDisplay = if typeof(payload) == "table" then payload.teahouseDisplay else nil
    -- server is authoritative: persist through the PWA API (it re-validates against ownership)
    local res = net:postDisplay(uid, deckDisplay, teahouseDisplay)
```

Insert the guard so it becomes:

```lua
    local deckDisplay = if typeof(payload) == "table" then payload.deckDisplay else nil
    local teahouseDisplay = if typeof(payload) == "table" then payload.teahouseDisplay else nil
    if deckDisplay == e.deckDisplay and teahouseDisplay == e.teahouseDisplay then
        return -- no-op: display already at the requested values (defends a modified client / redundant queued item)
    end
    -- server is authoritative: persist through the PWA API (it re-validates against ownership)
    local res = net:postDisplay(uid, deckDisplay, teahouseDisplay)
```

- [ ] **Step 6: SetPlacement no-op skip** — in the `SetPlacement` handler body, the `clamped` value is computed and then the built-size loadout is nil-guarded before `table.clone`. The body currently reads:

```lua
    local clamped = BuildingPlacer.clamp(buildingFP, boundsFP, { offset = { dx, dz }, facing = facing })
    -- merge into a NEW copy of the built size's loadout (pre-persist clone discipline)
    if e.teahouses[size] == nil then
        return -- built size has no owned loadout (non-contiguous ownership; defensive)
    end
    local newLoadout = table.clone(e.teahouses[size])
```

Insert the no-op guard after the nil-guard and before `table.clone` (at that point `e.teahouses[size]` is guaranteed non-nil):

```lua
    local clamped = BuildingPlacer.clamp(buildingFP, boundsFP, { offset = { dx, dz }, facing = facing })
    -- merge into a NEW copy of the built size's loadout (pre-persist clone discipline)
    if e.teahouses[size] == nil then
        return -- built size has no owned loadout (non-contiguous ownership; defensive)
    end
    local existingPlacement = e.teahouses[size].placement
    if
        existingPlacement ~= nil
        and existingPlacement.facing == clamped.facing
        and existingPlacement.offset[1] == clamped.offset[1]
        and existingPlacement.offset[2] == clamped.offset[2]
    then
        return -- no-op: placement already at the clamped target
    end
    local newLoadout = table.clone(e.teahouses[size])
```

- [ ] **Step 7: Verify build + suites + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src && rojo build -o /tmp/serialization-check.rbxl`
Expected: Lune green (unchanged count from Task 1), stylua/selene clean, `rojo build` succeeds (the wiring compiles). Delete the throwaway build: `rm -f /tmp/serialization-check.rbxl`.

- [ ] **Step 8: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): serialize the six mutating handlers per-uid via HandlerQueue; no-op skips on SetDisplay/SetPlacement"
```

- [ ] **Step 9: Studio smoke (user-driven, not a gate).** After a `rojo serve` restart, confirm each of the six flows still works uncontended: toggle a favorite, add a back door, buy an upgrade, change a display size, move a teahouse, bank a pot. Behavior is byte-identical to today when a player is not racing themselves; the serialization fix is only observable under self-contention, which the Task 1 Lune tests verify. No visual gate.

---

## Final: whole-branch review

After Task 2, dispatch the whole-branch review (superpowers:requesting-code-review) over the range (spec commit `ce7c34d`..HEAD) with the spec + these Global Constraints. Then per SDD, finish the branch.
