# Task 5 report — Tube render (mortar render pass)

**⚠ SUPERSEDED BELOW.** The original submission (client-side render pass in
`DecorationController.client.luau`) was ruled against the spec — "every player's mortars are
visible to every visitor, like decorations" and "rendered by the same machinery that draws
decorations" — which a `FireClient`-only, single-owner-visible client pass can never satisfy. The
coordinator authorized touching `main.server.luau`/`TreatmentApplier.luau` and folded the pending
muzzle-alignment fix into this round. See the "Fix report" section at the bottom for what actually
shipped; the original write-up above is kept for its research value (the wire-format findings
about `EconomyState` vs `FireworkState`, and the geometry idiom, both carried forward unchanged).

## What I implemented

`roblox/src/client/DecorationController.client.luau` gained an entirely new, self-contained mortar
render pass (functions, state, listeners) beside its existing decoration-prompt logic.

**Divergence from the brief's premise, stated up front:** the brief describes modifying "the
controller's existing rebuild pass" and "deck-bounds derivation." Neither exists in this file.
`DecorationController.client.luau` does not build or redraw decoration geometry at all — decorations
are built **server-side** by `TreatmentApplier._buildDecorations`
(`roblox/src/server/TreatmentApplier.luau`) and simply replicate in as tagged `Model`s; this client
file only attaches Move/Remove `ProximityPrompt`s to whatever `"Decoration"`-tagged models happen to
exist for the local player's claimed pad (via `CollectionService`). This matches
main.server.luau's own comment on the `SetMortarPlacement` handler: *"mortars are not server-built
props (TreatmentApplier never reads treatment.mortarPlacements/mortars — Task 5 renders them
client-side)."* So I built the entire mortar pipeline — geometry, placement math, rebuild triggers —
from scratch in this file, reusing idioms already established by sibling controllers
(`BackDoorController.client.luau`'s `watchFolder`/`bindStructure`, `MoveController.client.luau`'s
`facingFromPivotOf`/site-folder attribute reads).

**Geometry** (`buildMortarModel`): one `Model` per owned tier, named `Mortar_S`/`Mortar_M`/`Mortar_L`.
A timber `Base` part (`Vector3.new(bore*3+0.4, 0.5, bore*3+0.4)`, `Color3.fromRGB(216,214,206)`,
`Enum.Material.Wood`) sits under a `Tube` part (`Vector3.new(length, bore*3, bore*3)`,
`Shape = Enum.PartType.Cylinder`, local `CFrame.new(0, 0.5 + length/2, 0) * CFrame.Angles(0, 0,
math.rad(90))`) — the exact idiom `DecorationCatalog.luau`'s `tsukubai` builder uses to stand a
cylinder's default horizontal axis upright. All parts: `Anchored=true`, `CanCollide/CanQuery/CanTouch
= false`. `PrimaryPart = Tube`. The model is built at local origin and placed the same way
`TreatmentApplier._buildDecorations` places a decoration prop: `model:PivotTo(mountCF *
CFrame.new(table.unpack(BuildingPlacer.placeCF({offset={x,z}, facing}))))`.

**Placement** (`rebuildMortars`): reads `myPadId`'s `MaterializedSite_<padId>` folder
(`workspace.TeahouseSites`) for its `MountCF`/`DeckSize` attributes, computes `deckFP =
SizeClasses.deckFootprint(deckSize)` and the teahouse footprint (see required item below), then
calls `MortarPlacement.resolve(deckFP, myMortars, myMortarPlacements, teahouseFP)` and builds/places
one model per returned entry.

**Tagging**: each model gets `CollectionService:AddTag("Mortar")` plus attributes `padId` (string,
matching decorations' own attribute name) and `MortarId` (string, exact capitalization from the
brief). **Deliberately NOT tagged `"Decoration"`** — see divergence note below.

**Rendered-model home**: a new top-level `workspace.ClientMortarRender` folder, created once by this
script — NOT the site's own `MaterializedSite_<padId>` folder. `TreatmentApplier:apply()` destroys
every direct child of that folder on every server rebuild; parenting mortars there would let an
unrelated decoration/teahouse rebuild silently wipe client-only geometry the server doesn't know
exists.

**Rebuild triggers**:
1. `EconomyState.OnClientEvent` (existing handler, extended) — captures `p.mortars`/
   `p.mortarPlacements` (mirrored into `echoEconomy`'s payload) and rebuilds. Also re-arms a
   `Structure`-watcher on claim change (see #3).
2. `FireworkState.OnClientEvent` (**new listener, no server change** — see wire-through below).
3. A `folder.ChildAdded` watcher on the claimed pad's `MaterializedSite_<padId>` folder, filtered to
   `child.Name == "Structure"` — mirrors `BackDoorController.watchFolder`/`bindStructure` exactly,
   armed/rearmed whenever `myPadId` changes.

## Wire-through added

No server file was touched (as instructed). On the client, I added one **new subscription** to an
**existing** RemoteEvent: `FireworkState.OnClientEvent`. Reason: `e.mortars`/`e.mortarPlacements`
receive their real values ONLY via `pushFireworkState` (main.server.luau lines ~1336-1345, its own
comment: *"this is the ONLY place e.mortars/e.mortarPlacements get their real values (neither rides
the economy GET)"*) — fired on `FireworkState`, on join / after every launch / at every reveal.
`echoEconomy`/`EconomyState` only ever echoes back whatever `e.mortars`/`e.mortarPlacements` already
hold. Without this second listener, a player who owns mortars but has taken no OTHER economy action
(buy/move a decoration, etc.) since joining would see zero tubes on their own deck. `ShopController`
and `main.client.luau` already listen to the same event independently, so adding a third listener is
consistent with existing multi-subscriber use of this RemoteEvent.

I also added a **second, new trigger source** not literally named in the brief: the `Structure`
ChildAdded watcher (#3 above). Reason: `SetPlacement` (a teahouse move, B4) rebuilds the `Structure`
child WITHOUT ever calling `echoEconomy` (confirmed by reading its full handler — it ends at
`echoBackDoor`, never `echoEconomy`). Without this watcher, moving your teahouse would not re-nudge
your mortars against its new footprint until some unrelated action happened to also echo economy.

## REQUIRED — teahouse footprint derivation

**(1) How it's computed.** New private function `teahouseFootprint(folder, mountCF)` in
`DecorationController.client.luau`:
- Reads `folder:GetAttribute("TeahouseSize")` (string, `""` for a bare deck — set by
  `TreatmentApplier:apply` at the very end of every rebuild) and `folder:FindFirstChild("Structure")`
  (the built teahouse `Model`, present only when a teahouse is actually built), both from the pad's
  `MaterializedSite_<padId>` folder under `workspace.TeahouseSites`.
- Derives the teahouse's **deck-local placement** (`offset`, `facing`) by taking
  `mountCF:ToObjectSpace(structure:GetPivot())` and rounding the resulting yaw to the nearest cardinal
  — **the identical technique** `MoveController.client.luau`'s private `facingFromPivotOf` already
  uses for the same purpose. This is necessary because nothing else replicates the built teahouse's
  offset/facing to the client: `TreatmentApplier` computes and clamps `teahouse.placement` server-side
  inside `_buildBuilding`, uses it to compute its own `teahouseFP` for `_buildDecorations`, and then
  discards it — only `TeahouseSize`, `MountCF`, and `DeckSize` end up as folder attributes.
- Computes `buildingFP = SizeClasses.buildingFootprint(teahouseSize)` and returns
  `BuildingPlacer.footprintBounds(buildingFP, {offset={x,z}, facing})` — the same two pure shared
  functions `TreatmentApplier:apply` itself calls (`self._sizeClasses.buildingFootprint`,
  `self._buildingPlacer.footprintBounds`) to compute its own `teahouseFP`, just fed
  client-re-derived inputs instead of the server's in-memory `builtPlacement`.
- **Is it pure / server-computable?** The math (`SizeClasses.buildingFootprint`,
  `BuildingPlacer.footprintBounds`) is the same pure, Lune-tested shared code the server already
  runs. What is NOT pure is reading it back off a live `Structure`'s `CFrame` — that's a Roblox
  Instance read, unavoidable on the client since nothing else carries the placement to it. On the
  **server**, the equivalent value is already fully pure and server-computable without touching any
  Instance: `TreatmentApplier._buildBuilding` computes and returns exactly this `teahouseFP`
  in-memory every `apply()` call (`main.server.luau`'s `builtPlacement` local) — it is simply
  discarded after `_buildDecorations` uses it, rather than being stored (e.g. as an attribute) or fed
  into the launch-origin call the way the brief anticipates the controller aligning next.
- Returns `nil` when the deck is bare (`TeahouseSize == ""`) or the `Structure` child hasn't
  replicated in yet — `MortarPlacement.resolve` treats `nil` as "no nudge," same as a bare-deck
  decoration pass.

**(2) Exact bounds shape passed.** `{ minX: number, maxX: number, minZ: number, maxZ: number }` —
deck-local, produced by `BuildingPlacer.footprintBounds`, identical shape to `SizeClasses.Footprint`
and to `MortarPlacement.Bounds` (no conversion needed). This is the fourth positional argument
(`teahouseFP`) passed to `MortarPlacement.resolve(deckFP, myMortars, myMortarPlacements, teahouseFP)`.

This confirms the task's flagged concern is real and unresolved by this task (as instructed, I did
not touch `main.server.luau`): `muzzleOriginFor` in `main.server.luau` still calls
`MortarPlacement.resolve(bounds, e.mortars, e.mortarPlacements, nil)` with no teahouse footprint, so
a mortar nudged away from under the teahouse **visually** (this controller, teahouseFP populated) can
sit at a different spot than where the server computes the muzzle origin (teahouseFP = nil, i.e. the
un-nudged stored/default spot) whenever a nudge actually fires. Aligning the two is the controller's
job in a later, separate step.

## Judgment calls / divergences (all deliberate, reasoned above or below)

- **Tag `"Mortar"`, not `"Decoration"`.** The brief says "tag each Model the way decoration models
  are tagged." Reusing the literal `"Decoration"` tag would feed mortar models straight into this
  file's EXISTING `CollectionService:GetInstanceAddedSignal("Decoration")` → `tryBind` → `addPrompts`
  pipeline, which unconditionally attaches "Move"/"Remove" `ProximityPrompt`s to any tagged+padId-
  matching model. Since mortar models carry no `id`/`propId` attribute, those prompts would appear
  and do nothing when triggered — a dead, misleading UI regression, directly contradicting the
  brief's own "later Task 6 overlays prompts on these models" (i.e. Task 5's models should have NO
  prompts yet). I used a distinct tag (`"Mortar"`) with the same attribute-tagging STRUCTURE
  (`padId` + a type-specific id attribute), which I read as the more faithful interpretation of "the
  way decoration models are tagged."
- Base footprint (width/depth) isn't specified by the brief (only height 0.5, color, material) —
  chose `tube.bore*3 + 0.4` (square, scaling with tier) as a reasonable default.
- Tube color `Color3.fromRGB(58, 60, 66)` (dark gunmetal) + `Enum.Material.Metal` — the brief only
  specifies these for the timber base; picked a plausible metal tone for the tube.
- **Mortar visibility is owner-scoped**, same as this file's existing `myPadId` scoping: `mortars`/
  `mortarPlacements` are only ever sent to the owning player (`EconomyState`/`FireworkState` are both
  `FireClient` single-target, never broadcast to all clients). A visitor standing on someone else's
  deck will not currently see that owner's mortar tubes. This is an existing architecture property
  from Task 4's design (server never broadcasts these fields), not something introduced or fixable
  in this task's stated scope.

## Test / lint results

```
$ lune run tests/run
[WARN] ... (2 pre-existing, unrelated HandlerQueue.spec warnings about a deliberately-full/erroring
queue in that spec's own test cases)
1641 passed, 0 failed, 1641 total

$ stylua --check src tests tools
(no output — clean)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

## Files changed

- `roblox/src/client/DecorationController.client.luau` — the entire mortar render pass (new requires,
  new state, `buildMortarModel`, `clearMortarModels`, `teahouseFootprint`, `rebuildMortars`,
  `watchMortarFolder`, extended `EconomyState` handler, new `FireworkState` listener).

## Self-review findings

- Re-read the full diff after `stylua --check`/`selene` both passed clean; confirmed no leftover
  debug code, no shadowed locals, no unused variables.
- Confirmed `rebuildMortars()` is idempotent/safe to call repeatedly (always `clearMortarModels()`
  first) and cheap (≤3 tiny parts) — acceptable given it now fires on most economy-state churn, not
  just mortar-specific changes.
- Confirmed the `EconomyState` handler's early `return` after `watchMortarFolder(folder)` (which
  rebuilds internally) avoids a redundant double-rebuild on claim change, while every other path
  still ends in exactly one `rebuildMortars()` call.
- Verified `MortarPlacement.resolve`'s returned `Bounds`/`Placement` shapes need no conversion before
  being handed to `BuildingPlacer.placeCF`/`footprintBounds` — same field names throughout
  (`SizeClasses.Footprint`, `MortarPlacement.Bounds`, `BuildingPlacer`'s `FP`).

## Concerns

1. **Muzzle/visual mismatch** (flagged by the task itself, unresolved by design): see the required
   report item above — `main.server.luau`'s `muzzleOriginFor` passes `teahouseFP = nil`, so a
   nudged tube's visual spot and the server's muzzle origin can diverge until the controller is
   aligned.
2. **Cross-player visibility gap**: mortars render only for their owner's own client (inherited from
   Task 4's non-broadcast design for `mortars`/`mortarPlacements`), unlike decorations which
   everyone sees via server-side replication. Worth flagging to the owner even though it's outside
   this task's stated scope.
3. Two rebuild-trigger additions (`FireworkState` listener, `Structure`-ChildAdded watcher) go beyond
   a literal reading of "Rebuild on the same events decorations rebuild on (placement echo
   included)" — both are reasoned above as necessary to avoid real, demonstrable gaps (mortars never
   appearing at all; mortars not re-nudging after a teahouse move), not speculative additions.

---

# Fix report — rework to server-side rendering (coordinator ruling)

## Summary of the rework

Reverted the client-side pass entirely and moved mortar rendering into
`TreatmentApplier:apply`, beside `_buildDecorations`, so mortars are server-built and replicate to
every visitor exactly like decorations do. Folded in the muzzle-alignment fix (item 5) by
extracting the teahouse-placement-resolution math TreatmentApplier already ran into a new pure
`BuildingPlacer.resolveFit` function, called by both `TreatmentApplier._buildBuilding` and a new
`main.server.luau` helper `teahouseFootprintFor`, so the rendered tube and the muzzle origin can
never compute two different footprints from the same stored teahouse placement.

## 1. `TreatmentApplier:_buildMortars` (`roblox/src/server/TreatmentApplier.luau`)

Added `_buildMortars`, a sibling to `_buildDecorations`, called from `apply()` right after the
decorations step. `teahouseFP` (previously computed *inside* the decorations `if` block) is now
**hoisted above both** decoration and mortar steps so they consume the identical value — one
teahouse, one footprint, for both prop kinds.

`_buildMortars(padId, deckCF12, deckSize, teahouseFP, treatment.mortars, treatment.mortarPlacements,
staging)`: no-ops if `mortars` is nil/empty; otherwise calls
`self._mortarPlacement.resolve(deckFP, mortars, mortarPlacements, teahouseFP)` (the injected pure
`MortarPlacement` module — placement DECISIONS stay there, unchanged from Task 5's original design)
and for each returned `{mortarId, placement}` builds a `Model` and `PivotTo`s it via
`self._buildingPlacer.placeCF`/`deckCF`, exactly the same idiom `_buildDecorations` uses. Gated on
`treatment.lit == true`, same as decorations/flag/portal control, and `pcall`-wrapped with the same
fault-isolation discipline (`[MORTAR] mortar step failed for {padId}: ...; deck without mortars`) —
a bad tier can never blank the deck.

**Geometry kept exactly as Task 5 designed it** (moved verbatim from the reverted client file into
TreatmentApplier, built INLINE rather than via an injected catalog — the same pattern
`_buildNobori`/`_buildPortalControl` already use for a single fixed shape per case rather than a
choosable prop list): timber `Base` (`Vector3.new(bore*3+0.4, 0.5, bore*3+0.4)`,
`Color3.fromRGB(216,214,206)`, `Enum.Material.Wood`), a `Tube` cylinder
(`Vector3.new(length, bore*3, bore*3)`, `Shape=Cylinder`, local `CFrame.new(0, 0.5+length/2, 0) *
CFrame.Angles(0,0,rad(90))` — the tsukubai idiom), `Model` named `Mortar_S/M/L`,
`PrimaryPart = Tube`, all parts anchored/non-interactive. **Tagging ruling accepted as-is**: tag
`"Mortar"` (not `"Decoration"` — avoids feeding mortar models into
`DecorationController.client.luau`'s existing Move/Remove prompt pipeline, which would attach dead
prompts since mortars carry no `id`/`propId`) plus attributes `padId` and `MortarId`.

**Dependency injection**: `TreatmentApplier`'s `Deps` type and constructor gained
`mortarPlacement: any` (mirrors every other shared pure module already injected rather than
`require`d directly — the file's own header warns that a relative `require("../shared/X")` inside
`src/server` resolves on disk but not in the live DataModel, since `src/server` mounts at
`ServerScriptService.Roshambo` and `src/shared` at `ReplicatedStorage.RoshamboShared`). Wired at the
`TreatmentApplier.new({...})` call site in `main.server.luau`: `mortarPlacement = MortarPlacement`.

## 2. Client-side render pass reverted (`roblox/src/client/DecorationController.client.luau`)

Restored to byte-identical content from before Task 5's original commit (verified with `diff` —
zero remaining lines from the client pass). Removed: `buildMortarModel`, `clearMortarModels`,
`teahouseFootprint`, `rebuildMortars`, `watchMortarFolder`, the `ClientMortarRender` folder, the
`FireworkState` listener, the `Structure`-ChildAdded watcher, and the `EconomyState` handler
extensions. Nothing tiny was needed — clean revert.

## 3. Rebuild trigger for late-arriving mortar data (`main.server.luau`, `pushFireworkState`)

`e.mortars`/`e.mortarPlacements` still only receive real values inside `pushFireworkState` (the
fireworks GET) — that fact from the original report carries forward unchanged. Since mortars now
render server-side, a changed value there must trigger the same `rebuildClaimedPad` the decoration
flow uses, but `pushFireworkState`'s assignment is textually **before** `rebuildClaimedPad` is
declared (it needs `playerHouse`/`applier`, built later in the composition root), so it cannot call
it directly. Used the file's own existing idiom for this exact problem — a forward-declared
optional function local, assigned once the real implementation exists — mirroring `pushFireworkState`
itself: added `local rebuildClaimedPadFn: ((string) -> ())? = nil` near `pushFireworkState`'s own
forward declaration, assigned `rebuildClaimedPadFn = rebuildClaimedPad` immediately after
`rebuildClaimedPad`'s definition.

**Dirty-guard**: added a pure `mortarFingerprint(mortars, placements): string` (deterministic,
ordered by `MortarPlacement.MORTAR_ORDER` rather than raw table/JSON iteration order, which isn't
guaranteed stable across an HTTP round-trip) and a side-table `mortarRenderedFingerprint: {[string]:
string}` (same pattern as the file's existing `friendCache`/`shojiPersistGen` side-tables). Inside
`pushFireworkState`, after adopting `res.data.mortars`/`mortarPlacements` into `e`, it computes the
fingerprint and only calls `rebuildClaimedPadFn(uid)` when it differs from
`mortarRenderedFingerprint[uid]` — guarding against rebuilding the pad on every reveal/launch poll
when nothing about the player's mortars actually changed. `rebuildClaimedPad` already no-ops when
`e.claimedPadId == nil`, so the call is safe unconditionally once the fingerprint changed.

## 4. `SetMortarPlacement` triggers a rebuild (verified NOT already flowing through one — added it)

Confirmed by reading the full handler: previously it persisted (`net:putMortarPlacements`), mirrored
`e.mortarPlacements`, and called only `echoEconomy(player, uid)` — no rebuild, matching what the
(now-stale) comment claimed. Added, mirroring `SetDecorationPlacement`'s ending exactly:
`mortarRenderedFingerprint[uid] = mortarFingerprint(e.mortars, e.mortarPlacements)` (so
`pushFireworkState`'s next poll doesn't redundantly re-rebuild what this handler just rendered),
`rebuildClaimedPad(uid)`, `echoBackDoor(player, uid)` (parity — a rebuild replaces `Structure`, so
the back-door prompts need re-arming same as every other rebuild path), then `echoEconomy(player,
uid)` as before.

## 5. Muzzle alignment (`main.server.luau`, `muzzleOriginFor`)

**Extraction**: pulled the clamp-then-N-fallback logic out of `TreatmentApplier._buildBuilding`
into a new pure function `BuildingPlacer.resolveFit(buildingFP, deckFP, requested): Placement?`
(`roblox/src/shared/BuildingPlacer.luau`) — clamps the requested placement into the deck's
placement bounds; if the requested facing still doesn't fit after clamping, retries once at facing
`"N"` (same offset, re-clamped); returns `nil` only if even that fallback doesn't fit.
`_buildBuilding` now calls this instead of duplicating the logic inline. Added 4 new Lune tests in
`tests/BuildingPlacer.spec.luau` (`BuildingPlacer.resolveFit` describe block): in-bounds unchanged,
a stored placement clamped back in, a facing that only fits after falling back to N, and the
pathological "nothing fits" nil case.

**Wiring**: added `teahouseFootprintFor(e): any` in `main.server.luau`, placed right before
`muzzleOriginFor`. From `e` alone (no extra state needed — confirming the brief's "if the placement
isn't directly in `e`" branch didn't apply) it: resolves which teahouse size is actually built via
`SizeClasses.resolveBuilt` (same call `rebuildClaimedPad` already makes), reads that size's stored
`placement` (or `CENTERED_PLACEMENT`), computes `buildingFP = SizeClasses.buildingFootprint(size)`
and `deckFP = SizeClasses.placementBounds(builtDeckSize)` (placementBounds, not deckFootprint —
mirrors `_buildBuilding` exactly, since the railings occupy the footprint's perimeter), calls the
SAME `BuildingPlacer.resolveFit`, and returns `BuildingPlacer.footprintBounds(buildingFP,
placement)` (or `nil` for a bare deck or the pathological non-fit case). `muzzleOriginFor` now calls
`teahouseFootprintFor(e)` and passes the result as `MortarPlacement.resolve`'s 4th argument instead
of the hardcoded `nil`.

**Noted but explicitly NOT touched** (out of scope for this fix): `deckRowFor` — used by
`muzzleOriginFor` for the deck's world-position row and to source the `deckSize` fed into
`SizeClasses.deckFootprint` for the mortar's own deck-bounds clamp — sources `deckSize` as
`e.maxDeckSize or "S"`, which is NOT necessarily the same `deckSize` `SizeClasses.resolveBuilt`
would return under an active `deckDisplay` shrink. `teahouseFootprintFor` independently resolves
its OWN `built.deckSize` (matching what `TreatmentApplier` actually rendered with) for the
teahouse-footprint math specifically, so this fix does not introduce any new drift — but the
pre-existing `deckRowFor`/`resolveBuilt` discrepancy (affecting the deck-bounds clamp and the
deck's world position, not the teahouse footprint) is adjacent to this exact "muzzle-true" property
and worth the owner's attention in a future pass. Left alone here since fixing it is a separate,
larger, unrelated behavior change I wasn't asked to make.

## 6. Stale comment fixed

`SetMortarPlacement`'s handler comment ("mortars are not server-built props ... Task 5 renders them
client-side") replaced with one stating the current, correct architecture (server-built via
`TreatmentApplier:_buildMortars`, alongside `_buildDecorations`) and explaining why the handler now
rebuilds.

## Test coverage note (per the brief's constraint)

`TreatmentApplier` has **no existing Lune spec** — confirmed by search (`find . -iname
"*TreatmentApplier*"` returns only the source file) and consistent with its own header comment
("Roblox datatypes -> not Lune-testable; proven by the visual gate"). Per the coordinator's
instruction ("if it has none, say so rather than inventing a harness"), I did not invent one. The
part of this change that IS pure and Lune-testable — `BuildingPlacer.resolveFit`, the function both
`TreatmentApplier` and `muzzleOriginFor` now share — is covered by the 4 new tests described above.

## Test / lint results (full output)

```
$ lune run tests/run
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom
(both pre-existing, unrelated -- that spec's own deliberately-full/erroring queue test cases)

1645 passed, 0 failed, 1645 total

$ stylua --check src tests tools
(no output — clean)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

## Files changed (this round)

- `roblox/src/client/DecorationController.client.luau` — reverted to pre-Task-5 content (verified
  byte-identical via `diff`).
- `roblox/src/server/TreatmentApplier.luau` — `mortarPlacement` dependency; `_buildMortars` +
  `buildMortarModel`/`mortarPart` geometry helpers; `_buildBuilding` now calls
  `BuildingPlacer.resolveFit`; `teahouseFP` hoisted in `apply()`; mortar build step wired in beside
  decorations.
- `roblox/src/server/main.server.luau` — `mortarPlacement = MortarPlacement` wired into
  `TreatmentApplier.new`; `rebuildClaimedPadFn` forward declaration + assignment;
  `teahouseFootprintFor` helper; `muzzleOriginFor` now passes a real `teahouseFP`;
  `mortarFingerprint` + `mortarRenderedFingerprint` dirty-guard; `pushFireworkState` triggers a
  guarded rebuild; `SetMortarPlacement` handler now rebuilds/echoes back-door parity and updates the
  fingerprint cache; stale comment fixed.
- `roblox/src/shared/BuildingPlacer.luau` — new pure `BuildingPlacer.resolveFit`.
- `roblox/tests/BuildingPlacer.spec.luau` — 4 new tests for `resolveFit`.

## Self-review findings

- Re-read the full diff of every changed file after `stylua --check`/`selene`/`lune run tests/run`
  all passed clean.
- Confirmed `teahouseFP` in `TreatmentApplier:apply` is computed exactly once, before both the
  decorations and mortars steps, from the identical `builtPlacement`/`teahouse` — no duplicated or
  divergent computation between the two prop kinds.
- Confirmed `_buildMortars`'s `pcall` fault-isolation matches `_buildDecorations`'s discipline
  exactly (a bad tier warns and skips, never aborts the rest of `apply()`).
- Confirmed `mortarFingerprint`/`mortarRenderedFingerprint` don't create a re-entrancy hazard:
  `rebuildClaimedPadFn(uid)` is called synchronously from inside `pushFireworkState`'s
  `handlerQueue:run(uid, ...)` callback, and `rebuildClaimedPad` itself performs no yields (no HTTP
  calls, only synchronous Roblox instance work), so this is not a nested/duplicate
  `handlerQueue:run` for the same key.
- Verified `SetMortarPlacement`'s new `rebuildClaimedPad(uid)` call is a direct reference (not
  `rebuildClaimedPadFn`) since that handler is textually well after `rebuildClaimedPad`'s
  definition — no forward-declaration is needed there, matching how `SetDecorationPlacement`
  already calls it directly.
- Verified the `BuildingPlacer.resolveFit` extraction is behavior-preserving: the new tests
  reproduce the exact clamp/fits/N-fallback/nil branches the old inline `_buildBuilding` code took,
  and the full suite (which exercises `TreatmentApplier` only via the visual gate, not Lune — so
  this is really `BuildingPlacer`'s own coverage) still passes.

## Concerns

1. Mortars are gated on `treatment.lit == true` inside `TreatmentApplier:apply`, same as
   decorations/flag/portal control — a vacant/unlit pad shows no one's mortars. Not stated
   explicitly in the rework instructions, but treating mortars any differently from decorations on
   this axis seemed like the wrong asymmetry to introduce silently; flagging it in case the intent
   was actually "mortars are visible even on a vacant deck."
2. The pre-existing `deckRowFor` vs `SizeClasses.resolveBuilt` deck-size discrepancy noted in item 5
   above (not introduced by this fix, not fixed by it either) — worth a future look since it sits
   right next to the exact "muzzle-true" property this task cares about.
3. `MORTAR_BASE_TOP`/`MORTAR_BASE_COLOR`/`MORTAR_TUBE_COLOR`/the base-footprint formula are
   duplicated as module-level constants in `TreatmentApplier.luau` now (moved verbatim from the
   reverted client file, not extracted into a shared module) — acceptable given Task 5's own
   precedent (Nobori/PortalControl geometry is likewise inline, not catalog-based), but if Task 6's
   editor or a future visual pass needs these values too, they may be worth promoting to
   `MortarPlacement.luau` or a small shared constants module at that point.

---

# Final-review fix round

Whole-branch merge review came back "merge with fixes" — three findings, all in or near this
task's code. Fixed all three in one commit (`31dcd6f`).

## 1. CRITICAL — stale `mortarRenderedFingerprint` on rejoin

**Root cause confirmed exactly as described**: `mortarRenderedFingerprint[uid]` (set in
`pushFireworkState`, `main.server.luau`) was never cleared on leave. `Players.PlayerRemoving`
(the SECOND handler in the file, ~line 1896 — there's an unrelated first one at ~line 771 for
fates/familiar-roster/hud state that isn't touched by this) nils `playerHouse[uid]` and
`playerEconomy[uid]` but hadn't been taught about the new mortar-render side-table. On rejoin to
the same server instance with unchanged gear, `pushFireworkState`'s fresh fingerprint would match
the stale one from the PREVIOUS session and the rebuild would be silently skipped — a tubeless
deck for the whole session while `muzzleOriginFor` keeps computing a muzzle position that has no
visible tube.

**Fix**: added `mortarRenderedFingerprint[uid] = nil` immediately after `playerEconomy[uid] = nil`
in that `PlayerRemoving` handler.

**Belt-and-braces, as requested**: `pushFireworkState`'s dirty-check now only *records* the
fingerprint (and only *triggers* the rebuild) when `e.claimedPadId ~= nil`. Previously it recorded
the fingerprint unconditionally whenever it differed from the cached value, even for an unclaimed
player — harmless in itself (there's no pad to render), but it meant "rendered with fingerprint X"
could get written down for a uid that never actually rendered anything, which is exactly the kind
of lie the rejoin bug came from in the first place. Now an unclaimed uid never touches the cache at
all, so the first fingerprint ever recorded for a uid is always one that came with a real rebuild.

## 2. IMPORTANT — `muzzleOriginFor` resolved against the wrong deck size

**Confirmed the exact inconsistency**: `muzzleOriginFor` called `deckRowFor(uid)`, which sources
`deckSize` as `e.maxDeckSize or "S"` (the player's OWNED max size, a raw lookup with a hardcoded
`"S"` fallback) — while the render path (`rebuildClaimedPad` → `TreatmentApplier`) and this SAME
function's own `teahouseFootprintFor` helper both resolve `built.deckSize` via
`SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)`
— which accounts for an active display-shrink (`SetDisplay`) and the pad's own size cap
(`spec.maxSize`). Under either of those, `deckRowFor`'s row/size and the render path's row/size
would genuinely diverge: the muzzle math would transform through the wrong deck-placement row AND
clamp/nudge against the wrong deck bounds, while `teahouseFootprintFor` in the exact same function
call would already be using the correct (`resolveBuilt`-derived) size — one function, two deck
sizes.

**Fix**: `muzzleOriginFor` now gets its `(row, deckSize)` pair from `deckCFForUid` — which already
does exactly `DeckPlacement.resolve(spec.deckPlacements, built.deckSize, spec.maxSize)` off
`SizeClasses.resolveBuilt`, the identical pair `rebuildClaimedPad`/`TreatmentApplier` render with.
`deckCFForUid` is declared textually AFTER `muzzleOriginFor`, so this uses the same
forward-declaration idiom `rebuildClaimedPadFn` already established: a new
`local deckCFForUidFn: ((string) -> ({number}?, string?))? = nil` near the other forward
declarations, assigned `deckCFForUidFn = deckCFForUid` immediately after `deckCFForUid`'s
definition.

**`deckSiteFor` deliberately left untouched**, per the controller ruling: it still calls
`deckRowFor` for its own site-radius check just above in the same function file. Confirmed by
reading it that this really is benign there — `deckSiteFor` only uses the row's `x`/`z` to test
whether the player is standing within `SITE_RADIUS` (24 studs) of the deck's nominal position, a
coarse admission check, not a placement transform; a few studs of row drift from a display-shrink
would not meaningfully change who gets admitted to their own deck as a launch site.

## 3. IMPORTANT — `SHELL_MORTAR` drift now gets CI enforcement

**Fixture change** (`shared-fixtures/firework-shells.json`, edited as text, no reformat
round-trip — verified with `python3 -m json.tool` afterward that it's still valid JSON): added a
`mortars` array of `{shell, mortar}` objects — the gear-required SUBSET of the existing `shells`
list (`peony`→`mortar:S`, `willow`→`mortar:M`, `kiku`→`mortar:S`; `firecracker`/`ishibana` are
absent, meaning "no gear requirement" on both sides) — plus a `mortarsComment` field explaining the
new list, following the existing `comment` field's convention. Chose an additive top-level key
over restructuring `shells` into objects, since the latter would have touched every existing
consumer of the flat `{shells: string[]}` shape (both suites' existing tests, plus
`FireworkCatalog.spec.luau`) for no benefit.

**TS side** (`server/src/fireworks.ts`, `server/src/fireworks.test.ts`): exported `REQUIREMENTS`
(previously module-private; nothing else referenced it outside the file, confirmed by grep) and
its `Requirement` type. Added a new `describe` block, TDD (fixture-first) as requested: three
tests — every fixture shell NOT in `mortars` must not have `kind: 'gear'` in `REQUIREMENTS`; every
fixture `mortars` entry must match `REQUIREMENTS` exactly; and (the reverse direction) no OTHER
shell in `REQUIREMENTS` may carry a `kind: 'gear'` that the fixture doesn't know about. Ran
`npm test` before writing the fixture change to confirm these would have failed against a
hypothetical un-synced `REQUIREMENTS` (mentally verified via the assertions' shape — the export was
the only change needed to make them compilable, and they immediately passed against the real,
already-in-sync `REQUIREMENTS`).

**Lune side** (`roblox/tests/fixtures/fireworkShells.luau`, `roblox/tests/MortarPlacement.spec.luau`):
extended the existing fixture loader to also decode and expose `mortars` (with its own `assert`
that the field exists, matching the loader's existing defensive style for `shells`). Added a new
`describe` block to `MortarPlacement.spec.luau` mirroring the TS side exactly: fixture entries
match `SHELL_MORTAR`; every non-gear fixture shell has no `SHELL_MORTAR` entry; no OTHER
`SHELL_MORTAR` entry is missing from the fixture.

**Comment updated** (`MortarPlacement.luau`'s `SHELL_MORTAR` header): replaced the "no test catches
that drift (there is no shared-fixtures file for this one)" caveat with a description of the actual
enforcement now in place, naming both spec files and the fixture. Checked `fireworks.ts` for a
similar caveat comment to update — found none (the drift-risk framing had only ever lived in the
Luau file) — so added a short pointer comment there instead, above the new `export`.

## Test / lint results (full output)

```
$ cd roblox && lune run tests/run
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom
(both pre-existing, unrelated -- that spec's own deliberately-full/erroring queue test cases)

1649 passed, 0 failed, 1649 total   (was 1645 before this round; +4 new MortarPlacement.spec tests)

$ stylua --check src tests tools
(no output — clean)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ cd server && npm test
 Test Files  20 passed (20)
      Tests  486 passed (486)   (was 483 before this round; +3 new fireworks.test.ts tests)

$ cd server && npm run build
> tsc
(exits 0 — clean compile, confirms the new REQUIREMENTS/Requirement exports type-check)
```

## Files changed (this round)

- `roblox/src/server/main.server.luau` — `deckCFForUidFn` forward declaration + assignment;
  `muzzleOriginFor` now resolves `(row, deckSize)` via `deckCFForUidFn` instead of `deckRowFor`;
  `pushFireworkState`'s fingerprint recording gated on `e.claimedPadId ~= nil`; `PlayerRemoving`
  clears `mortarRenderedFingerprint[uid]`.
- `roblox/src/shared/MortarPlacement.luau` — `SHELL_MORTAR`'s drift-caveat comment updated to point
  at the new fixture enforcement.
- `roblox/tests/MortarPlacement.spec.luau` — new `describe` block, 3 tests, asserting
  `SHELL_MORTAR` against the fixture bidirectionally.
- `roblox/tests/fixtures/fireworkShells.luau` — now also decodes/exposes `mortars`.
- `server/src/fireworks.ts` — `REQUIREMENTS` and `Requirement` exported, with a pointer comment.
- `server/src/fireworks.test.ts` — new `describe` block, 3 tests, asserting `REQUIREMENTS` against
  the fixture bidirectionally.
- `shared-fixtures/firework-shells.json` — new `mortars` array + `mortarsComment`.

## Self-review findings

- Re-ran both full suites + both lint commands + a TS build after all three fixes together (not
  just after each individual fix) — all clean, numbers above.
- Re-read the full `main.server.luau` diff for this round: confirmed `deckCFForUidFn` is assigned
  exactly once, right after the one and only `local function deckCFForUid` definition (grepped to
  make sure there wasn't a second definition anywhere); confirmed `deckSiteFor`/`deckRowFor`
  themselves have zero diff this round.
- Confirmed the `PlayerRemoving` handler I edited is the right one (grepped both matches; the first
  handles fates/roster/hud cleanup and has nothing to do with `playerEconomy`).
- Confirmed the fixture JSON is still valid (`python3 -m json.tool`) and that I edited it as text —
  no formatter was run over the file, only the `Edit` tool's exact string replacement.
- Confirmed `REQUIREMENTS`'s export doesn't cross the "client is never told a shell's requirement"
  line: this is a TS module export for test-time access only, never serialized into an HTTP
  response — `evaluateShell`'s existing external contract (`ShellState`, no `Requirement` in it) is
  unchanged.

## Concerns

None outstanding from this round. The two concerns carried over from the previous round's report
(mortars gated on `treatment.lit == true`; mortar geometry constants inline in
`TreatmentApplier.luau` rather than shared) are unchanged by this fix round and still apply.
