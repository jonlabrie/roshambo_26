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

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FamiliarRoster = remotes:WaitForChild("FamiliarRoster") :: RemoteEvent

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
        wingL = wingL,
        wingR = wingR,
        tail = tail,
        seed = seedFor(userId),
        state = "IDLE",
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
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind ~= "consequence" or not cue.userId or not cue.result then
        return
    end
    -- `cue.result`, never `cue.effect`: LOSS's pool is empty, so an effect-derived reading cannot
    -- tell a loss from an unknown effect.
    local b = birds[cue.userId]
    if b then
        b.state = cue.result
        b.since = os.clock()
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

        local elapsed = now - b.since
        b.state = BirdFlight.stateAfter(b.state, elapsed)
        -- Past DETAIL_DISTANCE the bird holds a fixed offset instead of flying: at that range the
        -- motion is a few pixels and the per-frame trig is the whole cost.
        local o = if far > DETAIL_DISTANCE
            then BirdFlight.offsetFor("IDLE", 0, b.seed)
            else BirdFlight.offsetFor(b.state, elapsed, b.seed)
        -- FACE THE WAY IT IS GOING. A bird flying sideways is the thing that most stops it
        -- reading as a bird, and the heading falls straight out of the orbit's tangent.
        local ahead = BirdFlight.offsetFor(b.state, elapsed + 0.08, b.seed)
        local here = root.CFrame * CFrame.new(o.x, o.y, o.z)
        local there = root.CFrame * CFrame.new(ahead.x, ahead.y, ahead.z)
        local base = if (there.Position - here.Position).Magnitude > 0.01
            then CFrame.lookAt(here.Position, there.Position)
            else here
        b.part.CFrame = base

        if far <= DETAIL_DISTANCE then
            -- One flap cycle, and it stops when the bird perches — a bird sitting on a shoulder
            -- with its wings going is the tell that this is a box with decorations on it.
            local flap = if b.state == "SAFE" and elapsed > 1.2 then 0 else math.sin(now * 14 + b.seed) * 0.7
            b.wingL.CFrame = base * CFrame.new(-0.26, 0.06, 0) * CFrame.Angles(0, 0, flap)
            b.wingR.CFrame = base * CFrame.new(0.26, 0.06, 0) * CFrame.Angles(0, 0, -flap)
            b.tail.CFrame = base * CFrame.new(0, 0.04, 0.5)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local b = birds[tostring(player.UserId)]
    if b then
        b.part:Destroy()
        birds[tostring(player.UserId)] = nil
    end
end)
