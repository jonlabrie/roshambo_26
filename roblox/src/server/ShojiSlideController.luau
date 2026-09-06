--!strict
-- SHOJI: HOLD TO SLIDE. Extracted verbatim out of main.server.luau 2026-09-06 (server-file
-- split, phase one, task 2) -- the state (`shojiSlides`, `shojiPersistGen`,
-- `shojiPendingPersist`), the constants, the hold loop, the debounced persist, the leaving-player
-- flush and the `SlideShoji` handler body. Nothing about the behaviour changed; the only edits
-- were turning the entry file's top-level locals into fields of this object and taking its
-- Roblox services and neighbours by injection.
--
-- Runtime adapter: it touches Instances (bays, characters, the sites folder) and yields on HTTP,
-- so it has no Lune spec of its own. The arithmetic that CAN be tested off-Roblox lives in
-- ReplicatedStorage.RoshamboShared.ShojiSlideMath (slide key, run ordering, the reach distance)
-- and in ShojiRun (clamp/resolve/quantize/ordinalOf/directionFrom/isSlidable).
--
-- Server-authoritative sliding screens. A held SlideShoji advances one bay's `ShojiOpen`
-- attribute at SLIDE_RATE bay-widths/second in a direction latched ONCE at hold-start
-- (ShojiRun.directionFrom recomputed every step would reverse the screen under the player's
-- finger the moment it crossed the half-open mark -- see that function's own docs). The attribute
-- is the ONLY thing this handler writes: rendering the slide from it belongs to the client
-- controller.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShojiSlideMath =
    require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("ShojiSlideMath"))

local ShojiSlideController = {}
ShojiSlideController.__index = ShojiSlideController

local SLIDE_RATE = 1 / 1.2 -- bay-widths per second
-- BackDoorController's ProximityPrompt.MaxActivationDistance (12) + 4: generous, because there is
-- no server-side "who is inside whose house" registry -- this distance check to the bay's
-- un-moving Solid panel is what stands in for one.
local SHOJI_REACH = 12 + 4
local SHOJI_PERSIST_QUIET = 2 -- seconds of quiet after a hold ends before persisting

-- one active hold-to-slide loop per uid.
export type ShojiSlide = {
    alive: boolean,
    padId: string,
    side: string,
    -- BOTH namings of the same screen, deliberately. `bayNumber` is the raw <n> of Bay_<side>_<n>:
    -- the ONLY thing that crosses the SlideShoji wire, and so what a release/supersede is matched
    -- on. `index` is its ordinal within the side's shoji run (see collectShojiRun below), derived
    -- server-side by ShojiRun.ordinalOf, and is what the run arithmetic and the persisted
    -- `shojiOpen` list are indexed by. See ShojiRun.ordinalOf for why the wire is not the ordinal.
    bayNumber: number,
    index: number,
    bay: Model,
    structure: Model, -- for StructureOps.syncShojiBay's world-direction lookup at hold end
    count: number,
}

-- The debounced persist-on-hold-end target, one per SLIDE (uid + padId + side + index), not one
-- per uid (2026-08-18 review fix: a shared per-uid counter let sliding screen B within the quiet
-- window cancel screen A's still-pending write with no error and no trace). `shojiPersistGen` is
-- this generation counter, keyed by that composite key; `shojiPendingPersist` holds the latest
-- target awaiting each key's debounce, so PlayerRemoving can flush it immediately instead of
-- leaving it to wake up later and find the leaving player's house already gone.
export type ShojiPersistTarget = {
    uid: string,
    padId: string,
    side: string,
    index: number,
    count: number,
    bay: Model,
}

export type Deps = {
    players: Players,
    sitesFolder: Instance,
    StructureOps: any,
    ShojiRun: any,
    net: any,
    handlerQueue: any,
    getHouse: (uid: string) -> { padId: string, size: string, loadout: any }?,
    getEconomy: (uid: string) -> any,
    fireShojiState: (player: Player, payload: any) -> (),
    task: any,
    workspace: any,
}

-- The same bay-run collection StructureOps.applyShoji uses: Bay_<side>_<n> models that carry a
-- `Shoji` variant, ascending by n. MEMBERSHIP IS DELIBERATELY THE VARIANT, NOT THE RESOLVED STATE
-- (`BayState`). The prefab's grooves were authored per member of this list and a persisted
-- `shojiOpen` index means a position in it, so a player toggling one bay between solid and shoji
-- must not renumber their saved screen positions. Whether a member can actually be SLID is a
-- separate question, asked of `BayState` through ShojiRun.isSlidable at the point of the hold.
--
-- The client no longer builds a copy of this list (2026-08-18 final review): it fires the raw
-- Bay_<side>_<n> number and the mapping to an ordinal happens here, via ShojiRun.ordinalOf,
-- because only the server is guaranteed to see every bay. See that function's own note.
local function collectShojiRun(structure: Model, side: string): { { bayIndex: number, bay: Model } }
    local list: { { bayIndex: number, bay: Model } } = {}
    for _, c in structure:GetChildren() do
        if c:IsA("Model") then
            local s, idxStr = c.Name:match("^Bay_(%a+)_(%d+)$")
            if s == side then
                local shoji = c:FindFirstChild("Shoji")
                if shoji and shoji:IsA("Model") then
                    table.insert(list, { bayIndex = tonumber(idxStr) :: number, bay = c })
                end
            end
        end
    end
    return ShojiSlideMath.collectRun(list) :: { { bayIndex: number, bay: Model } }
end

-- The one part of a bay that never moves (its Solid variant's panel) -- the reach check's
-- reference point, same lookup tools/studio/trackShojiBays.luau uses for the identical reason.
local function shojiReachPosition(bay: Model): Vector3?
    local solid = bay:FindFirstChild("Solid")
    local panel = solid and solid:FindFirstChildWhichIsA("BasePart", true)
    return if panel then (panel :: BasePart).Position else nil
end

local function withinShojiReach(player: Player, pos: Vector3): boolean
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root == nil then
        return false
    end
    local rp = (root :: BasePart).Position
    return ShojiSlideMath.withinReach(
        { x = rp.X, y = rp.Y, z = rp.Z },
        { x = pos.X, y = pos.Y, z = pos.Z },
        SHOJI_REACH
    )
end

function ShojiSlideController.new(deps: Deps)
    return setmetatable({
        _d = deps,
        _slides = {} :: { [string]: ShojiSlide },
        _persistGen = {} :: { [string]: number },
        _pendingPersist = {} :: { [string]: ShojiPersistTarget },
    }, ShojiSlideController)
end

-- Persist ONE shoji slide's final travel, occupant-only: clone the loadout, set
-- shojiOpen[side][index] to the bay's live ShojiOpen attribute, net:setTeahouse, mirror into
-- the economy stash -- the same three-step shape SetBackDoor uses (stash, mirror, persist), for
-- the same reason: rebuild paths render from the stash, not from playerHouse. A visitor's slide
-- (no house, or occupying a different pad) writes nothing at all: no error, no message, it simply
-- is not theirs to keep. PlayerRemoving needs to reach this directly, to flush a pending debounced
-- persist before the leaving player's house is cleared.
function ShojiSlideController:persistShojiNow(target: ShojiPersistTarget)
    local d = self._d
    local uid = target.uid
    d.handlerQueue:run(uid, function()
        local house = d.getHouse(uid)
        if house == nil or house.padId ~= target.padId then
            return -- a visitor's slide is not theirs to keep
        end
        if not target.bay:IsDescendantOf(d.workspace) then
            return -- structure gone (rebuild/leave race): nothing live to read
        end
        local finalAttr = target.bay:GetAttribute("ShojiOpen")
        local finalOpen = if typeof(finalAttr) == "number" then finalAttr else 0
        local existingSide = house.loadout.shojiOpen and house.loadout.shojiOpen[target.side]
        local resolvedList = d.ShojiRun.resolve(existingSide, target.count)
        -- quantized, not raw: see ShojiRun.quantize -- `shojiOpen` shares one 4096-byte loadout
        -- document with every other teahouse setting, and a rejected document loses ALL of them.
        resolvedList[target.index] =
            d.ShojiRun.quantize(d.ShojiRun.clamp(target.index, target.count, finalOpen))
        -- merge into a NEW copy of the occupied size's loadout (don't alias the stash pre-persist)
        local newShojiOpen = table.clone(house.loadout.shojiOpen or {})
        newShojiOpen[target.side] = resolvedList
        local newLoadout = table.clone(house.loadout)
        newLoadout.shojiOpen = newShojiOpen
        house.loadout = newLoadout
        local e = d.getEconomy(uid)
        if e ~= nil and e.teahouses ~= nil then
            e.teahouses[house.size] = newLoadout
        end
        local persisted = d.net:setTeahouse(uid, house.size, newLoadout)
        if not persisted.ok then
            warn(`[SHOJI] setTeahouse failed for {uid}/{house.size}: {tostring(persisted.error)}`)
        end
    end)
end

-- Collapses every pending shoji persist for a LEAVING uid into ONE loadout write (2026-08-18
-- review round 2 fix). handlerQueue is a strict per-uid FIFO: a loop that called persistShojiNow
-- once per pending target only ran the FIRST one synchronously -- its HTTP call yields, marks the
-- lane "running", and every later target for the same uid was merely enqueued behind it. By the
-- time the lane actually drained to them, PlayerRemoving had already gone on to null
-- playerHouse[uid] a few lines later, so each queued-but-not-yet-run target found no house and
-- silently wrote nothing: exactly the multi-screen case the composite persist key exists to
-- support, undone by the very flush meant to protect it.
--
-- The fix is not to reorder the clearing -- there is no placement of handlerQueue:clear /
-- playerHouse[uid] = nil relative to N separate handlerQueue:run calls that makes all N safe,
-- because only the FIRST ever runs before the rest of this function continues. It is to make it
-- ONE call: read the house ONCE, HERE, before any queueing happens, merge every pending
-- target's final ShojiOpen into a single cloned loadout, and close over that already-built
-- loadout (and size) as plain captured locals in a single queued thunk -- never re-reading
-- playerHouse[uid] from inside it. That makes the clearing order irrelevant: there is nothing left
-- in the thunk that a later `nil` could invalidate. One HTTP call also costs less than N against a
-- budget the round loop shares.
function ShojiSlideController:flushForUid(uid: string)
    local d = self._d
    local targets: { ShojiPersistTarget } = {}
    for key, target in self._pendingPersist do
        if target.uid == uid then
            table.insert(targets, target)
            self._pendingPersist[key] = nil
            self._persistGen[key] = nil -- so a debounce that later wakes cannot write a second time
        end
    end
    if #targets == 0 then
        return
    end
    local house = d.getHouse(uid)
    if house == nil then
        return -- a visitor's slide is not theirs to keep
    end
    -- resolve each SIDE's list at most once, even if several targets share a side, so a second
    -- target on the same wall sets its own index into the SAME resolved list rather than each
    -- target clobbering the other's write with its own fresh resolve
    local newShojiOpen = table.clone(house.loadout.shojiOpen or {})
    local resolvedBySide: { [string]: { number } } = {}
    local wroteAny = false
    for _, target in targets do
        if target.padId ~= house.padId or not target.bay:IsDescendantOf(d.workspace) then
            continue -- stale: occupancy moved on, or the structure died (rebuild/leave race)
        end
        local resolvedList = resolvedBySide[target.side]
        if resolvedList == nil then
            local existingSide = house.loadout.shojiOpen and house.loadout.shojiOpen[target.side]
            resolvedList = d.ShojiRun.resolve(existingSide, target.count)
            resolvedBySide[target.side] = resolvedList
            newShojiOpen[target.side] = resolvedList
        end
        local finalAttr = target.bay:GetAttribute("ShojiOpen")
        local finalOpen = if typeof(finalAttr) == "number" then finalAttr else 0
        resolvedList[target.index] =
            d.ShojiRun.quantize(d.ShojiRun.clamp(target.index, target.count, finalOpen))
        wroteAny = true
    end
    if not wroteAny then
        return -- every pending target turned out stale; nothing left to persist
    end
    local newLoadout = table.clone(house.loadout)
    newLoadout.shojiOpen = newShojiOpen
    house.loadout = newLoadout
    local e = d.getEconomy(uid)
    if e ~= nil and e.teahouses ~= nil then
        e.teahouses[house.size] = newLoadout
    end
    local size = house.size -- captured now; the thunk below never re-reads the house
    -- DEFERRED, not queued inline (2026-08-18 final review). handlerQueue drains its lane on a
    -- freshly spawned thread, which runs synchronously up to its first yield -- and the first
    -- thing this thunk does is a yielding HTTP PUT. Queueing it here therefore parked
    -- PlayerRemoving inside setTeahouse, delaying siteCoordinator:onLeave (the pad release) a few
    -- lines below by the transport's own latency, or by its full timeout when the backend is sick.
    -- The write itself has no deadline; the pad release does, because the next player to walk up
    -- to that pad is waiting on it. Everything the thunk needs is already captured above, so the
    -- delay costs it nothing.
    d.task.defer(function()
        d.handlerQueue:run(uid, function()
            local persisted = d.net:setTeahouse(uid, size, newLoadout)
            if not persisted.ok then
                warn(`[SHOJI] setTeahouse (flush) failed for {uid}/{size}: {tostring(persisted.error)}`)
            end
        end)
    end)
end

-- Schedule (debounce), keyed per SLIDE TARGET -- not per uid (2026-08-18 review fix; see the
-- shojiPersistGen/shojiPendingPersist declarations above). Two releases of the SAME screen inside
-- the quiet window still collapse to one write, which is the debounce doing its job; two DIFFERENT
-- screens no longer cancel each other.
function ShojiSlideController:scheduleShojiPersist(
    uid: string,
    padId: string,
    side: string,
    index: number,
    count: number,
    bay: Model
)
    local key = ShojiSlideMath.slideKey(uid, padId, side, index)
    local gen = (self._persistGen[key] or 0) + 1
    self._persistGen[key] = gen
    self._pendingPersist[key] =
        { uid = uid, padId = padId, side = side, index = index, count = count, bay = bay }
    self._d.task.delay(SHOJI_PERSIST_QUIET, function()
        if self._persistGen[key] ~= gen then
            return -- superseded by a newer hold-end on THIS SAME screen within the quiet window
        end
        self._persistGen[key] = nil
        local target = self._pendingPersist[key]
        self._pendingPersist[key] = nil
        if target ~= nil then
            self:persistShojiNow(target)
        end
    end)
end

-- The hold loop: NOT run through handlerQueue (parking a multi-second loop in a player's lane
-- would block every other mutating handler of theirs for the duration of the hold). It never
-- touches anything handlerQueue exists to protect either -- no HTTP, only a replicated attribute
-- -- until it ends, at which point StructureOps.syncShojiBay (a live Instance write, but no HTTP)
-- and scheduleShojiPersist (the one thing that yields) run, and the latter goes through the queue
-- itself, same as every other persist in this file.
function ShojiSlideController:runShojiSlide(player: Player, uid: string, slide: ShojiSlide, direction: number)
    local d = self._d
    local last = os.clock()
    while slide.alive do
        d.task.wait()
        if not slide.alive then
            break
        end
        if not player:IsDescendantOf(d.players) then
            break -- player left
        end
        if not slide.bay:IsDescendantOf(d.workspace) then
            break -- structure died mid-hold (rebuild/leave race)
        end
        local pos = shojiReachPosition(slide.bay)
        if pos == nil or not withinShojiReach(player, pos) then
            break -- walked out of range
        end
        local now = os.clock()
        local dt = now - last
        last = now
        local current = slide.bay:GetAttribute("ShojiOpen")
        local openNow = if typeof(current) == "number" then current else 0
        local nextOpen = d.ShojiRun.clamp(slide.index, slide.count, openNow + direction * SLIDE_RATE * dt)
        -- TARGET only -- see StructureOps.applyShoji/syncShojiBay's own docs on why ShojiOpen and
        -- ShojiApplied are split: a stepped, replicated PivotTo every tick would fight whatever the
        -- client controller tweens from this same attribute.
        --
        -- Only when it actually MOVED (2026-08-18 final review). Once the clamp has pinned a screen
        -- at either end of its run, every further tick recomputed the identical number; writing it
        -- anyway replicated an attribute change to every client in the place ~60 times a second,
        -- each one waking their tween, for as long as a player kept leaning on G against a
        -- fully-open screen. There is no reason a hold that changes nothing should cost anything.
        if nextOpen ~= openNow then
            slide.bay:SetAttribute("ShojiOpen", nextOpen)
        end
    end
    if self._slides[uid] == slide then
        self._slides[uid] = nil
    end
    -- reconcile the server's OWN geometry to the final target ONCE, here, at hold end -- not per
    -- step. These are anchored scenery parts: server-side collision and every server raycast see
    -- ONLY what this call moves, nothing the loop wrote to the attribute above. Guarded the same
    -- way the loop itself was: a structure that died mid-hold (rebuild/leave race) leaves nothing
    -- live to move.
    if slide.bay:IsDescendantOf(d.workspace) then
        d.StructureOps.syncShojiBay(slide.structure, slide.side, slide.bay)
    end
    self:scheduleShojiPersist(uid, slide.padId, slide.side, slide.index, slide.count, slide.bay)
end

-- Stop a LEAVING player's shoji hold immediately rather than waiting for the loop's own
-- next-tick IsDescendantOf(Players) check to catch up, and fold that in-flight hold into the
-- pending persists so the flush that follows can save where it got to. Call this BEFORE
-- flushForUid, and before the leaving player's house is cleared.
function ShojiSlideController:foldActive(uid: string)
    local activeSlide = self._slides[uid]
    if activeSlide ~= nil then
        activeSlide.alive = false
        -- ...and fold that in-flight hold into the pending persists RIGHT HERE, before flushing
        -- (2026-08-18 final review). Killing the loop is not the same as saving where it got to:
        -- the loop only reaches its own scheduleShojiPersist on its NEXT tick, which is after this
        -- function has returned and nulled playerHouse[uid], so the target it schedules then finds
        -- no house and is silently discarded. Disconnecting mid-hold therefore always lost the
        -- write -- live geometry right, database stale. The bay's `ShojiOpen` attribute already
        -- holds the final travel (the loop stopped writing the instant `alive` went false, and
        -- flushForUid reads it synchronously afterwards), so this target is complete as it stands.
        -- The loop's own later scheduleShojiPersist for the same screen is then a no-op: the flush
        -- has already cleared this key's generation, and by then there is no house to write to.
        local key = ShojiSlideMath.slideKey(uid, activeSlide.padId, activeSlide.side, activeSlide.index)
        self._persistGen[key] = (self._persistGen[key] or 0) + 1
        self._pendingPersist[key] = {
            uid = uid,
            padId = activeSlide.padId,
            side = activeSlide.side,
            index = activeSlide.index,
            count = activeSlide.count,
            bay = activeSlide.bay,
        }
    end
end

-- How many slide targets are waiting on their debounce, across every uid. A test hook; the
-- runtime never asks.
function ShojiSlideController:pendingCount(): number
    local n = 0
    for _ in self._pendingPersist do
        n += 1
    end
    return n
end

-- NOT wrapped in handlerQueue (2026-08-18 final review). This handler does no HTTP and touches
-- nothing the queue exists to protect: `shojiSlides` is per-uid and it never reads `playerHouse`.
-- What it IS, is latency-critical -- a release has to land the moment the player lets go. The lane
-- is strict FIFO and a yielding thunk suspends it, so with the handler inside it a release could
-- queue behind the debounced `net:setTeahouse` PUT from a screen the player had already finished
-- with, and the screen kept sliding for the whole round trip: roughly ten studs of overshoot after
-- letting go. Worse, HandlerQueue.run refuses at MAX_PENDING and returns false, so a busy lane
-- could drop a release outright and leave a screen sliding until the player walked out of reach.
-- The one thing here that yields -- the persist -- still goes through the queue, from inside
-- persistShojiNow, exactly like every other write in this file.
function ShojiSlideController:onSlideRequest(player: Player, payload: any)
    local d = self._d
    local uid = tostring(player.UserId)
    local padId = if typeof(payload) == "table" then payload.padId else nil
    local side = if typeof(payload) == "table" then payload.side else nil
    -- the RAW Bay_<side>_<n> number, not a run ordinal (see ShojiRun.ordinalOf)
    local bayNumber = if typeof(payload) == "table" then payload.bay else nil
    local held = if typeof(payload) == "table" then payload.held else nil
    if typeof(padId) ~= "string" or typeof(side) ~= "string" or typeof(held) ~= "boolean" then
        return -- ill-typed request
    end
    if typeof(bayNumber) ~= "number" or bayNumber % 1 ~= 0 or bayNumber < 1 then
        return -- ill-typed / non-integer / non-positive bay number
    end

    if not held then
        local slide = self._slides[uid]
        if slide ~= nil and slide.padId == padId and slide.side == side and slide.bayNumber == bayNumber then
            slide.alive = false -- runShojiSlide notices next tick, unwinds, and persists
        end
        -- a release that doesn't match the active hold (stale/superseded) is simply ignored
        return
    end

    -- a further held=true for the screen already being held is a no-op: nothing stops a
    -- client resending held=true every frame, and re-latching from the current position each
    -- time would reproduce the reverse-under-your-finger bug the latch exists to prevent
    -- (2026-08-18 review fix). Only a hold on a DIFFERENT screen supersedes the active one.
    local existing = self._slides[uid]
    if
        existing ~= nil
        and existing.padId == padId
        and existing.side == side
        and existing.bayNumber == bayNumber
    then
        return
    end

    -- find the live structure this bay belongs to (F2/F4: a streaming/rebuild race just
    -- means there is nothing to slide, same posture as SetBackDoor above)
    local siteFolder = d.sitesFolder:FindFirstChild("MaterializedSite_" .. padId)
    local structure = siteFolder and siteFolder:FindFirstChild("Structure")
    if structure == nil then
        return
    end
    local run = collectShojiRun(structure :: Model, side)
    local count = #run
    -- raw bay number -> ordinal within THIS wall's run, decided here because the server is the
    -- side that can always see every bay (ShojiRun.ordinalOf's own note has the failure)
    local bayNumbers = table.create(count)
    for i, e in run do
        bayNumbers[i] = e.bayIndex
    end
    local index = d.ShojiRun.ordinalOf(bayNumbers, bayNumber)
    if index == nil then
        return -- not a shoji bay of this side: ill-typed / stale client, no message
    end
    local entry = run[index]

    -- The bay's RESOLVED state, never merely the presence of its `Shoji` variant, which every bay
    -- of a stock prefab has (2026-08-18 final review, critical -- see ShojiRun.isSlidable). The
    -- server does not trust that a prompt fired, or that the client was willing to ask: a solid
    -- bay is not slidable no matter what arrives on the wire, and sliding one would move an
    -- invisible non-colliding leaf behind the panel the player is looking at, then persist it.
    if not d.ShojiRun.isSlidable(entry.bay:GetAttribute("BayState")) then
        return
    end

    local pos = shojiReachPosition(entry.bay)
    local reachable = pos ~= nil and withinShojiReach(player, pos)
    local openAttr = entry.bay:GetAttribute("ShojiOpen")
    local openNow = if typeof(openAttr) == "number" then openAttr else 0
    if not reachable then
        -- the server never trusts that a prompt fired -- only that the player could
        -- plausibly reach it. Tell the HOLDER only, so a refused hold doesn't leave their
        -- prompt looking stuck; the attribute itself is untouched.
        if player:IsDescendantOf(d.players) then
            d.fireShojiState(
                player,
                { padId = padId, side = side, bay = bayNumber, open = openNow, accepted = false }
            )
        end
        return
    end

    -- a hold on a DIFFERENT screen supersedes the first: end it exactly like a release would
    -- (its own persist debounce still fires for whatever IT was sliding). `existing`, if
    -- non-nil here, is guaranteed to be a DIFFERENT screen -- the guard above already returned
    -- on an exact match.
    if existing ~= nil then
        existing.alive = false
    end

    -- latched HERE, ONCE, per ShojiRun.directionFrom's own docs
    local direction = d.ShojiRun.directionFrom(index, count, openNow)
    local slide: ShojiSlide = {
        alive = true,
        padId = padId,
        side = side,
        bayNumber = bayNumber,
        index = index,
        bay = entry.bay,
        structure = structure :: Model,
        count = count,
    }
    self._slides[uid] = slide

    if player:IsDescendantOf(d.players) then
        d.fireShojiState(
            player,
            { padId = padId, side = side, bay = bayNumber, open = openNow, accepted = true }
        )
    end

    d.task.spawn(function()
        self:runShojiSlide(player, uid, slide, direction)
    end)
end

return ShojiSlideController
