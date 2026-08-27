# Task 11 Report: DecorationController — owner prompts + auto-place on buy

## Status: DONE, committed 873c705

## Files
- CREATE `roblox/src/client/DecorationController.client.luau` (122 lines)
- MODIFY `roblox/src/server/TreatmentApplier.luau` (+1 line, `_buildDecorations`)

## Controller structure

Mirrors `BackDoorController.client.luau`'s geometry-driven binding idiom, but keyed on the
`CollectionService "Decoration"` tag instead of a folder/ChildAdded watch (Task 7 already tags
every decoration Model and stamps `id`/`padId` attributes on it — no folder-scan needed).

State:
- `myPadId: string?` — this client's own claimed pad, learned from `EconomyState` echoes.
- `pendingAutoMoveId: number?` — set by a `DecorationPlaced{id}` event after a buy; cleared the
  moment the matching instance is bound and the auto-`MoveDecoration` fires.
- `bound: {[Instance]: boolean}` — dedupes prompt creation per decoration Model.

Functions:
- `anchorPart(model)` — `PrimaryPart` else first descendant `BasePart`.
- `propIdOf(model)` — reads the `propId` attribute (the one this task adds server-side).
- `addPrompts(model)` — early-returns if already in `bound`; creates `DecorMove` (KeyCode E,
  fires `EventBus.MoveDecoration:Fire({padId, id, propId, part=model})`) and `DecorRemove`
  (KeyCode X, fires `SetDecorationRemove:FireServer({id})`) ProximityPrompts on the anchor part.
- `tryBind(inst)` — the single funnel described in the task context: rejects non-Models, rejects
  decorations whose `padId` attribute doesn't match `myPadId` (owner filter), calls `addPrompts`,
  then checks `pendingAutoMoveId` — if this instance's `id` attribute matches, it clears the
  pending id and fires `MoveDecoration` for it (only if `propId` is present/typed correctly, so a
  race where the attribute hasn't replicated yet just leaves the pending id armed for the next
  rescan rather than firing a broken payload).
- `rescanAll()` — iterates `CollectionService:GetTagged("Decoration")` and calls `tryBind` on each;
  called on every `EconomyState` pad-change, every `DecorationPlaced` event, and once at script
  start.

Wiring:
- `CollectionService:GetInstanceAddedSignal("Decoration"):Connect(tryBind)` — any decoration that
  replicates in later gets bound regardless of event ordering (the B3 replication-race lesson).
- `CollectionService:GetInstanceRemovedSignal("Decoration"):Connect(...)` — clears the `bound`
  entry (prompts die with their instance; no explicit prompt cleanup needed).
- `EconomyState.OnClientEvent` — updates `myPadId` only on change, then `rescanAll()` so
  already-replicated decorations get bound the moment the pad claim resolves (handles the "pad
  arrives after parts" ordering named in the task brief).
- `DecorationPlaced.OnClientEvent` — validates the payload shape, sets `pendingAutoMoveId`, then
  `rescanAll()` (handles "freshly-bought prop may not have replicated yet" — if it's not there yet,
  the `GetInstanceAddedSignal` connection's `tryBind` call catches it once it lands).
- `rescanAll()` at file scope, run once on script start for the ordinary case where decorations and
  claim are already both present.

## Applier edit (`TreatmentApplier.luau`, `_buildDecorations`)

```lua
model.Name = "Decoration"
model:SetAttribute("id", r.id)
model:SetAttribute("padId", padId)
model:SetAttribute("propId", r.propId)   -- added
model:AddTag("Decoration")
```

## Verification

1. `cd roblox && lune run tests/run` → `464 passed, 0 failed, 464 total` (the two `[WARN]` lines
   are pre-existing expected output from `HandlerQueue.spec`, not failures). Pure suite unaffected,
   as expected for a Roblox-runtime-only change.
2. `cd roblox && rojo build -o /tmp/decor-t11-check.rbxl` → `Built project to decor-t11-check.rbxl`
   (172788 bytes). Both files parse/compile under Rojo's Luau front end. Temp file removed after
   the check.
3. `cd roblox && stylua --check src tests && selene src` → both clean (stylua: no diff; selene:
   `0 errors, 0 warnings, 0 parse errors`) — but only after the deviation below.

## Deviation from the brief's literal code (required to pass verification)

The brief's Step-1 code block requires `DecorationCatalog` at the top:
```lua
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DecorationCatalog = require(shared:WaitForChild("DecorationCatalog"))
```
Nothing in the rest of the brief's controller code (or in the actual requirements — Move/Remove
prompts only read `id`/`padId`/`propId` attributes; the catalog's `footprint`/`build` calls belong
to `MoveController`, not this controller) ever references `DecorationCatalog` or `shared`. `selene
src` flagged it: `warning[unused_variable]: DecorationCatalog is assigned a value, but never used`,
which fails the "selene clean" verification gate given to me. Since the task instructions require
all three verification commands to pass clean, and this codebase has no `-- selene: allow(...)`
suppression precedent, I removed both the `local shared = ...` line and the `DecorationCatalog`
require — they were dead code with no effect on functionality. Confirmed via
`grep -rln "MoveDecoration" src/client/` that `MoveController.client.luau` is the one consumer that
actually calls `DecorationCatalog.footprint`/`.build` on the `MoveDecoration` payload; this
controller only needs to pass `propId` through, which it already reads off the model's attribute.

No other deviations. `EventBus.MoveDecoration` already existed (added by Task 9's generalization,
confirmed present in `roblox/src/client/EventBus.luau`'s `NAMES` list) and `MoveController.luau`'s
`enterDecoration` handler already expects exactly the `{padId, id, propId, part}` shape this
controller fires — verified by reading its guard clause (`typeof(payload.id) == "number"`,
`typeof(payload.propId) == "string"`, `typeof(payload.part) == "Instance"`). All three
`RoshamboRemotes` (`EconomyState`, `DecorationPlaced`, `SetDecorationRemove`) are declared in
`roblox/default.project.json`. The client folder (`src/client`) is mapped as a whole
(`"RoshamboClient": {"$path": "src/client"}`), so the new `*.client.luau` file needed no explicit
Rojo registration.

## Concerns

- None blocking. `tryBind` dedupes correctly via the `bound` table keyed by Instance (Lua table
  identity, not name), so re-running `rescanAll()` repeatedly (which happens on every
  `EconomyState`/`DecorationPlaced` event) never re-adds prompts to an already-bound decoration.
- `pendingAutoMoveId` is cleared inside `tryBind` in the same branch that fires the auto-move, so a
  second rescan after a successful auto-move won't re-fire `MoveDecoration` for the same id.
- One edge case worth flagging for the Studio visual gate (not a code defect): if
  `DecorationPlaced` fires for an id whose `propId` attribute hasn't replicated by the time the
  Model itself is tagged (attribute replication is not guaranteed atomic with tag replication),
  `tryBind` will bind the prompts but leave `pendingAutoMoveId` armed rather than firing a
  malformed move; a later `rescanAll()` (next `EconomyState` echo) would pick it up, but if no
  further echo arrives the auto-drag could be silently skipped. This matches the brief's own
  written behavior exactly (no additional retry loop was specified), so left as-is per "do not add
  functionality beyond the brief" — noting it here in case the visual gate surfaces it.
