--!strict
-- buildSkyBackdrop.luau — place the horizon backdrop: a ground plane below the horizon plus two
-- rings of mountain-range MeshParts outside the terrain box. Run via MCP execute_luau (Edit).
-- Writes ONLY Workspace.Sandbox.SkyBackdropTrial (trial home; promote to CanyonWorld once ruled).
--
-- WHY MESHES: two part-built trials (rolled blocks 2026-09-03, then wedge pyramids) read as
-- boxes/triangles. The strips come from roblox/tools/blender/backdrop_ranges.py, imported by the
-- owner with Studio's 3D Importer; MESH_IDS below is what that import minted. Each strip is a
-- normalised 1000 x 500 x 400 height-field (base at the bottom of its bounding box, crest at the
-- top) so THIS file owns the real sizes.
--
-- WHY THESE HEIGHTS: the canyon is a 300-stud-deep gorge and every vantage looks UP at its rim.
-- The wedge trial's crests (near y 400-620, far y 700-1050) sat below the skyline from the
-- suspension bridge — "I can barely see the massifs to the west". So each strip's height is
-- DERIVED: for each vantage in VANTAGES, raycast the terrain skyline angle toward the strip and
-- demand the crest clear it by CLEAR_DEG; the strip takes the max over vantages (skylines above
-- SKYLINE_IGNORE_DEG are cliff faces no backdrop can clear and are skipped). Capped at the
-- engine's 2048-stud part axis.
--
-- Orientation: the near strips carry a foothill apron on their local +Z face (Blender -Y ->
-- FBX/Roblox +Z with the pipeline's axis settings), so each strip is placed with local +Z
-- facing the canyon centre.
--
-- Atmosphere does the rest: distance fades the strips into the sky colour, so they follow the
-- day/night cycle with no code. Lighting is NOT touched here (day-night scope ruling).

local AssetService = game:GetService("AssetService")

-- MeshPart.MeshId read off the parts the 3D Importer created (2026-09-03). NOT the ids the
-- importer reports in its dialog — those are the wrapper assets and fail to load as meshes.
local MESH_IDS: { [string]: string } = {
    RangeNearA = "rbxassetid://103781309355938",
    RangeNearB = "rbxassetid://111609705703999",
    RangeNearC = "rbxassetid://80010923872086",
    RangeFarA = "rbxassetid://119851467306690",
    RangeFarB = "rbxassetid://108093568696221",
    RangeFarC = "rbxassetid://107831693918331",
}

local BOX_X, BOX_Z = 460, 320 -- terrain footprint half-extents
local BOX_MARGIN = 60
local GROUND_TOP_Y = 2
local STRIP_BASE_Y = -6 -- mesh base sits under the ground plane so its zero-height apron is hidden

local ROCK = Color3.fromRGB(36, 52, 30)
local GROUND = Color3.fromRGB(44, 52, 38)

local CLEAR_DEG = 8 -- crest must clear the terrain skyline by this much from every counted vantage
local SKYLINE_IGNORE_DEG = 40 -- steeper than this is a cliff face in front of the vantage; skip
local MAX_AXIS = 2000 -- engine cap is 2048
local VANTAGES: { { name: string, pos: Vector3 } } = {
    { name = "clearing", pos = Vector3.new(0, 118, 0) },
    { name = "southVantage", pos = Vector3.new(125, 192, 94) },
    { name = "switchbackDeck", pos = Vector3.new(159, 138, -66) },
    { name = "suspensionBridge", pos = Vector3.new(-246, 228, 0) },
    { name = "fallsLanding", pos = Vector3.new(-433, 258, -26) },
}

-- ring: ellipse radii, strip count, strip depth (radial), min crest, variants to cycle
type Ring = {
    name: string,
    rx: number,
    rz: number,
    count: number,
    depth: number,
    minCrest: number,
    variants: { string },
    phase: number,
}
local RINGS: { Ring } = {
    {
        name = "NearRange",
        rx = 1150,
        rz = 1000,
        count = 6,
        depth = 900,
        minCrest = 800,
        variants = { "RangeNearA", "RangeNearB", "RangeNearC" },
        phase = 0.0,
    },
    {
        name = "FarRange",
        rx = 2000,
        rz = 1750,
        count = 8,
        depth = 1400,
        minCrest = 1200,
        variants = { "RangeFarA", "RangeFarB", "RangeFarC" },
        phase = 0.5,
    },
}

local terrain = workspace.Terrain
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { terrain }

-- elevation angle (radians) at which a 4000-stud ray from `origin` toward `target` clears terrain
local function skylineAngle(origin: Vector3, target: Vector3): number
    local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z).Unit
    local lo, hi = -0.3, 1.3
    for _ = 1, 18 do
        local mid = (lo + hi) / 2
        local dir = (flat * math.cos(mid) + Vector3.new(0, math.sin(mid), 0)) * 4000
        if workspace:Raycast(origin, dir, terrainParams) then
            lo = mid
        else
            hi = mid
        end
    end
    return hi
end

-- crest height (world y) a strip centred at `centre` needs so every counted vantage sees it
local function requiredCrest(centre: Vector3, floor: number): (number, string)
    local best, who = floor, "floor"
    for _, v in ipairs(VANTAGES) do
        local ang = skylineAngle(v.pos, centre)
        if math.deg(ang) <= SKYLINE_IGNORE_DEG then
            local dist = (Vector3.new(centre.X, 0, centre.Z) - Vector3.new(v.pos.X, 0, v.pos.Z)).Magnitude
            local need = v.pos.Y + math.tan(ang + math.rad(CLEAR_DEG)) * dist
            if need > best then
                best, who = need, v.name
            end
        end
    end
    return math.min(best, MAX_AXIS + STRIP_BASE_Y), who
end

local function style(p: BasePart, color: Color3, mat: Enum.Material)
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Color = color
    p.Material = mat
end

local sandbox = workspace:FindFirstChild("Sandbox") or Instance.new("Folder")
sandbox.Name = "Sandbox"
sandbox.Parent = workspace
local old = sandbox:FindFirstChild("SkyBackdropTrial")
if old then
    old:Destroy()
end

local root = Instance.new("Model")
root.Name = "SkyBackdropTrial"
root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
root.Parent = sandbox

-- 1. Ground plane: 5x5 tiles of 2000 studs, top at GROUND_TOP_Y, so the skybox's bottom face never shows.
local ground = Instance.new("Model")
ground.Name = "Ground"
ground.Parent = root
for i = -2, 2 do
    for j = -2, 2 do
        local p = Instance.new("Part")
        p.Name = ("Tile_%d_%d"):format(i, j)
        p.Size = Vector3.new(2000, 4, 2000)
        p.CFrame = CFrame.new(i * 2000, GROUND_TOP_Y - 2, j * 2000)
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        style(p, GROUND, Enum.Material.Ground)
        p.Parent = ground
    end
end

-- 2. Range rings.
local rng = Random.new(20260903)
local log = {}
local missing = {}
for _, ring in ipairs(RINGS) do
    local m = Instance.new("Model")
    m.Name = ring.name
    m.Parent = root
    -- perimeter estimate (Ramanujan) -> strip length with ~35% overlap for the tapered ends
    local a, b = ring.rx, ring.rz
    local perimeter = math.pi * (3 * (a + b) - math.sqrt((3 * a + b) * (a + 3 * b)))
    local length = math.min(MAX_AXIS, perimeter / ring.count * 1.35)
    for k = 0, ring.count - 1 do
        local variant = ring.variants[(k % #ring.variants) + 1]
        local meshId = MESH_IDS[variant]
        if meshId == "" then
            missing[variant] = true
            continue
        end
        local ang = ((k + ring.phase) / ring.count) * 2 * math.pi + rng:NextNumber(-0.03, 0.03)
        local centre = Vector3.new(math.cos(ang) * ring.rx, 0, math.sin(ang) * ring.rz)
        -- the whole footprint (all four corners of the yawed rectangle) must clear the terrain
        -- box: the diagonal strips' ends swing toward the box corners, so checking only the
        -- inner-edge midpoint left four near strips over the rims (2026-09-03)
        local radial = Vector3.new(centre.X, 0, centre.Z).Unit
        local tangent = Vector3.new(-radial.Z, 0, radial.X)
        local function intrudes(c: Vector3): boolean
            for _, sx in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    local corner = c + tangent * (sx * length / 2) + radial * (sz * ring.depth / 2)
                    if
                        math.abs(corner.X) < BOX_X + BOX_MARGIN
                        and math.abs(corner.Z) < BOX_Z + BOX_MARGIN
                    then
                        return true
                    end
                end
            end
            return false
        end
        local pushed = 0
        while intrudes(centre) and pushed < 2000 do
            centre += radial * 25
            pushed += 25
        end
        local crest, who = requiredCrest(centre, ring.minCrest)
        local height = crest - STRIP_BASE_Y
        local part = AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
            CollisionFidelity = Enum.CollisionFidelity.Box,
            RenderFidelity = Enum.RenderFidelity.Automatic,
        })
        part.Name = ("%s_%02d_%s"):format(ring.name, k, variant)
        part.TextureID = ""
        part.Size = Vector3.new(length, height, ring.depth)
        -- local +Z faces the canyon centre (foothill apron toward the players); tangent along X
        local pos = Vector3.new(centre.X, STRIP_BASE_Y + height / 2, centre.Z)
        part.CFrame = CFrame.lookAt(pos, pos + radial) -- LookVector (-Z) points outward, so +Z faces in
        local d = rng:NextNumber(-0.03, 0.03)
        style(
            part,
            Color3.new(
                math.clamp(ROCK.R + d, 0, 1),
                math.clamp(ROCK.G + d * 1.2, 0, 1),
                math.clamp(ROCK.B + d, 0, 1)
            ),
            Enum.Material.Slate
        )
        part:SetAttribute("CrestY", math.round(crest))
        part:SetAttribute("CrestDrivenBy", who)
        part.Parent = m
        table.insert(
            log,
            ("%s crest=%d (%s) len=%d"):format(part.Name, math.round(crest), who, math.round(length))
        )
    end
end

local missingList = {}
for k in pairs(missing) do
    table.insert(missingList, k)
end
table.sort(missingList)
return ("built %s\n%s\nmissing mesh ids: %s"):format(
    root:GetFullName(),
    table.concat(log, "\n"),
    #missingList == 0 and "none" or table.concat(missingList, ", ")
)
