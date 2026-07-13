--!strict
-- Per-player back-door editor. When the server assigns this player a teahouse (BackDoorState),
-- puts a ProximityPrompt on each of that teahouse's back bays (Bay_back_<i>). Triggering a bay
-- asks the server to make it the single back door (or, on the active bay, to remove it). The
-- door re-renders SERVER-side; this only fires the request and relabels prompts from the echoed
-- backDoorIndex. Only ever runs for the local player's own occupied teahouse (BackDoorState is
-- fired to that player alone).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetBackDoor = remotes:WaitForChild("SetBackDoor") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent

local MAKE_LABEL = "Add a door here"
local REMOVE_LABEL = "Remove this door"

local prompts: { [number]: ProximityPrompt } = {} -- bayIndex -> its prompt
local activeIndex: number? = nil

local function relabel()
    for i, prompt in prompts do
        prompt.ActionText = if i == activeIndex then REMOVE_LABEL else MAKE_LABEL
    end
end

local function anchorPart(bay: Instance): BasePart?
    if bay:IsA("Model") and bay.PrimaryPart then
        return bay.PrimaryPart
    end
    return bay:FindFirstChildWhichIsA("BasePart", true)
end

-- Create one prompt per back bay (deduped), then relabel to the current active door.
local function bindBays(structure: Instance)
    for _, child in structure:GetChildren() do
        local idxStr = child.Name:match("^Bay_back_(%d+)$")
        if idxStr then
            local i = tonumber(idxStr) :: number
            if prompts[i] == nil then
                local anchor = anchorPart(child)
                if anchor then
                    local prompt = Instance.new("ProximityPrompt")
                    prompt.ActionText = MAKE_LABEL
                    prompt.ObjectText = "Back wall"
                    prompt.KeyboardKeyCode = Enum.KeyCode.E
                    prompt.MaxActivationDistance = 12
                    prompt.RequiresLineOfSight = false
                    prompt.Parent = anchor
                    prompt.Triggered:Connect(function()
                        SetBackDoor:FireServer({ bayIndex = i })
                    end)
                    prompts[i] = prompt
                end
            end
        end
    end
    relabel()
end

BackDoorState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" or typeof(payload.padId) ~= "string" then
        return
    end
    activeIndex = payload.backDoorIndex
    -- The structure is materialized server-side and replicating; wait (bounded) for it. Use
    -- WaitForChild, not FindFirstChild, to survive the async-replication startup race.
    local sitesFolder = workspace:WaitForChild("TeahouseSites")
    local siteFolder = sitesFolder:WaitForChild("MaterializedSite_" .. payload.padId, 15)
    local structure = siteFolder and siteFolder:WaitForChild("Structure", 15)
    if structure then
        bindBays(structure)
    else
        relabel()
    end
end)
