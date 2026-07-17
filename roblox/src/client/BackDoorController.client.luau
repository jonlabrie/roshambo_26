--!strict
-- Per-player back-door editor. When the server assigns this player a teahouse (BackDoorState),
-- puts a ProximityPrompt on each of that teahouse's back bays (Bay_back_<i>). Triggering a bay
-- asks the server to make it the single back door (or, on the active bay, to remove it). The
-- door re-renders SERVER-side; this only fires the request and relabels prompts from the echoed
-- backDoorIndex. Only ever runs for the local player's own occupied teahouse (BackDoorState is
-- fired to that player alone).
-- BackDoorState fires not just on join and on a SetBackDoor edit echo, but also after any
-- mid-session live rebuild (buy-to-claim, size upgrade, display change) — those rebuilds
-- destroy the old Structure (and every prompt anchored inside it) and materialize a new one.
-- bindBays therefore sweeps its `prompts` cache for destroyed/unparented entries before
-- deduping, so a rebuild's re-fire re-creates prompts on the NEW structure instead of treating
-- the dead ones as still bound.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetBackDoor = remotes:WaitForChild("SetBackDoor") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent

local MAKE_LABEL = "Add a door here"
local REMOVE_LABEL = "Remove this door"

local prompts: { [number]: ProximityPrompt } = {} -- bayIndex -> its prompt
local activeIndex: number? = nil

-- One door slot: with no door, every bay offers "add"; once a door exists, only the door bay
-- stays interactable (to remove it) and the other bays' prompts go quiet until it's removed.
local function relabel()
    local hasDoor = activeIndex ~= nil
    for i, prompt in prompts do
        if not hasDoor then
            prompt.Enabled = true
            prompt.ActionText = MAKE_LABEL
        elseif i == activeIndex then
            prompt.Enabled = true
            prompt.ActionText = REMOVE_LABEL
        else
            prompt.Enabled = false
        end
    end
end

-- Anchor the prompt to the bay's FIXED wall location — its Solid panel, which sits at the
-- bay centre and never moves. Anchoring to "first BasePart found" grabs the Door variant's
-- screen, which pockets AWAY from the bay when open, dragging the prompt off its own bay
-- (end-bay prompts then collide at the wall centre).
local function anchorPart(bay: Instance): BasePart?
    local solid = bay:FindFirstChild("Solid")
    local solidPart = solid and solid:FindFirstChildWhichIsA("BasePart", true)
    if solidPart then
        return solidPart
    end
    if bay:IsA("Model") and bay.PrimaryPart then
        return bay.PrimaryPart
    end
    return bay:FindFirstChildWhichIsA("BasePart", true)
end

-- Create one prompt per back bay (deduped), then relabel to the current active door. Rebuilds
-- destroy the previous Structure (and every prompt anchored inside it), so first sweep out any
-- cached entries whose prompt no longer has a parent — otherwise the dedupe below would
-- mistake those destroyed prompts for still-bound ones and skip re-creating them on the NEW
-- structure's bays.
local function bindBays(structure: Instance)
    for i, prompt in prompts do
        if prompt.Parent == nil then
            prompts[i] = nil
        end
    end
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
                    -- F, not the default E: the Favorite prompt (PerchPreferenceController) owns
                    -- E on the same teahouse; sharing it would let one suppress the other (Roblox
                    -- shows only the closest same-key prompt). Revisit if these merge into one menu.
                    prompt.KeyboardKeyCode = Enum.KeyCode.F
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
