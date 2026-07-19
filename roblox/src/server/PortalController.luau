--!strict
-- Home portal runtime (2026-07-19 spec): builds the always-open Arena Portal (walk in -> your own
-- deck) and wires each tagged deck PortalControl (open -> the marker tweens up INTO a passable
-- portal you step through to the arena, then shrinks back). Pure teleports (PivotTo), no DB writes,
-- so NOT on the HandlerQueue. Deck->arena is usable by anyone on the deck; arena->deck sends you to
-- YOUR own home only.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

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

-- The control marker transforms INTO the passable portal: it tweens up to PORTAL_OPEN_SIZE over
-- OPEN_TIME (base-anchored so the doorway sits on the deck), then STAYS OPEN as a shared doorway —
-- anyone on the deck who steps through is teleported, and each use pushes the auto-close out to
-- IDLE_CLOSE seconds from that use. It shrinks back to the marker IDLE_CLOSE seconds after the last
-- use (or after opening, if never used). `_openThresholds[control]` tracks whether a control is
-- currently open (keyed by the control instance, which is unique per deck rebuild).
local PORTAL_OPEN_SIZE = Vector3.new(4, 8, 0.6)
local OPEN_TIME = 0.25
local IDLE_CLOSE = 5 -- shrink this many seconds after the last step-through (or after opening)
local TWEEN_INFO = TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function PortalController:_openThreshold(control: Instance, _opener: Player)
    if not control:IsA("BasePart") then
        return
    end
    if self._openThresholds[control] ~= nil then
        return -- already open
    end
    self._openThresholds[control] = control
    local pt = self._d.portalTarget
    local markerSize = control.Size
    local markerCF = control.CFrame
    -- grow upward from the marker's base so the full doorway stands on the deck
    local baseCF = markerCF * CFrame.new(0, -markerSize.Y / 2, 0)
    local openCF = baseCF * CFrame.new(0, PORTAL_OPEN_SIZE.Y / 2, 0)
    local prompt = control:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        prompt.Enabled = false -- can't re-open while open
    end
    control.Transparency = 0.3 -- reads as a portal surface, not a solid marker, while open

    local closing = false
    local deadline = os.clock() + IDLE_CLOSE
    local debounce: { [Player]: boolean } = {}
    local touchConn: RBXScriptConnection? = nil

    local function closePortal()
        if closing then
            return
        end
        closing = true
        if touchConn then
            touchConn:Disconnect()
        end
        local shrink = TweenService:Create(control, TWEEN_INFO, { Size = markerSize, CFrame = markerCF })
        shrink.Completed:Connect(function()
            if control.Parent ~= nil then
                control.Transparency = 0
                control.Size = markerSize
                control.CFrame = markerCF
                if prompt then
                    prompt.Enabled = true
                end
            end
            if self._openThresholds[control] == control then
                self._openThresholds[control] = nil
            end
        end)
        shrink:Play()
    end

    -- fires at the current deadline; if a step-through pushed it forward, waits the new remaining
    local function scheduleClose()
        task.delay(math.max(0, deadline - os.clock()), function()
            if closing then
                return
            end
            if os.clock() >= deadline - 0.01 then
                closePortal()
            else
                scheduleClose()
            end
        end)
    end

    touchConn = control.Touched:Connect(function(hit)
        local player = self._d.players:GetPlayerFromCharacter(hit.Parent)
        if player == nil or debounce[player] then
            return -- anyone on the deck may pass; per-player debounce guards multi-part touches
        end
        debounce[player] = true
        task.delay(1, function()
            debounce[player] = nil
        end)
        local char = player.Character
        if char then
            char:PivotTo(CFrame.new(table.unpack(pt.ARENA_LANDING)))
        end
        if not closing then
            deadline = os.clock() + IDLE_CLOSE -- 5s from this use
        end
    end)
    TweenService:Create(control, TWEEN_INFO, { Size = PORTAL_OPEN_SIZE, CFrame = openCF }):Play()
    scheduleClose()
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
