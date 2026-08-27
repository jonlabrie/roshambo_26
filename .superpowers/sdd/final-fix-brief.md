# Final-review Critical fix — decouple buy-auto-move from the built instance

## The bug (from the whole-feature review)

A newly-bought decoration is minted server-side at `offset:[0,0]` (deck center). On a deck that owns a teahouse, the teahouse is also centered (`CENTERED_PLACEMENT = {0,0}`), so `DecorationLayout.resolve` marks the new prop `visible=false` → `TreatmentApplier._buildDecorations` skips it → **no `Decoration`-tagged Model ever appears**. `DecorationController`'s auto-move waits (`pendingAutoMoveId`) for that tagged instance, which never comes → the ghost-drag never starts. The player has spent points + a cap slot on an invisible, unreachable prop.

## The fix (realizes the spec's stated "buy → ghost-drag place" flow)

Make the buy **enter ghost-drag immediately**, independent of whether the built instance exists/is visible. The `SetDecorationPlacement` server handler already operates on the **stash** (finds the prop by id in `e.deckDecorations`), not on rendered instances, so committing a ghost-drag for a currently-hidden prop correctly repositions it and the rebuild renders it at the new (visible) offset.

This is NOT a new design decision — the spec says the feature "Ships buy → ghost-drag place" and "On the buy echo (carrying the new id), the client enters ghost-drag on that instance." We're fixing the impl to enter ghost-drag unconditionally instead of only when the default render happens to be visible.

**Deliberately unchanged (per spec, already user-confirmed "auto-hide works"):** placing/dragging a prop under the teahouse hides it (overlaps allowed, non-collidable); a hidden prop has no in-world prompt and is managed by shrinking the teahouse display to reveal it ("display small to show your garden"). Do NOT try to prevent overlap or add a panel-remove fallback — out of scope.

## Exact changes (3 files)

### 1. `roblox/src/server/main.server.luau` — add `propId` to the `DecorationPlaced` payload

In the decoration-buy branch of `RequestPurchase.OnServerEvent`, change:

```lua
            if player:IsDescendantOf(Players) and res.data.decoration ~= nil then
                DecorationPlaced:FireClient(player, { id = res.data.decoration.id })
            end
```

to:

```lua
            if player:IsDescendantOf(Players) and res.data.decoration ~= nil then
                DecorationPlaced:FireClient(player, { id = res.data.decoration.id, propId = res.data.decoration.propId })
            end
```

(`res.data.decoration` is the appended `{id, propId, offset, facing}` instance from the `/purchase` response, so `propId` is present.)

### 2. `roblox/src/client/DecorationController.client.luau` — buy triggers an immediate ghost-drag; remove the now-unused `pendingAutoMoveId` machinery

Replace the `DecorationPlaced.OnClientEvent` handler:

```lua
DecorationPlaced.OnClientEvent:Connect(function(p)
    if typeof(p) == "table" and typeof(p.id) == "number" and typeof(p.propId) == "string" and myPadId ~= nil then
        -- Enter ghost-drag for the freshly-bought prop IMMEDIATELY, independent of whether its
        -- default [0,0] render is visible: on a teahouse-owning deck the centered default is
        -- auto-hidden, so the built instance would never appear and waiting for it would strand
        -- the prop. enterDecoration tolerates a nil part and resolves the deck from padId.
        EventBus.MoveDecoration:Fire({ padId = myPadId, id = p.id, propId = p.propId, part = nil })
    end
end)
```

Delete the `pendingAutoMoveId` local variable and every reference to it. In particular, `tryBind` must no longer read/clear `pendingAutoMoveId` or fire `MoveDecoration` — its ONLY jobs now are: (a) ownership check (`padId` attr == `myPadId`), (b) `addPrompts(inst)` (deduped via `bound`). The Move prompt on an existing built prop still fires `EventBus.MoveDecoration:Fire({ padId = myPadId, id = <id attr>, propId = <propId attr>, part = model })` as before (that path passes a real `part`). Keep `rescanAll()` on `EconomyState` (binds prompts once `claimedPadId` resolves) and the `GetInstanceAddedSignal`/`GetInstanceRemovedSignal` connections. `rescanAll()` on `DecorationPlaced` is no longer needed (the buy now fires the drag directly) — remove that call if it was only there for the auto-move; the tag-added signal already handles late-arriving prompts.

### 3. `roblox/src/client/MoveController.client.luau` — `enterDecoration` tolerates a nil part; `startMove` tolerates a nil original

**`enterDecoration`** — accept `payload.part` as optional, require `payload.padId`, resolve the site folder from the part when present else from `padId`, and start the ghost at the stash default when there's no part:

```lua
local function enterDecoration(payload: any)
    if
        active
        or typeof(payload) ~= "table"
        or typeof(payload.id) ~= "number"
        or typeof(payload.propId) ~= "string"
        or typeof(payload.padId) ~= "string"
    then
        return
    end
    local part = if typeof(payload.part) == "Instance" then payload.part :: Model else nil
    local folder: Instance? = nil
    if part ~= nil then
        folder = part.Parent
    else
        local sites = workspace:FindFirstChild("TeahouseSites")
        folder = sites and sites:FindFirstChild("MaterializedSite_" .. payload.padId)
    end
    local m, deckSize = siteInfo(folder)
    local fp = DecorationCatalog.footprint(payload.propId)
    if m == nil or deckSize == nil or fp == nil then
        return
    end
    local ghostModel = DecorationCatalog.build(payload.propId)
    if ghostModel == nil then
        return
    end
    -- an existing (visible) prop starts the ghost at its current placement; a freshly-bought prop
    -- (no built part) starts at the stash default (deck centre) and the player drags it out.
    local dx, dz, facing = 0, 0, "N"
    if part ~= nil then
        dx, dz, facing = facingFromPivotOf(part, m)
    end
    startMove({
        original = part,
        ghost = ghostify(ghostModel),
        footprint = fp,
        deckFP = SizeClasses.deckFootprint(deckSize),
        mountCF = m,
        initialOffset = { math.round(dx), math.round(dz) },
        initialFacing = facing,
        commit = function(offset, f)
            SetDecorationPlacement:FireServer({ id = payload.id, offset = { offset[1], offset[2] }, facing = f })
        end,
    })
end
```

**`startMove`** — guard every `descriptor.original`-dependent step so a nil original is safe. The fade + prompt-disable block becomes:

```lua
    if descriptor.original ~= nil then
        fadeOriginal(descriptor.original, 0.7)
        for _, d in descriptor.original:GetDescendants() do
            if d:IsA("ProximityPrompt") and d.Enabled then
                d.Enabled = false
                table.insert(disabledPrompts, d)
            end
        end
    end
```

and the Destroying hook becomes:

```lua
    if descriptor.original ~= nil then
        table.insert(conns, descriptor.original.Destroying:Connect(exit))
    end
```

`exit()` already guards its restore with `if original then ... end`, so no change is needed there. The teahouse entry (`enterTeahouse`) always passes a real `original`, so its behavior is unchanged.

## Verification (run all three, paste into the report)

1. `cd roblox && lune run tests/run` — expect **464 passed, 0 failed** (pure suite unaffected).
2. `cd roblox && rojo build -o /tmp/decor-finalfix-check.rbxl` — must succeed (all three edited files parse).
3. `cd roblox && stylua --check src tests && selene src` — must be clean (auto-format with `cd roblox && stylua src tests` if needed, then re-check; fix any selene unused-variable warning, e.g. from removing `pendingAutoMoveId`).

## Commit

```
fix(roblox): buy enters ghost-drag immediately (decouple from built instance)

A decoration bought on a teahouse-owning deck defaults to the centred [0,0]
offset, which auto-hides under the centred teahouse -> the built instance never
appears -> the buy auto-move (which waited for that instance) never fired,
stranding the prop invisibly. The buy now enters ghost-drag directly from the
propId, independent of the built instance, so the player positions the new prop
immediately (SetDecorationPlacement operates on the stash, not rendered parts).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vf1gZydECjVW7ot94YH3ho
```
