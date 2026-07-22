--!strict
-- Rebuilds the Shōrō eave-skirt roof as reusable trapezoid MeshParts around the tower:
--   • 4 SLATE top panels  — a single uploaded trapezoid mesh instanced 4× (rotated 90° about
--     the tower centre), dressed with a SurfaceAppearance mapped by UPSLOPE UVs so the kawara
--     courses up each face (a world-space MaterialVariant runs cross-grain on two of four sides,
--     and WedgeParts tiled inconsistently across a hip — hence a mesh).
--   • 4 CYPRESS soffit panels — the SAME mesh, cypress MaterialVariant, dropped `DROP` studs
--     below the slate so the underside reads cypress (a MeshPart is single-material, so the
--     soffit MUST be a separate part).
--   • 4 CYPRESS fascia boards — thin boxes closing the `DROP` gap at each eave, so the edge
--     reads as a solid cypress eave board instead of two zero-thickness knife-edges. Outer face
--     kept flush with the eave (RErf).
--
-- PIPELINE (why the slate panel is a real MeshId, not an EditableMesh):
--   EditableMesh geometry does NOT serialize into a .rbxm (empty MeshId → 1-stud cube in
--   Edit + Play). So the trapezoid is UPLOADED once for a real asset id, and the panels are
--   built with AssetService:CreateMeshPartAsync(<that MeshId>) — those DO serialize. The upload
--   uses AS:CreateAssetAsync(editableMesh, Enum.AssetType.Mesh, params) — pass the EditableMesh
--   OBJECT directly (NOT Content.fromObject(em), which errors "Unable to cast value to Object").
--
-- CURRENT ASSET:  MeshId 98384801935296  (T = 7.5 studs/tile — gate-approved kawara size)
--
-- TO RE-TILE (change T): flip REUPLOAD = true, edit T, run → it uploads a new mesh and prints
-- the new id; paste it into MESHID below, set REUPLOAD = false, and re-run to build the panels.
--
-- RUN IN STUDIO (Edit) → produces `workspace.ShoroRoof` (Model of 12 parts) → right-click it →
-- Save to File → `roblox/assets/meshes/ShoroRoof.rbxm`. Referenced under RoshamboStage in
-- default.project.json. Corner coords match Shoro.luau's roof (eaveWY 134, RErf 17.55,
-- RInner 10.1525, yaw 0); if those change there, reprint them (ROOFPTS debug) and update below.
local AS = game:GetService("AssetService")

local REUPLOAD = false
local MESHID = "rbxassetid://98384801935296"
local T = 7.5 -- studs per tile; only used when REUPLOAD (baked into the uploaded UVs)

local DROP = 0.45 -- cypress soffit sits this far below the slate (= visible eave-band depth)
local FASCIA_D = 0.2 -- fascia board depth (thin)
local EAVE_Y = 134.0 -- slate eave edge Y (world)
local EAVE_Z = 17.55 -- outer eave radius RErf (world Z of the +Z-face eave)
local EAVE_X0, EAVE_X1 = -19.55, 15.55 -- +Z-face eave span (world X)

local centroid = Vector3.new(-2, 135.232915, 13.85125) -- +Z face bbox centre (rotation ref x/z = -2,0)
-- +Z face corners in WORLD coords (from the Shoro builder), made LOCAL by subtracting centroid
local eaveL = Vector3.new(-19.55, 134, 17.55) - centroid
local eaveR = Vector3.new(15.55, 134, 17.55) - centroid
local innerR = Vector3.new(8.1525, 136.46583, 10.1525) - centroid
local innerL = Vector3.new(-12.1525, 136.46583, 10.1525) - centroid

local SLATE = { -- RoofingTiles013A (same maps behind the SlateTile MaterialVariant)
    color = "rbxassetid://118941425684741",
    normal = "rbxassetid://91580065572768",
    rough = "rbxassetid://134921240678362",
}
local CYP = Color3.new(0.85, 0.84, 0.81) -- ZenDojo palette cypressWeathered

if REUPLOAD then
    local Uax = (eaveR - eaveL).Unit
    local eaveMid, innerMid = (eaveL + eaveR) / 2, (innerL + innerR) / 2
    local Vax = (innerMid - eaveMid).Unit
    local function uv(p: Vector3): Vector2
        return Vector2.new((p - eaveL):Dot(Uax) / T, (p - eaveL):Dot(Vax) / T)
    end
    local nrm = (eaveR - eaveL):Cross(innerL - eaveL).Unit
    if nrm.Y < 0 then
        nrm = -nrm
    end
    local em = AS:CreateEditableMesh()
    local vL, vR, viR, viL =
        em:AddVertex(eaveL), em:AddVertex(eaveR), em:AddVertex(innerR), em:AddVertex(innerL)
    local uL, uR, uiR, uiL =
        em:AddUV(uv(eaveL)), em:AddUV(uv(eaveR)), em:AddUV(uv(innerR)), em:AddUV(uv(innerL))
    local nn = em:AddNormal(nrm)
    local f1, f2 = em:AddTriangle(vL, vR, viR), em:AddTriangle(vL, viR, viL)
    em:SetFaceUVs(f1, { uL, uR, uiR })
    em:SetFaceUVs(f2, { uL, uiR, uiL })
    em:SetFaceNormals(f1, { nn, nn, nn })
    em:SetFaceNormals(f2, { nn, nn, nn })
    local ok, res, id = pcall(function()
        return AS:CreateAssetAsync(
            em,
            Enum.AssetType.Mesh,
            { Name = "ShoroRoofPanel", Description = "Shoro slate roof panel" }
        )
    end)
    if not ok or res ~= Enum.CreateAssetResult.Success then
        return "UPLOAD FAILED: ok=" .. tostring(ok) .. " res=" .. tostring(res) .. " id=" .. tostring(id)
    end
    return "UPLOADED new panel MeshId="
        .. tostring(id)
        .. " — paste into MESHID, set REUPLOAD=false, re-run"
end

-- rotate a base part's CFrame to face k (0..3), about the tower centre (-2,0)
local function faceCF(baseCF: CFrame, k: number): CFrame
    if k == 0 then
        return baseCF
    end
    return CFrame.new(-2, 0, 0) * CFrame.Angles(0, math.rad(90 * k), 0) * CFrame.new(2, 0, 0) * baseCF
end
local function meshPanel(name: string): MeshPart
    local p = AS:CreateMeshPartAsync(Content.fromUri(MESHID), {
        CollisionFidelity = Enum.CollisionFidelity.Box,
        RenderFidelity = Enum.RenderFidelity.Automatic,
    })
    p.Name = name
    p.Anchored = true
    p.DoubleSided = true
    p.TextureID = ""
    return p
end

local old = workspace:FindFirstChild("ShoroRoof")
if old then
    old:Destroy()
end
local model = Instance.new("Model")
model.Name = "ShoroRoof"

-- 4 slate top panels
local slateBase: MeshPart? = nil
for k = 0, 3 do
    local p = meshPanel("RoofPanel" .. (k + 1))
    p.Material = Enum.Material.Slate
    p.Color = Color3.fromRGB(210, 210, 204)
    local sa = Instance.new("SurfaceAppearance")
    sa.ColorMap = SLATE.color
    sa.NormalMap = SLATE.normal
    sa.RoughnessMap = SLATE.rough
    sa.Parent = p
    p.CFrame = faceCF(CFrame.new(centroid), k)
    p.Parent = model
    if k == 0 then
        slateBase = p
    end
end

-- 4 cypress soffit panels (same mesh, dropped straight down)
for k = 0, 3 do
    local p = meshPanel("RoofSoffit" .. (k + 1))
    p.Material = Enum.Material.Wood
    p.Color = CYP
    p.MaterialVariant = "CypressWeathered"
    p.CFrame = faceCF(CFrame.new(centroid - Vector3.new(0, DROP, 0)), k)
    p.Parent = model
end

-- 4 cypress fascia boards closing the DROP gap at each eave; outer face flush at EAVE_Z
local span = EAVE_X1 - EAVE_X0
local cx = (EAVE_X0 + EAVE_X1) / 2
local fasciaBase = CFrame.new(cx, EAVE_Y - DROP / 2, EAVE_Z - FASCIA_D / 2)
for k = 0, 3 do
    local b = Instance.new("Part")
    b.Name = "Fascia" .. (k + 1)
    b.Anchored = true
    b.TopSurface = Enum.SurfaceType.Smooth
    b.BottomSurface = Enum.SurfaceType.Smooth
    b.Size = Vector3.new(span, DROP, FASCIA_D)
    b.Material = Enum.Material.Wood
    b.Color = CYP
    b.MaterialVariant = "CypressWeathered"
    b.CFrame = faceCF(fasciaBase, k)
    b.Parent = model
end

model.PrimaryPart = slateBase
model.Parent = workspace
return "ShoroRoof built (4 slate + 4 soffit + 4 fascia) from MeshId "
    .. MESHID
    .. " — Save to File → assets/meshes/ShoroRoof.rbxm"
