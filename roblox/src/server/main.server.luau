--!strict
-- Composition root: wires Roblox services into the runtime-agnostic modules.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

-- Day/Night cycle: publish the fixed, global cycle constants once at boot as attributes on a
-- replicated Configuration. Clients derive t locally from workspace:GetServerTimeNow() (Roblox's
-- globally-synced Unix clock) + this FIXED epoch, so every player in every server instance sees the
-- same time-of-day at the same real moment. The server streams nothing afterward. (Foundation only;
-- the glyph/waterfall subscribers bind to EventBus.DayNight — see the day/night design spec.)
local DAY_NIGHT_EPOCH = 1735689600 -- fixed absolute anchor (2025-01-01T00:00:00Z, synced Unix seconds)
local dayNightConfig = Instance.new("Configuration")
dayNightConfig.Name = "DayNightConfig"
-- DEV KNOBS (Workspace number attributes, place-state, set in Edit — CLEAR BEFORE
-- PUBLISH or the published game loses the shared global clock):
--   "DayNightLockT"  freezes the cycle at that t every Play session — 0.19 = mid-day,
--                    0.75 = deep night (phases run dawn 10 / day 18 / dusk 25 / night 47 %).
--   "DayNightStartT" anchors the cycle at that t at session start, then runs LIVE —
--                    e.g. 0.953 ≈ 4 AM pre-dawn. Lock wins if both are set.
-- Remove the attribute(s) to restore the epoch-anchored global cycle.
local lockT = workspace:GetAttribute("DayNightLockT")
local startT = workspace:GetAttribute("DayNightStartT")
if typeof(lockT) == "number" then
    dayNightConfig:SetAttribute("CycleEpoch", workspace:GetServerTimeNow())
    dayNightConfig:SetAttribute("CycleLength", 1e9)
    dayNightConfig:SetAttribute("PhaseOffset", lockT)
elseif typeof(startT) == "number" then
    local LEN = 600
    dayNightConfig:SetAttribute("CycleEpoch", workspace:GetServerTimeNow() - startT * LEN)
    dayNightConfig:SetAttribute("CycleLength", LEN)
    dayNightConfig:SetAttribute("PhaseOffset", 0)
else
    dayNightConfig:SetAttribute("CycleEpoch", DAY_NIGHT_EPOCH)
    dayNightConfig:SetAttribute("CycleLength", 600) -- seconds per full loop (10 min); the manual timing knob
    dayNightConfig:SetAttribute("PhaseOffset", 0) -- fraction, aligns the global clock; gate-tuned
end
dayNightConfig.Parent = ReplicatedStorage

-- Round schedule for the client metronome (round-metronome spec): absolute times
-- on the GetServerTimeNow timeline, refreshed by RoundCoordinator's onSchedule.
local roundScheduleConfig = Instance.new("Configuration")
roundScheduleConfig.Name = "RoundScheduleConfig"
roundScheduleConfig.Parent = ReplicatedStorage

local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))
local RoundCoordinator = require(script.Parent:WaitForChild("RoundCoordinator"))
local ThrowBuffer = require(script.Parent:WaitForChild("ThrowBuffer"))
local HandlerQueue = require(script.Parent:WaitForChild("HandlerQueue"))
local PortalController = require(script.Parent:WaitForChild("PortalController"))
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local RoundClock = require(shared:WaitForChild("RoundClock"))
local CollectionService = game:GetService("CollectionService")
local LaunchSites = require(shared:WaitForChild("LaunchSites"))
local MortarPlacement = require(shared:WaitForChild("MortarPlacement"))
local FireworkCatalog = require(shared:WaitForChild("FireworkCatalog"))
local BoostLuck = require(shared:WaitForChild("BoostLuck"))
local GameRules = require(shared:WaitForChild("GameRules"))
local PlayerProfiles = require(shared:WaitForChild("PlayerProfiles"))
local ThemeManifest = require(shared:WaitForChild("ThemeManifest"))
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local FateRegistry = require(shared:WaitForChild("FateRegistry"))
local HudPrefs = require(shared:WaitForChild("HudPrefs"))
local Kamon = require(shared:WaitForChild("Kamon"))
local KamonDraw = require(shared:WaitForChild("KamonDraw"))
local PreferenceEditor = require(shared:WaitForChild("PreferenceEditor"))
local BackDoorEditor = require(shared:WaitForChild("BackDoorEditor"))
local WallBays = require(shared:WaitForChild("WallBays"))
local PortalTarget = require(shared:WaitForChild("PortalTarget"))
local ShojiRun = require(shared:WaitForChild("ShojiRun"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local SetHudPreference = remotes:WaitForChild("SetHudPreference") :: RemoteEvent
local RequestLedger = remotes:WaitForChild("RequestLedger") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local FateResolved = remotes:WaitForChild("FateResolved") :: RemoteEvent
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent
local FamiliarRoster = remotes:WaitForChild("FamiliarRoster") :: RemoteEvent
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent
local SetBackDoor = remotes:WaitForChild("SetBackDoor") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent
local SlideShoji = remotes:WaitForChild("SlideShoji") :: RemoteEvent
local ShojiState = remotes:WaitForChild("ShojiState") :: RemoteEvent
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local RequestSync = remotes:WaitForChild("RequestSync") :: RemoteEvent
local SetDisplay = remotes:WaitForChild("SetDisplay") :: RemoteEvent
local SetPlacement = remotes:WaitForChild("SetPlacement") :: RemoteEvent
local SetDecorationPlacement = remotes:WaitForChild("SetDecorationPlacement") :: RemoteEvent
local SetMortarPlacement = remotes:WaitForChild("SetMortarPlacement") :: RemoteEvent
local SetDecorationRemove = remotes:WaitForChild("SetDecorationRemove") :: RemoteEvent
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
local SetAccess = remotes:WaitForChild("SetAccess") :: RemoteEvent
local InviteUser = remotes:WaitForChild("InviteUser") :: RemoteEvent
local RevokeUser = remotes:WaitForChild("RevokeUser") :: RemoteEvent
local AccessState = remotes:WaitForChild("AccessState") :: RemoteEvent
local AccessBlocked = remotes:WaitForChild("AccessBlocked") :: RemoteEvent
local RequestFireworkLaunch = remotes:WaitForChild("RequestFireworkLaunch") :: RemoteEvent
local FireworkLaunched = remotes:WaitForChild("FireworkLaunched") :: RemoteEvent
local FireworkState = remotes:WaitForChild("FireworkState") :: RemoteEvent
local RequestProvingFire = remotes:WaitForChild("RequestProvingFire") :: RemoteEvent
local StatsData = remotes:WaitForChild("StatsData") :: RemoteEvent
local StatsPersonal = remotes:WaitForChild("StatsPersonal") :: RemoteEvent
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

-- Everyone arrives at ArenaSpawn: disable any other (place-only, e.g. leftover DevChannelSpawn)
-- SpawnLocation, and make sure ArenaSpawn itself is enabled. Code-only + self-healing.
for _, inst in workspace:GetDescendants() do
    if inst:IsA("SpawnLocation") then
        inst.Enabled = inst.Name == "ArenaSpawn"
    end
end

-- The shop's trigger volume ships inside the Rojo model, so it is here at startup rather than
-- created at runtime. Tagging it server-side means the client can find it by tag (which
-- replicates) instead of by a path that would break the moment a second shop is built.
do
    local hanabiya = stage:FindFirstChild("Hanabiya")
    local threshold = hanabiya and hanabiya:FindFirstChild("Threshold")
    if threshold then
        threshold:SetAttribute("shopId", "hanabiya")
        CollectionService:AddTag(threshold, "ShopThreshold")
    elseif hanabiya == nil then
        -- Say so. Silence here looks exactly like a working shop that nobody can open, and the
        -- likeliest cause is mundane: a place that has not been re-synced from Rojo since the
        -- model was added.
        warn("[SHOP] RoshamboStage.Hanabiya is missing — the shop cannot open (re-sync from Rojo?)")
    else
        warn("[SHOP] RoshamboStage.Hanabiya has no Threshold child — the shop cannot open")
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

-- HUD preferences are not wallet fields, so they do not live on a PlayerProfiles row. They ride
-- ProfileUpdate all the same: without that the client can only hard-default its preferences and
-- the ledger's preference switches would be write-only. Absent = the profile's own defaults, ON.
-- ONE ROW PER PLAYER, not one map per preference: they travel together on ProfileUpdate, they are
-- written by the same remote and repaired by the same ledger refresh, and a second parallel map is
-- how one of them ends up cleared on leave and the other left behind.
--
-- The default/merge RULE itself lives in shared/HudPrefs.luau, not here: this file is
-- Roblox-runtime only and Lune never loads it, so a bug in the merge (the exact failure this was
-- built to prevent — see HudPrefs.luau's header) would be invisible to every test this repo has.
-- ===== THE FAMILIAR ROSTER =====
-- Plumage is SOCIAL -- the whole point is that other people see your grade -- so every client
-- needs every PRESENT player's band, not just their own.
--
-- THE WHOLE ROSTER, NOT A DELTA. It is one small table for the players actually here, it is sent
-- only on events that are already rare (join, leave, a grade change at settlement, and most
-- rounds change nobody's), and a late-joining client needs the full picture anyway. A delta
-- protocol here would be complexity bought with nothing.
local familiarRoster: { [string]: any } = {}

local function pushFamiliarRoster()
    FamiliarRoster:FireAllClients(familiarRoster)
end

local hudPrefs: { [string]: HudPrefs.Prefs } = {}

-- Absent = the profile's own defaults, both ON. The stored row is returned BY REFERENCE for reads;
-- anything that writes must clone first (see SetHudPreference), because the failure-revert there
-- holds the pre-write row and an in-place edit would quietly rewrite its own undo.
local function prefsFor(uid: string): HudPrefs.Prefs
    local row = hudPrefs[uid]
    if row then
        return row
    end
    return HudPrefs.DEFAULTS
end

-- The onboarding beats a player has already dismissed, same treatment as hudPrefs: not a wallet
-- field, so it rides ProfileUpdate as its own per-instance cache rather than living on
-- PlayerProfiles. OnboardingController seeds its local "seenLocal" list from this once and then
-- tracks dismissals itself for the rest of the session — this cache exists so a REJOIN (a fresh
-- OnboardingController with nothing seeded yet) does not re-show a beat the player already
-- dismissed last time.
-- NIL MEANS "NOT KNOWN", not "nothing seen". The two are different answers and the client acts on
-- them differently: an empty list says "a genuine first-timer, teach them", nil says "the profile
-- has not answered yet, teach them nothing". They were conflated (`or {}` in fireProfile), which is
-- how a failed join fetch re-taught a veteran the whole game — see fireProfile below.
local hudSeenBeats: { [string]: { string } } = {}

-- Bumped by every accepted SetHudPreference fire. RequestLedger stamps it before its GET and
-- compares afterwards, so a response that was already in flight when a write landed is not applied
-- over the newer value. That is the whole mechanism keeping the ledger's authoritative refresh —
-- the only thing that repairs these two caches when the join fetch failed — from clobbering a
-- concurrent preference toggle.
local hudWriteSeq: { [string]: number } = {}

-- The nine ledger counters are not wallet fields either, so they get the same treatment as hudPrefs:
-- a per-instance cache, carried on ProfileUpdate.
--
-- They are NEVER advanced locally. The wallet can be, because the reconciliation loop overwrites it
-- authoritatively every round; these have no such path, and the local reveal is computed from the
-- pick buffer whether or not the POST /throws flush ever reached the backend. An accumulating
-- counter could therefore only drift UPWARD — a player watches ROUNDS THROWN climb to 40, rejoins,
-- and sees 37. A lifetime total that goes DOWN is worse than one that is briefly stale.
--
-- Instead they are RE-SEEDED FROM THE AUTHORITATIVE PROFILE when the player opens the ledger (see
-- RequestLedger). Opening maximal is a deliberate, occasional act, and these numbers only matter on
-- the one occasion someone looks at them.
type Counters = { [string]: number }
local COUNTER_KEYS = {
    "roundsPlayed",
    "wins",
    "safes",
    "losses",
    "lifetimeBanked",
    "bestPot",
    "throwsR",
    "throwsP",
    "throwsS",
}
local ledgerCounters: { [string]: Counters } = {}

local function seedCounters(userId: string, from: any)
    local out: Counters = {}
    for _, key in COUNTER_KEYS do
        local v = if type(from) == "table" then from[key] else nil
        out[key] = if type(v) == "number" then v else 0
    end
    ledgerCounters[userId] = out
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
            unresolvedWin = row.unresolvedWin,
            escalationPrompts = prefsFor(tostring(player.UserId)).escalationPrompts,
            resultSplash = prefsFor(tostring(player.UserId)).resultSplash,
            statusBars = prefsFor(tostring(player.UserId)).statusBars,
            counters = ledgerCounters[tostring(player.UserId)],
            -- NOT `or {}`. This fires from the reveal ("local") and reconciliation ("reconciled")
            -- paths too, which run whether or not the join fetch ever succeeded — so substituting
            -- an empty list for an unknown one told the client "this player has dismissed nothing"
            -- on the strength of a failed HTTP call, and every onboarding beat re-showed. nil is
            -- the honest answer and the client waits for a real one.
            seenBeats = hudSeenBeats[tostring(player.UserId)],
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
local lastTapeId: string? = nil
-- Declared up here because the round callback below re-broadcasts it the instant a
-- round settles, and that callback is wired long before the stats poller is built.
local lastStats: any = nil

-- FORWARD DECLARATION. The referee's helpers need playerEconomy and PadSites, which are built far
-- below; but the reveal fan-out just above here has to re-push shell state the moment a round
-- closes. Declared here, assigned once those exist.
local pushFireworkState: ((Player) -> ())? = nil

-- FORWARD DECLARATION. pushFireworkState (below, but textually BEFORE rebuildClaimedPad is
-- declared) needs to trigger the same pad rebuild the decoration flow uses whenever the fireworks
-- GET's mortars/mortarPlacements actually changed -- mortars now render server-side (TreatmentApplier)
-- like decorations, so late-arriving mortar data needs the identical rebuild, not just a state echo.
-- Assigned right after `local function rebuildClaimedPad` is defined.
local rebuildClaimedPadFn: ((string) -> ())? = nil

-- FORWARD DECLARATION (final-review fix round). muzzleOriginFor (below, but textually BEFORE
-- deckCFForUid is declared) must resolve the SAME (row, deckSize) pair the render path actually
-- built with -- deckCFForUid already runs SizeClasses.resolveBuilt + DeckPlacement.resolve(...,
-- built.deckSize, spec.maxSize), the exact call rebuildClaimedPad/TreatmentApplier use, honoring
-- an active display-shrink (SetDisplay) or pad cap (spec.maxSize) that deckRowFor's raw
-- `e.maxDeckSize or "S"` lookup does not. Assigned right after `local function deckCFForUid`.
local deckCFForUidFn: ((string) -> ({ number }?, string?))? = nil

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
                -- PUSH THE TAPE THE MOMENT A ROUND SETTLES. It used to ride only on the 60s
                -- stats poll, which is exactly the round period -- so the poll aliased with the
                -- round and landed at the same phase offset forever. The owner saw the summary
                -- board refresh with about four seconds left in every round and nowhere else.
                -- `onRound` fires on each phase change, but the tape only grows at settlement,
                -- so this is gated on the newest entry's id rather than on the callback.
                local newest = info.tape[1] and info.tape[1].id
                local grew = newest ~= lastTapeId
                lastTape = info.tape
                lastTapeId = newest
                if grew and lastStats then
                    lastStats.tape = lastTape
                    StatsData:FireAllClients(lastStats)
                end
            end
        end,
        -- WHEN CELEBRATIONS COME BACK, FIRE THEM ON THE DRUM, NOT ON THE WIRE. RevealTheater
        -- lands ~3s before the drum settles, so anything triggered on the remote is early. The
        -- recipe the deleted applyGrow used: delay by
        -- math.clamp(StrikeAtServerTime - workspace:GetServerTimeNow() + DrumStep.SETTLE_SECONDS,
        -- 0, DrumStep.SETTLE_SECONDS + LockSec) — clamped so it fails late, never early.
        --
        -- And it has to be SERVER-side: Humanoid scale replicates server->client only, so an
        -- avatar effect triggered on the client is visible to nobody but its owner.
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
                    -- Two things just changed: ishibana's window opened or closed with the world
                    -- throw, and a WIN has granted a firecracker. Without this the picker shows a
                    -- stale WAITING_FOR_R and a count one behind. A stale state can never produce a
                    -- WRONG firework — the referee re-validates every launch — but it can produce a
                    -- button a player will not tap.
                    if pushFireworkState then
                        pushFireworkState(player)
                    end
                end
            end
        end,
        onSchedule = function(s)
            -- local epoch ms -> GetServerTimeNow seconds: both clocks are "now" here,
            -- so carry the delta across.
            local strikeSt = workspace:GetServerTimeNow() + (s.strikeAtMs - deps.now()) / 1000
            roundScheduleConfig:SetAttribute("RoundId", s.roundId)
            roundScheduleConfig:SetAttribute("RoundCount", s.roundCount)
            roundScheduleConfig:SetAttribute("PeriodSec", s.periodMs / 1000)
            roundScheduleConfig:SetAttribute("OpenSec", s.openMs / 1000)
            roundScheduleConfig:SetAttribute("LockSec", s.lockMs / 1000)
            roundScheduleConfig:SetAttribute("RevealSec", s.revealMs / 1000)
            -- StrikeAtServerTime LAST: clients pull the whole schedule on its change.
            roundScheduleConfig:SetAttribute("StrikeAtServerTime", strikeSt)
        end,
        onReconciled = function(rows)
            for _, row in rows do
                -- /instances/.../results carries round results, not wallet state -- it has no
                -- unresolvedWin field. Pass through the row's current value; defaulting to false
                -- would drop the pot indicator's pulse on every reconciliation.
                local existing = profiles:get(row.robloxUserId)
                profiles:applyServer(row.robloxUserId, {
                    totalPoints = row.totalPoints,
                    pointsAtStake = row.pot,
                    currentStreak = row.streak,
                    stakingStreak = row.streak,
                    bestStreak = math.max(row.streak, (existing or { bestStreak = 0 }).bestStreak),
                    unresolvedWin = existing ~= nil and existing.unresolvedWin,
                })
                -- ⚠ MERGE, NEVER REPLACE: the entry also carries grade/gradeName/band/rank set
                -- elsewhere. And this is AUTHORITATIVE BUT LATE -- reconciliation lands on the next
                -- round's OPEN -- which is why AuraController also derives a streak optimistically
                -- from the reveal. Do not "fix" that by making the aura wait for this: a glow that
                -- lingers a round after a LOSS is a lie, and worse than one that starts late.
                -- ⚠ `row.streak` IS currentStreak: Settlement.ts:189 writes
                -- `streak: updated.currentStreak` into the results row. The field used to be named
                -- stakingStreak here and carried this value anyway, so the roster disagreed with
                -- itself between join and reconciliation. Now both say currentStreak and mean it.
                local rosterEntry = familiarRoster[row.robloxUserId]
                if rosterEntry then
                    rosterEntry.currentStreak = row.streak
                end
                local player = playerByUserId(row.robloxUserId)
                if player then
                    pushStats(player)
                    fireProfile(player, "reconciled")
                end
            end
            -- ONE push for the whole batch. Pushing inside the loop sends the entire roster once
            -- per reconciled player, which at fifty players is fifty broadcasts of one table.
            pushFamiliarRoster()
        end,
    },
})

-- Parked defect (n), fixed 2026-09-05: every PlayerAdded site now sweeps the players ALREADY
-- present after connecting -- a join that lands during any bootstrap yield above a connect was
-- silently missed (the mortar CSG hit exactly that window, d510c69: dead session, no claim).
-- Each handler is join-idempotent so the sweep-vs-event double run is harmless.
local function onPlayerJoinProfile(player: Player)
    if player:FindFirstChild("leaderstats") then
        return -- already processed (catch-up sweep raced the real event)
    end
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    for _, name in { "Points", "Pot", "Streak" } do
        local v = Instance.new("IntValue")
        v.Name = name
        v.Parent = stats
    end
    stats.Parent = player

    -- Zeros BEFORE the fetch, unconditionally. Seeding only inside `if res.ok` would leave the cache
    -- nil for the whole session on one transient failure, and ProfileUpdate is the ledger's ONLY
    -- channel — a nil there takes the live hero band and the preference switch down with the
    -- counters, none of which self-heal the way the wallet does.
    seedCounters(tostring(player.UserId), nil)

    task.spawn(function()
        local country: string? = nil
        pcall(function()
            country = LocalizationService:GetCountryRegionForPlayerAsync(player)
        end)
        local res = net:getPlayer(tostring(player.UserId), country, player.DisplayName)
        if res.ok then
            hudPrefs[tostring(player.UserId)] = HudPrefs.fromProfile(res.data)
            hudSeenBeats[tostring(player.UserId)] = if type(res.data.seenBeats) == "table"
                then res.data.seenBeats
                else {}
            seedCounters(tostring(player.UserId), res.data.counters)
            -- The join call already carries grade/gradeName/band, so the roster costs no request
            -- of its own.
            familiarRoster[tostring(player.UserId)] = {
                grade = res.data.grade,
                gradeName = res.data.gradeName,
                band = res.data.band,
                -- The aura needs both halves of every OTHER player: how deep their run is, and
                -- whether they have allowed anyone to see it. The roster is the only thing every
                -- client holds about everyone, so both ride here.
                --
                -- ⚠ currentStreak, NOT stakingStreak. Banking resets stakingStreak, and banking is
                -- THE decision in this game — tying the reward display to not-banking punishes the
                -- action the whole loop is built around, and is a large part of why so few players
                -- ever lit up. currentStreak survives a bank and reads as "how well are you calling
                -- the crowd", which is the skill on offer. Owner ruling 2026-08-25.
                currentStreak = res.data.currentStreak,
                auraVisibility = HudPrefs.fromProfile(res.data).auraVisibility,
            }
            pushFamiliarRoster()
            profiles:applyServer(tostring(player.UserId), {
                totalPoints = res.data.totalPoints,
                pointsAtStake = res.data.pointsAtStake,
                currentStreak = res.data.currentStreak,
                stakingStreak = res.data.stakingStreak,
                bestStreak = res.data.bestStreak,
                unresolvedWin = res.data.unresolvedWin,
            })
            pushStats(player)
            fireProfile(player, "sync")
        else
            warn(`[PROFILE] sync failed for {player.UserId}: {res.error or res.status}`)
        end
    end)
end

Players.PlayerAdded:Connect(onPlayerJoinProfile)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayerJoinProfile, p)
end

SubmitPick.OnServerEvent:Connect(function(player, throwValue)
    if type(throwValue) ~= "string" then
        return
    end
    -- PARKED, not removed. Nothing calls fates:begin any more (see the reveal handler), so this
    -- is always false — it is one table lookup and it is the seam anything like this re-enters
    -- through. FateRegistry and its tests are intact.
    if fates:isBound(tostring(player.UserId)) then
        print(`[PICK] {player.Name} rejected: FATE_BOUND`)
        return
    end
    -- No win gate: an unbanked pot never blocks a throw, because throwing again IS riding it.
    -- A fate is the only thing that refuses a pick here.
    local accepted, reason = coordinator:submitPick(tostring(player.UserId), throwValue)
    if not accepted then
        print(`[PICK] {player.Name} rejected: {reason}`)
    end
end)

local handlerQueue = HandlerQueue.new(task.spawn)

-- ⚠ `keep` IS THE ONLY THING READ OFF THE WIRE HERE — identity comes from `player`, which
-- OnServerEvent supplies, never from the payload ([[identity]]'s standing rule). A client cannot
-- bank someone else's pot by sending an id, because no id is sent.
--
-- A malformed keep REFUSES rather than defaulting to 0: 0 means a FULL bank, so the lenient
-- reading would cash out the player's whole pot on a garbled message. The server then validates
-- the value against that player's own pot and answers 409 if it is not a rung, so nothing here
-- has to know the ladder.
BankRequest.OnServerEvent:Connect(function(player, rawKeep)
    local keep = GameRules.keepFromWire(rawKeep)
    if keep == nil then
        warn(`[Bank] refusing malformed keep from {player.UserId}: {tostring(rawKeep)}`)
        return
    end
    handlerQueue:run(tostring(player.UserId), function()
        local res = net:postBank(tostring(player.UserId), keep)
        if res.ok then
            -- /bank's response doesn't carry unresolvedWin, but wallet.bankPot sets it false in
            -- the same atomic update, so mirror that rather than passing a now-stale true through.
            local existing = profiles:get(tostring(player.UserId))
            profiles:applyServer(tostring(player.UserId), {
                totalPoints = res.data.totalPoints,
                pointsAtStake = res.data.pointsAtStake,
                currentStreak = res.data.currentStreak,
                stakingStreak = res.data.stakingStreak,
                bestStreak = (existing or { bestStreak = 0 }).bestStreak,
                unresolvedWin = false,
            })
            pushStats(player)
            fireProfile(player, "banked")
        end
    end)
end)

-- The ledger's authoritative refresh. Fired when the player OPENS maximal, which is the one moment
-- the nine lifetime counters are actually looked at.
--
-- NOT hung off RequestSync, which was checked first and is the wrong hook: it is the late-listener
-- recovery path — it re-echoes state already cached on this server and makes no network call, and
-- EconomySync fires it on a 1s retry loop up to twenty times per join. Putting an HTTP fetch behind
-- it would mean up to twenty GET /players per player per join.
--
-- The counters, the HUD preferences and the seen-beats list are taken from the response; the
-- WALLET deliberately is not. The reconciliation loop already owns the wallet authoritatively, and a
-- mid-round fetch could stomp a fresher local reveal with a settlement that has not happened yet.
--
-- This is also the ONLY repair path for hudPrefs/hudSeenBeats: they are otherwise written once, by
-- the join fetch, inside its `if res.ok`. If that GET failed they stay nil for the session — the
-- player's preferences silently read back as ON however the database has them, and their
-- dismissed onboarding beats are unknown. Opening the ledger is what fixes both.
--
-- WHAT IT MUST NOT DO is apply a response that went stale in flight. The failure that flagged it:
-- open the ledger (fires this GET), toggle the escalation switch inside its latency window ->
-- SetHudPreference sets the cache and PUTs -> this GET returns carrying the PRE-toggle value and
-- overwrites it, and fireProfile echoes it back, so the switch visibly flips itself back. Hence the
-- sequence stamp: `hudWriteSeq[uid]` is read before the GET and re-read after, and the two
-- preference fields are applied only if no write landed in between. A raced refresh yields to the
-- write (which is authoritative — it is what the database now holds) instead of either clobbering
-- it or throwing the whole response away.
local lastLedgerFetch: { [string]: number } = {}
local LEDGER_FETCH_DEBOUNCE = 3

RequestLedger.OnServerEvent:Connect(function(player)
    local uid = tostring(player.UserId)
    local now = os.clock()
    if lastLedgerFetch[uid] ~= nil and now - lastLedgerFetch[uid] < LEDGER_FETCH_DEBOUNCE then
        return
    end
    lastLedgerFetch[uid] = now
    -- Stamped BEFORE the yield, compared after: see the note above.
    local seqAtFetch = hudWriteSeq[uid] or 0
    task.spawn(function()
        local res = net:getPlayer(uid)
        if not res.ok then
            -- The panel keeps whatever it last had rather than blanking; it is stale, not wrong.
            warn(`[LEDGER] refresh failed for {uid}: {res.error or res.status}`)
            return
        end
        seedCounters(uid, res.data.counters)
        if (hudWriteSeq[uid] or 0) == seqAtFetch then
            hudPrefs[uid] = HudPrefs.fromProfile(res.data)
            if type(res.data.seenBeats) == "table" then
                hudSeenBeats[uid] = res.data.seenBeats
            end
        end
        fireProfile(player, "ledger")
    end)
end)

SetHudPreference.OnServerEvent:Connect(function(player, body)
    if type(body) ~= "table" then
        return
    end
    local payload: { [string]: any } = {}
    if type(body.escalationPrompts) == "boolean" then
        payload.escalationPrompts = body.escalationPrompts
    end
    if type(body.resultSplash) == "boolean" then
        payload.resultSplash = body.resultSplash
    end
    if type(body.statusBars) == "boolean" then
        payload.statusBars = body.statusBars
    end
    if type(body.seenBeat) == "string" then
        payload.seenBeat = body.seenBeat
    end
    -- ⚠ Validated against the set rather than merely type-checked, exactly as HudPrefs.merge and
    -- the API route do. An unrecognised string must be refused, not written and not defaulted: a
    -- privacy setting knocked back to permissive by a malformed body is worse than a no-op.
    if HudPrefs.isVisibility(body.auraVisibility) then
        payload.auraVisibility = body.auraVisibility
    end
    if next(payload) == nil then
        return
    end
    -- Stamp the write NOW — before the queue wait and before the PUT, both of which yield — so an
    -- in-flight RequestLedger refresh knows its response predates this write and must not apply its
    -- own (older) preference fields over it. Bumped on the accepted FIRE rather than on the cache
    -- mutation so the guarded window covers the whole life of the write, queue time included.
    hudWriteSeq[tostring(player.UserId)] = (hudWriteSeq[tostring(player.UserId)] or 0) + 1
    -- THROUGH THE QUEUE, like every other mutating handler (SetPadPreference, SetBackDoor,
    -- RequestPurchase, BankRequest). This body yields on HTTP, and a bare task.spawn per fire meant
    -- a scripted client looping this remote could issue unbounded concurrent PUTs — enough to eat
    -- the ~500/min per-server HttpService budget and starve RoundCoordinator's own calls, breaking
    -- the round loop for all 50 players in the instance. The lane serializes one player's writes
    -- and drops the overflow past MAX_PENDING.
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        -- Cache first, PUT second, revert if the PUT fails — the same shape as SetPadPreference.
        -- The cache has to move first because an intervening fireProfile (a bank landing moments
        -- later) would otherwise echo the PRE-write value and appear to undo the switch; it has to
        -- be reverted on failure for the mirror-image reason, so the session never asserts a value
        -- the database does not hold.
        local prevPref = hudPrefs[uid]
        local prevBeats = hudSeenBeats[uid]
        if payload.escalationPrompts ~= nil or payload.resultSplash ~= nil or payload.statusBars ~= nil then
            -- MERGED onto the current row via the shared rule (see HudPrefs.luau), never inline
            -- and never replacing it: one remote carries every preference and a body naming only
            -- one of them must not silently reset another to its default.
            hudPrefs[uid] = HudPrefs.merge(prefsFor(uid), payload :: HudPrefs.Patch)
        end
        if payload.seenBeat ~= nil then
            -- Add-only, and only if new: OnboardingController already marks the beat seen
            -- optimistically, so this just guards the cache other events read from.
            local existing = hudSeenBeats[uid] or {}
            local already = false
            for _, id in existing do
                if id == payload.seenBeat then
                    already = true
                    break
                end
            end
            if not already then
                local merged = table.clone(existing)
                table.insert(merged, payload.seenBeat)
                hudSeenBeats[uid] = merged
            end
        end
        local persisted = net:putHudPreference(uid, payload)
        if not persisted.ok then
            warn(`[HUD] putHudPreference failed for {uid}: {persisted.error or persisted.status}`)
            hudPrefs[uid] = prevPref
            hudSeenBeats[uid] = prevBeats
            if player:IsDescendantOf(Players) then
                -- Re-fire state so the optimistic switch in the ledger footer flips back rather
                -- than leaving the player looking at a control that silently did nothing.
                fireProfile(player, "hudPrefRevert")
            end
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

-- Per-player, per-shell consecutive boost misses (the pity ramp's only state; BoostLuck
-- owns the math). Session-lived by design -- a rejoin starts at the honest floor.
local boostMisses: { [string]: { [string]: number } } = {}

Players.PlayerRemoving:Connect(function(player)
    fates:remove(tostring(player.UserId))
    -- Drop them from the roster and tell everyone, or their bird outlives them on every other
    -- client: BirdController keys on the roster, not on Players, so a stale entry is a stale bird.
    familiarRoster[tostring(player.UserId)] = nil
    pushFamiliarRoster()
    hudPrefs[tostring(player.UserId)] = nil
    ledgerCounters[tostring(player.UserId)] = nil
    lastLedgerFetch[tostring(player.UserId)] = nil
    hudSeenBeats[tostring(player.UserId)] = nil
    boostMisses[tostring(player.UserId)] = nil
    hudWriteSeq[tostring(player.UserId)] = nil
end)

local lastBoard: any = nil
task.spawn(function()
    while true do
        local res = net:getLeaderboards("world")
        local worldRec, hotStreak = nil, nil
        if res.ok and res.data.leaders then
            local top = res.data.leaders[1]
            if top then
                -- lifetimeBanked, NOT totalPoints: the board is sorted by career earnings
                -- server-side, and totalPoints is a spendable wallet that drops on every
                -- purchase -- reading it here would print a number that does not match the
                -- order the rows arrived in.
                worldRec = {
                    banked = top.lifetimeBanked or 0,
                    name = filterExternalName(top.displayName or "?"),
                }
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

local function onPlayerJoinBoard(player: Player)
    if lastBoard then
        BoardData:FireClient(player, lastBoard) -- re-fire is an idempotent client update
    end
end
Players.PlayerAdded:Connect(onPlayerJoinBoard)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayerJoinBoard, p) -- defect (n): catch a join that landed before this connect
end

-- FIX 4: names in leaders/recordsWeek/recordsAll/heat are EXTERNAL (player-chosen display
-- names) and this feed broadcasts to every client, world-visible on the Stats room's walls —
-- unlike the pushStatsPersonal 404 fallback below, which sends a name Roblox has already
-- moderated. StatsBoardModel.sanitize is not a substitute: it only uppercases and strips
-- non-ASCII, so ASCII abuse (still filterable, still offensive) passes straight through.
--
-- Cached by raw name so a name that keeps ranking round after round costs one filter call, not
-- one per 60s cycle. UNBOUNDED on purpose: the key space is the set of names that have ever
-- ranked into a top-10 (leaderboard, streak/bank/round records, or heat) — small next to the
-- player population, and this table lives only for the game server's process lifetime anyway.
local nameFilterCache: { [string]: string } = {}
local function cachedFilterName(name: string): string
    local cached = nameFilterCache[name]
    if cached then
        return cached
    end
    local filtered = filterExternalName(name)
    nameFilterCache[name] = filtered
    return filtered
end

-- Filter only what is RENDERED: no board in the Stats room shows more than 10 rows, so rows
-- past the 10th are left as-is rather than spent on a filter call nothing will ever display.
local STATS_BOARD_ROWS = 10
local function filterTop(list: { any }?): { any }
    local out = {}
    for i, row in list or {} do
        if i <= STATS_BOARD_ROWS then
            local copy = table.clone(row)
            copy.displayName = cachedFilterName(row.displayName or "?")
            table.insert(out, copy)
        else
            table.insert(out, row)
        end
    end
    return out
end

local function filterRecords(records: any?): any?
    if not records then
        return records
    end
    local copy = table.clone(records)
    copy.longestStreaks = filterTop(records.longestStreaks)
    copy.biggestBanks = filterTop(records.biggestBanks)
    copy.biggestRounds = filterTop(records.biggestRounds)
    return copy
end

-- The board arrives already named and already gated by the server; the only thing left to strip
-- is anything a client has no business holding. Its own filter rather than folded into
-- filterRecords so a future field on either cannot silently ride along on the other.
local function filterBoard(board: any?): any?
    if not board then
        return board
    end
    local copy = table.clone(board)
    copy.rows = filterTop(board.rows)
    return copy
end

local function filterHeat(heat: any?): any?
    if not heat then
        return heat
    end
    local copy = table.clone(heat)
    copy.leaders = filterTop(heat.leaders)
    return copy
end

-- THE STATS ROOM'S FEED. Separate from the BoardData poller above on purpose: that one is the
-- arena's 30s heartbeat and these are four REST reads whose own Cache-Control is 15-30s, so
-- pulling them on the same tick would triple the arena's request rate for walls nobody may be
-- standing in front of. 60s is slower than any of the caches and still far finer than the
-- cadence at which a career board actually moves.
task.spawn(function()
    while true do
        local leaders = net:getLeaderboards("world")
        local week = net:getStatsRecords("week")
        local all = net:getStatsRecords("all")
        local heat = net:getStatsHeat("day", nil)
        local board = net:getStatsBoard()
        -- Each field is independently nil-able: one endpoint failing must leave the other three
        -- boards showing their last good content rather than blanking the whole room.
        lastStats = {
            leaders = if leaders.ok
                then filterTop(leaders.data.leaders)
                else (lastStats and lastStats.leaders),
            recordsWeek = if week.ok then filterRecords(week.data) else (lastStats and lastStats.recordsWeek),
            recordsAll = if all.ok then filterRecords(all.data) else (lastStats and lastStats.recordsAll),
            heat = if heat.ok then filterHeat(heat.data) else (lastStats and lastStats.heat),
            board = if board.ok then filterBoard(board.data) else (lastStats and lastStats.board),
            depths = if board.ok then board.data.depths else (lastStats and lastStats.depths),
            tape = lastTape,
        }
        StatsData:FireAllClients(lastStats)
        -- 47, NOT 60. A 60s wait is exactly the round period (OPEN 51 + LOCK 2 +
        -- REVEAL 7), so the poll would alias with the round and refresh the slow
        -- boards at the same phase offset forever. 47 still clears the 30s and 15s
        -- Cache-Control windows on the endpoints it reads.
        task.wait(47)
    end
end)

-- The personal slip. Per-player, so it is pushed per-player: on join, and on the same 60s beat.
--
-- ⚠ IT ALSO FEEDS THE ROSTER, AT NO EXTRA COST. The status bars over a player's head need that
-- player's GRADE and RANK, and this response already carries both — so harvesting them here means
-- the bars refresh on a beat that already exists rather than adding a per-player request per
-- round. Rank moves as OTHER people play, so it genuinely needs refreshing; grade only ever
-- increases and only for its owner, which is why a join-time snapshot was enough for it alone.
local function pushStatsPersonal(player: Player)
    local res = net:getStatsPlayer(tostring(player.UserId))
    -- A 404 is the NORMAL state for someone who has never thrown. Send the empty shape rather
    -- than nothing, so the slip renders its zeros instead of hanging on "no data".
    StatsPersonal:FireClient(player, if res.ok then res.data else { displayName = player.DisplayName })
    if res.ok then
        local d = res.data
        local standing = d.week and d.week.standing
        local entry = familiarRoster[tostring(player.UserId)] or {}
        entry.grade = d.grade or entry.grade
        entry.gradeName = d.gradeName or entry.gradeName
        entry.band = d.band or entry.band
        -- ABSENT, not zero, when unqualified: the bar's absence is itself information — this
        -- player has not put in the 360 throws to be measured at all.
        entry.rank = standing and standing.rank or nil
        entry.of = standing and standing.of or nil
        familiarRoster[tostring(player.UserId)] = entry
        pushFamiliarRoster()
    end
end

local function onPlayerJoinStats(player: Player)
    if lastStats then
        StatsData:FireClient(player, lastStats) -- re-fire is an idempotent client update
    end
    task.spawn(pushStatsPersonal, player)
end
Players.PlayerAdded:Connect(onPlayerJoinStats)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayerJoinStats, p) -- defect (n): catch a join that landed before this connect
end

task.spawn(function()
    while true do
        task.wait(60)
        for _, player in Players:GetPlayers() do
            task.spawn(pushStatsPersonal, player)
        end
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
local DecorationLayout = require(shared:WaitForChild("DecorationLayout"))
local DecorationCatalog = require(shared:WaitForChild("DecorationCatalog"))
local AccessPolicy = require(shared:WaitForChild("AccessPolicy"))
local AccessGates = require(shared:WaitForChild("AccessGates"))
local StructureOps = require(script.Parent:WaitForChild("StructureOps"))
local PadOps = require(script.Parent:WaitForChild("PadOps"))
local PadSites = require(script.Parent:WaitForChild("PadSites"))
local TreatmentApplier = require(script.Parent:WaitForChild("TreatmentApplier"))

local playerPrefs: { [string]: { string } } = {}
local PREF_CAP = 32
local MAX_INVITED = 50 -- mirrors server/src/economy.ts MAX_INVITED
local ACCESS_MODES = { public = true, friends = true, private = true }

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

-- SHOJI (task 5): one active hold-to-slide loop per uid. Declared up here (not beside the
-- SlideShoji handler further down) because PlayerRemoving, which runs long before that handler in
-- the file, needs to stop a leaving player's loop immediately and flush any pending persist.
type ShojiSlide = {
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
local shojiSlides: { [string]: ShojiSlide } = {}

-- The debounced persist-on-hold-end target, one per SLIDE (uid + padId + side + index), not one
-- per uid (2026-08-18 review fix: a shared per-uid counter let sliding screen B within the quiet
-- window cancel screen A's still-pending write with no error and no trace). `shojiPersistGen` is
-- this generation counter, keyed by that composite key; `shojiPendingPersist` holds the latest
-- target awaiting each key's debounce, so PlayerRemoving can flush it immediately instead of
-- leaving it to wake up later and find playerHouse[uid] already gone.
type ShojiPersistTarget = {
    uid: string,
    padId: string,
    side: string,
    index: number,
    count: number,
    bay: Model,
}
local shojiPersistGen: { [string]: number } = {}
local shojiPendingPersist: { [string]: ShojiPersistTarget } = {}
local function shojiSlideKey(uid: string, padId: string, side: string, index: number): string
    return `{uid}\1{padId}\1{side}\1{index}`
end

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
        deckDecorations: { any },
        teahouseAccess: { mode: string, invited: { number } },
        -- owned mortar tiers + their stored placements (deck-mortars, 2026-09-04): both arrive
        -- on the fireworks GET (pushFireworkState), not the economy GET -- bootstrapped empty
        -- here, filled moments later once that first pushFireworkState lands.
        mortars: { string },
        mortarPlacements: { [string]: MortarPlacement.StoredPlacement }?,
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
        deckDecorations = e.deckDecorations,
        mortars = e.mortars,
        mortarPlacements = e.mortarPlacements,
    })
end

-- Persist ONE shoji slide's final travel, occupant-only: clone the loadout, set
-- shojiOpen[side][index] to the bay's live ShojiOpen attribute, net:setTeahouse, mirror into
-- playerEconomy -- the same three-step shape SetBackDoor uses further down (stash, mirror,
-- persist), for the same reason: rebuild paths render from the stash, not from playerHouse. A
-- visitor's slide (playerHouse[uid] absent, or occupying a different pad) writes nothing at all:
-- no error, no message, it simply is not theirs to keep. Declared here (well before the
-- SlideShoji handler itself) because PlayerRemoving needs to call it directly to flush a pending
-- debounced persist before playerHouse[uid] is cleared.
local function persistShojiNow(target: ShojiPersistTarget)
    local uid = target.uid
    handlerQueue:run(uid, function()
        local house = playerHouse[uid]
        if house == nil or house.padId ~= target.padId then
            return -- a visitor's slide is not theirs to keep
        end
        if not target.bay:IsDescendantOf(workspace) then
            return -- structure gone (rebuild/leave race): nothing live to read
        end
        local finalAttr = target.bay:GetAttribute("ShojiOpen")
        local finalOpen = if typeof(finalAttr) == "number" then finalAttr else 0
        local existingSide = house.loadout.shojiOpen and house.loadout.shojiOpen[target.side]
        local resolvedList = ShojiRun.resolve(existingSide, target.count)
        -- quantized, not raw: see ShojiRun.quantize -- `shojiOpen` shares one 4096-byte loadout
        -- document with every other teahouse setting, and a rejected document loses ALL of them.
        resolvedList[target.index] = ShojiRun.quantize(ShojiRun.clamp(target.index, target.count, finalOpen))
        -- merge into a NEW copy of the occupied size's loadout (don't alias the stash pre-persist)
        local newShojiOpen = table.clone(house.loadout.shojiOpen or {})
        newShojiOpen[target.side] = resolvedList
        local newLoadout = table.clone(house.loadout)
        newLoadout.shojiOpen = newShojiOpen
        house.loadout = newLoadout
        local e = playerEconomy[uid]
        if e ~= nil and e.teahouses ~= nil then
            e.teahouses[house.size] = newLoadout
        end
        local persisted = net:setTeahouse(uid, house.size, newLoadout)
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
-- ONE call: read playerHouse[uid] ONCE, HERE, before any queueing happens, merge every pending
-- target's final ShojiOpen into a single cloned loadout, and close over that already-built
-- loadout (and size) as plain captured locals in a single queued thunk -- never re-reading
-- playerHouse[uid] from inside it. That makes the clearing order irrelevant: there is nothing left
-- in the thunk that a later `nil` could invalidate. One HTTP call also costs less than N against a
-- budget the round loop shares.
local function flushShojiForUid(uid: string)
    local targets: { ShojiPersistTarget } = {}
    for key, target in shojiPendingPersist do
        if target.uid == uid then
            table.insert(targets, target)
            shojiPendingPersist[key] = nil
            shojiPersistGen[key] = nil -- so a debounce that later wakes cannot write a second time
        end
    end
    if #targets == 0 then
        return
    end
    local house = playerHouse[uid]
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
        if target.padId ~= house.padId or not target.bay:IsDescendantOf(workspace) then
            continue -- stale: occupancy moved on, or the structure died (rebuild/leave race)
        end
        local resolvedList = resolvedBySide[target.side]
        if resolvedList == nil then
            local existingSide = house.loadout.shojiOpen and house.loadout.shojiOpen[target.side]
            resolvedList = ShojiRun.resolve(existingSide, target.count)
            resolvedBySide[target.side] = resolvedList
            newShojiOpen[target.side] = resolvedList
        end
        local finalAttr = target.bay:GetAttribute("ShojiOpen")
        local finalOpen = if typeof(finalAttr) == "number" then finalAttr else 0
        resolvedList[target.index] = ShojiRun.quantize(ShojiRun.clamp(target.index, target.count, finalOpen))
        wroteAny = true
    end
    if not wroteAny then
        return -- every pending target turned out stale; nothing left to persist
    end
    local newLoadout = table.clone(house.loadout)
    newLoadout.shojiOpen = newShojiOpen
    house.loadout = newLoadout
    local e = playerEconomy[uid]
    if e ~= nil and e.teahouses ~= nil then
        e.teahouses[house.size] = newLoadout
    end
    local size = house.size -- captured now; the thunk below never re-reads playerHouse[uid]
    -- DEFERRED, not queued inline (2026-08-18 final review). handlerQueue drains its lane on a
    -- freshly spawned thread, which runs synchronously up to its first yield -- and the first
    -- thing this thunk does is a yielding HTTP PUT. Queueing it here therefore parked
    -- PlayerRemoving inside setTeahouse, delaying siteCoordinator:onLeave (the pad release) a few
    -- lines below by the transport's own latency, or by its full timeout when the backend is sick.
    -- The write itself has no deadline; the pad release does, because the next player to walk up
    -- to that pad is waiting on it. Everything the thunk needs is already captured above, so the
    -- delay costs it nothing.
    task.defer(function()
        handlerQueue:run(uid, function()
            local persisted = net:setTeahouse(uid, size, newLoadout)
            if not persisted.ok then
                warn(`[SHOJI] setTeahouse (flush) failed for {uid}/{size}: {tostring(persisted.error)}`)
            end
        end)
    end)
end

-- ============================ FIREWORKS: THE REFEREE ============================
-- A client asks; the server decides, spends, and only then tells everyone. A client never announces
-- its own firework. That is both the anti-cheat property and the perf rule: the server emits one
-- tiny event and every client renders locally from its own catalogue, so nothing about the show
-- crosses the wire per particle.
local SITE_RADIUS = 24

-- The newest tape entry is the last CLOSED round, which is exactly what ishibana's condition is
-- about. The tape already arrives on every poll — nothing extra is fetched to answer this.
local function lastWorldThrow(): string?
    local newest = lastTape and lastTape[1]
    return newest and newest.worldThrow or nil
end

-- Public sites are tagged in the place, not declared here — Rojo owns no place geometry.
-- NOTE: with no part tagged FireworkLaunchSite, the only site a player has is their own deck.
local function fireworkSites(): { LaunchSites.Site }
    local sites: { LaunchSites.Site } = {}
    for _, part in CollectionService:GetTagged("FireworkLaunchSite") do
        if part:IsA("BasePart") then
            local p = part.Position
            table.insert(
                sites,
                { pos = { x = p.X, y = p.Y, z = p.Z }, radius = SITE_RADIUS, ownerUserId = nil }
            )
        end
    end
    return sites
end

-- A player's own deck is a site for that player ALONE. Returns nil when they own no deck, which is
-- the common case for a new player: they use the public sites. The deck does NOT lend a mortar —
-- gear is personal, and the tube is the thing you bought.
-- (row, deckSize) for uid's claimed pad -- the exact `spec.deckPlacements` row deckSiteFor turns
-- into a launch-site position. Shared so RequestFireworkLaunch's muzzle math reads the IDENTICAL
-- row a launch was just validated against, rather than a second lookup that could drift from it.
local function deckRowFor(uid: string): ({ number }?, string?)
    local e = playerEconomy[uid]
    if e == nil or e.claimedPadId == nil then
        return nil, nil
    end
    local spec = PadSites[e.claimedPadId]
    if spec == nil then
        return nil, nil
    end
    local deckSize = e.maxDeckSize or "S"
    local row = spec.deckPlacements[deckSize] or spec.deckPlacements.S
    if row == nil then
        return nil, nil
    end
    return row, deckSize
end

local function deckSiteFor(uid: string): LaunchSites.Site?
    local row = deckRowFor(uid)
    if row == nil then
        return nil
    end
    return { pos = { x = row[1], y = row[2], z = row[3] }, radius = SITE_RADIUS, ownerUserId = uid }
end

-- The built teahouse's deck-local AABB for uid, or nil for a bare/vacant deck -- computed by the
-- IDENTICAL pure math TreatmentApplier itself uses (SizeClasses.buildingFootprint +
-- BuildingPlacer.resolveFit + BuildingPlacer.footprintBounds) from the SAME state `e` and
-- rebuildClaimedPad already read (built teahouse size/placement via SizeClasses.resolveBuilt).
-- Muzzle alignment (Task 5's controller ruling): muzzleOriginFor calls this so the mortar tube
-- TreatmentApplier renders and the muzzle origin the server computes resolve from the identical
-- footprint -- they can never drift onto two different answers for the same stored placement.
local function teahouseFootprintFor(e: any): any
    if e.claimedPadId == nil then
        return nil
    end
    local spec = PadSites[e.claimedPadId]
    if spec == nil then
        return nil
    end
    local teaSizes = {}
    for s in e.teahouses do
        table.insert(teaSizes, s)
    end
    local built =
        SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
    if built == nil or built.teahouseSize == nil then
        return nil -- bare deck: nothing to nudge away from
    end
    local teaLoadout = e.teahouses[built.teahouseSize]
    local requested = (teaLoadout and teaLoadout.placement) or CENTERED_PLACEMENT
    local buildingFP = SizeClasses.buildingFootprint(built.teahouseSize)
    -- placementBounds, not deckFootprint: mirrors TreatmentApplier._buildBuilding exactly (the
    -- railings occupy the deck footprint's perimeter).
    local deckFP = SizeClasses.placementBounds(built.deckSize)
    local placement = BuildingPlacer.resolveFit(buildingFP, deckFP, requested)
    if placement == nil then
        return nil -- pathological: even the N fallback doesn't fit; TreatmentApplier renders deck-only too
    end
    return BuildingPlacer.footprintBounds(buildingFP, placement)
end

-- Muzzle-true origin AND heading for a gear-required shell fired from the player's OWN deck:
-- runs MortarPlacement's resolved deck-local spot for the shell's required tier through the SAME
-- (row, deckSize) the render path actually built with. Deliberately NOT deckRowFor/deckSiteFor's
-- row (final-review fix round): deckSiteFor's own site-radius check just above stays on
-- deckRowFor's row (its tolerance makes the raw `e.maxDeckSize or "S"` lookup benign there, and
-- that's out of scope by controller ruling) -- but the MUZZLE math below needs deckCFForUid's
-- pair specifically, since that's the one SizeClasses.resolveBuilt + DeckPlacement.resolve(...,
-- built.deckSize, spec.maxSize) run through, matching rebuildClaimedPad/TreatmentApplier exactly.
-- Using deckRowFor here (as this used to) would transform through the WRONG row and feed
-- MortarPlacement.resolve the WRONG deck bounds whenever a display-shrink (SetDisplay) or pad cap
-- (spec.maxSize) is active -- while teahouseFootprintFor below already used resolveBuilt, so the
-- two halves of this same function were resolving two different deck sizes.
-- Returns (nil, nil) (fall back to the eye-level origin, no heading) when: the shell needs no gear
-- (MortarPlacement.SHELL_MORTAR has no entry for it, e.g. firecracker); the player isn't standing
-- at THIS deck specifically (a public site takes the eye-level origin even where it happens to
-- overlap someone's deck); or the required tier isn't actually owned/resolved there. Whether the
-- launch was even ALLOWED for a missing tier is the backend's call (postFireworkSpend already ran
-- by the time this is consulted) -- this only decides where an already-granted shell leaves from
-- and along what axis (mount-aware: rail-mounted tubes lean, floor tubes fire per their aim).
local function muzzleOriginFor(
    uid: string,
    pos: Vector3,
    deck: LaunchSites.Site?,
    shellId: string
): (Vector3?, Vector3?)
    local requiredMortar = MortarPlacement.SHELL_MORTAR[shellId]
    if requiredMortar == nil or deck == nil then
        return nil, nil
    end
    local dx, dz = pos.X - deck.pos.x, pos.Z - deck.pos.z
    if dx * dx + dz * dz > deck.radius * deck.radius then
        return nil, nil -- admitted by some OTHER site (e.g. a public plaza), not this deck
    end
    local row: { number }? = nil
    local deckSize: string? = nil
    if deckCFForUidFn then
        row, deckSize = deckCFForUidFn(uid)
    end
    local e = playerEconomy[uid]
    if row == nil or deckSize == nil or e == nil then
        return nil, nil
    end
    local bounds = SizeClasses.deckFootprint(deckSize)
    local teahouseFP = teahouseFootprintFor(e)
    local placement = MortarPlacement.resolve(bounds, e.mortars, e.mortarPlacements, teahouseFP)
    local spot = placement[requiredMortar]
    if spot == nil then
        return nil, nil -- required tier not owned; nothing to be muzzle-true FROM
    end
    local ox, oy, oz, hx, hy, hz = MortarPlacement.launch(row, spot, requiredMortar)
    return Vector3.new(ox, oy, oz), Vector3.new(hx, hy, hz)
end

-- Cheap dirty-check for "did this uid's owned mortars/placements actually change since the pad
-- last rendered them": a deterministic string (ordered by MORTAR_ORDER, not raw table iteration
-- order, which Lua/HTTP-JSON round-trips don't guarantee stays stable). Pure; no Roblox datatypes.
local function mortarFingerprint(mortars: { string }, placements: { [string]: any }?): string
    local ownedSet: { [string]: boolean } = {}
    for _, id in mortars do
        ownedSet[id] = true
    end
    local parts = {}
    for _, id in MortarPlacement.MORTAR_ORDER do
        if ownedSet[id] then
            local p = placements and placements[id]
            if p then
                table.insert(parts, `{id}:{p.offset[1]},{p.offset[2]},{p.mount},{p.aim}`)
            else
                table.insert(parts, id)
            end
        end
    end
    return table.concat(parts, "|")
end
-- Last fingerprint a uid's claimed pad was actually REBUILT with, so pushFireworkState's frequent
-- polling (every reveal, after every launch) doesn't rebuild the pad when nothing changed.
local mortarRenderedFingerprint: { [string]: string } = {}

-- Push the whole shell state to one player: after every launch (their count changed), at every
-- reveal (the window moved, a grant may have landed) and once on join. HTTP-yielding, so it runs on
-- the HandlerQueue like every other call here rather than a bare task.spawn per event.
pushFireworkState = function(player: Player)
    local uid = tostring(player.UserId)
    handlerQueue:run(uid, function()
        local res = net:getFireworks(uid, lastWorldThrow())
        if res.ok and player:IsDescendantOf(Players) then
            -- Tell the client where its OWN deck-site is. The deck was always a valid
            -- launch site server-side, but the HUD's affordance only knew the tagged
            -- public sites — so at your own teahouse the fire button never appeared
            -- (owner, 2026-09-04: "we haven't made that work yet!"). It had; it hid.
            local deck = deckSiteFor(uid)
            res.data.deckSite = if deck then deck.pos else nil
            -- Mirror the fireworks GET's mortar fields into playerEconomy (deck-mortars,
            -- 2026-09-04) -- this is the ONLY place e.mortars/e.mortarPlacements get their real
            -- values (neither rides the economy GET); every treatment/echo table that already
            -- carries deckDecorations reads them from here. res.data.mortarPlacements may
            -- legitimately be nil/absent (a fresh player with no stored overrides), so it is
            -- adopted directly, not defaulted away.
            local e = playerEconomy[uid]
            if e ~= nil then
                e.mortars = res.data.mortars or e.mortars
                e.mortarPlacements = res.data.mortarPlacements
                -- Mortars render server-side now (TreatmentApplier, like decorations), so
                -- late-arriving/changed mortar state needs the same pad rebuild the decoration
                -- flow uses -- guarded by the fingerprint so a reveal where nothing changed
                -- doesn't rebuild the pad (this fires far more often than any decoration event).
                -- Belt-and-braces (final-review fix round): only RECORD the fingerprint when a
                -- rebuild actually ran while the pad is claimed -- an unclaimed uid has no pad to
                -- render, so remembering "rendered with fp X" here would be a lie that could later
                -- suppress the real first rebuild once they do claim.
                if e.claimedPadId ~= nil then
                    local fp = mortarFingerprint(e.mortars, e.mortarPlacements)
                    if mortarRenderedFingerprint[uid] ~= fp then
                        mortarRenderedFingerprint[uid] = fp
                        if rebuildClaimedPadFn then
                            rebuildClaimedPadFn(uid)
                        end
                    end
                end
            end
            FireworkState:FireClient(player, res.data)
        end
    end)
end

RequestFireworkLaunch.OnServerEvent:Connect(function(player, shellId)
    if typeof(shellId) ~= "string" then
        return
    end
    local uid = tostring(player.UserId)
    handlerQueue:run(uid, function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root then
            return
        end
        local pos = root.Position
        local sites = fireworkSites()
        local deck = deckSiteFor(uid)
        if deck then
            table.insert(sites, deck)
        end
        if not LaunchSites.isValid({ x = pos.X, y = pos.Y, z = pos.Z }, sites, uid) then
            return -- not at a site; the client should not have offered the button
        end
        -- SPEND FIRST, BROADCAST SECOND. The reverse order would show a shell the player was not
        -- charged for whenever the spend loses its race.
        local res = net:postFireworkSpend(uid, shellId)
        if not res.ok then
            if pushFireworkState then
                pushFireworkState(player) -- re-sync: their count was not what they thought
            end
            return
        end
        -- A gear-required shell fired from the player's own deck launches from its mortar's
        -- actual muzzle. A NON-gear shell (firecracker) is "the shell you hold": hand height in
        -- character space -- right, half a stud up, a touch forward -- never the old 6-studs-
        -- overhead placeholder (owner gate, 2026-09-04: "firecrackers fire from over my head").
        -- Gear shells at PUBLIC sites keep the invisible overhead origin (spec: unchanged).
        local origin, heading = muzzleOriginFor(uid, pos, deck, shellId)
        if origin == nil and MortarPlacement.SHELL_MORTAR[shellId] ~= nil then
            -- PUBLIC TUBES (owner, 2026-09-06: shells from the arena square used to
            -- detonate "right above you: worst possible position"): a gear shell fired
            -- at a public site launches from the nearest battery's muzzle when one is
            -- in reach -- the Hanabiya rooftop serves the square. Several tubes: one
            -- drawn at random per launch. Hand shells (firecracker) stay in hand.
            local nearTubes = {}
            for _, mount in CollectionService:GetTagged("FireworkTubeMount") do
                if mount:IsA("BasePart") and (mount.Position - pos).Magnitude <= 140 then
                    table.insert(nearTubes, mount)
                end
            end
            if #nearTubes > 0 then
                local mount = nearTubes[math.random(1, #nearTubes)]
                local muzzle = mount.Size.Y / 2 + MortarPlacement.TUBE["mortar:L"].length
                origin = mount.Position + Vector3.new(0, muzzle + 0.2, 0)
            end
        end
        if origin == nil then
            if MortarPlacement.SHELL_MORTAR[shellId] == nil then
                origin = root.CFrame:PointToWorldSpace(Vector3.new(1.2, 0.6, -0.8))
            else
                origin = root.Position + Vector3.new(0, 6, 0)
            end
        end
        -- THE PITY RAMP (owner, 2026-09-06; math in BoostLuck): the server rolls this
        -- shell's luck against a per-player per-shell miss streak and sends the VERDICT --
        -- every client renders the same luck, and a paying player's drought is bounded.
        -- Recipes without boost get no field; the client's seeded roll stays the fallback.
        -- Streaks are session-lived by design: a rejoin starts at the honest floor.
        local boosted: boolean? = nil
        local baseChance = BoostLuck.baseChance(FireworkCatalog.RECIPES[shellId])
        if baseChance then
            local streaks = boostMisses[uid] or {}
            boostMisses[uid] = streaks
            local verdict, newMisses = BoostLuck.roll(baseChance, streaks[shellId] or 0, math.random())
            streaks[shellId] = newMisses
            boosted = verdict
        end
        FireworkLaunched:FireAllClients({
            shellId = shellId,
            origin = origin,
            heading = heading and { x = heading.X, y = heading.Y, z = heading.Z } or nil,
            seed = math.random(1, 2 ^ 31 - 1),
            by = uid,
            boosted = boosted,
        })
        if pushFireworkState then
            pushFireworkState(player)
        end
    end)
end)

-- THE PROVING RANGE (spec 2026-09-01-proving-range-design). Studio-only: fires any shell or
-- draft id from a named proving rack through the SAME FireworkLaunched broadcast the spend
-- path uses — director, LOD, pooling all engaged — but with NO inventory spend and NO backend
-- call. The IsStudio gate is the whole security model: a published client's request dies here.
RequestProvingFire.OnServerEvent:Connect(function(_player, shellId, rackName, forceBoost)
    if not RunService:IsStudio() then
        return
    end
    if typeof(shellId) ~= "string" or typeof(rackName) ~= "string" then
        return
    end
    local stageForProving = workspace:FindFirstChild("RoshamboStage")
    local ground = stageForProving and stageForProving:FindFirstChild("ProvingGround")
    local rack = ground and ground:FindFirstChild(rackName)
    if not (rack and rack:IsA("BasePart")) then
        return
    end
    FireworkLaunched:FireAllClients({
        shellId = shellId,
        -- rack.Position is the 6" tube's CENTER; +1.25 (its half-length) is the MUZZLE.
        -- +3 floated shells two studs above the tube (owner, 2026-09-03).
        origin = rack.Position + Vector3.new(0, 1.25, 0),
        seed = math.random(1, 2 ^ 31 - 1),
        by = "proving",
        -- The panel's Boost button forces the lucky roll (Studio-only path); absent,
        -- the client's seeded roll keeps the recipe's natural odds.
        boosted = if forceBoost == true then true else nil,
    })
end)

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
    decorationLayout = DecorationLayout,
    decorationCatalog = DecorationCatalog,
    kamonDraw = KamonDraw,
    mortarPlacement = MortarPlacement,
})

-- THE PUBLIC BATTERY (owner, 2026-09-06): every part tagged FireworkTubeMount (the
-- Hanabiya rooftop platform ships three) gets a REAL hollowed L tube stood on it at
-- boot -- the deck mortars' own CSG clone -- and the launch handler fires public gear
-- shells from these muzzles instead of the old invisible overhead origin. Deferred:
-- the CSG templates themselves build deferred, so this retries until they exist.
task.spawn(function()
    local mounts = {}
    for _, m in CollectionService:GetTagged("FireworkTubeMount") do
        if m:IsA("BasePart") then
            table.insert(mounts, m)
        end
    end
    if #mounts == 0 then
        return
    end
    local tubeLen = MortarPlacement.TUBE["mortar:L"].length
    for _, mount in mounts do
        local tube: BasePart? = nil
        for _ = 1, 60 do
            tube = applier:cloneTube("mortar:L")
            if tube then
                break
            end
            task.wait(0.5)
        end
        if tube then
            -- the template cylinder's axis is local X; +90 deg roll stands it up,
            -- muzzle skyward, seated on the mount plate.
            tube.CFrame = CFrame.new(mount.Position + Vector3.new(0, mount.Size.Y / 2 + tubeLen / 2, 0))
                * CFrame.Angles(0, 0, math.rad(90))
            tube.Parent = mount
        end
    end
end)

-- Rebuild the player's claimed pad at its currently-resolved sizes/placement, threading the
-- current portal + decoration state, keeping playerHouse in sync. Used by the decoration
-- buy/place/remove paths, which change decoration state and then re-render the standing pad.
local function rebuildClaimedPad(uid: string)
    local e = playerEconomy[uid]
    if e == nil or e.claimedPadId == nil then
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
    if built == nil then
        return
    end
    local teaLoadout = if built.teahouseSize then e.teahouses[built.teahouseSize] else nil
    local teahouse = if built.teahouseSize
        then {
            size = built.teahouseSize,
            loadout = teaLoadout,
            placement = (teaLoadout and teaLoadout.placement) or CENTERED_PLACEMENT,
        }
        else nil
    local treatment = {
        kind = "structure",
        loadout = teaLoadout,
        lit = true,
        crest = Kamon.forUserId(uid),
        portalOwned = e.portalOwned,
        deckDecorations = e.deckDecorations,
        mortarPlacements = e.mortarPlacements,
        mortars = e.mortars,
    }
    applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)
    if built.teahouseSize ~= nil then
        playerHouse[uid] = { padId = e.claimedPadId, size = built.teahouseSize, loadout = teaLoadout }
    else
        playerHouse[uid] = nil
    end
end
rebuildClaimedPadFn = rebuildClaimedPad

-- (deckCF12, deckSize) for a claimed owner's currently-built deck, or nil,nil.
local function deckCFForUid(uid: string): ({ number }?, string?)
    local e = playerEconomy[uid]
    if e == nil or e.claimedPadId == nil then
        return nil, nil
    end
    local spec = PadSites[e.claimedPadId]
    if spec == nil then
        return nil, nil
    end
    local teaSizes = {}
    for s in e.teahouses do
        table.insert(teaSizes, s)
    end
    local built =
        SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
    if built == nil then
        return nil, nil
    end
    return DeckPlacement.resolve(spec.deckPlacements, built.deckSize, spec.maxSize), built.deckSize
end
deckCFForUidFn = deckCFForUid

-- friend cache keyed "viewerId:ownerId" (friendship is static within a session).
local friendCache: { [string]: boolean } = {}
local function isFriend(viewer: Player, ownerId: number): boolean
    local key = `{viewer.UserId}:{ownerId}`
    local cached = friendCache[key]
    if cached ~= nil then
        return cached
    end
    local ok, result = pcall(function()
        return viewer:IsFriendsWith(ownerId)
    end)
    local val = ok and result == true
    friendCache[key] = val
    return val
end

-- The gate specs a blocked viewer needs at one occupied pad: the full sealing perimeter (four walls
-- around the deck) + any authored tunnel-mouth gates (PadSites[padId].accessGates, empty until the
-- survey task). The client reveals/solidifies them only within AccessGates.revealRadius of the deck.
local function gatesForPad(padId: string, deckCF12: { number }, deckSize: string): { any }
    local gates = AccessGates.deckPerimeter(deckCF12, deckSize)
    local spec = PadSites[padId]
    local authored = spec and spec.accessGates
    if authored then
        for _, g in authored do
            table.insert(gates, { cframe = g.cframe, size = g.size })
        end
    end
    return gates
end

-- Public/private mode BEACON: a small Neon orb at each occupied deck's canyon-facing front edge,
-- coloured by the owner's mode (green public / amber friends / red private). Unlike the per-viewer
-- privacy walls this is a shared world signal (server-created, replicated to everyone), so players
-- can read a teahouse's openness from the valley floor. No per-orb light -- Neon emission alone reads
-- from distance (mobile-perf rule). Kept in sync with the occupied set each recompute.
local NAV_COLORS: { [string]: Color3 } = {
    public = Color3.fromRGB(60, 210, 90), -- green
    friends = Color3.fromRGB(255, 226, 170), -- warm chōchin cream (blue read too close to green at distance)
    private = Color3.fromRGB(220, 45, 45), -- red
}
local navFolder = Instance.new("Folder")
navFolder.Name = "AccessNavLights"
navFolder.Parent = workspace

local function syncNavLights(occupied: { any })
    local seen: { [string]: boolean } = {}
    for _, pad in occupied do
        seen[pad.padId] = true
        local color = NAV_COLORS[pad.mode] or NAV_COLORS.public
        local specs = AccessGates.navLights(pad.deckCF12, pad.deckSize)
        local padFolder = navFolder:FindFirstChild(pad.padId)
        if padFolder == nil then
            padFolder = Instance.new("Folder")
            padFolder.Name = pad.padId
            padFolder.Parent = navFolder
        end
        local parts: { BasePart } = {}
        for _, c in padFolder:GetChildren() do
            if c:IsA("BasePart") then
                table.insert(parts, c)
            end
        end
        for i, spec in specs do
            local lp = parts[i]
            if lp == nil then
                lp = Instance.new("Part")
                lp.Anchored, lp.CanCollide, lp.CanQuery, lp.CanTouch, lp.CastShadow =
                    true, false, false, false, false
                lp.Material = Enum.Material.Neon
                lp.Parent = padFolder
            end
            lp.Color = color
            lp.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
            lp.CFrame = CFrame.new(table.unpack(spec.cframe))
        end
    end
    for _, child in navFolder:GetChildren() do
        if not seen[child.Name] then
            child:Destroy()
        end
    end
end

-- For each present player, push the set of occupied pads they are BLOCKED from (with gate specs).
-- Invite lists never leave the server. Cheap: O(viewers x occupiedPads).
local function recomputeAllAccess()
    -- snapshot occupied pads (owner present + claimed), with each owner's access + built deck.
    local occupied: {
        {
            padId: string,
            ownerId: number,
            mode: string,
            invited: { number },
            deckCF12: { number },
            deckSize: string,
        }
    } =
        {}
    for _, owner in Players:GetPlayers() do
        local ouid = tostring(owner.UserId)
        local e = playerEconomy[ouid]
        if e ~= nil and e.claimedPadId ~= nil and e.teahouseAccess ~= nil then
            local deckCF12, deckSize = deckCFForUid(ouid)
            if deckCF12 ~= nil and deckSize ~= nil then
                table.insert(occupied, {
                    padId = e.claimedPadId,
                    ownerId = owner.UserId,
                    mode = e.teahouseAccess.mode,
                    invited = e.teahouseAccess.invited,
                    deckCF12 = deckCF12,
                    deckSize = deckSize,
                })
            end
        end
    end
    syncNavLights(occupied)
    for _, viewer in Players:GetPlayers() do
        local blocked = {}
        for _, pad in occupied do
            local friend = if pad.mode == "friends" then isFriend(viewer, pad.ownerId) else false
            if not AccessPolicy.canEnter(pad.mode, pad.invited, viewer.UserId, pad.ownerId, friend) then
                table.insert(blocked, {
                    padId = pad.padId,
                    gates = gatesForPad(pad.padId, pad.deckCF12, pad.deckSize),
                    center = { pad.deckCF12[1], pad.deckCF12[2], pad.deckCF12[3] },
                    revealRadius = AccessGates.revealRadius(pad.deckSize),
                })
            end
        end
        AccessBlocked:FireClient(viewer, { blocked = blocked })
    end
end

-- userId -> username cache (names are stable); resolution yields, so cache aggressively.
local nameCache: { [number]: string } = {}
local function resolveName(userId: number): string
    local cached = nameCache[userId]
    if cached ~= nil then
        return cached
    end
    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    local resolved = if ok and type(name) == "string" then filterExternalName(name) else tostring(userId)
    nameCache[userId] = resolved
    return resolved
end

-- Echo the owner's own access state (mode + named invitees) to their panel. `notice` is an optional
-- transient message (bad name / already invited / list full) surfaced by the panel.
local function pushAccessState(player: Player, uid: string, notice: string?)
    local e = playerEconomy[uid]
    if e == nil or e.teahouseAccess == nil then
        return
    end
    local invited = {}
    for _, id in e.teahouseAccess.invited do
        table.insert(invited, { userId = id, name = resolveName(id) })
    end
    if not player:IsDescendantOf(Players) then
        return
    end
    AccessState:FireClient(player, { mode = e.teahouseAccess.mode, invited = invited, notice = notice })
end

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

-- Defect (n): once-per-join guard, so the catch-up sweep below and the real PlayerAdded event
-- can never run the economy flow twice for one player (double GET, double claim). Cleared in
-- PlayerRemoving with the rest of the per-uid state.
local economyJoinStarted: { [string]: boolean } = {}
local function onPlayerJoinEconomy(player: Player)
    task.spawn(function()
        do
            local uid = tostring(player.UserId)
            if economyJoinStarted[uid] then
                return
            end
            economyJoinStarted[uid] = true
        end
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
            deckDecorations = (ecoData and ecoData.deckDecorations) or {},
            teahouseAccess = (ecoData and ecoData.teahouseAccess) or { mode = "public", invited = {} },
            -- neither rides the economy GET (ecoData above) -- both arrive moments later off
            -- the fireworks GET, in pushFireworkState below.
            mortars = {},
            mortarPlacements = nil,
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
            action.treatment.deckDecorations = playerEconomy[uid].deckDecorations
            action.treatment.mortarPlacements = playerEconomy[uid].mortarPlacements
            action.treatment.mortars = playerEconomy[uid].mortars
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
        if pushFireworkState then
            pushFireworkState(player)
        end
        pushAccessState(player, uid)
        recomputeAllAccess()
    end)
end

Players.PlayerAdded:Connect(onPlayerJoinEconomy)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayerJoinEconomy, p) -- defect (n): the window the mortar CSG hit (d510c69)
end

-- Client-pull sync. The join handler pushes EconomyState/PreferenceState/etc. ONCE, but on a live
-- server those one-shot pushes can fire before a client's listeners are connected (RemoteEvents do
-- not queue for late listeners) -> the teahouse panel sits on "Loading...". Each client fires
-- RequestSync on startup and retries until its EconomyState lands; we re-echo that player's full
-- state (all guarded/idempotent). Light per-uid debounce so retries can't spin the server.
local lastSync: { [string]: number } = {}
RequestSync.OnServerEvent:Connect(function(player)
    local uid = tostring(player.UserId)
    local now = os.clock()
    if lastSync[uid] ~= nil and now - lastSync[uid] < 0.4 then
        return
    end
    lastSync[uid] = now
    echoEconomy(player, uid)
    if playerPrefs[uid] ~= nil then
        PreferenceState:FireClient(
            player,
            { padPreferences = playerPrefs[uid], names = namesFor(playerPrefs[uid]) }
        )
    end
    echoBackDoor(player, uid)
    pushAccessState(player, uid)
    -- FireworkState too (live-place find, 2026-09-05: the shop showed zero holdings while the
    -- picker was accurate). The join's one-shot FireworkState push races every listener
    -- independently -- ShopController connects later in script order than main.client and
    -- missed it, and this re-echo previously sent everything EXCEPT fireworks, so nothing ever
    -- re-delivered the counts to an idle player. The pull now returns the COMPLETE join state.
    if pushFireworkState then
        pushFireworkState(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local uid = tostring(player.UserId)
    -- stop a leaving player's shoji hold immediately rather than waiting for the loop's own
    -- next-tick IsDescendantOf(Players) check to catch up.
    local activeSlide = shojiSlides[uid]
    if activeSlide ~= nil then
        activeSlide.alive = false
        -- ...and fold that in-flight hold into the pending persists RIGHT HERE, before flushing
        -- (2026-08-18 final review). Killing the loop is not the same as saving where it got to:
        -- the loop only reaches its own scheduleShojiPersist on its NEXT tick, which is after this
        -- function has returned and nulled playerHouse[uid], so the target it schedules then finds
        -- no house and is silently discarded. Disconnecting mid-hold therefore always lost the
        -- write -- live geometry right, database stale. The bay's `ShojiOpen` attribute already
        -- holds the final travel (the loop stopped writing the instant `alive` went false, and
        -- flushShojiForUid reads it synchronously below), so this target is complete as it stands.
        -- The loop's own later scheduleShojiPersist for the same screen is then a no-op: the flush
        -- has already cleared this key's generation, and by then there is no house to write to.
        local key = shojiSlideKey(uid, activeSlide.padId, activeSlide.side, activeSlide.index)
        shojiPersistGen[key] = (shojiPersistGen[key] or 0) + 1
        shojiPendingPersist[key] = {
            uid = uid,
            padId = activeSlide.padId,
            side = activeSlide.side,
            index = activeSlide.index,
            count = activeSlide.count,
            bay = activeSlide.bay,
        }
    end
    playerPrefs[uid] = nil
    -- drop this uid's not-yet-run mutations FIRST -- flushShojiForUid below queues at most one
    -- fresh write, and defers even that, so it is never at risk of being wiped by this call.
    handlerQueue:clear(uid)
    -- flush every pending debounced shoji persist for this uid into ONE write NOW (2026-08-18
    -- review round 2 fix), before playerHouse[uid] is cleared below. flushShojiForUid reads the
    -- house and builds the merged loadout synchronously, before queueing anything, so the order
    -- of the two nils below no longer matters to it.
    flushShojiForUid(uid)
    playerHouse[uid] = nil
    playerEconomy[uid] = nil
    -- Final-review fix round: a stale entry here survives a rejoin to the SAME server instance.
    -- The join bootstraps e.mortars/e.mortarPlacements empty (pushFireworkState fills them
    -- moments later); if the fresh pushFireworkState's fingerprint happens to match what this
    -- uid's PREVIOUS session last rendered, the rebuild is skipped and the deck stays tubeless
    -- for the whole session while muzzleOriginFor keeps firing shells from the (now invisible)
    -- resolved muzzle. Clearing it here forces the next pushFireworkState to always rebuild once.
    mortarRenderedFingerprint[uid] = nil
    economyJoinStarted[uid] = nil -- defect (n): let a rejoin run the economy flow afresh
    recomputeAllAccess()
    local action = siteCoordinator:onLeave(uid)
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
        -- live, server-authoritative re-render (replicates to every client). Same structure
        -- instance as last render, so applyShoji's attribute-diff keeps every open screen where
        -- the player left it rather than snapping every screen shut.
        StructureOps.applyBays(structure, WallBays.resolve(manifest.bays, newWallBays))
        StructureOps.applyShoji(structure, newLoadout.shojiOpen)
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

-- ============================ SHOJI: HOLD TO SLIDE (task 5) ============================
-- Server-authoritative sliding screens. A held SlideShoji advances one bay's `ShojiOpen`
-- attribute at SLIDE_RATE bay-widths/second in a direction latched ONCE at hold-start
-- (ShojiRun.directionFrom recomputed every step would reverse the screen under the player's
-- finger the moment it crossed the half-open mark -- see that function's own docs). The attribute
-- is the ONLY thing this handler writes: rendering the slide from it belongs to the client
-- controller that is the next task in this plan, not to this one.
local SLIDE_RATE = 1 / 1.2 -- bay-widths per second
-- BackDoorController's ProximityPrompt.MaxActivationDistance (12) + 4: generous, because there is
-- no server-side "who is inside whose house" registry -- this distance check to the bay's
-- un-moving Solid panel is what stands in for one.
local SHOJI_REACH = 12 + 4
local SHOJI_PERSIST_QUIET = 2 -- seconds of quiet after a hold ends before persisting

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
    table.sort(list, function(a, b)
        return a.bayIndex < b.bayIndex
    end)
    return list
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
    return root ~= nil and (root.Position - pos).Magnitude <= SHOJI_REACH
end

-- Schedule (debounce), keyed per SLIDE TARGET -- not per uid (2026-08-18 review fix; see the
-- shojiPersistGen/shojiPendingPersist declarations above). Two releases of the SAME screen inside
-- the quiet window still collapse to one write, which is the debounce doing its job; two DIFFERENT
-- screens no longer cancel each other.
local function scheduleShojiPersist(
    uid: string,
    padId: string,
    side: string,
    index: number,
    count: number,
    bay: Model
)
    local key = shojiSlideKey(uid, padId, side, index)
    local gen = (shojiPersistGen[key] or 0) + 1
    shojiPersistGen[key] = gen
    shojiPendingPersist[key] =
        { uid = uid, padId = padId, side = side, index = index, count = count, bay = bay }
    task.delay(SHOJI_PERSIST_QUIET, function()
        if shojiPersistGen[key] ~= gen then
            return -- superseded by a newer hold-end on THIS SAME screen within the quiet window
        end
        shojiPersistGen[key] = nil
        local target = shojiPendingPersist[key]
        shojiPendingPersist[key] = nil
        if target ~= nil then
            persistShojiNow(target)
        end
    end)
end

-- The hold loop: NOT run through handlerQueue (parking a multi-second loop in a player's lane
-- would block every other mutating handler of theirs for the duration of the hold). It never
-- touches anything handlerQueue exists to protect either -- no HTTP, only a replicated attribute
-- -- until it ends, at which point StructureOps.syncShojiBay (a live Instance write, but no HTTP)
-- and scheduleShojiPersist (the one thing that yields) run, and the latter goes through the queue
-- itself, same as every other persist in this file.
local function runShojiSlide(player: Player, uid: string, slide: ShojiSlide, direction: number)
    local last = os.clock()
    while slide.alive do
        task.wait()
        if not slide.alive then
            break
        end
        if not player:IsDescendantOf(Players) then
            break -- player left
        end
        if not slide.bay:IsDescendantOf(workspace) then
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
        local nextOpen = ShojiRun.clamp(slide.index, slide.count, openNow + direction * SLIDE_RATE * dt)
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
    if shojiSlides[uid] == slide then
        shojiSlides[uid] = nil
    end
    -- reconcile the server's OWN geometry to the final target ONCE, here, at hold end -- not per
    -- step. These are anchored scenery parts: server-side collision and every server raycast see
    -- ONLY what this call moves, nothing the loop wrote to the attribute above. Guarded the same
    -- way the loop itself was: a structure that died mid-hold (rebuild/leave race) leaves nothing
    -- live to move.
    if slide.bay:IsDescendantOf(workspace) then
        StructureOps.syncShojiBay(slide.structure, slide.side, slide.bay)
    end
    scheduleShojiPersist(uid, slide.padId, slide.side, slide.index, slide.count, slide.bay)
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
SlideShoji.OnServerEvent:Connect(function(player, payload)
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
        local slide = shojiSlides[uid]
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
    local existing = shojiSlides[uid]
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
    local siteFolder = sitesFolder:FindFirstChild("MaterializedSite_" .. padId)
    local structure = siteFolder and siteFolder:FindFirstChild("Structure")
    if structure == nil then
        return
    end
    local run = collectShojiRun(structure, side)
    local count = #run
    -- raw bay number -> ordinal within THIS wall's run, decided here because the server is the
    -- side that can always see every bay (ShojiRun.ordinalOf's own note has the failure)
    local bayNumbers = table.create(count)
    for i, e in run do
        bayNumbers[i] = e.bayIndex
    end
    local index = ShojiRun.ordinalOf(bayNumbers, bayNumber)
    if index == nil then
        return -- not a shoji bay of this side: ill-typed / stale client, no message
    end
    local entry = run[index]

    -- The bay's RESOLVED state, never merely the presence of its `Shoji` variant, which every bay
    -- of a stock prefab has (2026-08-18 final review, critical -- see ShojiRun.isSlidable). The
    -- server does not trust that a prompt fired, or that the client was willing to ask: a solid
    -- bay is not slidable no matter what arrives on the wire, and sliding one would move an
    -- invisible non-colliding leaf behind the panel the player is looking at, then persist it.
    if not ShojiRun.isSlidable(entry.bay:GetAttribute("BayState")) then
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
        if player:IsDescendantOf(Players) then
            ShojiState:FireClient(
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
    local direction = ShojiRun.directionFrom(index, count, openNow)
    local slide: ShojiSlide = {
        alive = true,
        padId = padId,
        side = side,
        bayNumber = bayNumber,
        index = index,
        bay = entry.bay,
        structure = structure,
        count = count,
    }
    shojiSlides[uid] = slide

    if player:IsDescendantOf(Players) then
        ShojiState:FireClient(
            player,
            { padId = padId, side = side, bay = bayNumber, open = openNow, accepted = true }
        )
    end

    task.spawn(runShojiSlide, player, uid, slide, direction)
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
        if string.sub(item, 1, 11) == "decoration:" then
            -- the PWA is the id authority: adopt the returned list + the new instance's id, rebuild
            -- the claimed pad so the prop renders, then tell the client to enter placement for it.
            -- (Decorations never change deck tier or portal ownership, so we DON'T touch
            -- e.maxDeckSize/e.portalOwned here — the decoration /purchase response omits them.)
            e.deckDecorations = res.data.deckDecorations or e.deckDecorations
            if e.claimedPadId ~= nil then
                rebuildClaimedPad(uid)
                echoBackDoor(player, uid)
            end
            if player:IsDescendantOf(Players) and res.data.decoration ~= nil then
                DecorationPlaced:FireClient(
                    player,
                    { id = res.data.decoration.id, propId = res.data.decoration.propId }
                )
            end
            echoEconomy(player, uid)
            return
        end
        if string.sub(item, 1, 9) == "firework:" or string.sub(item, 1, 7) == "mortar:" then
            -- Same hazard as the decoration branch above: the firework/mortar /purchase response
            -- carries only { item, totalPoints, shellId/mortarTier, count } — no maxDeckSize, no
            -- portalOwned, no teahouseSizes. Falling through would blank this session's deck tier
            -- and portal ownership (buy-to-claim prompts reappear on owned perches, the home portal
            -- stops opening, and recomputeAllAccess() drops the pad from `occupied` so a
            -- friends-only deck opens to EVERYONE). Buying a shell or a mortar changes neither the
            -- structure nor access, so return before touching any of it; the count that DID change
            -- lives in FireworkState, which pushFireworkState carries.
            if pushFireworkState then
                pushFireworkState(player)
            end
            echoEconomy(player, uid)
            return
        end
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
                    action.treatment.deckDecorations = e.deckDecorations
                    action.treatment.mortarPlacements = e.mortarPlacements
                    action.treatment.mortars = e.mortars
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
                    local treatment = {
                        kind = "structure",
                        loadout = teaLoadout,
                        lit = true,
                        crest = Kamon.forUserId(uid),
                        portalOwned = e.portalOwned,
                        deckDecorations = e.deckDecorations,
                        mortarPlacements = e.mortarPlacements,
                        mortars = e.mortars,
                    }
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
        -- re-push access gates: a mid-session claim or size upgrade changes occupancy/deck geometry
        recomputeAllAccess()
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
                local treatment = {
                    kind = "structure",
                    loadout = teaLoadout,
                    lit = true,
                    crest = Kamon.forUserId(uid),
                    portalOwned = e.portalOwned,
                    deckDecorations = e.deckDecorations,
                    mortarPlacements = e.mortarPlacements,
                    mortars = e.mortars,
                }
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
        -- re-push access gates: display resize changes deck footprint -> gate geometry
        recomputeAllAccess()
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
        local treatment = {
            kind = "structure",
            loadout = fresh,
            lit = true,
            crest = Kamon.forUserId(uid),
            portalOwned = e.portalOwned,
            deckDecorations = e.deckDecorations,
            mortarPlacements = e.mortarPlacements,
            mortars = e.mortars,
        }
        applier:apply(e.claimedPadId, spec, treatment, builtNow.deckSize, teahouse)
        playerHouse[uid] = { padId = e.claimedPadId, size = size, loadout = fresh }
        echoBackDoor(player, uid) -- geometry watch re-arms the F prompts on the new structure
    end)
end)

SetDecorationPlacement.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return -- occupant-only, same discipline as SetPlacement
        end
        if
            typeof(payload) ~= "table"
            or typeof(payload.id) ~= "number"
            or typeof(payload.offset) ~= "table"
        then
            return
        end
        local id = payload.id
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
        -- find the instance by id (stale client view -> no-op)
        local idx: number? = nil
        for i, d in e.deckDecorations do
            if d.id == id then
                idx = i
                break
            end
        end
        if idx == nil then
            return
        end
        local propId = e.deckDecorations[idx].propId
        local fp = DecorationCatalog.footprint(propId)
        if fp == nil then
            return
        end
        -- server-authoritative clamp against the CURRENT deck footprint (full deck; decorations may
        -- sit to the very edge). Persist the clamped value, never raw client numbers.
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
        if built == nil then
            return
        end
        local deckFP = SizeClasses.deckFootprint(built.deckSize)
        local clamped = BuildingPlacer.clamp(fp, deckFP, { offset = { dx, dz }, facing = facing })
        -- build a NEW list (pre-persist clone discipline) with this instance updated
        local newList = table.clone(e.deckDecorations)
        newList[idx] = { id = id, propId = propId, offset = clamped.offset, facing = clamped.facing }
        local persisted = net:setDecorations(uid, newList)
        if not persisted.ok then
            warn(`[DECOR] setDecorations(place) failed for {uid}: {tostring(persisted.error)}`)
            echoEconomy(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.deckDecorations = newList
        rebuildClaimedPad(uid)
        echoBackDoor(player, uid) -- rebuild replaced the Structure; re-arm the F prompts (parity)
        echoEconomy(player, uid)
    end)
end)

-- Mirrors SetDecorationPlacement's shape exactly, keyed on mortarId instead of a decoration
-- instance id (a mortar has no separate instance -- owning a tier IS the instance). Mortars ARE
-- server-built props now (TreatmentApplier:_buildMortars, alongside _buildDecorations -- Task 5's
-- controller ruling superseded the original client-side-render plan so every visitor sees them,
-- not just the owner), so a moved mortar needs the SAME rebuildClaimedPad/echoBackDoor step
-- SetDecorationPlacement uses to redraw for everyone, not just echoEconomy back to the mover.
SetMortarPlacement.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return -- occupant-only, same discipline as SetDecorationPlacement
        end
        if
            typeof(payload) ~= "table"
            or typeof(payload.mortarId) ~= "string"
            or typeof(payload.offset) ~= "table"
        then
            return
        end
        local mortarId = payload.mortarId
        local dx, dz = payload.offset[1], payload.offset[2]
        local mount = payload.mount
        local aim = payload.aim
        local isKnownMortar = false
        for _, id in MortarPlacement.MORTAR_ORDER do
            isKnownMortar = isKnownMortar or id == mortarId
        end
        if not isKnownMortar then
            return
        end
        local owned = false
        for _, id in e.mortars do
            owned = owned or id == mortarId
        end
        if not owned then
            return -- gear is personal: standing on your own deck doesn't lend a tier you don't own
        end
        if typeof(dx) ~= "number" or dx ~= dx or math.abs(dx) == math.huge then
            return
        end
        if typeof(dz) ~= "number" or dz ~= dz or math.abs(dz) == math.huge then
            return
        end
        if mount ~= "floor" and mount ~= "rail" then
            return
        end
        local isKnownAim = false
        for _, a in MortarPlacement.AIMS do
            isKnownAim = isKnownAim or a == aim
        end
        if not isKnownAim then
            return
        end
        -- build a NEW map (pre-persist clone discipline); resolve()'s own clamp handles
        -- out-of-bounds values at read time, so nothing is clamped here (Task 2's module owns
        -- that decision, not this runtime file).
        local newMap = table.clone(e.mortarPlacements or {})
        newMap[mortarId] = { offset = { dx, dz }, mount = mount, aim = aim }
        local persisted = net:putMortarPlacements(uid, newMap)
        if not persisted.ok then
            warn(`[MORTAR] putMortarPlacements failed for {uid}: {tostring(persisted.error)}`)
            echoEconomy(player, uid) -- resync
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.mortarPlacements = newMap
        mortarRenderedFingerprint[uid] = mortarFingerprint(e.mortars, e.mortarPlacements) -- rendering NOW; pushFireworkState's next poll must not redundantly re-rebuild
        rebuildClaimedPad(uid)
        echoBackDoor(player, uid) -- rebuild replaced the Structure; re-arm the F prompts (parity)
        echoEconomy(player, uid)
    end)
end)

SetDecorationRemove.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return
        end
        local id = if typeof(payload) == "table" then payload.id else payload
        if typeof(id) ~= "number" then
            return
        end
        local newList = {}
        local found = false
        for _, d in e.deckDecorations do
            if d.id == id then
                found = true
            else
                table.insert(newList, d)
            end
        end
        if not found then
            return -- stale id: no-op
        end
        local persisted = net:setDecorations(uid, newList)
        if not persisted.ok then
            warn(`[DECOR] setDecorations(remove) failed for {uid}: {tostring(persisted.error)}`)
            echoEconomy(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.deckDecorations = newList
        rebuildClaimedPad(uid)
        echoBackDoor(player, uid) -- rebuild replaced the Structure; re-arm the F prompts (parity)
        echoEconomy(player, uid)
    end)
end)

SetAccess.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
            return -- owner-only, occupying a claimed pad
        end
        local mode = if typeof(payload) == "table" then payload.mode else nil
        if typeof(mode) ~= "string" or not ACCESS_MODES[mode] then
            return
        end
        if mode == e.teahouseAccess.mode then
            return -- no-op
        end
        local newAccess = { mode = mode, invited = table.clone(e.teahouseAccess.invited) }
        local persisted = net:setAccess(uid, newAccess)
        if not persisted.ok then
            warn(`[AC] setAccess(mode) failed for {uid}: {tostring(persisted.error)}`)
            pushAccessState(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.teahouseAccess = newAccess
        recomputeAllAccess()
        pushAccessState(player, uid)
    end)
end)

InviteUser.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
            return
        end
        local username = if typeof(payload) == "table" then payload.username else nil
        if typeof(username) ~= "string" or #username == 0 or #username > 20 then
            return
        end
        if #e.teahouseAccess.invited >= MAX_INVITED then
            pushAccessState(player, uid, "Invite list is full")
            return
        end
        local ok, resolved = pcall(function()
            return Players:GetUserIdFromNameAsync(username)
        end)
        if not ok or typeof(resolved) ~= "number" then
            pushAccessState(player, uid, `No player named "{username}"`)
            return
        end
        if resolved == player.UserId then
            pushAccessState(player, uid, "You always have access to your own teahouse")
            return
        end
        for _, id in e.teahouseAccess.invited do
            if id == resolved then
                pushAccessState(player, uid, "Already invited")
                return
            end
        end
        local newInvited = table.clone(e.teahouseAccess.invited)
        table.insert(newInvited, resolved)
        local newAccess = { mode = e.teahouseAccess.mode, invited = newInvited }
        local persisted = net:setAccess(uid, newAccess)
        if not persisted.ok then
            warn(`[AC] setAccess(invite) failed for {uid}: {tostring(persisted.error)}`)
            pushAccessState(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.teahouseAccess = newAccess
        recomputeAllAccess()
        pushAccessState(player, uid, `Invited {resolveName(resolved)}`)
    end)
end)

RevokeUser.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
            return
        end
        local userId = if typeof(payload) == "table" then payload.userId else nil
        if typeof(userId) ~= "number" then
            return
        end
        local newInvited = {}
        local found = false
        for _, id in e.teahouseAccess.invited do
            if id == userId then
                found = true
            else
                table.insert(newInvited, id)
            end
        end
        if not found then
            return -- stale id: no-op
        end
        local newAccess = { mode = e.teahouseAccess.mode, invited = newInvited }
        local persisted = net:setAccess(uid, newAccess)
        if not persisted.ok then
            warn(`[AC] setAccess(revoke) failed for {uid}: {tostring(persisted.error)}`)
            pushAccessState(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.teahouseAccess = newAccess
        recomputeAllAccess()
        pushAccessState(player, uid)
    end)
end)

-- Gate the deck portal by teahouse access: a blocked viewer can reach a deck's PortalControl prompt
-- through the perimeter wall (prompts are distance-based), but must not be able to use it. Find the
-- pad's present owner (by claimedPadId) and apply canEnter; ungated when no present owner claims it.
local function canOpenPortal(player: Player, control: Instance): boolean
    local padId = control:GetAttribute("padId")
    if typeof(padId) ~= "string" then
        return true
    end
    for _, owner in Players:GetPlayers() do
        local e = playerEconomy[tostring(owner.UserId)]
        if e ~= nil and e.claimedPadId == padId and e.teahouseAccess ~= nil then
            local friend = if e.teahouseAccess.mode == "friends"
                then isFriend(player, owner.UserId)
                else false
            return AccessPolicy.canEnter(
                e.teahouseAccess.mode,
                e.teahouseAccess.invited,
                player.UserId,
                owner.UserId,
                friend
            )
        end
    end
    return true
end

local portalController = PortalController.new({
    players = Players,
    canOpen = canOpenPortal,
    portalTarget = PortalTarget,
    getEconomy = function(uid)
        local e = playerEconomy[uid]
        if e == nil then
            return nil
        end
        return { portalOwned = e.portalOwned == true, claimedPadId = e.claimedPadId }
    end,
    deckCFForClaim = function(uid)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return nil
        end
        local spec = PadSites[e.claimedPadId]
        if spec == nil then
            return nil
        end
        local teaSizes = {}
        for s in e.teahouses do
            table.insert(teaSizes, s)
        end
        local built =
            SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
        if built == nil then
            return nil
        end
        return DeckPlacement.resolve(spec.deckPlacements, built.deckSize, spec.maxSize), built.deckSize
    end,
})
portalController:start()

print(`[ROSHAMBO] playable loop starting against {config.baseUrl}`)
task.spawn(function()
    -- ⚠ pcall'd, ALWAYS (the (g)-adjacent hazard, fixed 2026-09-05): this loop IS the game --
    -- one throw here (a backend hiccup mid-decode, a server/place duration-shape mismatch on
    -- the FIRST poll) used to kill the round loop for the whole server until restart. A failed
    -- poll now logs and retries on a short backoff instead; the round loop never dies.
    local POLL_ERROR_BACKOFF = 3
    while true do
        local ok, result = pcall(function()
            return coordinator:pollOnce()
        end)
        if ok then
            task.wait(result)
        else
            warn(`[ROUND] pollOnce threw ({tostring(result)}); retrying in {POLL_ERROR_BACKOFF}s`)
            task.wait(POLL_ERROR_BACKOFF)
        end
    end
end)

-- Access backstop: the authoritative half of enforcement. Every ACCESS_TICK seconds, for each
-- occupied deck, teleport back any player standing on it who is not allowed in (canEnter=false).
-- Catches side jump-ins, exploiters who nulled a local gate, and eviction when a mode flips /
-- an invite is revoked. Owner + allowed guests are never moved. Uses deck-LOCAL bounds so it
-- follows the deck's rotation.
local ACCESS_TICK = 0.3
task.spawn(function()
    while true do
        task.wait(ACCESS_TICK)
        -- snapshot occupied decks once per tick
        for _, owner in Players:GetPlayers() do
            local ouid = tostring(owner.UserId)
            local e = playerEconomy[ouid]
            if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
                continue
            end
            local deckCF12, deckSize = deckCFForUid(ouid)
            if deckCF12 == nil or deckSize == nil then
                continue
            end
            local fp = SizeClasses.deckFootprint(deckSize)
            local deckCF = CFrame.new(table.unpack(deckCF12))
            local evictCF = CFrame.new(table.unpack(AccessGates.evictionPoint(deckCF12, deckSize)))
            for _, viewer in Players:GetPlayers() do
                if viewer == owner then
                    continue -- owner is always allowed; never evict
                end
                local char = viewer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root == nil then
                    continue
                end
                -- is the viewer standing within this deck's footprint (deck-local), within a height band?
                local rel = deckCF:PointToObjectSpace(root.Position)
                if rel.X < fp.minX or rel.X > fp.maxX or rel.Z < fp.minZ or rel.Z > fp.maxZ then
                    continue
                end
                if rel.Y < -2 or rel.Y > AccessGates.GATE_H then
                    continue -- far below/above the deck plane: not on this deck
                end
                local friend = if e.teahouseAccess.mode == "friends"
                    then isFriend(viewer, owner.UserId)
                    else false
                if
                    not AccessPolicy.canEnter(
                        e.teahouseAccess.mode,
                        e.teahouseAccess.invited,
                        viewer.UserId,
                        owner.UserId,
                        friend
                    )
                then
                    char:PivotTo(evictCF)
                end
            end
        end
    end
end)
