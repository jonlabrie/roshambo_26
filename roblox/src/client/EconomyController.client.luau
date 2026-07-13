--!strict
-- Walk-up buy/upgrade prompts for the size economy (B2). Non-owner (no maxDeckSize): a
-- "Buy S deck & claim" prompt on each VACANT materialized site (Occupied attribute false).
-- Owner: an "Upgrade" prompt on their OWN claimed site offering the next deck/teahouse tier.
-- Server-authoritative: this only fires RequestPurchase and relabels from the echoed EconomyState.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local SizeClasses = require(shared:WaitForChild("SizeClasses"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent

local state = {
    maxDeckSize = nil :: string?,
    teahouseSizes = {} :: { string },
    claimedPadId = nil :: string?,
    catalog = nil :: any,
    totalPoints = 0,
}
local prompts: { [string]: ProximityPrompt } = {} -- siteId -> its prompt

local function priceOf(item: string): number?
    local kind, size = string.match(item, "^(%a+):(%a+)$")
    if state.catalog and kind and size and state.catalog[kind] then
        return state.catalog[kind][size]
    end
    return nil
end

local function anchor(structure: Instance): BasePart?
    local deck = structure:FindFirstChild("PadDeck", true)
    if deck and deck:IsA("BasePart") then
        return deck
    end
    return structure:FindFirstChildWhichIsA("BasePart", true)
end

-- returns (item, actionText) or nil for what this site offers the local player
local function offerFor(siteId: string, occupied: boolean): (string?, string?)
    if state.maxDeckSize == nil then
        -- non-owner: buy the S deck & claim a VACANT site
        if not occupied then
            local p = priceOf("deck:S")
            return "deck:S", `Buy S deck & claim — {p} pts`
        end
        return nil, nil
    end
    -- owner: upgrades only on their OWN claimed site. ONE prompt alternates deck<->teahouse: if
    -- the deck is bigger than the biggest owned teahouse, the next step is a teahouse (to fill the
    -- deck); otherwise it's a bigger deck. Covers BOTH ladders through the single key.
    if siteId ~= state.claimedPadId then
        return nil, nil
    end
    local maxTea: string? = nil
    for _, s in state.teahouseSizes do
        if maxTea == nil or SizeClasses.rank[s] > SizeClasses.rank[maxTea] then
            maxTea = s
        end
    end
    local deckRank = if state.maxDeckSize ~= nil then SizeClasses.rank[state.maxDeckSize] else 0
    local teaRank = if maxTea ~= nil then SizeClasses.rank[maxTea] else 0
    if deckRank > teaRank then
        local nt = SizeClasses.nextTier(maxTea) -- next teahouse tier, guaranteed <= deck here
        if nt ~= nil then
            return `teahouse:{nt}`, `Add {nt} teahouse — {priceOf(`teahouse:{nt}`)} pts`
        end
    end
    local nd = SizeClasses.nextTier(state.maxDeckSize)
    if nd ~= nil then
        return `deck:{nd}`, `Upgrade deck → {nd} — {priceOf(`deck:{nd}`)} pts`
    end
    return nil, nil -- fully upgraded (L deck + L teahouse)
end

local function refresh()
    local sites = workspace:FindFirstChild("TeahouseSites")
    if sites == nil then
        return
    end
    for _, folder in sites:GetChildren() do
        local siteId = folder.Name:match("^MaterializedSite_(.+)$")
        if siteId then
            local occupied = folder:GetAttribute("Occupied") == true
            local item, text = offerFor(siteId, occupied)
            local existing = prompts[siteId]
            if item == nil then
                if existing then
                    existing:Destroy()
                    prompts[siteId] = nil
                end
            else
                local structure = folder:FindFirstChild("Structure")
                local a = structure and anchor(structure)
                if a then
                    local prompt = existing
                    if prompt == nil then
                        prompt = Instance.new("ProximityPrompt")
                        prompt.ObjectText = "Teahouse"
                        prompt.KeyboardKeyCode = Enum.KeyCode.G -- E=Favorite, F=door, G=economy
                        prompt.MaxActivationDistance = 14
                        prompt.RequiresLineOfSight = false
                        prompt.Parent = a
                        local capturedId = siteId
                        prompt.Triggered:Connect(function()
                            local it =
                                select(1, offerFor(capturedId, (folder:GetAttribute("Occupied") == true)))
                            if it then
                                RequestPurchase:FireServer({ item = it, padId = capturedId })
                            end
                        end)
                        prompts[siteId] = prompt
                    end
                    prompt.ActionText = text
                end
            end
        end
    end
end

EconomyState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then
        return
    end
    state.totalPoints = payload.totalPoints or 0
    state.maxDeckSize = payload.maxDeckSize
    state.teahouseSizes = payload.teahouseSizes or {}
    state.claimedPadId = payload.claimedPadId
    if payload.catalog ~= nil then
        state.catalog = payload.catalog
    end
    refresh()
end)

workspace:WaitForChild("TeahouseSites")
task.defer(refresh)
