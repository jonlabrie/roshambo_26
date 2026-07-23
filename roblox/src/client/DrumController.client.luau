--!strict
-- Drives the mawari-dōrō revolving lantern atop the shōrō. It RESTS through ACTIVE + TALLY
-- showing the prior throw; on the bell strike (`gongHit`) the inner 12-facet drum is kicked
-- into a fast spin about its VERTICAL axis and DECELERATES to rest on the actual World Throw
-- (that becomes the next round's "prior"). Four windows 90° apart all read the same symbol.
-- Offset-capture pattern (cf. WheelController). Glyphs come from the shared Glyphs module and
-- are always full-bright (SurfaceGui LightInfluence 0) so they read gold-on-cypress by day and
-- as a lit glyph on the darkened wood by night. The pin-wheel flick is preserved as ambient
-- machinery (its physical reconnection to the vertical drum is the T8 drive-chain pass).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DrumStep = require(shared:WaitForChild("DrumStep"))
local Glyphs = require(shared:WaitForChild("Glyphs"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("ThrowDrum")
local drum = rig:WaitForChild("Drum") :: BasePart
local hub = drum.CFrame

local FACES = 12

-- SYMBOL_FOR_FACE (k % 3). Mirrors ThrowDrum.SYMBOL_FOR_FACE without requiring the builder
-- (builders live under tools/ and are not replicated to clients).
local SYMBOL_FOR_FACE: { [number]: string } = {}
do
    local sym = { [0] = "R", [1] = "P", [2] = "S" }
    for k = 0, FACES - 1 do
        SYMBOL_FOR_FACE[k] = sym[k % 3]
    end
end

-- Capture each facet's offset from the hub so we can re-place it under any hub rotation.
-- Only the 12 facets spin (the shade posts/cap/base/lamp are static). The DAY glyph is a
-- SurfaceGui parented to each facet (rides along automatically). The NIGHT glyph is separate Neon
-- geometry (a SurfaceGui can't bloom) — those parts are captured into the spin set below so they
-- ride the drum the same way the facets do. Both crossfade with nightFactor (GlyphDayNight).
local spinParts: { BasePart } = {}
local spinOffsets: { CFrame } = {}
for k = 0, FACES - 1 do
    local face = rig:WaitForChild("Face" .. k) :: BasePart
    table.insert(spinParts, face)
    table.insert(spinOffsets, hub:ToObjectSpace(face.CFrame))
    -- DAY: the approved gilt-gold glyph on the facet's outward (Front, -Z) side. Match the canvas
    -- aspect to the facet (a 4:5 panel) so the ○ ring stays round rather than stretched to an oval.
    local fs = face.Size -- {faceW, h, thickness}
    local cw = math.max(1, math.round(200 * fs.X / fs.Y))
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(cw, 200)
    gui.LightInfluence = 0
    gui.Parent = face
    Glyphs.renderDay(gui, SYMBOL_FOR_FACE[k])
    -- NIGHT: Neon geometry on the same facet; capture each part into the spin set so it turns with
    -- the drum (parenting to the anchored face alone would NOT carry it under our CFrame-driven spin).
    for _, np in Glyphs.buildNightNeon(face, SYMBOL_FOR_FACE[k]) do
        table.insert(spinParts, np)
        table.insert(spinOffsets, hub:ToObjectSpace(np.CFrame))
    end
end

-- MOTION (strike-keyed), preserved from the hex drum but on the VERTICAL axis.
-- Spin is about the hub's LOCAL Y. Symbol `sym` sits at the −Z front window when
-- θ ≡ −sym*30° (mod 360); symbols recur every 3 facets → a detent every 90° (π/2).
local DRUM_KICK = 4 -- rad/s during the constant spin (live-tunable via "DrumKick" attr)
local SPIN_SEC = 1.0
local GLIDE_SEC = 2.0
local KICK_DUR = 0.5

local theta = 0
local omega = 0
local mode = "hold"
local spinUntil = 0
local glideT0 = 0
local glideP0 = 0
local glideD = 0
local landTheta = 0
local strikeT0 = -1
local latestWorldThrow: string? = nil

-- PIN-WHEEL parts that flick on the strike (BellDrive) — unchanged; ambient machinery.
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
addKick("VertShaft", 1, 6.25, -1) -- pivots MIRROR ArenaLayout.bellDrive.vertBase (x, z)
addKick("VertPaddle", 1, 6.25, -1)
local kickT0 = -1
local kickBase = 0
local function applyKick(angle: number)
    for _, k in kickParts do
        local piv = CFrame.new(k.px, k.restY, k.pz)
        k.part.CFrame = piv * CFrame.Angles(0, k.sign * angle, 0) * piv:Inverse() * k.restCF
    end
end

local function applyTheta()
    local spun = hub * CFrame.Angles(0, theta, 0) -- LOCAL Y is the spin axis
    for i, p in spinParts do
        p.CFrame = spun * spinOffsets[i]
    end
end

-- Resting θ showing `throw` at the −Z window, at least `dmin` below current θ (keeps the
-- drum turning one direction into rest). Detents for a symbol recur every π/2 (90°).
local function landTargetFor(throw: string, dmin: number): number
    local sym = DrumStep.faceForThrow(throw) -- 0/1/2
    local tgt = math.rad(-sym * 30) -- a detent with `sym` at the −Z front window
    while tgt > theta - dmin do
        tgt -= math.pi / 2 -- step down a quarter-turn (continuing the −θ direction)
    end
    return tgt
end

applyTheta()

RunService.Heartbeat:Connect(function(_dt)
    if mode == "spin" then
        theta -= omega * _dt
        if os.clock() >= spinUntil then
            local throw = latestWorldThrow or "R"
            landTheta = landTargetFor(throw, omega * GLIDE_SEC / 2)
            glideP0 = theta
            glideD = theta - landTheta
            glideT0 = os.clock()
            mode = "glide"
        end
        applyTheta()
    elseif mode == "glide" then
        local s = (os.clock() - glideT0) / GLIDE_SEC
        if s >= 1 then
            theta = landTheta
            omega = 0
            mode = "hold"
            EventBus.Cue:Fire({ kind = "drumRest" })
        else
            theta = glideP0
                - glideD * (3 * s * s - 2 * s * s * s)
                - omega * GLIDE_SEC * (s * s * s - 2 * s * s + s)
        end
        applyTheta()
    end
    if kickT0 >= 0 then
        local prog = (os.clock() - kickT0) / KICK_DUR
        if prog >= 1 then
            applyKick(kickBase + math.pi)
            kickBase += math.pi
            kickT0 = -1
        else
            applyKick(kickBase + math.pi * (1 - (1 - prog) * (1 - prog)))
        end
    end
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    latestWorldThrow = reveal.worldThrow
end)

RoundUpdate.OnClientEvent:Connect(function(info)
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
    if cue.kind == "gongHit" then
        local throw = latestWorldThrow
        if not throw then
            return
        end
        latestWorldThrow = throw
        omega = (stage:GetAttribute("DrumKick") :: number) or DRUM_KICK
        spinUntil = os.clock() + SPIN_SEC
        strikeT0 = os.clock()
        mode = "spin"
        kickT0 = os.clock()
    end
end)
