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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local FireworkCatalog = require(shared:WaitForChild("FireworkCatalog"))
local FireworkDrafts = require(shared:WaitForChild("FireworkDrafts"))
local FireworkSchedule = require(shared:WaitForChild("FireworkSchedule"))
local FireworkDirector = require(shared:WaitForChild("FireworkDirector"))
local BurstStyles = require(shared:WaitForChild("BurstStyles"))
local MortarPlacement = require(shared:WaitForChild("MortarPlacement"))

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
    sound: Sound, -- burstVoices[1]; kept as the named main voice
    burstVoices: { Sound }, -- rotated per break phase so adjacent breaks never share
    tail: Sound, -- the SECOND voice: a style's tailSound (the owner's canyon sizzle over
    -- hotaru's final flicker) deliberately OVERLAPS the burst's decay, so it cannot share
    -- the main Sound -- that one's SoundId swap would cut whichever clip was still playing.
    -- Salvo voices (owner, 2026-09-06): a salute grouping overlaps its own 3s clips, so each
    -- shot needs its own Sound. Built at pool construction with the salute clip PREASSIGNED
    -- -- they only ever play that one clip, and eager creation means they are loaded before
    -- the first fire. Lazy creation was the first-shell bug: three fresh Sounds all played
    -- before their clip bound, and the engine released all three booms together, late, while
    -- the 0.1s flashes died unloaded (owner, 2026-09-06, reproduced six times).
    salvoVoices: { Sound },
    -- Launch voices, one per thump clip, PREASSIGNED at pool build (owner, 2026-09-06:
    -- "sometimes the thump doesn't actually play until the shell is already high overhead").
    -- The slot's main Sound swaps SoundId between thump and break clips, and a Play() before
    -- the new clip binds is QUEUED by the engine until it does -- usually ~30ms, occasionally
    -- seconds. A launch never has slack to hide that; the break at t+3s does. So launches get
    -- voices that never swap and never bind at fire time; slot.sound keeps the breaks.
    launchVoices: { [string]: Sound },
    -- The HEAVY ascent's second layer (owner, 2026-09-06, after the Trail-widening
    -- retreat): a particle comet streaming glow sparks behind the rising shell — how a
    -- big shell reads in a real display (burning debris, not a wider ribbon). Purely
    -- ADDITIVE: the pinned trails-approved Trail is untouched; killing this layer
    -- restores it exactly. Dedicated emitter, so its properties are set ONCE at pool
    -- build (only Color, Size and Rate move per launch) — the shared-emitter full-write
    -- discipline doesn't apply.
    comet: ParticleEmitter,
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
    -- ⚠ LONG ENOUGH TO STAY ROOTED AT THE TUBE. At 0.45 the tail end of the ribbon faded
    -- before the eye caught the comet, so every launch read as starting mid-air (owner,
    -- 2026-09-03: "launch beginnings still well overhead"). 2.4s keeps the ribbon anchored
    -- at the muzzle for most of a ~3s flight (owner ruling 2026-09-03: ~3s average).
    trail.Lifetime = 2.4
    -- ⚠ THE TAIL DIES BY FADING, NOT BY ERASURE (owner, 2026-09-03: the hard Lifetime
    -- eraser read as a constant-rate wipe; "the last thing we see should be the last bit
    -- of trail fading to full transparency"). The gradient runs head (0) -> oldest (1):
    -- fully transparent well before the eraser, so the cut edge is never visible; the
    -- PERCEIVED tail end is the fade, which retraces the shell's own decelerating path.
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.6, 0.45),
        NumberSequenceKeypoint.new(0.85, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    -- comet taper: full width at the shell, needle at the tail
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0.2),
    })
    trail.LightEmission = 1
    trail.Enabled = false
    trail.Parent = shell

    -- THREE burst voices, rotated per break. The original "one Sound per slot -- a shell's
    -- phases never overlap" assumption died with multi-burst shells: hotaru-boosted's two
    -- clouds sit 0.5s apart and dan's acts 0.6s, while a break clip runs ~2s -- one voice
    -- meant every following break CUT the previous boom mid-ring (owner, 2026-09-06:
    -- "at least one burst has no associated aerial audio... cut off by the previous or
    -- next wave"). Three voices cover any adjacent trio; a sub-burst volley still plays
    -- ONE report per phase, never one per point.
    local burstVoices: { Sound } = {}
    for _ = 1, 3 do
        local v = Instance.new("Sound")
        v.RollOffMode = Enum.RollOffMode.InverseTapered
        v.Volume = BurstStyles.SOUND_LEVELS.volume
        v.RollOffMinDistance = BurstStyles.SOUND_LEVELS.rolloffMin
        v.RollOffMaxDistance = BurstStyles.SOUND_LEVELS.rolloffMax
        v.Parent = shell
        table.insert(burstVoices, v)
    end
    local snd = burstVoices[1]

    local tailSnd = Instance.new("Sound")
    tailSnd.RollOffMode = Enum.RollOffMode.InverseTapered
    tailSnd.RollOffMinDistance = BurstStyles.SOUND_LEVELS.rolloffMin
    tailSnd.RollOffMaxDistance = BurstStyles.SOUND_LEVELS.rolloffMax
    tailSnd.Parent = shell

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
        em.LightInfluence = 0 -- default 1 lets scene light DIM the stars, worst at night (spec §7)
        em.Rate = 0
        -- Everything else — LightEmission (the stacking law, per style since 2026-09-03),
        -- SpreadAngle, Drag, Transparency, Speed, Lifetime, Brightness, Acceleration — is a
        -- style property (BurstStyles.STYLES), applied per emit by fireBurst below. The pool
        -- sets only what's invariant across every style and shell.
        em.Parent = p
        table.insert(points, p)
        table.insert(emitters, em)
    end

    -- The heavy comet layer: Rate-driven (the one emitter in the system that is — the
    -- shell's continuous motion does the streaming; particles spawn at the shell and lag
    -- behind in world space). Budget disclosure: rate 90 x ~0.55s mean life ≈ 50 alive,
    -- ~6% of a heavy shell's doubled (800) budget (owner-tuned 2026-09-06).
    local comet = Instance.new("ParticleEmitter")
    comet.Enabled = false
    comet.Rate = 0 -- armed per heavy launch
    comet.LightInfluence = 0
    comet.Texture = BurstStyles.TEXTURES.dot
    comet.Lifetime = NumberRange.new(0.35, 0.7)
    comet.Speed = NumberRange.new(2, 6)
    comet.SpreadAngle = Vector2.new(180, 180)
    comet.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(1, 0.12),
    })
    comet.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    comet.Acceleration = Vector3.new(0, -18, 0)
    comet.Drag = 1.5
    comet.Brightness = 2.5
    comet.LightEmission = 0.85 -- the stacking law: sparks overlap the Trail constantly
    comet.Orientation = Enum.ParticleOrientation.FacingCamera
    comet.Parent = shell

    local launchVoices: { [string]: Sound } = {}
    local function addLaunchVoice(id: string)
        local v = Instance.new("Sound")
        v.SoundId = id
        v.Volume = BurstStyles.SOUND_LEVELS.volume
        v.RollOffMode = Enum.RollOffMode.InverseTapered
        v.RollOffMinDistance = BurstStyles.SOUND_LEVELS.rolloffMin
        v.RollOffMaxDistance = BurstStyles.SOUND_LEVELS.rolloffMax
        v.Parent = shell
        launchVoices[id] = v
    end
    for _, id in BurstStyles.SOUNDS.launch do
        addLaunchVoice(id)
    end
    addLaunchVoice(BurstStyles.SOUNDS.launch_medium)
    addLaunchVoice(BurstStyles.SOUNDS.launch_heavy)

    -- 8 = the salvo count ceiling (FireworkRecipes: boost.salvo.count admits 1..8; 5-8 is
    -- the reserved standalone-salute range). All voices share one loaded buffer.
    local salvoVoices = {}
    for _ = 1, 8 do
        local voice = Instance.new("Sound")
        voice.SoundId = BurstStyles.SOUNDS.salute
        voice.RollOffMode = Enum.RollOffMode.InverseTapered
        voice.RollOffMinDistance = BurstStyles.SOUND_LEVELS.rolloffMin
        voice.RollOffMaxDistance = BurstStyles.SOUND_LEVELS.rolloffMax
        voice.Parent = shell
        table.insert(salvoVoices, voice)
    end

    table.insert(pool, {
        shell = shell,
        trail = trail,
        points = points,
        emitters = emitters,
        sound = snd,
        burstVoices = burstVoices,
        tail = tailSnd,
        salvoVoices = salvoVoices,
        launchVoices = launchVoices,
        comet = comet,
    })
end

local WHITE = { 255, 255, 255 }

local function colorOf(rgb: { number }?): Color3
    local c = rgb or WHITE
    return Color3.fromRGB(c[1], c[2], c[3])
end

-- ⚠ SOUND TRAVELS. Each phase sound is delayed by this listener's distance to its source
-- over the speed of sound — the flash is instant, the thump crosses the canyon. Per client,
-- so the bridge hears it tight and FallsLanding hears the ~0.17s of physics. Phase order is
-- safe: every phase of one shell gets a near-identical delay, so nothing reorders.
local function playSound(
    slot: Slot,
    id: string?,
    audible: boolean,
    from: Vector3,
    speed: number?,
    voice: Sound?,
    volumeScale: number?
)
    if not (id and audible) then
        return
    end
    local cam = workspace.CurrentCamera
    local dist = if cam then (cam.CFrame.Position - from).Magnitude else 0
    local snd = voice or slot.sound
    local function fire()
        -- Set EVERY play: a re-pop leaves its voice quiet, and the next break on that
        -- voice must come back at full volume.
        snd.Volume = BurstStyles.SOUND_LEVELS.volume * (volumeScale or 1)
        snd.SoundId = id
        -- Per-shell jitter (seeded, so every client hears the same shell the same way):
        -- ±8% speed shifts pitch and length together, and even one clip stops sounding
        -- like itself on repeat (owner, 2026-09-04: "they all sound the same"). The birds
        -- run ±3% for the same reason.
        snd.PlaybackSpeed = speed or 1
        snd:Play()
        -- Seek past a clip's measured pre-roll so the transient lands ON the event
        -- (BurstStyles.SOUND_TRIMS; the deck-launch thump carried ~0.2s of head).
        local trim = BurstStyles.SOUND_TRIMS[id]
        if trim then
            snd.TimePosition = trim
        end
    end
    local delay = dist / BurstStyles.SOUND_LEVELS.speedOfSound
    -- ⚠ SUB-FRAME DELAYS RUN INLINE. task.delay(0) still parks the thunk until the next
    -- Heartbeat — a whole frame of silence for a listener standing AT the tube, where the
    -- ear is least forgiving (owner, 2026-09-06: lag persisted after the head trim; the
    -- residue was frame-hops, not the clip).
    if delay < 1 / 60 then
        fire()
    else
        task.delay(delay, fire)
    end
end

-- The launch thump's own player: uses the slot's PREASSIGNED voice for the clip, so the
-- fire-time path touches no SoundId — nothing to bind, nothing for the engine to queue.
-- A clip outside the launch set (a draft's pinned launch sound) falls back to the swap path.
local function playLaunch(slot: Slot, id: string?, audible: boolean, from: Vector3, speed: number?)
    if not (id and audible) then
        return
    end
    local voice = slot.launchVoices[id]
    if voice == nil then
        playSound(slot, id, audible, from, speed)
        return
    end
    local cam = workspace.CurrentCamera
    local dist = if cam then (cam.CFrame.Position - from).Magnitude else 0
    local function fire()
        voice.PlaybackSpeed = speed or 1
        voice:Play()
        local trim = BurstStyles.SOUND_TRIMS[id]
        if trim then
            voice.TimePosition = trim
        end
    end
    local delay = dist / BurstStyles.SOUND_LEVELS.speedOfSound
    if delay < 1 / 60 then
        fire()
    else
        task.delay(delay, fire)
    end
end

-- ⚠ PRELOAD EVERY SOUND AND SPRITE ONCE, AT STARTUP. A Sound's first :Play() otherwise
-- streams the asset from the CDN mid-show, and the session's first launch thump arrives
-- while the shell is already climbing (owner, 2026-09-03). Async: the show can start
-- before this finishes; it only moves the cost off the first shell.
task.spawn(function()
    local ContentProvider = game:GetService("ContentProvider")
    local warm = {}
    local seen: { [string]: boolean } = {}
    local function add(id: string)
        -- Dedupe: the three burst roles share one 5-clip pool, and warming the same
        -- asset three times just pushes everything behind it further down the queue.
        if seen[id] then
            return
        end
        seen[id] = true
        local s = Instance.new("Sound")
        s.SoundId = id
        table.insert(warm, s)
    end
    -- Textures first — they are tiny next to audio, and an unloaded texture is an
    -- INVISIBLE burst (lesson 2 in the header). Then the launch thumps and the salute
    -- voices, the clips a show opens with and the kicker cannot be late for; hash
    -- iteration used to leave their queue position to luck (owner, 2026-09-06 twice:
    -- launches lagged until settle, and a session's first salvo piled its three booms
    -- into one late burst).
    for _, id in BurstStyles.TEXTURES do
        table.insert(warm, id)
    end
    for _, id in BurstStyles.SOUNDS.launch do
        add(id)
    end
    add(BurstStyles.SOUNDS.launch_medium)
    add(BurstStyles.SOUNDS.launch_heavy)
    add(BurstStyles.SOUNDS.salute)
    add(BurstStyles.SOUNDS.salute_single)
    for _, v in BurstStyles.SOUNDS do
        if typeof(v) == "table" then
            for _, id in v do
                add(id)
            end
        else
            add(v)
        end
    end
    pcall(function()
        ContentProvider:PreloadAsync(warm)
    end)
    for _, w in warm do
        if typeof(w) == "Instance" then
            w:Destroy()
        end
    end
end)

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

-- `pointOffset` rotates which pooled point/emitter each frame claims (wrapping over
-- 1..MAX_POINTS-1; index MAX_POINTS is the kicker/flash reserve). Overlapping burst
-- phases used to ALL start at point 1, and emitter properties are live-evaluated -- so
-- a staggered phase REWROTE the airborne particles of the one before it, texture
-- included (owner, 2026-09-06: dan's three glyph clusters all turned into "the same
-- paper glyph" and faded early). Returns the frame count so the caller advances.
local function fireBurst(
    slot: Slot,
    ev: any,
    anchorPos: Vector3,
    rng: Random,
    lifeScale: number,
    pointOffset: number
): number
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
    -- Per-point texture pins SHUFFLE per shell (owner, 2026-09-06: the glyph-to-arm
    -- assignment was frozen -- "rock top right, paper top left, scissors below" every
    -- time). Seeded Fisher-Yates on a copy: same deal on every client, different deal
    -- per shell.
    local pointTextures = ev.textures
    if pointTextures then
        pointTextures = table.clone(pointTextures)
        for i = #pointTextures, 2, -1 do
            local j = rng:NextInteger(1, i)
            pointTextures[i], pointTextures[j] = pointTextures[j], pointTextures[i]
        end
    end
    -- COLOR OVER LIFE (owner, 2026-09-03): the star IGNITES near-white, settles to the
    -- shell's saturated color for the body of the burn, and embers into the edge color at
    -- death. The heat lives HERE, not in Brightness — brightness past ~8 saturated every
    -- overlap to white and the color drowned.
    local core = colorOf(ev.color)
    local edge = colorOf(ev.edgeColor or ev.color)
    local flash = core:Lerp(Color3.new(1, 1, 1), 0.75)
    -- A dying star cools like a blackbody: dim orange-brown, whatever color it burned.
    -- Using the raw edgeColor here read as "blue grey white" on pale-edged shells
    -- (owner, 2026-09-03); the ember keeps only a hint of the shell's own tint.
    local ember = Color3.fromRGB(150, 70, 25):Lerp(edge, 0.2)
    -- With additive blending, BLACK IS OFF: driving the color to near-black at death is
    -- what ramps the glow to zero as the star fades (owner, 2026-09-03: end-of-life reads
    -- soft). Transparency alone dims the sprite but leaves its bloom halo mushy.
    local dark = ember:Lerp(Color3.new(0, 0, 0), 0.85)
    local color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, flash),
        ColorSequenceKeypoint.new(0.12, core),
        ColorSequenceKeypoint.new(0.7, core),
        ColorSequenceKeypoint.new(0.9, ember),
        ColorSequenceKeypoint.new(1, dark),
    })
    -- The star SHRINKS as it burns out -- a dying spark tightens to a point, it does not
    -- linger at full size behind a transparency curtain.
    -- ⚠ THE FLOOR: sprite size rides spread (below), which silently made SMALL bursts
    -- grow SMALL STARS -- dan's spread-22 mini-peonies wore 0.28-stud stars against a
    -- standard peony's 0.53 and read as haze (owner, 2026-09-06: "the stars themselves
    -- are smaller somehow?"). A small burst keeps readable stars.
    local s0 = math.max((ev.spread or 30) / 80 * style.sizeScale, 0.5)
    local size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, s0),
        NumberSequenceKeypoint.new(0.7, s0),
        NumberSequenceKeypoint.new(1, s0 * 0.3),
    })
    -- Velocity-parallel aligns each sprite to its own path, so a streak's bright head
    -- LEADS and its tail trails behind — camera billboards wore the streak upside down
    -- on falling stars (owner, 2026-09-03).
    local orientation = if style.orientation == "velocity"
        then Enum.ParticleOrientation.VelocityParallel
        else Enum.ParticleOrientation.FacingCamera
    -- VelocityParallel runs the sprite's HORIZONTAL axis along the motion; the streak is
    -- authored vertical, so unrotated it lay perpendicular to its own path (owner,
    -- 2026-09-03). 90° turns it into the direction of travel; dots are symmetric, 0.
    local rotation = if style.orientation == "velocity" then NumberRange.new(-90) else NumberRange.new(0)
    local acceleration = if ev.droop == true
        then Vector3.new(0, -28, 0)
        else Vector3.new(style.acceleration[1], style.acceleration[2], style.acceleration[3])
    -- `spread` scales the BURST RADIUS (emission speed), with 30 as the neutral value --
    -- before 2026-09-04 it only scaled sprite size, and a "spread ladder" (kiku 28/38/50)
    -- was three near-identical bursts (owner: "can't tell much of a difference").
    local radiusScale = (ev.spread or 30) / 30
    local speed = NumberRange.new(style.speed[1] * radiusScale, style.speed[2] * radiusScale)
    -- lifeScale > 1 only via boost.lifeScale: a lucky shell's stars simply live longer.
    local lifetime = NumberRange.new(style.lifetime[1] * lifeScale, style.lifetime[2] * lifeScale)
    local spreadAngle = Vector2.new(style.spreadAngle[1], style.spreadAngle[2])
    local transparency = transparencyOf(style)

    for i, f in frames do
        local idx = ((pointOffset + i - 2) % (MAX_POINTS - 1)) + 1
        local p, em = slot.points[idx], slot.emitters[idx]
        -- Frame `rot` is an XYZ Euler triple authored against RotX*RotY*RotZ composition;
        -- CFrame.Angles applies in exactly that order (it IS fromEulerAnglesXYZ).
        p.CFrame = CFrame.new(anchorPos + Vector3.new(f.pos[1], f.pos[2], f.pos[3]))
            * CFrame.Angles(math.rad(f.rot[1]), math.rad(f.rot[2]), math.rad(f.rot[3]))
        -- Per-POINT texture pins (owner, 2026-09-06: dan's triple bloom, one throw
        -- glyph per arm) override the phase texture, which overrides the style role.
        em.Texture = (pointTextures and pointTextures[i]) or texture
        em.Color = color
        em.Size = size
        em.Speed = speed
        em.Drag = style.drag
        em.Lifetime = lifetime
        em.Brightness = style.brightness * (ev.glow or 1)
        em.SpreadAngle = spreadAngle
        em.Acceleration = acceleration
        em.Transparency = transparency
        em.Orientation = orientation
        em.Rotation = rotation
        em.LightEmission = style.lightEmission
        em:Emit(particles)
    end
    return #frames
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

    -- A heavy shell (the L class) emits at WEIGHT_HEAVY x the budget and is CHARGED
    -- WEIGHT_HEAVY admission slots below -- the weighted sky total never exceeds what
    -- the mobile floor was measured against; a volley of heavies staggers sooner.
    local weight = if recipe.heavy then FireworkDirector.WEIGHT_HEAVY else 1
    local lod = FireworkDirector.lodFor(distance, weight)
    local schedule = FireworkSchedule.compile(recipe, lod.particles)

    -- THE SEED IS WHY EVERY CLIENT SEES THE SAME SHOW. Without it each machine rolls its own
    -- apex and its own scatter, and two people watching one firework cannot talk about what they
    -- saw. The server sends one per launch.
    local rng = Random.new(payload.seed)
    -- One voice-speed per shell, drawn FIRST so its position in the stream is stable.
    local soundSpeed = 0.92 + rng:NextNumber() * 0.16
    -- FUSE VARIANCE (owner, 2026-09-06: a six-station volley broke in perfect lockstep —
    -- "they all detonate simultaneously... isn't there variability between shells?").
    -- Every shell's build was already its own — scatter, apex, boost roll, sounds — but
    -- the TIMELINE was recipe-exact, so same-frame launches broke same-frame. A seeded
    -- ±6% stretch on every phase time gives each shell its own fuse, the way real fuses
    -- run fast or slow: a 3s flight lands anywhere in ~2.82-3.18s, multi-act spacing
    -- scales with it, and the at=0 launch stays on the command. Drawn here (before
    -- last/tail derive) so release margins ride the stretched clock too.
    local fuseScale = 0.94 + rng:NextNumber() * 0.12
    for _, ev in schedule do
        ev.at *= fuseScale
    end
    local origin = payload.origin
    -- THE HEADING (rail-mounts, 2026-09-04): a muzzle launch from a player's own deck sends a
    -- unit vector the flight rides along; every other launch site (public sites, proving range,
    -- hand firecrackers) sends no heading, and the vertical default reproduces today's flight
    -- exactly -- same rng stream, same vectors.
    local dir = if payload.heading
        then Vector3.new(payload.heading.x, payload.heading.y, payload.heading.z).Unit
        else Vector3.new(0, 1, 0)
    -- ⚠ RNG DRAW ORDER IS CROSS-CLIENT DETERMINISM: x, then height, then z -- exactly the order
    -- the old `Vector3.new(rng(-8,8), 60 + rng(-6,6), rng(-8,8))` consumed the stream in. Drawing
    -- into locals in this order and assembling afterward keeps every client's rng in lockstep.
    local scatterX = rng:NextNumber(-8, 8)
    local heightJitter = rng:NextNumber(-6, 6)
    local scatterZ = rng:NextNumber(-8, 8)
    -- NOT A PITCHING MACHINE (owner, 2026-09-05: "a curve is different from a knuckle, and
    -- we're currently just throwing fastballs from a pitching machine on the deck"). Two
    -- seeded personalities per HEADING launch, drawn AFTER the base three so the nil-heading
    -- rng stream stays byte-identical:
    --   WOBBLE -- a +-2.5 degree cone on the exit axis itself, visible right at the muzzle;
    --   the ballistics cascade from the angle (downrange = 2h*tan theta), so one wobble
    --   varies exit angle, curve and reach together, like real shot-to-shot mortar scatter.
    --   BREAK -- a +-12 stud late-arc deviation perpendicular to the flight; zero at the
    --   muzzle (the control point stays on the wobbled axis), emerging as the shell falls
    --   off its line near the peak. Verticals get their break for free from the base scatter;
    --   tilted flights need it at this scale or the deterministic lean swamps it.
    local breakVec = Vector3.zero
    if payload.heading then
        local p1 = dir:Cross(Vector3.new(0, 1, 0))
        p1 = if p1.Magnitude > 1e-4 then p1.Unit else Vector3.new(1, 0, 0)
        local p2 = dir:Cross(p1)
        local wobble = math.rad(2.5)
        local a1 = rng:NextNumber(-wobble, wobble)
        local a2 = rng:NextNumber(-wobble, wobble)
        dir = (dir + p1 * math.tan(a1) + p2 * math.tan(a2)).Unit
        breakVec = p1 * rng:NextNumber(-12, 12) + p2 * rng:NextNumber(-12, 12)
    end
    -- BALLISTIC APEX (2026-09-05): a tilted launch must CURVE -- leave along the tube's axis,
    -- bend over, peak far out with the path flattening. The straight dir-line apex made deck
    -- shells rise in a dead-straight slant. For a parabola whose initial velocity tilts theta
    -- from vertical and peaks at height h, the peak sits 2*h*tan(theta) downrange -- so keep
    -- today's HEIGHT (h = run * dir.Y) and put the horizontal displacement where physics puts
    -- it. dir vertical => horizontal term is exactly zero and this is byte-identical to the
    -- old `origin + dir * run + scatter` (public sites, proving range, firecrackers untouched).
    -- Per-source apex (owner, 2026-09-06: the rooftop and mid pool sit low -- "more
    -- launch velocity to get a bit higher"): the server may send apexHeight with the
    -- launch; absent, the 2026-09-03 default 60 stands.
    local run = (if typeof(payload.apexHeight) == "number" then payload.apexHeight else 60) + heightJitter
    local h = run * dir.Y
    local horiz = Vector3.new(dir.X, 0, dir.Z)
    local horizMag = horiz.Magnitude
    local apexOffset = Vector3.new(0, h, 0)
    if horizMag > 1e-6 and dir.Y > 1e-6 then
        -- tan(theta) = horizontal/vertical of the unit heading; downrange = 2 * h * tan(theta)
        apexOffset += horiz.Unit * (2 * h * (horizMag / dir.Y))
    end
    local apex = origin + apexOffset + Vector3.new(scatterX, 0, scatterZ) + breakVec -- 60: owner, 2026-09-03 ("bursts should ride higher")

    -- `tail` is the longest release-worthy lifetime among this shell's burst styles (kamuro's
    -- 4.2s crown must not have its slot's parts re-positioned under it while it's still hanging).
    local last = 0
    local tail = 0
    for _, ev in schedule do
        last = math.max(last, ev.at)
        if ev.kind == "burst" then
            -- Pessimistic: assume a phase's boost hits, so a lucky long-lived break is
            -- never cut down by slot reuse.
            local boostLife = if ev.boost then (ev.boost.lifeScale or 1) else 1
            tail = math.max(tail, BurstStyles.releaseTail(ev.style) * boostLife)
        end
    end

    -- AUTO-LOOK (owner, 2026-09-03, from the cold walk: new players "will miss the detonation
    -- of their firework because they don't know to look up"). Tell the local camera where THIS
    -- player's own shell will break — fired here, after the fuse stretch and the full seeded
    -- apex derivation, because this is the only place the true burst point exists; any other
    -- consumer would have to replay the rng stream to know it. LaunchLookController sweeps.
    if payload.by == tostring(Players.LocalPlayer.UserId) then
        local firstBurstAt: number? = nil
        for _, ev in schedule do
            if ev.kind == "burst" and (firstBurstAt == nil or ev.at < firstBurstAt) then
                firstBurstAt = ev.at
            end
        end
        EventBus.OwnLaunch:Fire({ apex = apex, burstAt = firstBurstAt or 3 })
    end

    -- THE SHELL-LEVEL BOOST ROLL (owner, 2026-09-05, superseding the per-phase roll): the
    -- surprise is a property of the SHELL -- "you landed the bonus" -- so one seeded roll
    -- against the first boost-carrying phase's chance decides every boosted phase AND whether
    -- boostOnly phases (wa's second ring; later, salute endings) exist at all. Drawn here,
    -- before the schedule loop, only when the recipe carries boost anywhere: recipes without
    -- it consume nothing, and the draw is a pure function of the recipe on every client.
    local shellBoosted = false
    do
        local chance: number? = nil
        for _, ev in schedule do
            if ev.boost then
                chance = ev.boost.chance
                break
            end
        end
        if chance then
            -- The seeded draw ALWAYS happens (stream stability), but the SERVER's pity-ramp
            -- verdict wins when the payload carries one (owner, 2026-09-06; BoostLuck):
            -- per-player miss streaks live server-side, every client renders the same luck,
            -- and a paying player's drought is bounded. The local roll remains the fallback
            -- for launches with no verdict -- the proving range, deliberately: auditions
            -- judge the recipe's floor, not the ramp.
            local rolled = rng:NextNumber() < chance
            shellBoosted = if typeof(payload.boosted) == "boolean" then payload.boosted else rolled
        end
    end

    -- (The random BONUS shell was removed 2026-09-06 at owner request; lifeScale is now
    -- moved only by boost.lifeScale, per phase.)
    local lifeScale = 1

    active += weight
    local burstsPlayed = 0 -- rotates this shell's break audio across the slot's burst voices
    local pointCursor = 0 -- rotates point/emitter claims so overlapping phases never collide
    -- One shuffled deck per colorPool table, per shell (dan's act one draws four hands
    -- from one five-color pool). Keyed by pool identity; recipes are module-level tables,
    -- so identity is stable.
    local colorDecks: { [any]: { list: { { number } }, next: number } } = {}
    for _, ev in schedule do
        -- The at=0 report runs INLINE: task.delay(0) costs a Heartbeat, and that frame plus
        -- playSound's own hop plus the clip's attack was the launch-thump lag a listener at
        -- the tube heard (owner, 2026-09-06). Timed phases keep task.delay.
        local runEvent = function()
            local anchorPos = if ev.anchor == "apex" then apex else origin
            if ev.kind == "report" then
                slot.shell.Position = origin
                -- The tube's voice: an explicit recipe sound wins; otherwise an L-tube shell
                -- speaks with the heavy close-miked grunt and everything else rotates through
                -- the launch pool. The pool draw is seeded, and the branch is decided by
                -- shellId (identical on every client), so clients stay in rng lockstep.
                local launchId = ev.sound
                if not launchId then
                    local tube = MortarPlacement.SHELL_MORTAR[payload.shellId]
                    if tube == "mortar:L" then
                        launchId = BurstStyles.SOUNDS.launch_heavy
                    elseif tube == "mortar:M" then
                        -- The middle rung (owner, 2026-09-06: the rotation "sounds a little
                        -- thin" from an M tube next to the L grunt).
                        launchId = BurstStyles.SOUNDS.launch_medium
                    else
                        local launchPool = BurstStyles.SOUNDS.launch
                        launchId = launchPool[rng:NextInteger(1, #launchPool)]
                    end
                end
                playLaunch(slot, launchId, lod.sound, origin, soundSpeed)
                -- THE MUZZLE FLASH: the visual partner of the launch thump, anchoring the
                -- launch to the tube the way the ribbon alone could not. A fixed ~14 sparks
                -- (2% of a shell's budget; the mobile floor was measured at 500-700) with the
                -- FULL property set written -- pool emitters are shared, so a partial write
                -- would inherit the previous shell's style.
                local fp = slot.points[1]
                local fem = slot.emitters[1]
                fp.CFrame = CFrame.new(origin)
                fem.Texture = BurstStyles.TEXTURES.dot
                fem.Color = ColorSequence.new(Color3.fromRGB(255, 236, 200), Color3.fromRGB(255, 200, 120))
                fem.Size = NumberSequence.new(0.45)
                fem.Orientation = Enum.ParticleOrientation.FacingCamera
                fem.Rotation = NumberRange.new(0)
                fem.LightEmission = 1 -- the flash IS a light source; few sparks, no stacking risk
                fem.Speed = NumberRange.new(8, 18)
                fem.Drag = 2
                fem.Lifetime = NumberRange.new(0.2, 0.4)
                fem.Brightness = 2
                fem.SpreadAngle = Vector2.new(20, 20)
                fem.Acceleration = Vector3.new(0, -4, 0)
                fem.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.6, 0.2),
                    NumberSequenceKeypoint.new(1, 1),
                })
                fem:Emit(14)
            elseif ev.kind == "ascent" then
                -- ⚠ THE RIBBON RIDES THE HEADING (owner, 2026-09-05: deck trails were "exactly
                -- like the old ones we discarded" while proving/public looked right). The comet's
                -- attachment pair is separated along the shell's LOCAL Y; when that offset lies
                -- along the motion the segments overlap into the tuned thin comet, and when the
                -- motion tilts away from it the same offset unfolds the Trail into the wide
                -- angled band we threw away. Align local Y with the flight direction; a vertical
                -- dir keeps the identity orientation and is byte-identical to the old code.
                if dir.Y > 0.999 then
                    slot.shell.CFrame = CFrame.new(origin)
                else
                    local xAxis = dir:Cross(Vector3.new(0, 1, 0)).Unit
                    local zAxis = xAxis:Cross(dir)
                    slot.shell.CFrame = CFrame.fromMatrix(origin, xAxis, dir, zAxis)
                end
                -- ⚠ CLEAR BEFORE ENABLE. The slot's shell TELEPORTS here from wherever its
                -- previous shell died; a re-enabled Trail can draw ghost geometry from its
                -- stale segment history — streaks hanging at the LAST apex (owner, 2026-09-03:
                -- "trails soared many studs above the launch tubes").
                slot.trail:Clear()
                slot.trail.Color = ColorSequence.new(colorOf(ev.color))
                slot.trail.Enabled = true
                -- The comet spark layer makes the tube ladder VISUAL the way the thumps
                -- made it audible (owner, 2026-09-06): S rides the bare Trail, M sheds a
                -- light spark stream, L the full debris comet. Fill-rate cost is near-nil
                -- either way — the sparks are small and strung out along the flight, the
                -- opposite of a break's clustered hundreds. Explicitly doused for S
                -- because slots are shared. (Drafts have no SHELL_MORTAR row, so an
                -- M-bound draft shows no sparks at the range — same limitation as the
                -- launch voice; pin `heavy` for L auditions.)
                local tube = MortarPlacement.SHELL_MORTAR[payload.shellId]
                local cometRate = if recipe.heavy then 90 elseif tube == "mortar:M" then 45 else 0
                if cometRate > 0 then
                    local c = colorOf(ev.color)
                    slot.comet.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.25), c)
                    slot.comet.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, if recipe.heavy then 0.45 else 0.32),
                        NumberSequenceKeypoint.new(1, if recipe.heavy then 0.12 else 0.09),
                    })
                    slot.comet.Rate = cometRate
                    slot.comet.Enabled = true
                else
                    slot.comet.Enabled = false
                end
                playSound(slot, ev.sound, lod.sound, origin, soundSpeed)
                -- The comet rises to the apex over whatever time the next phase leaves it —
                -- in TWO stages: straight out of the tube for the first ~60% of the height,
                -- then easing into the apex's lateral drift. One straight slanted tween read
                -- as "tilted trajectories" (owner, 2026-09-03); a mortar leaves its tube along
                -- its own heading (vertical, absent one). Two chained tweens cost what one
                -- does; the trail rounds the knee.
                local rise = math.max(0.05, last - ev.at)
                -- ⚠ DRIVEN PER FRAME, NOT TWEENED. TweenService stepped this shell in
                -- 1.8-stud chunks at ~15Hz (measured 2026-09-03), and the trail drew the
                -- chunks -- the owner read it instantly ("feels like screen space"). A
                -- quadratic bezier from the muzzle through a control point along the heading
                -- to the apex, advanced on Heartbeat, is smooth at true framerate and is the
                -- honest ballistic shape: true to the tube at launch, decelerating into the drift.
                -- Parabola-true control: a quadratic bezier reproduces a ballistic arc when the
                -- control sits where the tube-axis line reaches APEX HEIGHT (tangent leaves along
                -- the tube, arrives horizontal at the peak). Vertical dir: (apex.Y-origin.Y)/dir.Y
                -- is the old `run` exactly, so the 0.9-scaled control -- and the whole flight --
                -- is byte-identical for public sites, the proving range, and firecrackers.
                local control = origin + dir * ((apex.Y - origin.Y) / math.max(dir.Y, 0.05) * 0.9)
                local t0 = os.clock()
                local flight: RBXScriptConnection
                flight = RunService.Heartbeat:Connect(function()
                    local k = math.min((os.clock() - t0) / rise, 1)
                    -- ⚠ CUBIC ease-out, and the exponent IS the ballistics (owner asked after
                    -- gravity, 2026-09-03: there is none simulated -- the curve implies it).
                    -- Exponent 3 fronts the deceleration like air drag on a fast muzzle exit
                    -- (~50%% faster launch than quadratic for the same flight) and floats the
                    -- shell into its break, which is how a real mortar shell rises.
                    local e = 1 - (1 - k) * (1 - k) * (1 - k)
                    local a = origin:Lerp(control, e)
                    local b = control:Lerp(apex, e)
                    slot.shell.Position = a:Lerp(b, e)
                    if k >= 1 then
                        flight:Disconnect()
                    end
                end)
            elseif ev.kind == "burst" then
                -- A boostOnly phase exists only on a lucky shell (owner, 2026-09-05): the
                -- structural surprise. Skipped ENTIRELY on the floor roll -- no break, no
                -- sound, no trail state change; the floor shell honestly never had it.
                if ev.boostOnly and not shellBoosted then
                    return
                end
                slot.trail.Enabled = false
                slot.comet.Enabled = false -- the ascent layer ends where the break begins
                -- THE BOOST (owner design, 2026-09-04; roll hoisted to the SHELL 2026-09-05):
                -- a burst phase carrying `boost` upgrades on the shell's one seeded roll —
                -- wider, brighter, MORE POINTS (which divide the budget, never add
                -- particles), longer-lived.
                local bev = ev
                local phaseLife = lifeScale
                if ev.boost then
                    local boosted = shellBoosted
                    if boosted then
                        bev = table.clone(ev)
                        bev.spread = (ev.spread or 30) * (ev.boost.spread or 1)
                        bev.glow = (ev.glow or 1) * (ev.boost.glow or 1)
                        bev.points = math.min(MAX_POINTS, ev.points + (ev.boost.points or 0))
                        phaseLife = lifeScale * (ev.boost.lifeScale or 1)

                        -- ⚠ LUCK MUST BE LEGIBLE (owner, 2026-09-04: "hard to know you've
                        -- landed a bonus by sight"). Two sellers, both at ~75% of the
                        -- boosted break's life, as the stars begin to fade:
                        -- 1. THE KICKER — a tight pop of stars at the anchor (28 sparks,
                        --    the muzzle-flash budget disclosure applies).
                        -- 2. THE DOUBLE-TAP — a second, sharper report on the tail voice,
                        --    skipped when the style owns its tail (hotaru's sizzle).
                        -- boost.kicker = false skips BOTH (owner, 2026-09-05): a shell whose
                        -- surprise is structural (wa's double ring) needs no selling.
                        local style = BurstStyles.styleOf(ev.style)
                        local kickAt = style.lifetime[2] * phaseLife * 0.75
                        local wantKicker = ev.boost.kicker ~= false
                        local salvo = ev.boost.salvo
                        if salvo then
                            -- THE SALVO KICKER (owner, 2026-09-06: kamuro "needs a big boom at
                            -- starburst, always, and the kicker should be a follow-up of a
                            -- half-dozen aerial explosions/salutes" — 3-4 for kamuro's kicker,
                            -- 5-8 reserved for standalone salute shells): N flash-and-bang
                            -- salutes in a tight VARIABLE grouping above the break, each its own
                            -- 3D voice at its own pitch. Replaces the star pop + double-tap.
                            -- ⚠ EVERY DRAW HAPPENS HERE, UNCONDITIONALLY — count, gaps, offsets,
                            -- speeds — never inside a per-client gate, so all clients keep rng
                            -- lockstep whether or not they can hear it.
                            local count = rng:NextInteger(salvo.count[1], salvo.count[2])
                            local gapMin = if salvo.gap then salvo.gap[1] else 0.08
                            local gapMax = if salvo.gap then salvo.gap[2] else 0.25
                            local shotAt = 0
                            local shots = {}
                            for i = 1, count do
                                if i > 1 then
                                    shotAt += rng:NextNumber(gapMin, gapMax)
                                end
                                shots[i] = {
                                    at = shotAt,
                                    -- BELOW the break, not above it (owner, 2026-09-06: the
                                    -- salutes were "detonating near the top of the arc, when
                                    -- they should be falling with and in the middle of the
                                    -- streaks, because that's where your eye is"). By salvo
                                    -- time kamuro's arms have drooped 10-20 studs under the
                                    -- anchor; the flashes land among them.
                                    offset = Vector3.new(
                                        rng:NextNumber(-9, 9),
                                        rng:NextNumber(-16, -7),
                                        rng:NextNumber(-9, 9)
                                    ),
                                    speed = 0.94 + rng:NextNumber() * 0.12,
                                    -- The shuffle: each shot draws its flare art and its
                                    -- rotation from the seeded stream, so every flash is a
                                    -- different star at a different angle — and the same
                                    -- star on every client.
                                    flare = BurstStyles.SALUTE_FLARES[rng:NextInteger(
                                        1,
                                        #BurstStyles.SALUTE_FLARES
                                    )],
                                    rot = rng:NextNumber(0, 360),
                                }
                            end
                            local cam = workspace.CurrentCamera
                            local dist = if cam then (cam.CFrame.Position - anchorPos).Magnitude else 0
                            local travel = dist / BurstStyles.SOUND_LEVELS.speedOfSound
                            -- Half a second EARLIER than the star-pop kicker's mark (owner,
                            -- 2026-09-06: "the kicker salutes trigger too late") — the salvo
                            -- opens while the crown still burns, not as it fades.
                            local salvoAt = math.max(0.1, kickAt - 0.5)
                            for i, shot in shots do
                                task.delay(salvoAt + shot.at, function()
                                    -- THE FLASH: no starburst (owner, 2026-09-06: "a single,
                                    -- bright white flash... as dazzling as possible"). ONE
                                    -- particle at the emitter's 10-stud size cap, pure white,
                                    -- held solid then snapped off — Brightness 8 under full
                                    -- additive drives it through the bloom threshold, so the
                                    -- post pass blooms it well past its own sprite. FULL
                                    -- property write (shared emitters); shots are sequential,
                                    -- so they share the kicker's point.
                                    local kp = slot.points[MAX_POINTS]
                                    local kem = slot.emitters[MAX_POINTS]
                                    kp.CFrame = CFrame.new(anchorPos + shot.offset)
                                    -- PURPOSE-MADE BURST ART (owner, 2026-09-06: "salutes are
                                    -- a first class effect" — crossed streak sprites read as a
                                    -- line whenever the rotations aligned). One flare sprite
                                    -- with the star and its hot core baked into the texture,
                                    -- shuffled and rotated per shot from the seeded stream.
                                    kem.Texture = shot.flare
                                    kem.Color = ColorSequence.new(Color3.new(1, 1, 1))
                                    -- Rise-and-fall, not fade (owner, 2026-09-06): the SIZE is
                                    -- the envelope — snaps up, collapses — and the sprite stays
                                    -- solid until the last instant.
                                    kem.Size = NumberSequence.new({
                                        NumberSequenceKeypoint.new(0, 2),
                                        NumberSequenceKeypoint.new(0.3, 6),
                                        NumberSequenceKeypoint.new(1, 2),
                                    })
                                    kem.Speed = NumberRange.new(0, 0)
                                    kem.Drag = 0
                                    kem.Lifetime = NumberRange.new(0.09, 0.12)
                                    kem.Brightness = 8
                                    kem.SpreadAngle = Vector2.new(0, 0)
                                    kem.Acceleration = Vector3.zero
                                    kem.Transparency = NumberSequence.new({
                                        NumberSequenceKeypoint.new(0, 0),
                                        NumberSequenceKeypoint.new(0.9, 0),
                                        NumberSequenceKeypoint.new(1, 1),
                                    })
                                    kem.Orientation = Enum.ParticleOrientation.FacingCamera
                                    kem.Rotation = NumberRange.new(shot.rot, shot.rot)
                                    kem.LightEmission = 1
                                    kem:Emit(1)
                                end)
                                if lod.sound then
                                    task.delay(salvoAt + shot.at + travel, function()
                                        local voice = slot.salvoVoices[i]
                                        -- A cold-cache voice stays SILENT rather than queueing:
                                        -- a Play() before the clip binds is released whenever
                                        -- the download lands — one late pile of simultaneous
                                        -- booms, worse than a quiet first shell.
                                        if voice and voice.IsLoaded then
                                            voice.Volume = BurstStyles.SOUND_LEVELS.volume * 0.9
                                            voice.PlaybackSpeed = shot.speed
                                            voice:Play()
                                        end
                                    end)
                                end
                            end
                        elseif wantKicker then
                            task.delay(kickAt, function()
                                local kp = slot.points[MAX_POINTS]
                                local kem = slot.emitters[MAX_POINTS]
                                kp.CFrame = CFrame.new(anchorPos)
                                -- kickerStreaks (owner, 2026-09-05: yashi's violet center pop
                                -- is "streaks, not stars"): the streak sprite runs its length
                                -- along the velocity, which needs VelocityParallel PLUS
                                -- Rotation -90 -- the sprite is authored vertical (the kamuro
                                -- orientation saga) -- and real speed to streak along.
                                local streaks = ev.boost.kickerStreaks == true
                                kem.Texture = if streaks
                                    then BurstStyles.TEXTURES.streak
                                    else BurstStyles.TEXTURES.dot
                                -- THE READABLE KICKER (owner, 2026-09-05: "not enough stars to
                                -- carry the color"). Four levers, because glow alone whitens:
                                -- at LightEmission 1 / Brightness 4 the pileup blew out to white
                                -- (the vocabulary's stacking law), and the old white->color fade
                                -- spent most of a 0.25-0.4s life in its white half. Hue from
                                -- birth (color warmed 35% toward white), longer life, blowout
                                -- pulled under full additive, and 28 stars (~4% of a shell's
                                -- 500-700 budget -- the honest disclosure, up from 16/2%).
                                local kc = ev.boost.kickerColor
                                local hue = if kc
                                    then Color3.fromRGB(kc[1], kc[2], kc[3])
                                    else Color3.fromRGB(255, 220, 160)
                                kem.Color = ColorSequence.new(hue:Lerp(Color3.new(1, 1, 1), 0.35), hue)
                                kem.Size = NumberSequence.new(if streaks then 0.8 else 0.5)
                                kem.Speed = if streaks
                                    then NumberRange.new(24, 38)
                                    else NumberRange.new(16, 30)
                                kem.Drag = 3
                                -- streak kickers rain (owner, 2026-09-05): the violet streaks
                                -- get the time to arc out and fall; dot pops stay snappy.
                                kem.Lifetime = if streaks
                                    then NumberRange.new(0.85, 1.2)
                                    else NumberRange.new(0.45, 0.7)
                                kem.Brightness = 2.5
                                kem.SpreadAngle = Vector2.new(360, 360)
                                kem.Acceleration = Vector3.new(0, -4, 0)
                                kem.Transparency = NumberSequence.new({
                                    NumberSequenceKeypoint.new(0, 0),
                                    NumberSequenceKeypoint.new(0.7, 0.1),
                                    NumberSequenceKeypoint.new(1, 1),
                                })
                                kem.Orientation = if streaks
                                    then Enum.ParticleOrientation.VelocityParallel
                                    else Enum.ParticleOrientation.FacingCamera
                                kem.Rotation = if streaks
                                    then NumberRange.new(-90, -90)
                                    else NumberRange.new(0)
                                kem.LightEmission = 0.85
                                kem:Emit(28)
                            end)
                            if not style.tailSound then
                                local soundPool = BurstStyles.SOUNDS[style.soundRole]
                                -- ⚠ drawn OUTSIDE the lod.sound gate: audibility is per-client
                                -- (distance), and a draw skipped by a far client would desync
                                -- every rng draw after it — the burst geometry included.
                                local tapId = if typeof(soundPool) == "table"
                                    then soundPool[rng:NextInteger(1, #soundPool)]
                                    else soundPool
                                if lod.sound then
                                    local cam = workspace.CurrentCamera
                                    local dist = if cam
                                        then (cam.CFrame.Position - anchorPos).Magnitude
                                        else 0
                                    task.delay(
                                        kickAt + dist / BurstStyles.SOUND_LEVELS.speedOfSound,
                                        function()
                                            slot.tail.SoundId = tapId
                                            slot.tail.Volume = BurstStyles.SOUND_LEVELS.volume * 0.45
                                            slot.tail.PlaybackSpeed = soundSpeed * 1.12 -- sharper than the main
                                            slot.tail:Play()
                                        end
                                    )
                                end
                            end
                        end
                    end
                end
                -- THE COLOR DECK (owner, 2026-09-06, dan's act one: small peonies in
                -- "violet, green, blue, orange, red -- chosen randomly per shell"): a
                -- colorPool phase draws its core from the shell's shuffled deck --
                -- shuffled ONCE per pool per shell (seeded: every client deals the same
                -- hand, and the draws are fixed-count for stream stability), consumed in
                -- phase order, wrapping. The edge derives from the core, lightened.
                if ev.colorPool then
                    if bev == ev then
                        bev = table.clone(ev)
                    end
                    local deck = colorDecks[ev.colorPool]
                    if deck == nil then
                        local order = table.clone(ev.colorPool)
                        for i = #order, 2, -1 do
                            local j = rng:NextInteger(1, i)
                            order[i], order[j] = order[j], order[i]
                        end
                        deck = { list = order, next = 1 }
                        colorDecks[ev.colorPool] = deck
                    end
                    local core = deck.list[deck.next]
                    deck.next = (deck.next % #deck.list) + 1
                    bev.color = core
                    bev.edgeColor = {
                        core[1] + (255 - core[1]) * 0.55,
                        core[2] + (255 - core[2]) * 0.55,
                        core[3] + (255 - core[3]) * 0.55,
                    }
                end
                -- A recipe may pin a burst sound; otherwise the style's role resolves to a
                -- VARIANT POOL and the shell's seeded rng picks one — same clip on every
                -- client, different clip per shell, so a show is not one boom on repeat.
                -- ⚠ The draw sits immediately before fireBurst's own draws, so the per-burst
                -- rng order stays a pure function of the payload.
                local soundId = ev.sound
                if not soundId then
                    local soundPool = BurstStyles.SOUNDS[BurstStyles.styleOf(ev.style).soundRole]
                    if typeof(soundPool) == "table" then
                        soundId = soundPool[rng:NextInteger(1, #soundPool)]
                    else
                        soundId = soundPool
                    end
                end
                -- Rotate the burst voice so this break never cuts the previous one's clip.
                burstsPlayed += 1
                local burstVoice = slot.burstVoices[((burstsPlayed - 1) % #slot.burstVoices) + 1]
                playSound(slot, soundId, lod.sound, anchorPos, soundSpeed, burstVoice)
                -- RE-POPS (owner, 2026-09-06: the strobe's flicker waves read as re-bursts
                -- and "burst 2 is almost always silent"): the style's square wave re-ignites
                -- at declared fractions of star life, and each re-burst gets a soft report --
                -- the SAME clip, quieter and a touch sharper, on the rotated voices. No new
                -- rng draws, so the stream stays in lockstep.
                local rePops = BurstStyles.styleOf(ev.style).rePops
                if rePops then
                    local popStyle = BurstStyles.styleOf(ev.style)
                    local meanLife = (popStyle.lifetime[1] + popStyle.lifetime[2]) / 2 * phaseLife
                    for _, frac in rePops do
                        burstsPlayed += 1
                        local popVoice = slot.burstVoices[((burstsPlayed - 1) % #slot.burstVoices) + 1]
                        task.delay(frac * meanLife, function()
                            playSound(slot, soundId, lod.sound, anchorPos, soundSpeed * 1.06, popVoice, 0.45)
                        end)
                    end
                end
                -- The tail voice: a style's second sound, entering its own delay after the
                -- break (plus the same speed-of-sound travel), on the slot's SEPARATE tail
                -- Sound so it can overlap the burst clip's decay.
                local tailSpec = BurstStyles.styleOf(ev.style).tailSound
                if tailSpec and lod.sound then
                    local tailId = BurstStyles.SOUNDS[tailSpec.role]
                    local cam = workspace.CurrentCamera
                    local dist = if cam then (cam.CFrame.Position - anchorPos).Magnitude else 0
                    task.delay(tailSpec.delay + dist / BurstStyles.SOUND_LEVELS.speedOfSound, function()
                        local vol = BurstStyles.SOUND_LEVELS.volume * tailSpec.volume
                        slot.tail.SoundId = tailId
                        slot.tail.Volume = vol
                        slot.tail:Play()
                        -- THE SOUND OBEYS THE PHASE, not the clip: fade out over 0.35s once
                        -- the style's declared duration is up, however long the file runs.
                        local mySound = slot.tail
                        task.delay(tailSpec.duration, function()
                            for step = 1, 7 do
                                task.delay(0.05 * step, function()
                                    if mySound.SoundId == tailId then
                                        mySound.Volume = vol * (1 - step / 7)
                                        if step == 7 then
                                            mySound:Stop()
                                        end
                                    end
                                end)
                            end
                        end)
                    end)
                end
                pointCursor += fireBurst(slot, bev, anchorPos, rng, phaseLife, pointCursor)
            end
        end
        if ev.at > 0 then
            task.delay(ev.at, runEvent)
        else
            runEvent()
        end
    end

    -- Released after the last phase plus the longest burst style's release tail, so the slot is
    -- not reused — and its parts repositioned — while its own sparks are still on screen.
    task.delay(last + tail + 0.2, function()
        active -= weight
        slot.trail.Enabled = false
        slot.comet.Enabled = false -- belt: a boostOnly-skipped burst must not leak the layer
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
