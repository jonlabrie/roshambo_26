### Task 3: NetworkClient — placements out and back

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau`

**Interfaces:**
- Consumes: the backend routes from Task 1.
- Produces: `NetworkClient.putMortarPlacements(self, robloxUserId: string, placements: { [string]: any }): Result` (PUT `/players/{id}/mortar-placements`, body `{ placements = placements }`); `getFireworks`'s decoded result now includes `mortarPlacements` (no change needed if the method returns the decoded body as-is — verify and state which in the report).

- [ ] **Step 1: Read the file's existing PUT method** (the decorations one) and mirror it exactly — same retry/error idiom, name `putMortarPlacements`.
- [ ] **Step 2: Verify `getFireworks` passes the whole decoded body through** (it should — it returns `res.data`); if any field-picking exists, add `mortarPlacements`.
- [ ] **Step 3: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/server/NetworkClient.luau
git commit -m "feat(mortars): NetworkClient.putMortarPlacements + GET passthrough"
```

---

