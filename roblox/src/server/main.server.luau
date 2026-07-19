--!strict
-- Composition root: wires Roblox services into the runtime-agnostic modules.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))
local RoundCoordinator = require(script.Parent:WaitForChild("RoundCoordinator"))
local ThrowBuffer = require(script.Parent:WaitForChild("ThrowBuffer"))
local HandlerQueue = require(script.Parent:WaitForChild("HandlerQueue"))
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local RoundClock = require(shared:WaitForChild("RoundClock"))
local GameRules = require(shared:WaitForChild("GameRules"))
local PlayerProfiles = require(shared:WaitForChild("PlayerProfiles"))
local ThemeManifest = require(shared:WaitForChild("ThemeManifest"))
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local FateRegistry = require(shared:WaitForChild("FateRegistry"))
local PreferenceEditor = require(shared:WaitForChild("PreferenceEditor"))
local BackDoorEditor = require(shared:WaitForChild("BackDoorEditor"))
local WallBays = require(shared:WaitForChild("WallBays"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local FateResolved = remotes:WaitForChild("FateResolved") :: RemoteEvent
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent
local SetBackDoor = remotes:WaitForChild("SetBackDoor") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local SetDisplay = remotes:WaitForChild("SetDisplay") :: RemoteEvent
local SetPlacement = remotes:WaitForChild("SetPlacement") :: RemoteEvent
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local secretsModule = script.Parent:FindFirstChild("SecretsLocal")
    or script.Parent:WaitForChild("SecretsExample")
local config = require(secretsModule) :: { baseUrl: string, apiKey: string }

local themeOk, themeErrs = ThemeManifest.validate(ZenDojo)
if not themeOk then
    error("[THEME] ZenDojo invalid: " .. table.concat(themeErrs, "; "))
end

-- StreamingEnabled is on, but the central monument is the focal point every
-- player watches from spawn (~200 studs away). Mark its models Persistent so they
-- (and all their parts) are always replicated — otherwise client controllers that
-- capture parts once at startup (e.g. WheelController's rig:GetChildren()) run
-- before the parts stream in and silently capture nothing.
-- Persist the arena-visible Models so distant spawn-watchers always have them.
-- RoshamboStage holds the Rojo hero props; CanyonWorld/Arena holds the relocated
-- place-only river/falls VFX + rocks (see the workspace-organization convention).
-- The far canyon (CanyonWorld/Paths|Structures|Legacy) is intentionally NOT persisted
-- and streams normally, matching pre-reorg behavior.
local StagePersistence = require(shared:WaitForChild("StagePersistence"))
local stage = workspace:WaitForChild("RoshamboStage")
local persistRoots = { stage }
local canyonWorld = workspace:FindFirstChild("CanyonWorld")
local arena = canyonWorld and canyonWorld:FindFirstChild("Arena")
if arena then
    table.insert(persistRoots, arena)
end
for _, model in StagePersistence.persistTargets(persistRoots) do
    (model :: Model).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end

local deps = {
    request = function(req)
        local ok, resp = pcall(function()
            return HttpService:RequestAsync({
                Url = req.Url,
                Method = req.Method,
                Headers = req.Headers,
                Body = req.Body,
            })
        end)
        if not ok then
            warn(`[NET] transport error: {resp}`)
            return { ok = false }
        end
        return { ok = true, statusCode = resp.StatusCode, body = resp.Body }
    end,
    jsonDecode = function(s: string)
        return HttpService:JSONDecode(s)
    end,
    jsonEncode = function(t: any)
        return HttpService:JSONEncode(t)
    end,
    sleep = function(seconds: number)
        task.wait(seconds)
    end,
    now = function()
        return DateTime.now().UnixTimestampMillis
    end,
    random = function()
        return math.random()
    end,
}

local net = NetworkClient.new({ baseUrl = config.baseUrl, apiKey = config.apiKey }, deps)
local clock = RoundClock.new()
local profiles = PlayerProfiles.new(GameRules)
local fates = FateRegistry.new()

local function applyGrow(player: Player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    for _, name in { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" } do
        local v = humanoid:FindFirstChild(name) :: NumberValue?
        if v then
            local up = TweenService:Create(
                v,
                TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Value = 1.6 }
            )
            up:Play()
            task.delay(8, function()
                TweenService:Create(v, TweenInfo.new(1.2), { Value = 1 }):Play()
            end)
        end
    end
end

local EPITHET = "A WANDERER"
local function filterExternalName(name: string): string
    local anyPlayer = Players:GetPlayers()[1]
    if not anyPlayer then
        return EPITHET
    end
    local ok, result = pcall(function()
        local r = TextService:FilterStringAsync(name, anyPlayer.UserId)
        return r:GetNonChatStringForBroadcastAsync()
    end)
    if not ok or result:find("#") then
        return EPITHET
    end
    return result
end

local function leaderstatsFor(player: Player): Folder?
    return player:FindFirstChild("leaderstats") :: Folder?
end

local function pushStats(player: Player)
    local row = profiles:get(tostring(player.UserId))
    local stats = leaderstatsFor(player)
    if not row or not stats then
        return
    end
    (stats:FindFirstChild("Points") :: IntValue).Value = row.totalPoints;
    (stats:FindFirstChild("Pot") :: IntValue).Value = row.pointsAtStake;
    (stats:FindFirstChild("Streak") :: IntValue).Value = row.currentStreak
end

local function fireProfile(player: Player, source: string)
    local row = profiles:get(tostring(player.UserId))
    if row then
        ProfileUpdate:FireClient(player, {
            totalPoints = row.totalPoints,
            pointsAtStake = row.pointsAtStake,
            currentStreak = row.currentStreak,
            stakingStreak = row.stakingStreak,
            bestStreak = row.bestStreak,
            source = source,
        })
    end
end

local function playerByUserId(userId: string): Player?
    for _, p in Players:GetPlayers() do
        if tostring(p.UserId) == userId then
            return p
        end
    end
    return nil
end

local lastTape: any = {}

local coordinator = RoundCoordinator.new({
    net = net,
    clock = clock,
    buffer = ThrowBuffer.new(),
    rules = GameRules,
    log = print,
    random = math.random,
    now = deps.now,
    instanceId = if game.JobId ~= "" then game.JobId else "studio-local",
    callbacks = {
        onRound = function(info)
            RoundUpdate:FireAllClients(info)
            if info.tape then
                lastTape = info.tape
            end
        end,
        onReveal = function(reveal)
            RevealTheater:FireAllClients({
                worldThrow = reveal.worldThrow,
                distribution = reveal.distribution,
                totalPlayers = reveal.totalPlayers,
                results = reveal.results,
                whiffed = reveal.whiffed,
            })
            for _, player in Players:GetPlayers() do
                local userId = tostring(player.UserId)
                local mine = reveal.results[userId]
                RevealResult:FireClient(player, {
                    worldThrow = reveal.worldThrow,
                    distribution = reveal.distribution,
                    totalPlayers = reveal.totalPlayers,
                    pick = mine and mine.pick,
                    result = mine and mine.result,
                })
                if mine then
                    profiles:applyLocalResult(userId, mine.result)
                    pushStats(player)
                    fireProfile(player, "local")
                    if mine.result == "WIN" then
                        applyGrow(player)
                    elseif mine.result == "LOSS" then
                        fates:begin(userId)
                    end
                end
            end
        end,
        onReconciled = function(rows)
            for _, row in rows do
                profiles:applyServer(row.robloxUserId, {
                    totalPoints = row.totalPoints,
                    pointsAtStake = row.pot,
                    currentStreak = row.streak,
                    stakingStreak = row.streak,
                    bestStreak = math.max(
                        row.streak,
                        (profiles:get(row.robloxUserId) or { bestStreak = 0 }).bestStreak
                    ),
                })
                local player = playerByUserId(row.robloxUserId)
                if player then
                    pushStats(player)
                    fireProfile(player, "reconciled")
                end
            end
        end,
    },
})

Players.PlayerAdded:Connect(function(player)
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    for _, name in { "Points", "Pot", "Streak" } do
        local v = Instance.new("IntValue")
        v.Name = name
        v.Parent = stats
    end
    stats.Parent = player

    task.spawn(function()
        local country: string? = nil
        pcall(function()
            country = LocalizationService:GetCountryRegionForPlayerAsync(player)
        end)
        local res = net:getPlayer(tostring(player.UserId), country)
        if res.ok then
            profiles:applyServer(tostring(player.UserId), {
                totalPoints = res.data.totalPoints,
                pointsAtStake = res.data.pointsAtStake,
                currentStreak = res.data.currentStreak,
                stakingStreak = res.data.stakingStreak,
                bestStreak = res.data.bestStreak,
            })
            pushStats(player)
            fireProfile(player, "sync")
        else
            warn(`[PROFILE] sync failed for {player.UserId}: {res.error or res.status}`)
        end
    end)
end)

SubmitPick.OnServerEvent:Connect(function(player, throwValue)
    if type(throwValue) ~= "string" then
        return
    end
    if fates:isBound(tostring(player.UserId)) then
        print(`[PICK] {player.Name} rejected: FATE_BOUND`)
        return
    end
    local accepted, reason = coordinator:submitPick(tostring(player.UserId), throwValue)
    if not accepted then
        print(`[PICK] {player.Name} rejected: {reason}`)
    end
end)

local handlerQueue = HandlerQueue.new(task.spawn)

BankRequest.OnServerEvent:Connect(function(player)
    handlerQueue:run(tostring(player.UserId), function()
        local res = net:postBank(tostring(player.UserId))
        if res.ok then
            profiles:applyServer(tostring(player.UserId), {
                totalPoints = res.data.totalPoints,
                pointsAtStake = res.data.pointsAtStake,
                currentStreak = res.data.currentStreak,
                stakingStreak = res.data.stakingStreak,
                bestStreak = (profiles:get(tostring(player.UserId)) or { bestStreak = 0 }).bestStreak,
            })
            pushStats(player)
            fireProfile(player, "banked")
        end
    end)
end)

FateResolved.OnServerEvent:Connect(function(player, reason)
    if reason ~= "caught" and reason ~= "accepted" then
        return
    end
    local userId = tostring(player.UserId)
    if fates:resolve(userId) then
        FateResolved:FireAllClients(userId, reason)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    fates:remove(tostring(player.UserId))
end)

local lastBoard: any = nil
task.spawn(function()
    while true do
        local res = net:getLeaderboards("world")
        local worldRec, hotStreak = nil, nil
        if res.ok and res.data.leaders then
            local top = res.data.leaders[1]
            if top then
                worldRec = { points = top.totalPoints, name = filterExternalName(top.displayName or "?") }
            end
            local best, bestName = 0, nil
            for _, l in res.data.leaders do
                if (l.currentStreak or 0) > best then
                    best, bestName = l.currentStreak, l.displayName
                end
            end
            if bestName then
                hotStreak = { streak = best, name = filterExternalName(bestName) }
            end
        end
        lastBoard = {
            tape = lastTape,
            worldRec = worldRec,
            hotStreak = hotStreak,
            playersNow = (lastTape[1] and lastTape[1].totalPlayers) or 0,
        }
        BoardData:FireAllClients(lastBoard)
        task.wait(30)
    end
end)

Players.PlayerAdded:Connect(function(player)
    if lastBoard then
        BoardData:FireClient(player, lastBoard)
    end
end)

-- D.6: lifecycle + vacant state across all 14 surveyed perches; a joining owner claims
-- one (lit), the rest stay dormant; release on leave. (D.2 proved this on a 2-3 pad subset.)
local StructureBuilder = require(shared:WaitForChild("StructureBuilder"))
local PadBuilder = require(shared:WaitForChild("PadBuilder"))
local StructureCatalog = require(shared:WaitForChild("StructureCatalog"))
local PadRegistry = require(shared:WaitForChild("PadRegistry"))
local SiteCoordinator = require(shared:WaitForChild("SiteCoordinator"))
local BuildingPlacer = require(shared:WaitForChild("BuildingPlacer"))
local SizeClasses = require(shared:WaitForChild("SizeClasses"))
local DeckPlacement = require(shared:WaitForChild("DeckPlacement"))
local StructureOps = require(script.Parent:WaitForChild("StructureOps"))
local PadOps = require(script.Parent:WaitForChild("PadOps"))
local PadSites = require(script.Parent:WaitForChild("PadSites"))
local TreatmentApplier = require(script.Parent:WaitForChild("TreatmentApplier"))

local playerPrefs: { [string]: { string } } = {}
local PREF_CAP = 32

-- item C: PadSites.displayName is server-only, but the panel wants real names for favorites
-- instead of "Perch <siteId>". Build a siteId -> displayName map alongside every padPreferences
-- list this server sends, so the client never has to guess a name for an id it can't look up.
local function namesFor(siteIds: { string }): { [string]: string }
    local names = {}
    for _, id in siteIds do
        local spec = PadSites[id]
        names[id] = (spec and spec.displayName) or id
    end
    return names
end

-- The teahouse each player currently occupies, for occupant-gated live edits (B1 back door):
-- padId + the occupied SIZE + that size's loadout (the merge target for wallBays edits).
local playerHouse: { [string]: { padId: string, size: string, loadout: any } } = {}

-- B4: the default placement for a build path whose loadout carries none yet (uniform rule:
-- every build site renders `loadout.placement or CENTERED_PLACEMENT`).
local CENTERED_PLACEMENT = { offset = { 0, 0 }, facing = "N" }

-- economy per player (for purchase gating + the client's prompts/labels): the fetched balance,
-- deck tier, owned teahouse loadouts, and the claimed pad (nil until they own+claim).
local playerEconomy: {
    [string]: {
        totalPoints: number,
        maxDeckSize: string?,
        teahouses: { [string]: any },
        claimedPadId: string?,
        deckDisplay: string?,
        teahouseDisplay: string?,
        portalOwned: boolean,
    },
} =
    {}
-- the price catalog is identical for everyone; stash the first one fetched so echoes carry it.
local economyCatalog: any = nil

local function echoEconomy(player: Player, uid: string)
    local e = playerEconomy[uid]
    if e == nil or not player:IsDescendantOf(Players) then
        return
    end
    local teaSizes = {}
    for size in e.teahouses do
        table.insert(teaSizes, size)
    end
    EconomyState:FireClient(player, {
        totalPoints = e.totalPoints,
        maxDeckSize = e.maxDeckSize,
        teahouseSizes = teaSizes,
        claimedPadId = e.claimedPadId,
        catalog = economyCatalog,
        deckDisplay = e.deckDisplay,
        teahouseDisplay = e.teahouseDisplay,
        portalOwned = e.portalOwned,
    })
end

-- B3 gate fix: mid-session live rebuilds (buy-to-claim, upgrade, display change) destroy the
-- old Structure (and its back-door prompts) and build a new one; re-fire BackDoorState so the
-- client rebinds prompts to the NEW structure. No-op if playerHouse[uid] was just cleared (bare
-- deck / no loadout this session) or the player already left mid-yield.
local function echoBackDoor(player: Player, uid: string)
    local house = playerHouse[uid]
    if house ~= nil and player:IsDescendantOf(Players) then
        BackDoorState:FireClient(player, {
            padId = house.padId,
            backDoorIndex = BackDoorEditor.backDoorIndex(house.loadout.wallBays),
        })
    end
end

local siteCoordinator = SiteCoordinator.new(PadRegistry.new())
local sitesFolder = Instance.new("Folder")
sitesFolder.Name = "TeahouseSites"
sitesFolder.Parent = workspace

local applier = TreatmentApplier.new({
    container = sitesFolder,
    padBuilder = PadBuilder,
    structureBuilder = StructureBuilder,
    catalog = StructureCatalog,
    structureOps = StructureOps,
    padOpsNew = PadOps.new,
    buildingPlacer = BuildingPlacer,
    sizeClasses = SizeClasses,
    deckPlacement = DeckPlacement,
})

-- Register all 14 surveyed perches in stable T01..T14 order (PadSites is a keyed dict
-- with no iteration order, so the id list is explicit). Each registers as a dormant
-- vacant site; a joining owner claims the first fitting one (size-tier, then this order).
for i = 1, 14 do
    local id = string.format("T%02d", i)
    local spec = PadSites[id]
    if spec then
        siteCoordinator:registerPad(id, spec)
    end
end
for _, action in siteCoordinator:vacantActions() do
    applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        local res = net:getEconomy(tostring(player.UserId))
        local uid = tostring(player.UserId)
        local ecoData = if res.ok then res.data else nil
        local prefs = (ecoData and ecoData.padPreferences) or {}
        local teahouses = (ecoData and ecoData.teahouses) or {}
        playerPrefs[uid] = prefs
        if ecoData and ecoData.catalog then
            economyCatalog = ecoData.catalog
        end
        playerEconomy[uid] = {
            totalPoints = (ecoData and ecoData.totalPoints) or 0,
            maxDeckSize = ecoData and ecoData.maxDeckSize or nil,
            teahouses = teahouses,
            claimedPadId = nil,
            deckDisplay = ecoData and ecoData.deckDisplay or nil,
            teahouseDisplay = ecoData and ecoData.teahouseDisplay or nil,
            portalOwned = (ecoData and ecoData.portalOwned) or false,
        }
        local action = siteCoordinator:onJoin(uid, {
            maxDeckSize = playerEconomy[uid].maxDeckSize,
            teahouses = teahouses,
            deckDisplay = playerEconomy[uid].deckDisplay,
            teahouseDisplay = playerEconomy[uid].teahouseDisplay,
        }, prefs)
        if action then
            -- getEconomy yields; if the player left mid-call, PlayerRemoving's onLeave
            -- already ran as a no-op (nothing was held yet). Release the just-claimed pad
            -- so it doesn't leak lit for a departed player (and _held doesn't go stale).
            if not player:IsDescendantOf(Players) then
                local rel = siteCoordinator:onLeave(uid)
                if rel then
                    applier:apply(rel.padId, rel.spec, rel.treatment, rel.deckSize, rel.teahouse)
                end
                playerPrefs[uid] = nil
                playerHouse[uid] = nil
                playerEconomy[uid] = nil
                return
            end
            action.treatment.portalOwned = playerEconomy[uid].portalOwned
            applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
            playerEconomy[uid].claimedPadId = action.padId
            local tsize = action.teahouse and action.teahouse.size or "bare"
            print(`[D.5] {player.UserId} claimed {action.padId} deck={action.deckSize} teahouse={tsize}`)
            if action.teahouse ~= nil and action.teahouse.loadout ~= nil then
                playerHouse[uid] = {
                    padId = action.padId,
                    size = action.teahouse.size,
                    loadout = action.teahouse.loadout,
                }
                if player:IsDescendantOf(Players) then
                    BackDoorState:FireClient(player, {
                        padId = action.padId,
                        backDoorIndex = BackDoorEditor.backDoorIndex(action.teahouse.loadout.wallBays),
                    })
                end
            end
        end
        if player:IsDescendantOf(Players) then
            PreferenceState:FireClient(
                player,
                { padPreferences = playerPrefs[uid], names = namesFor(playerPrefs[uid]) }
            )
        end
        echoEconomy(player, uid)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    playerPrefs[tostring(player.UserId)] = nil
    playerHouse[tostring(player.UserId)] = nil
    playerEconomy[tostring(player.UserId)] = nil
    handlerQueue:clear(tostring(player.UserId))
    local action = siteCoordinator:onLeave(tostring(player.UserId))
    if action then
        applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
        print(`[D.4] {player.UserId} released {action.padId}`)
    end
end)

SetPadPreference.OnServerEvent:Connect(function(player, siteId)
    handlerQueue:run(tostring(player.UserId), function()
        if type(siteId) ~= "string" or PadSites[siteId] == nil then
            return -- ignore ill-typed / unknown site ids
        end
        local uid = tostring(player.UserId)
        local current = playerPrefs[uid] or {}
        local newList, favorited = PreferenceEditor.togglePreference(current, siteId, PREF_CAP)
        playerPrefs[uid] = newList
        local persisted = net:setPreferences(uid, newList)
        if not persisted.ok then
            warn(`[D.5] setPreferences failed for {uid}: {tostring(persisted.error)}`)
            playerPrefs[uid] = current
            if player:IsDescendantOf(Players) then
                -- revert client, no toast
                PreferenceState:FireClient(player, { padPreferences = current, names = namesFor(current) })
            end
            return
        end
        if player:IsDescendantOf(Players) then
            PreferenceState:FireClient(player, {
                padPreferences = newList,
                names = namesFor(newList),
                changed = siteId,
                favorited = favorited,
                name = PadSites[siteId].displayName or siteId,
            })
        end
    end)
end)

SetBackDoor.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local house = playerHouse[uid]
        if house == nil then
            return -- not occupying a teahouse this session; ignore (occupant-only)
        end
        -- find the live, already-materialized structure to read its back-bay count + re-render
        local siteFolder = sitesFolder:FindFirstChild("MaterializedSite_" .. house.padId)
        local structure = siteFolder and siteFolder:FindFirstChild("Structure")
        if structure == nil then
            return -- streaming / rebuild race: nothing to re-render (F2/F4)
        end
        local manifest = StructureOps.readManifest(structure)
        local backBayCount = 0
        for _, bay in manifest.bays do
            if bay.side == "back" then
                backBayCount += 1
            end
        end
        local bayIndex = if typeof(payload) == "table" then payload.bayIndex else nil
        if typeof(bayIndex) ~= "number" or bayIndex % 1 ~= 0 or bayIndex < 1 or bayIndex > backBayCount then
            return -- ill-typed / non-integer / out-of-range request
        end
        local newWallBays = BackDoorEditor.setBackDoor(house.loadout.wallBays, bayIndex, backBayCount)
        -- merge into a NEW copy of the occupied size's loadout (don't alias the stash pre-persist)
        local newLoadout = table.clone(house.loadout)
        newLoadout.wallBays = newWallBays
        -- live, server-authoritative re-render (replicates to every client)
        StructureOps.applyBays(structure, WallBays.resolve(manifest.bays, newWallBays))
        house.loadout = newLoadout
        -- rebuild paths (RequestPurchase upgrade, SetDisplay, buy-to-claim) render from this stash,
        -- not from playerHouse; keep it in sync or the next rebuild reverts this door.
        local e = playerEconomy[uid]
        if e ~= nil and e.teahouses ~= nil then
            e.teahouses[house.size] = newLoadout
        end
        -- best-effort persist: a failure keeps the live door this session (lost next join), no revert
        local persisted = net:setTeahouse(uid, house.size, newLoadout)
        if not persisted.ok then
            warn(`[B1] setTeahouse failed for {uid}/{house.size}: {tostring(persisted.error)}`)
        end
        if player:IsDescendantOf(Players) then
            BackDoorState:FireClient(player, {
                padId = house.padId,
                backDoorIndex = BackDoorEditor.backDoorIndex(newWallBays),
            })
        end
    end)
end)

RequestPurchase.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil then
            return
        end
        local item = if typeof(payload) == "table" then payload.item else nil
        if typeof(item) ~= "string" then
            return
        end
        local kindPre = string.match(item, "^(%a+):")
        -- buy-to-claim: a non-owner buying a deck:* claims the specific pad named in the payload.
        -- Validate + reserve-check the pad BEFORE spending points, so a full/occupied pad doesn't
        -- silently strand the player on a different pad (or no pad at all) after paying.
        local isBuyToClaim = e.claimedPadId == nil and kindPre == "deck"
        local claimPadId: string? = nil
        if isBuyToClaim then
            local padId = if typeof(payload) == "table" and typeof(payload.padId) == "string"
                then payload.padId
                else nil
            if padId == nil or PadSites[padId] == nil or not siteCoordinator:isVacant(padId) then
                warn(`[B2] buy-to-claim {item} for {uid} rejected: pad {tostring(padId)} unavailable`)
                echoEconomy(player, uid) -- resync the client's labels/balance
                return
            end
            claimPadId = padId
        end
        local res = net:postPurchase(uid, item)
        if not res.ok then
            warn(`[B2] purchase {item} failed for {uid}: {tostring(res.error)}`)
            echoEconomy(player, uid) -- resync the client's labels/balance
            return
        end
        -- the purchase HTTP call yielded; if the player left during it, do NOT claim/rebuild a pad
        -- for a departed uid (PlayerRemoving already ran as a no-op for the not-yet-claimed case,
        -- which would otherwise leak a scarce pad). Points are already persisted server-side.
        if not player:IsDescendantOf(Players) then
            playerEconomy[uid] = nil
            return
        end
        -- adopt the authoritative new state
        e.totalPoints = res.data.totalPoints
        e.maxDeckSize = res.data.maxDeckSize
        e.portalOwned = res.data.portalOwned or false
        local kind, size = string.match(item, "^(%a+):(%a+)$")
        if kind == "teahouse" and size then
            e.teahouses[size] = { baseStyle = "teahouse-1story" }
        end
        if isBuyToClaim and claimPadId then
            -- postPurchase yielded; re-check vacancy, a claim could have raced in meanwhile.
            if siteCoordinator:isVacant(claimPadId) then
                local action = siteCoordinator:onJoin(uid, {
                    maxDeckSize = e.maxDeckSize,
                    teahouses = e.teahouses,
                    deckDisplay = e.deckDisplay,
                    teahouseDisplay = e.teahouseDisplay,
                }, { claimPadId })
                if action ~= nil and action.padId == claimPadId then
                    action.treatment.portalOwned = e.portalOwned
                    applier:apply(
                        action.padId,
                        action.spec,
                        action.treatment,
                        action.deckSize,
                        action.teahouse
                    )
                    e.claimedPadId = action.padId
                    -- mirror the initial-join sync (below, ~line 502): the reachable case here is a
                    -- RETURNING owner whose auto-claim failed at join (pad scarcity -- every pad was
                    -- occupied), who already owns a teahouse loadout from a prior session and is now
                    -- buying a deck upgrade once a pad frees up. This claim builds their owned
                    -- teahouse for the first time this session, so playerHouse must track it too, or
                    -- the back door would stay inert for the rest of the session. (A brand-new player
                    -- can't reach this: validatePurchase enforces teahouse size <= owned deck size,
                    -- so a teahouse can never be bought before any deck.)
                    if action.teahouse ~= nil and action.teahouse.loadout ~= nil then
                        playerHouse[uid] = {
                            padId = action.padId,
                            size = action.teahouse.size,
                            loadout = action.teahouse.loadout,
                        }
                    else
                        playerHouse[uid] = nil
                    end
                    echoBackDoor(player, uid)
                else
                    warn(
                        `[B2] {uid} bought {item} but pad {claimPadId} could not be claimed this session`
                            .. " (will be auto-placed on next join)"
                    )
                end
            else
                warn(
                    `[B2] {uid} bought {item} but pad {claimPadId} was claimed by another player mid-purchase`
                        .. " (will be auto-placed on next join)"
                )
            end
        elseif e.claimedPadId ~= nil then
            -- upgrade: live-rebuild the claimed pad at the new sizes
            local spec = PadSites[e.claimedPadId]
            if spec then
                local teaSizes = {}
                for s in e.teahouses do
                    table.insert(teaSizes, s)
                end
                local built = SizeClasses.resolveBuilt(
                    e.maxDeckSize,
                    teaSizes,
                    spec.maxSize,
                    e.deckDisplay,
                    e.teahouseDisplay
                )
                if built then
                    local teaLoadout = if built.teahouseSize then e.teahouses[built.teahouseSize] else nil
                    local teahouse = if built.teahouseSize
                        then {
                            size = built.teahouseSize,
                            loadout = teaLoadout,
                            placement = (teaLoadout and teaLoadout.placement) or CENTERED_PLACEMENT,
                        }
                        else nil
                    local treatment =
                        { kind = "structure", loadout = teaLoadout, lit = true, portalOwned = e.portalOwned }
                    applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)
                    -- keep playerHouse in sync with the just-rebuilt structure (B3 final review):
                    -- a stale entry would validate SetBackDoor against the NEW structure's bay count
                    -- but persist the edit into the PREVIOUS size's loadout via net:setTeahouse.
                    if built.teahouseSize ~= nil then
                        playerHouse[uid] = {
                            padId = e.claimedPadId,
                            size = built.teahouseSize,
                            loadout = teaLoadout,
                        }
                    else
                        playerHouse[uid] = nil -- bare deck: no live loadout to edit
                    end
                    echoBackDoor(player, uid)
                end
            end
        end
        echoEconomy(player, uid)
    end)
end)

SetDisplay.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return -- must own+occupy a perch to set a display
        end
        local deckDisplay = if typeof(payload) == "table" then payload.deckDisplay else nil
        local teahouseDisplay = if typeof(payload) == "table" then payload.teahouseDisplay else nil
        if deckDisplay == e.deckDisplay and teahouseDisplay == e.teahouseDisplay then
            return -- no-op: display already at the requested values (defends a modified client / redundant queued item)
        end
        -- server is authoritative: persist through the PWA API (it re-validates against ownership)
        local res = net:postDisplay(uid, deckDisplay, teahouseDisplay)
        if not res.ok then
            warn(`[B3] postDisplay failed for {uid}: {tostring(res.error)}`)
            echoEconomy(player, uid) -- resync
            return
        end
        if not player:IsDescendantOf(Players) then
            return -- left during the HTTP yield; nothing to rebuild
        end
        e.deckDisplay = res.data.deckDisplay
        e.teahouseDisplay = res.data.teahouseDisplay
        -- live rebuild the claimed pad at the new displayed sizes
        local spec = PadSites[e.claimedPadId]
        if spec then
            local teaSizes = {}
            for s in e.teahouses do
                table.insert(teaSizes, s)
            end
            local built = SizeClasses.resolveBuilt(
                e.maxDeckSize,
                teaSizes,
                spec.maxSize,
                e.deckDisplay,
                e.teahouseDisplay
            )
            if built then
                local teaLoadout = if built.teahouseSize then e.teahouses[built.teahouseSize] else nil
                local teahouse = if built.teahouseSize
                    then {
                        size = built.teahouseSize,
                        loadout = teaLoadout,
                        placement = (teaLoadout and teaLoadout.placement) or CENTERED_PLACEMENT,
                    }
                    else nil
                local treatment =
                    { kind = "structure", loadout = teaLoadout, lit = true, portalOwned = e.portalOwned }
                applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)
                -- keep playerHouse in sync with the just-rebuilt structure (B3 final review): a
                -- stale entry would validate SetBackDoor against the NEW structure's bay count but
                -- persist the edit into the PREVIOUS size's loadout (or a hidden bare-deck pad's).
                if built.teahouseSize ~= nil then
                    playerHouse[uid] = {
                        padId = e.claimedPadId,
                        size = built.teahouseSize,
                        loadout = teaLoadout,
                    }
                else
                    playerHouse[uid] = nil -- teahouseDisplay == "none": bare deck, no live loadout
                end
                echoBackDoor(player, uid)
            end
        end
        echoEconomy(player, uid)
    end)
end)

SetPlacement.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return -- occupant-only, same discipline as SetDisplay
        end
        if typeof(payload) ~= "table" or typeof(payload.offset) ~= "table" then
            return
        end
        local dx, dz = payload.offset[1], payload.offset[2]
        local facing = payload.facing
        if typeof(dx) ~= "number" or dx ~= dx or math.abs(dx) == math.huge then
            return
        end
        if typeof(dz) ~= "number" or dz ~= dz or math.abs(dz) == math.huge then
            return
        end
        if facing ~= "N" and facing ~= "E" and facing ~= "S" and facing ~= "W" then
            return
        end
        local spec = PadSites[e.claimedPadId]
        if spec == nil then
            return
        end
        local teaSizes = {}
        for s in e.teahouses do
            table.insert(teaSizes, s)
        end
        local built =
            SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
        if built == nil or built.teahouseSize == nil then
            return -- bare deck / nothing built: nothing to move
        end
        local size = built.teahouseSize
        local buildingFP = SizeClasses.buildingFootprint(size)
        local boundsFP = SizeClasses.placementBounds(built.deckSize)
        if not BuildingPlacer.canFitFacing(buildingFP, boundsFP, facing) then
            return -- this facing cannot fit this built combination (UI never offers it)
        end
        -- server-authoritative: clamp the request against the BUILT combination and persist the
        -- clamped value (never raw client numbers)
        local clamped = BuildingPlacer.clamp(buildingFP, boundsFP, { offset = { dx, dz }, facing = facing })
        -- merge into a NEW copy of the built size's loadout (pre-persist clone discipline)
        if e.teahouses[size] == nil then
            return -- built size has no owned loadout (non-contiguous ownership; defensive)
        end
        local existingPlacement = e.teahouses[size].placement
        if
            existingPlacement ~= nil
            and existingPlacement.facing == clamped.facing
            and existingPlacement.offset[1] == clamped.offset[1]
            and existingPlacement.offset[2] == clamped.offset[2]
        then
            return -- no-op: placement already at the clamped target
        end
        local newLoadout = table.clone(e.teahouses[size])
        newLoadout.placement = clamped
        local persisted = net:setTeahouse(uid, size, newLoadout)
        if not persisted.ok then
            warn(`[B4] setTeahouse(placement) failed for {uid}/{size}: {tostring(persisted.error)}`)
            echoEconomy(player, uid) -- resync
            return
        end
        if not player:IsDescendantOf(Players) then
            return -- left during the HTTP yield; nothing to rebuild
        end
        if e.teahouses[size] == nil then
            return -- stash vanished during the yield (defensive, mirrors the pre-yield guard)
        end
        -- post-yield: merge ONLY the placement onto the CURRENT stash (a SetBackDoor landing during
        -- the yield must not be clobbered by our pre-yield snapshot — B4 final review)
        local fresh = table.clone(e.teahouses[size])
        fresh.placement = clamped
        e.teahouses[size] = fresh
        -- post-yield: a SetDisplay may have landed during the HTTP yield; recompute what is built
        -- NOW and rebuild only if the size we just placed is still the one standing (its rebuild
        -- already rendered the pre-move placement; ours must not stamp stale sizes over it)
        local teaSizesNow = {}
        for s in e.teahouses do
            table.insert(teaSizesNow, s)
        end
        local builtNow = SizeClasses.resolveBuilt(
            e.maxDeckSize,
            teaSizesNow,
            spec.maxSize,
            e.deckDisplay,
            e.teahouseDisplay
        )
        if builtNow == nil or builtNow.teahouseSize ~= size then
            return -- persisted + stash-merged; the standing build belongs to a newer state
        end
        local teahouse = { size = size, loadout = fresh, placement = clamped }
        local treatment = { kind = "structure", loadout = fresh, lit = true, portalOwned = e.portalOwned }
        applier:apply(e.claimedPadId, spec, treatment, builtNow.deckSize, teahouse)
        playerHouse[uid] = { padId = e.claimedPadId, size = size, loadout = fresh }
        echoBackDoor(player, uid) -- geometry watch re-arms the F prompts on the new structure
    end)
end)

print(`[ROSHAMBO] playable loop starting against {config.baseUrl}`)
task.spawn(function()
    while true do
        local delay = coordinator:pollOnce()
        task.wait(delay)
    end
end)
