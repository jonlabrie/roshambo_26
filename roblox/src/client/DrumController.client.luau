--!strict
-- Drives the mawari-dōrō revolving lantern atop the shōrō. It RESTS through OPEN + LOCK
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

-- Collect the parts that turn with the hub. Only the 12 facets spin (the shade posts/cap/base/lamp
-- are static). The DAY glyph is a SurfaceGui parented to each facet (rides along automatically).
-- The NIGHT glyph is separate Neon geometry (a SurfaceGui can't bloom) — those parts join the spin
-- set so they ride the drum the same way the facets do. Both crossfade with nightFactor
-- (GlyphDayNight). Only the ROOT's offset is captured: the set is welded below, so the rest follow
-- it rather than being placed individually.
local spinParts: { BasePart } = {}
for k = 0, FACES - 1 do
    local face = rig:WaitForChild("Face" .. k) :: BasePart
    table.insert(spinParts, face)
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
    end
end

-- WELD THE SPIN SET INTO ONE ASSEMBLY (2026-09-06). Every member is placed by the SAME transform
-- (`spun * offset`, one hub rotation about local Y), so the 12 facets and their 12 night glyphs are
-- one rigid body by construction -- the drum turns, nothing inside it moves relative to anything
-- else. Welded, `applyTheta` writes ONE CFrame per frame instead of 24.
--
-- ⚠ CHILDREN MUST BE UNANCHORED, and WELD FIRST / UNANCHOR SECOND, per part (see AssemblyWeld and
-- [[misc-engine-traps]]): two anchored parts welded stay two independent anchored roots and the
-- weld buys nothing, while the reverse order would leave a loose board mid-air if a weld failed.
-- An anchored root carrying unanchored parts is a single ANCHORED assembly -- not simulated, not
-- replicated as motion -- which is what makes it safe under a client-side animation.
--
-- ⚠ AND THIS ONE IS DELIBERATELY CLIENT-SIDE, against the server-side rule the other welds follow.
-- Half the set does not exist on the server: `Glyphs.buildNightNeon` builds the 12 GlyphNight
-- MeshParts HERE, at runtime, because Rojo cannot load mesh geometry from a MeshId in a
-- `.model.json` ([[rojo-meshpart-rbxm]]) and ThrowDrum is generator output. Welding on the client
-- is safe here only because ThrowDrum is a direct-child Model of RoshamboStage and so is marked
-- ModelStreamingMode.Persistent by main.server.luau: its parts are always replicated, in full,
-- rather than arriving piecemeal the way the ChochinSway registration race assumed they had.
local spinRoot = spinParts[1]
local spinRootOffset = hub:ToObjectSpace(spinRoot.CFrame)
do
    local bound = 0
    for _, p in spinParts do
        if p ~= spinRoot then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = spinRoot
            weld.Part1 = p
            weld.Parent = spinRoot
            p.Anchored = false
            bound += 1
        end
    end
    spinRoot.Anchored = true
    print(`[DRUM] welded {bound} parts into the spin assembly (root {spinRoot.Name})`)
end

-- MOTION (strike-keyed), preserved from the hex drum but on the VERTICAL axis.
-- Spin is about the hub's LOCAL Y. Symbol `sym` sits at the −Z front window when
-- θ ≡ −sym*30° (mod 360); symbols recur every 3 facets → a detent every 90° (π/2).
-- rad/s during the constant spin, still live-tunable via the "DrumKick" attribute below. From
-- DrumStep rather than a literal: the glide carries this velocity into its own Hermite curve
-- (see the theta update below), and DrumStep.spec asserts against the same constant.
local DRUM_KICK = DrumStep.KICK_OMEGA
-- From DrumStep, not local literals: the SERVER waits this same span before growing a winner's
-- avatar (it cannot hear `drumRest`), so a retimed spin or glide has to move both together.
local SPIN_SEC = DrumStep.SPIN_SECONDS
local GLIDE_SEC = DrumStep.GLIDE_SECONDS
-- PADDLE CHOREOGRAPHY (2026-07-23): the strike smacks the paddle 90° so it rests
-- PARALLEL to the log, out of the dowel's path; once the drawing dowel has crawled
-- south past the paddle's sweep, the spindle slowly carries it the remaining 270°
-- (same direction — one clean turn per round) back to perpendicular, cocked for the
-- next strike. The fiction: all of it is driven by the throw drum overhead.
local KICK_FLICK_DUR = 0.4
local KICK_RETURN_DUR = 4.0
local PADDLE_Z = 6.42 -- MIRRORS ArenaLayout.bellDrive.paddle z
local PADDLE_CLEAR = 1.6 -- the dowel must be this far south before the return sweep starts

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
local landingCue = "drumRest" -- "drumRest" (a real face) | "drumMiss" (honest between-windows stop)
-- s past min spin to wait for the reveal before settling anyway. From DrumStep, not a local literal:
-- main.client.luau's reveal-safety fallback has to sit BEHIND this worst case or it spoils the throw
-- while the drum is still turning, and it can only do that if the number is visible outside this file.
local STALL_MAX = DrumStep.STALL_MAX_SECONDS

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
addKick("VertShaft", 1, 6.42, -1) -- pivots MIRROR ArenaLayout.bellDrive.vertBase (x, z)
addKick("VertPaddle", 1, 6.42, -1)
local kickAngle = 0 -- current settled rotation
local kickBase = 0 -- segment start angle
local kickTarget = 0 -- segment end angle
local kickDur = KICK_FLICK_DUR
local kickT0 = -1
local kickState = "perp" -- "perp" | "flick" | "parallel" | "return"
local kickDowelPart = stage:WaitForChild("BonshoRig"):WaitForChild("ShuMokuDowel") :: BasePart
local function applyKick(angle: number)
    for _, k in kickParts do
        local piv = CFrame.new(k.px, k.restY, k.pz)
        k.part.CFrame = piv * CFrame.Angles(0, k.sign * angle, 0) * piv:Inverse() * k.restCF
    end
end

-- ONE write: the spin set is a welded assembly, so placing its root places all 24 parts.
local function applyTheta()
    local spun = hub * CFrame.Angles(0, theta, 0) -- LOCAL Y is the spin axis
    spinRoot.CFrame = spun * spinRootOffset
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
        local haveThrow = latestWorldThrow ~= nil
        if os.clock() >= spinUntil and (haveThrow or os.clock() >= spinUntil + STALL_MAX) then
            -- THE DRUM NEVER LIES (owner's ruling, 2026-09-05, overturning the ship-and-watch
            -- residual): a late payload means the drum lands LATE; a payload that never comes
            -- means it rests BETWEEN windows -- an honest miss, cue "drumMiss". The old
            -- fallback (`lastLandedThrow or "R"`) put a stale face at the window for the tape
            -- to contradict, which is worse than no face at all.
            if haveThrow then
                local throw = latestWorldThrow :: string
                latestWorldThrow = nil
                landTheta = landTargetFor(throw, omega * GLIDE_SEC / 2)
                landingCue = "drumRest"
            else
                landTheta = DrumStep.missTargetTheta(theta, omega * GLIDE_SEC / 2)
                landingCue = "drumMiss"
            end
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
            EventBus.Cue:Fire({ kind = landingCue })
        else
            theta = glideP0
                - glideD * (3 * s * s - 2 * s * s * s)
                - omega * GLIDE_SEC * (s * s * s - 2 * s * s + s)
        end
        applyTheta()
    end
    if kickT0 >= 0 then
        local prog = math.clamp((os.clock() - kickT0) / kickDur, 0, 1)
        local eased = if kickState == "flick"
            then 1 - (1 - prog) * (1 - prog) -- smacked: fast, easing out
            else prog * prog * (3 - 2 * prog) -- driven: smooth slow crawl
        applyKick(kickBase + (kickTarget - kickBase) * eased)
        if prog >= 1 then
            kickAngle = kickTarget
            kickT0 = -1
            kickState = if kickState == "flick" then "parallel" else "perp"
        end
    elseif kickState == "parallel" and kickDowelPart.Position.Z > PADDLE_Z + PADDLE_CLEAR then
        -- the drawing dowel is safely past the paddle's sweep: crawl back to perpendicular
        kickState = "return"
        kickBase = kickAngle
        kickTarget = kickAngle + 3 * math.pi / 2
        kickDur = KICK_RETURN_DUR
        kickT0 = os.clock()
    end
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    latestWorldThrow = reveal.worldThrow
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "OPEN" and mode ~= "hold" and strikeT0 >= 0 then
        -- Guard fires only beyond the worst legitimate spin + stall + glide (10s)
        if os.clock() - strikeT0 > SPIN_SEC + STALL_MAX + GLIDE_SEC + 1 then
            if latestWorldThrow then
                landTheta = landTargetFor(latestWorldThrow, 0)
            end
            latestWorldThrow = nil -- consume on use
            theta = landTheta
            omega = 0
            mode = "hold"
            applyTheta()
        end
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongHit" then
        omega = (stage:GetAttribute("DrumKick") :: number) or DRUM_KICK
        spinUntil = os.clock() + SPIN_SEC
        strikeT0 = os.clock()
        mode = "spin"
        -- the dowel smacks the paddle: fast 90° to rest PARALLEL to the log
        kickState = "flick"
        kickBase = kickAngle
        kickTarget = kickAngle + math.pi / 2
        kickDur = KICK_FLICK_DUR
        kickT0 = os.clock()
    end
end)
