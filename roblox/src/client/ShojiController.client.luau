--!strict
-- Client prompts and tween for sliding shoji screens (task 6). Renders `main.server.luau`'s
-- "SHOJI: HOLD TO SLIDE" section and StructureOps.applyShoji/syncShojiBay.
--
-- TARGET vs APPLIED -- read this before touching `ShojiApplied`. Each shoji bay carries TWO
-- number attributes. `ShojiOpen` is the TARGET: where the screen is sliding to, rewritten many
-- times a second by the server's hold loop without ever moving an Instance. `ShojiApplied` is
-- where the SERVER'S OWN geometry has actually been moved to, written once at hold end (by
-- StructureOps.syncShojiBay) purely so the server can reconcile its own collision copy. This
-- controller renders ONLY `ShojiOpen`. A client that rendered from `ShojiApplied` would sit still
-- for the whole hold and then jump at the end, because that attribute doesn't move until the hold
-- is over.
--
-- Lifecycle, copied in SHAPE from BackDoorController.client.luau, which solved the hard part of
-- this once already -- see its own header for the full "why RemoteEvents aren't ordered against
-- replication" story. One structural difference from that controller: BackDoorController binds to
-- a SINGLE padId handed to it by a per-player event, because editing your back door is a
-- private session on your own teahouse. Shoji screens are a general mechanic -- ANY player can
-- slide a screen on ANY teahouse (the server's gate is a plausible-reach check, not ownership) --
-- so this controller instead watches the WHOLE TeahouseSites folder, the same breadth
-- PerchPreferenceController and EconomyController use for their own all-sites prompts. Within
-- each site, though, the watchFolder/bindStructure/late-ChildAdded lifecycle is
-- BackDoorController's, one instance per padId: a teahouse's Structure is destroyed and rebuilt
-- under its stable site folder (MaterializedSite_<padId>) on every buy/upgrade/edit, so binding
-- prompts at event-arrival time would be racy and could silently miss a teahouse.
--
-- One level deeper than BackDoorController's late-arrival handling: there, a bay's INDEX is its
-- own raw `Bay_back_<i>` number, so a late-arriving bay only ever adds itself. Here, the `index`
-- fired to the server is the bay's ORDINAL WITHIN ITS SIDE'S SHOJI RUN -- the bays of that side
-- that carry a `Shoji` variant, in ascending Bay_<side>_<n> order, exactly as
-- StructureOps.applyShoji and main.server.luau's collectShojiRun collect it -- so a late-arriving
-- bay (or a bay whose OWN `Shoji` child hasn't replicated in yet) can change every OTHER bay's
-- ordinal on that side. `rebuildSide` below always recomputes and rebinds a side's entire run from
-- scratch rather than patching one bay in place, so a late arrival never leaves a stale ordinal
-- pointed at the wrong screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SlideShoji = remotes:WaitForChild("SlideShoji") :: RemoteEvent
local ShojiState = remotes:WaitForChild("ShojiState") :: RemoteEvent

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local ShojiRun = require(shared:WaitForChild("ShojiRun"))

-- Short enough to read as driven by the hold (a stalled screen would feel laggy), long enough to
-- smooth over the server's per-frame attribute writes (a 0s snap would visibly stutter at the
-- server's own tick rate). Linear, not eased: this is a continuous hold, not a one-shot flourish.
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Linear)

-- ShojiRun.runAxis is the ONE source for "front/back run along local X, left/right along local Z"
-- (2026-08-18 review fix: this used to be a hand-copy of StructureOps.SHOJI_RUN_AXIS_LOCAL, and a
-- server-only module the client can't require anyway). It returns a plain {x,y,z} -- Vector3 is a
-- Roblox global, absent from the Lune runtime that module is tested under -- wrapped into a
-- Vector3 here, at the Roblox boundary.
local function runAxisVector(side: string): Vector3?
    local axis = ShojiRun.runAxis(side)
    return if axis then Vector3.new(axis.x, axis.y, axis.z) else nil
end
local SIDES = { "front", "back", "left", "right" }

type BayEntry = {
    padId: string,
    side: string,
    ordinal: number,
    bay: Model,
    leaf: Model,
    prompt: ProximityPrompt,
    homePivot: CFrame,
    worldDir: Vector3,
    value: NumberValue,
    tween: Tween?,
    holding: boolean, -- this CLIENT currently has an accepted-or-pending hold in flight on it
    valueConn: RBXScriptConnection,
    attrConn: RBXScriptConnection,
}

type PadState = {
    padId: string,
    folder: Instance,
    folderAddedConn: RBXScriptConnection?,
    folderRemovedConn: RBXScriptConnection?,
    structure: Model?,
    structureConn: RBXScriptConnection?,
    bays: { [string]: BayEntry }, -- keyed "<side>_<ordinal>"
    pendingShojiWatchers: { [Model]: RBXScriptConnection }, -- bays still missing their Shoji child
}

local pads: { [string]: PadState } = {}

local function bayKey(side: string, ordinal: number): string
    return side .. "_" .. ordinal
end

-- A screen already open should not offer to open further -- the prompt only ever knows "shut" vs
-- "not shut", not how far open it is.
local function actionTextFor(open: number): string
    return if open == 0 then "Slide open" else "Slide shut"
end

local function currentOpen(bay: Model): number
    local attr = bay:GetAttribute("ShojiOpen")
    return if typeof(attr) == "number" then attr else 0
end

-- Anchor the prompt to the bay's FIXED wall location -- its Solid panel -- never the Shoji leaf,
-- which is the very thing this controller moves; a prompt riding it would drag off its own bay
-- the moment the screen slid (the same trap BackDoorController.anchorPart documents for the back
-- door's Door variant).
local function anchorPart(bay: Model): BasePart?
    local solid = bay:FindFirstChild("Solid")
    local solidPart = solid and solid:FindFirstChildWhichIsA("BasePart", true)
    if solidPart then
        return solidPart
    end
    if bay.PrimaryPart then
        return bay.PrimaryPart
    end
    return bay:FindFirstChildWhichIsA("BasePart", true)
end

-- The same bay-run collection StructureOps.applyShoji/main.server.luau's collectShojiRun use:
-- Bay_<side>_<n> models that carry a `Shoji` variant, ascending by n. Kept in sync BY HAND with
-- those, because the server's `index` names nothing on this client unless the list is identical.
local function collectRun(structure: Model, side: string): { { rawIndex: number, bay: Model } }
    local list: { { rawIndex: number, bay: Model } } = {}
    for _, c in structure:GetChildren() do
        if c:IsA("Model") then
            local s, idxStr = c.Name:match("^Bay_(%a+)_(%d+)$")
            if s == side then
                local shoji = c:FindFirstChild("Shoji")
                if shoji and shoji:IsA("Model") then
                    table.insert(list, { rawIndex = tonumber(idxStr) :: number, bay = c })
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return a.rawIndex < b.rawIndex
    end)
    return list
end

local function destroyBayEntry(entry: BayEntry)
    if entry.holding then
        -- (2026-08-18 review fix) An active hold on THIS bay from THIS client: destroying the
        -- prompt does NOT raise PromptButtonHoldEnded the way toggling Enabled does (see the
        -- ShojiState handler below), so without this the server never hears the hold stopped and
        -- keeps sliding a screen nothing is rendering anymore, until the player wanders out of
        -- reach. Fire the release ourselves before tearing anything down.
        SlideShoji:FireServer({ padId = entry.padId, side = entry.side, index = entry.ordinal, held = false })
        entry.holding = false
    end
    if entry.tween then
        entry.tween:Cancel()
    end
    -- entry.bay is NOT ours to destroy (it's server-owned geometry, alive or about to be
    -- rebuilt); only disconnect what we attached to it.
    entry.attrConn:Disconnect()
    entry.prompt:Destroy()
    entry.value:Destroy() -- also disconnects entry.valueConn, an event of this same instance
end

-- Retarget, don't fight, an in-flight tween: Cancel leaves the NumberValue at whatever it had
-- already interpolated to (TweenService never resets on Cancel), and a new Tween always plays
-- FROM an object's CURRENT property value -- so a change arriving mid-tween picks up exactly
-- where the old one left off instead of snapping back to the previous target first.
local function retarget(entry: BayEntry, open: number)
    if entry.tween then
        entry.tween:Cancel()
    end
    local tween = TweenService:Create(entry.value, TWEEN_INFO, { Value = open })
    entry.tween = tween
    tween:Play()
end

local function createBayEntry(
    padId: string,
    structure: Model,
    side: string,
    ordinal: number,
    bay: Model
): BayEntry?
    local leafChild = bay:FindFirstChild("Shoji")
    if not (leafChild and leafChild:IsA("Model")) then
        return nil
    end
    local leaf = leafChild :: Model
    local anchor = anchorPart(bay)
    if anchor == nil then
        return nil
    end
    local localAxis = runAxisVector(side)
    if not localAxis then
        return nil
    end

    -- the STRUCTURE's own placed pivot, not the leaf's: a side-wall leaf is itself yawed 90
    -- degrees by how the prefab was authored, so its OWN local X is not the wall's run direction.
    -- Converting through the structure's pivot (not a bare world axis) is what keeps a slide on
    -- the wall plane when the teahouse's pad sits at a yaw, per StructureOps.applyShoji's own
    -- review note.
    local worldDir = structure:GetPivot():VectorToWorldSpace(localAxis)
    local open = currentOpen(bay)
    -- Home MUST be derived from `ShojiApplied`, not `ShojiOpen` (2026-08-18 review fix, critical).
    -- `ShojiOpen` is the TARGET, rewritten many times a second by a hold; the leaf's actual pose
    -- only ever moves at materialize and at hold END, when the server reconciles it and writes
    -- `ShojiApplied` to match. During somebody ELSE's hold, `ShojiOpen` and the leaf's real pose
    -- are the same number only when nobody is holding -- a bind mid-hold (a late joiner, a
    -- reconnect, this side's own rebuild racing a stranger's hold) would read a target of, say,
    -- 0.9 against a leaf still sitting at 0.1, and cache a home 4.8 studs off. Nothing snaps at
    -- that instant because the algebra cancels; every render after it is simply wrong for this
    -- client alone, until the whole structure rebuilds. `ShojiApplied` is read ONCE, here, for
    -- this derivation and nothing else -- it must NOT be re-read on a later change (the server
    -- writes it at every hold end; re-deriving home there would shift the screen by its own
    -- travel). Render below still comes only from `ShojiOpen`.
    local appliedAttr = bay:GetAttribute("ShojiApplied")
    local applied = if typeof(appliedAttr) == "number" then appliedAttr else 0
    local homePivot = leaf:GetPivot() + worldDir * (-ShojiRun.displacement(applied))

    local value = Instance.new("NumberValue")
    value.Value = open

    local entry = {} :: BayEntry
    entry.padId = padId
    entry.side = side
    entry.ordinal = ordinal
    entry.bay = bay
    entry.leaf = leaf
    entry.homePivot = homePivot
    entry.worldDir = worldDir
    entry.value = value
    entry.tween = nil
    entry.holding = false

    entry.valueConn = value.Changed:Connect(function(v: number)
        entry.leaf:PivotTo(entry.homePivot + entry.worldDir * ShojiRun.displacement(v))
    end)

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = actionTextFor(open)
    prompt.ObjectText = "Shoji screen"
    -- G, not the default E or BackDoorController's F: E belongs to the Favorite prompt
    -- (PerchPreferenceController) and F to the back-door editor, both possibly live on the same
    -- teahouse at once, and Roblox shows only the closest prompt sharing a key.
    prompt.KeyboardKeyCode = Enum.KeyCode.G
    prompt.HoldDuration = 60 -- never completes; the HOLD drives the slide, not a fire-on-complete
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = anchor
    entry.prompt = prompt

    prompt.PromptButtonHoldBegan:Connect(function()
        entry.holding = true
        SlideShoji:FireServer({ padId = padId, side = side, index = ordinal, held = true })
    end)
    prompt.PromptButtonHoldEnded:Connect(function()
        entry.holding = false
        SlideShoji:FireServer({ padId = padId, side = side, index = ordinal, held = false })
    end)

    entry.attrConn = bay:GetAttributeChangedSignal("ShojiOpen"):Connect(function()
        local nowOpen = currentOpen(bay)
        entry.prompt.ActionText = actionTextFor(nowOpen)
        retarget(entry, nowOpen)
    end)

    return entry
end

-- Recompute and rebind this side's ENTIRE run from the structure's current children. Called on
-- first bind and on every later ChildAdded that could have changed the run's membership, rather
-- than patching one bay in place, because a late arrival can shift every OTHER bay's ordinal.
local function rebuildSide(padState: PadState, structure: Model, side: string)
    for key, entry in padState.bays do
        if entry.side == side then
            destroyBayEntry(entry)
            padState.bays[key] = nil
        end
    end
    local run = collectRun(structure, side)
    for ordinal, item in run do
        local entry = createBayEntry(padState.padId, structure, side, ordinal, item.bay)
        if entry then
            padState.bays[bayKey(side, ordinal)] = entry
        end
    end
    -- A Bay_<side>_<n> model can itself have replicated before its OWN `Shoji` descendant does
    -- (a replicated subtree's descendants can land after its root's ChildAdded fires on the
    -- client, per BackDoorController's own note) -- such a bay is silently excluded from `run`
    -- above (same as a bay with no shoji variant at all, an entirely ordinary shape). Watch it
    -- once for that child; when it lands, this side's whole run is rebuilt again so the newcomer
    -- gets counted and every following ordinal shifts correctly.
    --
    -- Deduped per BAY INSTANCE in `padState.pendingShojiWatchers` (2026-08-18 review fix): without
    -- this, a wall that rebuilds twice while a bay is still streaming in got a FRESH watcher on
    -- every rebuildSide call, on top of whichever one from the previous call was still armed and
    -- waiting on the same bay -- every one of them would fire on arrival, each triggering its own
    -- full-side rebuild in the same tick. A bay already being watched is skipped outright; there
    -- is nothing to refresh, since the watcher fires on the CHILD landing, not on anything about
    -- this rebuild.
    for _, c in structure:GetChildren() do
        if c:IsA("Model") then
            local s = c.Name:match("^Bay_(%a+)_%d+$")
            if s == side and not c:FindFirstChild("Shoji") and padState.pendingShojiWatchers[c] == nil then
                local watched = c
                local conn: RBXScriptConnection
                conn = watched.ChildAdded:Connect(function(child)
                    if child.Name == "Shoji" then
                        padState.pendingShojiWatchers[watched] = nil
                        conn:Disconnect()
                        rebuildSide(padState, structure, side)
                    end
                end)
                padState.pendingShojiWatchers[watched] = conn
            end
        end
    end
end

-- Drop every late-arrival watcher this pad has armed (structure switch, or its site folder losing
-- its Structure with no replacement): each one is on a bay belonging to a structure that is now
-- dead or about to be, so none of them should fire a rebuild for a side that's about to be, or
-- just was, rebuilt from scratch anyway.
local function clearPendingWatchers(padState: PadState)
    for bay, conn in padState.pendingShojiWatchers do
        conn:Disconnect()
        padState.pendingShojiWatchers[bay] = nil
    end
end

-- Bind to whichever Structure currently lives under this pad's site folder. Idempotent per
-- structure instance, same discipline as BackDoorController.bindStructure: switching to a
-- genuinely new structure drops every bay entry (they belonged to the dead structure) and
-- rebuilds all four sides from scratch.
local function bindStructure(padState: PadState, structure: Model)
    if padState.structure == structure then
        return
    end
    if padState.structureConn then
        padState.structureConn:Disconnect()
        padState.structureConn = nil
    end
    for _, entry in padState.bays do
        destroyBayEntry(entry)
    end
    padState.bays = {}
    clearPendingWatchers(padState)
    padState.structure = structure
    for _, side in SIDES do
        rebuildSide(padState, structure, side)
    end
    -- A replicated subtree's descendants can land after the Structure root's own ChildAdded
    -- fires on the client, so a Bay_<side>_<n> may still be arriving after the sweep above.
    padState.structureConn = structure.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            local side = child.Name:match("^Bay_(%a+)_%d+$")
            if side and ShojiRun.runAxis(side) then
                rebuildSide(padState, structure, side)
            end
        end
    end)
end

-- Watch one site folder (MaterializedSite_<padId>) for whichever Structure lives under it. This
-- connection persists for as long as the folder does -- what makes RemoteEvent/replication
-- ordering irrelevant here, same as BackDoorController.watchFolder: whenever a new Structure
-- lands under this folder, for ANY reason (buy-to-claim, size upgrade, display change, a door or
-- shoji edit that re-renders geometry), it gets bound. A torn-down-to-bare-deck site (Structure
-- removed with no replacement) drops this pad's bay entries too, so nothing lingers pointed at
-- destroyed instances.
local function watchFolder(padId: string, folder: Instance)
    local padState = pads[padId]
    if padState == nil then
        padState = {
            padId = padId,
            folder = folder,
            folderAddedConn = nil,
            folderRemovedConn = nil,
            structure = nil,
            structureConn = nil,
            bays = {},
            pendingShojiWatchers = {},
        }
        pads[padId] = padState
    end
    if padState.folderAddedConn ~= nil then
        return -- already watching this pad
    end
    padState.folderAddedConn = folder.ChildAdded:Connect(function(child)
        if child.Name == "Structure" and child:IsA("Model") then
            bindStructure(padState :: PadState, child)
        end
    end)
    padState.folderRemovedConn = folder.ChildRemoved:Connect(function(child)
        if child == padState.structure then
            if padState.structureConn then
                padState.structureConn:Disconnect()
                padState.structureConn = nil
            end
            for _, entry in padState.bays do
                destroyBayEntry(entry)
            end
            padState.bays = {}
            clearPendingWatchers(padState)
            padState.structure = nil
        end
    end)
    -- Covers the event-after-replication order: the Structure may already be there by the time
    -- this starts watching (ChildAdded only fires for children added AFTER connecting).
    local existing = folder:FindFirstChild("Structure")
    if existing and existing:IsA("Model") then
        bindStructure(padState, existing)
    end
end

local function bindSite(folder: Instance)
    local padId = folder.Name:match("^MaterializedSite_(.+)$")
    if not padId then
        return
    end
    watchFolder(padId, folder)
end

local sitesFolder = workspace:WaitForChild("TeahouseSites")
for _, f in sitesFolder:GetChildren() do
    bindSite(f)
end
sitesFolder.ChildAdded:Connect(bindSite)

-- The server never trusts that a prompt fired -- only that the player could plausibly reach the
-- bay -- so a hold this client thinks it started can be refused (ShojiState.accepted == false)
-- without ShojiOpen ever changing. An acceptance needs no action here: the attribute listener
-- above already renders whatever the hold loop writes. A refusal does, though -- the player is
-- still physically holding G, HoldDuration is 60s, and the built-in progress ring would keep
-- filling for up to a minute with nothing moving, which reads as the game being stuck. Toggling
-- Enabled off and back on cancels an in-progress hold (Roblox fires PromptButtonHoldEnded for it)
-- and re-arms the prompt for a fresh attempt once the player is back in reach.
ShojiState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" or payload.accepted ~= false then
        return
    end
    local padId = payload.padId
    local side = payload.side
    local index = payload.index
    if typeof(padId) ~= "string" or typeof(side) ~= "string" or typeof(index) ~= "number" then
        return
    end
    local padState = pads[padId]
    local entry = padState and padState.bays[bayKey(side, index)]
    if entry == nil then
        return
    end
    entry.prompt.Enabled = false
    task.defer(function()
        entry.prompt.Enabled = true
    end)
end)
