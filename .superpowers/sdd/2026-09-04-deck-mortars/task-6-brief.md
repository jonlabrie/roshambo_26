### Task 6: Back-door editor — move-only gear

**Files:**
- Modify: `roblox/src/client/BackDoorController.client.luau`

**Interfaces:**
- Consumes: Task 5's `MortarId`-attributed Models, the `SetMortarPlacement` remote (Task 4), the editor's existing decoration move flow.
- Produces: the owner-facing placement UX.

Behavior contract:
- Mortars join the editor's movable set with the decoration DRAG/rotate flow, firing `SetMortarPlacement:FireServer({ mortarId = id, offset = { x, z }, facing = f })` on drop.
- NO remove/sell affordance for mortars: whatever prompt/action the decoration flow shows for removal is absent on a `MortarId` model. Move and rotate only.
- The 24-cap display logic ignores mortars entirely.

- [ ] **Step 1: Read the editor's decoration flow fully; implement.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/client/BackDoorController.client.luau
git commit -m "feat(mortars): back-door editor moves gear -- drag and rotate, never remove"
```

---

