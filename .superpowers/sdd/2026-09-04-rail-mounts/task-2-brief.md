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

