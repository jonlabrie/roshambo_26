--!nocheck
-- buildSuspensionBridge.luau — the valley's kazurabashi setpiece: a ~112-stud vine/rope suspension
-- footbridge across the Far-Wall canyon (spec 2026-07-09-suspension-bridge-design.md). Studio-runnable
-- (Edit; command bar / MCP execute_luau). Parts-only + catenary math, idempotent.
--
-- The VISIBLE rope/slat geometry is grouped into N_SEG span-segment Models (Seg_1..Seg_N), each tagged
-- "BridgeSway" and stamped a "SwayPhase" (0..1) attribute so BridgeSway.client.luau can pivot ~10 bones in a
-- travelling wave. The collision FLOOR + fall BARRIERS are static children of the root (never swayed).
-- Output: Workspace.CanyonWorld.Structures.Bridges.SuspensionBridge (place-only — SAVE THE PLACE).
local CollectionService = game:GetService("CollectionService")
local ws = workspace

local CONFIG = {
    capA = "Abutment_A_Cap",
    capB = "Abutment_B_Cap",
    SAG = 8,
    WIDTH = 6,
    N_SEG = 10,
    handH = 2.9,
    edgeDia = 0.5,
    handDia = 0.36,
    suspDia = 0.14,
    latticeDia = 0.10,
    suspEvery = 4.0,
    cableSeg = 1.5,
    slatPitch = 1.05,
    slatLen = 6.4,
    slatH = 0.28,
    slatD = 0.55,
    slatProud = 0.06,
    floorSeg = 2.0,
    floorH = 0.4,
    barrierH = 5.0,
    barrierT = 0.4,
    VINE = Color3.fromRGB(105, 86, 55),
    LASH = Color3.fromRGB(120, 100, 66),
    TIMBER = Color3.fromRGB(107, 79, 51),
    STONE = Color3.fromRGB(96, 94, 88),
    DARK = Color3.fromRGB(30, 26, 20),
}

local function capTop(name)
    local p
    for _, d in ws:GetDescendants() do
        if d.Name == name and d:IsA("BasePart") then
            p = d
            break
        end
    end
    assert(p, "missing " .. name)
    return Vector3.new(p.Position.X, p.Position.Y + p.Size.Y / 2, p.Position.Z)
end

local A, B = capTop(CONFIG.capA), capTop(CONFIG.capB)

local function lerp(a, b, t)
    return a + (b - a) * t
end
local function deckPoint(t)
    return Vector3.new(lerp(A.X, B.X, t), lerp(A.Y, B.Y, t) - CONFIG.SAG * 4 * t * (1 - t), lerp(A.Z, B.Z, t))
end
local function travel(t)
    local d = deckPoint(math.min(t + 0.01, 1)) - deckPoint(math.max(t - 0.01, 0))
    d = Vector3.new(d.X, 0, d.Z)
    return d.Magnitude > 1e-4 and d.Unit or Vector3.new(0, 0, -1)
end
local function cross(t)
    local tr = travel(t)
    return Vector3.new(-tr.Z, 0, tr.X)
end
local function segFor(t)
    return math.clamp(math.floor(t * CONFIG.N_SEG) + 1, 1, CONFIG.N_SEG)
end
local function edge(t, side)
    return deckPoint(t) + cross(t) * (CONFIG.WIDTH / 2 * side)
end

-- a rope cylinder spanning world points a->b (long axis local X). Uses the place-only "RopeHemp"
-- MaterialVariant (generated via the Studio material generator, base Fabric, StudsPerTile 0.6) so the
-- ropes read as twisted hemp; falls back to plain Fabric if the variant isn't present in the place.
local function cyl(parent, name, dia, a, b, color)
    local p = Instance.new("Part")
    p.Name = name
    p.Shape = Enum.PartType.Cylinder
    p.Anchored = true
    p.CanCollide = false
    p.Color = color
    p.Material = Enum.Material.Fabric
    p.MaterialVariant = "RopeHemp"
    p.Size = Vector3.new((b - a).Magnitude + dia * 0.5, dia, dia)
    p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
    p.Parent = parent
    return p
end

-- ===== build =====
local bridges = ws.CanyonWorld.Structures:FindFirstChild("Bridges") or Instance.new("Model")
bridges.Name = "Bridges"
bridges.Parent = ws.CanyonWorld.Structures
local root = bridges:FindFirstChild("SuspensionBridge")
if root then
    root:Destroy()
end
root = Instance.new("Model")
root.Name = "SuspensionBridge"
root.Parent = bridges

local seg = {}
for i = 1, CONFIG.N_SEG do
    local m = Instance.new("Model")
    m.Name = "Seg_" .. i
    m.Parent = root
    local ph = (i - 0.5) / CONFIG.N_SEG
    m:SetAttribute("SwayPhase", ph)
    m.WorldPivot = CFrame.new(deckPoint(ph))
    CollectionService:AddTag(m, "BridgeSway")
    seg[i] = m
end

-- four catenary cables (2 deck-edge at ±WIDTH/2, 2 hand at +handH), chained cylinders
local n = math.ceil((deckPoint(1) - deckPoint(0)).Magnitude / CONFIG.cableSeg)
for _, side in { 1, -1 } do
    for i = 0, n - 1 do
        local t0, t1 = i / n, (i + 1) / n
        local mid = (t0 + t1) / 2
        local eA, eB = edge(t0, side), edge(t1, side)
        cyl(seg[segFor(mid)], "DeckCable", CONFIG.edgeDia, eA, eB, CONFIG.VINE)
        local up = Vector3.new(0, CONFIG.handH, 0)
        cyl(seg[segFor(mid)], "HandCable", CONFIG.handDia, eA + up, eB + up, CONFIG.VINE)
    end
end

return string.format(
    "SuspensionBridge: %d segments, %d parts (cables). endA.Y=%.1f mid.Y=%.1f endB.Y=%.1f",
    CONFIG.N_SEG,
    #root:GetDescendants() - CONFIG.N_SEG,
    deckPoint(0).Y,
    deckPoint(0.5).Y,
    deckPoint(1).Y
)
