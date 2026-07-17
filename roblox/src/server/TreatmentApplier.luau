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
    sizeClasses: any, -- pure deckFootprint/buildingFootprint/prefabName (SizeClasses)
    deckPlacement: any, -- pure per-size deck-pivot lookup (DeckPlacement)
}

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
        _deckPlacement = deps.deckPlacement,
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
                -- darken only the SHOWN shoji into opaque unlit paper. Each Solid/Door bay still
                -- contains a HIDDEN Shoji part (applyBays set it Transparency=1); do NOT resurrect
                -- those, or dormant teahouses sprout phantom dark shoji "walls" on every bay.
                if d.Transparency < 1 then
                    d.Transparency = 0
                end
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

-- Build the placed building into `staging` when it fits the deck (a non-fit is a graceful
-- skip -> deck only). May throw on bad placement/build data; the caller fault-isolates it.
function TreatmentApplier:_buildBuilding(
    padId: string,
    deckCF12: { number },
    treatment: any,
    teahouse: any,
    deckSize: string,
    staging: Instance
)
    local deckFP = self._sizeClasses.deckFootprint(deckSize)
    local buildingFP = self._sizeClasses.buildingFootprint(teahouse.size)
    -- B4: clamp the SAVED placement into this deck at render time (stored values never change;
    -- a display-shrunk deck slides the building minimally back into bounds). fits() stays only
    -- as a last-ditch guard for pathological data.
    local placement = self._buildingPlacer.clamp(buildingFP, deckFP, teahouse.placement)
    if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
        warn(
            `[D.6] {padId}: {teahouse.size} building does not fit the {deckSize} deck at its placement; deck only`
        )
        return
    end
    -- world pivot = deck CFrame composed with the local placement transform (offset + facing)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    local placedCF = deckCF * CFrame.new(table.unpack(self._buildingPlacer.placeCF(placement)))
    local mount = { cframe = { placedCF:GetComponents() }, footprint = buildingFP }
    local prefabName = self._sizeClasses.prefabName(teahouse.loadout.baseStyle, teahouse.size)
    local model = self._structureBuilder.build(
        teahouse.loadout,
        mount,
        self._catalog,
        self._structureOps,
        prefabName
    ) :: Model
    model.Name = "Structure"
    -- (no ScaleTo: sizes are authored per-size prefabs, not a scaled base)
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
        folder:SetAttribute("MountCF", nil)
        folder:SetAttribute("DeckSize", nil)
        folder:SetAttribute("TeahouseSize", nil)
        return
    end
    local deckCF12 = self._deckPlacement.resolve(spec.deckPlacements, deckSize, spec.maxSize)
    if deckCF12 == nil then
        warn(`[D.6] {padId}: no deck placement for size {deckSize} (maxSize {spec.maxSize}); skipping`)
        return
    end
    local staging = Instance.new("Folder")
    local mountCF = CFrame.new(table.unpack(deckCF12))
    local okDeck, deckErr = pcall(function()
        self._padBuilder.buildDeck(deckSize, deckCF12, self._padOpsNew(mountCF, staging))
    end)
    if not okDeck then
        warn(`[D.6] deck build failed for {padId}: {deckErr}`)
        staging:Destroy()
        return -- keep whatever was there (F4: no crash, no orphan swap)
    end
    -- build a building only when there's one to build; a nil teahouse or nil loadout is a
    -- bare deck (Piece-B: owns a deck but no teahouse) — the deck stands alone.
    if teahouse ~= nil and teahouse.loadout ~= nil then
        -- fault-isolate the WHOLE building step (fit-check + placement math + build): a bad
        -- placement or build must leave the staged deck standing, never abort the caller's
        -- vacantActions / PlayerRemoving loop (F2/F4).
        local okBuilding, buildingErr = pcall(function()
            self:_buildBuilding(padId, deckCF12, treatment, teahouse, deckSize, staging)
        end)
        if not okBuilding then
            warn(`[D.6] building step failed for {padId}: {buildingErr}; deck only`)
        end
    end
    -- commit: drop the old site and adopt the freshly staged deck + building
    for _, c in folder:GetChildren() do
        c:Destroy()
    end
    for _, c in staging:GetChildren() do
        c.Parent = folder
    end
    staging:Destroy()
    folder:SetAttribute("Occupied", treatment.lit == true)
    -- B4: authoritative deck frame + built sizes for the client move mode (MoveController).
    folder:SetAttribute("MountCF", mountCF)
    folder:SetAttribute("DeckSize", deckSize)
    folder:SetAttribute(
        "TeahouseSize",
        if teahouse ~= nil and teahouse.loadout ~= nil then teahouse.size else ""
    )
end

return TreatmentApplier
