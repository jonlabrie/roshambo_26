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

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local FateResolved = remotes:WaitForChild("FateResolved") :: RemoteEvent
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent
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
local stage = workspace:WaitForChild("RoshamboStage")
for _, child in stage:GetChildren() do
    if child:IsA("Model") then
        child.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
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

-- D.2: lifecycle + vacant state — two pads; a joining owner claims one (lit), the
-- other stays dormant; release on leave. Replaces D.1's static single-owner block.
local StructureBuilder = require(shared:WaitForChild("StructureBuilder"))
local PadBuilder = require(shared:WaitForChild("PadBuilder"))
local StructureCatalog = require(shared:WaitForChild("StructureCatalog"))
local PadRegistry = require(shared:WaitForChild("PadRegistry"))
local SiteCoordinator = require(shared:WaitForChild("SiteCoordinator"))
local StructureOps = require(script.Parent:WaitForChild("StructureOps"))
local PadOps = require(script.Parent:WaitForChild("PadOps"))
local PadSites = require(script.Parent:WaitForChild("PadSites"))
local TreatmentApplier = require(script.Parent:WaitForChild("TreatmentApplier"))

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
})

-- cliff-proof registered first: the sole local joiner claims it; cliff-proof-2 stays dormant
for _, id in { "cliff-proof", "cliff-proof-2" } do
    siteCoordinator:registerPad(id, PadSites[id])
end
for _, action in siteCoordinator:vacantActions() do
    applier:buildSupport(action.spec)
    applier:apply(action.padId, action.spec, action.treatment)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        local res = net:getTeahouses(tostring(player.UserId))
        local loadout = if res.ok then (res.data.teahouses or {}).M else nil
        local action = siteCoordinator:onJoin(tostring(player.UserId), loadout)
        if action then
            applier:apply(action.padId, action.spec, action.treatment)
            print(`[D.2] {player.UserId} claimed {action.padId}`)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local action = siteCoordinator:onLeave(tostring(player.UserId))
    if action then
        applier:apply(action.padId, action.spec, action.treatment)
        print(`[D.2] {player.UserId} released {action.padId}`)
    end
end)

print(`[ROSHAMBO] playable loop starting against {config.baseUrl}`)
task.spawn(function()
    while true do
        local delay = coordinator:pollOnce()
        task.wait(delay)
    end
end)
