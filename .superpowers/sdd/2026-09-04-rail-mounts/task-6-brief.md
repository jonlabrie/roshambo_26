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

