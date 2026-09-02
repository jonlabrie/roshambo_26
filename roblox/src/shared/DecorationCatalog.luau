--!strict
-- The decoration catalog for the deck-decoration framework (2026-07-19). Pure lookups
-- (footprint/has/ids, Lune-tested) plus a Roblox-only placeholder builder (never called under
-- Lune — it only references Instance/Vector3/Color3 inside build()). The propId set MUST mirror
-- server/src/economy.ts PRICES.decoration (the TS<->Luau drift caveat): prices live TS-side, the
-- footprint + geometry live here. All footprints are centered on the prop origin.
local DecorationCatalog = {}

export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }

-- mirrors server MAX_DECORATIONS (economy.ts); used only for client-side cap display
DecorationCatalog.MAX_DECORATIONS = 24

-- stable render/order list of propIds
local ORDER = { "ishidoro", "tsukubai", "bonsai", "bench" }

-- centered footprints (studs). Distinct per prop so the four read as different objects.
local FOOTPRINTS: { [string]: Footprint } = {
    ishidoro = { minX = -1, maxX = 1, minZ = -1, maxZ = 1 }, -- stone lantern ~2x2
    tsukubai = { minX = -1.5, maxX = 1.5, minZ = -1.5, maxZ = 1.5 }, -- water basin ~3x3
    bonsai = { minX = -0.75, maxX = 0.75, minZ = -0.75, maxZ = 0.75 }, -- potted plant ~1.5x1.5
    bench = { minX = -2, maxX = 2, minZ = -0.75, maxZ = 0.75 }, -- wooden bench ~4x1.5
}

function DecorationCatalog.ids(): { string }
    return table.clone(ORDER)
end

function DecorationCatalog.has(propId: string): boolean
    return FOOTPRINTS[propId] ~= nil
end

function DecorationCatalog.footprint(propId: string): Footprint?
    return FOOTPRINTS[propId]
end

-- ===== Roblox-only placeholder geometry (art pass later) =====
-- Each builder returns a Model with PrimaryPart set; the caller pivots, tags, and parents it.
-- Parts are anchored + fully non-interactive (the framework overlays its own prompts on the Model).
local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    return p
end

local BUILDERS: { [string]: () -> Model } = {}

BUILDERS.ishidoro = function(): Model
    local STONE = Color3.fromRGB(150, 148, 140)
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local base = part("Base", Vector3.new(1.4, 0.6, 1.4), STONE, Enum.Material.Slate)
    base.CFrame = CFrame.new(0, 0.3, 0)
    base.Parent = m
    local shaft = part("Shaft", Vector3.new(0.5, 1.4, 0.5), STONE, Enum.Material.Slate)
    shaft.CFrame = CFrame.new(0, 1.3, 0)
    shaft.Parent = m
    local head = part("Head", Vector3.new(1.2, 0.8, 1.2), STONE, Enum.Material.Slate)
    head.CFrame = CFrame.new(0, 2.4, 0)
    head.Parent = m
    m.PrimaryPart = shaft
    return m
end

BUILDERS.tsukubai = function(): Model
    local STONE = Color3.fromRGB(150, 148, 140)
    local WATER = Color3.fromRGB(90, 130, 150)
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local basin = part("Basin", Vector3.new(2.6, 1.0, 2.6), STONE, Enum.Material.Slate)
    basin.Shape = Enum.PartType.Cylinder
    basin.CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
    basin.Parent = m
    local water = part("Water", Vector3.new(0.2, 2.0, 2.0), WATER, Enum.Material.Glass)
    water.Shape = Enum.PartType.Cylinder
    water.Transparency = 0.3
    water.CFrame = CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90))
    water.Parent = m
    m.PrimaryPart = basin
    -- ⚠ PivotTo aligns a model by its PrimaryPart's PIVOT, and the basin's CFrame carries the
    -- 90-degree roll that stands the cylinder up -- left alone, placement un-rotates the whole
    -- prop flat on its side (parked defect (l); the mortar tubes shipped with the identical bug
    -- and were fixed the same way at the 2026-09-04 gate, 9d3cd3c). Cancel the basin's own
    -- frame so the model pivot is identity at the model origin.
    basin.PivotOffset = basin.CFrame:Inverse()
    return m
end

BUILDERS.bonsai = function(): Model
    local WOOD = Color3.fromRGB(120, 82, 48)
    local LEAF = Color3.fromRGB(70, 120, 60)
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local pot = part("Pot", Vector3.new(1.1, 0.7, 1.1), WOOD, Enum.Material.WoodPlanks)
    pot.CFrame = CFrame.new(0, 0.35, 0)
    pot.Parent = m
    local foliage = part("Foliage", Vector3.new(1.3, 1.1, 1.3), LEAF, Enum.Material.Grass)
    foliage.Shape = Enum.PartType.Ball
    foliage.CFrame = CFrame.new(0, 1.3, 0)
    foliage.Parent = m
    m.PrimaryPart = pot
    return m
end

BUILDERS.bench = function(): Model
    local WOOD = Color3.fromRGB(120, 82, 48)
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local seat = part("Seat", Vector3.new(4.0, 0.3, 1.4), WOOD, Enum.Material.WoodPlanks)
    seat.CFrame = CFrame.new(0, 1.0, 0)
    seat.Parent = m
    for _, x in { -1.6, 1.6 } do
        local leg = part("Leg", Vector3.new(0.3, 1.0, 1.2), WOOD, Enum.Material.WoodPlanks)
        leg.CFrame = CFrame.new(x, 0.5, 0)
        leg.Parent = m
    end
    m.PrimaryPart = seat
    return m
end

function DecorationCatalog.build(propId: string): Model?
    local builder = BUILDERS[propId]
    if builder == nil then
        return nil
    end
    return builder()
end

return DecorationCatalog
