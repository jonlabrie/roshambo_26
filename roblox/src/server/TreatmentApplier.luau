--!strict
-- Studio-runtime applier for sub-project D. `apply` transactionally (re)builds a
-- site's Structure child per a VacantState Treatment AND its dynamic support posts
-- (built to the materialized footprint: a stilt only where terrain drops below the
-- deck; embed/void corners get none), shuttering the structure when not lit. Roblox
-- datatypes -> not Lune-testable; proven by the visual gate. A thin adapter:
-- the builders/ops/catalog are injected.
-- ⚠ KamonDraw is the RENDERER ONLY. The note below still holds: WHOSE crest this is arrives on
-- the treatment, computed at the call site, so this file never decides affiliation. Drawing one
-- is a different dependency from choosing one.
local KamonDraw = require("../shared/KamonDraw")

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

-- ===== THE NOBORI — the owner's flag, and their crest on it =====
-- Item 6's stated flex: a banner-pole flag at the teahouse. A nobori is the right form — a tall
-- narrow banner reads from across the canyon where a doorway noren does not.
--
-- ⚠ BUILT PER OWNER, NOT AUTHORED INTO THE PREFAB. The teahouse prefabs are shared by everyone,
-- and a crest is not: a flag in the prefab would fly one house's mon over every house. The crest
-- arrives on the TREATMENT, computed at the call site, so this file stays the thin adapter it
-- says it is and needs no Kamon dependency of its own.
--
-- ⚠ ONLY ON A LIT DECK. A vacant pad flying somebody's crest would say a house is home when it is
-- not, and the shoji glow already carries occupancy — this must agree with it.
local FLAG_CLOTH = KamonDraw.CLOTH

-- Crest drawing lives in Kamon.draw as of 2026-08-22 — the sashimono is the second surface the
-- note that used to sit here anticipated.
local drawCrest = KamonDraw.draw

function TreatmentApplier:_buildNobori(
    padId: string,
    deckCF12: { number },
    deckSize: string,
    teaDx: number,
    crest: any,
    staging: Instance
)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    local fp = self._sizeClasses.deckFootprint(deckSize)
    -- FRONT corner, on the side the teahouse is NOT on — the same auto-swap the portal control
    -- uses, mirrored to the front so the flag meets you on the approach rather than hiding behind
    -- the building. Deck-local: -Z is the front/view edge.
    local onLeft = teaDx > 0
    local x = if onLeft then fp.minX + 1.2 else fp.maxX - 1.2
    local z = fp.minZ + 1.2

    local model = Instance.new("Model")
    model.Name = "Nobori"

    local POLE_H = 9
    local pole = Instance.new("Part")
    pole.Name = "Pole"
    pole.Shape = Enum.PartType.Cylinder
    pole.Size = Vector3.new(POLE_H, 0.18, 0.18)
    pole.Anchored = true
    pole.CanCollide = false
    pole.CastShadow = false
    pole.Color = Color3.fromRGB(96, 78, 56)
    pole.Material = Enum.Material.Wood
    pole.CFrame = deckCF * CFrame.new(x, POLE_H / 2, z) * CFrame.Angles(0, 0, math.rad(90))
    pole.Parent = model

    -- The cloth hangs from near the top, to ONE side of the pole, which is what makes a nobori a
    -- nobori rather than a flag on a flagpole.
    local CLOTH_W, CLOTH_H = 1.7, 5.4
    local side = if onLeft then 1 else -1
    local cloth = Instance.new("Part")
    cloth.Name = "Cloth"
    cloth.Size = Vector3.new(CLOTH_W, CLOTH_H, 0.06)
    cloth.Anchored = true
    cloth.CanCollide = false
    cloth.CastShadow = false
    cloth.Color = FLAG_CLOTH
    cloth.Material = Enum.Material.Fabric
    cloth.CFrame = deckCF * CFrame.new(x + side * (CLOTH_W / 2 + 0.12), POLE_H - CLOTH_H / 2 - 0.5, z)
    cloth.Parent = model

    if crest and crest.shapes then
        local PPS = 96
        local gui = Instance.new("SurfaceGui")
        gui.Name = "Crest"
        gui.Face = Enum.NormalId.Front
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = PPS
        gui.AlwaysOnTop = false
        gui.Parent = cloth
        -- 1.2 studs, matching the throw glyph already on these lanterns (GlyphPlateA is 1.20 on
        -- its narrow axis). That size is the benchmark: it was tuned until it read.
        drawCrest(gui, crest, math.floor(1.2 * PPS))
    end

    model:SetAttribute("padId", padId)
    model:SetAttribute("crestId", crest and crest.id)
    model.Parent = staging
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
    -- THE FLAG. Only for a lit deck: a vacant pad flying somebody's crest would say a house is
    -- home when it is not, and the shoji glow already carries occupancy — the two must agree.
    -- Fault-isolated like every other optional fixture: a bad crest must never blank the deck.
    if treatment.lit == true and treatment.crest ~= nil then
        local teaDxFlag = (
            teahouse
            and teahouse.placement
            and teahouse.placement.offset
            and teahouse.placement.offset[1]
        ) or 0
        local okFlag, flagErr = pcall(function()
            self:_buildNobori(padId, deckCF12, deckSize, teaDxFlag, treatment.crest, staging)
        end)
        if not okFlag then
            warn(`[NOBORI] flag build failed for {padId}: {flagErr}`)
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
