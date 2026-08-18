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
    seed: number,
    state: string,
    since: number,
    band: number,
}

local birds: { [string]: Bird } = {}
local roster: { [string]: any } = {}
-- HELD UNTIL THE DRUM RESTS. See the gate below.
local pending: { [string]: string } = {}

local function seedFor(userId: string): number
    local n = tonumber(userId) or 0
    return (n % 997) / 997 * math.pi * 2
end

local function makeBird(userId: string): Bird
    local p = Instance.new("Part")
    p.Name = `Familiar_{userId}`
    p.Size = Vector3.new(0.55, 0.4, 0.85)
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.SmoothPlastic
    p.Color = BAND_COLOR[0]
    p.Parent = folder
    return { part = p, seed = seedFor(userId), state = "IDLE", since = os.clock(), band = 0 }
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
        b.part.Color = BAND_COLOR[math.clamp(b.band, 0, 5)]
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

-- ===== THE DRUM GATE =====
-- `RevealTheater` lands about 3.45s BEFORE the throw drum finishes turning, so reacting on arrival
-- announces the round while the wheel is still spinning. That is worse here than anywhere else in
-- the codebase: the petals spoil a round only for their own owner, but a bird is visible across
-- the arena, so an early celebration gives the answer to everyone watching that player.
--
-- Same treatment as LanternController, TheaterController, main.client.luau and StatsController:
-- stash on the consequence cue, apply on `drumRest`.
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "consequence" and cue.userId and cue.result then
        -- `cue.result`, never `cue.effect`: LOSS's effect pool is empty, so an effect-derived
        -- reading cannot tell a loss from an unknown effect.
        pending[cue.userId] = cue.result
    elseif cue.kind == "drumRest" then
        for userId, result in pending do
            local b = birds[userId]
            if b then
                b.state = result
                b.since = os.clock()
            end
        end
        table.clear(pending)
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
            continue
        end
        local far = if eye then (root.Position - eye).Magnitude else 0
        if far > DRAW_DISTANCE then
            b.part.Transparency = 1
            continue
        end
        b.part.Transparency = 0

        local elapsed = now - b.since
        b.state = BirdFlight.stateAfter(b.state, elapsed)
        -- Past DETAIL_DISTANCE the bird holds a fixed offset instead of flying: at that range the
        -- motion is a few pixels and the per-frame trig is the whole cost.
        local o = if far > DETAIL_DISTANCE
            then BirdFlight.offsetFor("IDLE", 0, b.seed)
            else BirdFlight.offsetFor(b.state, elapsed, b.seed)
        b.part.CFrame = root.CFrame * CFrame.new(o.x, o.y, o.z)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local b = birds[tostring(player.UserId)]
    if b then
        b.part:Destroy()
        birds[tostring(player.UserId)] = nil
    end
end)
