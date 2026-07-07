--!strict
-- Studio-runtime applier for sub-project D. `apply` transactionally (re)builds a
-- site's Structure child per a VacantState Treatment AND its dynamic support posts
-- (built to the materialized footprint: a stilt only where terrain drops below the
-- deck; embed/void corners get none), shuttering the structure when not lit. Roblox
-- datatypes -> not Lune-testable; proven by the visual gate. A thin adapter:
-- the builders/ops/catalog are injected.
local TreatmentApplier = {}
TreatmentApplier.__index = TreatmentApplier

export type Deps = {
    container: Instance,
    padBuilder: any,
    structureBuilder: any,
    catalog: any,
    structureOps: any,
    padOpsNew: (CFrame, Instance) -> any,
}

function TreatmentApplier.new(deps: Deps)
    return setmetatable({
        _c = deps.container,
        _padBuilder = deps.padBuilder,
        _structureBuilder = deps.structureBuilder,
        _catalog = deps.catalog,
        _structureOps = deps.structureOps,
        _padOpsNew = deps.padOpsNew,
        _folders = {} :: { [string]: Folder },
    }, TreatmentApplier)
end

function TreatmentApplier:_folder(padId: string): Folder
    local f = self._folders[padId]
    if not f then
        f = Instance.new("Folder")
        f.Name = "MaterializedSite_" .. padId
        f.Parent = self._c
        self._folders[padId] = f
    end
    return f
end

local function shutter(model: Model)
    for _, d in model:GetDescendants() do
        if d:IsA("PointLight") then
            d.Enabled = false
        elseif d:IsA("BasePart") then
            if d.Name == "Shoji" then
                d.Transparency = 0
            elseif d.Name == "ShojiGlow" then
                d.Transparency = 1
            end
        end
    end
    local chochin = model:FindFirstChild("ChochinSwing", true)
    if chochin then
        chochin:Destroy()
    end
end

function TreatmentApplier:apply(padId: string, spec: any, treatment: any, scale: number?, footprint: any?)
    local folder = self:_folder(padId)
    if treatment.kind ~= "structure" then
        local existing = folder:FindFirstChild("Structure")
        if existing then
            existing:Destroy()
        end
        return -- garden treatment: applier deferred to a later increment
    end
    local mount = { cframe = spec.mountCF, hand = spec.hand, footprint = footprint }
    local ok, result = pcall(function()
        return self._structureBuilder.build(treatment.loadout, mount, self._catalog, self._structureOps)
    end)
    if not ok then
        warn(`[D.4] apply failed for {padId}: {result}`)
        return -- keep whatever was there (F4: no crash, no orphan swap)
    end
    local model = result :: Model
    model.Name = "Structure"
    if scale ~= nil and scale ~= 1 then
        model:ScaleTo(scale)
    end
    if not treatment.lit then
        shutter(model)
    end
    -- transactional swap: drop the old structure + old posts, build the new posts to
    -- the materialized footprint (dynamic: a stilt only where terrain is below the deck),
    -- then parent the new structure.
    local existing = folder:FindFirstChild("Structure")
    if existing then
        existing:Destroy()
    end
    for _, c in folder:GetChildren() do
        if c.Name == "PadPost" then
            c:Destroy()
        end
    end
    if footprint ~= nil then
        local mountCF = CFrame.new(table.unpack(spec.mountCF))
        self._padBuilder.build(
            { mountCF = spec.mountCF, hand = spec.hand, footprint = footprint },
            self._padOpsNew(mountCF, folder)
        )
    end
    model.Parent = folder
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
end

return TreatmentApplier
