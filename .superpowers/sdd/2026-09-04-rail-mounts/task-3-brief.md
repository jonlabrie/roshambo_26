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

