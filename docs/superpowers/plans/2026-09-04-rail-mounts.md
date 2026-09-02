# Rail Mounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mortars become aimable hardware — floor OR front-rail mounted, three aims in a 60° deck-front arc — and shells fly along the tube's visible axis.

**Architecture:** The placement record evolves to `{mount, offset, aim}` (reader-side legacy defaults). A pure `MortarPlacement.pose/launch` computes the tube's world pose and launch heading once; `TreatmentApplier` renders from it and the Studio server launches from it, so geometry and trajectory cannot drift. `FireworkLaunched` carries a server-computed `heading`; `FireworkController` generalizes its flight from "up" to "along heading". The editor's drop position decides the mount; rotate cycles the three aims.

**Tech Stack:** TypeScript + Vitest (`server/`), Luau (strict) + Lune harness (`roblox/`).

**Spec:** `docs/superpowers/specs/2026-09-04-rail-mounts-design.md`

## Global Constraints

- **Both mounts** (owner): `mount: 'floor' | 'rail'`; rail = FRONT rail only this round. The enum exists to grow (roof later).
- **Three aims** (owner): `aim: 'L' | 'C' | 'R'` — `C` = deck-front (local −Z; verified live 2026-09-04: Nobori on −Z, PortalControl on +Z). Sign convention, pinned: facing the canyon (LookVector −Z, RightVector +X), `L` yaws 30° toward −X, `R` toward +X.
- **Elevations are single tunables**: `ELEVATION = { floor = 12, rail = 25 }` degrees from vertical — owner tunes at the gate.
- **Legacy reads as `floor`/`C`**: stored records without `mount`/`aim` (and mortars with no record) keep today's spot and gain the canyon bias. `facing` on old records is ignored, tolerated by validators, never written by new code.
- **One pose, two consumers**: render and launch both read `MortarPlacement.pose/launch` — never derive tilt independently (the resolveFit rule).
- **`heading = nil` reproduces today's vertical flight exactly** — public sites, proving range, firecrackers unchanged.
- Rail geometry mirrors `PadOps`: cap top 2.75 above deck, cap width 0.45, `NEWEL_W = 0.45`; front edge is local minZ; cap outer face flush with the edge (cap center z = minZ + 0.225).
- Shared Luau modules pure `--!strict`, Lune-loadable. Lint from `roblox/`: `stylua --check src tests tools && selene src tools` — **read selene's FULL output; warnings fail CI**. Tests `lune run tests/run`; server `npm test` from `server/` (`nvm use` first if npm errors).
- ⚠ Boot-race rule (earned at the mortar gate, `d510c69`): NOTHING added to `main.server.luau` top-level bootstrap or `TreatmentApplier.new` may yield inline — the PlayerAdded handlers have no join catch-up (parked defect (k)).
- ⚠ PivotTo rule (earned, `9d3cd3c`): a model whose PrimaryPart carries rotation needs `PivotOffset = cframe:Inverse()` before `PivotTo`.
- No new RemoteEvents — `default.project.json` is untouched this round.
- Commit after each task, repo message style, trailers:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01Vw3EoAN2H4ZcRXNtu2mFco`.

## File Structure

| File | Responsibility |
|---|---|
| `server/src/loadout.ts` (modify) | validator accepts `mount`/`aim`, `facing` optional-legacy |
| `server/src/loadout.test.ts` (modify) | new-record + legacy-record cases |
| `roblox/src/shared/MortarPlacement.luau` (modify) | AIMS/ELEVATION/RAIL constants, mount-aware `resolve`, `pose`, `launch` (replaces `muzzleWorld`) |
| `roblox/tests/MortarPlacement.spec.luau` (modify) | pose/launch hand-checks, rail clamp, legacy defaults |
| `roblox/src/server/TreatmentApplier.luau` (modify) | render both mounts from `pose` |
| `roblox/src/server/main.server.luau` (modify) | `muzzleOriginFor` → origin+heading via `launch`; payload `heading`; handler accepts `mount`/`aim` |
| `roblox/src/client/FireworkController.client.luau` (modify) | flight along `heading` |
| `roblox/src/client/MoveController.client.luau` (modify) | drop-decides-mount, aim cycling, leaning ghost |

---

### Task 1: Backend validator — mount and aim

**Files:**
- Modify: `server/src/loadout.ts` (`validateMortarPlacements`, ~line 170)
- Test: `server/src/loadout.test.ts` (extend the `validateMortarPlacements` describe)

**Interfaces:**
- Consumes: existing `Check`, `MAX_PLACEMENT_OFFSET`, `PLACEMENT_FACINGS`.
- Produces: the validator accepts `{ offset, mount?, aim?, facing? }` per entry — `mount ∈ {'floor','rail'}` and `aim ∈ {'L','C','R'}` when present, `facing` legacy-optional (valid cardinal when present), allowed-key set now `offset|facing|mount|aim`, everything else rejected as today. Routes/model unchanged (Mixed field already carries arbitrary keys; PUT/GET shapes identical).

- [ ] **Step 1: Failing tests** — append inside the existing `describe('validateMortarPlacements', ...)`:

```ts
it('accepts the rail-mounts record shape (mount + aim, no facing)', () => {
    const v = { 'mortar:S': { offset: [2, -3], mount: 'rail', aim: 'L' } };
    expect(validateMortarPlacements(v, owned)).toEqual({ ok: true });
});
it('still accepts legacy records (facing, no mount/aim)', () => {
    const v = { 'mortar:S': { offset: [2, -3], facing: 'E' } };
    expect(validateMortarPlacements(v, owned)).toEqual({ ok: true });
});
it('rejects unknown mount, unknown aim, and still rejects unknown keys', () => {
    expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], mount: 'roof', aim: 'C' } }, owned).ok).toBe(false);
    expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], mount: 'rail', aim: 'X' } }, owned).ok).toBe(false);
    expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], aim: 'C', evil: 1 } }, owned).ok).toBe(false);
});
```

- [ ] **Step 2: Verify failure** — `npm test` from `server/`: FAIL (mount/aim rejected as unknown keys).
- [ ] **Step 3: Implement** — in `validateMortarPlacements`, beside the existing checks (mirror the file's idiom exactly):

```ts
const MORTAR_MOUNTS = new Set(['floor', 'rail']);
const MORTAR_AIMS = new Set(['L', 'C', 'R']);
```

Extend the per-entry allowed-key check to `offset|facing|mount|aim`. Make `facing` OPTIONAL: validate against `PLACEMENT_FACINGS` only when present. Add: `mount`, when present, must be in `MORTAR_MOUNTS` (else `{ ok: false, error: 'BAD_MOUNT' }`); `aim`, when present, must be in `MORTAR_AIMS` (else `{ ok: false, error: 'BAD_AIM' }`). Offset rules unchanged.

- [ ] **Step 4: Green + commit**

```bash
npm test
git add src/loadout.ts src/loadout.test.ts
git commit -m "feat(mortars): validator learns mount and aim -- facing goes legacy-optional"
```

---

### Task 2: MortarPlacement — mount-aware resolve, pose, launch

**Files:**
- Modify: `roblox/src/shared/MortarPlacement.luau`
- Test: `roblox/tests/MortarPlacement.spec.luau`

**Interfaces:**
- Consumes: nothing new (pure).
- Produces (exact names later tasks rely on):
  - `MortarPlacement.AIMS = { "L", "C", "R" }`
  - `MortarPlacement.ELEVATION = { floor = 12, rail = 25 }` (degrees from vertical, owner-tunable)
  - `MortarPlacement.RAIL = { capTop = 2.75, capWidth = 0.45, newelMargin = 0.95 }` (⚠ mirrors `PadOps` CAP_TOP/CAP_W/NEWEL_W — carry a drift-caveat comment; newelMargin = NEWEL_W + 0.5 breathing room)
  - `MortarPlacement.BASE_OFFSET = { floor = 0.5, rail = 0.35 }` (tube-bottom height above the mount point: timber base / rail saddle block)
  - `type Resolved = { mount: string, x: number, z: number, aim: string }`
  - `MortarPlacement.resolve(deckBounds, owned, stored?, teahouseFP?) → { [mortarId]: Resolved }` — same signature, richer rows. Floor path unchanged (defaults/clamp/nudge); a stored record with `mount = "rail"` resolves `x = clamp(offset[1], minX + newelMargin, maxX - newelMargin)`, `z = deckBounds.minZ + RAIL.capWidth / 2` (nudge never applies to rail — the teahouse cannot occupy the rail). Records without `mount`/`aim` → `mount = "floor"`, `aim = "C"`; `facing` ignored.
  - `MortarPlacement.axisLocal(mount: string, aim: string) → (number, number, number)` — the tube's deck-local unit axis: with `el = math.rad(ELEVATION[mount])` and `(ax, az) = AIM_DIR[aim]`, returns `(math.sin(el) * ax, math.cos(el), math.sin(el) * az)` where `AIM_DIR = { L = {-0.5, -0.8660254037844386}, C = {0, -1}, R = {0.5, -0.8660254037844386} }` (file-local).
  - `MortarPlacement.pose(deckRow, resolved, mortarId) → (mx, my, mz, axx, axy, axz)` — world mount point and world unit axis: mount local = `(resolved.x, mountY, resolved.z)` with `mountY = 0` for floor, `RAIL.capTop` for rail; both point and axis transformed through the 12-number row-major deck row (`world = pos + R * local` for the point; `R * axis` for the direction — same R-row convention `muzzleWorld` used).
  - `MortarPlacement.launch(deckRow, resolved, mortarId) → (ox, oy, oz, hx, hy, hz)` — muzzle origin = mount point + axis × (`BASE_OFFSET[mount]` + `TUBE[mortarId].length`); heading = the axis. **Replaces `muzzleWorld`, which is DELETED** (sole caller updated in Task 4; its old spec tests rewritten below).

- [ ] **Step 1: Failing spec** — REPLACE the `muzzleWorld` test block and APPEND to the describe (harness idiom `describe/test/expect(...).toBe`):

```lua
    test("legacy records and absent records resolve floor/C; rail records ride the cap", function()
        local stored = {
            ["mortar:S"] = { offset = { 2, -3 }, facing = "E" }, -- legacy: facing ignored
            ["mortar:M"] = { offset = { 40, 0 }, mount = "rail", aim = "R" },
        }
        local out = MortarPlacement.resolve(BOUNDS, ALL, stored, nil)
        expect(out["mortar:S"].mount).toBe("floor")
        expect(out["mortar:S"].aim).toBe("C")
        expect(out["mortar:S"].x).toBe(2)
        expect(out["mortar:L"].mount).toBe("floor") -- no record at all
        expect(out["mortar:M"].mount).toBe("rail")
        expect(out["mortar:M"].aim).toBe("R")
        expect(out["mortar:M"].x).toBe(BOUNDS.maxX - 0.95) -- newelMargin clamp
        expect(math.abs(out["mortar:M"].z - (BOUNDS.minZ + 0.225)) < 1e-9).toBe(true)
    end)

    test("axisLocal: C leans toward -Z by the mount's elevation; L/R yaw 30 degrees", function()
        local x, y, z = MortarPlacement.axisLocal("rail", "C")
        expect(math.abs(x) < 1e-9).toBe(true)
        expect(math.abs(y - math.cos(math.rad(25))) < 1e-9).toBe(true)
        expect(math.abs(z - (-math.sin(math.rad(25)))) < 1e-9).toBe(true)
        local lx, _, lz = MortarPlacement.axisLocal("floor", "L")
        expect(math.abs(lx - (-0.5 * math.sin(math.rad(12)))) < 1e-9).toBe(true)
        expect(lz < 0).toBe(true)
        -- always unit length
        local ux, uy, uz = MortarPlacement.axisLocal("rail", "R")
        expect(math.abs(ux * ux + uy * uy + uz * uz - 1) < 1e-9).toBe(true)
    end)

    test("launch: identity deck row, rail C -- muzzle sits up the tilted axis, heading matches", function()
        local row = { 100, 50, -20, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local resolved = { mount = "rail", x = 2, z = -5.775, aim = "C" }
        local ox, oy, oz, hx, hy, hz = MortarPlacement.launch(row, resolved, "mortar:L")
        local el = math.rad(25)
        local run = 0.35 + 2.5 -- BASE_OFFSET.rail + L tube length
        expect(math.abs(ox - 102) < 1e-9).toBe(true)
        expect(math.abs(oy - (50 + 2.75 + run * math.cos(el))) < 1e-9).toBe(true)
        expect(math.abs(oz - (-20 + -5.775 - run * math.sin(el))) < 1e-9).toBe(true)
        expect(math.abs(hx) < 1e-9).toBe(true)
        expect(math.abs(hy - math.cos(el)) < 1e-9).toBe(true)
        expect(math.abs(hz - (-math.sin(el))) < 1e-9).toBe(true)
    end)

    test("launch: 90-degree yaw deck row rotates both point and heading", function()
        -- same rotation rows the old muzzleWorld test used: local x -> world -z
        local rot = { 100, 50, -20, 0, 0, 1, 0, 1, 0, -1, 0, 0 }
        local resolved = { mount = "floor", x = 2, z = 0, aim = "C" }
        local _, _, oz, hx, hy = MortarPlacement.launch(rot, resolved, "mortar:S")
        local el = math.rad(12)
        -- local heading (0, cos el, -sin el): world x' = z*1 -> hx = -sin el... via R rows:
        -- x' = r4*lx + r5*ly + r6*lz = lz ; y' = ly ; z' = -lx
        expect(math.abs(hx - (-math.sin(el))) < 1e-9).toBe(true)
        expect(math.abs(hy - math.cos(el)) < 1e-9).toBe(true)
        -- point: local (2, mountY+..., 0) -> z' = -2 for the x component of the mount
        expect(oz < -20 + 1e-9 + 2.1 and oz > -25).toBe(true) -- mount x=2 maps toward -z of origin
    end)
```

(The last position assertion is deliberately a coarse band — the exact value is
`-20 - 2` for the mount point with a zero-z-component axis contribution; assert
`math.abs(oz - (-22)) < 1e-9` if implementing exactly as specified, and prefer that
tighter form.)

- [ ] **Step 2: Verify failure** — `lune run tests/run` (old muzzleWorld tests removed, new ones fail: fields/functions missing).
- [ ] **Step 3: Implement** per the Interfaces block. `resolve` keeps floor defaults/clamp/nudge byte-identical; rail records skip the nudge. Delete `muzzleWorld`.
- [ ] **Step 4: Green** — `lune run tests/run`.
- [ ] **Step 5: Lint (FULL output) + commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/MortarPlacement.luau tests/MortarPlacement.spec.luau
git commit -m "feat(mortars): mount-aware resolve, pose and launch -- the tube's axis is the trajectory"
```

---

### Task 3: TreatmentApplier — render both mounts from the pose

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau`

**Interfaces:**
- Consumes: `MortarPlacement.resolve` (richer rows), `pose`, `BASE_OFFSET`, `RAIL`, the hollow tube templates (unchanged), `mortarPart`, the PivotOffset discipline.
- Produces: leaning tubes on floor and rail that later tasks' launches visibly match.

Behavior contract:

1. `_buildMortars` reads the new `Resolved` rows. For each mortar, get the world pose from `MortarPlacement.pose(deckRow12, resolved, mortarId)` — but since the applier places models with `PivotTo(deckCF * localCF)`, the equivalent LOCAL composition is fine: build the model at origin, tilt it, and pivot to `deckCF * CFrame.new(resolved.x, mountY, resolved.z)`. The tilt: rotate the model so its local +Y aligns with `MortarPlacement.axisLocal(mount, aim)` (e.g. `CFrame.lookAlong`/`CFrame.fromMatrix` with the axis as up-vector, yaw-stable). State in the report which construction was used and why it agrees with `pose` (a spec-level requirement: render and launch share the axis math — do NOT re-derive angles from constants here).
2. **Floor mount** (`mount == "floor"`): timber base as today at the deck surface; the TUBE (and only the tube — the base stays flat) leans along the axis, tube bottom at `BASE_OFFSET.floor` above the mount point.
3. **Rail mount** (`mount == "rail"`): no timber base. A small clamp block (`Enum.Material.Wood`, `RAIL.capWidth + 0.2` square, 0.35 tall — `BASE_OFFSET.rail`) saddles the rail cap at the mount point (`mountY = RAIL.capTop` puts it atop the cap); the tube leans from the clamp's top along the axis.
4. Model naming/tagging/attributes unchanged (`Mortar_S/M/L`, tag `"Mortar"`, `padId`, `MortarId`); PrimaryPart = tube with the PivotOffset rule applied to whatever rotation it carries.
5. No new yields anywhere in the rebuild path (boot-race rule).

- [ ] **Step 1: Implement the contract.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/server/TreatmentApplier.luau
git commit -m "feat(mortars): tubes lean -- floor and rail renders drawn from the shared pose"
```

---

### Task 4: Studio server — heading in the payload, mount/aim through the handler

**Files:**
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `MortarPlacement.launch` (Task 2), the existing `muzzleOriginFor`/`deckCFForUid`/`teahouseFootprintFor` wiring, `SetMortarPlacement` handler, `FireworkLaunched` broadcast.
- Produces: `FireworkLaunched` payload gains `heading: { x, y, z }?`; stored mortar records gain `mount`/`aim`.

Behavior contract:

1. **`muzzleOriginFor` → origin AND heading**: rename/extend to return `(Vector3?, Vector3?)` — it already resolves the placement with the right bounds and teahouseFP; swap the `muzzleWorld` call for `MortarPlacement.launch` and return both the origin and the heading as Vector3s. Non-gear/public-site paths return `(nil, nil)`.
2. **Payload**: `FireworkLaunched:FireAllClients` gains `heading = heading and { x = heading.X, y = heading.Y, z = heading.Z } or nil`. Hand-firecracker and public-site launches send no heading (Global Constraint: nil = today's vertical flight).
3. **`SetMortarPlacement` handler**: payload gains `mount` and `aim` — validate `mount` in `{ "floor", "rail" }` and `aim` in `MortarPlacement.AIMS` (both REQUIRED in the new payload — the client always sends them; a payload missing either is rejected like any malformed payload). The stored record written to `e.mortarPlacements[mortarId]` becomes `{ offset = ..., mount = ..., aim = ... }` (no `facing`). Everything else (occupant gate, ownership, finite offsets, rebuild, persist via `net:putMortarPlacements`, fingerprint pre-seed, echo) unchanged.
4. No behavior change for decorations, public sites, proving, or firecrackers.

- [ ] **Step 1: Implement the contract.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/server/main.server.luau
git commit -m "feat(fireworks): launches carry a heading -- muzzle origin and axis from one pose"
```

---

### Task 5: FireworkController — flight along the heading

**Files:**
- Modify: `roblox/src/client/FireworkController.client.luau`

**Interfaces:**
- Consumes: `payload.heading` (Task 4), the existing flight code: `apex = origin + Vector3.new(rng(-8,8), 60 + rng(-6,6), rng(-8,8))` (~line 353), bezier `control = origin + Vector3.new(0, (apex.Y - origin.Y) * 0.9, 0)` (~line 433), bonus `apex = origin + (apex - origin) * Vector3.new(1, BONUS.apexScale, 1)` (~line 375).
- Produces: the generalized flight later shells inherit for free.

Behavior contract (exact formulas — generalize, do not fork):

1. `local dir = if payload.heading then Vector3.new(payload.heading.x, payload.heading.y, payload.heading.z).Unit else Vector3.new(0, 1, 0)` — computed once beside `origin`.
2. Apex: `apex = origin + dir * (60 + rng:NextNumber(-6, 6)) + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))` — same scatter magnitudes, axis-aligned run replaced by the heading run. With `dir = (0,1,0)` this is EXACTLY the current expression (same rng draw ORDER matters for cross-client determinism: keep the draws in the current order — height jitter first or lateral first, whichever the current code does — state it in the report).
3. Bonus: `apex = origin + (apex - origin) + dir * ((apex - origin):Dot(dir) * (BurstStyles.BONUS.apexScale - 1))` — stretches the along-heading component by apexScale, leaves scatter alone. With vertical dir this reproduces the old Y-scaling to within the scatter's tiny contribution; state the equivalence check in the report.
4. Bezier control: `local run = (apex - origin):Dot(dir)` then `control = origin + dir * (run * 0.9)` — with vertical dir this is byte-equivalent to the current vertical control.
5. Everything else (sound timing, muzzle flash at `origin`, trail, LOD) unchanged — they key off `origin` and the bezier, which is the point.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/client/FireworkController.client.luau
git commit -m "feat(fireworks): the arc follows the heading -- vertical stays the nil default"
```

---

### Task 6: Editor — the drop decides the mount, rotate cycles the aim

**Files:**
- Modify: `roblox/src/client/MoveController.client.luau`

**Interfaces:**
- Consumes: `enterMortar`/`startMove`/`stepDrag`/the R-rotate flow (`rotate()` with `FACING_ORDER`, 1-stud snap), `MortarPlacement.AIMS`/`axisLocal`/`RAIL`, deck bounds already derived in the drag flow, `SetMortarPlacement:FireServer` (payload from Task 4).
- Produces: the owner-facing mount/aim UX.

Behavior contract:

1. **Mortar drags carry `{ mount, aim }` state** seeded from the model's current render (read attributes if present, else `floor`/`C` — Task 3 may add `Mount`/`Aim` attributes to the built model for exactly this seed; if it did not, add them THERE, not here, and note it).
2. **The drop decides the mount**: at commit, if the ghost's deck-local `z <= deckBounds.minZ + 1.25` (`RAIL_SNAP_BAND = 1.25`, a local constant with a comment), the placement is `mount = "rail"`, `offset = { snappedX, 0 }`; otherwise `mount = "floor"`, `offset = { snappedX, snappedZ }` as today. While dragging inside the band, the ghost visibly snaps onto the rail cap (y to `RAIL.capTop`, z to the cap line) so the mount switch reads before the drop.
3. **R cycles `L → C → R`** on mortar drags (decorations/teahouse keep `FACING_ORDER`). The ghost's tilt updates from `MortarPlacement.axisLocal(mount, aim)` on every cycle AND on band enter/exit (elevation differs per mount).
4. Commit fires `SetMortarPlacement:FireServer({ mortarId = id, mount = mount, offset = offset, aim = aim })`. Cancel restores as today.
5. Decoration and teahouse flows byte-identical.

- [ ] **Step 1: Read the drag flow fully; implement.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/client/MoveController.client.luau src/server/TreatmentApplier.luau
git commit -m "feat(mortars): drop on the rail to mount it -- R cycles the three aims"
```

(The `TreatmentApplier.luau` in the add is for the `Mount`/`Aim` attribute seed if point 1 adds it there; omit if unchanged.)

---

### Task 7: Deploy, owner gate, wiki — MAIN SESSION ONLY

**Do not dispatch this task to a subagent.** Needs the owner, Studio, and AWS.

- [ ] **Step 1:** Push main; `aws apprunner start-deployment` on `roshambo_server_dev` (auto-deploy OFF); wait `SUCCEEDED`. (Backend change is Task 1 only — small, but the validator must be live before Studio writes mount/aim records.)
- [ ] **Step 2:** Rojo sync check (no project.json change this round), owner restarts Play.
- [ ] **Step 3: Owner gate:** tubes render leaning (floor 12°); drag one onto the front rail — it saddles the cap at 25°; R cycles L/C/R with the ghost leaning; fire all three aims — arcs fan the 60° arc out over the canyon and shells leave the tilted muzzles; a floor tube's shells lean too; firecracker/public sites unchanged; placements persist across Plays; **tune `ELEVATION` values live** to the owner's eye; visitor-view check if feasible. Carry-forward: the same-server rejoin check still awaits the published place.
- [ ] **Step 4:** Wiki: `fireworks.md` as-built paragraph + `log.md` entries (ship + any gate finds); note the elevation values the owner settled on. Commit docs.

---

## Self-Review (performed at write time)

- **Spec coverage:** §1 → T1 (validator) + T2 (resolve/legacy reader); §2 → T2 (pose) + T3 (render); §3 → T4 (heading) + T5 (flight); §4 → T6; §5 tests → T1/T2; gate + elevation tuning → T7. Both-mounts, three-aims, nil-heading-compat all in Global Constraints.
- **Placeholder scan:** T3/T4/T5/T6 are behavior contracts over runtime files (established house pattern, four successful precedents); each names exact symbols, constants, and formulas. T3 point 1 delegates one construction choice (how the model tilt is composed) and requires the report to state its agreement with `pose` — explicit delegation, not a TBD.
- **Type consistency:** `Resolved {mount, x, z, aim}` produced in T2, consumed in T3/T4; `launch` return order `(ox,oy,oz,hx,hy,hz)` matches T4's use; `AIMS`/`ELEVATION`/`RAIL`/`BASE_OFFSET` names consistent across T2/T3/T6; payload `{mortarId, mount, offset, aim}` identical in T4 handler and T6 FireServer; `heading` shape `{x,y,z}` identical in T4 send and T5 read.
- **Determinism note:** T5 pins rng draw order — the cross-client seed discipline from the vocabulary work.
