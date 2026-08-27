--!strict
-- watchWingbeat.luau — see the wingbeat deliberately, instead of waiting for a random flight.
--
-- ⚠ WHY THIS EXISTS. Familiars hold a perch for 10–60s and then fly to a RANDOMLY chosen one, so
-- "watch a flight side-on" means loitering and hoping. A change to the beat could not be gated.
--
-- Two modes, because there are two different questions and they want different rigs:
--
--   ISOLATED (Edit or Play) — IS THE MOTION RIGHT? A bird parked in front of the camera, side-on,
--   wings driven at a fraction of real speed, with the wingtip's path traced as a ribbon of beads
--   so the loop is a SHAPE you can look at rather than a blur you have to infer. This is the mode
--   that answers "does the tip trace a loop, do both wings rise together, is 45° too much".
--
--   FLIGHT (Edit or Play) — DOES IT READ? A second, test-only bird flying the Overlook upper
--   deck's north rail ↔ south rail (~30 studs), pausing at each end, forever. View from EAST of
--   the deck: side-on is the angle where a vertical beat and a fore-aft sweep look most different.
--
--   ⚠ EDIT IS THE EASIER PATH and the one to reach for. No Play, no datamodel to choose, no
--   streaming, and the camera flies free. In Play this MUST run on the client (see the guard
--   below), which means finding Studio's Test-tab Client/Server toggle.
--
-- ⚠ EVERYTHING LANDS IN ONE FOLDER IN Workspace.Sandbox, the sanctioned home for throwaway rigs
-- ([[rojo-and-place]]). Nothing touches RoshamboStage or CanyonWorld. Delete the folder and every
-- connection drops and every borrowed tag is restored — that is the whole cleanup story, and it is
-- why each connection re-checks the folder rather than trusting a flag.

-- ⚠ WHICH BIRD. The roster is `<Species>Body` / `<Species>Wings` under
-- ReplicatedStorage.RoshamboBirds, so this is the only line to change to look at a different one.
-- Every framing number below is DERIVED from the chosen bird's own size, because the karasu is
-- twice the uguisu and a distance tuned for one is wrong by 2x for the other.
local SPECIES: string = "Uguisu" -- "Uguisu" | "Karasu"

local MODE: string = "ISOLATED" -- "ISOLATED" | "FLIGHT"
local BEAT_RATE = 0.22 -- fraction of real wingbeat speed (ISOLATED only)
local TRACE = true -- draw the wingtip path (ISOLATED only)
local PAUSE_AT_ENDS = 2.0 -- seconds perched before flying back (FLIGHT only)
local TRACE_BEADS = 140

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "WingbeatWatch"

-- ⚠ RUN THIS ON THE CLIENT. In Play, the command bar has a context dropdown (Client / Server) and
-- it does NOT default to Client. Run on the server and the tool reports success while you see
-- nothing: the parts are made server-side, `StreamingEnabled` is on, and they never reach your
-- screen. The real familiars have no such problem because BirdController is a LocalScript and
-- builds its birds client-side -- `Workspace.Familiars` does not exist on the server at all.
-- Better to refuse loudly than to print "FLIGHT: 30.2 studs" at someone staring at an empty rail.
local IN_PLAY = RunService:IsRunning()
if IN_PLAY and RunService:IsServer() then
    error(
        "watchWingbeat: this ran on the SERVER, where StreamingEnabled means you will never see it "
            .. "(the real familiars are client-built -- Workspace.Familiars does not exist on the "
            .. "server at all). Either switch the datamodel to Client -- in current Studio that is "
            .. "the Test tab's 'Current: Client/Server' toggle, NOT the command bar -- or just stop "
            .. "Play and run this in EDIT, which needs no context at all and is the easier path."
    )
end

-- ⚠ REQUIRE A CLONE, NOT THE MODULE. Studio's command-bar VM caches a ModuleScript's RESULT, so
-- once anything in this session has required BirdFlight, every later require returns the same
-- table however many times Rojo has synced since ([[misc-engine-traps]]). Parent the clone beside
-- the original first, so any relative require inside it still resolves against its real siblings.
local function freshRequire(module: ModuleScript): any
    local clone = module:Clone()
    clone.Name = module.Name .. "_watchTmp"
    clone.Parent = module.Parent
    local ok, result = pcall(require, clone)
    clone:Destroy()
    assert(ok, `watchWingbeat: could not require {module.Name}: {result}`)
    return result
end

local sharedFolder = ReplicatedStorage:WaitForChild("RoshamboShared")
local BirdFlight = freshRequire(sharedFolder:WaitForChild("BirdFlight") :: ModuleScript)

-- Accept either a MeshPart or the Model the 3D Importer wraps it in — same reason BirdController
-- does: which of the two reached the .rbxm depends on what was right-clicked.
local function meshOf(a: Instance?): BasePart?
    if not a then
        return nil
    end
    return (if a:IsA("BasePart") then a else a:FindFirstChildWhichIsA("MeshPart", true)) :: BasePart?
end

local birdAssets = ReplicatedStorage:FindFirstChild("RoshamboBirds")
assert(birdAssets, "watchWingbeat: no ReplicatedStorage.RoshamboBirds")
local BODY = meshOf(birdAssets:FindFirstChild(SPECIES .. "Body"))
local WINGS = meshOf(birdAssets:FindFirstChild(SPECIES .. "Wings"))
assert(
    BODY and WINGS,
    `watchWingbeat: need both {SPECIES}Body and {SPECIES}Wings under ReplicatedStorage.RoshamboBirds`
)

-- ⚠ FRAMING COMES OFF THE BIRD, not off a constant. Body LENGTH is the z extent — the FBX axis
-- conversion puts nose-to-tail on z — and the karasu is 1.640 against the uguisu's 0.828.
local BODY_LEN = (BODY :: BasePart).Size.Z
local VIEW_DISTANCE = BODY_LEN * 3.0
local BEAD_SIZE = BODY_LEN * 0.015

-- ===== workspace =====

local sandbox = workspace:FindFirstChild("Sandbox")
if not sandbox then
    sandbox = Instance.new("Folder")
    sandbox.Name = "Sandbox"
    sandbox.Parent = workspace
end

local existing = sandbox:FindFirstChild(FOLDER_NAME)
if existing then
    existing:Destroy() -- re-running replaces the previous rig rather than stacking two
end

local rig = Instance.new("Folder")
rig.Name = FOLDER_NAME
rig.Parent = sandbox

local function spawnBird(): (BasePart, BasePart, { [string]: Bone })
    local body = (BODY :: BasePart):Clone()
    local wings = (WINGS :: BasePart):Clone()
    for _, p in { body, wings } do
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.Parent = rig
    end
    wings.Transparency = 1
    local bones: { [string]: Bone } = {}
    for _, name in { "wing_R", "wing_L", "wrist_R", "wrist_L" } do
        local b = wings:FindFirstChild(name, true)
        if b and b:IsA("Bone") then
            bones[name] = b
        end
    end
    -- ⚠ THE HIPS LIVE ON THE BODY, NOT THE WINGS, and the tool needs them or it cannot show the
    -- landing gear at all -- which it could not, until 2026-08-25.
    for _, name in { "joint12", "joint25" } do
        local b = body:FindFirstChild(name, true)
        if b and b:IsA("Bone") then
            bones[name] = b
        end
    end
    return body, wings, bones
end

-- Seat both halves by their SHARED ORIGIN (the feet), never by the part centre, and take the
-- rotation from `base` — PivotOffset's rotation carries the FBX axis conversion and reintroduces a
-- nose-up attitude. Exactly what BirdController does, and for the same reasons.
local function seat(body: BasePart, wings: BasePart, base: CFrame)
    body.CFrame = base * CFrame.new(-body.PivotOffset.Position)
    wings.CFrame = base * CFrame.new(-wings.PivotOffset.Position)
end

local function pose(bones: { [string]: Bone }, open: number, beatX: number, beatZ: number)
    local shoulder, wrist = BirdFlight.foldAngles(open)
    local zRight = math.rad(shoulder + beatZ)
    if bones.wing_R then
        bones.wing_R.Transform = CFrame.Angles(math.rad(beatX), 0, zRight)
    end
    if bones.wing_L then
        bones.wing_L.Transform = CFrame.Angles(math.rad(beatX), 0, -zRight)
    end
    if bones.wrist_R then
        bones.wrist_R.Transform = CFrame.Angles(0, 0, math.rad(wrist))
    end
    if bones.wrist_L then
        bones.wrist_L.Transform = CFrame.Angles(0, 0, math.rad(-wrist))
    end
end

-- ===== ISOLATED =====

local function runIsolated()
    local cam = workspace.CurrentCamera
    assert(cam, "watchWingbeat: no CurrentCamera")
    local origin = cam.CFrame.Position + cam.CFrame.LookVector * VIEW_DISTANCE
    -- SIDE-ON: aim the bird along the camera's RIGHT, so its profile faces the lens. A bird viewed
    -- nose-on tells you nothing about a wingbeat.
    local base = CFrame.lookAt(origin, origin + cam.CFrame.RightVector)

    local body, wings, bones = spawnBird()
    wings.Transparency = 0
    seat(body, wings, base)

    local beads: { BasePart } = {}
    if TRACE then
        for i = 1, TRACE_BEADS do
            local bead = Instance.new("Part")
            bead.Name = `Tip{i}`
            bead.Shape = Enum.PartType.Ball
            bead.Size = Vector3.new(BEAD_SIZE, BEAD_SIZE, BEAD_SIZE)
            bead.Anchored, bead.CanCollide, bead.CastShadow = true, false, false
            bead.Material = Enum.Material.Neon
            bead.Color = Color3.fromRGB(255, 210, 90)
            bead.Transparency = 1
            bead.Parent = rig
            beads[i] = bead
        end
    end

    local t, cursor = 0, 0
    local conn: RBXScriptConnection
    conn = RunService.Heartbeat:Connect(function(dt)
        if rig.Parent == nil then
            conn:Disconnect()
            return
        end
        t += dt * BEAT_RATE
        local beatX, beatZ = BirdFlight.beatPose(t, 0, true)
        pose(bones, 1, beatX, beatZ)
        if TRACE and bones.wrist_R and bones.wing_R then
            -- TransformedWorldCFrame reflects the POSED bone, so this traces what is actually on
            -- screen rather than what the maths intended.
            local w = bones.wing_R.TransformedWorldCFrame.Position
            local r = bones.wrist_R.TransformedWorldCFrame.Position
            cursor = cursor % TRACE_BEADS + 1
            local bead = beads[cursor]
            bead.Position = r + (r - w)
            bead.Transparency = 0
        end
    end)

    print(
        ("[watchWingbeat] %s ISOLATED at %.1f%% speed, %s. Body %.2f studs, viewed from %.2f. Delete Workspace.Sandbox.%s to stop."):format(
            SPECIES,
            BEAT_RATE * 100,
            if TRACE then "tracing the right wingtip" else "no trace",
            BODY_LEN,
            VIEW_DISTANCE,
            FOLDER_NAME
        )
    )
end

-- ===== FLIGHT =====

-- The Overlook's rails are compass-named (RailNUpperDeckCap1, RailSUpperDeckCap1, ...). Pick the
-- N/S pair whose x agree most closely, so the flight runs almost pure north-south and reads
-- side-on from the east.
local function overlookPair(): (Attachment?, Attachment?)
    local north: { Attachment }, south: { Attachment } = {}, {}
    for _, a in CollectionService:GetTagged("FamiliarPerch") do
        if a:IsA("Attachment") and a:IsDescendantOf(workspace) then
            local parent = a.Parent
            local name = if parent then parent.Name else ""
            if string.find(a:GetFullName(), "Overlook") and string.find(name, "Upper") then
                if string.match(name, "^RailN") then
                    table.insert(north, a)
                elseif string.match(name, "^RailS") then
                    table.insert(south, a)
                end
            end
        end
    end
    local bestN, bestS, bestDx = nil, nil, math.huge
    for _, n in north do
        for _, s in south do
            local dx = math.abs(n.WorldPosition.X - s.WorldPosition.X)
            if dx < bestDx then
                bestN, bestS, bestDx = n, s, dx
            end
        end
    end
    return bestN, bestS
end

local function runFlight()
    local a, b = overlookPair()
    assert(a and b, "watchWingbeat: could not find an Overlook upper-deck N/S rail pair")
    local from, to = (a :: Attachment).WorldPosition, (b :: Attachment).WorldPosition

    -- ⚠ TAKE THE TWO PERCHES OUT OF THE POOL. Within one client no two birds share a perch — the
    -- controller's `taken` table covers every bird that client renders — but a real familiar could
    -- still CLAIM one of these and sit in the middle of the demo. Untagging removes them from
    -- pickPerch's candidate list; the tags are restored when the rig folder is deleted.
    -- ⚠ ONLY BORROW IN PLAY, AND THE REASON IS SYMMETRIC. In PLAY a real familiar could claim one
    -- of these two and sit in the middle of the demo, so the tags come off -- and that edit dies
    -- with the session, so it costs nothing. In EDIT there are no familiars at all (BirdController
    -- is a LocalScript and never runs), so there is nothing to exclude AND the tag change would be
    -- a change to the SAVED PLACE. Four Overlook perches were lost exactly that way before this
    -- check existed: borrowed in Edit, never given back, silently missing from every bird's pool.
    local borrowed: { Attachment } = {}
    if IN_PLAY then
        borrowed = { a :: Attachment, b :: Attachment }
        for _, at in borrowed do
            CollectionService:RemoveTag(at, "FamiliarPerch")
        end
    end

    local body, wings, bones = spawnBird()
    -- ⚠ HORIZONTAL distance drives the path; the height difference is lerped on top. `along` is
    -- spent along the GROUND TRACK, so feeding it a 3D magnitude overshoots whenever the two
    -- perches sit at different heights. These two are level, which is exactly why it would have
    -- gone unnoticed until the tool was pointed at some other pair.
    local flatRun = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
    local distance = flatRun.Magnitude
    local climb = to.Y - from.Y
    local duration = BirdFlight.flightDuration(distance)
    local legNo = 0
    local phase, clock = "PERCH", 0

    local conn: RBXScriptConnection
    conn = RunService.Heartbeat:Connect(function(dt)
        if rig.Parent == nil then
            conn:Disconnect()
            for _, at in borrowed do
                if at.Parent then
                    CollectionService:AddTag(at, "FamiliarPerch")
                end
            end
            return
        end
        clock += dt
        local src = if legNo % 2 == 0 then from else to
        local dst = if legNo % 2 == 0 then to else from

        if phase == "PERCH" then
            -- ⚠ DO NOT SNAP TO THE NEXT DESTINATION ON ARRIVAL. This used to face `dst` from the
            -- first perched frame, and since legNo had already flipped, dst was where the bird had
            -- just come FROM -- a clean 180 the instant it landed (owner, 2026-08-25). A bird lands
            -- facing the way it was going, stands, and THEN turns to leave. Tool-only: the game's
            -- perched branch keeps its yaw and never had this.
            local departing = (dst - src) * Vector3.new(1, 0, 1)
            local arriving = if legNo == 0 then departing else -departing
            local yawFrom = math.atan2(-arriving.X, -arriving.Z)
            local yawTo = math.atan2(-departing.X, -departing.Z)
            local delta = (yawTo - yawFrom + math.pi) % (2 * math.pi) - math.pi
            local turnStart = PAUSE_AT_ENDS * 0.45
            local q = math.clamp((clock - turnStart) / math.max(1e-3, PAUSE_AT_ENDS - turnStart), 0, 1)
            local yaw = yawFrom + delta * (q * q * (3 - 2 * q))
            seat(body, wings, CFrame.new(src) * CFrame.Angles(0, yaw, 0))
            pose(bones, 0, 0, 0)
            wings.Transparency = 1
            if bones.joint12 then
                bones.joint12.Transform = CFrame.new()
            end
            if bones.joint25 then
                bones.joint25.Transform = CFrame.new()
            end
            if clock >= PAUSE_AT_ENDS then
                phase, clock = "FLY", 0
            end
            return
        end

        local k = math.min(1, clock / duration)
        local shape = BirdFlight.flightShape(0, legNo)
        local along, side, rise = BirdFlight.flightPoint(k, distance, shape)
        local dir = (dst - src)
        local flat = Vector3.new(dir.X, 0, dir.Z)
        local unit = if flat.Magnitude > 1e-4 then flat.Unit else Vector3.new(0, 0, 1)
        local lateral = Vector3.new(-unit.Z, 0, unit.X)
        local dy = if legNo % 2 == 0 then climb else -climb
        -- ⚠ `along` IS A FRACTION (0..1), NOT STUDS. flightPoint returns `dist / total`, and
        -- BirdController spends it as `fwd * (along * dist)`. Dropping the `* distance` here made
        -- the bird advance at most ONE stud across a thirty-stud flight while `rise` -- which IS
        -- in studs -- lifted it 2.6, so it bobbed up and down over the departure rail and read as
        -- hovering motionless. Two values in one return tuple, different units, no type to catch it.
        local pos = src + unit * (along * distance) + lateral * side + Vector3.new(0, rise + dy * k, 0)

        local open = BirdFlight.wingExtension(clock, 0, true)
        local beatX, beatZ = BirdFlight.beatPose(clock, 0, true)
        wings.Transparency = BirdFlight.wingTransparency(open)
        pose(bones, open, beatX, beatZ)
        -- gear up, same as BirdController: the tool is only useful if it shows what the game does
        local tuck = math.rad(BirdFlight.legTuck(k) * BirdFlight.LEG_TUCK_DEG)
        if bones.joint12 then
            bones.joint12.Transform = CFrame.Angles(tuck, 0, 0)
        end
        if bones.joint25 then
            bones.joint25.Transform = CFrame.Angles(tuck, 0, 0)
        end
        seat(body, wings, CFrame.lookAt(pos, pos + unit))

        if k >= 1 then
            legNo += 1
            phase, clock = "PERCH", 0
        end
    end)

    print(
        ("[watchWingbeat] FLIGHT: %s <-> %s, %.1f studs, %.2fs each way."):format(
            (a :: Attachment).Parent and ((a :: Attachment).Parent :: Instance).Name or "?",
            (b :: Attachment).Parent and ((b :: Attachment).Parent :: Instance).Name or "?",
            distance,
            duration
        )
    )
    print(
        ("[watchWingbeat] Stand EAST of the deck for a side-on view. Delete Workspace.Sandbox.%s to stop."):format(
            FOLDER_NAME
        )
    )
end

if MODE == "FLIGHT" then
    runFlight()
else
    runIsolated()
end
