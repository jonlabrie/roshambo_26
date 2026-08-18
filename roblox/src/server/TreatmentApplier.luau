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
    sizeClasses: any, -- pure deckFootprint/placementBounds/buildingFootprint/prefabName (SizeClasses)
    deckPlacement: any, -- pure per-size deck-pivot lookup (DeckPlacement)
    decorationLayout: any, -- pure DecorationLayout.resolve
    decorationCatalog: any, -- DecorationCatalog (footprint pure; build is Roblox-only)
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
        _decorationLayout = deps.decorationLayout,
        _decorationCatalog = deps.decorationCatalog,
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
    -- placementBounds, not deckFootprint: the deck footprint's perimeter is occupied by the
    -- railings (PadOps), so the building must clamp/fit inside the inset that keeps it clear
    -- of them (B4 gate finding).
    local deckFP = self._sizeClasses.placementBounds(deckSize)
    local buildingFP = self._sizeClasses.buildingFootprint(teahouse.size)
    -- B4: clamp the SAVED placement into this deck at render time (stored values never change;
    -- a display-shrunk deck slides the building minimally back into bounds). fits() stays only
    -- as a last-ditch guard for pathological data.
    local placement = self._buildingPlacer.clamp(buildingFP, deckFP, teahouse.placement)
    if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
        -- a persisted facing can stop fitting when the deck display shrinks (e.g. an L teahouse
        -- facing E/W on its own L deck, post-shrink); teahouse <= deck guarantees the N facing
        -- always fits, so fall back to it once (same offset, re-clamped) rather than vanishing
        -- the building. Only if even THAT fails (pathological data) do we skip to deck-only.
        placement = self._buildingPlacer.clamp(
            buildingFP,
            deckFP,
            { offset = teahouse.placement.offset, facing = "N" }
        )
        if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
            warn(
                `[D.6] {padId}: {teahouse.size} building does not fit the {deckSize} deck at its placement; deck only`
            )
            return nil
        end
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
    -- fresh clone, so every bay starts homed (no ShojiOpen attribute yet); applyShoji parks each
    -- screen where the loadout left it.
    self._structureOps.applyShoji(model, teahouse.loadout.shojiOpen)
    model.Name = "Structure"
    -- (no ScaleTo: sizes are authored per-size prefabs, not a scaled base)
    if not treatment.lit then
        shutter(model)
    end
    model.Parent = staging
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
    return placement
end

-- Build the owner's visible deck decorations onto the staged deck. teahouseFP is the built
-- teahouse's deck-local AABB (nil for a bare deck) — DecorationLayout hides props under it. Each
-- prop is a non-collidable Model tagged Decoration with id + padId attributes; DecorationController
-- (client) puts owner-only Move/Remove prompts on them. May throw on bad build data; fault-isolated
-- by the caller (a bad prop must never blank the deck).
function TreatmentApplier:_buildDecorations(
    padId: string,
    deckCF12: { number },
    deckSize: string,
    teahouseFP: any,
    decorations: { any },
    staging: Instance
)
    local deckFP = self._sizeClasses.deckFootprint(deckSize)
    local resolved = self._decorationLayout.resolve(deckFP, teahouseFP, decorations)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    for _, r in resolved do
        if not r.visible then
            continue
        end
        local model = self._decorationCatalog.build(r.propId)
        if model == nil then
            continue
        end
        local placeCF = self._buildingPlacer.placeCF({ offset = r.offset, facing = r.facing })
        model:PivotTo(deckCF * CFrame.new(table.unpack(placeCF)))
        model.Name = "Decoration"
        model:SetAttribute("id", r.id)
        model:SetAttribute("padId", padId)
        model:SetAttribute("propId", r.propId)
        model:AddTag("Decoration")
        model.Parent = staging
    end
end

-- The home-portal deck control: a small tagged fixture on the deck railing (placeholder art).
-- Built only for an owner's lit deck that has the portal; PortalController wires its prompt.
function TreatmentApplier:_buildPortalControl(
    padId: string,
    deckCF12: { number },
    deckSize: string,
    teaDx: number,
    staging: Instance
)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    local control = Instance.new("Part")
    control.Name = "PortalControl"
    control.Size = Vector3.new(1.5, 3, 0.5)
    control.Anchored = true
    control.CanCollide = false
    control.Color = Color3.fromRGB(120, 90, 200)
    control.Material = Enum.Material.Neon
    -- Against a side railing toward the back of the pad. Deck-local: -Z = front/view, +Z =
    -- back/access (the open edge), ±X = the side railings. Auto-swap to the side away from the
    -- teahouse: teaDx > 0 (building on the +X/right half) -> control LEFT, else -> control RIGHT.
    -- Sized off the deck footprint so it hugs the railing at any deck size, a few studs in from the
    -- open back edge. Gate-tunable.
    local fp = self._sizeClasses.deckFootprint(deckSize)
    local onLeft = teaDx > 0
    local x = if onLeft then fp.minX + 1.5 else fp.maxX - 1.5
    -- yaw 90deg so the doorway's wide face runs ALONG the side railing (flush, parallel), and
    -- faces the deck interior (+X from the left railing, -X from the right) so you step in from
    -- the deck side.
    local yaw = if onLeft then math.rad(90) else math.rad(-90)
    control.CFrame = deckCF * CFrame.new(x, 1.5, fp.maxZ - 4) * CFrame.Angles(0, yaw, 0)
    control:SetAttribute("padId", padId)
    control:AddTag("PortalControl")
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Open portal"
    prompt.ObjectText = "To arena"
    prompt.KeyboardKeyCode = Enum.KeyCode.G
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = control
    control.Parent = staging
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
    local builtPlacement: any = nil
    if teahouse ~= nil and teahouse.loadout ~= nil then
        -- fault-isolate the WHOLE building step (fit-check + placement math + build): a bad
        -- placement or build must leave the staged deck standing, never abort the caller's
        -- vacantActions / PlayerRemoving loop (F2/F4).
        local okBuilding, placementOrErr = pcall(function()
            return self:_buildBuilding(padId, deckCF12, treatment, teahouse, deckSize, staging)
        end)
        if okBuilding then
            builtPlacement = placementOrErr
        else
            warn(`[D.6] building step failed for {padId}: {placementOrErr}; deck only`)
        end
    end
    -- decorations: owner's placed props, hidden under the built teahouse. teahouseFP is the built
    -- teahouse's deck-local AABB (nil when deck-only). Fault-isolated: a bad prop never blanks the deck.
    local decorations = treatment.deckDecorations
    if treatment.lit == true and decorations ~= nil and #decorations > 0 then
        local teahouseFP: any = nil
        if builtPlacement ~= nil and teahouse ~= nil then
            local buildingFP = self._sizeClasses.buildingFootprint(teahouse.size)
            teahouseFP = self._buildingPlacer.footprintBounds(buildingFP, builtPlacement)
        end
        local okDecor, decorErr = pcall(function()
            self:_buildDecorations(padId, deckCF12, deckSize, teahouseFP, decorations, staging)
        end)
        if not okDecor then
            warn(`[DECOR] decoration step failed for {padId}: {decorErr}; deck without props`)
        end
    end
    if treatment.portalOwned == true and treatment.lit == true then
        -- the player may have dragged the teahouse (B4) onto the control's default side; put the
        -- control on the emptier lateral half so it hugs a railing away from the building.
        local teaDx = (
            teahouse
            and teahouse.placement
            and teahouse.placement.offset
            and teahouse.placement.offset[1]
        ) or 0
        local okPortal, portalErr = pcall(function()
            self:_buildPortalControl(padId, deckCF12, deckSize, teaDx, staging)
        end)
        if not okPortal then
            warn(`[HP] portal control build failed for {padId}: {portalErr}`)
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
