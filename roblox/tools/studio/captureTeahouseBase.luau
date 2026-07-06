--!strict
-- Capture the perfected canyon TeahousePrototype into the portable base prefab
-- `ServerStorage.StructurePrefabs.teahouse-1story` used by the Structure builder
-- (StructureBuilder / StructurePlanner in src/shared). Run via MCP execute_luau
-- (datamodel Edit) or paste into a Studio command bar. Idempotent: re-running
-- rebuilds the prefab from the current TeahousePrototype.
--
-- What it authors (the slot manifest StructureBuilder.readManifest expects):
--   * strips the 6 EngawaPost support posts (below the datum = the PAD's job)
--   * datum = the EngawaSupport frame underside (local Y ~= 105.80); pivot set to
--     the frame-underside centre, front = veranda (-Z), so PivotTo(mount) places+orients
--   * Role_timber/wall/roof/cap tags for recolor
--   * MirrorX tags on the parts that negate-X for a left-hand build (engawa assembly,
--     koran, understructure, side shoji+glow+mull, SideWall) — the set that fixes the
--     left-hand shoji/SideWall bug; roof/gables/front stay untagged
--   * MirrorXRigid tag on the ChochinSwing sub-assembly (a grouped lantern) so the
--     mirror rigid-relocates it to the opposite corner rather than reflecting it internally
--   * ShojiBay tag + Bay attribute (1..3) on the front shoji panels
--   * Tatami tag on the mat; FlagMount_1/FlagMount_2 attachments on PerimF
-- Prefab is place-only (save the place after); committing a .rbxmx is a follow-up.

local SS = game:GetService("ServerStorage")

local function capture()
    local src = workspace:FindFirstChild("TeahousePrototype")
    assert(src, "TeahousePrototype not found in workspace")
    local folder = SS:FindFirstChild("StructurePrefabs") or Instance.new("Folder")
    folder.Name = "StructurePrefabs"
    folder.Parent = SS
    local existing = folder:FindFirstChild("teahouse-1story")
    if existing then
        existing:Destroy()
    end

    local m = src:Clone()
    m.Name = "teahouse-1story"
    -- 1) strip the pad's job: the terrain-raycasting support posts
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p.Name == "EngawaPost" then
            p:Destroy()
        end
    end
    m.Parent = folder

    -- 2) datum = frame underside; author the model pivot there, facing the veranda (-Z)
    local piv = m:GetPivot()
    local y0 = math.huge
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p.Name:match("^Perim") then
            y0 = math.min(y0, piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2)
        end
    end
    local below = {}
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") then
            local lb = piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2
            if lb < y0 - 0.01 then
                table.insert(below, p.Name)
            end
        end
    end
    assert(#below == 0, "parts below the datum (Y0) are the pad's job: " .. table.concat(below, ","))
    local posW = piv:PointToWorldSpace(Vector3.new(0, y0, 0))
    local frontW = piv:VectorToWorldSpace(Vector3.new(0, 0, -1))
    m.WorldPivot = CFrame.lookAt(posW, posW + frontW, Vector3.yAxis)
    piv = m:GetPivot()

    -- 3) manifest tags
    local ROLE = {
        Girder = "timber",
        RafterTail = "timber",
        Newel = "timber",
        Baluster = "timber",
        BackWall = "wall",
        SideWall = "wall",
        Shoji = "wall",
        RoofF = "roof",
        RoofB = "roof",
        GableA = "roof",
        GableB = "roof",
        RailCap = "cap",
        PerimF = "cap",
        PerimB = "cap",
        PerimL = "cap",
        PerimR = "cap",
        Joist = "cap",
    }
    local MIRROR = {
        EngawaF = true,
        EngawaS = true,
        RailCap = true,
        RailMid = true,
        Newel = true,
        Baluster = true,
        PerimF = true,
        PerimB = true,
        PerimL = true,
        PerimR = true,
        Joist = true,
        SideWall = true,
    }
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") then
            if ROLE[p.Name] then
                p:AddTag("Role_" .. ROLE[p.Name])
            end
            local sideShoji = (p.Name == "Shoji" or p.Name == "ShojiGlow" or p.Name == "Mull")
                and p.Size.Z > p.Size.X
            if MIRROR[p.Name] or sideShoji then
                p:AddTag("MirrorX")
            end
            if p.Name == "Shoji" and p.Size.X > p.Size.Z then
                local lx = piv:ToObjectSpace(p.CFrame).Position.X
                local bay = ({ [-6] = 1, [0] = 2, [6] = 3 })[math.floor(lx + 0.5)] or 0
                p:AddTag("ShojiBay")
                p:SetAttribute("Bay", bay)
            end
            if p.Name == "Tatami" then
                p:AddTag("Tatami")
            end
        end
    end

    -- 3b) the chochin is a grouped sub-assembly (ChochinSwing) whose part names are not in
    -- the MIRROR set; tag the whole model MirrorXRigid so the mirror relocates it rigidly
    -- to the opposite corner (no internal reflection — a lantern must not be left/right flipped)
    for _, d in m:GetDescendants() do
        if d:IsA("Model") and d.Name == "ChochinSwing" then
            d:AddTag("MirrorXRigid")
        end
    end

    -- 4) flag-mount attachments on the front beam
    local host
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p.Name == "PerimF" then
            host = p
        end
    end
    assert(host, "PerimF host not found")
    for name, lp in { FlagMount_1 = Vector3.new(-9, 12, -13), FlagMount_2 = Vector3.new(15, 12, -13) } do
        local a = Instance.new("Attachment")
        a.Name = name
        a.WorldCFrame = piv * CFrame.new(lp)
        a.Parent = host
    end

    return m
end

return capture()
