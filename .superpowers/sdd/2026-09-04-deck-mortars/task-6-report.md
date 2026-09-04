# Task 6 Report — Back-door editor: move-only gear

## File attribution mismatch (like Task 5's)

The brief said to modify `BackDoorController.client.luau`. That file has nothing to do with
decoration/gear placement — it's the F-prompt door-slot editor for a teahouse's back wall
(`Bay_back_<i>` bays, `SetBackDoor` remote). It does not touch decorations, drag, rotate, or the
24-cap. Read fully before writing anything, per the task instructions.

The real "editor's existing decoration move flow" is two files:
- `src/client/DecorationController.client.luau` — CollectionService-tag-driven prompt binding
  (padId-scoped Move/Remove ProximityPrompts on "Decoration"-tagged models).
- `src/client/MoveController.client.luau` — the generic ghost-drag/rotate/commit core
  (`startMove`, `applyGhost`, `stepDrag`, `rotate`, HUD strip), with per-kind entry points
  (`enterTeahouse`, `enterDecoration`) wired off `EventBus` BindableEvents.

I implemented the mortar move flow in these two files instead, per the task's own instruction to
follow the real structure rather than the plan's file attribution.

## What I implemented

1. **`src/client/DecorationController.client.luau`** — generalized `addPrompts`/`tryBind`/
   `rescanAll` to take an `isMortar: boolean` and also scan/bind the CollectionService `"Mortar"`
   tag (padId-scoped, same discipline as `"Decoration"`). A Mortar model gets ONLY the Move
   prompt (`ObjectText = "Mortar"`), firing a new `EventBus.MoveMortar` event with
   `{ padId, mortarId, part }` (mortarId read off the model's `MortarId` attribute, written by
   `TreatmentApplier:_buildMortars`). The Remove-prompt block is skipped entirely (`if isMortar
   then return end` before it's built) — no remove/sell affordance exists on a MortarId model,
   period; the code path that builds it isn't even reached.

2. **`src/client/EventBus.luau`** — added `"MoveMortar"` to the `NAMES` list (new BindableEvent,
   alongside `MoveTeahouse`/`MoveDecoration`).

3. **`src/client/MoveController.client.luau`** — added `enterMortar(payload)`, connected to
   `EventBus.MoveMortar.Event`. Key design decision: unlike a decoration (which may have `part =
   nil` right after purchase, before its instance replicates), an owned mortar tier ALWAYS has a
   rendered instance the instant it's owned — `MortarPlacement.resolve` gives every owned id a
   default spot (front edge, staggered) with no "not yet placed" state. So `enterMortar` requires
   a real `part` and clones it directly for the ghost (`ghostify(part:Clone())`), the same pattern
   `enterTeahouse` uses for the Structure — no separate mortar-catalog/builder module needed (the
   thing `enterDecoration` needs `DecorationCatalog.build()` for, because a freshly-bought
   decoration prop has no instance to clone yet). On commit: `SetMortarPlacement:FireServer({
   mortarId, offset = {x,z}, facing })` — exact payload shape the brief specifies.

4. **`src/shared/MortarPlacement.luau`** — exported `MortarPlacement.FOOTPRINT`, a
   `{minX,maxX,minZ,maxZ}` table built from the ALREADY-EXISTING private `PLACEMENT_HALF = 0.5`
   constant (the same size-independent gear half-extent the server's `resolve()`/`clampPoint`
   already clamps every mortar placement against). This is reuse, not a new decision: the value
   already existed and was already the module's stated footprint philosophy ("Generic gear
   footprint half-extent used to clamp a placement's center onto the deck"); I only exposed it,
   shaped like `DecorationCatalog.footprint()`'s return type, so `MoveController` can feed it to
   `BuildingPlacer.clamp`/`canFitFacing` exactly like a decoration's footprint. Since it's a new
   *public* export, I added a Lune test for it (`tests/MortarPlacement.spec.luau`) asserting the
   four bounds values.

## REQUIRED — cap-display finding

`MAX_DECORATIONS = 24` display logic lives in `src/shared/TeahouseMenuModel.luau:134-135`:
```lua
local decorCount = #(state.deckDecorations or {})
local underCap = decorCount < DecorationCatalog.MAX_DECORATIONS
```
It counts `state.deckDecorations` — a state field populated from `e.deckDecorations` throughout
`src/server/main.server.luau`. Mortars are carried in **entirely separate** fields, `e.mortars`
and `e.mortarPlacements`, populated only from `pushFireworkState`'s mirror of the fireworks GET
(`main.server.luau:1412-1415`, see the comment there: "this is the ONLY place e.mortars/
e.mortarPlacements get their real values ... every treatment/echo table that already carries
deckDecorations reads them from here"). `SetMortarPlacement`'s server handler
(`main.server.luau:2761-2821`) never touches `e.deckDecorations`, and `SetDecorationRemove`
(`main.server.luau:2823+`) iterates `e.deckDecorations` only — a mortar model, being tagged
`"Mortar"` not `"Decoration"` and living in a disjoint list, can never enter that count.

**Conclusion: the cap display naturally excludes mortars already — it counts by decoration
inventory (`deckDecorations`), not by scanning models/tags. No code change was needed or made.**

## Drag → offset/facing mapping

Reused, not reinvented. `MoveController.stepDrag()` (unchanged, generic) computes `{offset, facing}`
from the mouse-ray/deck-plane intersection; `rotate()` (unchanged, generic) cycles facing on R/HUD
button, gated by `BuildingPlacer.canFitFacing(footprint, deckFP, candidate)`. The only per-kind
input this math needs is a footprint — supplied for mortars by the newly-exported
`MortarPlacement.FOOTPRINT` (see above), consumed identically to `DecorationCatalog.footprint()`.
No new pure module was created; the existing shared modules (`BuildingPlacer`, `MortarPlacement`)
already covered everything needed once `FOOTPRINT` was exposed.

## Test / lint results

```
$ lune run tests/run
[WARN] [QUEUE] dropping request for u: queue full (8)          <- pre-existing HandlerQueue backpressure test, unrelated
[WARN] [QUEUE] handler error for u: .../HandlerQueue.spec:80: boom  <- same, intentional test-induced error
1646 passed, 0 failed, 1646 total

$ stylua --check src tests tools
(1 diff found in tests/MortarPlacement.spec.luau — my own new test's line-wrapping;
 fixed with `stylua src tests tools`, then --check passed clean)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ lune run tests/run   (re-run after stylua reformat)
1646 passed, 0 failed, 1646 total
```

## Files changed

- `roblox/src/client/DecorationController.client.luau` — Mortar tag binding, Move-only prompt
- `roblox/src/client/EventBus.luau` — new `MoveMortar` BindableEvent
- `roblox/src/client/MoveController.client.luau` — new `enterMortar` entry point
- `roblox/src/shared/MortarPlacement.luau` — exported `FOOTPRINT`
- `roblox/tests/MortarPlacement.spec.luau` — test for `FOOTPRINT`

Commit: `33b383b` — "feat(mortars): back-door editor moves gear -- drag and rotate, never remove"

## Self-review findings

Read the full diff after staging (`git diff --cached`). No issues found:
- Remove-prompt code path is structurally unreachable for `isMortar == true` (early `return`
  before the block that builds it), not just hidden by a runtime check — matches "whatever
  prompt/action the decoration flow shows for removal is absent on a MortarId model" literally.
- `enterMortar` requires `payload.part` to be a real `Instance` (returns early otherwise) since
  mortars never have the "no instance yet" case decorations do — this is intentionally stricter
  than `enterDecoration`, not an oversight.
- `SetMortarPlacement` payload shape (`{ mortarId, offset = {x,z}, facing }`) matches the brief
  and the server handler's expectations (`main.server.luau:2761+`) exactly.
- `folder = part.Parent` for a Mortar model resolves to the site folder
  (`MaterializedSite_<padId>`) exactly as it does for decorations — confirmed via
  `TreatmentApplier._buildMortars`/the staging-folder reparent step
  (`main` commit block: `for _, c in staging:GetChildren() do c.Parent = folder end`), so
  `siteInfo(folder)` (reading `MountCF`/`DeckSize` attributes) works unchanged.
- Only files relevant to this task were staged/committed — pre-existing unrelated working-tree
  changes (`art/birds/uguisu/uguisu_authored.blend`, `.superpowers/sdd/.gitignore`, present before
  this session started) were left untouched and unstaged.

## Concerns

None. The server side (Task 4/5) was already complete and required no changes; this was a
client-only addition that reuses the existing tag-binding and ghost-drag infrastructure with no
new architectural surface beyond one exported constant and one BindableEvent.
