## Task 7: Server — region backstop (teleport-back / eviction)

**Files:**
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `AccessPolicy.canEnter`, `AccessGates.evictionPoint`, `deckCFForUid`, `isFriend`, `SizeClasses.deckFootprint` (existing).
- Produces: a background loop that PivotTo's a disallowed player out of any occupied deck region.

- [ ] **Step 1: Add the backstop loop**

Add near the end of `main.server.luau` (after the `portalController:start()` block, before/after the coordinator poll loop):

```lua
-- Access backstop: the authoritative half of enforcement. Every ACCESS_TICK seconds, for each
-- occupied deck, teleport back any player standing on it who is not allowed in (canEnter=false).
-- Catches side jump-ins, exploiters who nulled a local gate, and eviction when a mode flips /
-- an invite is revoked. Owner + allowed guests are never moved. Uses deck-LOCAL bounds so it
-- follows the deck's rotation.
local ACCESS_TICK = 0.3
task.spawn(function()
    while true do
        task.wait(ACCESS_TICK)
        -- snapshot occupied decks once per tick
        for _, owner in Players:GetPlayers() do
            local ouid = tostring(owner.UserId)
            local e = playerEconomy[ouid]
            if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
                continue
            end
            local deckCF12, deckSize = deckCFForUid(ouid)
            if deckCF12 == nil or deckSize == nil then
                continue
            end
            local fp = SizeClasses.deckFootprint(deckSize)
            local deckCF = CFrame.new(table.unpack(deckCF12))
            local evictCF = CFrame.new(table.unpack(AccessGates.evictionPoint(deckCF12, deckSize)))
            for _, viewer in Players:GetPlayers() do
                if viewer == owner then
                    continue -- owner is always allowed; never evict
                end
                local char = viewer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root == nil then
                    continue
                end
                -- is the viewer standing within this deck's footprint (deck-local), within a height band?
                local rel = deckCF:PointToObjectSpace(root.Position)
                if rel.X < fp.minX or rel.X > fp.maxX or rel.Z < fp.minZ or rel.Z > fp.maxZ then
                    continue
                end
                if rel.Y < -2 or rel.Y > AccessGates.GATE_H then
                    continue -- far below/above the deck plane: not on this deck
                end
                local friend = if e.teahouseAccess.mode == "friends" then isFriend(viewer, owner.UserId) else false
                if not AccessPolicy.canEnter(e.teahouseAccess.mode, e.teahouseAccess.invited, viewer.UserId, owner.UserId, friend) then
                    char:PivotTo(evictCF)
                end
            end
        end
    end
end)
```

- [ ] **Step 2: Verify + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && rojo build -o /tmp/ac-t7-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): access region backstop (teleport-back eviction)"
```

---

