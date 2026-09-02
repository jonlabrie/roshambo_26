--!strict
-- Owner-only in-world controls for placed deck decorations (2026-07-19 framework), extended
-- (deck-mortars, 2026-09-04) to cover mortar tubes too. Mirrors BackDoorController's
-- geometry-driven binding, but keyed on CollectionService tags: whenever a Decoration OR Mortar
-- Model whose padId attribute matches THIS client's claimed pad replicates in, it gets a Move
-- ProximityPrompt (decorations also get Remove -- mortars deliberately never do: gear is
-- move/rotate-only, no sell affordance, per the deck-mortars spec). Tag replication +
-- GetInstanceAddedSignal make RemoteEvent/replication ordering irrelevant (same lesson as the
-- back-door rebind). A decoration buy fires DecorationPlaced{ id, propId }; we enter ghost-drag
-- IMMEDIATELY off the propId (part=nil), independent of the built instance — the freshly-bought
-- prop's centred default can be auto-hidden under the teahouse, so waiting for its instance would
-- strand it invisibly. Mortars have no such case: a tier renders at a resolved default the
-- instant it's owned (MortarPlacement.resolve), so its Move prompt always has a real instance to
-- ghost-clone (see MoveController.enterMortar).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
local SetDecorationRemove = remotes:WaitForChild("SetDecorationRemove") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local myPadId: string? = nil
local bound: { [Instance]: boolean } = {} -- decoration/mortar Model -> prompts added

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

-- MortarId is written by TreatmentApplier._buildMortars as a model attribute (Task 5 rework).
local function mortarIdOf(model: Instance): string?
    return model:GetAttribute("MortarId") :: string?
end

local function addPrompts(model: Model, isMortar: boolean)
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
    move.ObjectText = if isMortar then "Mortar" else "Decoration"
    move.KeyboardKeyCode = Enum.KeyCode.E
    move.MaxActivationDistance = 10
    move.RequiresLineOfSight = false
    move.Parent = anchor
    move.Triggered:Connect(function()
        if isMortar then
            local mortarId = mortarIdOf(model)
            if typeof(mortarId) == "string" then
                EventBus.MoveMortar:Fire({ padId = myPadId, mortarId = mortarId, part = model })
            end
        else
            local id = model:GetAttribute("id")
            local propId = propIdOf(model)
            if typeof(id) == "number" and typeof(propId) == "string" then
                EventBus.MoveDecoration:Fire({ padId = myPadId, id = id, propId = propId, part = model })
            end
        end
    end)

    -- NO remove/sell affordance for mortars (deck-mortars spec): gear is move/rotate-only.
    if isMortar then
        return
    end

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

-- Bind a tagged decoration/mortar IF it belongs to this client's claimed pad.
local function tryBind(inst: Instance, isMortar: boolean)
    if not inst:IsA("Model") then
        return
    end
    local padId = inst:GetAttribute("padId")
    if padId == nil then
        -- Join-time replication can fire the tag signal BEFORE the model's attributes apply
        -- (2026-09-04 gate: models built during the claim flow never bound — padId read nil
        -- and nothing retried; every later incremental rebuild bound fine). Wait for the
        -- attribute once, then retry.
        local conn: RBXScriptConnection
        conn = inst:GetAttributeChangedSignal("padId"):Connect(function()
            conn:Disconnect()
            tryBind(inst, isMortar)
        end)
        return
    end
    if myPadId == nil or padId ~= myPadId then
        return
    end
    addPrompts(inst, isMortar)
end

local function rescanAll()
    for _, inst in CollectionService:GetTagged("Decoration") do
        tryBind(inst, false)
    end
    for _, inst in CollectionService:GetTagged("Mortar") do
        tryBind(inst, true)
    end
end

CollectionService:GetInstanceAddedSignal("Decoration"):Connect(function(inst)
    tryBind(inst, false)
end)
CollectionService:GetInstanceRemovedSignal("Decoration"):Connect(function(inst)
    bound[inst] = nil
end)
CollectionService:GetInstanceAddedSignal("Mortar"):Connect(function(inst)
    tryBind(inst, true)
end)
CollectionService:GetInstanceRemovedSignal("Mortar"):Connect(function(inst)
    bound[inst] = nil
end)

EconomyState.OnClientEvent:Connect(function(p)
    myPadId = p.claimedPadId
    -- rescan on EVERY echo, not just a pad change: the bound-guard makes it idempotent and the
    -- model count is tiny, and it closes every models-before-echo / echo-before-models ordering
    -- (the change-only guard left join-time builds unbound with nothing to retry them).
    rescanAll()
end)

DecorationPlaced.OnClientEvent:Connect(function(p)
    if
        typeof(p) == "table"
        and typeof(p.id) == "number"
        and typeof(p.propId) == "string"
        and myPadId ~= nil
    then
        -- Enter ghost-drag for the freshly-bought prop IMMEDIATELY, independent of whether its
        -- default [0,0] render is visible: on a teahouse-owning deck the centered default is
        -- auto-hidden, so the built instance would never appear and waiting for it would strand
        -- the prop. enterDecoration tolerates a nil part and resolves the deck from padId.
        EventBus.MoveDecoration:Fire({ padId = myPadId, id = p.id, propId = p.propId, part = nil })
    end
end)

rescanAll()
