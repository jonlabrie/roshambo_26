-- Idempotent ZenDojo terrain: run via MCP execute_luau in EDIT mode.
-- Numbers from tools/builders/ArenaLayout.luau — re-paste on layout change.
-- Fills are sized >= 4 studs (terrain voxel resolution); thinner fills mush.
-- Tanada look (2026-06-07 refs): wavy terrace edges via sine-stamped lobes
-- and bays, flooded paddy strips along each wall base, backdrop hill ring.
local L = {
    bowlRadius = 220,
    basinRadius = 16,
    apronRadius = 84,
    tiers = { { radius = 116, height = 6 }, { radius = 152, height = 16 }, { radius = 188, height = 28 } },
    paddyStripWidth = 10,
    koiPond = { pos = { -130, 0, -115 }, radius = 14 },
    sando = { fromZ = -192, toZ = -86, fromY = 28, toY = 2, width = 10 },
}
local Terrain = workspace.Terrain
-- wipe the build region (covers backdrop hills)
Terrain:FillRegion(
    Region3.new(Vector3.new(-360, -60, -360), Vector3.new(360, 80, 360)):ExpandToGrid(4),
    4,
    Enum.Material.Air
)
-- backdrop hill ring: half-buried grass domes for the mountain silhouette
local HILLS = {
    { 10, 265, 55, 38 },
    { 55, 275, 65, 52 },
    { 100, 258, 48, 30 },
    { 150, 282, 70, 58 },
    { 195, 262, 52, 34 },
    { 240, 278, 60, 46 },
    { 285, 260, 45, 28 },
    { 330, 272, 62, 50 },
}
for _, h in HILLS do
    local a = math.rad(h[1])
    Terrain:FillBall(
        Vector3.new(math.cos(a) * h[2], h[4] - h[3], math.sin(a) * h[2]),
        h[3],
        Enum.Material.LeafyGrass
    )
end
-- bowl rim (outer ground ring at top tier height)
Terrain:FillCylinder(CFrame.new(0, L.tiers[3].height - 2, 0), 8, L.bowlRadius + 30, Enum.Material.LeafyGrass)
-- carve tiers (outer → inner), then organic edge stamps, then paddy strips
for i = #L.tiers, 1, -1 do
    local t = L.tiers[i]
    Terrain:FillCylinder(CFrame.new(0, t.height + 18, 0), 36, t.radius, Enum.Material.Air)
    Terrain:FillCylinder(CFrame.new(0, t.height - 2, 0), 4, t.radius, Enum.Material.LeafyGrass)
end
-- wavy walls: stamp bays (air) and lobes (grass) along each tier edge.
-- Deterministic sine mix — same result every run.
for i, t in L.tiers do
    local outerH = if i < #L.tiers then L.tiers[i + 1].height else L.tiers[#L.tiers].height
    for deg = 0, 354, 6 do
        local a = math.rad(deg)
        local wave = math.sin(a * 3 + t.radius) * 6 + math.sin(a * 7 + t.radius * 2) * 3
        local sx = math.cos(a) * (t.radius + wave)
        local sz = math.sin(a) * (t.radius + wave)
        if wave > 1.5 then
            -- bay: notch carved into the higher outer wall
            Terrain:FillCylinder(CFrame.new(sx, t.height + 18, sz), 36, 9, Enum.Material.Air)
            Terrain:FillCylinder(CFrame.new(sx, t.height - 2, sz), 4, 9, Enum.Material.LeafyGrass)
        elseif wave < -1.5 then
            -- lobe: finger of the higher terrace reaching inward
            Terrain:FillCylinder(
                CFrame.new(sx, (outerH + 2) / 2 - 2, sz),
                outerH + 4,
                9,
                Enum.Material.LeafyGrass
            )
        end
    end
end
-- flooded paddy strips: ring of water stamps along the base of each wall,
-- following the same wave so the water hugs the organic edge. Stamped as
-- small overlapping cylinders (a disc fill would flood the inner tiers).
for _, t in L.tiers do
    local stripMid = t.radius - 2 - L.paddyStripWidth / 2
    for deg = 0, 358, 4 do
        local a = math.rad(deg)
        local wave = math.sin(a * 3 + t.radius) * 6 + math.sin(a * 7 + t.radius * 2) * 3
        local sx = math.cos(a) * (stripMid + wave)
        local sz = math.sin(a) * (stripMid + wave)
        -- recess 2 studs below the tier surface, then flood
        Terrain:FillCylinder(
            CFrame.new(sx, t.height + 14, sz),
            32,
            L.paddyStripWidth / 2 + 2,
            Enum.Material.Air
        )
        Terrain:FillCylinder(CFrame.new(sx, t.height - 4, sz), 4, L.paddyStripWidth / 2, Enum.Material.Water)
    end
end
-- karesansui apron: carve to open sky, lay a 6-stud gravel slab (surface ~y2)
Terrain:FillCylinder(CFrame.new(0, 18, 0), 36, L.apronRadius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(0, -1, 0), 6, L.apronRadius, Enum.Material.Ground)
-- basin: 10-stud shaft, 4-stud water slab (surface y0, ~2-stud gravel lip)
Terrain:FillCylinder(CFrame.new(0, 3, 0), 10, L.basinRadius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(0, -2, 0), 4, L.basinRadius, Enum.Material.Water)
-- koi pond: carve through tier 3's surface (~28), water 19..23
local kx, kz = L.koiPond.pos[1], L.koiPond.pos[3]
Terrain:FillCylinder(CFrame.new(kx, 28, kz), 16, L.koiPond.radius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(kx, 21, kz), 4, L.koiPond.radius, Enum.Material.Water)
-- sandō ramp: carved channel descending the tier walls, rim plaza → apron.
for z = L.sando.fromZ, L.sando.toZ, 8 do
    local t = (z - L.sando.fromZ) / (L.sando.toZ - L.sando.fromZ)
    local floorY = L.sando.fromY + (L.sando.toY - L.sando.fromY) * t
    Terrain:FillBlock(CFrame.new(0, floorY + 10, z), Vector3.new(L.sando.width, 16, 9), Enum.Material.Air)
    Terrain:FillBlock(CFrame.new(0, floorY - 2, z), Vector3.new(L.sando.width, 4, 9), Enum.Material.Ground)
end
-- east/west access ramps: apron edge up to the rim, so terraces are walkable
for _, dir in { 1, -1 } do
    local fromX, toX = L.apronRadius, L.tiers[3].radius + 6
    for x = fromX, toX, 8 do
        local t = (x - fromX) / (toX - fromX)
        local floorY = 2 + (L.tiers[3].height - 2) * t
        Terrain:FillBlock(
            CFrame.new(dir * x, floorY + 10, 0),
            Vector3.new(9, 16, L.sando.width),
            Enum.Material.Air
        )
        Terrain:FillBlock(
            CFrame.new(dir * x, floorY - 2, 0),
            Vector3.new(9, 4, L.sando.width),
            Enum.Material.Ground
        )
    end
end
return "terrain built"
