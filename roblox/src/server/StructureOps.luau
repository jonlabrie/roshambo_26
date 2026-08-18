--!strict
-- Runtime `ops` adapter for A's StructureBuilder (injected in main.server.luau).
-- recolor/setTexture are productionized verbatim from the throwaway
-- tools/studio/materializeStructureDemo.luau; readManifest/clonePrefab/pivotTo/applyBays are new.
-- Roblox datatypes -> not Lune-testable; proven by the D.1 visual gate.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ShojiRun = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("ShojiRun"))

local StructureOps = {}

function StructureOps.clonePrefab(prefabName: string): Model
    local prefabs = ServerStorage:FindFirstChild("StructurePrefabs")
    local prefab = prefabs and prefabs:FindFirstChild(prefabName)
    if not prefab then
        error(`StructureOps.clonePrefab: no prefab named '{prefabName}' under ServerStorage.StructurePrefabs`)
    end
    return prefab:Clone() :: Model
end

function StructureOps.readManifest(model: Model): any
    local roleSet: { [string]: boolean } = {}
    local shojiSet: { [number]: boolean } = {}
    local flagSet: { [string]: boolean } = {}
    local hasTatami = false
    local bays: { { side: string, index: number } } = {}
    for _, d in model:GetDescendants() do
        for _, tag in CollectionService:GetTags(d) do
            local role = string.match(tag, "^Role_(.+)$")
            if role then
                roleSet[role] = true
            elseif tag == "ShojiBay" then
                local bay = d:GetAttribute("Bay")
                if typeof(bay) == "number" then
                    shojiSet[bay] = true
                end
            elseif tag == "Bay" then
                local side = d:GetAttribute("Side")
                local index = d:GetAttribute("Index")
                if typeof(side) == "string" and typeof(index) == "number" then
                    table.insert(bays, { side = side, index = index })
                end
            elseif tag == "Tatami" then
                hasTatami = true
            elseif string.match(tag, "^FlagMount") then
                flagSet[tag] = true
            end
        end
    end
    local roles, shojiBays, flagMounts = {}, {}, {}
    for r in roleSet do
        table.insert(roles, r)
    end
    for b in shojiSet do
        table.insert(shojiBays, b)
    end
    for fm in flagSet do
        table.insert(flagMounts, fm)
    end
    return {
        roles = roles,
        shojiBays = shojiBays,
        hasTatami = hasTatami,
        flagMounts = flagMounts,
        bays = bays,
    }
end

-- Show each bay's chosen variant (Solid/Shoji/Door) and hide the other two. Variant models are
-- named after their state (capitalised); each authored part carries a ShownTransparency attribute.
-- Shown parts restore that transparency and collide iff visible (the neon ShojiGlow stays
-- transparent + non-colliding); hidden parts go fully transparent + non-colliding so players
-- cannot hit an invisible wall. A missing bay model / state / variant warns and is skipped so the
-- bay keeps its authored default rather than being blanked (F2/F4).
local STATE_VARIANT = { solid = "Solid", shoji = "Shoji", door = "Door" }
function StructureOps.applyBays(model: Model, bays: { { side: string, index: number, state: string } })
    local byName: { [string]: Model } = {}
    for _, c in model:GetChildren() do
        if c:IsA("Model") and c.Name:match("^Bay_%a+_%d+$") then
            byName[c.Name] = c
        end
    end
    for _, b in bays do
        local bayName = `Bay_{b.side}_{b.index}`
        local bay = byName[bayName]
        local shownName = STATE_VARIANT[b.state]
        local shownModel = if bay and shownName then bay:FindFirstChild(shownName) else nil
        if not bay then
            warn(`[StructureOps] applyBays: no bay model '{bayName}'`)
        elseif not shownName then
            warn(`[StructureOps] applyBays: unknown state '{b.state}' for '{bayName}'`)
        elseif not shownModel then
            warn(`[StructureOps] applyBays: bay '{bayName}' missing '{shownName}' variant`)
        else
            -- The bay's RESOLVED state, stamped where everyone downstream can read it (2026-08-18
            -- final review, critical). Nothing else in the place can answer "is this bay actually a
            -- shoji screen right now": the loop below hides a variant by transparency, never by
            -- removing it, so a solid bay still owns (and answers FindFirstChild for) its Shoji
            -- model. ShojiController gated its prompts on that presence and the SlideShoji handler
            -- gated its holds on it, which put a "Slide open" prompt on nearly every wall in the
            -- game -- WallBays.defaultState is `solid` for every side but the front -- and let the
            -- server slide, sync and persist an invisible non-colliding leaf behind the panel the
            -- player was looking at. Attributes replicate, so one write here serves both sides of
            -- the wire; both read it through ShojiRun.isSlidable. Written only on a bay that was
            -- actually applied: a warned-and-skipped bay above keeps its authored default, and
            -- claiming a state for it would be a lie a prompt would act on.
            bay:SetAttribute("BayState", b.state)
            for _, variant in bay:GetChildren() do
                if variant:IsA("Model") then
                    local vis = variant == shownModel
                    for _, p in variant:GetDescendants() do
                        if p:IsA("BasePart") then
                            if vis then
                                local st = p:GetAttribute("ShownTransparency")
                                p.Transparency = if typeof(st) == "number" then st else 0
                                p.CanCollide = p.Transparency < 1
                            else
                                p.Transparency = 1
                                p.CanCollide = false
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Which axis of the STRUCTURE's own LOCAL frame a side's shoji screens slide along: front/back
-- bays step along local X, left/right along local Z. This mirrors
-- tools/studio/trackShojiBays.luau's RUN_AXIS in spirit, but that tool applies its axis in WORLD
-- space because it runs on an unplaced prefab sitting in ServerStorage, where local and world
-- agree. applyShoji never gets that luxury -- it only ever runs on an already-placed structure
-- (TreatmentApplier calls it straight after structureBuilder.build has pivoted the model onto its
-- pad; SetBackDoor calls it on a live, already-placed structure) -- so a fixed WORLD axis here
-- would push every screen off the wall plane by an amount that grows with the pad's yaw and the
-- size of the slide. Caught in review round 1: on a pad yawed ~12.7 degrees, a plain world-X delta
-- for a 6-stud (one bay-width) slide landed the leaf ~1.3 studs off the wall, and an 18-stud
-- three-bay stack drifted ~4 studs off. The fix is to convert the LOCAL run axis to a world
-- direction via the structure's own placed pivot (CFrame:VectorToWorldSpace), every call, rather
-- than assuming world axes ever line up with the wall.
--
-- The axis-per-side rule itself lives in ShojiRun.runAxis (2026-08-18 review fix) -- the shared,
-- Lune-tested module -- not a local copy here: ShojiController.client.luau needs the identical
-- rule and a hand-copy on each side of the wire is exactly the kind of drift that pushed a screen
-- off its own wall plane in the first place. This wraps its plain {x,y,z} in a Vector3 at the
-- Roblox boundary.
local function runAxisVector(side: string): Vector3?
    local axis = ShojiRun.runAxis(side)
    return if axis then Vector3.new(axis.x, axis.y, axis.z) else nil
end

-- Slide each side's shoji screens to the travel recorded in `shojiOpen` (a per-side list of
-- bay-widths; see ShojiRun). A SIDE'S RUN IS ONLY THE BAYS THAT CARRY A `Shoji` VARIANT, in
-- ascending Bay_<side>_<index> order -- the same rule tools/studio/trackShojiBays.luau used when
-- it cut the channels, because the groove ordinal a screen's geometry was tracked against is its
-- position within that subset, not its raw bay index. A bay modelled with no Shoji variant (this
-- prefab's plain Bay_left_*/Bay_right_* wall segments, say) earns no ordinal and must not be
-- counted, or every real screen would be shifted one channel deeper than the geometry expects.
-- This is an entirely ORDINARY shape (the small teahouse has no side screens at all) so it is
-- skipped SILENTLY -- warning here would fire on every materialize of every such teahouse.
--
-- TWO attributes, not one (2026-08-18 review fix). `ShojiOpen` is the TARGET -- what the screen is
-- sliding to, freely rewritten many times a second by the SlideShoji hold loop in main.server.luau
-- without ever touching an Instance. `ShojiApplied` is where the server's own geometry actually
-- is. This function is the only thing that ever moves a leaf, and it does so by the DIFFERENCE
-- between `open` (the resolved target) and `ShojiApplied` (what was last actually applied) -- NOT
-- `ShojiOpen`, which the hold loop may have already dragged far ahead of the geometry. Applying the
-- delta against `ShojiOpen` instead would read the target as its own basis and move nothing.
--
-- Idempotent, and safe to call more than once on the same model (a re-render after a door edit,
-- for instance): each leaf's HOME is not cached anywhere -- the model this runs against can be
-- destroyed and rebuilt out from under a module-level cache -- so home is instead read back from
-- the bay's own `ShojiApplied` attribute (absent means 0, i.e. the leaf is at home). A call moves
-- the leaf by the DIFFERENCE between the new travel and whatever that attribute already says, so
-- calling twice with the same shojiOpen is a no-op and repeated calls never accumulate drift.
-- A missing/unrecognised side is warned and skipped, same failure posture as applyBays (F2/F4).
function StructureOps.applyShoji(model: Model, shojiOpen: { [string]: any }?)
    local bySide: { [string]: { { index: number, bay: Model, shoji: Model } } } = {}
    for _, c in model:GetChildren() do
        if c:IsA("Model") then
            local side, idxStr = c.Name:match("^Bay_(%a+)_(%d+)$")
            if side then
                local shoji = c:FindFirstChild("Shoji")
                if shoji and shoji:IsA("Model") then
                    local list = bySide[side]
                    if not list then
                        list = {}
                        bySide[side] = list
                    end
                    table.insert(list, { index = tonumber(idxStr) :: number, bay = c, shoji = shoji })
                end
            end
        end
    end

    -- the structure's OWN placed frame, not the leaf's: a side-wall leaf is itself yawed 90
    -- degrees by how the prefab was authored, so ITS local X is not the wall's run direction --
    -- the structure's frame is the one every bay's coordinates were authored against.
    local structurePivot = model:GetPivot()

    for side, list in bySide do
        table.sort(list, function(a, b)
            return a.index < b.index
        end)
        local localAxis = runAxisVector(side)
        if not localAxis then
            warn(`[StructureOps] applyShoji: unrecognised side '{side}'`)
        else
            local count = #list
            local storedSide = if shojiOpen then shojiOpen[side] else nil
            -- shojiOpen[side] should be a per-bay list or absent. Anything else -- a stray
            -- boolean/number left by an older document shape -- is malformed data that should
            -- not exist, so (unlike the silent skip above) this DOES warn: ShojiRun.resolve
            -- would already treat it as absent, but the warning is what tells us the data is
            -- bad rather than just "this house has no shoji open".
            if storedSide ~= nil and typeof(storedSide) ~= "table" then
                warn(
                    `[StructureOps] applyShoji: shojiOpen.{side} is a {typeof(storedSide)}, not a list; treating as closed`
                )
                storedSide = nil
            end
            local resolved = ShojiRun.resolve(storedSide, count)
            local worldDir = structurePivot:VectorToWorldSpace(localAxis)
            for ordinal, entry in list do
                local open = resolved[ordinal]
                local prevAppliedAttr = entry.bay:GetAttribute("ShojiApplied")
                local prevApplied = if typeof(prevAppliedAttr) == "number" then prevAppliedAttr else 0
                local deltaStuds = ShojiRun.displacement(open) - ShojiRun.displacement(prevApplied)
                if deltaStuds ~= 0 then
                    entry.shoji:PivotTo(entry.shoji:GetPivot() + worldDir * deltaStuds)
                end
                entry.bay:SetAttribute("ShojiOpen", open)
                entry.bay:SetAttribute("ShojiApplied", open)
            end
        end
    end
end

-- Reconciles ONE bay's rendered leaf with its OWN live `ShojiOpen` attribute -- the target the
-- SlideShoji hold loop has been freely rewriting, tick by tick, without moving anything. Called
-- once, at hold end, NOT per step (a stepped, replicated CFrame would fight the client's tween of
-- the attribute, which is the entire reason `ShojiOpen` and `ShojiApplied` are split in the first
-- place). Unlike `applyShoji`, which resolves an externally supplied loadout for an ENTIRE side
-- (defaulting every bay the caller didn't mention to closed), this touches exactly the one bay
-- named, leaving every other screen's last-applied position untouched -- during a hold only this
-- bay's target has moved, and a whole-side reconcile would have to know every other bay's target
-- too, which nothing here has reason to reach for.
function StructureOps.syncShojiBay(model: Model, side: string, bay: Model)
    local localAxis = runAxisVector(side)
    if not localAxis then
        warn(`[StructureOps] syncShojiBay: unrecognised side '{side}'`)
        return
    end
    local shojiVariant = bay:FindFirstChild("Shoji")
    if not (shojiVariant and shojiVariant:IsA("Model")) then
        warn(`[StructureOps] syncShojiBay: bay '{bay.Name}' has no Shoji variant`)
        return
    end
    local shoji = shojiVariant :: Model
    local targetAttr = bay:GetAttribute("ShojiOpen")
    local target = if typeof(targetAttr) == "number" then targetAttr else 0
    local appliedAttr = bay:GetAttribute("ShojiApplied")
    local applied = if typeof(appliedAttr) == "number" then appliedAttr else 0
    local deltaStuds = ShojiRun.displacement(target) - ShojiRun.displacement(applied)
    if deltaStuds ~= 0 then
        local worldDir = model:GetPivot():VectorToWorldSpace(localAxis)
        shoji:PivotTo(shoji:GetPivot() + worldDir * deltaStuds)
    end
    bay:SetAttribute("ShojiApplied", target)
end

function StructureOps.recolor(m: Model, role: string, rgb: { number })
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("Role_" .. role) then
            p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
        end
    end
end

function StructureOps.setTexture(m: Model, target: string, assetId: string)
    if target == "Tatami" then
        for _, p in m:GetDescendants() do
            if p:HasTag("Tatami") then
                local d = p:FindFirstChildOfClass("Decal")
                if d then
                    d.Face = Enum.NormalId.Top
                    d.Texture = assetId
                else
                    d = Instance.new("Decal")
                    d.Face = Enum.NormalId.Top
                    d.Texture = assetId
                    d.Parent = p
                end
            end
        end
    else
        local bay = tonumber(target:match("ShojiBay:(%d+)"))
        for _, p in m:GetDescendants() do
            if p:HasTag("ShojiBay") and p:GetAttribute("Bay") == bay then
                local d = p:FindFirstChildOfClass("Decal")
                if d then
                    d.Face = Enum.NormalId.Front
                    d.Texture = assetId
                else
                    d = Instance.new("Decal")
                    d.Face = Enum.NormalId.Front
                    d.Texture = assetId
                    d.Parent = p
                end
            end
        end
    end
end

function StructureOps.attachPrefab(_m: Model, mount: string, prefabId: string)
    -- Flags/attachments are out of D.1 scope (seeded loadout carries none). A real
    -- implementation clones ServerStorage.StructureComponents[prefabId] to the named
    -- anchor; deferred until component prefabs + the economy catalog exist.
    warn(`[StructureOps] attachPrefab not implemented in D.1 (mount={mount}, prefab={prefabId})`)
end

function StructureOps.pivotTo(m: Model, cf12: { number })
    m:PivotTo(CFrame.new(table.unpack(cf12)))
end

return StructureOps
