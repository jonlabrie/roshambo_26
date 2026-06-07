-- Idempotent ZenDojo terrain: run via MCP execute_luau in EDIT mode.
-- Numbers from tools/builders/ArenaLayout.luau — re-paste on layout change.
-- Fills are sized >= 4 studs (terrain voxel resolution); thinner fills mush.
local L = {
    bowlRadius = 192,
    basinRadius = 16,
    apronRadius = 74,
    tiers = { { radius = 101, height = 4.5 }, { radius = 133, height = 12 }, { radius = 164, height = 21 } },
    koiPond = { pos = { -122, 0, -108 }, radius = 14 },
    sando = { fromZ = -166, toZ = -76, fromY = 21, toY = 2, width = 10 },
}
local Terrain = workspace.Terrain
-- wipe the build region
Terrain:FillRegion(
    Region3.new(Vector3.new(-240, -20, -240), Vector3.new(240, 60, 240)):ExpandToGrid(4),
    4,
    Enum.Material.Air
)
-- bowl rim (outer ground ring at top tier height)
Terrain:FillCylinder(CFrame.new(0, L.tiers[3].height - 2, 0), 8, L.bowlRadius + 30, Enum.Material.LeafyGrass)
-- carve tiers: each lower tier cuts a flat-bottomed cylinder down to its height
for i = #L.tiers, 1, -1 do
    local t = L.tiers[i]
    Terrain:FillCylinder(CFrame.new(0, t.height + 16, 0), 32, t.radius, Enum.Material.Air)
    Terrain:FillCylinder(CFrame.new(0, t.height - 2, 0), 4, t.radius, Enum.Material.LeafyGrass)
end
-- karesansui apron: carve to open sky, lay a 6-stud gravel slab (surface ~y2)
Terrain:FillCylinder(CFrame.new(0, 16, 0), 32, L.apronRadius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(0, -1, 0), 6, L.apronRadius, Enum.Material.Ground)
-- basin: 10-stud shaft, 4-stud water slab (surface y0, ~2-stud gravel lip)
Terrain:FillCylinder(CFrame.new(0, 3, 0), 10, L.basinRadius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(0, -2, 0), 4, L.basinRadius, Enum.Material.Water)
-- koi pond: carve through tier 3's surface (~21), water 12..16
local kx, kz = L.koiPond.pos[1], L.koiPond.pos[3]
Terrain:FillCylinder(CFrame.new(kx, 21, kz), 14, L.koiPond.radius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(kx, 14, kz), 4, L.koiPond.radius, Enum.Material.Water)
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
        local floorY = 2 + (21 - 2) * t
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
