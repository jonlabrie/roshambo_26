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
local FireworkDrafts = require(shared:WaitForChild("FireworkDrafts"))
local FireworkSchedule = require(shared:WaitForChild("FireworkSchedule"))
local FireworkDirector = require(shared:WaitForChild("FireworkDirector"))
local BurstStyles = require(shared:WaitForChild("BurstStyles"))

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
local MAX_POINTS = BurstStyles.MAX_POINTS
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
    snd.Volume = BurstStyles.SOUND_LEVELS.volume
    snd.RollOffMinDistance = BurstStyles.SOUND_LEVELS.rolloffMin
    snd.RollOffMaxDistance = BurstStyles.SOUND_LEVELS.rolloffMax
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
        em.LightInfluence = 0 -- default 1 lets scene light DIM the stars, worst at night (spec §7)
        em.Rate = 0
        -- Everything else — SpreadAngle, Drag, Transparency, Speed, Lifetime, Brightness,
        -- Acceleration — is a style property (BurstStyles.STYLES), applied per emit by
        -- fireBurst below. The pool sets only what's invariant across every style and shell.
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

-- The keypoint list -> NumberSequence conversion, memoized per style table identity so it isn't
-- rebuilt on every emit (styles are static module-level tables, so identity is stable for the
-- program's whole life — nothing to evict).
local transparencyCache: { [BurstStyles.Style]: NumberSequence } = {}
local function transparencyOf(style: BurstStyles.Style): NumberSequence
    local cached = transparencyCache[style]
    if cached then
        return cached
    end
    local keypoints = {}
    for i, kp in style.transparency do
        keypoints[i] = NumberSequenceKeypoint.new(kp[1], kp[2])
    end
    local seq = NumberSequence.new(keypoints)
    transparencyCache[style] = seq
    return seq
end

local function fireBurst(slot: Slot, ev: any, anchorPos: Vector3, rng: Random)
    -- `frames` are the style's point rule turning ev.points into per-part placement/orientation —
    -- ring/kamuro's rules always collapse to a single frame, so this iterates #frames, NOT
    -- ev.points: one part cannot stand in for eight positions in one frame.
    local style = BurstStyles.styleOf(ev.style)
    local frames = BurstStyles.pointFrames(ev.style, math.min(ev.points, MAX_POINTS), ev.scatter, function()
        return rng:NextNumber()
    end)

    -- Budget is sacred: normally `particles` is PER POINT, exactly as scheduled. Compensation
    -- only applies to the deliberate single-frame collapse (tilted/single rules, ring/kamuro),
    -- where one physical frame stands in for the whole points' worth of break locations, so that
    -- frame emits ev.particles * ev.points to match the scheduled total. Any other shortfall —
    -- e.g. pointFrames clamping scatter/circle to MAX_POINTS frames — is left alone: the frames
    -- that exist each emit their per-point share, which UNDER-emits relative to what was
    -- scheduled. Budget is never exceeded, only sometimes not fully spent.
    local particles = if #frames == 1 and ev.points > 1 then ev.particles * ev.points else ev.particles

    local texture = ev.texture or BurstStyles.TEXTURES[style.textureRole]
    local color = ColorSequence.new(colorOf(ev.color), colorOf(ev.edgeColor or ev.color))
    local size = NumberSequence.new((ev.spread or 30) / 40)
    local acceleration = if ev.droop == true
        then Vector3.new(0, -28, 0)
        else Vector3.new(style.acceleration[1], style.acceleration[2], style.acceleration[3])
    local speed = NumberRange.new(style.speed[1], style.speed[2])
    local lifetime = NumberRange.new(style.lifetime[1], style.lifetime[2])
    local spreadAngle = Vector2.new(style.spreadAngle[1], style.spreadAngle[2])
    local transparency = transparencyOf(style)

    for i, f in frames do
        local p, em = slot.points[i], slot.emitters[i]
        -- Frame `rot` is an XYZ Euler triple authored against RotX*RotY*RotZ composition;
        -- CFrame.Angles applies in exactly that order (it IS fromEulerAnglesXYZ).
        p.CFrame = CFrame.new(anchorPos + Vector3.new(f.pos[1], f.pos[2], f.pos[3]))
            * CFrame.Angles(math.rad(f.rot[1]), math.rad(f.rot[2]), math.rad(f.rot[3]))
        em.Texture = texture
        em.Color = color
        em.Size = size
        em.Speed = speed
        em.Drag = style.drag
        em.Lifetime = lifetime
        em.Brightness = style.brightness
        em.SpreadAngle = spreadAngle
        em.Acceleration = acceleration
        em.Transparency = transparency
        em:Emit(particles)
    end
end

local function play(payload: any, distance: number)
    -- Shipped shells first, then proving drafts ("draft:family/variant" — Studio only;
    -- resolve() is nil for anything else). Same interpreter either way: what the range
    -- proves is exactly what a player will get.
    local recipe = FireworkCatalog.RECIPES[payload.shellId] or FireworkDrafts.resolve(payload.shellId)
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

    -- `tail` is the longest release-worthy lifetime among this shell's burst styles (kamuro's
    -- 4.2s crown must not have its slot's parts re-positioned under it while it's still hanging).
    local last = 0
    local tail = 0
    for _, ev in schedule do
        last = math.max(last, ev.at)
        if ev.kind == "burst" then
            tail = math.max(tail, BurstStyles.releaseTail(ev.style))
        end
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
                -- A recipe may pin a burst sound; otherwise the style's role resolves to a
                -- VARIANT POOL and the shell's seeded rng picks one — same clip on every
                -- client, different clip per shell, so a show is not one boom on repeat.
                -- ⚠ The draw sits immediately before fireBurst's own draws, so the per-burst
                -- rng order stays a pure function of the payload.
                local soundId = ev.sound
                if not soundId then
                    local pool = BurstStyles.SOUNDS[BurstStyles.styleOf(ev.style).soundRole]
                    if typeof(pool) == "table" then
                        soundId = pool[rng:NextInteger(1, #pool)]
                    else
                        soundId = pool
                    end
                end
                playSound(slot, soundId, lod.sound)
                fireBurst(slot, ev, anchorPos, rng)
            end
        end)
    end

    -- Released after the last phase plus the longest burst style's release tail, so the slot is
    -- not reused — and its parts repositioned — while its own sparks are still on screen.
    task.delay(last + tail + 0.2, function()
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
