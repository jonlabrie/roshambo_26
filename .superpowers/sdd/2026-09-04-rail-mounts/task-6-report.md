# Task 6 report: Editor — the drop decides the mount, rotate cycles the aim

## Fix round 1 (review verdict: Approved with one Required + one optional Minor)

**Required — ineffective nil-guard in `retiltMortarGhost`** (was `:131-132`).
`local tube = typeof(mortarId) == "string" and MortarPlacement.TUBE[mortarId]` short-circuits to
the boolean `false` (not `nil`) when the ghost's `MortarId` attribute isn't a string, and the old
guard `if barrel == nil or tube == nil then return end` doesn't catch a `false` value — `tube ==
nil` is `false` when `tube` is `false` too, so execution would fall through to `tube.length` a few
lines later and throw. Latent in practice (a mortar ghost always carries a valid `MortarId`
attribute, cloned from the real built model), but the guard failed at exactly the case it was
named for. Fixed: `if barrel == nil or not tube then return end`, with a comment explaining the
short-circuit-to-`false` behavior so the next reader doesn't "simplify" it back.

**Optional Minor — redundant PivotTo work on the hot path.** `applyMortarGhost` calls
`g:PivotTo(pivot)`, whose barrel repositioning `retiltMortarGhost` immediately overwrites on the
very next line, every `RenderStepped` frame during a mortar drag. Per the coordinator's guidance
(comment, don't restructure the hot path for a micro-optimization), added a comment on the
`PivotTo` call explaining: it's still needed because it moves the *base block* (which
`retiltMortarGhost` never touches) to the new mount point; only the barrel's re-positioning work
inside it is redundant, and that's intentional rather than an oversight.

Verification: `lune run tests/run` → 1652 passed, 0 failed (unchanged); `stylua --check src tests
tools` → clean (ran `stylua` once to apply its own formatting to the new comments, then verified
`--check` clean); `selene src tools` → 0 errors, 0 warnings, 0 parse errors. Commit `6ed3d62` —
`fix(mortars): retiltMortarGhost's nil-guard now catches false, not just nil` — diff is `+11/-2`
in `MoveController.client.luau` only.

## Implementation per contract point

**Point 1 — mortar drags carry `{ mount, aim }` state, seeded from attributes.**
Added a file-scope `mortarState: { mount, aim }?` (nil for every non-mortar drag). Seeded in
`enterMortar` from `part:GetAttribute("Mount")`/`part:GetAttribute("Aim")`, defaulting to
`"floor"`/`"C"` when absent or not a recognized value (`table.find(MortarPlacement.AIMS, rawAim)`).
Passed into `startMove` via a new optional `descriptor.mortar` field; `startMove` sets/clears
`mortarState` accordingly, and `exit()` clears it on every exit path (cancel and commit both route
through `exit()`).

**Attribute-seed choice: attributes off `part`, not the event shape.** Task 3's
`TreatmentApplier._buildMortars` already stamps `Mount`/`Aim` onto the built model
(`src/server/TreatmentApplier.luau:415-417`), so `EventBus.MoveMortar`'s payload
(`{ padId, mortarId, part }`, unchanged in `DecorationController.client.luau:66`) needed no
widening — `enterMortar` reads the attributes directly off the `part` it already receives. No
event-shape change.

**Point 2 — the drop decides the mount; live band snap during drag.**
New `applyMortarGhost(g, m)`, called from `applyGhost()` when `mortarState ~= nil` (early return,
so the decoration/teahouse branch below is unreached and unchanged). Every frame (via the
existing `stepDrag` → `applyGhost()` RenderStepped loop): if the ghost's raw deck-local
`z <= deckFP.minZ + RAIL_SNAP_BAND` (new local constant, `1.25`, commented as the editor's own
snap tolerance, distinct from `MortarPlacement.RAIL`'s actual rail geometry) →
`mortarState.mount = "rail"`, x clamped to `[deckFP.minX + RAIL.newelMargin, deckFP.maxX -
RAIL.newelMargin]` (mirrors `MortarPlacement.resolve`'s own rail clamp exactly), z snapped to
`deckFP.minZ + RAIL.capWidth/2`, model elevated to `RAIL.capTop`. Otherwise
`mortarState.mount = "floor"` and it clamps exactly as before (`BuildingPlacer.clamp` against
`MortarPlacement.FOOTPRINT`), at `y = 0`.

At commit, the closure reads the live `mortarState` (not the initial seed — see below) and builds
the wire offset: `mount == "rail"` → `{ offset[1], 0 }` (the server never reads a rail's stored z;
`MortarPlacement.resolve` recomputes it from `RAIL.capWidth`); otherwise `{ offset[1], offset[2] }`
as today.

**Point 3 — R cycles `L → C → R` on mortar drags only; tilt updates on cycle and band enter/exit.**
`rotate()` gets an early-return branch for `mortarState ~= nil` that cycles
`MortarPlacement.AIMS` and calls `applyGhost()`; the existing `FACING_ORDER` loop below is
untouched and unreached for mortars. Tilt: new `retiltMortarGhost(g, pivot, mount, aim)`,
mirroring `TreatmentApplier.buildMortarModel`'s own construction (`center = axis * (baseOffset +
tube.length/2)`, orientation from a local `tubeOrientation` mirror, `barrel.CFrame = pivot *
localCF`, `barrel.PivotOffset = localCF:Inverse()` so the model's pivot stays exactly `pivot`
after retilting — verified algebraically: `GetPivot() = barrel.CFrame * PivotOffset = (pivot *
localCF) * localCF:Inverse() = pivot`). Called unconditionally at the end of every
`applyMortarGhost` invocation, i.e. every frame during a mortar drag — this covers both an
explicit aim cycle (point 3's "every cycle") and a band enter/exit (elevation/mount change) without
separate change-tracking, since it just re-derives from the current `mortarState` each time.

**Ghost-tilt construction choice.** `TreatmentApplier.tubeOrientation` is a private local function
in a server file; a `.client.luau` can't `require` across the server/client boundary. Per the
brief's allowance, added a small local mirror (`tubeOrientation`, 10 lines) in `MoveController`
with a comment naming `TreatmentApplier.luau` as the source of truth. `MortarPlacement.axisLocal`,
`.BASE_OFFSET`, `.TUBE`, `.RAIL` are all consumed from the shared module as-is — no re-derived
geometry.

**Point 4 — commit payload.** `SetMortarPlacement:FireServer({ mortarId, mount, offset, aim })`,
matching Task 4's server handler (`src/server/main.server.luau:2813-2869`) exactly — verified
against its validation (`mount ~= "floor" and mount ~= "rail"` rejects; `AIMS` membership check;
`offset[1]`/`offset[2]` read as `dx`/`dz`).

**Point 5 — decoration/teahouse untouched.** Every mortar-specific branch is an early-return guard
ahead of the pre-existing code (`applyGhost`, `rotate`, `enterMortar`'s facing line replaced with a
2-value capture — same `facingFromPivotOf` call, third return now discarded since mortars never
use a facing). `enterTeahouse`/`enterDecoration` and their `commit` closures are byte-for-byte
unchanged.

## Test / lint results

```
$ lune run tests/run
[WARN] [QUEUE] dropping request for u: queue full (8)     <- pre-existing HandlerQueue.spec fixture noise, unrelated
[WARN] [QUEUE] handler error for u: .../tests/HandlerQueue.spec:80: boom  <- same
1652 passed, 0 failed, 1652 total

$ stylua --check src tests tools
(clean, no output)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

`.client.luau` is untested by design (no test references `MoveController`); the suite result
confirms no regression elsewhere. `selene` and `stylua` both scan `src/client` and passed clean on
the new code, including strict-mode type annotations.

## Files changed

- `roblox/src/client/MoveController.client.luau` (only file in the commit; +132/-5)
  - Added: `mortarState`, `RAIL_SNAP_BAND`, local `tubeOrientation` mirror, `retiltMortarGhost`,
    `applyMortarGhost`.
  - Modified: `applyGhost` (mortar early-return branch), `rotate` (mortar early-return branch),
    `exit` (clears `mortarState`), `startMove` (seeds `mortarState` from `descriptor.mortar`),
    `enterMortar` (reads `Mount`/`Aim` attributes, builds the `mortar` descriptor field, new
    commit closure reading live `mortarState`).
- `roblox/src/server/TreatmentApplier.luau` — **not touched**; Task 3 already added the
  `Mount`/`Aim` attribute seed (`model:SetAttribute("Mount", r.mount)` /
  `model:SetAttribute("Aim", r.aim)`, lines 416-417), so nothing here needed to change.

Commit: `2245335` — `feat(mortars): drop on the rail to mount it -- R cycles the three aims`

## Self-review findings

- Verified the `PivotOffset` algebra for `retiltMortarGhost` by hand (see above) — the model's
  `GetPivot()` stays exactly the `pivot` value passed in immediately after retilting, so a
  subsequent frame's `PivotTo` (translation-only, since the model's rotation stays identity) keeps
  landing correctly.
- Verified `applyMortarGhost`'s rail-branch x-clamp mirrors `MortarPlacement.resolve`'s server-side
  rail clamp exactly (same `RAIL.newelMargin` bounds against the same `deckFP`), so the client
  preview and the eventual server-authoritative rebuild can't disagree about where a rail mortar
  can sit in X.
- Verified the commit payload against `main.server.luau`'s `SetMortarPlacement.OnServerEvent`
  handler field-by-field (`mortarId`, `mount`, `offset` as `{dx,dz}`, `aim`), including that a
  rail's `offset[2]` is genuinely unread server-side (`resolve`'s rail branch never touches
  `override.offset[2]`), so sending `0` there is inert, not a lossy simplification.
- Confirmed `enterMortar`'s `facingFromPivotOf(part, m)` still returns `(0,0,"N")`-equivalent
  rotation for a real mortar's pivot (since `TreatmentApplier._buildMortars` places mortars via
  `deckCF * CFrame.new(x, mountY, z)` — translation only, no rotation component), so discarding
  the third return value and hard-coding `initialFacing = "N"` is not a behavior change from what
  the discarded value would have computed anyway; it's just no longer silently relied upon.

## Concerns

- **Ghost base geometry doesn't swap with mount during a live drag.** The ghost's base/clamp block
  (the "Base" timber block for floor vs. "Clamp" wood block for rail — different height *and*
  shape, `TreatmentApplier.buildMortarModel` lines ~315-340) is never rebuilt during the drag; only
  the barrel retilts and the whole model's `y` elevates for the rail band. So a rail-snapped ghost
  shows the floor-style base block hovering at clamp height rather than a saddle-shaped clamp,
  until commit triggers the server rebuild that replaces the model with correctly built geometry.
  This is a cosmetic-only gap in the *preview*, not a placement-correctness issue — the brief's
  ghost-tilt guidance scoped this to "tilt" specifically, and rebuilding the base geometry client-
  side would mean duplicating `buildMortarModel`'s block-construction code (not just the six-line
  `tubeOrientation` idiom it explicitly permitted mirroring). Flagging in case the owner wants a
  follow-up polish task; did not treat it as in scope for this task.
- No other concerns; test suite, stylua, and selene are all clean, and the diff is scoped to the
  one file the brief named.
