--!strict
-- Owner-only in-world controls for placed deck decorations (2026-07-19 framework). Mirrors
-- BackDoorController's geometry-driven binding, but keyed on the CollectionService "Decoration"
-- tag: whenever a Decoration Model whose padId attribute matches THIS client's claimed pad
-- replicates in, it gets Move + Remove ProximityPrompts. Tag replication + GetInstanceAddedSignal
-- make RemoteEvent/replication ordering irrelevant (same lesson as the back-door rebind). A buy
-- fires DecorationPlaced{ id, propId }; we enter ghost-drag IMMEDIATELY off the propId (part=nil),
-- independent of the built instance — the freshly-bought prop's centred default can be auto-hidden
-- under the teahouse, so waiting for its instance would strand it invisibly.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
local SetDecorationRemove = remotes:WaitForChild("SetDecorationRemove") :: RemoteEvent
-- mortars arrive on FireworkState, not EconomyState -- see the mortar section below.
local FireworkState = remotes:WaitForChild("FireworkState") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local SizeClasses = require(shared:WaitForChild("SizeClasses"))
local BuildingPlacer = require(shared:WaitForChild("BuildingPlacer"))
local MortarPlacement = require(shared:WaitForChild("MortarPlacement"))

local myPadId: string? = nil
local bound: { [Instance]: boolean } = {} -- decoration Model -> prompts added

local function anchorPart(model: Model): BasePart?
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

-- propId is written by TreatmentApplier._buildDecorations as a model attribute (Task 11 Step 2).
local function propIdOf(model: Instance): string?
    return model:GetAttribute("propId") :: string?
end

local function addPrompts(model: Model)
    if bound[model] then
        return
    end
    local anchor = anchorPart(model)
    if anchor == nil then
        return
    end
    bound[model] = true

    local move = Instance.new("ProximityPrompt")
    move.Name = "DecorMove"
    move.ActionText = "Move"
    move.ObjectText = "Decoration"
    move.KeyboardKeyCode = Enum.KeyCode.E
    move.MaxActivationDistance = 10
    move.RequiresLineOfSight = false
    move.Parent = anchor
    move.Triggered:Connect(function()
        local id = model:GetAttribute("id")
        local propId = propIdOf(model)
        if typeof(id) == "number" and typeof(propId) == "string" then
            EventBus.MoveDecoration:Fire({ padId = myPadId, id = id, propId = propId, part = model })
        end
    end)

    local remove = Instance.new("ProximityPrompt")
    remove.Name = "DecorRemove"
    remove.ActionText = "Remove"
    remove.ObjectText = "Decoration"
    remove.KeyboardKeyCode = Enum.KeyCode.X
    remove.MaxActivationDistance = 10
    remove.RequiresLineOfSight = false
    remove.Parent = anchor
    remove.Triggered:Connect(function()
        local id = model:GetAttribute("id")
        if typeof(id) == "number" then
            SetDecorationRemove:FireServer({ id = id })
        end
    end)
end

-- Bind a tagged decoration IF it belongs to this client's claimed pad.
local function tryBind(inst: Instance)
    if not inst:IsA("Model") then
        return
    end
    local padId = inst:GetAttribute("padId")
    if myPadId == nil or padId ~= myPadId then
        return
    end
    addPrompts(inst)
end

local function rescanAll()
    for _, inst in CollectionService:GetTagged("Decoration") do
        tryBind(inst)
    end
end

-- ===== mortars: client-rendered tubes (deck-mortars, 2026-09-04, Task 5) =====
-- Unlike decorations, mortars are NOT server-built (main.server.luau, SetMortarPlacement's
-- handler: "TreatmentApplier never reads treatment.mortarPlacements/mortars -- Task 5 renders
-- them client-side"), so this controller builds the Models itself instead of merely binding
-- prompts to ones the server replicated in. Rendered models are parented to a folder THIS script
-- owns, never to the site's own MaterializedSite_<padId> folder -- TreatmentApplier:apply()
-- destroys every direct child of that folder on every rebuild, which would silently wipe geometry
-- the server doesn't know exists.
local mortarRenderFolder = Instance.new("Folder")
mortarRenderFolder.Name = "ClientMortarRender"
mortarRenderFolder.Parent = workspace

local MORTAR_TAG = "Mortar" -- deliberately NOT "Decoration": see report divergence note
local BASE_TOP = 0.5 -- mirrors MortarPlacement's own (unexported) BASE_TOP -- muzzleWorld assumes
-- the tube's local top sits at exactly this height above the deck
local BASE_COLOR = Color3.fromRGB(216, 214, 206)
local TUBE_COLOR = Color3.fromRGB(58, 60, 66)

local myMortars: { string } = {}
local myMortarPlacements: any = nil
local mortarModels: { [string]: Model } = {}
local currentMortarFolder: Instance? = nil
local mortarFolderConn: RBXScriptConnection? = nil

local function mortarPart(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    return p
end

-- One Model per owned tier: a timber base under a vertical metal tube. The tube's cylinder
-- orientation copies DecorationCatalog's tsukubai idiom exactly (Shape = Cylinder, then
-- CFrame.Angles(0, 0, rad(90)) to stand the part's default horizontal axis upright) so the
-- caller's later PivotTo places it the same way a decoration prop is placed.
local function buildMortarModel(mortarId: string): Model?
    local tube = MortarPlacement.TUBE[mortarId]
    local tier = mortarId:match("^mortar:(%u)$")
    if tube == nil or tier == nil then
        return nil
    end
    local m = Instance.new("Model")
    m.Name = "Mortar_" .. tier

    local baseSide = tube.bore * 3 + 0.4
    local base = mortarPart("Base", Vector3.new(baseSide, BASE_TOP, baseSide), BASE_COLOR, Enum.Material.Wood)
    base.CFrame = CFrame.new(0, BASE_TOP / 2, 0)
    base.Parent = m

    local barrel = mortarPart(
        "Tube",
        Vector3.new(tube.length, tube.bore * 3, tube.bore * 3),
        TUBE_COLOR,
        Enum.Material.Metal
    )
    barrel.Shape = Enum.PartType.Cylinder
    barrel.CFrame = CFrame.new(0, BASE_TOP + tube.length / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
    barrel.Parent = m

    m.PrimaryPart = barrel
    return m
end

local function clearMortarModels()
    for _, model in mortarModels do
        model:Destroy()
    end
    mortarModels = {}
end

-- Deck-local AABB of the built teahouse (nil for a bare deck), read the same way
-- MoveController.facingFromPivotOf does: the live Structure's world pivot relative to the deck's
-- own mount CFrame. Nothing else replicates a teahouse's offset/facing to the client, so this is
-- the only way this controller can learn it.
local function teahouseFootprint(folder: Instance, mountCF: CFrame): any
    local teaSize = folder:GetAttribute("TeahouseSize")
    if typeof(teaSize) ~= "string" or teaSize == "" then
        return nil
    end
    local structure = folder:FindFirstChild("Structure")
    if structure == nil or not structure:IsA("Model") then
        return nil
    end
    local rel = mountCF:ToObjectSpace((structure :: Model):GetPivot())
    local _, ry, _ = rel:ToOrientation()
    local deg = (math.round(math.deg(ry) / 90) * 90) % 360
    local facing = if deg == 0 then "N" elseif deg == 90 then "E" elseif deg == 180 then "S" else "W"
    local buildingFP = SizeClasses.buildingFootprint(teaSize)
    return BuildingPlacer.footprintBounds(
        buildingFP,
        { offset = { rel.Position.X, rel.Position.Z }, facing = facing }
    )
end

local function rebuildMortars()
    clearMortarModels()
    if myPadId == nil or #myMortars == 0 then
        return
    end
    local sites = workspace:FindFirstChild("TeahouseSites")
    local folder = sites and sites:FindFirstChild("MaterializedSite_" .. myPadId)
    if folder == nil then
        return
    end
    local mountCF = folder:GetAttribute("MountCF")
    local deckSize = folder:GetAttribute("DeckSize")
    if typeof(mountCF) ~= "CFrame" or typeof(deckSize) ~= "string" then
        return
    end
    local deckFP = SizeClasses.deckFootprint(deckSize)
    local teahouseFP = teahouseFootprint(folder, mountCF)
    local resolved = MortarPlacement.resolve(deckFP, myMortars, myMortarPlacements, teahouseFP)
    local padId = myPadId
    for mortarId, placement in resolved do
        local model = buildMortarModel(mortarId)
        if model ~= nil then
            local placeCF =
                BuildingPlacer.placeCF({ offset = { placement.x, placement.z }, facing = placement.facing })
            model:PivotTo((mountCF :: CFrame) * CFrame.new(table.unpack(placeCF)))
            model:SetAttribute("padId", padId)
            model:SetAttribute("MortarId", mortarId)
            model:AddTag(MORTAR_TAG)
            model.Parent = mortarRenderFolder
            mortarModels[mortarId] = model
        end
    end
end

-- Watch a site folder for whichever Structure lives under it -- same lifecycle
-- BackDoorController.watchFolder/bindStructure uses to survive RemoteEvent/replication ordering.
-- A teahouse move (SetPlacement) rebuilds the Structure WITHOUT ever firing EconomyState, so this
-- is the only client-side signal that the teahouse footprint (and therefore the nudge) changed.
local function watchMortarFolder(folder: Instance)
    if folder == currentMortarFolder then
        return
    end
    if mortarFolderConn then
        mortarFolderConn:Disconnect()
        mortarFolderConn = nil
    end
    currentMortarFolder = folder
    mortarFolderConn = folder.ChildAdded:Connect(function(child)
        if child.Name == "Structure" then
            rebuildMortars()
        end
    end)
    rebuildMortars() -- the folder's attributes (MountCF/DeckSize/TeahouseSize) are already live
end

CollectionService:GetInstanceAddedSignal("Decoration"):Connect(tryBind)
CollectionService:GetInstanceRemovedSignal("Decoration"):Connect(function(inst)
    bound[inst] = nil
end)

EconomyState.OnClientEvent:Connect(function(p)
    local newPad = p.claimedPadId
    -- e.mortars/e.mortarPlacements ARE mirrored into EconomyState's payload (echoEconomy), so
    -- SetMortarPlacement's echo lands here -- but their REAL first values only ever arrive on
    -- FireworkState (see that listener below); adopt whatever this echo carries either way.
    if typeof(p.mortars) == "table" then
        myMortars = p.mortars
    end
    myMortarPlacements = p.mortarPlacements
    if newPad ~= myPadId then
        myPadId = newPad
        rescanAll() -- claim just resolved: bind any decorations already replicated in
        if mortarFolderConn then
            mortarFolderConn:Disconnect()
            mortarFolderConn = nil
        end
        currentMortarFolder = nil
        clearMortarModels()
        if myPadId ~= nil then
            local sites = workspace:WaitForChild("TeahouseSites")
            local folder = sites:WaitForChild("MaterializedSite_" .. myPadId, 15)
            if folder ~= nil and myPadId == newPad then
                watchMortarFolder(folder) -- rebuilds mortars internally
                return
            end
        end
    end
    rebuildMortars()
end)

-- Mortars ride the fireworks GET (pushFireworkState), not the economy GET or any echoEconomy
-- call: main.server.luau's own comment on `e.mortars`/`e.mortarPlacements` is explicit that this
-- is "the ONLY place [they] get their real values" -- fired on join, after every launch, and at
-- every reveal. Without this listener a player who owns mortars but has touched no OTHER economy
-- action yet (no decoration move, no purchase) would see zero tubes on their own deck.
FireworkState.OnClientEvent:Connect(function(state)
    if typeof(state) ~= "table" then
        return
    end
    if typeof(state.mortars) == "table" then
        myMortars = state.mortars
    end
    myMortarPlacements = state.mortarPlacements
    rebuildMortars()
end)

DecorationPlaced.OnClientEvent:Connect(function(p)
    if
        typeof(p) == "table"
        and typeof(p.id) == "number"
        and typeof(p.propId) == "string"
        and myPadId ~= nil
    then
        -- Enter ghost-drag for the freshly-bought prop IMMEDIATELY, independent of whether its
        -- default [0,0] render is visible: on a teahouse-owning deck the centered default is
        -- auto-hidden, so the built instance would never appear and waiting for it would strand
        -- the prop. enterDecoration tolerates a nil part and resolves the deck from padId.
        EventBus.MoveDecoration:Fire({ padId = myPadId, id = p.id, propId = p.propId, part = nil })
    end
end)

rescanAll()
