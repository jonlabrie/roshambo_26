-- Idempotent ZenDojo terrain: run via MCP execute_luau in EDIT mode.
-- Numbers from tools/builders/ArenaLayout.luau — re-paste on layout change.
-- Fills are sized >= 4 studs (terrain voxel resolution); thinner fills mush.
local L = {
    bowlRadius = 110,
    basinRadius = 16,
    apronRadius = 42,
    tiers = { { radius = 58, height = 3 }, { radius = 76, height = 8 }, { radius = 94, height = 14 } },
    koiPond = { pos = { -70, 0, -62 }, radius = 14 },
}
local Terrain = workspace.Terrain
-- wipe the build region
Terrain:FillRegion(
    Region3.new(Vector3.new(-140, -20, -140), Vector3.new(140, 40, 140)):ExpandToGrid(4),
    4,
    Enum.Material.Air
)
-- bowl rim (outer ground ring at top tier height)
Terrain:FillCylinder(CFrame.new(0, L.tiers[3].height - 2, 0), 8, L.bowlRadius + 30, Enum.Material.LeafyGrass)
-- carve tiers: each lower tier cuts a flat-bottomed cylinder down to its height
for i = #L.tiers, 1, -1 do
    local t = L.tiers[i]
    Terrain:FillCylinder(CFrame.new(0, t.height + 14, 0), 28, t.radius, Enum.Material.Air)
    Terrain:FillCylinder(CFrame.new(0, t.height - 2, 0), 4, t.radius, Enum.Material.LeafyGrass)
end
-- karesansui apron: carve to open sky, lay a 6-stud gravel slab (surface ~y2)
Terrain:FillCylinder(CFrame.new(0, 14, 0), 28, L.apronRadius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(0, -1, 0), 6, L.apronRadius, Enum.Material.Ground)
-- basin: 10-stud shaft, 4-stud water slab (surface y0, ~2-stud gravel lip)
Terrain:FillCylinder(CFrame.new(0, 3, 0), 10, L.basinRadius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(0, -2, 0), 4, L.basinRadius, Enum.Material.Water)
-- koi pond: carve through tier 3 (8..20 clears the voxel lid), water 6..10
local kx, kz = L.koiPond.pos[1], L.koiPond.pos[3]
Terrain:FillCylinder(CFrame.new(kx, 14, kz), 12, L.koiPond.radius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(kx, 8, kz), 4, L.koiPond.radius, Enum.Material.Water)
return "terrain built"
