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
-- A THIRD attribute decides whether a bay gets a prompt AT ALL: `BayState`, written by
-- StructureOps.applyBays as it applies each bay (2026-08-18 final review, critical). Do NOT go
-- back to `bay:FindFirstChild("Shoji")` for that question. applyBays hides a variant by setting
-- Transparency = 1, never by removing it, so EVERY bay of a stock prefab answers that lookup --
-- and WallBays.defaultState is `solid` for every side except the front. Gating on presence put a
-- "Slide open" prompt on most of the walls in the game, anchored to a visible solid panel, and a
-- hold on one slid an invisible non-colliding leaf. The rule lives in ShojiRun.isSlidable, shared
-- with the server, which gates hold ACCEPTANCE on the same attribute rather than trusting that
-- this controller was willing to ask.
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
-- The unit of state here is ONE BAY, watched independently of every other bay on its wall. It used
-- to be a whole side, rebuilt from scratch on every arrival, because the number this controller
-- fired to the server was the bay's ORDINAL within its side's shoji run -- so a bay arriving late
-- renumbered every other bay after it. The wire now carries the RAW `Bay_<side>_<n>` number and
-- the SERVER maps it to a run ordinal (ShojiRun.ordinalOf), for a correctness reason rather than a
-- tidiness one: this client can only count the bays whose `Shoji` child has replicated to it,
-- while the server always sees the whole wall, so during that window the client's ordinal n named
-- the server's ordinal n+1 and a press slid the NEIGHBOURING screen. With raw numbers, a late
-- arrival can only ever add itself, so nothing about one bay depends on another and there is no
-- hand-copied run collector left on this side of the wire to drift.
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

type BayEntry = {
    padId: string,
    side: string,
    bayNumber: number, -- the raw <n> of Bay_<side>_<n>, which is what goes over the wire
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

-- One per Bay_<side>_<n> model of a bound structure, whether or not it currently has a screen.
-- `stateConn` is the whole point of watching a bay with no entry: a bay toggled from solid to
-- shoji at runtime (the back-door editor re-applies a whole wall live) has to GAIN its prompt
-- without waiting for the structure to be rebuilt, and one toggled the other way has to lose it.
type BayWatch = {
    bay: Model,
    side: string,
    bayNumber: number,
    stateConn: RBXScriptConnection,
    shojiConn: RBXScriptConnection?, -- armed only while the bay's own `Shoji` child is still absent
    entry: BayEntry?,
}

type PadState = {
    padId: string,
    folder: Instance,
    folderAddedConn: RBXScriptConnection?,
    folderRemovedConn: RBXScriptConnection?,
    structure: Model?,
    structureConn: RBXScriptConnection?,
    watches: { [Model]: BayWatch },
    entries: { [string]: BayEntry }, -- keyed "<side>_<bayNumber>", for the ShojiState reply
}

local pads: { [string]: PadState } = {}

local function bayKey(side: string, bayNumber: number): string
    return side .. "_" .. bayNumber
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

local function destroyBayEntry(entry: BayEntry)
    if entry.holding then
        -- (2026-08-18 review fix) An active hold on THIS bay from THIS client: destroying the
        -- prompt does NOT raise PromptButtonHoldEnded the way toggling Enabled does (see the
        -- ShojiState handler below), so without this the server never hears the hold stopped and
        -- keeps sliding a screen nothing is rendering anymore, until the player wanders out of
        -- reach. Fire the release ourselves before tearing anything down.
        SlideShoji:FireServer({
            padId = entry.padId,
            side = entry.side,
            bay = entry.bayNumber,
            held = false,
        })
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
    bayNumber: number,
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
    entry.bayNumber = bayNumber
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
        SlideShoji:FireServer({ padId = padId, side = side, bay = bayNumber, held = true })
    end)
    prompt.PromptButtonHoldEnded:Connect(function()
        entry.holding = false
        SlideShoji:FireServer({ padId = padId, side = side, bay = bayNumber, held = false })
    end)

    entry.attrConn = bay:GetAttributeChangedSignal("ShojiOpen"):Connect(function()
        local nowOpen = currentOpen(bay)
        entry.prompt.ActionText = actionTextFor(nowOpen)
        retarget(entry, nowOpen)
    end)

    return entry
end

-- Bring ONE bay's prompt into agreement with what that bay currently IS. Called on first sight of
-- the bay, whenever its `BayState` changes, and when its `Shoji` child finally replicates. A bay
-- only earns a prompt when its resolved state is shoji AND the leaf to slide has actually arrived;
-- anything else tears down whatever it had. Idempotent, so every one of those triggers can fire in
-- the same tick without churning the prompt.
local function refreshBay(padState: PadState, structure: Model, watch: BayWatch)
    local leaf = watch.bay:FindFirstChild("Shoji")
    local hasLeaf = leaf ~= nil and leaf:IsA("Model")
    -- A bay model can replicate before its own descendants do (a replicated subtree's children can
    -- land after its root's ChildAdded fires on the client, per BackDoorController's own note), so
    -- a shoji bay may briefly have no leaf. Watch once for it; the arrival re-runs this function.
    if hasLeaf then
        if watch.shojiConn then
            watch.shojiConn:Disconnect()
            watch.shojiConn = nil
        end
    elseif watch.shojiConn == nil then
        watch.shojiConn = watch.bay.ChildAdded:Connect(function(child)
            if child.Name == "Shoji" then
                refreshBay(padState, structure, watch)
            end
        end)
    end

    local want = hasLeaf and ShojiRun.isSlidable(watch.bay:GetAttribute("BayState"))
    local key = bayKey(watch.side, watch.bayNumber)
    if want and watch.entry == nil then
        local entry = createBayEntry(padState.padId, structure, watch.side, watch.bayNumber, watch.bay)
        if entry then
            watch.entry = entry
            padState.entries[key] = entry
        end
    elseif not want and watch.entry ~= nil then
        destroyBayEntry(watch.entry)
        watch.entry = nil
        padState.entries[key] = nil
    end
end

local function destroyWatch(padState: PadState, watch: BayWatch)
    watch.stateConn:Disconnect()
    if watch.shojiConn then
        watch.shojiConn:Disconnect()
        watch.shojiConn = nil
    end
    if watch.entry then
        destroyBayEntry(watch.entry)
        padState.entries[bayKey(watch.side, watch.bayNumber)] = nil
        watch.entry = nil
    end
    padState.watches[watch.bay] = nil
end

local function clearWatches(padState: PadState)
    for _, watch in padState.watches do
        destroyWatch(padState, watch)
    end
    padState.watches = {}
    padState.entries = {}
end

-- Start (or re-run) the watch on one Bay_<side>_<n> model. Deduped per bay INSTANCE: a structure
-- whose ChildAdded fires again for a bay already seen must not stack a second `BayState` listener
-- on it, each firing its own refresh in the same tick.
local function watchBay(padState: PadState, structure: Model, child: Instance)
    if not child:IsA("Model") then
        return
    end
    local side, numStr = child.Name:match("^Bay_(%a+)_(%d+)$")
    if side == nil or numStr == nil then
        return
    end
    if ShojiRun.runAxis(side) == nil then
        return -- a side with no run direction has nothing this controller can slide
    end
    local bay = child :: Model
    local existing = padState.watches[bay]
    if existing ~= nil then
        refreshBay(padState, structure, existing)
        return
    end
    local watch = {} :: BayWatch
    watch.bay = bay
    watch.side = side
    watch.bayNumber = tonumber(numStr) :: number
    watch.shojiConn = nil
    watch.entry = nil
    watch.stateConn = bay:GetAttributeChangedSignal("BayState"):Connect(function()
        refreshBay(padState, structure, watch)
    end)
    padState.watches[bay] = watch
    refreshBay(padState, structure, watch)
end

-- Bind to whichever Structure currently lives under this pad's site folder. Idempotent per
-- structure instance, same discipline as BackDoorController.bindStructure: switching to a
-- genuinely new structure drops every bay watch (they belonged to the dead structure) and
-- rebuilds them from the newcomer's own children.
local function bindStructure(padState: PadState, structure: Model)
    if padState.structure == structure then
        return
    end
    if padState.structureConn then
        padState.structureConn:Disconnect()
        padState.structureConn = nil
    end
    clearWatches(padState)
    padState.structure = structure
    for _, child in structure:GetChildren() do
        watchBay(padState, structure, child)
    end
    -- A replicated subtree's descendants can land after the Structure root's own ChildAdded
    -- fires on the client, so a Bay_<side>_<n> may still be arriving after the sweep above.
    padState.structureConn = structure.ChildAdded:Connect(function(child)
        watchBay(padState, structure, child)
    end)
end

local function unbindStructure(padState: PadState)
    if padState.structureConn then
        padState.structureConn:Disconnect()
        padState.structureConn = nil
    end
    clearWatches(padState)
    padState.structure = nil
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
            watches = {},
            entries = {},
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
            unbindStructure(padState :: PadState)
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
-- bay, and that the bay's own `BayState` really is shoji -- so a hold this client thinks it
-- started can be refused (ShojiState.accepted == false) without ShojiOpen ever changing. An
-- acceptance needs no action here: the attribute listener above already renders whatever the hold
-- loop writes. A refusal does, though -- the player is still physically holding G, HoldDuration is
-- 60s, and the built-in progress ring would keep filling for up to a minute with nothing moving,
-- which reads as the game being stuck. Toggling Enabled off and back on cancels an in-progress
-- hold (Roblox fires PromptButtonHoldEnded for it) and re-arms the prompt for a fresh attempt once
-- the player is back in reach.
ShojiState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" or payload.accepted ~= false then
        return
    end
    local padId = payload.padId
    local side = payload.side
    local bayNumber = payload.bay
    if typeof(padId) ~= "string" or typeof(side) ~= "string" or typeof(bayNumber) ~= "number" then
        return
    end
    local padState = pads[padId]
    local entry = padState and padState.entries[bayKey(side, bayNumber)]
    if entry == nil then
        return
    end
    entry.prompt.Enabled = false
    task.defer(function()
        entry.prompt.Enabled = true
    end)
end)
