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
local DRUM_KICK = 4 -- rad/s the drum spins at during the constant phase (live-tunable via "DrumKick" attr)
local SPIN_SEC = 1.0 -- the drum spins at a steady speed for this long after the strike…
local GLIDE_SEC = 2.0 -- …then eases smoothly to rest on the World Throw over this long
local KICK_DUR = 0.5 -- seconds the pin-wheel flick (a half turn) takes

local theta = 0 -- continuous hub angle (radians); decreases as the drum spins
local omega = 0 -- steady spin speed (rad/s) captured at the strike; reused as the glide's start velocity
local mode = "hold" -- "hold" | "spin" | "glide"
local spinUntil = 0 -- os.clock() at which the steady spin ends and the glide begins
local glideT0 = 0 -- os.clock() when the glide began
local glideP0 = 0 -- θ at the glide's start
local glideD = 0 -- total θ the glide travels (glideP0 → landTheta)
local landTheta = 0 -- target θ (a detent showing the World Throw) the glide ends on
local strikeT0 = -1 -- os.clock() of the current strike; for the stuck-guard on ACTIVE
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
addKick("VertShaft", 1, 6, -1)
addKick("VertPaddle", 1, 6, -1) -- the paddle the kick dowel strikes — turns with the kick shaft
addKick("DriveGearA", 1, 6, -1)
addKick("DriveGearB", -1.18, 7, 1)
addKick("DrivePaddle", -1.18, 7, 1)
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
    if mode == "spin" then
        -- steady spin for SPIN_SEC; then hand off to the glide on the next branch.
        theta -= omega * dt
        if os.clock() >= spinUntil then
            -- set up the glide: pick the World-Throw detent nearest the natural
            -- ease-out distance (ω·T/2, the constant-decel reach), then land on it
            -- exactly via a cubic that starts at the spin velocity ω and ends at 0.
            local throw = latestWorldThrow or "rock"
            landTheta = landTargetFor(throw, omega * GLIDE_SEC / 2)
            glideP0 = theta
            glideD = theta - landTheta
            glideT0 = os.clock()
            mode = "glide"
        end
        applyTheta()
    elseif mode == "glide" then
        -- cubic Hermite over GLIDE_SEC: p(s) = p0 − D·(3s²−2s³) − ω·T·(s³−2s²+s).
        -- p'(0) = −ω (continuous with the spin), p'(T) = 0 (rests on the detent),
        -- p(T) = landTheta exactly → a smooth glide to the World Throw, no snap.
        local s = (os.clock() - glideT0) / GLIDE_SEC
        if s >= 1 then
            theta = landTheta -- settle exactly on the detent
            omega = 0
            mode = "hold"
            EventBus.Cue:Fire({ kind = "drumRest" }) -- the throw may now be revealed
        else
            theta = glideP0
                - glideD * (3 * s * s - 2 * s * s * s)
                - omega * GLIDE_SEC * (s * s * s - 2 * s * s + s)
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
    -- Stuck-guard: the spin+glide is a deterministic ~4s, so it normally finishes on
    -- its own (a touch into this fresh ACTIVE — fine, the next strike is a round away).
    -- Only step in if it's clearly OVERDUE (stalled), and only then snap to the throw
    -- detent — never cut a glide that's still gracefully running.
    if info.phase == "ACTIVE" and mode ~= "hold" and strikeT0 >= 0 then
        if os.clock() - strikeT0 > SPIN_SEC + GLIDE_SEC + 1 then
            if latestWorldThrow then
                landTheta = landTargetFor(latestWorldThrow, 0)
            end
            theta = landTheta
            omega = 0
            mode = "hold"
            applyTheta()
        end
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    -- The drum is at rest until CONTACT. We key off "gongHit" (fired at the swing's end,
    -- when the log actually reaches the bell and the dowel meets the paddle) — NOT
    -- "gongStrike" (the swing's start), so the drum spins on the strike, not before it.
    if cue.kind == "gongHit" then
        local throw = latestWorldThrow
        if not throw then
            return -- nothing authoritative yet; stay at rest on the prior face
        end
        -- The kick: spin the drum at a steady DRUM_KICK for SPIN_SEC, then glide to the
        -- World Throw over GLIDE_SEC (handled in the heartbeat). The motion is a fixed
        -- ~4s regardless of speed, so the landing is deterministic; `throw` is bound now
        -- so the glide targets the right detent even if a later reveal arrives.
        latestWorldThrow = throw
        omega = (stage:GetAttribute("DrumKick") :: number) or DRUM_KICK
        spinUntil = os.clock() + SPIN_SEC
        strikeT0 = os.clock()
        mode = "spin"
        kickT0 = os.clock() -- flick the pin-wheel in lockstep
    end
end)
