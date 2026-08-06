--!strict
-- THE PHASE PLAYER. Compiles a recipe against the distance-appropriate budget and executes the
-- resulting schedule from fixed pools. It knows nothing about any particular shell — a new shell is
-- a row in FireworkCatalog and this file does not change.
--
-- THREE LESSONS THE 2026-07-20 BENCH PAID FOR, none of them optional:
--   1. ParticleEmitter:Emit() does NOT replicate server->client. Emission happens HERE, on each
--      client, from a tiny server event. A server-side :Emit() is simply invisible.
--   2. An emitter with Texture == "" renders nothing. Every burst phase names one.
--   3. Launch relative to something real. The bench's first pass fired at the world origin, 110
--      studs below the player, and showed nothing.
--
-- NO PER-SHELL DYNAMIC LIGHTS. The single biggest killer on mobile. Glow is LightEmission plus the
-- one global Bloom; a PointLight per burst would undo the entire budget.
--
-- NOTHING HERE IS TESTED. No harness in this repo loads a `.client.luau`, which is exactly why
-- every DECISION lives in FireworkDirector and FireworkSchedule, both pure and both covered. This
-- file owns instances and does what it is told. A green suite says nothing about whether a firework
-- appears — that needs eyes in Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local FireworkCatalog = require(shared:WaitForChild("FireworkCatalog"))
local FireworkSchedule = require(shared:WaitForChild("FireworkSchedule"))
local FireworkDirector = require(shared:WaitForChild("FireworkDirector"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FireworkLaunched = remotes:WaitForChild("FireworkLaunched") :: RemoteEvent

-- ONE global Bloom, reused if the place already has one. Creating a second stacks a whole extra
-- full-screen post pass — the v1 bench did exactly that against the shipped Lighting.Bloom and
-- nobody attributed the cost or the washed-out look to it.
if not Lighting:FindFirstChildOfClass("BloomEffect") then
    local bloom = Instance.new("BloomEffect")
    bloom.Name = "FireworkBloom"
    bloom.Intensity = 0.6
    bloom.Size = 24
    bloom.Threshold = 0.95
    bloom.Parent = Lighting
end

local folder = Instance.new("Folder")
folder.Name = "FireworkPool"
folder.Parent = workspace

-- MAX_POINTS burst parts per slot, because a nested break happens at several places AT ONCE and
-- :Emit() fires wherever its part currently is — one part cannot be in six places in one frame.
local MAX_POINTS = 8
local POOL_SIZE = FireworkDirector.MAX_CONCURRENT + 4

type Slot = {
    shell: BasePart,
    trail: Trail,
    points: { BasePart },
    emitters: { ParticleEmitter },
    sound: Sound,
}
local pool: { Slot } = {}
local poolNext = 1
local active = 0

for _ = 1, POOL_SIZE do
    local shell = Instance.new("Part")
    shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch = true, false, false, false
    shell.CastShadow = false
    shell.Transparency = 1
    shell.Size = Vector3.new(1, 1, 1)
    shell.Parent = folder

    -- The ascent comet. A Trail is property-driven rather than :Emit()-driven, so unlike the burst
    -- it WOULD have replicated from the server — it lives here anyway so a shell is one pooled
    -- object with one lifetime.
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Position, a1.Position = Vector3.new(0, -0.5, 0), Vector3.new(0, 0.5, 0)
    a0.Parent, a1.Parent = shell, shell
    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = a0, a1
    trail.Lifetime = 0.45
    trail.LightEmission = 1
    trail.Enabled = false
    trail.Parent = shell

    -- ONE Sound per slot, not one per phase. A shell's phases never overlap in time, and a
    -- sub-burst volley plays ONE report rather than six — six voices of one clip is noise and six
    -- times the mixer cost.
    local snd = Instance.new("Sound")
    snd.RollOffMode = Enum.RollOffMode.InverseTapered
    snd.RollOffMaxDistance = FireworkDirector.NEAR_STUDS
    snd.Parent = shell

    local points, emitters = {}, {}
    for _ = 1, MAX_POINTS do
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
        p.CastShadow = false
        p.Transparency = 1
        p.Size = Vector3.new(1, 1, 1)
        p.Parent = folder
        local em = Instance.new("ParticleEmitter")
        em.Enabled = false -- burst-only; :Emit() drives it
        em.LightEmission = 1
        em.Rate = 0
        em.Speed = NumberRange.new(20, 60)
        em.Lifetime = NumberRange.new(1.2, 2.4)
        em.Parent = p
        table.insert(points, p)
        table.insert(emitters, em)
    end

    table.insert(pool, { shell = shell, trail = trail, points = points, emitters = emitters, sound = snd })
end

local WHITE = { 255, 255, 255 }

local function colorOf(rgb: { number }?): Color3
    local c = rgb or WHITE
    return Color3.fromRGB(c[1], c[2], c[3])
end

local function playSound(slot: Slot, id: string?, audible: boolean)
    if id and audible then
        slot.sound.SoundId = id
        slot.sound:Play()
    end
end

local function fireBurst(slot: Slot, ev: any, anchorPos: Vector3, rng: Random)
    -- `points` break locations scattered around the anchor. `particles` is PER POINT — the schedule
    -- already divided the shell's budget, so this must never multiply it back up.
    local n = math.min(ev.points, MAX_POINTS)
    for i = 1, n do
        local p, em = slot.points[i], slot.emitters[i]
        local off = if ev.scatter > 0
            then Vector3.new(
                rng:NextNumber(-ev.scatter, ev.scatter),
                rng:NextNumber(-ev.scatter, ev.scatter) * 0.6,
                rng:NextNumber(-ev.scatter, ev.scatter)
            )
            else Vector3.zero
        p.Position = anchorPos + off
        em.Texture = ev.texture or ""
        em.Color = ColorSequence.new(colorOf(ev.color), colorOf(ev.edgeColor or ev.color))
        em.Size = NumberSequence.new((ev.spread or 30) / 40)
        em.Acceleration = if ev.droop then Vector3.new(0, -28, 0) else Vector3.new(0, -6, 0)
        em:Emit(ev.particles)
    end
end

local function play(payload: any, distance: number)
    local recipe = FireworkCatalog.RECIPES[payload.shellId]
    if not recipe then
        return -- the contract test exists so this cannot happen in a shipped build
    end
    local slot = pool[poolNext]
    poolNext = (poolNext % POOL_SIZE) + 1

    local lod = FireworkDirector.lodFor(distance)
    local schedule = FireworkSchedule.compile(recipe, lod.particles)

    -- THE SEED IS WHY EVERY CLIENT SEES THE SAME SHOW. Without it each machine rolls its own
    -- apex and its own scatter, and two people watching one firework cannot talk about what they
    -- saw. The server sends one per launch.
    local rng = Random.new(payload.seed)
    local origin = payload.origin
    local apex = origin
        + Vector3.new(rng:NextNumber(-8, 8), 46 + rng:NextNumber(-6, 6), rng:NextNumber(-8, 8))

    local last = 0
    for _, ev in schedule do
        last = math.max(last, ev.at)
    end

    active += 1
    for _, ev in schedule do
        task.delay(ev.at, function()
            local anchorPos = if ev.anchor == "apex" then apex else origin
            if ev.kind == "report" then
                slot.shell.Position = origin
                playSound(slot, ev.sound, lod.sound)
            elseif ev.kind == "ascent" then
                slot.shell.Position = origin
                slot.trail.Color = ColorSequence.new(colorOf(ev.color))
                slot.trail.Enabled = true
                playSound(slot, ev.sound, lod.sound)
                -- The comet rises to the apex over whatever time the next phase leaves it.
                local rise = math.max(0.05, last - ev.at)
                TweenService:Create(
                    slot.shell,
                    TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Position = apex }
                ):Play()
            elseif ev.kind == "burst" then
                slot.trail.Enabled = false
                playSound(slot, ev.sound, lod.sound)
                fireBurst(slot, ev, anchorPos, rng)
            end
        end)
    end

    -- Released after the last phase plus the longest particle lifetime, so the slot is not reused
    -- while its own sparks are still on screen.
    task.delay(last + 2.6, function()
        active -= 1
        slot.trail.Enabled = false
    end)
end

FireworkLaunched.OnClientEvent:Connect(function(payload)
    if
        typeof(payload) ~= "table"
        or typeof(payload.origin) ~= "Vector3"
        or typeof(payload.seed) ~= "number"
        or typeof(payload.shellId) ~= "string"
    then
        return
    end
    local cam = workspace.CurrentCamera
    local distance = if cam then (cam.CFrame.Position - payload.origin).Magnitude else 0
    local decision = FireworkDirector.admit(active, distance)
    if not decision.render then
        return
    end
    if decision.delayMs > 0 then
        task.delay(decision.delayMs / 1000, function()
            play(payload, distance)
        end)
    else
        play(payload, distance)
    end
end)
