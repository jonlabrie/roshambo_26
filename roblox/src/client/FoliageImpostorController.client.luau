--!strict
-- Angle-fade for card-impostor foliage. Clump Models tagged "GrassImpostor"
-- carry a <Name>_Caps MeshPart (top-down bake at plume height) and <Name>_Vert
-- planes. Verticals always show; the caps' LocalTransparencyModifier follows
-- the camera's elevation over each clump (ImpostorFade), so eye-level views
-- keep a clean profile and overlooks see a rosette instead of a star.
--
-- STREAMING: parts stream in and out under StreamingEnabled, so NOTHING about
-- a clump's contents is cached at tag time — the update loop resolves the caps
-- part live each tick (FindFirstChild by naming convention, O(1)) and anchors
-- on the cap's own position. Caching descendants at registration is how the
-- first version silently did nothing: models tag-replicate before their parts.
--
-- Live-tune: Workspace attributes ImpostorCapFadeLo / ImpostorCapFadeHi
-- (degrees; defaults from ImpostorFade.DEFAULT).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ImpostorFade = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("ImpostorFade"))

local TAG = "GrassImpostor"
local UPDATE_INTERVAL = 0.1

local tagged: { [Model]: boolean } = {}

local function register(inst: Instance)
    if inst:IsA("Model") then
        tagged[inst] = true
    end
end

local function unregister(inst: Instance)
    tagged[inst :: Model] = nil
end

for _, inst in CollectionService:GetTagged(TAG) do
    register(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)

local function num(attr: string, default: number): number
    local v = workspace:GetAttribute(attr)
    return if typeof(v) == "number" then v else default
end

-- every band live-tunable from Workspace attributes; defaults from the module
local function config(): ImpostorFade.Config
    local d = ImpostorFade.DEFAULT
    return {
        capFadeLo = num("ImpostorCapFadeLo", d.capFadeLo),
        capFadeHi = num("ImpostorCapFadeHi", d.capFadeHi),
        edgeLo = num("ImpostorEdgeLo", d.edgeLo),
        edgeHi = num("ImpostorEdgeHi", d.edgeHi),
        vertFadeLo = num("ImpostorVertFadeLo", d.vertFadeLo),
        vertFadeHi = num("ImpostorVertFadeHi", d.vertFadeHi),
    }
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
    acc += dt
    if acc < UPDATE_INTERVAL then
        return
    end
    acc = 0
    local cam = workspace.CurrentCamera
    if not cam then
        return
    end
    local camPos = cam.CFrame.Position
    local cfg = config()
    local dead: { Model }? = nil
    for model in tagged do
        if model.Parent == nil then
            dead = dead or {}
            table.insert(dead :: { Model }, model)
            continue
        end
        local cap = model:FindFirstChild(model.Name .. "_Caps")
        if cap == nil or not cap:IsA("BasePart") then
            continue -- parts not streamed in yet; next tick will see them
        end
        local d = camPos - cap.Position
        local run = math.sqrt(d.X * d.X + d.Z * d.Z)
        local elev = ImpostorFade.elevation(d.Y, run)
        cap.LocalTransparencyModifier = ImpostorFade.capTransparency(elev, cfg)
        -- per-plane edge fade: a vertical plane hides as the camera sweeps
        -- across its edge; its 60°-offset partners carry the silhouette
        for i = 1, 3 do
            local vert = model:FindFirstChild(model.Name .. "_Vert" .. i)
            if vert and vert:IsA("BasePart") then
                local n = ImpostorFade.planeNormal(i)
                local wn = vert.CFrame:VectorToWorldSpace(Vector3.new(n.x, 0, n.z))
                local absDot = if run > 0.01 then math.abs((wn.X * d.X + wn.Z * d.Z) / run) else 1
                vert.LocalTransparencyModifier = ImpostorFade.vertTransparency(absDot, elev, cfg)
            end
        end
    end
    if dead then
        for _, m in dead do
            tagged[m] = nil
        end
    end
end)
