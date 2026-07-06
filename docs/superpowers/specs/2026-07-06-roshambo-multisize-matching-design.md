# Roshambo Multi-Size Fit Matching — Design (sub-project D, increment 3)

**Status:** design approved in brainstorm (2026-07-06); pre-planning. Third increment of sub-project D — runtime materialization. Roblox-side; pure modules Lune-tested, Studio applier proven by a two-pad visual gate.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** D.2 (`afa62ac..7593a3c`) drives a single size — `onJoin` claims the first vacant pad via `claimVacant` and materializes the player's `M` loadout. D.3 makes it **multi-size**: a player owns teahouses across size classes (C.1 already stores `teahouses` as a `{sizeClass → loadout}` map), pads differ in footprint, and a joining owner gets the **largest owned size that fits a vacant pad**, falling back smaller. It generalizes B.4's `PadRegistry:claimVacantFor`/`fits` (single-footprint, unused until now) and adds the size-class definitions C.1 deferred.

**Proxy note (explicit):** we have exactly one prefab (`teahouse-1story`). D.3 represents size classes as a **scale factor** on it (a testing proxy) — the destination is **authored per-size prefabs**. The design isolates the proxy so the swap is a substitution, not a rewrite: the only proxy-specific element is the `scale` field (and one `Model:ScaleTo` call). With authored prefabs, `scale → 1` and each size's *stored* loadout points at its authored `baseStyle`; the matching, the pad footprints, the per-size loadouts, and all wiring are unchanged.

## Problem

D.2's `SiteCoordinator:onJoin(playerId, ownedLoadout)` takes a single loadout and claims the first vacant pad regardless of size. But:

- A player owns a **set** of sizes (`{S, M, L}`), stored per size class in C.1's `User.teahouses` map.
- Pads differ in footprint; a large teahouse must not land on a pad too small for it.
- The runtime should show the player their **biggest** teahouse that fits an available pad, falling back to a smaller size when the big pads are taken or the pad is small (the C.1 spec's stated behavior).

B.4 already provides the primitives — `PadRegistry.fits(padFP, structFP)` (containment) and `PadRegistry:claimVacantFor(owner, structFP)` (first vacant pad that fits a footprint) — but nothing defines the size classes or drives multi-size selection. D.3 supplies both.

## Goals

- A pure **`SizeClasses`** module: the single definition of `S/M/L` (footprint + proxy `scale`) and `nativeSize(padFootprint)` (a pad's largest fitting class).
- Generalize **`SiteCoordinator:onJoin`** to take the whole owned-sizes map and pick the largest owned size that fits a vacant pad (size-first, first-fit, falling back smaller); the `Action` carries the chosen `scale`.
- **`TreatmentApplier`** applies `Model:ScaleTo(scale)` after building (no-op at `scale == 1`).
- Two pads of **different footprints** so fit matters; a vacant pad's dormant structure renders at its `nativeSize`.
- Proven by Lune tests (matching + fallback + native size) and a two-pad visual gate (a large claimed teahouse + a small dormant one).

## Non-goals (later)

- **Authored-tier prefabs** (entry tent → 1-story → multi-story) — the art the proxy stands in for; a later art pass / E. This design is built for that swap.
- **Best-fit pad selection** — D.3 keeps B.4's first-fit (registration order); best-fit (smallest sufficient pad) is a future refinement.
- **Perch preference** (D.4); **garden applier / real perch survey / migration** (D.5).
- Visual demonstration of *fallback* — solo Studio Play has one joiner claiming one pad, so fallback (owning L but only M fitting) is Lune-tested, not shown (same limit as D.2's release).

## Architecture

Same pure-brain / Studio-applier split. Sizes live in one pure module; the coordinator picks a size; the applier scales the built structure. All new pure modules are Lune-loadable, so the pure-module requires (`SizeClasses` → `PadRegistry` for `fits`; `SiteCoordinator` → `VacantState` + `SizeClasses`) are allowed under the DI rule; the `PadRegistry` **instance** stays injected.

### Size model & the S=base decision

`teahouse-1story`'s captured footprint is the **base**: `{ minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 }`. The current teahouse is the **smallest** size, so **S is the base**, and **L is 2× S** (a clear 2× contrast, per the design decision):

```
S: scale 1.0   (today's teahouse)
M: scale 1.5
L: scale 2.0
```

Size-class footprint = `base × scale` (scaled about the datum pivot, matching `Model:ScaleTo`). L's footprint is therefore `2 × base` (~45 × 32 studs), which spreads support posts wider than the base layout — so the L pad needs a location with terrain under the larger footprint. **MCP-verified 2026-07-06:** at `cliff-proof-2`'s location `(-130, 240, 125)` the `2×base` footprint lands **6/6 posts** (lengths 3–48); the base footprint at `cliff-proof` `(-60, 274, 105)` lands 6/6 (6–47).

`Model:ScaleTo(scale)` scales the model about its pivot (the datum / floor-underside), so the floor stays on the pad and the structure scales upward. Because each size's footprint **equals its pad's footprint** (S→base pad, L→2×base pad), the floor is flush on the posts at every size — no overhang.

### Component 1 — `SizeClasses.luau` *(src/shared, pure, Lune-tested)*

```lua
SizeClasses.BASE_FOOTPRINT = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 }
SizeClasses.order = { "L", "M", "S" }          -- largest first
SizeClasses.scale = { S = 1.0, M = 1.5, L = 2.0 }   -- S = today's teahouse (base); L = 2x S

SizeClasses.footprintFor(sizeClass: string) -> Footprint   -- BASE_FOOTPRINT * scale[sizeClass]
SizeClasses.nativeSize(padFootprint: Footprint) -> string? -- first class in `order` whose footprintFor fits padFootprint (via PadRegistry.fits); nil if none
```

`nativeSize` requires `PadRegistry` only for the static `PadRegistry.fits` (pure). `scale`/footprints are the only place sizing is defined.

### Component 2 — `SiteCoordinator` changes *(pure, Lune-tested)*

`onJoin(playerId, ownedTeahouses)` — `ownedTeahouses` is the full `{sizeClass → loadout}` map (nil/empty for a wanderer):

```
if the player already holds a pad -> nil          (double-join guard, unchanged)
for _, size in SizeClasses.order do               -- L, then M, then S
    local loadout = ownedTeahouses and ownedTeahouses[size]
    if loadout then
        local claim = registry:claimVacantFor(playerId, SizeClasses.footprintFor(size))
        if claim then
            record hold; return {
                padId = claim.id, spec = claim.spec,
                treatment = VacantState.resolve(playerId, loadout, claim.spec.vacantForm),  -- lit
                scale = SizeClasses.scale[size], sizeClass = size,
            }
        end
    end
end
return nil                                         -- owns nothing that fits any vacant pad
```

`onLeave(playerId)` and `vacantActions()` gain a **dormant scale = the pad's `nativeSize` scale** (a big pad reverts to a big dormant shell, a small pad to a small one): `local native = SizeClasses.nativeSize(spec.footprint); scale = native and SizeClasses.scale[native] or 1`. `Action` type gains `scale: number` and optional `sizeClass: string?`.

### Component 3 — `TreatmentApplier:apply` change *(Studio-only)*

Signature gains `scale`: `:apply(padId, spec, treatment, scale)`. After a successful `structureBuilder.build(...)` and before the shutter/parent:

```lua
if scale ~= nil and scale ~= 1 then
    model:ScaleTo(scale)
end
```

`buildSupport` is unchanged (posts come from the pad's own footprint). Everything else (transactional swap, shutter-when-dormant) is unchanged.

### Component 4 — `PadSites` (two differing footprints)

- `cliff-proof` — the **small** pad: footprint = base = `{ minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 }` (fits **S** only; `nativeSize` = S). mountCF `{ -60, 274, 105, … }` unchanged.
- `cliff-proof-2` — the **large** pad: footprint = `2 × base` = `{ minX = -14.80, maxX = 30.00, minZ = -23.40, maxZ = 8.64 }` (fits **L**, M, S; `nativeSize` = L). mountCF `{ -130, 240, 125, … }` unchanged; MCP-verified 6/6 at this location for the 2×base footprint (re-confirm during the build).

**Register `cliff-proof-2` (large) first** so the sole local joiner claims it with L; `cliff-proof` (small) stays dormant at S. (The `-2` id is a D.2 artifact; keeping the ids avoids churn — only the registration order and footprints change.)

### Component 5 — `main.server` wiring

Register the large pad first — `for _, id in { "cliff-proof-2", "cliff-proof" }` (D.2 registered them in the opposite order). Pass the **whole** teahouses map to `onJoin` (not `.M`): `local owned = if res.ok then res.data.teahouses or {} else nil`; `siteCoordinator:onJoin(tostring(player.UserId), owned)`. Every `applier:apply(...)` call site adds `action.scale` — the startup `vacantActions` loop, the join path, the leave path, and the leave-during-join release path (D.2 fix).

## Data flow / gate

```
seed local player: teahouses = { S=<loadout>, M=<loadout>, L=<loadout> }  (vermilion)
startup:  cliff-proof-2 (big) -> dormant @ nativeSize L (scale 2.0);  cliff-proof (small) -> dormant @ nativeSize S (scale 1.0)
join:     onJoin tries L -> fits cliff-proof-2 (registered first) -> claim, lit, scale 2.0
result:   cliff-proof-2 = 2x lit L teahouse;  cliff-proof = current-size dark dormant S shell
```

The 2× size difference proves scale-materialization + fit. Fallback (owning L but a pad fitting only M) is Lune-tested.

## Testing

- **Lune — `SizeClasses.spec.luau`**: `footprintFor` scales the base per class (S=base, L=2×base); `nativeSize` returns S for a base pad, L for a `2×base` pad, nil for a pad smaller than S; `order`/`scale` values.
- **Lune — `SiteCoordinator.spec` additions**: `onJoin` picks the largest owned size that fits (owns {S,M,L} + a `2×base` pad → L, scale 2.0); **fallback** — with a single vacant pad of footprint `1.6×base` (fits M at 1.5×, not L at 2×): a player owning only {L} → nil (L doesn't fit, no smaller size owned), and a player owning {L,M} → claims **M** (scale 1.5, L skipped because it doesn't fit); a wanderer (nil/empty map) → nil; two owners take two differently-sized pads; the chosen `scale`/`sizeClass` ride in the Action; `vacantActions`/`onLeave` carry the pad's native-size scale. (Existing D.2 `SiteCoordinator` tests updated to pass a `{M=loadout}` map instead of a bare loadout, and to register pads with real base-sized footprints — the D.2 helper used `footprint = {}`, which `claimVacantFor` can't match against.)
- **Visual gate (two pads, ONE attempt then stop):** seed the local player {S,M,L}; Play → `cliff-proof` = full-size lit L teahouse, `cliff-proof-2` = small dormant S shell; console shows the chosen size class. Release/fallback are Lune-covered.

## v1 deliverables

1. `roblox/src/shared/SizeClasses.luau` + `roblox/tests/SizeClasses.spec.luau`.
2. `roblox/src/shared/SiteCoordinator.luau` — multi-size `onJoin`, native-size dormant scale, `Action.scale`/`sizeClass` (+ `SiteCoordinator.spec` updates).
3. `roblox/src/server/TreatmentApplier.luau` — `apply(...scale)` + `ScaleTo`.
4. `roblox/src/server/PadSites.luau` — `cliff-proof-2` footprint → `2×base` (large); `cliff-proof` stays base (small).
5. `roblox/src/server/main.server.luau` — register `cliff-proof-2` first; pass the full map to `onJoin`; thread `scale` through every `apply` call site.

## Build order

TDD `SizeClasses` (Lune) → generalize `SiteCoordinator:onJoin` + native-size dormant scale, updating the D.2 specs to the map form + real footprints (Lune) → add `scale` to `TreatmentApplier:apply` (Studio) → set `cliff-proof-2` footprint to `2×base` + MCP-verify 6/6 → wire `main.server` (register big-first + full map + scale threading) → seed the local player {S,M,L} → two-pad visual gate → stop for user review.
