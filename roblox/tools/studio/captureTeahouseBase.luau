--!strict
-- Capture the bay-structured `TeahousePrototype` into the portable base prefab
-- `ServerStorage.StructurePrefabs.teahouse-1story` used by the Structure builder
-- (StructureBuilder / StructurePlanner / StructureOps in src). Run via MCP execute_luau
-- (datamodel Edit) or paste into a Studio command bar. Idempotent: re-running rebuilds
-- the prefab from the current TeahousePrototype.
--
-- Source: an SP1 modular teahouse in Workspace as `TeahousePrototype` (10 `Bay_<side>_<index>`
-- models, each with `Solid` / `Shoji` / `Door` child models, on a floor-datumed building).
--
-- SP1 MODULAR BAYS (2026-07-12): the whole-building mirror is retired; "which side is open"
-- is now a per-bay state (solid | shoji | door) resolved from the loadout `wallBays` map.
-- The building is already deck-free (the pad/PadBuilder owns the deck) and floor-datumed
-- (floor at local y = 0, seats on the procedural deck top), so this capture no longer strips
-- a deck or re-datums — it clones the source and applies the manifest tags the runtime reads:
--   * Bay tag + Side / Index / GrooveDepth attributes on every `Bay_<side>_<index>` model,
--     so StructureOps.readManifest can enumerate bays and applyBays can address them.
--   * Role_wall (Solid panels + Shoji paper), Role_roof (RoofF/RoofB/Gable), Role_timber
--     (RafterTail) for recolor. The black shoji frame/kumiko and the timber track/posts are
--     deliberately left untagged so they keep their authored colour across schemes.
--   * ShojiBay tag + Bay attribute (1..3) on the FRONT bays' shoji paper (texturing hook;
--     front-only for SP1).
--   * Tatami tag on the mat fields.
--   * FlagMount_1/FlagMount_2 attachments on a corner WallPost at eave height (dormant;
--     kept for forward-compat with the flag attachment system).
-- No MirrorX / MirrorXRigid tags (the mirror is gone). Prefab is place-only (save the place
-- after running); committing a .rbxmx is a follow-up.

local SS = game:GetService("ServerStorage")

-- manifest recolor roles, by part name (asserted here so the prefab's roles are guaranteed by
-- the tool regardless of what the source clone carried)
local ROLE = {
    Panel = "wall", -- solid bay infill
    Shoji = "wall", -- shoji paper (legacy: shoji recolours with the wall role)
    RoofF = "roof",
    RoofB = "roof",
    GableA = "roof",
    GableB = "roof",
    RafterTail = "timber",
}

local function capture()
    local src = workspace:FindFirstChild("TeahousePrototype")
    assert(src, "TeahousePrototype not found in workspace")

    -- sanity: the source must be the SP1 bay-structured teahouse (10 Bay_<side>_<index> models)
    local bays = {}
    for _, c in src:GetChildren() do
        if c:IsA("Model") and c.Name:match("^Bay_%a+_%d+$") then
            table.insert(bays, c)
        end
    end
    assert(#bays == 10, "expected 10 Bay_* models in TeahousePrototype, found " .. #bays)

    local folder = SS:FindFirstChild("StructurePrefabs") or Instance.new("Folder")
    folder.Name = "StructurePrefabs"
    folder.Parent = SS
    local existing = folder:FindFirstChild("teahouse-1story")
    if existing then
        existing:Destroy()
    end

    local m = src:Clone()
    m.Name = "teahouse-1story"
    m.Parent = folder
    local piv = m:GetPivot()

    -- datum sanity: the building floor (Solid panel base) must sit at local y = 0 so it seats on
    -- the procedural deck top. The source is authored that way; this only guards against drift.
    local floorY = math.huge
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p.Name == "Panel" then
            floorY = math.min(floorY, piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2)
        end
    end
    assert(floorY < math.huge, "no Solid Panel found for the floor datum")
    assert(math.abs(floorY) < 0.05, string.format("building floor not at y=0 (got %.3f)", floorY))

    -- 1) roles + tatami by part name (idempotent)
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") then
            if ROLE[p.Name] then
                p:AddTag("Role_" .. ROLE[p.Name])
            end
            if p.Name == "Tatami" then
                p:AddTag("Tatami")
            end
        end
    end

    -- 2) tag every bay model so the runtime can enumerate + address it
    for _, c in m:GetChildren() do
        local side, idx = c.Name:match("^Bay_(%a+)_(%d+)$")
        if c:IsA("Model") and side then
            c:AddTag("Bay")
            c:SetAttribute("Side", side)
            c:SetAttribute("Index", tonumber(idx))
            c:SetAttribute("GrooveDepth", c:GetAttribute("GrooveDepth") or 0)
        end
    end

    -- 3) ShojiBay + Bay attribute on the FRONT bays' shoji paper (texturing hook; front-only)
    for _, c in m:GetChildren() do
        local idx = c.Name:match("^Bay_front_(%d+)$")
        if c:IsA("Model") and idx then
            local shoji = c:FindFirstChild("Shoji")
            if shoji then
                for _, p in shoji:GetChildren() do
                    if p:IsA("BasePart") and p.Name == "Shoji" then
                        p:AddTag("ShojiBay")
                        p:SetAttribute("Bay", tonumber(idx))
                    end
                end
            end
        end
    end

    -- 4) flag mounts (dormant): two attachments on a corner WallPost at eave height, kept for
    --    forward-compat with the flag attachment system. Clear any inherited from the source
    --    clone first so re-running does not accumulate duplicates.
    for _, d in m:GetDescendants() do
        if d:IsA("Attachment") and d.Name:match("^FlagMount") then
            d:Destroy()
        end
    end
    local host
    for _, p in m:GetChildren() do
        if p:IsA("BasePart") and p.Name == "WallPost" then
            host = p
            break
        end
    end
    if host then
        for name, lp in { FlagMount_1 = Vector3.new(-9, 11, -5.68), FlagMount_2 = Vector3.new(9, 11, -5.68) } do
            local a = Instance.new("Attachment")
            a.Name = name
            a.WorldCFrame = piv * CFrame.new(lp)
            a.Parent = host
        end
    end

    return m
end

return capture()
