--!strict
-- The 花火屋 noren stirring in the doorway. Each panel is a chain of segments hung from the head
-- rail (built in tools/builders/Machiya.luau), and this walks that chain every frame, bending each
-- joint a little further than the one above so the stir travels DOWN the cloth. A single rigid
-- rectangle swinging reads as a swinging rectangle; the bend is what reads as cloth.
--
-- THE SWAY IS A FRACTION OF EACH SEGMENT'S OWN REST LEAN, never an absolute angle. That is not a
-- style choice: the panel hangs leaning back under the eave precisely so it stays clear of the
-- reserved promenade, and scaling the rest lean can only ever make it lean MORE or LESS, never
-- cross vertical and swing out over the street. An absolute amplitude would have to be checked
-- against the frontage line, and would go wrong the day the rest lean changed.
--
-- Rest angles are read off the parts themselves at startup, so this file holds no copy of the
-- builder's hang. Nothing here is tested — no harness in this repo loads a `.client.luau`.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))
local AmbientConfig = require(script.Parent:WaitForChild("AmbientConfig"))

local TAG = "NorenSeg"
local SWAY = 0.85 -- how far the lean breathes, as a fraction of itself
local CROSS = 0.25 -- a smaller sideways drift, so it is not a flat pendulum
local SPEED = 0.55 -- rad/s — a slow indoor draught, not weather
local LAG = 0.6 -- phase added per segment down the panel: the stir travels

type Seg = { part: BasePart, rest: number, h: number }
type Panel = { hinge: Vector3, segs: { Seg }, phase: number }

-- Captured the FIRST time each part is seen, and never re-read. Panels are rebuilt as their
-- siblings replicate in, and by then the earlier segments are already being animated — measuring
-- "rest" off a live part would bake a mid-swing pose in as the hang and drift a little further
-- every time a rebuild happened.
local original: { [BasePart]: CFrame } = {}
local panels: { [Instance]: Panel } = {}

local function rebuild(parent: Instance)
    local found: { BasePart } = {}
    for _, c in parent:GetChildren() do
        if c:IsA("BasePart") and CollectionService:HasTag(c, TAG) then
            if original[c] == nil then
                original[c] = c.CFrame
            end
            table.insert(found, c)
        end
    end
    if #found == 0 then
        panels[parent] = nil
        return
    end
    -- Seg1, Seg2, Seg3 — the chain's order IS the name order, and the builder's test holds each
    -- segment's top on the one above, so a wrong order would visibly tear the panel apart.
    table.sort(found, function(a, b)
        return a.Name < b.Name
    end)
    local segs: { Seg } = {}
    for _, p in found do
        local base = original[p]
        local rx = select(1, base:ToEulerAnglesXYZ())
        table.insert(segs, { part = p, rest = rx, h = p.Size.Y })
    end
    local top = original[found[1]]
    local hinge = (top * CFrame.new(0, found[1].Size.Y / 2, 0)).Position
    panels[parent] = {
        hinge = hinge,
        segs = segs,
        -- Positional desync, so the panels in a bay do not stir as one sheet.
        phase = (hinge.X * 0.73 + hinge.Y * 0.29) % (2 * math.pi),
    }
end

local function onTagged(p: Instance)
    if p.Parent then
        rebuild(p.Parent)
    end
end

for _, p in CollectionService:GetTagged(TAG) do
    onTagged(p)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(onTagged)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(onTagged)

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = AmbientConfig.get()
    local fire, nextAcc = AmbientBudget.step(acc, dt, c.interval)
    acc = nextAcc
    if not fire then
        return
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return
    end
    local camCF = cam.CFrame
    local camPos, look = camCF.Position, camCF.LookVector
    local t = os.clock()
    for _, panel in panels do
        local d = panel.hinge - camPos
        local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
        if not AmbientBudget.inRange(distSq, c) then
            continue
        end
        -- sqrt only for what survived the range test; see AmbientBudget.inRange
        local dist = math.sqrt(distSq)
        local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
        if not AmbientBudget.inView(fdot, c) then
            continue
        end
        -- Walk the chain from the rail: each segment hangs off the bottom of the one above, so
        -- the panel stays joined no matter how far any single joint bends.
        local pos = panel.hinge
        for i, s in panel.segs do
            local ax = s.rest * (1 + SWAY * math.sin(t * SPEED + panel.phase + i * LAG))
            local az = s.rest * CROSS * math.sin(t * SPEED * 0.7 + panel.phase * 1.3 + i * LAG)
            local dir = CFrame.Angles(ax, 0, az)
            local drop = dir:VectorToWorldSpace(Vector3.new(0, -s.h, 0))
            s.part.CFrame = CFrame.new(pos + drop * 0.5) * dir
            pos += drop
        end
    end
end)
