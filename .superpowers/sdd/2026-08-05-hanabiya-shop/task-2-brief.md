### Task 2: Buying a shell refreshes the count

Closes spec §6b. `RequestPurchase` echoes `EconomyState` so points update, but nothing pushes `FireworkState` — a player would buy a peony, watch their balance drop, and see the picker still reading ×0 until the next reveal.

**Files:**
- Modify: `roblox/src/server/main.server.luau` (the `RequestPurchase.OnServerEvent` handler)

**Interfaces:**
- Consumes: `pushFireworkState(player: Player)`, already defined in this file by the fireworks referee.
- Produces: nothing new. `FireworkState` fires after a firework or mortar purchase.

- [ ] **Step 1: Find the purchase handler's success path**

Run from `roblox/`:

```bash
grep -n "RequestPurchase.OnServerEvent" -A 40 src/server/main.server.luau | grep -n "echoEconomy"
```

The handler ends its success path with an `echoEconomy(player, uid)` call. That is the anchor.

- [ ] **Step 2: Push firework state after a firework or mortar purchase**

Immediately after that `echoEconomy(player, uid)` inside the `RequestPurchase` handler, add:

```lua
            -- Buying a shell changes a COUNT, and the count lives in FireworkState, not
            -- EconomyState. Without this the balance drops and the picker keeps reading the old
            -- number until the next reveal happens to push state for its own reasons — which
            -- reads as the purchase having failed.
            if typeof(item) == "string" and (item:sub(1, 9) == "firework:" or item:sub(1, 7) == "mortar:") then
                if pushFireworkState then
                    pushFireworkState(player)
                end
            end
```

`item` is the handler's existing local holding the requested item string. If it is named differently in the handler, use that name — do not introduce a second local.

- [ ] **Step 3: Run every gate**

Run from `roblox/`:

```bash
stylua src tests tools && stylua --check src tests tools && selene src tools && lune run tests/run
```

Expected: clean, zero warnings, all tests pass. **Note what this does and does not prove:** no harness loads `main.server.luau`. Green means nothing regressed elsewhere; the behaviour is a Studio-gate item.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "fix(roblox): buying a shell refreshes the count, not just the balance"
```

---

