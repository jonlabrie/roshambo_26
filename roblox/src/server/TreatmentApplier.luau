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
    buildingPlacer: any, -- pure placeCF/fits (BuildingPlacer)
    sizeClasses: any, -- pure scale/deckFootprint (SizeClasses)
}

-- The building's own footprint at S (walls ~18.7 x 12.7), centered on its pivot. Scaled by the
-- teahouse size for the non-fatal fit-check against the deck. (teahouse.size <= deckSize is
-- already guaranteed upstream, so this is a safety net; refine when authored M/L prefabs land.)
local BUILDING_BASE = { minX = -9.35, maxX = 9.35, minZ = -6.35, maxZ = 6.35 }

function TreatmentApplier.new(deps: Deps)
    return setmetatable({
        _c = deps.container,
        _padBuilder = deps.padBuilder,
        _structureBuilder = deps.structureBuilder,
        _catalog = deps.catalog,
        _structureOps = deps.structureOps,
        _padOpsNew = deps.padOpsNew,
        _buildingPlacer = deps.buildingPlacer,
        _sizeClasses = deps.sizeClasses,
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

-- Build the placed building into `staging` when a teahouse is present and fits the deck.
-- Non-fatal: a build/fit failure logs and leaves the deck standing (F2/F4).
function TreatmentApplier:_buildBuilding(
    padId: string,
    spec: any,
    treatment: any,
    teahouse: any,
    deckSize: string,
    staging: Instance
)
    local placement = teahouse.placement
    local deckFP = self._sizeClasses.deckFootprint(deckSize)
    local s = self._sizeClasses.scale[teahouse.size]
    local buildingFP = {
        minX = BUILDING_BASE.minX * s,
        maxX = BUILDING_BASE.maxX * s,
        minZ = BUILDING_BASE.minZ * s,
        maxZ = BUILDING_BASE.maxZ * s,
    }
    if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
        warn(
            `[D.6] {padId}: {teahouse.size} building does not fit the {deckSize} deck at its placement; deck only`
        )
        return
    end
    -- world pivot = deck CFrame composed with the local placement transform (offset + facing)
    local deckCF = CFrame.new(table.unpack(spec.mountCF))
    local placedCF = deckCF * CFrame.new(table.unpack(self._buildingPlacer.placeCF(placement)))
    local mount =
        { cframe = { placedCF:GetComponents() }, openSide = placement.openSide, footprint = buildingFP }
    local ok, result = pcall(function()
        return self._structureBuilder.build(teahouse.loadout, mount, self._catalog, self._structureOps)
    end)
    if not ok then
        warn(`[D.6] building failed for {padId}: {result}`)
        return -- deck stands; no building this pass
    end
    local model = result :: Model
    model.Name = "Structure"
    if s ~= 1 then
        model:ScaleTo(s) -- scales the BUILDING about its (placed) pivot; the deck is unscaled
    end
    if not treatment.lit then
        shutter(model)
    end
    model.Parent = staging
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
end

-- Rebuild a site from scratch: the hand-agnostic pad (deck slab + beams + engawa rail + posts)
-- for `deckSize`, plus the optional building placed on it. Transactional: everything is staged
-- off-tree and swapped in only on success, so a failure never blanks a live site (F2/F4).
function TreatmentApplier:apply(padId: string, spec: any, treatment: any, deckSize: string?, teahouse: any?)
    local folder = self:_folder(padId)
    if treatment.kind ~= "structure" or deckSize == nil then
        -- garden / no-deck treatment: clear the site (applier deferred to a later increment)
        for _, c in folder:GetChildren() do
            c:Destroy()
        end
        return
    end
    local staging = Instance.new("Folder")
    local mountCF = CFrame.new(table.unpack(spec.mountCF))
    local okDeck, deckErr = pcall(function()
        self._padBuilder.buildDeck(deckSize, spec.mountCF, self._padOpsNew(mountCF, staging))
    end)
    if not okDeck then
        warn(`[D.6] deck build failed for {padId}: {deckErr}`)
        staging:Destroy()
        return -- keep whatever was there (F4: no crash, no orphan swap)
    end
    if teahouse ~= nil then
        self:_buildBuilding(padId, spec, treatment, teahouse, deckSize, staging)
    end
    -- commit: drop the old site and adopt the freshly staged deck + building
    for _, c in folder:GetChildren() do
        c:Destroy()
    end
    for _, c in staging:GetChildren() do
        c.Parent = folder
    end
    staging:Destroy()
end

return TreatmentApplier
