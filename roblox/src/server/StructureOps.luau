--!strict
-- Runtime `ops` adapter for A's StructureBuilder (injected in main.server.luau).
-- recolor/setTexture/mirrorX are productionized verbatim from the throwaway
-- tools/studio/materializeStructureDemo.luau; readManifest/clonePrefab/pivotTo are new.
-- Roblox datatypes -> not Lune-testable; proven by the D.1 visual gate.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local StructureOps = {}

function StructureOps.clonePrefab(baseStyle: string): Model
    return (ServerStorage:FindFirstChild("StructurePrefabs") :: Folder)
            :FindFirstChild(baseStyle)
            :Clone() :: Model
end

function StructureOps.readManifest(model: Model): any
    local roleSet: { [string]: boolean } = {}
    local shojiSet: { [number]: boolean } = {}
    local flagSet: { [string]: boolean } = {}
    local hasTatami = false
    for _, d in model:GetDescendants() do
        for _, tag in CollectionService:GetTags(d) do
            local role = string.match(tag, "^Role_(.+)$")
            if role then
                roleSet[role] = true
            elseif tag == "ShojiBay" then
                local bay = d:GetAttribute("Bay")
                if typeof(bay) == "number" then
                    shojiSet[bay] = true
                end
            elseif tag == "Tatami" then
                hasTatami = true
            elseif string.match(tag, "^FlagMount") then
                flagSet[tag] = true
            end
        end
    end
    local roles, shojiBays, flagMounts = {}, {}, {}
    for r in roleSet do
        table.insert(roles, r)
    end
    for b in shojiSet do
        table.insert(shojiBays, b)
    end
    for fm in flagSet do
        table.insert(flagMounts, fm)
    end
    return { roles = roles, shojiBays = shojiBays, hasTatami = hasTatami, flagMounts = flagMounts }
end

function StructureOps.mirrorX(m: Model)
    local piv = m:GetPivot()
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("MirrorX") then
            local lc = piv:ToObjectSpace(p.CFrame)
            local rot = lc - lc.Position
            p.CFrame = piv * (CFrame.new(-lc.Position.X, lc.Position.Y, lc.Position.Z) * rot)
        end
    end
    for _, d in m:GetDescendants() do
        if d:IsA("Model") and d:HasTag("MirrorXRigid") then
            local lc = piv:ToObjectSpace(d:GetPivot())
            d:PivotTo(piv * CFrame.new(-lc.Position.X, lc.Position.Y, lc.Position.Z) * (lc - lc.Position))
        end
    end
end

function StructureOps.recolor(m: Model, role: string, rgb: { number })
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("Role_" .. role) then
            p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
        end
    end
end

function StructureOps.setTexture(m: Model, target: string, assetId: string)
    if target == "Tatami" then
        for _, p in m:GetDescendants() do
            if p:HasTag("Tatami") then
                -- selene: allow(deprecated)
                local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal", p)
                d.Face = Enum.NormalId.Top
                d.Texture = assetId
            end
        end
    else
        local bay = tonumber(target:match("ShojiBay:(%d+)"))
        for _, p in m:GetDescendants() do
            if p:HasTag("ShojiBay") and p:GetAttribute("Bay") == bay then
                -- selene: allow(deprecated)
                local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal", p)
                d.Face = Enum.NormalId.Front
                d.Texture = assetId
            end
        end
    end
end

function StructureOps.attachPrefab(_m: Model, mount: string, prefabId: string)
    -- Flags/attachments are out of D.1 scope (seeded loadout carries none). A real
    -- implementation clones ServerStorage.StructureComponents[prefabId] to the named
    -- anchor; deferred until component prefabs + the economy catalog exist.
    warn(`[StructureOps] attachPrefab not implemented in D.1 (mount={mount}, prefab={prefabId})`)
end

function StructureOps.pivotTo(m: Model, cf12: { number })
    m:PivotTo(CFrame.new(table.unpack(cf12)))
end

return StructureOps
