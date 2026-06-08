--!strict
-- Drives the hexagonal World-Throw drum atop the shōrō (spec §4b). It HOLDS the
-- prior round's throw through ACTIVE+lockout; on TALLY it free-cycles a rapid
-- drumroll (target unknown); on the bell strike (`gongStrike` cue at REVEAL) it
-- snaps onto the actual World Throw via DrumStep.landingStep and locks — that
-- becomes the next round's "prior". Mirrors WheelController's offset-capture +
-- phase/cue handling. Symbol SurfaceGuis are attached here at runtime (the face
-- frame rotates with the drum, so orientation is a runtime concern; the builder
-- only ships the timber slabs). 4b refines visuals.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DrumStep = require(shared:WaitForChild("DrumStep"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("ThrowDrum")
local drum = rig:WaitForChild("Drum") :: BasePart
local hub = drum.CFrame

-- capture each face's offset from the hub so we can re-place it under any hub
-- rotation (the WheelController pattern).
local faces: { [number]: BasePart } = {}
local faceOffsets: { [number]: CFrame } = {}
for k = 0, 5 do
    local face = rig:WaitForChild("Face" .. k) :: BasePart
    faces[k] = face
    faceOffsets[k] = hub:ToObjectSpace(face.CFrame)
end

-- Symbol glyphs (BoardController's GLYPH table). Attach one SurfaceGui per face.
local GLYPH = { [0] = "○", [1] = "─", [2] = "∧" }
local GOLD = Color3.fromRGB(212, 176, 102)
for k = 0, 5 do
    local face = faces[k]
    -- Front (+local Z) and Back (−local Z) of the slab both can face a window
    -- across the drum's half-turn, so label both faces of the slab.
    for _, faceEnum in { Enum.NormalId.Front, Enum.NormalId.Back } do
        local gui = Instance.new("SurfaceGui")
        gui.Face = faceEnum
        gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        gui.CanvasSize = Vector2.new(300, 300)
        gui.Parent = face
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextColor3 = GOLD
        label.TextScaled = false
        label.TextSize = 200
        label.Font = Enum.Font.GothamBlack
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Text = GLYPH[k % 3]
        label.Parent = gui
    end
end

-- Geometry: at hub angle θ=0, face 3 sits at the −Z front window. The hub
-- rotates about its local X by θ; a face's world angle is k*60° + θ, and the
-- window is at 180°. Advancing `currentFace` by +1 needs θ to DECREASE by 60°
-- (θ = 180° − currentFace*60°). θ stays continuous (never reset) so no snap.
local DETENT = math.rad(60)
local STEP_TIME = 0.08

local currentFace = 3 -- face at the −Z window at θ=0 → symbol R
local theta = 0 -- continuous hub angle (radians)
local rolling = false
local latestWorldThrow: string? = nil
local priorThrow: string? = nil

local function applyTheta()
    local spun = hub * CFrame.Angles(theta, 0, 0)
    for k = 0, 5 do
        faces[k].CFrame = spun * faceOffsets[k]
    end
end

-- Tween the hub one +1 detent (currentFace += 1, θ -= 60°). Returns once the
-- tween completes so a stepper can await it (one tween at a time → no fights).
local function stepOnce(duration: number)
    currentFace = (currentFace + 1) % 6
    theta -= DETENT
    local target = hub * CFrame.Angles(theta, 0, 0)
    local tween =
        TweenService:Create(drum, TweenInfo.new(duration, Enum.EasingStyle.Sine), { CFrame = target })
    tween:Play()
    -- Heartbeat-follow the tweened hub so the faces track it each frame (the
    -- faces aren't children of the hub, so they don't inherit its tween).
    local hb = RunService.Heartbeat:Connect(function()
        local spun = drum.CFrame
        for k = 0, 5 do
            faces[k].CFrame = spun * faceOffsets[k]
        end
    end)
    tween.Completed:Wait()
    hb:Disconnect()
    -- settle exactly on the detent (avoid float drift accumulating across steps)
    applyTheta()
end

applyTheta()

RevealTheater.OnClientEvent:Connect(function(reveal)
    latestWorldThrow = reveal.worldThrow
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "TALLY" then
        -- start the rapid free drumroll: it does NOT know the target; it just
        -- cycles +1 detents until the strike lands.
        if rolling then
            return
        end
        rolling = true
        task.spawn(function()
            while rolling do
                stepOnce(STEP_TIME)
            end
        end)
    elseif info.phase == "ACTIVE" then
        -- holding the prior throw; ensure the roll is stopped (it already is
        -- after the strike, but clear the flag defensively).
        rolling = false
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind ~= "gongStrike" then
        return
    end
    rolling = false -- stop the free roll; any in-flight step finishes its tween
    local throw = latestWorldThrow
    if not throw then
        return -- nothing authoritative yet; hold wherever we are
    end
    task.spawn(function()
        -- continue the +1 direction onto the result (1..3 detents), then lock.
        local landFace = DrumStep.landingStep(currentFace, throw)
        local steps = (landFace - currentFace) % 6
        for _ = 1, steps do
            stepOnce(0.12)
        end
        currentFace = landFace
        priorThrow = throw
        local _ = priorThrow -- becomes next round's held symbol (faces stay put)
    end)
end)
