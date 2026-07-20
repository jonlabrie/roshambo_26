--!strict
-- B4 move mode: a client-side translucent ghost of your teahouse follows the aim across the
-- deck (1-stud snap, R rotates 90°), click/✓ commits one SetPlacement, X/✕ cancels. The ghost
-- is local-only; the server re-validates with the same shared math and rebuilds. Entry is the
-- panel's Move button via EventBus.MoveTeahouse { padId }. While a move is active, the faded
-- original's back-door ProximityPrompts are disabled (a mid-drag F press is otherwise a race
-- with the pending SetPlacement) and restored on exit/commit.
-- Dragging (stepDrag) is a math intersection of the camera's aim ray against the deck's own
-- plane (mountCF's position/UpVector) — NOT a geometry raycast — so the building's own bulk
-- can never occlude the far side of the deck and stall the ghost. Aiming past the deck's edge
-- resolves to an out-of-bounds plane point, which BuildingPlacer.clamp (inside applyGhost)
-- pulls back to the nearest in-bounds spot; aiming past a corner is therefore the intended way
-- to park the ghost flush into that corner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local BuildingPlacer = require(shared:WaitForChild("BuildingPlacer"))
local SizeClasses = require(shared:WaitForChild("SizeClasses"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetPlacement = remotes:WaitForChild("SetPlacement") :: RemoteEvent
local SetDecorationPlacement = remotes:WaitForChild("SetDecorationPlacement") :: RemoteEvent
local DecorationCatalog = require(shared:WaitForChild("DecorationCatalog"))

local player = Players.LocalPlayer
local FACING_ORDER = { "N", "E", "S", "W" }

-- ===== toast palette (per B1/B2/B3 convention) =====
local BG = Color3.fromRGB(20, 18, 16)
local TEXT = Color3.fromRGB(240, 228, 205)

-- mode state (nil when inactive)
local active = false
local ghost: Model? = nil
local original: Model? = nil
local mountCF: CFrame? = nil
local buildingFP: any = nil
local deckFP: any = nil
local current = { offset = { 0, 0 }, facing = "N" }
local commitFn: ((offset: { number }, facing: string) -> ())? = nil
local conns: { RBXScriptConnection } = {}
local hud: ScreenGui? = nil
local disabledPrompts: { ProximityPrompt } = {}

-- ===== Step 2: ghost + fade helpers =====

-- Turn a caller-supplied model into a translucent, non-interactive ghost parented to workspace.
-- The caller decides what the ghost IS (a Structure clone for a teahouse, a fresh catalog prop for
-- a decoration); this only fades/anchors it and strips any interactables.
local function ghostify(model: Model): Model
    model.Name = "MoveGhost"
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d.Transparency < 1 then
                d.Transparency = 0.6
            end
        elseif d:IsA("ProximityPrompt") then
            d:Destroy() -- no interactables on the ghost (back-door prompts clone along)
        end
    end
    model.Parent = workspace -- NOT the site folder: kept independent of whatever that folder does
    return model
end

local function fadeOriginal(structure: Model, amount: number)
    for _, d in structure:GetDescendants() do
        if d:IsA("BasePart") then
            d.LocalTransparencyModifier = amount
        end
    end
end

-- ===== Step 3: placement math =====

-- placeCF's yaw convention: N=0, E=90, S=180, W=270 (CCW, matches CFrame.Angles(0, rad(y), 0))
local function facingFromPivotOf(structure: Model, mount: CFrame): (number, number, string)
    local rel = mount:ToObjectSpace(structure:GetPivot())
    local _, ry, _ = rel:ToOrientation()
    local deg = (math.round(math.deg(ry) / 90) * 90) % 360
    local facing = if deg == 0 then "N" elseif deg == 90 then "E" elseif deg == 180 then "S" else "W"
    return rel.Position.X, rel.Position.Z, facing
end

local function applyGhost()
    local g, m = ghost, mountCF
    if g == nil or m == nil then
        return
    end
    current = BuildingPlacer.clamp(buildingFP, deckFP, current)
    g:PivotTo(m * CFrame.new(table.unpack(BuildingPlacer.placeCF(current))))
end

-- Advance to the next facing (wrapping) that the current building can actually fit in against
-- the deck's placement bounds; a facing whose rotation-aware extents overflow the bounds (B4
-- gate finding: L-on-L facing E/W) is skipped rather than offered. If no OTHER facing fits, this
-- is a no-op (stays on the current facing). Shared by both the HUD button and the R key so they
-- can't drift apart.
local function rotate()
    local idx = table.find(FACING_ORDER, current.facing) or 1
    for _ = 1, #FACING_ORDER - 1 do
        idx = (idx % #FACING_ORDER) + 1
        local candidate = FACING_ORDER[idx]
        if BuildingPlacer.canFitFacing(buildingFP, deckFP, candidate) then
            current.facing = candidate
            applyGhost()
            return
        end
    end
    -- no other facing fits: no-op
end

local function stepDrag()
    local camera = workspace.CurrentCamera
    if camera == nil then
        return
    end
    local pos = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(pos.X, pos.Y)
    local m = mountCF :: CFrame
    local planePoint = m.Position
    local normal = m.UpVector
    local denom = ray.Direction:Dot(normal)
    if math.abs(denom) < 1e-4 then
        return -- camera looking parallel to the deck plane: hold last position
    end
    local t = (planePoint - ray.Origin):Dot(normal) / denom
    if t <= 0 then
        return -- plane is behind the camera: hold last position
    end
    local hitPos = ray.Origin + ray.Direction * t
    local rel = m:PointToObjectSpace(hitPos)
    current = { offset = { math.round(rel.X), math.round(rel.Z) }, facing = current.facing }
    applyGhost()
end

-- ===== Step 5 (declared ahead of buildHud, which references them): commit / exit =====

local function exit()
    if not active then
        return
    end
    active = false
    for _, c in conns do
        c:Disconnect()
    end
    conns = {}
    if ghost then
        ghost:Destroy()
        ghost = nil
    end
    if original then
        fadeOriginal(original, 0)
        for _, prompt in disabledPrompts do
            if prompt.Parent ~= nil then
                prompt.Enabled = true
            end
        end
        disabledPrompts = {}
        original = nil
    end
    if hud then
        hud:Destroy()
        hud = nil
    end
    commitFn = nil
end

local function commit()
    if not active then
        return
    end
    if commitFn then
        commitFn(current.offset, current.facing)
    end
    exit() -- the server rebuild arriving is the confirmation
end

-- ===== Step 4: mode HUD =====

-- Small pinned strip, bottom-center: Rotate / Place / Cancel. Touch users rely on this (no
-- click-to-commit on Touch — see the InputBegan handler in enter()); desktop users can also use
-- keys R / X, or click to commit.
local function buildHud()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MoveHud"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local strip = Instance.new("Frame")
    strip.Name = "Strip"
    strip.AnchorPoint = Vector2.new(0.5, 1)
    strip.Position = UDim2.new(0.5, 0, 1, -24)
    strip.Size = UDim2.fromOffset(360, 44)
    strip.BackgroundTransparency = 1
    strip.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = strip

    local function makeButton(order: number, text: string, onClick: () -> ()): TextButton
        local button = Instance.new("TextButton")
        button.Name = "Btn" .. order
        button.LayoutOrder = order
        button.Size = UDim2.fromOffset(112, 44)
        button.BackgroundColor3 = BG
        button.BackgroundTransparency = 0.1
        button.TextColor3 = TEXT
        button.Font = Enum.Font.Gotham
        button.TextSize = 14
        button.Text = text
        button.Parent = strip
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        button.MouseButton1Click:Connect(onClick)
        return button
    end

    makeButton(1, "⟳ Rotate (R)", rotate)
    makeButton(2, "✓ Place", commit)
    makeButton(3, "✕ Cancel (X)", exit)

    hud = gui
end

-- ===== Step 5: generic core + entries =====

-- descriptor: { original: Model, ghost: Model (already ghostified), footprint, deckFP, mountCF,
--   initialOffset: {n,n}, initialFacing: string, commit: (offset, facing) -> () }
local function startMove(descriptor: any)
    if active then
        return
    end
    active = true
    mountCF = descriptor.mountCF
    buildingFP = descriptor.footprint
    deckFP = descriptor.deckFP
    original = descriptor.original
    commitFn = descriptor.commit
    current = {
        offset = { descriptor.initialOffset[1], descriptor.initialOffset[2] },
        facing = descriptor.initialFacing,
    }
    ghost = descriptor.ghost
    fadeOriginal(descriptor.original, 0.7)
    for _, d in descriptor.original:GetDescendants() do
        if d:IsA("ProximityPrompt") and d.Enabled then
            d.Enabled = false
            table.insert(disabledPrompts, d)
        end
    end
    applyGhost()
    buildHud() -- Step 4's HUD; store in `hud`
    table.insert(conns, RunService.RenderStepped:Connect(stepDrag))
    table.insert(
        conns,
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then
                return
            end
            if input.KeyCode == Enum.KeyCode.R then
                rotate()
            elseif input.KeyCode == Enum.KeyCode.X then
                exit()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                commit() -- desktop: click places. Touch uses the ✓ button (a tap would
                -- commit mid-positioning, so Touch deliberately does NOT commit here)
            end
        end)
    )
    table.insert(conns, descriptor.original.Destroying:Connect(exit)) -- rebuild landed mid-mode
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(conns, humanoid.Died:Connect(exit))
    end
    table.insert(conns, player.CharacterAdded:Connect(exit))
end

-- Resolve a claimed site's deck frame + deck size from a MaterializedSite folder.
local function siteInfo(folder: Instance?): (CFrame?, string?)
    if folder == nil then
        return nil, nil
    end
    local m = folder:GetAttribute("MountCF")
    local deckSize = folder:GetAttribute("DeckSize")
    if typeof(m) ~= "CFrame" or typeof(deckSize) ~= "string" then
        return nil, nil
    end
    return m, deckSize
end

-- Teahouse entry (behavior-equivalent to the pre-generalization enter): ghost the Structure clone,
-- bounds = placementBounds (off the railings), commit -> SetPlacement.
local function enterTeahouse(payload: any)
    if active or typeof(payload) ~= "table" or typeof(payload.padId) ~= "string" then
        return
    end
    local sites = workspace:FindFirstChild("TeahouseSites")
    local folder = sites and sites:FindFirstChild("MaterializedSite_" .. payload.padId)
    local structure = folder and folder:FindFirstChild("Structure")
    local m, deckSize = siteInfo(folder)
    local teaSize = folder and folder:GetAttribute("TeahouseSize")
    if structure == nil or m == nil or deckSize == nil then
        return
    end
    if typeof(teaSize) ~= "string" or teaSize == "" then
        return -- bare deck: nothing to move
    end
    local dx, dz, facing = facingFromPivotOf(structure :: Model, m)
    startMove({
        original = structure,
        ghost = ghostify((structure :: Model):Clone()),
        footprint = SizeClasses.buildingFootprint(teaSize),
        deckFP = SizeClasses.placementBounds(deckSize),
        mountCF = m,
        initialOffset = { math.round(dx), math.round(dz) },
        initialFacing = facing,
        commit = function(offset, f)
            SetPlacement:FireServer({ offset = { offset[1], offset[2] }, facing = f })
        end,
    })
end

-- Decoration entry: ghost a fresh catalog prop, bounds = full deck footprint (props may sit to the
-- edge), commit -> SetDecorationPlacement{ id }.
local function enterDecoration(payload: any)
    if
        active
        or typeof(payload) ~= "table"
        or typeof(payload.id) ~= "number"
        or typeof(payload.propId) ~= "string"
        or typeof(payload.part) ~= "Instance"
    then
        return
    end
    local part = payload.part :: Model
    local folder = part.Parent
    local m, deckSize = siteInfo(folder)
    local fp = DecorationCatalog.footprint(payload.propId)
    if m == nil or deckSize == nil or fp == nil then
        return
    end
    local ghostModel = DecorationCatalog.build(payload.propId)
    if ghostModel == nil then
        return
    end
    local dx, dz, facing = facingFromPivotOf(part, m)
    startMove({
        original = part,
        ghost = ghostify(ghostModel),
        footprint = fp,
        deckFP = SizeClasses.deckFootprint(deckSize),
        mountCF = m,
        initialOffset = { math.round(dx), math.round(dz) },
        initialFacing = facing,
        commit = function(offset, f)
            SetDecorationPlacement:FireServer({
                id = payload.id,
                offset = { offset[1], offset[2] },
                facing = f,
            })
        end,
    })
end

EventBus.MoveTeahouse.Event:Connect(enterTeahouse)
EventBus.MoveDecoration.Event:Connect(enterDecoration)
