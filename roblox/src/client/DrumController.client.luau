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

-- capture each spinning part's offset from the hub so we can re-place it under
-- any hub rotation (the WheelController pattern). The whole hex prism spins:
-- the 6 rim faces AND the 12 spokes. The shaft is round/symmetric → left static.
local faces: { [number]: BasePart } = {}
local spinParts: { BasePart } = {}
local spinOffsets: { CFrame } = {}
for k = 0, 5 do
    local face = rig:WaitForChild("Face" .. k) :: BasePart
    faces[k] = face
    table.insert(spinParts, face)
    table.insert(spinOffsets, hub:ToObjectSpace(face.CFrame))
end
for _, child in rig:GetChildren() do
    if (child.Name :: string):match("^Spoke%d+$") then
        table.insert(spinParts, child :: BasePart)
        table.insert(spinOffsets, hub:ToObjectSpace((child :: BasePart).CFrame))
    end
end

-- Symbol glyphs (BoardController's GLYPH table). Attach one SurfaceGui per face.
local GLYPH = { [0] = "○", [1] = "─", [2] = "∧" }
local GOLD = Color3.fromRGB(212, 176, 102)
for k = 0, 5 do
    local face = faces[k]
    -- Only the OUTWARD face (local +Z = the radial/visible side) carries the
    -- glyph; the inward side faces the open interior and would be a duplicate.
    -- Canvas matches the face's X:Y aspect so the glyph stays round (a square
    -- canvas on the 2:1 slab squashed the ring into an oval). Small canvas +
    -- fixed TextSize so the glyph reads big (TextSize caps at 100px).
    local fs = face.Size
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front -- the slab is built Front-outward (see faceRot)
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(math.floor(100 * fs.X / fs.Y), 100)
    gui.Parent = face
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = GOLD
    label.TextScaled = false
    label.TextSize = 92
    label.Font = Enum.Font.GothamBlack
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = GLYPH[k % 3]
    label.Parent = gui
end

-- MOTION (continuous, cue-anchored). The drum spins about the hub's local X by a
-- continuous angle θ (decreasing). It does NOT use the round's TALLY phase — that
-- arrives via REST polling and the 2s window is often skipped/late, which is why
-- the old stepper "only span ~0.5s then jarred". Instead it anchors to the two
-- RELIABLE EventBus cues the hammer drives off the clock:
--   • latchClick (lockout)  → start a slow spin that gently decelerates
--   • gongStrike (reveal)   → decelerate to rest on the World Throw (no snap)
-- A face k sits at the −Z window when θ ≡ 180° + k*60° (mod 360°). Because face
-- k and k+3 share a glyph, any one symbol recurs every 180° (π) of θ. θ is never
-- reset, so the rest pose is always a true detent (never an edge).
local SPIN_OMEGA0 = 5.0 -- rad/s at lockout (≈ a relaxed half-turn/sec drumroll)
local SPIN_DAMP = 0.45 -- per-second exponential slow-down while spinning
local SPIN_FLOOR = 2.0 -- keep drifting this fast until the strike lands it
local GLIDE = 1.3 -- nominal seconds the landing glide should take to rest

local theta = 0 -- continuous hub angle (radians); decreases as the drum spins
local omega = 0 -- current angular speed (rad/s)
local mode = "hold" -- "hold" | "spin" | "land"
local landTheta = 0 -- target θ (a detent) once landing
local landDecel = 0 -- constant angular deceleration (rad/s²) during landing
local latestWorldThrow: string? = nil

local function applyTheta()
    local spun = hub * CFrame.Angles(theta, 0, 0)
    for i, p in spinParts do
        p.CFrame = spun * spinOffsets[i]
    end
end

-- The resting θ that shows `throw` at the −Z window, placed at least `dmin`
-- below the current θ so the drum keeps turning the same direction into rest.
-- Detents for a given symbol recur every π (face `sym` and `sym`+3 share it).
local function landTargetFor(throw: string, dmin: number): number
    local sym = DrumStep.faceForThrow(throw) -- 0/1/2; face `sym` shows it
    local tgt = math.rad(180 + sym * 60) -- a detent with `sym` at the −Z window
    while tgt > theta - dmin do
        tgt -= math.pi -- step down by a half-turn (continuing the −θ direction)
    end
    return tgt
end

applyTheta()

RunService.Heartbeat:Connect(function(dt)
    if mode == "spin" then
        omega = math.max(SPIN_FLOOR, omega * (1 - SPIN_DAMP * dt))
        theta -= omega * dt
        applyTheta()
    elseif mode == "land" then
        -- constant deceleration continuing from the live spin speed: no jump,
        -- ω falls to 0 exactly as θ reaches the detent.
        omega -= landDecel * dt
        if omega <= 0 or theta <= landTheta then
            theta = landTheta -- settle exactly on the detent
            omega = 0
            mode = "hold"
        else
            theta -= omega * dt
        end
        applyTheta()
    end
    -- "hold": faces stay put (showing the prior throw); no per-frame work needed
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    latestWorldThrow = reveal.worldThrow
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    -- Safety: a fresh ACTIVE means the previous round is well over; stop any spin
    -- still running (e.g. a dropped reveal) and hold the last face.
    if info.phase == "ACTIVE" and mode == "spin" then
        mode = "hold"
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "latchClick" then
        -- picks closed: the world spins up its decision.
        omega = SPIN_OMEGA0
        mode = "spin"
    elseif cue.kind == "gongStrike" then
        local throw = latestWorldThrow
        if not throw then
            return -- nothing authoritative yet; keep spinning/holding
        end
        -- Pick a detent at least far enough ahead to glide into at the current
        -- speed (ω·GLIDE/2 is the constant-decel stopping distance), but never a
        -- snap-short quarter turn. Then solve the decel that lands ω at 0 there.
        if omega < SPIN_FLOOR then
            omega = SPIN_FLOOR -- ensure a live speed to decelerate from
        end
        local dmin = math.max(omega * GLIDE * 0.5, math.rad(90))
        landTheta = landTargetFor(throw, dmin)
        local dist = theta - landTheta
        landDecel = (omega * omega) / (2 * dist)
        mode = "land" -- decelerate to rest on the throw (no snap)
    end
end)
