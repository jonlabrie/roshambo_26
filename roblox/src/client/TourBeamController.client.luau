--!strict
-- The tour's waypoint: ONE tall client-side beam over the current stop (spec §4 — owner
-- picked the classic beam over diegetic lanterns: unmissable beats beautiful for a demo
-- week). Client-only because each guest is on their own step; old hands (step NONE/DONE)
-- never see it. Degradation (spec §8): a missing tag means no beam but the beat cards still
-- show — warn once per step, never error.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TourGuide = require(script.Parent.Parent:WaitForChild("shared"):WaitForChild("TourGuide"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local ARRIVE_STUDS = 30 -- inside this range the beam dims; at the MODEL stop it also fires arrival
local POLL_SECONDS = 0.25
local BEAM_HEIGHT = 220
local BEAM_GIRTH = 4

local beam: BasePart? = nil
local currentStep = "NONE"
local target: BasePart? = nil
local arrivalFired = false
local warnedStep: { [string]: boolean } = {}

local function clearBeam()
    if beam then
        beam:Destroy()
        beam = nil
    end
    target = nil
end

local function buildBeam(at: BasePart)
    clearBeam()
    local p = Instance.new("Part")
    p.Name = "TourBeam"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(255, 214, 120) -- chōchin gold, not alarm red
    p.Transparency = 0.35
    p.Size = Vector3.new(BEAM_GIRTH, BEAM_HEIGHT, BEAM_GIRTH)
    p.CFrame = CFrame.new(at.Position + Vector3.new(0, BEAM_HEIGHT / 2, 0))
    p.Parent = workspace
    beam = p
    target = at
end

local function retarget(step: string)
    currentStep = step
    arrivalFired = false
    local tag = TourGuide.beamTag(step)
    if tag == nil then
        clearBeam()
        return
    end
    local tagged = CollectionService:GetTagged(tag)
    local part: BasePart? = nil
    for _, inst in tagged do
        if inst:IsA("BasePart") then
            part = inst
            break
        end
    end
    if part == nil then
        clearBeam()
        if not warnedStep[step] then
            warnedStep[step] = true
            warn(`[Tour] no part tagged {tag} — beam skipped, cards still carry the words`)
        end
        return
    end
    buildBeam(part)
end

EventBus.TourStep.Event:Connect(retarget)

-- Proximity: dim the beam when the guest is basically there, and at the MODEL stop fire the
-- arrival beat exactly once per step activation. Throttled — this is a walkstate check, not
-- a per-frame effect.
local sincePoll = 0
RunService.Heartbeat:Connect(function(dt: number)
    sincePoll += dt
    if sincePoll < POLL_SECONDS then
        return
    end
    sincePoll = 0
    local at = target
    local b = beam
    if at == nil or b == nil then
        return
    end
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root == nil or not root:IsA("BasePart") then
        return
    end
    local flat = at.Position - root.Position
    local near = Vector3.new(flat.X, 0, flat.Z).Magnitude <= ARRIVE_STUDS
    b.Transparency = if near then 0.85 else 0.35
    if near and currentStep == "MODEL" and not arrivalFired then
        arrivalFired = true
        EventBus.Onboard:Fire("modelArrival", nil)
    end
end)
