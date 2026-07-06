--!strict
-- Visual gate for the Structure builder: materialize a sample loadout onto two
-- hand-placed mounts (right + left) from the captured base prefab. Run via MCP
-- execute_luau (datamodel Edit) or the Studio command bar.
--
-- MCP Studio scripts cannot `require` repo modules, so the `ops` adapter and the
-- resolved `plan` are INLINED here (a deliberate mirror, like buildPaths.luau
-- mirrors CanyonPath). The real logic — StructurePlanner/StructureBuilder — is
-- Lune-tested in src/shared; this script only proves the geometry/tags look right.
-- The sample plan below equals StructurePlanner.plan for:
--   loadout = { baseStyle="teahouse-1story", colorScheme="scheme.vermilion",
--               shoji={ [2]="shoji.crane" }, tatami="tatami.gold" }
-- Placeholder texture asset ids won't render a real image; the visible proofs are
-- the recolor (vermilion) and — critically — the left-hand mirror (side shoji
-- face the veranda, SideWall on the cliff side).

local SS = game:GetService("ServerStorage")

local function recolorRole(m: Model, role: string, rgb: { number })
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("Role_" .. role) then
            p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
        end
    end
end

local function setTexture(m: Model, target: string, assetId: string)
    if target == "Tatami" then
        for _, p in m:GetDescendants() do
            if p:HasTag("Tatami") then
                local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal")
                d.Face = Enum.NormalId.Top
                d.Texture = assetId
                d.Parent = p
            end
        end
    else
        local bay = tonumber(target:match("ShojiBay:(%d+)"))
        for _, p in m:GetDescendants() do
            if p:HasTag("ShojiBay") and p:GetAttribute("Bay") == bay then
                local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal")
                d.Face = Enum.NormalId.Front
                d.Texture = assetId
                d.Parent = p
            end
        end
    end
end

local function mirrorX(m: Model)
    local piv = m:GetPivot()
    -- axis-aligned tagged parts: negate local X (position), keep rotation
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("MirrorX") then
            local lc = piv:ToObjectSpace(p.CFrame)
            local rot = lc - lc.Position
            p.CFrame = piv * (CFrame.new(-lc.Position.X, lc.Position.Y, lc.Position.Z) * rot)
        end
    end
    -- grouped sub-assemblies (the chochin): rigid-relocate the whole model to the
    -- mirrored corner, preserving orientation (no internal reflection)
    for _, d in m:GetDescendants() do
        if d:IsA("Model") and d:HasTag("MirrorXRigid") then
            local lc = piv:ToObjectSpace(d:GetPivot())
            d:PivotTo(piv * CFrame.new(-lc.Position.X, lc.Position.Y, lc.Position.Z) * (lc - lc.Position))
        end
    end
end

local function apply(m: Model, hand: string)
    if hand == "left" then
        mirrorX(m)
    end
    recolorRole(m, "timber", { 120, 45, 35 })
    recolorRole(m, "wall", { 232, 216, 190 })
    recolorRole(m, "roof", { 40, 42, 48 })
    recolorRole(m, "cap", { 40, 42, 48 })
    setTexture(m, "ShojiBay:2", "rbxassetid://102000000001")
    setTexture(m, "Tatami", "rbxassetid://102000000011")
end

local function run()
    local prefab = SS.StructurePrefabs["teahouse-1story"]
    local demo = workspace:FindFirstChild("StructureDemo")
    if demo then
        demo:Destroy()
    end
    demo = Instance.new("Folder")
    demo.Name = "StructureDemo"
    demo.Parent = workspace

    local base = workspace.TeahousePrototype:GetPivot().Position + Vector3.new(110, 6, 0)
    local mounts = {
        { hand = "right", cf = CFrame.new(base) },
        { hand = "left", cf = CFrame.new(base + Vector3.new(60, 0, 0)) },
    }
    for _, mt in mounts do
        local m = prefab:Clone()
        m.Parent = demo
        apply(m, mt.hand)
        m:PivotTo(mt.cf) -- snap datum -> mount
    end
    return demo
end

return run()
