--!strict
-- Owner-only in-world controls for placed deck decorations (2026-07-19 framework). Mirrors
-- BackDoorController's geometry-driven binding, but keyed on the CollectionService "Decoration"
-- tag: whenever a Decoration Model whose padId attribute matches THIS client's claimed pad
-- replicates in, it gets Move + Remove ProximityPrompts. Tag replication + GetInstanceAddedSignal
-- make RemoteEvent/replication ordering irrelevant (same lesson as the back-door rebind). A buy
-- fires DecorationPlaced{ id }; when that instance is present + owned, we auto-enter ghost-drag.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
