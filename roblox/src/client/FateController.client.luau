--!strict
-- The Three Fates (spec §6.1), placeholder visuals. Per-victim authority:
-- the LOCAL player's pursuit is simulated here authoritatively (contact or
-- acceptance fires FateResolved); other victims' dooms are approximations
-- that snap on the broadcast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Doom = require(shared:WaitForChild("DoomEscalation"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FateResolved = remotes:WaitForChild("FateResolved") :: RemoteEvent

local localPlayer = Players.LocalPlayer

type Flight = {
    userId: string,
    fateId: string,
    startedAt: number,
    lastSpawn: number,
    entities: { BasePart },
    accepted: boolean,
    resolving: boolean,
}
local flights: { [string]: Flight } = {}

local function characterOf(userId: string): Model?
    for _, p in Players:GetPlayers() do
        if tostring(p.UserId) == userId then
            return p.Character
        end
    end
    return nil
end

local function makeEntity(fateId: string, near: Vector3): BasePart
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    if fateId == "fateBoulder" then
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(6, 6, 6)
        part.Color = Color3.fromRGB(110, 105, 95)
        part.Position = near + Vector3.new(math.random(-8, 8), 40, math.random(-8, 8))
    elseif fateId == "fatePaper" then
        part.Size = Vector3.new(2.4, 0.1, 3.2)
        part.Color = Color3.fromRGB(245, 239, 223)
        part.Position = near + Vector3.new(math.random(-20, 20), math.random(4, 10), math.random(-20, 20))
    else -- fateShears: rises from the ground ahead
        part.Size = Vector3.new(0.6, 4, 1.6)
        part.Color = Color3.fromRGB(180, 184, 190)
        part.Position = near + Vector3.new(math.random(-10, 10), -3, math.random(-10, 10))
        TweenService:Create(
            part,
            TweenInfo.new(0.4, Enum.EasingStyle.Back),
            { Position = part.Position + Vector3.new(0, 4, 0) }
        ):Play()
    end
    part.Parent = workspace
    return part
end

local function squash(character: Model)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        local dust = Instance.new("ParticleEmitter")
        dust.Rate = 0
        dust.Lifetime = NumberRange.new(0.5, 1)
        dust.Parent = root
        dust:Emit(20)
        task.delay(1.2, function()
            dust:Destroy()
        end)
    end
end

local function endFlight(userId: string)
    local flight = flights[userId]
    if not flight then
        return
    end
    for _, e in flight.entities do
        e:Destroy()
    end
    flights[userId] = nil
    local character = characterOf(userId)
    if character then
        squash(character)
    end
end

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "consequence" and cue.effect and cue.effect:sub(1, 4) == "fate" then
        flights[cue.userId] = {
            userId = cue.userId,
            fateId = cue.effect,
            startedAt = os.clock(),
            lastSpawn = 0,
            entities = {},
            accepted = false,
            resolving = false,
        }
    elseif cue.kind == "acceptFate" then
        local flight = flights[tostring(localPlayer.UserId)]
        if flight then
            flight.accepted = true
        end
    end
end)

FateResolved.OnClientEvent:Connect(function(userId: string)
    endFlight(userId)
end)

RunService.Heartbeat:Connect(function(dt)
    for userId, flight in flights do
        local character = characterOf(userId)
        local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root then
            continue
        end
        local now = os.clock()
        local elapsed = now - flight.startedAt
        local stage = Doom.stageAt(elapsed)

        if
            now - flight.lastSpawn >= Doom.spawnInterval(flight.fateId, stage)
            and #flight.entities < Doom.entityCap(flight.fateId, stage)
        then
            flight.lastSpawn = now
            table.insert(flight.entities, makeEntity(flight.fateId, root.Position))
        end

        local speed = Doom.speed(flight.fateId, stage)
        local isLocal = userId == tostring(localPlayer.UserId)
        local caught = false
        for _, e in flight.entities do
            if flight.fateId ~= "fateShears" then
                local p = Doom.homingStep(
                    { x = e.Position.X, y = e.Position.Y, z = e.Position.Z },
                    { x = root.Position.X, y = root.Position.Y + 2, z = root.Position.Z },
                    speed,
                    dt
                )
                e.Position = Vector3.new(p.x, p.y, p.z)
            end
            if isLocal and (e.Position - root.Position).Magnitude < 3.5 then
                caught = true
            end
        end

        if isLocal then
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local victimSpeed = humanoid and humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed or 0
            if
                not flight.resolving
                and (flight.accepted or caught or Doom.shouldFastCatch(victimSpeed, elapsed))
            then
                FateResolved:FireServer(if flight.accepted then "accepted" else "caught")
                flight.resolving = true
                flight.accepted = false
                flight.startedAt = now + 60 -- debounce until the broadcast clears it
            end
        end
    end
end)
