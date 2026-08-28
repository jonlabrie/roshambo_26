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
local BirdVoice = require(shared:WaitForChild("BirdVoice"))
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

-- ===== SONG =====
-- The clips are the DOCK UGUISU'S, already uploaded and moderation-cleared ([[falls-dock]]).
-- Same species, so the same recordings are correct -- but the dock bird carries an owner gate
-- from 2026-07-28 that this must not trample: "Birds are ephemeral... this bird lives here and
-- you have to be close to hear it." A familiar singing freely would make that bird ordinary.
--
-- Three things keep them apart. The familiar sings ONLY on a win, so it is an event and not
-- ambience. Its rolloff is far tighter than the dock's 12-55, so it is intimate rather than a
-- landmark you can hear across the pool. And it is quieter.
-- ⚠ THE CLIPS AND LEVELS NOW LIVE PER SPECIES in `shared/BirdVoice.luau`, because a crow is
-- not a loud warbler. The uguisu's volume of 0.85 was raised from 0.38 on the owner's ear
-- (2026-08-22): the old value was set to stay under the falls-dock uguisu's 0.6, but that bird
-- is AMBIENCE across a pool while this one sings on your shoulder — what it must not do is
-- drown the dock bird out AT the dock, and the tight rolloff already handles that. Being too
-- quiet to hear was the worse failure. That reasoning moved with the number.
local SPECIES = "Uguisu" -- ⚠ hardcoded: nothing selects a bird per player yet (F&F item 6)
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
    hipL: Bone?,
    hipR: Bone?,
    root: Bone?,
    seed: number,
    flyingSince: number?,
    -- A perched flutter is EVENT-TRIGGERED (landing, winning) with a slow idle rate underneath
    -- it (owner, 2026-08-25). The controller owns WHEN; BirdFlight owns the shape.
    flutterSince: number?,
    flutterNo: number,
    nextFlutterAt: number,
    wasFlying: boolean,
    lastState: string,
    -- A perch turn. `turnFrom`/`turnTo` are ABSOLUTE yaws in radians, captured once when the turn
    -- starts -- see the note on BirdFlight.turnPose for why an incremental turn would spin.
    turnSince: number?,
    turnFrom: number,
    turnTo: number,
    turnNo: number,
    nextTurnAt: number,
    -- The victory song waits for the bird to actually land; a timer cannot know when that is.
    singArmed: boolean,
    singOwn: boolean,
    singAt: number?,
    flightFrom: Vector3?, -- a flight is a PATH between two points, so both ends must be held
    flightTo: Vector3?,
    flightAt: number,
    flightFor: number,
    flightShape: string,
    flightNo: number, -- when this flight began, or nil while perched: the wings OPEN over
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
        -- The two leg chains: joint12 -> joint13 -> joint14 and joint25 -> joint13.001 -> ...
        -- Rotating the HIP swings the whole leg, which is the lift; the knee would only fold it.
        hipL = bone("joint12"),
        hipR = bone("joint25"),
        root = bone("joint1"),
        seed = seedFor(userId),
        flyingSince = nil,
        flutterSince = nil,
        flutterNo = 0,
        nextFlutterAt = os.clock() + BirdFlight.nextFlutterGap(seedFor(userId), 0),
        wasFlying = false,
        lastState = "RESTING",
        turnSince = nil,
        turnFrom = 0,
        turnTo = 0,
        turnNo = 0,
        nextTurnAt = os.clock() + BirdFlight.nextTurnGap(seedFor(userId), 0),
        singArmed = false,
        singOwn = false,
        singAt = nil,
        flightFrom = nil,
        flightTo = nil,
        flightAt = 0,
        flightFor = 0,
        flightShape = "DIRECT",
        flightNo = 0,
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
    local voice = BirdVoice.VOICE[SPECIES]
    local clip = BirdVoice.pick(SPECIES, math.random)
    -- A species with no voice is SILENT rather than borrowed. Nothing to clean up, and no slot
    -- taken, so the count below must not have been incremented yet.
    if not voice or not clip then
        return
    end
    singing += 1
    local s = Instance.new("Sound")
    s.SoundId = `rbxassetid://{clip}`
    s.Volume = voice.volume
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance = voice.rolloff[1]
    s.RollOffMaxDistance = voice.rolloff[2]
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

-- ⚠ MEASURE THE SHOULDER, DO NOT GUESS IT. BirdFlight's SHOULDER constant put the bird's feet
-- 0.189 studs (2.3 inches) above the arm and inboard of it -- owner, 2026-08-22: "still at least
-- 3 inches above my shoulder". Measured on a live R15: RightUpperArm top sits at y +0.811,
-- x +1.128 from the HumanoidRootPart, and neither number is a constant across avatars -- R6,
-- R15 and scaled bodies all differ. Take it from the character when the part is there.
-- How far inboard of the upper arm's centre the bird stands, as a fraction of arm width.
local SEAT_INBOARD = 0.42
-- ⚠ AND A LITTLE ABOVE THE ARM'S TOP FACE. The bird's origin is at its FEET, so seating it exactly
-- on `arm.Position + Size.Y/2` ought to stand it on the surface — except the part's top face is not
-- the visible shoulder: the R15 arm mesh and anything layered over it (clothing, accessories) sit
-- proud of the bounding box, so the feet sank in (owner, 2026-08-26). Proportional to the arm, so
-- scaled avatars lift by the same amount relative to themselves.
--
-- ⚠ MEASURED, not guessed. R15 RightUpperArm is 1.213 studs tall on this rig, so 0.10 lifted the
-- bird 1.46 INCHES and the owner called it an inch too high (1 stud ~ 1 foot in the owner's units).
-- 0.031 lands it at 0.45 inches -- clear of the mesh, not standing on air.
local SEAT_LIFT = 0.031

local function shoulderSeat(character: Model): Vector3?
    local arm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not (arm and arm:IsA("BasePart") and root) then
        return nil
    end
    local top = arm.Position + Vector3.new(0, arm.Size.Y * 0.5, 0)
    local local_ = root.CFrame:PointToObjectSpace(top)
    -- ⚠ THE MIDDLE OF THE SHOULDER, NOT ITS OUTER EDGE. Owner, 2026-08-25: the bird was sitting
    -- "at the outer edge". `arm.Position` is the arm's CENTRE, and the old 0.18 nudged barely
    -- inboard of that — still out over the arm rather than on the shoulder proper. 0.42 lands it
    -- just short of the arm's inner face, which is where the arm meets the torso and reads as the
    -- middle of the shoulder. Derived from the arm's own width, so R6, R15 and scaled bodies all
    -- get the same PROPORTION rather than a constant that only suits one of them.
    return Vector3.new(local_.X - arm.Size.X * SEAT_INBOARD, local_.Y + arm.Size.Y * SEAT_LIFT, local_.Z)
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
            -- ⚠ ARMED HERE, FIRED ON THE LANDING -- see the update loop. A TIMER CANNOT KNOW WHEN
            -- THE BIRD ARRIVES. The first version waited a random 0..2.2s, the second waited
            -- `ENTRY.WIN` (2.4s) first; both still sang early, because arrival is not a fixed time
            -- at all. The bird FLIES to the shoulder, and `flightDuration` is 0.85s plus distance
            -- over cruise speed -- a bird twenty studs away needs 2.65s, and one across the canyon
            -- needs far more. Any constant is wrong for every distance but one.
            b.singArmed = true
            b.singOwn = cue.userId == tostring(Players.LocalPlayer.UserId)
            b.singAt = nil
        else
            b.singArmed = false
            b.singAt = nil
        end
    end
end)

RunService.RenderStepped:Connect(function()
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
            if b.state == "WIN" then
                -- Keep BirdFlight's HOP (the x shuffle and y bob) but re-base it on the seat
                -- measured off this avatar, rather than on its guessed constant.
                local seat = root.Parent and shoulderSeat(root.Parent :: Model)
                if seat then
                    o = {
                        x = seat.X + (o.x - BirdFlight.SHOULDER_X),
                        y = seat.Y + (o.y - BirdFlight.SHOULDER_Y),
                        z = seat.Z + o.z,
                    }
                end
            end
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
        -- ⚠ A FLIGHT IS A PATH, NOT A LERP. This was `b.pos:Lerp(target, speedCappedStep)`,
        -- which is at full speed on frame one, stops dead on arrival, and travels in a straight
        -- line -- so a hop along a rail finished inside two frames and read as the bird SLIDING.
        -- Now the bird commits to a route when the target moves, and flies it: takeoff, cruise,
        -- landing, over a duration with a floor, along a shaped path (see BirdFlight).
        if b.pos.Magnitude == 0 then
            b.pos = target
            b.flightTo = target
        end

        -- ⚠ PROGRESS IS MEASURED BEFORE THE REPLAN DECISION, because the decision depends on it.
        -- The old code replanned on distance alone, which meant a drifting orbit target reset the
        -- flight clock before the flight could ever finish. See BirdFlight.shouldReplan.
        local committed = b.flightTo
        local arrived = b.flightFor <= 0 or (now - b.flightAt) / b.flightFor >= 1
        local drift = if committed then (target - committed).Magnitude else math.huge
        if not committed or BirdFlight.shouldReplan(arrived, drift) then
            -- new destination: plan a fresh flight from wherever the bird actually is
            b.flightFrom = b.pos
            b.flightTo = target
            b.flightNo += 1
            b.flightAt = now
            b.flightFor = BirdFlight.flightDuration((target - b.pos).Magnitude)
            b.flightShape = BirdFlight.flightShape(b.seed, b.flightNo)
        end

        local from = b.flightFrom or b.pos
        local to = b.flightTo or target
        local leg = to - from
        local dist = leg.Magnitude
        local k = if b.flightFor > 0 then math.min(1, (now - b.flightAt) / b.flightFor) else 1
        local prev = b.pos
        if k >= 1 then
            -- ⚠ ONCE ARRIVED, TRACK THE LIVE TARGET, NOT THE COMMITTED ONE. The flight model
            -- commits to a route and only replans when the destination moves more than 0.35
            -- studs -- which is right for perch-to-perch travel, and WRONG the moment the bird
            -- lands somewhere that moves. The WIN shoulder perch hops (bob 0.13, shuffle 0.09):
            -- all under the threshold, so the bird froze at the spot it first arrived at and the
            -- victory dance never played (owner, 2026-08-22). It also could not follow a player
            -- who walked. Arrival ends the flight; after that the bird simply IS at its target.
            b.pos = target
        elseif dist < 0.02 then
            b.pos = to
        else
            local along, side, rise = BirdFlight.flightPoint(k, dist, b.flightShape)
            local fwd = leg.Unit
            -- lateral axis: horizontal and square to the leg, so a CIRCLE swings around the
            -- perch rather than corkscrewing through the ground
            local lat = fwd:Cross(Vector3.yAxis)
            lat = if lat.Magnitude > 1e-4 then lat.Unit else Vector3.xAxis
            b.pos = from + fwd * (along * dist) + lat * side + Vector3.yAxis * rise
        end
        local travelled = (b.pos - prev).Magnitude
        local heading = if travelled > 0.001 then (b.pos - prev).Unit else Vector3.zAxis

        -- FACING. A bird crossing the arena faces where it is going; a PERCHED one has a travel
        -- vector of nearly zero, so it would snap to a default axis and read as broken. On the
        -- shoulder it looks where its host looks, turned slightly outward so it is in profile
        -- rather than nose-on -- a bird is only identifiable from the side.
        -- ⚠ THE WIN FACING APPLIED DURING THE WHOLE APPROACH, so the bird flew to the shoulder
        -- already turned outboard -- owner: "it look like it was flying sideways as part of it's
        -- pathfinding to the avatar". A bird faces where it is GOING until it lands; the shoulder
        -- pose is an arrival pose, not a travel one.
        -- ===== PERCH TURN =====
        -- ⚠ ABSOLUTE ANGLES, NOT AN OFFSET. The perched branch below derives its heading by
        -- reading the bird's OWN LookVector back each frame. Adding a turn to that every frame
        -- would feed the result back in and compound into a spin, so `turnFrom`/`turnTo` are
        -- captured once, here, and interpolated between.
        --
        -- ⚠ AND THE THREE PERCH MOTIONS MUST NOT OVERLAP. A turn on top of a flutter or the
        -- victory hop reads as one confused compound move rather than two separate habits.
        -- Only on a REAL perch, too: a bird pivoting on someone's shoulder is not a bird.
        local turning = b.turnSince ~= nil and (now - (b.turnSince or 0)) < BirdFlight.TURN_TIME
        if far <= DETAIL_DISTANCE and travelled <= 0.001 and b.perch then
            local flutterRunning = b.flutterSince ~= nil
                and (now - (b.flutterSince or 0)) < BirdFlight.FLUTTER_BURST
            local hopping = b.state == "WIN" and not resting
            if not turning and not flutterRunning and not hopping and now >= b.nextTurnAt then
                local f = b.part.CFrame.LookVector
                b.turnFrom = math.atan2(-f.X, -f.Z)
                b.turnTo = b.turnFrom + math.rad(BirdFlight.turnAmount(b.seed, b.turnNo))
                b.turnSince = now
                b.turnNo += 1
                b.nextTurnAt = now + BirdFlight.nextTurnGap(b.seed, b.turnNo)
                turning = true
            end
        end

        local base: CFrame
        if b.state == "WIN" and not resting and k >= 1 then
            base = CFrame.new(b.pos)
                * (root.CFrame - root.CFrame.Position)
                * CFrame.Angles(0, math.rad(BirdFlight.SHOULDER_YAW), 0)
        elseif travelled > 0.001 then
            base = CFrame.lookAt(b.pos, b.pos + heading)
        else
            -- ⚠ A PERCHED BIRD STANDS LEVEL. This used to preserve the bird's existing
            -- rotation, so a bird arriving in a steep dive stayed nose-down on its perch, and a
            -- freshly cloned one kept whatever attitude the importer baked in. Keep the YAW --
            -- it should still face where it last flew -- and drop the pitch and roll.
            if turning then
                -- Driven from the captured pair, so the self-read above cannot compound it. The
                -- hop returns to zero at the end, which is what puts the bird back on the rail.
                local p, hop = BirdFlight.turnPose(now - (b.turnSince or 0))
                local yaw = b.turnFrom + (b.turnTo - b.turnFrom) * p
                base = CFrame.new(b.pos + Vector3.new(0, hop, 0)) * CFrame.Angles(0, yaw, 0)
            else
                local f = b.part.CFrame.LookVector
                local flat = Vector3.new(f.X, 0, f.Z)
                base = if flat.Magnitude > 1e-4
                    then CFrame.lookAt(b.pos, b.pos + flat.Unit)
                    else CFrame.new(b.pos)
            end
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

            -- ===== FLUTTER TRIGGERS =====
            -- ⚠ A FLUTTER IS AN EVENT, NOT A METRONOME. Owner, 2026-08-25: "event triggered plus
            -- a longer idle period". Landing is the honest trigger -- a bird settles as it
            -- arrives -- and a win fires one too, for the case where the familiar is ALREADY on
            -- the shoulder and so never lands. Starting is GUARDED: on a won round both triggers
            -- fire in the same frame, and restarting a running burst would read as a hitch.
            local running = b.flutterSince ~= nil and (now - (b.flutterSince or 0)) < BirdFlight.FLUTTER_BURST
            local landed = b.wasFlying and not flying
            local justWon = b.state == "WIN" and b.lastState ~= "WIN"
            if not running and not flying and (landed or justWon or now >= b.nextFlutterAt) then
                b.flutterSince = now
                b.flutterNo += 1
                b.nextFlutterAt = now + BirdFlight.nextFlutterGap(b.seed, b.flutterNo)
            end
            b.wasFlying = flying
            b.lastState = b.state

            -- ⚠ TRANSPARENCY IS THE HIDING MECHANISM, and it is the only one that works. Bone
            -- scale is discarded by Roblox and folding leaves 93 of 208 verts outside the body,
            -- so a perched bird's wings are hidden rather than tucked (owner, 2026-08-22).
            --
            -- Openness comes from a DIFFERENT source depending on what the bird is doing: in
            -- flight it is the takeoff ease, perched it is the flutter burst. Both feed the same
            -- fade, so a perched wing appears BY unfolding instead of popping into view.
            local open
            if flying then
                open = BirdFlight.wingExtension(now - (b.flyingSince or now), b.seed, true)
            else
                open = BirdFlight.flutterExtension(now - (b.flutterSince or -99), b.seed)
            end
            if b.wings then
                b.wings.Transparency = BirdFlight.wingTransparency(open)
            end

            local shoulder, wrist = BirdFlight.foldAngles(open)
            -- ⚠ THE BEAT USES BOTH BONE AXES, AND THEY MIRROR DIFFERENTLY -- measured, not
            -- assumed. local X lifts the tip and does NOT mirror: the same sign raises both wings.
            -- local Z sweeps fore-aft and DOES mirror, which is exactly why the fold already runs
            -- `shoulder` on the right and `-shoulder` on the left. Mirroring X too would have one
            -- wing rise while the other fell.
            local beatX, beatZ = BirdFlight.beatPose(now, b.seed, flying)
            local zRight = math.rad(shoulder + beatZ)
            if b.wingR then
                b.wingR.Transform = CFrame.Angles(math.rad(beatX), 0, zRight)
            end
            if b.wingL then
                b.wingL.Transform = CFrame.Angles(math.rad(beatX), 0, -zRight)
            end
            if b.wristR then
                b.wristR.Transform = CFrame.Angles(0, 0, math.rad(wrist))
            end
            if b.wristL then
                b.wristL.Transform = CFrame.Angles(0, 0, math.rad(-wrist))
            end

            -- ===== FEET =====
            -- ⚠ A HOP IS A WEIGHT SHIFT, NOT A SLIDE. The bird used to translate sideways across
            -- the shoulder, which read as sliding; now it stays put and alternates feet, leaning
            -- onto whichever one is still holding the perch (owner, 2026-08-22).
            -- ⚠ GEAR UP. A flying bird with its legs down reads as "a plane flying with the
            -- wheels down" (owner, 2026-08-25). Measured: +100 degrees at the hip folds the whole
            -- leg chain inside the body's bounding box, so no knee bone is needed. Both hips take
            -- the SAME sign, which is the convention the victory hop already uses.
            -- ===== THE VICTORY SONG =====
            -- ⚠ THIS IS THE MOMENT THE DANCE STARTS, which is the only correct cue for the song:
            -- the bird is in a WIN, its flight is over, and it is no longer moving. Everything a
            -- timer was trying to approximate is simply true here.
            if b.singArmed and b.state == "WIN" and not resting and not flying and k >= 1 then
                if not b.singAt then
                    b.singAt = now + math.random() * SONG_STAGGER
                elseif now >= b.singAt then
                    b.singArmed = false
                    b.singAt = nil
                    sing(b, b.singOwn)
                end
            end

            if flying then
                local tuck = math.rad(BirdFlight.legTuck(k) * BirdFlight.LEG_TUCK_DEG)
                if b.hipL then
                    b.hipL.Transform = CFrame.Angles(tuck, 0, 0)
                end
                if b.hipR then
                    b.hipR.Transform = CFrame.Angles(tuck, 0, 0)
                end
                if b.root then
                    b.root.Transform = CFrame.new()
                end
            elseif b.state == "WIN" and not resting then
                local liftL, liftR, roll = BirdFlight.legPose(now, b.seed)
                if b.hipL then
                    b.hipL.Transform = CFrame.Angles(math.rad(liftL * 26), 0, 0)
                end
                if b.hipR then
                    b.hipR.Transform = CFrame.Angles(math.rad(liftR * 26), 0, 0)
                end
                if b.root then
                    b.root.Transform = CFrame.Angles(0, 0, math.rad(roll))
                end
            elseif b.hipL then
                b.hipL.Transform = CFrame.new()
                if b.hipR then
                    b.hipR.Transform = CFrame.new()
                end
                if b.root then
                    b.root.Transform = CFrame.new()
                end
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
