--!strict
-- Owner-only in-world controls for placed deck decorations (2026-07-19 framework). Mirrors
-- BackDoorController's geometry-driven binding, but keyed on the CollectionService "Decoration"
-- tag: whenever a Decoration Model whose padId attribute matches THIS client's claimed pad
-- replicates in, it gets Move + Remove ProximityPrompts. Tag replication + GetInstanceAddedSignal
-- make RemoteEvent/replication ordering irrelevant (same lesson as the back-door rebind). A buy
-- fires DecorationPlaced{ id, propId }; we enter ghost-drag IMMEDIATELY off the propId (part=nil),
-- independent of the built instance — the freshly-bought prop's centred default can be auto-hidden
-- under the teahouse, so waiting for its instance would strand it invisibly.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
local SetDecorationRemove = remotes:WaitForChild("SetDecorationRemove") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local myPadId: string? = nil
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

-- Bind a tagged decoration IF it belongs to this client's claimed pad.
local function tryBind(inst: Instance)
    if not inst:IsA("Model") then
        return
    end
    local padId = inst:GetAttribute("padId")
    if myPadId == nil or padId ~= myPadId then
        return
    end
    addPrompts(inst)
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
