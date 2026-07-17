--!strict
-- Per-player back-door editor. When the server assigns this player a teahouse (BackDoorState),
-- puts a ProximityPrompt on each of that teahouse's back bays (Bay_back_<i>). Triggering a bay
-- asks the server to make it the single back door (or, on the active bay, to remove it). The
-- door re-renders SERVER-side; this only fires the request and relabels prompts from the echoed
-- backDoorIndex.
--
-- Lifecycle: RemoteEvents are NOT ordered with respect to instance replication, and every
-- rebuild (buy-to-claim, size upgrade, display change, door edit) destroys the old Structure and
-- adopts a new one under the SAME site folder (MaterializedSite_<padId>), which TreatmentApplier
-- keeps stable across rebuilds. So instead of binding prompts at event-arrival time (racy — the
-- new Structure may not exist yet, or the old one may still be alive and about to die), this
-- controller watches the site folder for whichever Structure lives under it right now:
--   * watchFolder(folder) arms a persistent folder.ChildAdded connection plus an immediate check
--     for an already-present Structure. It is the piece that makes event/replication ordering
--     irrelevant — once armed for a padId, ANY future Structure landing there gets bound,
--     whether or not a BackDoorState event happens to accompany it.
--   * bindStructure(structure) is idempotent per structure instance: switching to a genuinely
--     new Structure drops the old prompt cache (those prompts died with their structure) and
--     rebinds; it also watches the new Structure's own ChildAdded, since a replicated subtree's
--     descendants (the Bay_back_<i> models) can land after the Structure root's ChildAdded
--     fires on the client.
-- BackDoorState itself only ever supplies padId + the currently active door index; rendering the
-- door lives entirely server-side (StructureOps.applyBays), replicated like any other geometry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetBackDoor = remotes:WaitForChild("SetBackDoor") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent

local MAKE_LABEL = "Add a door here"
local REMOVE_LABEL = "Remove this door"

local activeIndex: number? = nil
local currentFolder: Instance? = nil
local currentStructure: Instance? = nil
local folderConn: RBXScriptConnection? = nil
local structureBaysConn: RBXScriptConnection? = nil
local prompts: { [number]: ProximityPrompt } = {} -- bayIndex -> its prompt, for currentStructure only

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

-- Create (once) the prompt for one back bay of the CURRENT structure. Deduped on prompts[i] so
-- the initial GetChildren() sweep and the late-arrival ChildAdded connection (below) can't both
-- create a prompt for the same bay if a bay lands mid-sweep.
local function createPromptForBay(bay: Instance, i: number)
    if prompts[i] ~= nil then
        return
    end
    local anchor = anchorPart(bay)
    if anchor == nil then
        return
    end
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = MAKE_LABEL
    prompt.ObjectText = "Back wall"
    -- F, not the default E: the Favorite prompt (PerchPreferenceController) owns E on the same
    -- teahouse; sharing it would let one suppress the other (Roblox shows only the closest
    -- same-key prompt). Revisit if these merge into one menu.
    prompt.KeyboardKeyCode = Enum.KeyCode.F
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = anchor
    prompt.Triggered:Connect(function()
        SetBackDoor:FireServer({ bayIndex = i })
    end)
    prompts[i] = prompt
end

-- Bind prompts to whichever Structure currently lives under the watched site folder. Switching
-- to a genuinely new structure (rebuild) drops the old prompt cache — those prompts belong to
-- the dead structure — and re-scans + re-watches the new one. Calling this again for the SAME
-- structure (e.g. a plain door-edit echo re-resolving the same live structure) is a no-op past
-- the relabel, so it never duplicates prompts or listeners.
local function bindStructure(structure: Instance)
    if structure ~= currentStructure then
        if structureBaysConn then
            structureBaysConn:Disconnect()
            structureBaysConn = nil
        end
        prompts = {}
        currentStructure = structure
        for _, child in structure:GetChildren() do
            local idxStr = child.Name:match("^Bay_back_(%d+)$")
            if idxStr then
                createPromptForBay(child, tonumber(idxStr) :: number)
            end
        end
        -- A replicated subtree's descendants can land after the root's ChildAdded fires on the
        -- client, so a Bay_back_<i> may still be arriving after the sweep above; catch it here.
        structureBaysConn = structure.ChildAdded:Connect(function(child)
            local idxStr = child.Name:match("^Bay_back_(%d+)$")
            if idxStr then
                createPromptForBay(child, tonumber(idxStr) :: number)
                relabel()
            end
        end)
    end
    relabel()
end

-- Watch a site folder (MaterializedSite_<padId>) for whichever Structure lives under it. This
-- connection persists across rebuilds — it's what makes RemoteEvent/replication ordering
-- irrelevant: whenever a new Structure lands under this folder, for ANY reason, it gets bound,
-- whether or not a BackDoorState event accompanies it. A bare-deck rebuild (no teahouse) simply
-- leaves no Structure child; the watch stays armed until the teahouse returns.
local function watchFolder(folder: Instance)
    if folder ~= currentFolder then
        if folderConn then
            folderConn:Disconnect()
            folderConn = nil
        end
        currentFolder = folder
        folderConn = folder.ChildAdded:Connect(function(child)
            if child.Name == "Structure" then
                bindStructure(child)
            end
        end)
        -- Covers the event-after-replication order: the Structure may already be there by the
        -- time we start watching (ChildAdded only fires for children added AFTER connecting).
        local existing = folder:FindFirstChild("Structure")
        if existing then
            bindStructure(existing)
        end
    end
end

BackDoorState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" or typeof(payload.padId) ~= "string" then
        return
    end
    activeIndex = payload.backDoorIndex
    -- The structure is materialized server-side and replicating; wait (bounded) for the site
    -- folder itself. Use WaitForChild, not FindFirstChild, to survive the async-replication
    -- startup race. The Structure inside it is handled by watchFolder, not waited for here.
    local sitesFolder = workspace:WaitForChild("TeahouseSites")
    local siteFolder = sitesFolder:WaitForChild("MaterializedSite_" .. payload.padId, 15)
    if siteFolder then
        watchFolder(siteFolder)
    end
    -- Always relabel, even on a plain door-edit echo (same padId, same live structure): only the
    -- active-door state changed, and the same-structure dedupe in bindStructure means this never
    -- duplicates prompts.
    relabel()
end)
