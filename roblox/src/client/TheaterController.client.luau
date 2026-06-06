--!strict
-- Executes choreography cues: builds the cue schedule from RevealTheater and
-- phase changes, fires them onto the EventBus, and plays the simple
-- placeholder consequence effects (petals, umbrella). Fates are handled by
-- FateController; UI toasts by main.client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Choreo = require(shared:WaitForChild("ChoreographyMachine"))
local EffectRegistry = require(shared:WaitForChild("EffectRegistry"))
local EffectSelector = require(shared:WaitForChild("EffectSelector"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local selector = EffectSelector.new(EffectRegistry, { random = math.random })

local function characterOf(userId: string): Model?
    for _, p in Players:GetPlayers() do
        if tostring(p.UserId) == userId then
            return p.Character
        end
    end
    return nil
end

local function petals(character: Model)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 217, 138))
    emitter.Lifetime = NumberRange.new(1, 1.8)
    emitter.Speed = NumberRange.new(4, 7)
    emitter.Rate = 0
    emitter.Parent = head
    emitter:Emit(30)
    task.delay(2.5, function()
        emitter:Destroy()
    end)
end

local function umbrella(character: Model)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end
    local canopy = Instance.new("Part")
    canopy.Shape = Enum.PartType.Cylinder
    canopy.Anchored = true
    canopy.CanCollide = false
    canopy.Color = Color3.fromRGB(179, 74, 58)
    canopy.Size = Vector3.new(0.4, 0.5, 0.5)
    canopy.CFrame = head.CFrame * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90))
    canopy.Parent = workspace
    TweenService:Create(canopy, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.new(0.4, 6, 6) })
        :Play()
    task.delay(2, function()
        TweenService
            :Create(canopy, TweenInfo.new(0.3), { Size = Vector3.new(0.4, 0.5, 0.5), Transparency = 1 })
            :Play()
        task.delay(0.35, function()
            canopy:Destroy()
        end)
    end)
end

local function execute(cue: any)
    EventBus.Cue:Fire(cue)
    if cue.kind == "consequence" then
        local character = characterOf(cue.userId)
        if not character then
            return
        end
        if cue.effect == "growPetals" then
            petals(character) -- the grow itself is server-side (replicated scale)
        elseif cue.effect == "umbrellaPop" then
            umbrella(character)
        end
        -- fate* effects are consumed by FateController via the same Cue event
    end
end

RoundUpdate.OnClientEvent:Connect(function(info)
    for _, kind in Choreo.phaseCues(info.phase) do
        EventBus.Cue:Fire({ kind = kind })
    end
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    local cues = Choreo.revealCues(reveal, {
        staggerMaxMs = 600,
        random = math.random,
        selectEffect = function(slot, ctx)
            return selector:select(slot, ctx)
        end,
    })
    for _, cue in cues do
        task.delay(cue.atMs / 1000, execute, cue)
    end
end)
