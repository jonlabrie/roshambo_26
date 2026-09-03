--!strict
-- The tour's waypoint: ONE tall client-side beam over the current stop (spec §4 — owner
-- picked the classic beam over diegetic lanterns: unmissable beats beautiful for a demo
-- week). Client-only because each guest is on their own step; old hands (step NONE/DONE)
-- never see it. Degradation (spec §8): a missing tag means no beam but the beat cards still
-- show — warn once per step, never error.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local TourGuide = require(shared:WaitForChild("TourGuide"))
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

-- Factored out of `retarget` (F2) so the Heartbeat poll below can retry the SAME lookup once a
-- streamed-in tag becomes available, without duplicating the tag->part resolution.
local function resolveTagged(step: string): BasePart?
    local tag = TourGuide.beamTag(step)
    if tag == nil then
        return nil
    end
    local tagged = CollectionService:GetTagged(tag)
    for _, inst in tagged do
        if inst:IsA("BasePart") then
            return inst
        end
    end
    return nil
end

local function retarget(step: string)
    -- F6: idempotent. A redundant TourStep fire for the step we're already showing must not
    -- blink the beam or re-arm `arrivalFired` — that would let the arrival beat re-fire, or the
    -- beam flicker, on a resend that changed nothing.
    if step == currentStep and beam ~= nil then
        return
    end
    currentStep = step
    arrivalFired = false
    local tag = TourGuide.beamTag(step)
    if tag == nil then
        clearBeam()
        return
    end
    local part = resolveTagged(step)
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
    -- F2: under StreamingEnabled the next stop's tagged part is usually far away and may be
    -- streamed out when its TourStep fires — `target == nil` then latches forever with only
    -- `retarget`'s one-shot lookup to blame. Re-attempt the same resolution here every poll
    -- while the current step still wants a beam but has none, so a tag that streams in a few
    -- seconds later still gets picked up. `warnedStep` still gates the warn to once per step —
    -- it must not gate the retry itself, or a miss would be permanent again.
    if target == nil and TourGuide.beamTag(currentStep) ~= nil then
        local part = resolveTagged(currentStep)
        if part then
            buildBeam(part)
        end
    end
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
