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

-- LOD. Both numbers are GUESSES until measured on the A13, which is the device that governs the
-- floor -- they are named and commented rather than inlined so the Studio gate can move them.
local DRAW_DISTANCE = 90 -- beyond this the bird stops updating and hides
local DETAIL_DISTANCE = 45 -- beyond this it stops animating and simply holds position

-- Five bands, not fifteen grades: fifteen visually distinct birds is neither achievable nor
-- legible across an arena. Index 0 is unranked.
local BAND_COLOR = {
    [0] = Color3.fromRGB(150, 146, 138),
    [1] = Color3.fromRGB(196, 180, 148),
    [2] = Color3.fromRGB(206, 158, 96),
    [3] = Color3.fromRGB(196, 108, 72),
    [4] = Color3.fromRGB(150, 84, 152),
    [5] = Color3.fromRGB(228, 196, 96),
}

local folder = Instance.new("Folder")
folder.Name = "Familiars"
folder.Parent = workspace

type Bird = {
    part: BasePart,
    pos: Vector3,
    perch: Attachment?,
    holdUntil: number,
    wingL: BasePart,
    wingR: BasePart,
    tail: BasePart,
    seed: number,
    state: string,
    since: number,
    band: number,
}

local birds: { [string]: Bird } = {}
local roster: { [string]: any } = {}
local function seedFor(userId: string): number
    local n = tonumber(userId) or 0
    return (n % 997) / 997 * math.pi * 2
end

-- FOUR PARTS, NOT A MESH. A body, two wings and a tail is enough silhouette to read as a bird at
-- arena distance, and it needs no uploaded asset — which matters because a mesh is a gate the
-- owner has to pass before any of this can be looked at. Same trick the chochin uses: a
-- SpecialMesh sphere squashed into an oblong body.
local function piece(name: string, size: Vector3, parent: Instance): BasePart
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end

local function makeBird(userId: string): Bird
    local model = Instance.new("Model")
    model.Name = `Familiar_{userId}`
    model.Parent = folder

    local body = piece("Body", Vector3.new(0.42, 0.38, 0.78), model)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = body

    -- Wings are WEDGES: a flat plate reads as a plank, a wedge reads as a wing even head-on.
    local wingL = piece("WingL", Vector3.new(0.06, 0.30, 0.62), model)
    local wingR = piece("WingR", Vector3.new(0.06, 0.30, 0.62), model)
    local tail = piece("Tail", Vector3.new(0.05, 0.20, 0.34), model)

    for _, p in { body, wingL, wingR, tail } do
        p.Color = BAND_COLOR[0]
    end

    return {
        part = body,
        pos = Vector3.zero,
        perch = nil,
        holdUntil = 0,
        wingL = wingL,
        wingR = wingR,
        tail = tail,
        seed = seedFor(userId),
        state = "RESTING",
        since = os.clock(),
        band = 0,
    }
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
        local c = BAND_COLOR[math.clamp(b.band, 0, 5)]
        b.part.Color, b.wingL.Color, b.wingR.Color, b.tail.Color = c, c, c, c
    end
    -- A bird whose player left must go, or it hangs in the air forever: this controller keys on
    -- the roster, so a stale entry is a stale bird.
    for userId, b in birds do
        if not roster[userId] then
            release(b)
            b.part:Destroy()
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
            b.wingL.Transparency, b.wingR.Transparency, b.tail.Transparency = 1, 1, 1
            continue
        end
        local far = if eye then (root.Position - eye).Magnitude else 0
        if far > DRAW_DISTANCE then
            b.part.Transparency = 1
            b.wingL.Transparency, b.wingR.Transparency, b.tail.Transparency = 1, 1, 1
            continue
        end
        b.part.Transparency = 0
        b.wingL.Transparency, b.wingR.Transparency, b.tail.Transparency = 0, 0, 0

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
                -- Sit ON the anchor, not in it.
                target = b.perch.WorldPosition + Vector3.new(0, 0.2, 0)
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

        local base = CFrame.lookAt(b.pos, b.pos + heading)
        b.part.CFrame = base

        if far <= DETAIL_DISTANCE then
            -- Wings follow what the bird is DOING: hard while climbing, barely moving while sunk,
            -- and STILL once it has settled on a perch. A perched bird with its wings going is the
            -- tell that this is a box with decorations on it.
            local landed = resting and b.perch ~= nil and travelled < 0.05
            local beat = if b.state == "WIN" then 18 elseif b.state == "LOSS" then 7 else 12
            local depth = if b.state == "WIN" then 0.9 elseif b.state == "LOSS" then 0.35 else 0.7
            local flap = if landed then 0 else math.sin(now * beat + b.seed) * depth
            b.wingL.CFrame = base * CFrame.new(-0.26, 0.06, 0) * CFrame.Angles(0, 0, flap)
            b.wingR.CFrame = base * CFrame.new(0.26, 0.06, 0) * CFrame.Angles(0, 0, -flap)
            b.tail.CFrame = base * CFrame.new(0, 0.04, 0.5)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local b = birds[tostring(player.UserId)]
    if b then
        release(b)
        b.part:Destroy()
        birds[tostring(player.UserId)] = nil
    end
end)
