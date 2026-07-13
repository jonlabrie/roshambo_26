--!strict
-- Walk-up buy/upgrade prompts for the size economy (B2). Non-owner (no maxDeckSize): a
-- "Buy S deck & claim" prompt on each VACANT materialized site (Occupied attribute false).
-- Owner: an upgrade prompt on their OWN claimed site, alternating deck<->teahouse so BOTH
-- ladders are reachable. Server-authoritative: fires RequestPurchase, relabels from the echoed
-- EconomyState, never applies the purchase. The server (TreatmentApplier) destroys+rebuilds a
-- site's children on every purchase, so this rebinds when the anchor is replaced, and listens to
-- ChildAdded/Occupied per site so other players' claims update our prompts too (like
-- PerchPreferenceController). Prices come from the echoed catalog. Key G (E=Favorite, F=door).
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
local bound: { [string]: { prompt: ProximityPrompt, anchor: BasePart } } = {}

local function priceOf(item: string): any
    local kind, size = string.match(item, "^(%a+):(%a+)$")
    if state.catalog and kind and size and state.catalog[kind] then
        return state.catalog[kind][size]
    end
    return "?"
end

-- (item, actionText) or (nil, nil) for what a site offers the local player right now
local function offerFor(siteId: string, occupied: boolean): (string?, string?)
    if state.maxDeckSize == nil then
        -- non-owner: buy the S deck & claim a VACANT site
        if not occupied then
            return "deck:S", `Buy S deck & claim — {priceOf("deck:S")} pts`
        end
        return nil, nil
    end
    -- owner: upgrades only on their OWN claimed site; alternate deck<->teahouse
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
        local nt = SizeClasses.nextTier(maxTea)
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

-- the deck part is present for any built pad (bare deck OR teahouse); fall back to any BasePart
local function anchorOf(folder: Instance): BasePart?
    local deck = folder:FindFirstChild("PadDeck", true)
    if deck and deck:IsA("BasePart") then
        return deck
    end
    return folder:FindFirstChildWhichIsA("BasePart", true)
end

local function clearPrompt(siteId: string)
    local b = bound[siteId]
    if b then
        b.prompt:Destroy()
        bound[siteId] = nil
    end
end

local function refreshSite(folder: Instance)
    local siteId = folder.Name:match("^MaterializedSite_(.+)$")
    if not siteId then
        return
    end
    local occupied = folder:GetAttribute("Occupied") == true
    local item, text = offerFor(siteId, occupied)
    if item == nil then
        clearPrompt(siteId)
        return
    end
    local anchor = anchorOf(folder)
    if anchor == nil then
        clearPrompt(siteId)
        return
    end
    local b = bound[siteId]
    -- (re)create when there's no prompt, or the site was rebuilt (anchor replaced / detached)
    if b == nil or b.anchor ~= anchor or b.anchor.Parent == nil then
        clearPrompt(siteId)
        local prompt = Instance.new("ProximityPrompt")
        prompt.ObjectText = "Teahouse"
        prompt.KeyboardKeyCode = Enum.KeyCode.G
        prompt.MaxActivationDistance = 14
        prompt.RequiresLineOfSight = false
        prompt.Parent = anchor
        prompt.Triggered:Connect(function()
            local it = select(1, offerFor(siteId, folder:GetAttribute("Occupied") == true))
            if it then
                RequestPurchase:FireServer({ item = it, padId = siteId })
            end
        end)
        bound[siteId] = { prompt = prompt, anchor = anchor }
        b = bound[siteId]
    end
    b.prompt.ActionText = text
end

local function refreshAll()
    local sites = workspace:FindFirstChild("TeahouseSites")
    if sites == nil then
        return
    end
    for _, folder in sites:GetChildren() do
        refreshSite(folder)
    end
end

local function bindSite(folder: Instance)
    if not folder.Name:match("^MaterializedSite_(.+)$") then
        return
    end
    -- the server rebuilds a site (destroy+re-parent children) on claim/upgrade and flips Occupied;
    -- refresh on either so our prompt rebinds and other players' claims update our labels.
    folder.ChildAdded:Connect(function()
        refreshSite(folder)
    end)
    folder:GetAttributeChangedSignal("Occupied"):Connect(function()
        refreshSite(folder)
    end)
    refreshSite(folder)
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
    refreshAll()
end)

local sitesFolder = workspace:WaitForChild("TeahouseSites")
for _, folder in sitesFolder:GetChildren() do
    bindSite(folder)
end
sitesFolder.ChildAdded:Connect(bindSite)
