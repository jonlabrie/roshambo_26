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

-- ===== THE DRUM-REST GATE =====
-- RevealTheater lands about three seconds BEFORE the throw drum finishes turning, so scheduling the
-- choreography off its arrival gave the round away while the wheel was still spinning: the petals
-- (and the server's avatar grow alongside them) fired on a player whose result was not yet on the
-- drum. main.client.luau and LanternController already hold their reveal and paint on the `drumRest`
-- cue (fired by DrumController when the glide settles); this is the same treatment.
--
-- The cue offsets stay RELATIVE — `Choreo.revealCues` returns `atMs` measured from the start of the
-- choreography, and the schedule is built at flush time so the whole sequence simply starts later
-- with its internal timing intact. Building it early and subtracting would have been the way to
-- shift it.
local REVEAL_SAFETY = 3 -- seconds before a dropped drumRest cue is assumed lost
local pendingReveal: any = nil
local drumAtRest = false

local function runReveal(reveal: any)
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
end

local function maybeRunReveal()
    if pendingReveal and drumAtRest then
        local reveal = pendingReveal
        pendingReveal = nil
        runReveal(reveal)
    end
end

RoundUpdate.OnClientEvent:Connect(function(info)
    for _, kind in Choreo.phaseCues(info.phase) do
        EventBus.Cue:Fire({ kind = kind })
    end
    if info.phase == "ACTIVE" then
        -- The drum respins for the new round, so last round's rest no longer counts as this one's.
        -- `pendingReveal` is deliberately NOT cleared here: REVEAL is ~3s and so is the safety
        -- below, so this boundary and that timer race — clearing would occasionally drop a round's
        -- choreography entirely, which is the one outcome worse than playing it late. The safety
        -- always consumes it within REVEAL_SAFETY, so there is nothing to clear that will not have
        -- cleared itself.
        drumAtRest = false
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        drumAtRest = true
        maybeRunReveal()
    end
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    pendingReveal = reveal
    maybeRunReveal() -- only runs if the drum has already settled
    -- CHOREOGRAPHY THAT NEVER PLAYS IS WORSE THAN CHOREOGRAPHY THAT PLAYS EARLY. If the drumRest
    -- cue is dropped — DrumController's own stall guard reset it, the client joined mid-glide —
    -- run anyway. Compared by IDENTITY to the current pending reveal so a later round's payload,
    -- already waiting on its own gate, is never flushed by an older round's timer.
    task.delay(REVEAL_SAFETY, function()
        if pendingReveal == reveal then
            drumAtRest = true
            maybeRunReveal()
        end
    end)
end)
