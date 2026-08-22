--!strict
-- ONE SMALL BIRD PER PRESENT PLAYER, and it is the round result made legible.
--
-- WHY A BIRD AT ALL. Round results did not read: a win emitted 30 particles and nothing else (the
-- 1.6x avatar grow it once had was deleted), a safe drew a featureless disc that the owner read as
-- a cloud, and a loss had no visual whatsoever. The familiar was already the approved answer --
-- `docs/superpowers/specs/2026-07-04-roshambo-metagame-design.md` specifies these exact three
-- reactions and calls the familiar "the mobile status display complementing the teahouse's static
-- one".
--
-- THE GRAMMAR IS VERTICAL. Win rises, safe perches, loss darts away. The space above a player's
-- head is the only region never occluded by another avatar, so height is what survives a crowd of
-- fifty on a phone. All of that arithmetic lives in `BirdFlight`, which is pure and Lune-tested;
-- this file only renders it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local BirdFlight = require(shared:WaitForChild("BirdFlight"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local CollectionService = game:GetService("CollectionService")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FamiliarRoster = remotes:WaitForChild("FamiliarRoster") :: RemoteEvent

-- THE BIRD IS A SKINNED MeshPart CLONED FROM A TEMPLATE, and it has to be a clone: `Bone`s are
-- ordinary child instances, so `AssetService:CreateMeshPartAsync` cannot rebuild them from a
-- MeshId -- it returns bare geometry. The template ships as a committed .rbxm via Rojo, the same
-- route as BonshoBell and ShoroRoof ([[rojo-meshpart-rbxm]]).
local birdAssets = ReplicatedStorage:WaitForChild("RoshamboBirds", 20)
local asset = birdAssets and birdAssets:FindFirstChild("UguisuBody")
local wingAsset = birdAssets and birdAssets:FindFirstChild("UguisuWings")
-- ⚠ ACCEPT EITHER A MeshPart OR THE MODEL THE IMPORTER WRAPS IT IN. Studio's 3D Importer emits a
-- Model containing the MeshPart plus an AnimationController and an InitialPoses folder, and which
-- of the two gets saved to the .rbxm depends on what was right-clicked. Requiring one shape makes
-- the asset pipeline depend on a click, so take the MeshPart wherever it is.
local function meshOf(a: Instance?): BasePart?
    if not a then
        return nil
    end
    return (if a:IsA("BasePart") then a else a:FindFirstChildWhichIsA("MeshPart", true)) :: BasePart?
end
local TEMPLATE = meshOf(asset)
-- ⚠ THE WINGS ARE A SEPARATE PART, AND THAT IS THE WHOLE MECHANISM. Owner, 2026-08-22: the wings
-- "should completely disappear when the bird is perched/at rest". Nothing on a bound wing can do
-- that -- `Bone.Transform` DISCARDS SCALE (measured: set 0.06, reads back 1.0), and at the best
-- fold 93 of 208 wing vertices are still outside the body. Transparency on a separate MeshPart is
-- complete and unarguable, and the wings stay SKINNED so they keep the two-bone fold and the flap.
local WING_TEMPLATE = meshOf(wingAsset)
if not TEMPLATE then
    -- ⚠ DO NOT let a missing asset take the client down. Familiars are decoration; the round
    -- still has to be playable without them. A missing WINGS template is survivable on its own —
    -- the bird simply never flies with them — so it is warned about but not fatal.
    warn("[BirdController] no RoshamboBirds.UguisuBody -- familiars disabled")
    return
end
if not WING_TEMPLATE then
    warn("[BirdController] no RoshamboBirds.UguisuWings -- familiars will not spread wings")
end

-- ===== PERCHING (owner's numbers, 2026-08-18) =====
-- A resting familiar belongs in the world, not orbiting a head: "it'll look like a bad cartoon
-- where everyone just got knocked on the head". Perches are tagged attachments emitted by the
-- builders (roofs, decks, teahouse railings) and swept onto place-only geometry (path railings,
-- bridges, hero trees).
local PERCH_RADIUS = 20 -- how far from its OWNER a bird will look for somewhere to sit
-- A perch is held for a random span in this band, then the bird moves. Re-picked RANDOMLY from
-- everything in range, so it sometimes returns to the one it just left — which is what a real
-- bird does and what stops the movement reading as a patrol.
local HOLD_MIN, HOLD_MAX = 10, 60
-- Past this the bird gives up its perch and flies to catch up. Without it, an owner who walks off
-- leaves their familiar behind on the far side of the canyon.
local LEASH = 70
local FLY_SPEED = 34 -- studs/sec toward wherever it is going

-- ===== SONG =====
-- The clips are the DOCK UGUISU'S, already uploaded and moderation-cleared ([[falls-dock]]).
-- Same species, so the same recordings are correct -- but the dock bird carries an owner gate
-- from 2026-07-28 that this must not trample: "Birds are ephemeral... this bird lives here and
-- you have to be close to hear it." A familiar singing freely would make that bird ordinary.
--
-- Three things keep them apart. The familiar sings ONLY on a win, so it is an event and not
-- ambience. Its rolloff is far tighter than the dock's 12-55, so it is intimate rather than a
-- landmark you can hear across the pool. And it is quieter.
local SONG = { 74571915778017, 93957494294947, 133151225815336 }
local SONG_VOLUME = 0.38 -- the dock bird runs 0.6; this must not compete with it
local SONG_ROLLOFF_MIN, SONG_ROLLOFF_MAX = 6, 26
-- ⚠ EVERY WINNER WINS AT THE SAME INSTANT -- more so under TEST_MODE, where the World Throw
-- cycles R->P->S and a whole crowd can throw the same winning hand. Fifty birds opening together
-- is a cacophony, so each waits a random beat and only a few sing at all.
local SONG_STAGGER = 2.2 -- seconds of jitter before a bird decides to sing
-- Every winner's OWN bird sings — it has just landed on their shoulder and the song is the
-- point. Other people's birds sing sometimes, which is what keeps a crowd from becoming a wall
-- of noise. The stagger still applies to both.
local SONG_CHANCE_OWN = 1.0
local SONG_CHANCE_OTHER = 0.3
local MAX_CONCURRENT_SONGS = 6

-- LOD. Both numbers are GUESSES until measured on the A13, which is the device that governs the
-- floor -- they are named and commented rather than inlined so the Studio gate can move them.
local DRAW_DISTANCE = 90 -- beyond this the bird stops updating and hides
local DETAIL_DISTANCE = 45 -- beyond this it stops animating and simply holds position

-- ⚠ GRADE BANDS ARE SET ASIDE (owner, 2026-08-21): "birds simply aren't large enough for it to
-- matter, unless we design our own kind of (presumably larger) bird, like a raven/crow to carry
-- it." The four-part greybox tinted every part by band; a textured MeshPart does not tint that
-- way, and repainting an uguisu purple or gold stops it being an uguisu. The roster still carries
-- `band` and it is still stored on the bird -- nothing consumes it yet, deliberately.

local folder = Instance.new("Folder")
folder.Name = "Familiars"
folder.Parent = workspace

type Bird = {
    part: BasePart,
    pos: Vector3,
    perch: Attachment?,
    holdUntil: number,
    billLower: Bone?,
    wings: BasePart?,
    wingL: Bone?,
    wingR: Bone?,
    wristL: Bone?,
    wristR: Bone?,
    head: Bone?,
    neck: Bone?,
    tail: Bone?,
    seed: number,
    flyingSince: number?, -- when this flight began, or nil while perched: the wings OPEN over
    state: string, -- time and the ease has to start from the launch, not from os.clock()
    since: number,
    band: number,
}

local birds: { [string]: Bird } = {}
local roster: { [string]: any } = {}
local function seedFor(userId: string): number
    local n = tonumber(userId) or 0
    return (n % 997) / 997 * math.pi * 2
end

local function makeBird(userId: string): Bird
    local part = TEMPLATE:Clone() :: BasePart
    part.Name = `Familiar_{userId}`
    -- The importer's AnimationController and InitialPoses folder ride along on a Model-shaped
    -- template. We drive Bone.Transform directly, so they are dead weight on every bird.
    for _, c in part:GetChildren() do
        if not c:IsA("Bone") then
            c:Destroy()
        end
    end
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Massless = true
    -- ⚠ NEVER INHERIT THE TEMPLATE'S ROTATION. Studio's importer leaves an arbitrary rotation on
    -- the MeshPart -- UguisuBody arrived with LookVector (0, 1, 0), nose straight up -- and the
    -- perched branch below PRESERVES whatever rotation a bird already has. A fresh clone would
    -- therefore keep the importer's attitude forever, which is exactly what the owner saw.
    part.CFrame = CFrame.new(part.Position)
    part.Parent = folder

    -- The wings ride as their own part, CFramed onto the body every frame. Both halves were
    -- exported around the SAME origin, so matching pivots is all the mating they need.
    local wings: BasePart? = nil
    if WING_TEMPLATE then
        local w = WING_TEMPLATE:Clone() :: BasePart
        w.Name = `FamiliarWings_{userId}`
        for _, c in w:GetChildren() do
            if not c:IsA("Bone") then
                c:Destroy()
            end
        end
        w.Anchored = true
        w.CanCollide = false
        w.CanQuery = false
        w.CanTouch = false
        w.CastShadow = false
        w.Massless = true
        w.Transparency = 1 -- a bird is born perched
        w.Parent = folder
        wings = w
    end

    local function bone(name: string): Bone?
        local host: Instance? = if string.find(name, "wing") or string.find(name, "wrist")
            then wings
            else part
        return host and host:FindFirstChild(name, true) :: Bone?
    end

    return {
        part = part,
        wings = wings,
        pos = Vector3.zero,
        perch = nil,
        holdUntil = 0,
        billLower = bone("bill_lower"),
        wingL = bone("wing_L"),
        wingR = bone("wing_R"),
        wristL = bone("wrist_L"),
        wristR = bone("wrist_R"),
        -- joint4 carries the head, joint3 the neck below it, joint8 the tail base. Splitting a
        -- head turn across TWO bones is what keeps the neck from shearing: the neck takes the
        -- lead and the head follows, which is also the order a real bird moves in.
        head = bone("joint4"),
        neck = bone("joint3"),
        tail = bone("joint8"),
        seed = seedFor(userId),
        flyingSince = nil,
        state = "RESTING",
        since = os.clock(),
        band = 0,
    }
end

local singing = 0

local function sing(b: Bird, isOwn: boolean)
    local chance = if isOwn then SONG_CHANCE_OWN else SONG_CHANCE_OTHER
    -- The owner's own bird is never crowded out: it bypasses the concurrency ceiling.
    if not isOwn and (singing >= MAX_CONCURRENT_SONGS or math.random() > chance) then
        return
    end
    singing += 1
    local s = Instance.new("Sound")
    s.SoundId = `rbxassetid://{SONG[math.random(#SONG)]}`
    s.Volume = SONG_VOLUME
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance = SONG_ROLLOFF_MIN
    s.RollOffMaxDistance = SONG_ROLLOFF_MAX
    s.PlaybackSpeed = 0.97 + math.random() * 0.06 -- the dock scheduler's jitter, same reason
    s.Parent = b.part
    s.Ended:Once(function()
        singing -= 1
        s:Destroy()
    end)
    -- A clip that never fires Ended (failed load, moderation) would leak a slot forever.
    task.delay(8, function()
        if s.Parent then
            singing -= 1
            s:Destroy()
        end
    end)
    s:Play()
end

local function characterRoot(userId: string): BasePart?
    for _, pl in Players:GetPlayers() do
        if tostring(pl.UserId) == userId then
            local c = pl.Character
            return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
        end
    end
    return nil
end

-- Which perches are spoken for on THIS client. Deliberately client-local: two players' birds may
-- double up across machines, and nobody can see both screens. Paying for agreement would mean a
-- server round-trip for a decoration.
local taken: { [Attachment]: boolean } = {}

local function perchIsGone(a: Attachment): boolean
    -- ⚠ StreamingEnabled IS ON. A distant railing can be streamed out mid-flight, so a perch must
    -- be re-checked rather than trusted — a cached CFrame lands the bird on remembered air.
    return a.Parent == nil or not a:IsDescendantOf(workspace)
end

local function pickPerch(ownerPos: Vector3): Attachment?
    local near: { Attachment } = {}
    for _, a in CollectionService:GetTagged("FamiliarPerch") do
        if a:IsA("Attachment") and not perchIsGone(a) and not taken[a] then
            if (a.WorldPosition - ownerPos).Magnitude <= PERCH_RADIUS then
                table.insert(near, a)
            end
        end
    end
    if #near == 0 then
        return nil
    end
    return near[math.random(#near)]
end

local function release(b: Bird)
    if b.perch then
        taken[b.perch] = nil
        b.perch = nil
    end
end

FamiliarRoster.OnClientEvent:Connect(function(next_: { [string]: any })
    roster = next_ or {}
    for userId, entry in roster do
        local b = birds[userId]
        if not b then
            b = makeBird(userId)
            birds[userId] = b
        end
        b.band = tonumber(entry.band) or 0
    end
    -- A bird whose player left must go, or it hangs in the air forever: this controller keys on
    -- the roster, so a stale entry is a stale bird.
    for userId, b in birds do
        if not roster[userId] then
            release(b)
            b.part:Destroy()
            if b.wings then
                b.wings:Destroy()
            end
            birds[userId] = nil
        end
    end
end)

-- ===== THE DRUM GATE IS UPSTREAM, AND THAT IS THE WHOLE POINT =====
-- `RevealTheater` lands about 3.45s BEFORE the throw drum finishes turning, and reacting on its
-- arrival would announce the round while the wheel is still spinning. That is worse here than
-- anywhere else in the codebase: petals spoil a round only for their own owner, but a bird is
-- visible across the arena, so an early celebration hands the answer to everyone watching that
-- player.
--
-- ⚠ BUT THE GATE IS NOT OURS TO APPLY. `TheaterController` holds the entire cue schedule and
-- builds it AT FLUSH TIME, on `drumRest` — so by the time a `consequence` cue reaches this bus it
-- is ALREADY past the drum. The first version of this file stashed consequences and waited for a
-- `drumRest` that had therefore already fired, and the bird never reacted at all. Consuming the
-- cue directly is both correct and gated; re-gating it is what broke it.
--
-- ⚠ EVERY BIRD RESETS TO RESTING AT THE START OF EACH REVEAL, and this is what makes "no entry" a
-- real state rather than a forgotten one. A held result with nothing to end it left a player who
-- won an hour ago with a bird still circling triumphantly (owner, 2026-08-18). `heroTileLand` is
-- the reveal's own opening cue and arrives at atMs 0, ahead of every staggered consequence, so
-- clearing on it is clearing exactly one reveal's worth of state at exactly the right moment.
--
-- SAFE therefore needs no case at all: it simply never moves a bird off RESTING. Nothing changed,
-- so the bird does not change.
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "heroTileLand" then
        for _, b in birds do
            b.state = "RESTING"
            b.since = os.clock()
        end
        return
    end
    if cue.kind ~= "consequence" or not cue.userId then
        return
    end
    -- `cue.result`, never `cue.effect`: LOSS's pool is empty, so an effect-derived reading cannot
    -- tell a loss from an unknown effect.
    if cue.result ~= "WIN" and cue.result ~= "LOSS" then
        return
    end
    local b = birds[cue.userId]
    if b then
        b.state = cue.result
        b.since = os.clock()
        if cue.result == "WIN" then
            local at = b.since
            task.delay(math.random() * SONG_STAGGER, function()
                -- Only if the win is still the bird's current state: a reveal reset, or the
                -- player leaving, must not produce a song from nowhere.
                if birds[cue.userId] == b and b.state == "WIN" and b.since == at then
                    sing(b, cue.userId == tostring(Players.LocalPlayer.UserId))
                end
            end)
        end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    local eye = camera and camera.CFrame.Position
    local now = os.clock()
    for userId, b in birds do
        local root = characterRoot(userId)
        if not root then
            b.part.Transparency = 1
            if b.wings then
                b.wings.Transparency = 1
            end
            continue
        end
        local far = if eye then (root.Position - eye).Magnitude else 0
        if far > DRAW_DISTANCE then
            b.part.Transparency = 1
            if b.wings then
                b.wings.Transparency = 1
            end
            continue
        end
        b.part.Transparency = 0

        -- A result LAPSES after BirdFlight.RESULT_HOLD and the bird goes back to the world; a
        -- reveal also resets it regardless. Holding until the next round read as hovering.
        local elapsed = now - b.since
        local resting = BirdFlight.stateAfter(b.state, elapsed) == "RESTING"

        -- ===== WHERE IS IT TRYING TO BE =====
        local target: Vector3
        if not resting then
            -- A result takes the bird off its perch entirely: it is doing something, not sitting.
            release(b)
            local o = BirdFlight.offsetFor(b.state, elapsed, b.seed)
            target = (root.CFrame * CFrame.new(o.x, o.y, o.z)).Position
        else
            if b.perch and perchIsGone(b.perch) then
                release(b)
            end
            -- Give up a perch when it has been held long enough, or when the owner has walked far
            -- enough that staying would strand the bird.
            if
                b.perch and (now > b.holdUntil or (root.Position - b.perch.WorldPosition).Magnitude > LEASH)
            then
                release(b)
            end
            if not b.perch then
                local found = pickPerch(root.Position)
                if found then
                    b.perch = found
                    taken[found] = true
                    b.holdUntil = now + HOLD_MIN + math.random() * (HOLD_MAX - HOLD_MIN)
                end
            end
            if b.perch then
                -- Sit ON the anchor. The mesh carries its ORIGIN AT THE FEET, so the perch
                -- position is the bird's position -- the old +0.2 fudge the four-part bird
                -- needed (its origin sat at the body centre) is gone.
                target = b.perch.WorldPosition
            else
                -- ⚠ NOWHERE TO SIT: fall back to the orbit rather than freezing. This is also
                -- what keeps a bird OUT of buildings (owner: birds do not go inside) — indoors
                -- there are no perches, so a bird that already has one simply keeps it and waits
                -- outside; only a bird with none at all follows its owner in.
                local o = BirdFlight.offsetFor("RESTING", elapsed, b.seed)
                target = (root.CFrame * CFrame.new(o.x, o.y, o.z)).Position
            end
        end

        -- ===== FLY THERE =====
        -- One speed-capped lerp does the whole job: leaving a perch, crossing to another, and
        -- settling all read as flight without a scripted path.
        if b.pos.Magnitude == 0 then
            b.pos = target
        end
        local step = math.min(1, (FLY_SPEED * dt) / math.max(0.01, (target - b.pos).Magnitude))
        local nextPos = b.pos:Lerp(target, step)
        local travelled = (nextPos - b.pos).Magnitude
        local heading = if travelled > 0.001 then (nextPos - b.pos).Unit else Vector3.zAxis
        b.pos = nextPos

        -- FACING. A bird crossing the arena faces where it is going; a PERCHED one has a travel
        -- vector of nearly zero, so it would snap to a default axis and read as broken. On the
        -- shoulder it looks where its host looks, turned slightly outward so it is in profile
        -- rather than nose-on -- a bird is only identifiable from the side.
        local base: CFrame
        if b.state == "WIN" and not resting then
            base = CFrame.new(b.pos)
                * (root.CFrame - root.CFrame.Position)
                * CFrame.Angles(0, math.rad(-28), 0)
        elseif travelled > 0.001 then
            base = CFrame.lookAt(b.pos, b.pos + heading)
        else
            -- ⚠ A PERCHED BIRD STANDS LEVEL. This used to preserve the bird's existing
            -- rotation, so a bird arriving in a steep dive stayed nose-down on its perch, and a
            -- freshly cloned one kept whatever attitude the importer baked in. Keep the YAW --
            -- it should still face where it last flew -- and drop the pitch and roll.
            local f = b.part.CFrame.LookVector
            local flat = Vector3.new(f.X, 0, f.Z)
            base = if flat.Magnitude > 1e-4
                then CFrame.lookAt(b.pos, b.pos + flat.Unit)
                else CFrame.new(b.pos)
        end
        -- ⚠ SEAT BY THE SHARED ORIGIN, NOT THE PART CENTRE. Setting `CFrame = base` puts the
        -- part's BOUNDING-BOX CENTRE at the perch, and the body's centre rides 0.236 studs above
        -- its feet -- half the bird's height -- so the bird sank into whatever it landed on.
        --
        -- `PivotOffset.POSITION` is the offset from the part centre to the origin both halves
        -- were exported around, which is the feet. Verified: feet land within 0.021 of the target
        -- and the two halves agree to 0.00000 studs at a shared bone.
        --
        -- ⚠ ITS *ROTATION* MUST BE IGNORED. PivotOffset also carries the FBX axis conversion
        -- (90, 0, -180), so `PivotTo` reintroduces exactly the nose-up attitude that was fixed a
        -- moment ago. Take the position, take the rotation from `base`.
        b.part.CFrame = base * CFrame.new(-b.part.PivotOffset.Position)
        if b.wings then
            b.wings.CFrame = base * CFrame.new(-b.wings.PivotOffset.Position)
        end

        if far <= DETAIL_DISTANCE then
            -- FLYING IS A FACT ABOUT MOVEMENT, NOT ABOUT STATE. A bird hopping on a shoulder is
            -- not resting, but it is not flying either, and beating its wings there reads as a
            -- bird about to take off.
            local flying = travelled > 0.05
            if flying then
                if not b.flyingSince then
                    b.flyingSince = now
                end
            else
                b.flyingSince = nil
            end

            -- ⚠ TRANSPARENCY IS THE HIDING MECHANISM, and it is the only one that works. Bone
            -- scale is discarded by Roblox and folding leaves 93 of 208 verts outside the body,
            -- so a perched bird's wings are hidden rather than tucked (owner, 2026-08-22).
            local since = if b.flyingSince then now - b.flyingSince else 0
            local open = BirdFlight.wingExtension(since, b.seed, flying)
            if b.wings then
                b.wings.Transparency = if open <= 0 then 1 else 0
            end

            local shoulder, wrist = BirdFlight.foldAngles(open)
            local lift = math.rad(BirdFlight.wingAngle(now, b.seed, flying))
            if b.wingR then
                b.wingR.Transform = CFrame.Angles(0, 0, math.rad(shoulder) - lift)
            end
            if b.wingL then
                b.wingL.Transform = CFrame.Angles(0, 0, math.rad(-shoulder) + lift)
            end
            if b.wristR then
                b.wristR.Transform = CFrame.Angles(0, 0, math.rad(wrist))
            end
            if b.wristL then
                b.wristL.Transform = CFrame.Angles(0, 0, math.rad(-wrist))
            end

            -- ===== IDLE =====
            -- ⚠ ONLY WHILE PERCHED. A bird in the air is not looking around; it is going
            -- somewhere, and a head snapping about mid-flight reads as a glitch.
            local idleYaw, idlePitch, idleTail = 0, 0, 0
            if not flying then
                idleYaw, idlePitch, idleTail = BirdFlight.idlePose(now, b.seed)
            end
            if b.neck then
                b.neck.Transform = CFrame.Angles(math.rad(idlePitch * 0.35), math.rad(idleYaw * 0.4), 0)
            end
            if b.head then
                b.head.Transform = CFrame.Angles(math.rad(idlePitch * 0.65), math.rad(idleYaw * 0.6), 0)
            end
            if b.tail then
                b.tail.Transform = CFrame.Angles(math.rad(idleTail), 0, 0)
            end

            if b.billLower then
                local gape = 0
                if b.state == "WIN" and not resting then
                    local pulse = math.sin(now * 9 + b.seed)
                    gape = math.rad(16) * math.max(0, pulse) ^ 2
                end
                b.billLower.Transform = CFrame.Angles(-gape, 0, 0)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local b = birds[tostring(player.UserId)]
    if b then
        release(b)
        b.part:Destroy()
        if b.wings then
            b.wings:Destroy()
        end
        birds[tostring(player.UserId)] = nil
    end
end)
