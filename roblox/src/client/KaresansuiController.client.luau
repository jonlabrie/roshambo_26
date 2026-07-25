--!strict
-- Builds the karesansui ripple rings around every KaresansuiIsland-tagged rock at
-- boot (EditableMesh doesn't replicate and Rojo JSON can't carry mesh geometry —
-- the CamMesh pattern). Move/add/remove a tagged boulder in Studio and the rings
-- follow on the next Play; no code edits. Rings are VISUAL ONLY (spec).
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local RakingMesh = require(shared:WaitForChild("RakingMesh"))

local stage = workspace:WaitForChild("RoshamboStage")
local garden = stage:WaitForChild("Karesansui")

local SEGMENTS = 96 -- solid disc: fine segments keep the circles round up close
local PITCH = 0.35 -- ring spacing (gate-tuned tighter than the field rows)
local AMPLITUDE = 0.15
local SOFT = 0.5 -- crest softness: 0 hard-faceted V, 1 fully smooth (gate knob)
local RING_BAND = 3.2 -- ripple field extends this far beyond the island footprint
local FOOT_TUCK = 0.7 -- rings start under the stone's overhang: the axis-aligned
-- footprint overestimates rotated/irregular rocks, and rings should touch the stone

-- re-tagging an island in Studio refreshes its rings instead of stacking duplicates
local built: { [BasePart]: BasePart } = {}

local function buildRings(island: BasePart)
    local old = built[island]
    if old then
        old:Destroy()
        built[island] = nil
    end
    -- per-stone override: set a RingFootprintR number attribute on an island to
    -- pin its inner ring radius exactly (elongated rocks defeat the axis-aligned guess)
    local footprintR = (island:GetAttribute("RingFootprintR") :: number?)
        or math.max(island.Size.X, island.Size.Z) / 2 * FOOT_TUCK
    local g = {
        footprintR = footprintR,
        maxR = footprintR + RING_BAND,
        pitch = PITCH,
        amplitude = AMPLITUDE,
        soft = SOFT,
    }
    local ok, err = pcall(function()
        local m = RakingMesh.build(g, SEGMENTS)
        local em = AssetService:CreateEditableMesh()
        local vids, nids = table.create(#m.verts), table.create(#m.normals)
        for i, v in m.verts do
            vids[i] = em:AddVertex(Vector3.new(v[1], v[2], v[3]))
            nids[i] = em:AddNormal(Vector3.new(m.normals[i][1], m.normals[i][2], m.normals[i][3]))
        end
        for _, t in m.tris do
            local f = em:AddTriangle(vids[t[1]], vids[t[2]], vids[t[3]])
            em:SetFaceNormals(f, { nids[t[1]], nids[t[2]], nids[t[3]] })
        end
        local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
        part.Name = "RakingRings"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Sand
        part.MaterialVariant = "RakedGravelRings" -- gravel color/roughness, NO normal
        -- map (the rings' real ridges do the relief); triplanar, so it matches the
        -- field's material in world space. Tint MUST match the Field slabs' part
        -- color — part color multiplies the ColorMap, and the field is tinted.
        part.Color = Color3.new(0.87, 0.85, 0.79)
        -- rings lie flat on the field slab the island stands in — read the slab's
        -- actual top so per-panel floor heights need no mirrored constant here
        local ringY: number? = nil
        for _, f in garden:GetChildren() do
            if f:IsA("BasePart") and f.Name:match("^Field") then
                local dx = math.abs(island.Position.X - f.Position.X)
                local dz = math.abs(island.Position.Z - f.Position.Z)
                if dx <= f.Size.X / 2 and dz <= f.Size.Z / 2 then
                    ringY = f.Position.Y + f.Size.Y / 2 - 0.05 -- sunk slightly: crests ride ~0.1 proud
                    break
                end
            end
        end
        assert(ringY, "island stands on no Field slab — tag only rocks inside the garden panels")
        part.CFrame = CFrame.new(island.Position.X, ringY, island.Position.Z)
        part.Parent = garden
        built[island] = part
    end)
    if not ok then
        warn(`[KARESANSUI] rings skipped for {island:GetFullName()}: {err}`)
    end
end

for _, island in CollectionService:GetTagged("KaresansuiIsland") do
    if island:IsA("BasePart") then
        buildRings(island)
    end
end
CollectionService:GetInstanceAddedSignal("KaresansuiIsland"):Connect(function(inst)
    if inst:IsA("BasePart") then
        buildRings(inst)
    end
end)
