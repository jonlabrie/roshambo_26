## Task 11: `DecorationController` — owner prompts + auto-place on buy

**Files:**
- Create: `roblox/src/client/DecorationController.client.luau`

**Interfaces:**
- Consumes: `EconomyState` (own `claimedPadId`), `DecorationPlaced` (Task 8), `SetDecorationRemove` (Task 8), `EventBus.MoveDecoration` (Task 9); the `Decoration` tag + `id`/`padId` attributes (Task 7).
- Produces: for each `Decoration` Model whose `padId` == the client's own `claimedPadId`, a **Move** prompt (fires `EventBus.MoveDecoration`) and a **Remove** prompt (fires `SetDecorationRemove`). On `DecorationPlaced{ id }` after a buy, auto-enters ghost-drag for that instance once it exists.

- [ ] **Step 1: Implement `roblox/src/client/DecorationController.client.luau`**

```lua
--!strict
-- Owner-only in-world controls for placed deck decorations (2026-07-19 framework). Mirrors
-- BackDoorController's geometry-driven binding, but keyed on the CollectionService "Decoration"
-- tag: whenever a Decoration Model whose padId attribute matches THIS client's claimed pad
-- replicates in, it gets Move + Remove ProximityPrompts. Tag replication + GetInstanceAddedSignal
-- make RemoteEvent/replication ordering irrelevant (same lesson as the back-door rebind). A buy
-- fires DecorationPlaced{ id }; when that instance is present + owned, we auto-enter ghost-drag.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DecorationCatalog = require(shared:WaitForChild("DecorationCatalog"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
local SetDecorationRemove = remotes:WaitForChild("SetDecorationRemove") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local myPadId: string? = nil
local pendingAutoMoveId: number? = nil
local bound: { [Instance]: boolean } = {} -- decoration Model -> prompts added

local function anchorPart(model: Model): BasePart?
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

-- propId is written by TreatmentApplier._buildDecorations as a model attribute (Task 11 Step 2).
local function propIdOf(model: Instance): string?
    return model:GetAttribute("propId") :: string?
end

local function addPrompts(model: Model)
    if bound[model] then
        return
    end
    local anchor = anchorPart(model)
    if anchor == nil then
        return
    end
    bound[model] = true

    local move = Instance.new("ProximityPrompt")
    move.Name = "DecorMove"
    move.ActionText = "Move"
    move.ObjectText = "Decoration"
    move.KeyboardKeyCode = Enum.KeyCode.E
    move.MaxActivationDistance = 10
    move.RequiresLineOfSight = false
    move.Parent = anchor
    move.Triggered:Connect(function()
        local id = model:GetAttribute("id")
        local propId = propIdOf(model)
        if typeof(id) == "number" and typeof(propId) == "string" then
            EventBus.MoveDecoration:Fire({ padId = myPadId, id = id, propId = propId, part = model })
        end
    end)

    local remove = Instance.new("ProximityPrompt")
    remove.Name = "DecorRemove"
    remove.ActionText = "Remove"
    remove.ObjectText = "Decoration"
    remove.KeyboardKeyCode = Enum.KeyCode.X
    remove.MaxActivationDistance = 10
    remove.RequiresLineOfSight = false
    remove.Parent = anchor
    remove.Triggered:Connect(function()
        local id = model:GetAttribute("id")
        if typeof(id) == "number" then
            SetDecorationRemove:FireServer({ id = id })
        end
    end)
end

-- Bind a tagged decoration IF it belongs to this client's claimed pad. Also fulfils a pending
-- auto-move (post-buy) when the matching instance appears.
local function tryBind(inst: Instance)
    if not inst:IsA("Model") then
        return
    end
    local padId = inst:GetAttribute("padId")
    if myPadId == nil or padId ~= myPadId then
        return
    end
    addPrompts(inst)
    local id = inst:GetAttribute("id")
    if pendingAutoMoveId ~= nil and typeof(id) == "number" and id == pendingAutoMoveId then
        local propId = propIdOf(inst)
        if typeof(propId) == "string" then
            pendingAutoMoveId = nil
            EventBus.MoveDecoration:Fire({ padId = myPadId, id = id, propId = propId, part = inst })
        end
    end
end

local function rescanAll()
    for _, inst in CollectionService:GetTagged("Decoration") do
        tryBind(inst)
    end
end

CollectionService:GetInstanceAddedSignal("Decoration"):Connect(tryBind)
CollectionService:GetInstanceRemovedSignal("Decoration"):Connect(function(inst)
    bound[inst] = nil
end)

EconomyState.OnClientEvent:Connect(function(p)
    local newPad = p.claimedPadId
    if newPad ~= myPadId then
        myPadId = newPad
        rescanAll() -- claim just resolved: bind any decorations already replicated in
    end
end)

DecorationPlaced.OnClientEvent:Connect(function(p)
    if typeof(p) == "table" and typeof(p.id) == "number" then
        pendingAutoMoveId = p.id
        rescanAll() -- the freshly-built prop may already be here; otherwise tryBind catches it
    end
end)

rescanAll()
```

> **`propId` recovery:** `addPrompts`/`tryBind` read a `propId` attribute off the Decoration model. Task 7's `_buildDecorations` tags `id` + `padId` but NOT `propId`. Add `model:SetAttribute("propId", r.propId)` in `_buildDecorations` (one line) so the client can pass it to `MoveDecoration`. Make that edit as part of THIS task (it's the consumer that needs it) and re-commit the applier line here.

- [ ] **Step 2: Add the `propId` attribute in `TreatmentApplier._buildDecorations`**

In `roblox/src/server/TreatmentApplier.luau`, in `_buildDecorations`, add the attribute next to the others:

```lua
        model.Name = "Decoration"
        model:SetAttribute("id", r.id)
        model:SetAttribute("padId", padId)
        model:SetAttribute("propId", r.propId)
        model:AddTag("Decoration")
```

- [ ] **Step 3: Lint + tests**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.
Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/client/DecorationController.client.luau roblox/src/server/TreatmentApplier.luau
git commit -m "feat(roblox): DecorationController owner prompts + auto-place on buy"
```

---

## Visual gate (after Task 11 — run in Studio via Rojo, not a task)

Sync with `rojo serve`, play as a claimed deck-owner, and verify:
1. The panel's **Decorations** section lists four props with prices; buying one spends points.
2. After a buy, ghost-drag begins automatically on the new prop; a click/✓ places it; four props place with **distinct footprints**.
3. Each placed prop shows owner-only **Move** and **Remove** prompts; Move re-enters ghost-drag, Remove deletes it (no refund).
4. **Auto-hide:** place props in the open yard under a small teahouse display, then raise the teahouse Display to a larger size — the covered props vanish; shrink back and they return. Stored placement is unchanged (they reappear where they were).
5. Cap: buying past 24 is refused (button disabled at the cap).
6. Props survive Display / size-upgrade / teahouse-Move rebuilds.
7. **Regression:** the teahouse **Move** still works exactly as before (the generalized `MoveController`).

---

## Self-Review notes (for the executor)

- **Spec coverage:** data model (T1,T3), catalog split (T1 TS, T5 Luau), `DecorationLayout.resolve` (T6), server routes (T1–T3), Roblox stash/thread/handlers (T7,T8), `MoveController` generalization (T9), panel section (T10), `DecorationController` (T11), all error-handling rows (T1 cap/unknown, T2 malformed, T8 stale-id no-op + occupant gate, T6 bare-deck) — covered.
- **Type consistency:** `deckDecorations` is `{ id, propId, offset:{x,z}, facing }` everywhere; the propId set is the same four ids in TS + Luau; `footprintBounds`/`resolve`/`clamp` signatures match their call sites.
- **Known deferred (do NOT build):** swap-decoration economy, teahouse-anchored props, banner/noren slot content + flex economies, flex behaviors, collidable/sittable props, partial refunds, multi-pad decoration memory, art pass.
