--!strict
-- Plants the falls-pool iris from BAKED as-built coordinates.
--
-- Run in Studio (Edit) via the command bar. Idempotent: it clears its own output first, so a
-- re-run replaces rather than doubles.
--
-- WHY BAKED: these are hand-sited. The algorithm proposed margin cells; the USER moved the
-- hero clump across the pool and approved the rest, and there is no rule that regenerates
-- that judgement. `buildBridge` once read PathDraft markers and broke the moment they were
-- deleted — surveyed coordinates get baked, like placeYamadoro and SwitchbackDeck.
--
-- THE SITING LOGIC (2026-07-30):
--   * The falls pool is a COMPOSED SITE — dock, yukimi, cherry, uguisu — with its own
--     internal logic. Iris joins that composition; it is not the output of a scatter rule.
--   * Licensed by the garden spec: FallsDock carries a 15-stud garden radius that OVERRIDES
--     longitude (§2), and §3 places "iris at the water" in the GARDEN band.
--   * Every plant sits in genuine WET MARGIN — chosen from cells at water level (189.0) with
--     open water on at least 3 of 8 surrounding probes. Iris ensata grows IN the margin, not
--     beside it, so "near the water" is not the same test.
--   * The HERO clump is seen ACROSS the pool, ~20 studs from the dock. Its first position was
--     beside the dock and competed with the cherry behind it — two pink-purple masses at the
--     same depth doing the same job. Across the water it reads at a different distance.
--   * Singles are spread ~9 studs apart, no two adjacent ones the same variant.
--
-- Source: ServerStorage.IrisLibrary (12 variants, 54 MeshParts, one per material — a MeshPart
-- takes ONE SurfaceAppearance, so multi-material meshes import untextured). 001-006 are the
-- true single plants; 007-012 are multi-plant hero clumps.
local ServerStorage = game:GetService("ServerStorage")

-- yaw is what CFrame.Angles was GIVEN. Reading it back with atan2(-r02, r00) returns the
-- negative, so do not round-trip these through that extraction without negating.
local PLANTINGS = {
    { name = "DockIris_1", variant = "Iris009", pos = { -365.630, 188.010, -19.648 }, yaw = -83.49 },
    { name = "PoolIris_1", variant = "Iris001", pos = { -367.000, 189.537, -2.000 }, yaw = 24.00 },
    { name = "PoolIris_2", variant = "Iris002", pos = { -345.000, 187.730, -4.000 }, yaw = -61.00 },
    { name = "PoolIris_3", variant = "Iris003", pos = { -369.000, 188.679, 15.000 }, yaw = 137.00 },
    { name = "PoolIris_4", variant = "Iris004", pos = { -372.000, 188.210, -11.000 }, yaw = -18.00 },
    { name = "PoolIris_5", variant = "Iris005", pos = { -358.000, 188.751, 18.000 }, yaw = 95.00 },
    { name = "PoolIris_6", variant = "Iris006", pos = { -349.000, 189.465, 12.000 }, yaw = -122.00 },
    { name = "PoolIris_7", variant = "Iris004", pos = { -345.000, 188.830, -29.000 }, yaw = -74.00 },
    { name = "PoolIris_8", variant = "Iris001", pos = { -355.000, 189.000, -28.000 }, yaw = 118.00 },
}

local lib = ServerStorage:FindFirstChild("IrisLibrary")
if not lib then
    return "REFUSED: ServerStorage.IrisLibrary is missing"
end
local heroes = workspace.CanyonWorld.Foliage:FindFirstChild("Heroes")
if not heroes then
    return "REFUSED: CanyonWorld.Foliage.Heroes is missing"
end

for _, c in ipairs(heroes:GetChildren()) do
    if c.Name == "DockIris_1" or c.Name:match("^PoolIris_%d+$") then
        c:Destroy()
    end
end

local report = {}
for _, p in ipairs(PLANTINGS) do
    local m = Instance.new("Model")
    m.Name = p.name
    m.Parent = heroes
    local n = 0
    for _, d in ipairs(lib:GetDescendants()) do
        if d:IsA("MeshPart") and d.Name:match("^" .. p.variant .. "_") then
            local pc = d:Clone()
            pc.Anchored = true
            -- foliage is scenery: no collision, no queries, no shadow cost
            pc.CanCollide = false
            pc.CanQuery = false
            pc.CanTouch = false
            pc.CastShadow = false
            pc.Parent = m
            n += 1
        end
    end
    if n == 0 then
        m:Destroy()
        table.insert(report, string.format("  %s: NO %s pieces in IrisLibrary", p.name, p.variant))
    else
        -- pivot at the clump's BASE centre, so PivotTo seats it rather than burying it
        local cf, size = m:GetBoundingBox()
        m.WorldPivot = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
        m:PivotTo(CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * CFrame.Angles(0, math.rad(p.yaw), 0))
        local _, s2 = m:GetBoundingBox()
        table.insert(report, string.format("  %-12s %-8s %d pieces  h %.2f", p.name, p.variant, n, s2.Y))
    end
end

return string.format("planted %d iris at the falls pool\n%s", #PLANTINGS, table.concat(report, "\n"))
