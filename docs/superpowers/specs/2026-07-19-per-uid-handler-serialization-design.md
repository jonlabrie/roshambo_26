# Per-UID Handler Serialization — Design

**B-series hardening.** Approved in brainstorm 2026-07-19.

## Problem

Each mutating Roblox-server RemoteEvent handler runs on its own thread per firing, and
yields mid-body on an `HttpService:RequestAsync` call (via `net:...`). Two firings of the
same handler — or two different mutating handlers — for the **same player** can therefore
interleave across that yield: handler A reads the in-memory stash, yields; handler B runs to
completion (mutating the stash + persisting); A resumes and writes its now-stale snapshot back,
losing B's field. This is the mid-yield race family the B3 and B4 reviews flagged and patched
per-instance three times (locked-rung, buy-to-claim threading, `playerHouse` staleness,
SetPlacement's post-yield merge). There is also a raced-PUT last-writer-wins residual at the
Mongo user-document level when two of the player's PUTs are in flight at once.

Root cause: no serialization. The fixes so far each hardened one interleaving; this retires the
whole family by making a single player's mutating handlers run **strictly one at a time**.

## Goal

A per-uid FIFO queue so a player's mutating handlers never overlap. Because one human occupies
exactly one Roblox server instance, in-process per-uid serialization also fully closes the DB
residual for the realistic case (a single user's PUTs can no longer be concurrent) — no
Mongo-side locking is needed (that would only matter for one user on two servers at once, which
cannot happen).

## Decisions (brainstorm)

- **Queue & run in order** (per-uid FIFO), not mutex-drop or per-kind coalesce. No committed
  edit is lost; edits apply in click order.
- **All six** per-uid HTTP-yielding mutating handlers are wrapped:
  `SetBackDoor`, `SetDisplay`, `SetPlacement`, `RequestPurchase`, `SetPadPreference`,
  `BankRequest`. They all persist through the same PWA user document, so any pair can race the
  doc's fields; one uniform rule avoids per-handler "is this one safe?" judgment.
- **Cap the queue, drop-newest + warn** at `MAX_PENDING = 8`. Already-queued edits still run;
  a spammed/scripted button cannot build an unbounded backlog of HTTP calls + world rebuilds.
- **No separate time-based debounce.** The cap bounds resource use and the honest clients
  already suppress the worst redundant fires. Add a cheap server-side no-op early-return only
  where idempotence is trivially detectable (SetDisplay, SetPlacement).
- **Thunk-queue, not a mutex.** The lane owns the run→next lifecycle, so there is no
  `release()` for a handler's many early-return / `pcall`-failure paths to forget (a missed
  release would deadlock that player's edits forever).

## Architecture

### `roblox/src/server/HandlerQueue.luau` (new, pure, DI'd, Lune-tested)

A single-purpose module. Runtime-agnostic: the one Roblox dependency (thread spawning) is
injected, so Lune drives it deterministically.

**Injected dependency:** `spawn: (fn: () -> ()) -> ()` — runs `fn` on a fresh thread. Production
passes `task.spawn` (runs immediately up to the first yield, so the uncontended path keeps
today's zero-latency behavior). Lune passes a fake scheduler that records thunks and steps them
on demand.

**State:** `self._lanes: { [string]: Lane }` where `Lane = { running: boolean, pending: { () -> () } }`.

**Constant:** `MAX_PENDING = 8`.

**API:**

- `HandlerQueue.new(spawn): HandlerQueue`
- `HandlerQueue:run(uid: string, thunk: () -> ()): boolean` — the whole surface.
  - Create the lane if absent (`{ running = false, pending = {} }`).
  - If `#lane.pending >= MAX_PENDING`: `warn(...)` and `return false` (drop-newest).
  - `table.insert(lane.pending, thunk)`.
  - If not `lane.running`, start draining. `return true`.
- `HandlerQueue:clear(uid: string)` — delete the lane (called on `PlayerRemoving`). Not-yet-run
  pending thunks are dropped; a thunk already mid-flight is unaffected (it finishes on its own
  thread and its post-yield `IsDescendantOf(Players)` guards make it a safe no-op).

**Drain (`_drain(uid)`, private):** sets `lane.running = true`, then spawns **exactly one** worker
thread (via the injected `spawn`) that runs a sequential loop: pop `pending[1]`, run it inside
`pcall` (a thrown handler `warn`s but does not wedge the lane), repeat until `pending` is empty;
then set `lane.running = false` and, if still empty, delete the lane. It is one worker looping —
never one spawn per thunk — so a thunk's yield suspends the whole loop and the next thunk cannot
start until the current one returns. Each thunk yields on its HTTP call, so the drain thread suspends there and
resumes when the response lands — the lane's thunks run strictly sequentially. A `run(uid, …)`
arriving mid-yield appends to `pending` and is picked up by the already-running drain (it does
not start a second drain, because `lane.running` is true).

Properties (all Lune-tested): FIFO order; the 9th concurrent `run` returns false and is dropped;
an erroring thunk does not block its successors; a mid-drain enqueue is picked up by the running
drain; `clear` drops pending and resets the lane.

### Wiring (`roblox/src/server/main.server.luau`)

Instantiate once: `local handlerQueue = HandlerQueue.new(task.spawn)`.

Each of the six handlers gets the same mechanical wrap — the existing body moves **verbatim**
into a thunk:

```lua
Remote.OnServerEvent:Connect(function(player, ...)
    local uid = tostring(player.UserId)
    handlerQueue:run(uid, function()
        <existing handler body, unchanged>
    end)
end)
```

- The body keeps its own `local uid = tostring(player.UserId)` line (harmless recompute) and its
  synchronous top-of-handler validation guards. Guards run *inside* the thunk rather than before
  queueing: they are cheap and synchronous, and the cap bounds total work either way, so
  wrapping the whole body keeps all six edits identical and low-risk. (Trade-off accepted: a
  modified client spamming malformed requests still consumes lane slots, but the cap keeps that
  bounded — the same protection the honest path gets.)
- **`BankRequest`** currently wraps its own body in `task.spawn(function() … end)`. Replace that
  inline `task.spawn` with `handlerQueue:run(uid, function() … end)` — do not double-spawn. Its
  body writes the balance via `net:postBank` → `profiles:applyServer` (the leaderstats path, not
  the economy stash), but that PUT hits the same Mongo user document as the economy handlers, so
  serializing it closes its DB-level race with them.
- Handlers whose payload arg is not `player`-only (e.g. `SetPadPreference(player, siteId)`,
  `SetBackDoor(player, payload)`) capture their extra argument in the thunk closure as they do
  today — no `table.pack` needed; the closure closes over the parameters directly.

### Lifecycle

The existing economy-cleanup `Players.PlayerRemoving` handler (clears
`playerPrefs`/`playerHouse`/`playerEconomy`) gains `handlerQueue:clear(uid)`. Leak-free: pending
thunks for a departed player are dropped; an in-flight one completes harmlessly.

### Cheap no-op skips (idempotent handlers only)

- **SetDisplay**: before its `net:postDisplay` call, return early if the requested `deckDisplay`
  and `teahouseDisplay` both equal the current `e.deckDisplay` / `e.teahouseDisplay`.
- **SetPlacement**: before its `net:setTeahouse` call, return early if the requested
  `{offset, facing}` equals the stored placement on `e.teahouses[size]` (same offset values +
  facing).

Defense against a modified client or a redundant queued item; the honest B3 client already
guards display no-ops. The other four handlers get no no-op skip (toggles and balance ops are not
cleanly idempotent to detect).

## Error handling

- A thunk that throws is caught by the drain's `pcall`, `warn`ed, and the lane proceeds to the
  next thunk — one bad handler never wedges a player's queue.
- Each handler keeps its own existing failure/resync behavior (post-yield `IsDescendantOf`
  re-check, `echoEconomy`/`echoBackDoor`/state re-fire on persist failure) unchanged — the queue
  wraps them, it does not replace them.
- Queue overflow (`run` returns false) is a `warn` only; the client re-syncs from the echoes of
  the requests that did run.

## Testing & verification

- **Lune (`HandlerQueue.spec.luau`, TDD):** FIFO ordering across two enqueues on one lane;
  independent lanes for different uids run without interfering; the cap drops the 9th (`run`
  returns false, the first 8 still run); an erroring thunk does not block its successors; a `run`
  during an active drain is picked up by that drain (no second drain, no lost thunk); `clear`
  drops pending. Driven by a fake `spawn` + fake thunks that yield on a test-controlled signal.
- **Existing suites stay green:** server Vitest and roblox Lune unaffected (the wiring is a
  mechanical wrap; no pure-module contracts change).
- **Studio smoke (not a visual gate):** confirm the six flows still work uncontended
  (favorite toggle, back door, purchase, display change, placement move, bank) — behavior is
  byte-identical to today when a player is not racing themselves. The race fix is only observable
  under self-contention, which is impractical to hand-trigger, so the queue's Lune tests are the
  real verification of the fix; there is no visual gate.

## Non-goals / deferred

- **Cross-instance / distributed locking** — unnecessary (one human = one server instance); the
  DB residual for the realistic case is closed by in-process serialization.
- **Time-based debounce / rate limiting** — the cap is the bound; a separate timer is YAGNI.
- **Serializing non-mutating or non-HTTP handlers** (`SubmitPick`, `FateResolved`) — they do not
  persist to the user document mid-yield; out of scope.
- **Coalescing / per-kind latest-wins** — queue-with-cap is sufficient; per-kind keying was set
  aside in the brainstorm.
- **Reworking the handler bodies** — the wrap is mechanical; the interleaving-specific fixes
  already in the bodies (e.g. SetPlacement's post-yield merge) stay as belt-and-suspenders and
  are not removed.
