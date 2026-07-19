--!strict
-- Home portal runtime (2026-07-19 spec): builds the always-open Arena Portal (walk in -> your own
-- deck) and wires each tagged deck PortalControl (open -> a passable threshold -> step through to
-- the arena). Pure teleports (PivotTo), no DB writes, so NOT on the HandlerQueue. Deck->arena is
-- usable by anyone on the deck; arena->deck sends you to YOUR own home only.
local CollectionService = game:GetService("CollectionService")

local PortalController = {}
PortalController.__index = PortalController

export type Deps = {
    players: Players,
    portalTarget: any,
    getEconomy: (uid: string) -> { portalOwned: boolean, claimedPadId: string? }?,
    deckCFForClaim: (uid: string) -> ({ number }?, string?), -- (deckCF12, deckSize); nil,nil if no claim
}

function PortalController.new(deps: Deps)
    return setmetatable({ _d = deps, _openThresholds = {} :: { [Instance]: Instance? } }, PortalController)
end

function PortalController:buildArena()
    local pt = self._d.portalTarget
    local portal = Instance.new("Part")
    portal.Name = "ArenaPortal"
    portal.Anchored = true
    portal.CanCollide = false
    portal.Size = Vector3.new(6, 10, 1)
    portal.Color = Color3.fromRGB(120, 90, 200)
    portal.Material = Enum.Material.Neon
    portal.CFrame = CFrame.new(table.unpack(pt.ARENA_PORTAL_CF))
    portal.Parent = workspace
    local debounce: { [Player]: boolean } = {}
    portal.Touched:Connect(function(hit)
        local player = self._d.players:GetPlayerFromCharacter(hit.Parent)
        if player == nil or debounce[player] then
            return
        end
        local eco = self._d.getEconomy(tostring(player.UserId))
        if eco == nil or not eco.portalOwned or eco.claimedPadId == nil then
            return -- landmark for non-owners; only home-portal owners travel
        end
        local deckCF12, deckSize = self._d.deckCFForClaim(tostring(player.UserId))
        if deckCF12 == nil or deckSize == nil then
            return
        end
        debounce[player] = true
        local char = player.Character
        if char then
            char:PivotTo(CFrame.new(table.unpack(pt.deckLanding(deckCF12, deckSize))))
        end
        task.delay(1, function()
            debounce[player] = nil
        end)
    end)
end

function PortalController:_bindControl(control: Instance)
    local prompt = control:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt == nil then
        return
    end
    prompt.Triggered:Connect(function(player)
        -- anyone standing on the deck may open it (deck -> public arena is not privileged)
        self:_openThreshold(control, player)
    end)
end

function PortalController:_openThreshold(control: Instance, _opener: Player)
    if not control:IsA("BasePart") then
        return
    end
    if self._openThresholds[control] ~= nil then
        return -- already open
    end
    local pt = self._d.portalTarget
    local threshold = Instance.new("Part")
    threshold.Name = "PortalThreshold"
    threshold.Anchored = true
    threshold.CanCollide = false
    threshold.Size = Vector3.new(4, 7, 1)
    threshold.Color = Color3.fromRGB(150, 120, 230)
    threshold.Material = Enum.Material.ForceField
    threshold.CFrame = (control :: BasePart).CFrame * CFrame.new(0, 2, -2)
    threshold.Parent = workspace
    self._openThresholds[control] = threshold
    local conn
    conn = threshold.Touched:Connect(function(hit)
        local player = self._d.players:GetPlayerFromCharacter(hit.Parent)
        if player == nil then
            return
        end
        local char = player.Character
        if char then
            char:PivotTo(CFrame.new(table.unpack(pt.ARENA_LANDING)))
        end
        conn:Disconnect()
        threshold:Destroy()
        if self._openThresholds[control] == threshold then
            self._openThresholds[control] = nil
        end
    end)
    task.delay(12, function()
        if self._openThresholds[control] == threshold then
            conn:Disconnect()
            threshold:Destroy()
            self._openThresholds[control] = nil
        end
    end)
end

function PortalController:bindControls()
    for _, control in CollectionService:GetTagged("PortalControl") do
        self:_bindControl(control)
    end
    CollectionService:GetInstanceAddedSignal("PortalControl"):Connect(function(control)
        self:_bindControl(control)
    end)
end

function PortalController:start()
    self:buildArena()
    self:bindControls()
end

return PortalController
