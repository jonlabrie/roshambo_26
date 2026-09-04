### Task 4: Studio server — state carriage, SetMortarPlacement, muzzle-true launches

**Files:**
- Modify: `roblox/default.project.json` (AS TEXT: one line in `RoshamboRemotes`, beside `SetDecorationPlacement`): `"SetMortarPlacement": { "$className": "RemoteEvent" },`
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `MortarPlacement.resolve/muzzleWorld/MORTAR_ORDER` (Task 2), `net:putMortarPlacements` (Task 3), `deckSiteFor`/`PadSites`/`DeckPlacement` (existing), the fireworks GET's new `mortarPlacements`.
- Produces: per-player mortar state the client render (Task 5) and editor (Task 6) read; deck launches from the required tier's muzzle.

Behavior contract (this file is runtime-only; decisions already live in Task 2's tested module):

1. **State**: wherever the fireworks GET result is consumed (`pushFireworkState` and the economy bootstrap that stores `e.deckDecorations`), stow `e.mortarPlacements` (raw stored map, may be nil) and `e.mortars` if not already held. Extend the SAME state tables that carry `deckDecorations` to clients (the ~line 1088/1424 tables) with `mortarPlacements = e.mortarPlacements` and `mortars = e.mortars` — visitors render every deck's mortars, exactly like decorations.
2. **`SetMortarPlacement` handler**: mirror `SetDecorationPlacement`'s shape (occupant-only, payload validation: `mortarId` in `MortarPlacement.MORTAR_ORDER` AND in `e.mortars`; `offset` two finite numbers; `facing` N/E/S/W). Update the in-memory map, echo the same client-facing state event the decoration flow echoes, then persist via `net:putMortarPlacements` on the handlerQueue (full-map PUT, decoration discipline: optimistic local, reconciled by the echo).
3. **Launch origin**: in `RequestFireworkLaunch`, after `LaunchSites.isValid` passes — when the valid site is the player's OWN deck (`deckSiteFor(uid)` matched) AND the shell's requirement is gear (consult the fireworks state's `reason`-free launchable data the server already holds, or simply: shell id has a mortar requirement per a small shared mirror — implementer's choice, stated in the report), compute origin = `MortarPlacement.muzzleWorld(deckRow, resolvedPlacement, requiredMortarId)` where `deckRow` is the same `spec.deckPlacements` row `deckSiteFor` reads and `resolvedPlacement` comes from `MortarPlacement.resolve` with the deck's bounds + stored map. `firecracker` and public-site launches keep `root.Position + Vector3.new(0, 6, 0)`.
4. ⚠ The required-tier mapping lives server-side in TS (`REQUIREMENTS`); the Studio server knows only `reason` strings. Add the minimal honest mirror: `MortarPlacement.SHELL_MORTAR: { [string]: string }` in Task 2's module — `{ peony = "mortar:S", willow = "mortar:M", kiku = "mortar:S" }` — with the drift caveat comment, and a line in this task's report flagging that promotion of a gear shell now touches that table too (the ShellDisplay lesson, pre-empted).

- [ ] **Step 1: project.json line (text Edit).**
- [ ] **Step 2: Implement the contract.** (Task 2 must first gain `SHELL_MORTAR` — do that edit + a two-line spec test as part of THIS task, since Task 2 may already be reviewed: test that every `SHELL_MORTAR` value is in `MORTAR_ORDER`.)
- [ ] **Step 3: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add default.project.json src/server/main.server.luau src/shared/MortarPlacement.luau tests/MortarPlacement.spec.luau
git commit -m "feat(mortars): server state carriage, SetMortarPlacement, muzzle-true deck launches"
```

---

