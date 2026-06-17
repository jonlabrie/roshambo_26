--!strict
-- Drives the hexagonal World-Throw drum atop the shōrō (spec §4b). It RESTS through
-- ACTIVE + TALLY showing the prior round's throw; on the bell strike (`gongStrike` cue
-- at REVEAL) the shu-moku's dowel flicks the pin-wheel and the drum is kicked into a
-- fast spin that decelerates to rest on the actual World Throw — that becomes the next
-- round's "prior". Offset-capture pattern (cf. WheelController). Symbol SurfaceGuis are
-- attached here at runtime (the face frame rotates with the drum, so orientation is a
-- runtime concern; the builder only ships the timber slabs). 4b refines visuals.
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

-- MOTION (strike-keyed). The drum RESTS through ACTIVE + TALLY (showing the prior
-- throw). On the bell strike the shu-moku's east-flank dowel flicks the pin-wheel
-- (kick shaft → gears A/B → paddle beam → a drum spoke); the drum is kicked into a
-- fast spin and then DECELERATES to rest on the actual World Throw. Spin is about the
-- hub's local X (= the drum's world-Z axle after the yaw). A face k sits at the −Z
-- window when θ ≡ 180° + k*60° (mod 360°); faces k and k+3 share a glyph so any symbol
-- recurs every 180° (π). θ is never reset, so rest is always a true detent.
local DRUM_KICK = 14 -- rad/s impulse the strike imparts to the drum
local SPINUP_TURNS = 3 -- it spins ~this many turns before settling on the face
local KICK_DUR = 0.5 -- seconds the pin-wheel flick (a half turn) takes

local theta = 0 -- continuous hub angle (radians); decreases as the drum spins
local omega = 0 -- current angular speed (rad/s)
local mode = "hold" -- "hold" | "land"
local landTheta = 0 -- target θ (a detent) once landing
local landDecel = 0 -- constant angular deceleration (rad/s²) during landing
local latestWorldThrow: string? = nil

-- PIN-WHEEL parts that flick on the strike (BellDrive). The kick shaft + gear A turn
-- about the kick-shaft axis (x=1,z=6); gear B + the paddle beam turn the opposite way
-- (1:1) about gear B's axis (x=-1.18,z=7), so the paddle sweeps and flicks the drum
-- spoke. Geometry mirrors ArenaLayout.bellDrive (build-time; keep in sync).
local bell = stage:WaitForChild("BellDrive")
local kickParts: { any } = {}
local function addKick(name: string, px: number, pz: number, sign: number)
    local p = bell:FindFirstChild(name)
    if p and p:IsA("BasePart") then
        table.insert(
            kickParts,
            { part = p, restCF = p.CFrame, restY = p.Position.Y, px = px, pz = pz, sign = sign }
        )
    end
end
addKick("VertShaft", 1, 6, 1)
addKick("DriveGearA", 1, 6, 1)
addKick("DriveGearB", -1.18, 7, -1)
addKick("DrivePaddle", -1.18, 7, -1)
local kickT0 = -1 -- os.clock() when the flick started; <0 = idle
local kickBase = 0 -- accumulated flick angle (the pawl ratchets one half-turn per strike)
local function applyKick(angle: number)
    for _, k in kickParts do
        local piv = CFrame.new(k.px, k.restY, k.pz)
        k.part.CFrame = piv * CFrame.Angles(0, k.sign * angle, 0) * piv:Inverse() * k.restCF
    end
end

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
    if mode == "land" then
        -- kicked at DRUM_KICK, decelerating constantly so ω hits 0 exactly as θ
        -- reaches the detent → spin-up-then-settle on the World Throw, no snap.
        omega -= landDecel * dt
        if omega <= 0 or theta <= landTheta then
            theta = landTheta -- settle exactly on the detent
            omega = 0
            mode = "hold"
            EventBus.Cue:Fire({ kind = "drumRest" }) -- the throw may now be revealed
        else
            theta -= omega * dt
        end
        applyTheta()
    end
    -- pin-wheel flick: a half-turn eased out over KICK_DUR, then held (ratcheted).
    if kickT0 >= 0 then
        local prog = (os.clock() - kickT0) / KICK_DUR
        if prog >= 1 then
            applyKick(kickBase + math.pi)
            kickBase += math.pi
            kickT0 = -1
        else
            applyKick(kickBase + math.pi * (1 - (1 - prog) * (1 - prog))) -- ease-out
        end
    end
    -- "hold": faces stay put (showing the prior throw); no per-frame work needed
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    latestWorldThrow = reveal.worldThrow
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    -- Safety: a fresh ACTIVE means the previous round is well over; if a landing was
    -- somehow left running (e.g. a dropped reveal), settle to hold on the last face.
    if info.phase == "ACTIVE" and mode ~= "hold" then
        omega = 0
        mode = "hold"
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    -- The drum is at rest until the STRIKE. (latchClick is ignored now — no TALLY
    -- drumroll; the drum only moves when the dowel kicks the pin-wheel.)
    if cue.kind == "gongStrike" then
        local throw = latestWorldThrow
        if not throw then
            return -- nothing authoritative yet; stay at rest on the prior face
        end
        -- The kick: impulse the drum to DRUM_KICK, pick the World Throw detent ~SPINUP_TURNS
        -- ahead, and solve the constant decel that lands ω at 0 exactly there.
        omega = DRUM_KICK
        local dmin = SPINUP_TURNS * 2 * math.pi
        landTheta = landTargetFor(throw, dmin)
        local dist = theta - landTheta
        landDecel = (omega * omega) / (2 * dist)
        mode = "land"
        kickT0 = os.clock() -- flick the pin-wheel in lockstep
    end
end)
