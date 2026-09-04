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

