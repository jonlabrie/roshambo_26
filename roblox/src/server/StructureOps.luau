--!strict
-- Runtime `ops` adapter for A's StructureBuilder (injected in main.server.luau).
-- recolor/setTexture are productionized verbatim from the throwaway
-- tools/studio/materializeStructureDemo.luau; readManifest/clonePrefab/pivotTo/applyBays are new.
-- Roblox datatypes -> not Lune-testable; proven by the D.1 visual gate.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ShojiRun = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("ShojiRun"))

local StructureOps = {}

function StructureOps.clonePrefab(prefabName: string): Model
    local prefabs = ServerStorage:FindFirstChild("StructurePrefabs")
    local prefab = prefabs and prefabs:FindFirstChild(prefabName)
    if not prefab then
        error(`StructureOps.clonePrefab: no prefab named '{prefabName}' under ServerStorage.StructurePrefabs`)
    end
    return prefab:Clone() :: Model
end

function StructureOps.readManifest(model: Model): any
    local roleSet: { [string]: boolean } = {}
    local shojiSet: { [number]: boolean } = {}
    local flagSet: { [string]: boolean } = {}
    local hasTatami = false
    local bays: { { side: string, index: number } } = {}
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
            elseif tag == "Bay" then
                local side = d:GetAttribute("Side")
                local index = d:GetAttribute("Index")
                if typeof(side) == "string" and typeof(index) == "number" then
                    table.insert(bays, { side = side, index = index })
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
    return {
        roles = roles,
        shojiBays = shojiBays,
        hasTatami = hasTatami,
        flagMounts = flagMounts,
        bays = bays,
    }
end

-- Show each bay's chosen variant (Solid/Shoji/Door) and hide the other two. Variant models are
-- named after their state (capitalised); each authored part carries a ShownTransparency attribute.
-- Shown parts restore that transparency and collide iff visible (the neon ShojiGlow stays
-- transparent + non-colliding); hidden parts go fully transparent + non-colliding so players
-- cannot hit an invisible wall. A missing bay model / state / variant warns and is skipped so the
-- bay keeps its authored default rather than being blanked (F2/F4).
local STATE_VARIANT = { solid = "Solid", shoji = "Shoji", door = "Door" }
function StructureOps.applyBays(model: Model, bays: { { side: string, index: number, state: string } })
    local byName: { [string]: Model } = {}
    for _, c in model:GetChildren() do
        if c:IsA("Model") and c.Name:match("^Bay_%a+_%d+$") then
            byName[c.Name] = c
        end
    end
    for _, b in bays do
        local bayName = `Bay_{b.side}_{b.index}`
        local bay = byName[bayName]
        local shownName = STATE_VARIANT[b.state]
        local shownModel = if bay and shownName then bay:FindFirstChild(shownName) else nil
        if not bay then
            warn(`[StructureOps] applyBays: no bay model '{bayName}'`)
        elseif not shownName then
            warn(`[StructureOps] applyBays: unknown state '{b.state}' for '{bayName}'`)
        elseif not shownModel then
            warn(`[StructureOps] applyBays: bay '{bayName}' missing '{shownName}' variant`)
        else
            for _, variant in bay:GetChildren() do
                if variant:IsA("Model") then
                    local vis = variant == shownModel
                    for _, p in variant:GetDescendants() do
                        if p:IsA("BasePart") then
                            if vis then
                                local st = p:GetAttribute("ShownTransparency")
                                p.Transparency = if typeof(st) == "number" then st else 0
                                p.CanCollide = p.Transparency < 1
                            else
                                p.Transparency = 1
                                p.CanCollide = false
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Which world axis a side's shoji screens slide along: front/back bays step along X, left/right
-- along Z. Mirrors tools/studio/trackShojiBays.luau's RUN_AXIS -- the Studio tool that cut the
-- channels this moves leaves through -- so runtime and authoring agree on which axis is "open".
local SHOJI_RUN_AXIS: { [string]: string } = { front = "X", back = "X", left = "Z", right = "Z" }

-- Slide each side's shoji screens to the travel recorded in `shojiOpen` (a per-side list of
-- bay-widths; see ShojiRun). A SIDE'S RUN IS ONLY THE BAYS THAT CARRY A `Shoji` VARIANT, in
-- ascending Bay_<side>_<index> order -- the same rule tools/studio/trackShojiBays.luau used when
-- it cut the channels, because the groove ordinal a screen's geometry was tracked against is its
-- position within that subset, not its raw bay index. A bay modelled with no Shoji variant (this
-- prefab's plain Bay_left_*/Bay_right_* wall segments, say) earns no ordinal and must not be
-- counted, or every real screen would be shifted one channel deeper than the geometry expects.
--
-- Idempotent, and safe to call more than once on the same model (a re-render after a door edit,
-- for instance): each leaf's HOME is not cached anywhere -- the model this runs against can be
-- destroyed and rebuilt out from under a module-level cache -- so home is instead read back from
-- the bay's own `ShojiOpen` attribute (absent means 0, i.e. the leaf is at home). A call moves the
-- leaf by the DIFFERENCE between the new travel and whatever the attribute already says, so
-- calling twice with the same shojiOpen is a no-op and repeated calls never accumulate drift.
-- A missing/unrecognised side is warned and skipped, same failure posture as applyBays (F2/F4).
function StructureOps.applyShoji(model: Model, shojiOpen: { [string]: { number } }?)
    local bySide: { [string]: { { index: number, bay: Model, shoji: Model } } } = {}
    for _, c in model:GetChildren() do
        if c:IsA("Model") then
            local side, idxStr = c.Name:match("^Bay_(%a+)_(%d+)$")
            if side then
                local shoji = c:FindFirstChild("Shoji")
                if shoji and shoji:IsA("Model") then
                    local list = bySide[side]
                    if not list then
                        list = {}
                        bySide[side] = list
                    end
                    table.insert(list, { index = tonumber(idxStr) :: number, bay = c, shoji = shoji })
                end
            end
        end
    end

    for side, list in bySide do
        table.sort(list, function(a, b)
            return a.index < b.index
        end)
        local runAxis = SHOJI_RUN_AXIS[side]
        if not runAxis then
            warn(`[StructureOps] applyShoji: unrecognised side '{side}'`)
        else
            local count = #list
            local resolved = ShojiRun.resolve(shojiOpen and shojiOpen[side], count)
            for ordinal, entry in list do
                local open = resolved[ordinal]
                local prevAttr = entry.bay:GetAttribute("ShojiOpen")
                local prevOpen = if typeof(prevAttr) == "number" then prevAttr else 0
                local deltaStuds = ShojiRun.displacement(open) - ShojiRun.displacement(prevOpen)
                if deltaStuds ~= 0 then
                    local delta = if runAxis == "X"
                        then Vector3.new(deltaStuds, 0, 0)
                        else Vector3.new(0, 0, deltaStuds)
                    entry.shoji:PivotTo(entry.shoji:GetPivot() + delta)
                end
                entry.bay:SetAttribute("ShojiOpen", open)
            end
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
                local d = p:FindFirstChildOfClass("Decal")
                if d then
                    d.Face = Enum.NormalId.Top
                    d.Texture = assetId
                else
                    d = Instance.new("Decal")
                    d.Face = Enum.NormalId.Top
                    d.Texture = assetId
                    d.Parent = p
                end
            end
        end
    else
        local bay = tonumber(target:match("ShojiBay:(%d+)"))
        for _, p in m:GetDescendants() do
            if p:HasTag("ShojiBay") and p:GetAttribute("Bay") == bay then
                local d = p:FindFirstChildOfClass("Decal")
                if d then
                    d.Face = Enum.NormalId.Front
                    d.Texture = assetId
                else
                    d = Instance.new("Decal")
                    d.Face = Enum.NormalId.Front
                    d.Texture = assetId
                    d.Parent = p
                end
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
