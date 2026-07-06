--!strict
-- Studio-runtime applier for sub-project D. Builds a pad's support posts once
-- (buildSupport) and transactionally (re)builds its Structure child per a
-- VacantState Treatment (apply), shuttering the structure when not lit. Roblox
-- datatypes -> not Lune-testable; proven by the D.2 visual gate. A thin adapter:
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

function TreatmentApplier:buildSupport(spec: any)
    local folder = self:_folder(spec.id)
    local mountCF = CFrame.new(table.unpack(spec.mountCF))
    self._padBuilder.build(spec, self._padOpsNew(mountCF, folder))
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

function TreatmentApplier:apply(padId: string, spec: any, treatment: any, scale: number?)
    local folder = self:_folder(padId)
    if treatment.kind ~= "structure" then
        local existing = folder:FindFirstChild("Structure")
        if existing then
            existing:Destroy()
        end
        return -- garden treatment: applier deferred to D.5
    end
    local mount = { cframe = spec.mountCF, hand = spec.hand, footprint = spec.footprint }
    local ok, result = pcall(function()
        return self._structureBuilder.build(treatment.loadout, mount, self._catalog, self._structureOps)
    end)
    if not ok then
        warn(`[D.2] apply failed for {padId}: {result}`)
        return -- keep whatever structure was already there (F4: no crash, no orphan swap)
    end
    local model = result :: Model
    model.Name = "Structure"
    if scale ~= nil and scale ~= 1 then
        model:ScaleTo(scale)
    end
    if not treatment.lit then
        shutter(model)
    end
    local existing = folder:FindFirstChild("Structure")
    if existing then
        existing:Destroy()
    end
    model.Parent = folder
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
end

return TreatmentApplier
