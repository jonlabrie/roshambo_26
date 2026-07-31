--!strict
-- Angle-fade for card-impostor foliage. Clump Models tagged "GrassImpostor"
-- carry a *_Caps MeshPart (top-down bake at plume height) and *_Vert planes.
-- Verticals always show; the caps' LocalTransparencyModifier follows the
-- camera's elevation over each clump (ImpostorFade), so eye-level views keep a
-- clean profile and overlooks see a rosette instead of a star. Client-only:
-- LocalTransparencyModifier never replicates.
--
-- Live-tune: Workspace attributes ImpostorCapFadeLo / ImpostorCapFadeHi
-- (degrees; defaults from ImpostorFade.DEFAULT).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ImpostorFade = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("ImpostorFade"))

local TAG = "GrassImpostor"
local UPDATE_INTERVAL = 0.1
local ANCHOR_UP = 2 -- studs above the clump pivot: mid-plume, where the caps sit

type ClumpInfo = { caps: { BasePart }, anchor: Vector3 }
local clumps: { [Model]: ClumpInfo } = {}

local function register(inst: Instance)
    local model = inst :: Model
    if not model:IsA("Model") then
        return
    end
    local caps: { BasePart } = {}
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") and d.Name:find("_Caps") then
            table.insert(caps, d)
        end
    end
    if #caps > 0 then
        clumps[model] = {
            caps = caps,
            anchor = model:GetPivot().Position + Vector3.new(0, ANCHOR_UP, 0),
        }
    end
end

local function unregister(inst: Instance)
    clumps[inst :: Model] = nil
end

for _, inst in CollectionService:GetTagged(TAG) do
    register(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)

local function config(): ImpostorFade.Config
    local lo = workspace:GetAttribute("ImpostorCapFadeLo")
    local hi = workspace:GetAttribute("ImpostorCapFadeHi")
    if typeof(lo) == "number" and typeof(hi) == "number" then
        return { capFadeLo = lo, capFadeHi = hi }
    end
    return ImpostorFade.DEFAULT
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
    for model, info in clumps do
        if model.Parent == nil then
            clumps[model] = nil
            continue
        end
        local d = camPos - info.anchor
        local run = math.sqrt(d.X * d.X + d.Z * d.Z)
        local t = ImpostorFade.capTransparency(ImpostorFade.elevation(d.Y, run), cfg)
        for _, p in info.caps do
            p.LocalTransparencyModifier = t
        end
    end
end)
