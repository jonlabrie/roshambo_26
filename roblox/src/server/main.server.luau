--!strict
-- Composition root: wires Roblox services into the runtime-agnostic modules.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))
local RoundCoordinator = require(script.Parent:WaitForChild("RoundCoordinator"))
local ThrowBuffer = require(script.Parent:WaitForChild("ThrowBuffer"))
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

BankRequest.OnServerEvent:Connect(function(player)
    task.spawn(function()
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

-- The teahouse each player currently occupies, for occupant-gated live edits (B1 back door):
-- padId + the occupied SIZE + that size's loadout (the merge target for wallBays edits).
local playerHouse: { [string]: { padId: string, size: string, loadout: any } } = {}

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
        local res = net:getTeahouses(tostring(player.UserId))
        -- a non-ok fetch reads as "owns nothing" (no pad this session, no retry)
        local owned = if res.ok then res.data.teahouses or {} else nil
        local prefs = if res.ok then res.data.padPreferences else nil
        local uid = tostring(player.UserId)
        playerPrefs[uid] = prefs or {}
        local action = siteCoordinator:onJoin(uid, owned, prefs)
        if action then
            -- getTeahouses yields; if the player left mid-call, PlayerRemoving's onLeave
            -- already ran as a no-op (nothing was held yet). Release the just-claimed pad
            -- so it doesn't leak lit for a departed player (and _held doesn't go stale).
            if not player:IsDescendantOf(Players) then
                local rel = siteCoordinator:onLeave(uid)
                if rel then
                    applier:apply(rel.padId, rel.spec, rel.treatment, rel.deckSize, rel.teahouse)
                end
                playerPrefs[uid] = nil
                playerHouse[uid] = nil
                return
            end
            applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
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
            PreferenceState:FireClient(player, { padPreferences = playerPrefs[uid] })
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    playerPrefs[tostring(player.UserId)] = nil
    playerHouse[tostring(player.UserId)] = nil
    local action = siteCoordinator:onLeave(tostring(player.UserId))
    if action then
        applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
        print(`[D.4] {player.UserId} released {action.padId}`)
    end
end)

SetPadPreference.OnServerEvent:Connect(function(player, siteId)
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
            PreferenceState:FireClient(player, { padPreferences = current }) -- revert client, no toast
        end
        return
    end
    if player:IsDescendantOf(Players) then
        PreferenceState:FireClient(player, {
            padPreferences = newList,
            changed = siteId,
            favorited = favorited,
            name = PadSites[siteId].displayName or siteId,
        })
    end
end)

SetBackDoor.OnServerEvent:Connect(function(player, payload)
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
    if typeof(bayIndex) ~= "number" or bayIndex < 1 or bayIndex > backBayCount then
        return -- ill-typed / out-of-range request
    end
    local newWallBays = BackDoorEditor.setBackDoor(house.loadout.wallBays, bayIndex, backBayCount)
    -- merge into a NEW copy of the occupied size's loadout (don't alias the stash pre-persist)
    local newLoadout = table.clone(house.loadout)
    newLoadout.wallBays = newWallBays
    -- live, server-authoritative re-render (replicates to every client)
    StructureOps.applyBays(structure, WallBays.resolve(manifest.bays, newWallBays))
    house.loadout = newLoadout
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

print(`[ROSHAMBO] playable loop starting against {config.baseUrl}`)
task.spawn(function()
    while true do
        local delay = coordinator:pollOnce()
        task.wait(delay)
    end
end)
