--!strict
-- THE SASHIMONO — the back banner a player wears, carrying their crest and their grade.
--
-- A sashimono is the small flag samurai and ashigaru wore in a holder on the back of the armour,
-- so you could tell who was who in a melee. Owner, 2026-08-22: "wasn't there a kind of portable
-- flag Japanese soldiers wore, to identify themselves on the field? Has e.g. a crest on it? Could
-- that carry rank as well?" That is exactly the problem this solves, and the period answer to it.
--
-- ⚠ IT EXISTS BECAUSE THE BIRD CANNOT CARRY STATUS. Grade bands were tried on the familiar and
-- set aside (owner, 2026-08-21): "birds simply aren't large enough for it to matter". A 7-inch
-- bird at arena distance cannot show a rank, and repainting it stops it being an uguisu. A banner
-- standing above head height can, and it does not fight the species.
--
-- ⚠ CLIENT-BUILT FOR EVERY PLAYER, NOT REPLICATED. Same pattern as the familiar: fifty banners
-- built on each client cost nothing to replicate and nothing to the server. Nothing here is
-- authoritative — the crest is derived from the userId and the grade arrives on the roster the
-- familiars already use.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Kamon = require(shared:WaitForChild("Kamon"))
local KamonDraw = require(shared:WaitForChild("KamonDraw"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FamiliarRoster = remotes:WaitForChild("FamiliarRoster") :: RemoteEvent

-- Proportions. A real sashimono is roughly a 1.2m square of cloth on a pole standing about a
-- metre above the shoulder. On a 5-stud avatar that is a banner you can read across a courtyard,
-- which is the entire point of the object.
local POLE_H = 4.2
local POLE_R = 0.06
local CLOTH_W, CLOTH_H = 1.5, 2.1
local CLOTH_T = 0.05
local LEAN = 14 -- degrees back from vertical, the angle it sits in the holder
local PPS = 96

-- ⚠ GRADE IS SHOWN AS BARS, NOT COLOUR. Owner, 2026-08-22: "something like bars (optionally)
-- displayed above/beside a player". Bars read as a COUNT at distance; a hue reads as nothing, and
-- that is what killed the colour scheme on the bird. Five bands, drawn as filled pips down the
-- hoist edge so they are legible in silhouette.
local BANDS = 5

local folder = Instance.new("Folder")
folder.Name = "Sashimono"
folder.Parent = workspace

local worn: { [string]: Model } = {}
local bands: { [string]: number } = {}

local function build(userId: string, character: Model): Model?
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if not (torso and torso:IsA("BasePart")) then
        return nil
    end

    local model = Instance.new("Model")
    model.Name = `Sashimono_{userId}`

    local function piece(name: string, size: Vector3, colour: Color3): BasePart
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.Color = colour
        p.Anchored = false
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Massless = true
        p.Material = Enum.Material.SmoothPlastic
        p.Parent = model
        return p
    end

    local pole = piece("Pole", Vector3.new(POLE_R * 2, POLE_H, POLE_R * 2), Color3.fromRGB(72, 58, 44))
    local cloth = piece("Cloth", Vector3.new(CLOTH_W, CLOTH_H, CLOTH_T), KamonDraw.CLOTH)

    -- The holder sits centred on the back, and the banner leans back out of the player's way.
    local mount = torso.CFrame
        * CFrame.new(0, torso.Size.Y * 0.25, torso.Size.Z * 0.5 + 0.10)
        * CFrame.Angles(math.rad(LEAN), 0, 0)
    pole.CFrame = mount * CFrame.new(0, POLE_H * 0.5 - torso.Size.Y * 0.25, 0)
    -- cloth hangs to ONE side of the pole, as it is lashed in life, not centred on it
    cloth.CFrame = pole.CFrame * CFrame.new(CLOTH_W * 0.5 + POLE_R, POLE_H * 0.5 - CLOTH_H * 0.5 - 0.15, 0)

    for _, p in { pole, cloth } do
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = torso
        weld.Part1 = p
        weld.Parent = p
    end

    local gui = Instance.new("SurfaceGui")
    gui.Name = "Face"
    gui.Face = Enum.NormalId.Back
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = PPS
    gui.AlwaysOnTop = false
    gui.Parent = cloth

    -- crest in the upper field, at the same 1.2 studs the nobori and the lantern glyphs use --
    -- that size was tuned until it read, and it is the benchmark for every crest surface
    local crestHolder = Instance.new("Frame")
    crestHolder.BackgroundTransparency = 1
    crestHolder.Size = UDim2.fromOffset(1.2 * PPS, 1.2 * PPS)
    crestHolder.Position = UDim2.new(0.5, -0.6 * PPS, 0.06, 0)
    crestHolder.Parent = gui
    KamonDraw.draw(crestHolder, Kamon.forUserId(userId), math.floor(1.2 * PPS))

    -- grade pips down the hoist edge
    local rail = Instance.new("Frame")
    rail.Name = "Grade"
    rail.BackgroundTransparency = 1
    rail.Size = UDim2.fromScale(0.16, 0.30)
    rail.Position = UDim2.fromScale(0.04, 0.62)
    rail.Parent = gui
    for i = 1, BANDS do
        local pip = Instance.new("Frame")
        pip.Name = `Pip{i}`
        pip.BorderSizePixel = 0
        pip.BackgroundColor3 = KamonDraw.INK
        pip.BackgroundTransparency = 1 -- lit by setGrade
        pip.Size = UDim2.fromScale(1, 1 / (BANDS * 1.6))
        pip.Position = UDim2.fromScale(0, (i - 1) / BANDS)
        pip.Parent = rail
    end

    model.Parent = folder
    return model
end

local function setGrade(userId: string, band: number)
    local m = worn[userId]
    if not m then
        return
    end
    local cloth = m:FindFirstChild("Cloth")
    local rail = cloth and cloth:FindFirstChild("Face") and cloth.Face:FindFirstChild("Grade")
    if not rail then
        return
    end
    for i = 1, BANDS do
        local pip = rail:FindFirstChild(`Pip{i}`)
        if pip then
            -- pips fill from the BOTTOM, so a grade reads as a rising stack
            pip.BackgroundTransparency = if (BANDS - i + 1) <= band then 0 else 1
        end
    end
end

local function refresh(player: Player)
    local userId = tostring(player.UserId)
    local existing = worn[userId]
    if existing then
        existing:Destroy()
        worn[userId] = nil
    end
    local ch = player.Character
    if not ch then
        return
    end
    local m = build(userId, ch)
    if m then
        worn[userId] = m
        setGrade(userId, bands[userId] or 0)
    end
end

local function watch(player: Player)
    player.CharacterAdded:Connect(function()
        task.wait(0.4) -- let the rig assemble; a weld to a half-built character tears
        refresh(player)
    end)
    if player.Character then
        refresh(player)
    end
end

for _, p in Players:GetPlayers() do
    watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
    local userId = tostring(player.UserId)
    local m = worn[userId]
    if m then
        m:Destroy()
    end
    worn[userId] = nil
    bands[userId] = nil
end)

-- The roster the familiars already use carries `band`, so the sashimono needs no new plumbing.
FamiliarRoster.OnClientEvent:Connect(function(next_: { [string]: any })
    for userId, entry in next_ or {} do
        bands[userId] = tonumber(entry.band) or 0
        setGrade(userId, bands[userId])
    end
end)
