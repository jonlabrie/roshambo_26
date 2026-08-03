--!strict
-- Play-loop WIRING. Since the play-HUD redesign this file builds NO UI at all: every
-- `Instance.new` moved to HudController (the minimal HUD). What stays is the seam between the
-- remotes and the renderers, because it is the part that is subtle rather than decorative:
--   • the authoritative World-Throw tape and the per-round personal WIN/SAFE/LOSS badges,
--   • the DRUM-REST SPOILER GATE (see `visibleTape` / `maybeShowReveal`),
--   • the HudModel session — the escalation's consecutive-miss backoff,
--   • the optimistic local pick.
--
-- It publishes all of that on `EventBus.HudState:Fire(inputs, aux)`:
--   inputs : a HudModel.Inputs — the controller calls HudModel.view(inputs, aux.session)
--   aux    : { session = HudModel.Session, tape = { { worldThrow, result? } }, pick = string? }
-- and takes picks back on `EventBus.HudPick`. Transient notices go out on `EventBus.Toast`.
--
-- BankRequest is deliberately not bound here any more: the persistent BANK button is gone, and
-- banking is one half of the RISK/BANK pair that resolves a win through the ResolveWin remote.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HudModel = require(shared:WaitForChild("HudModel"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local FateResolvedEvt = remotes:WaitForChild("FateResolved") :: RemoteEvent
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent

local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer

local TAPE_N = 5 -- how many tape entries the HUD can show
local TICK = 0.1 -- HudState cadence; the round timer is a depleting hairline, so keep it smooth
local REVEAL_SAFETY = 3 -- seconds before a dropped drumRest cue is assumed lost

-- The tape renders DIRECTLY from the authoritative World-Throw tape (newest-first, deduped, each
-- entry carrying a round id), carried by both RoundUpdate (every phase) and BoardData (on join +
-- every 30s). Rendering from the tape — rather than accumulating client-side — means it seeds the
-- instant either arrives and can never duplicate. Personal badges are keyed by round id and set
-- when the local drum finishes revealing that round.
local tape: { { id: string, worldThrow: string } } = {}
local badgeById: { [string]: string } = {}
local currentRoundId: string? = nil -- the round in play (from RoundUpdate)
local revealedRoundId: string? = nil -- the latest round our drum has finished

local phase = ""
local lockoutAt: number? = nil
local fateBound = false
local myPick: string? = nil
local roundCouldThrow = false

local wallet = { totalPoints = 0, pointsAtStake = 0, currentStreak = 0, unresolvedWin = false }

-- Not on the wire yet: ProfileUpdate does not carry the profile's escalationPrompts. Default ON,
-- which is the profile's own default, until the ledger's preference switch feeds it.
local escalationPrompts = true

local session = HudModel.newSession()

-- couldThrow mirrors the server's own refusal conditions: a round the player was refused is not
-- a round they ignored.
local function roundEnded(couldThrow: boolean, picked: boolean)
    session = HudModel.onRoundEnded(session, { couldThrow = couldThrow, picked = picked })
end

-- The clock may not have synced when ACTIVE opens (secondsToLockout arrives nil). The old HUD let
-- the player throw anyway and so do we: report a nominal countdown comfortably above the
-- escalation threshold, so throws stay enabled and the alarm stays quiet.
local UNSYNCED_SECONDS = 30

local function secondsLeft(): number
    if phase ~= "ACTIVE" then
        return 0
    end
    if not lockoutAt then
        return UNSYNCED_SECONDS
    end
    return math.max(0, lockoutAt - os.clock())
end

-- SPOILER GATE. If the newest tape entry is the round still being revealed — our drum has not
-- settled on it yet — hold it back until the wheel stops. Painting it early gives away the
-- world's throw while the drum is still turning.
local function visibleTape(): { { worldThrow: string, result: string? } }
    local skip = 0
    if currentRoundId and tape[1] and tape[1].id == currentRoundId and currentRoundId ~= revealedRoundId then
        skip = 1
    end
    local out: { { worldThrow: string, result: string? } } = {}
    for i = 1, TAPE_N do
        local entry = tape[i + skip]
        if not entry then
            break
        end
        table.insert(out, { worldThrow = entry.worldThrow, result = badgeById[entry.id] })
    end
    return out
end

local function publish()
    EventBus.HudState:Fire({
        phase = phase,
        secondsLeft = secondsLeft(),
        pointsAtStake = wallet.pointsAtStake,
        currentStreak = wallet.currentStreak,
        totalPoints = wallet.totalPoints,
        unresolvedWin = wallet.unresolvedWin,
        fateBound = fateBound,
        pickedThisRound = myPick ~= nil,
        escalationPrompts = escalationPrompts,
    }, {
        session = session,
        tape = visibleTape(),
        pick = myPick,
    })
end

local function toast(line: string)
    EventBus.Toast:Fire(line)
end

local function setTape(t: any)
    if t and #t > 0 then
        tape = t
        publish()
    end
end

-- BoardData (pushed on join + every 30s) seeds the tape immediately from the instance-cached
-- copy — no per-player cost to the external server.
BoardData.OnClientEvent:Connect(function(d)
    setTape(d and d.tape)
end)

-- The reveal headline AND the new tape tile wait for the drum to stop turning (the drumRest cue),
-- so the throw is not spoiled mid-spin. The vote distribution is folded into that same headline
-- rather than announced on its own: it names the world throw too, and the old prose ticker
-- released it the instant the reveal landed, which spoiled the wheel while it was still turning.
local pendingReveal: { headline: string, roundId: string?, result: string? }? = nil
local drumAtRest = false

local function maybeShowReveal()
    if pendingReveal and drumAtRest then
        local p = pendingReveal
        pendingReveal = nil
        toast(p.headline)
        -- Badge this round by id and un-gate it in the tape now the drum's at rest.
        if p.roundId then
            if p.result then
                badgeById[p.roundId] = p.result
            end
            revealedRoundId = p.roundId
        end
        publish()
    end
end

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        drumAtRest = true
        maybeShowReveal()
    end
end)

EventBus.HudPick.Event:Connect(function(value: string)
    -- Optimistic: the tile lights the moment it is tapped. The server is what actually refuses a
    -- pick (fate-bound, win-bound, past the lockout).
    myPick = value
    SubmitPick:FireServer(value)
    publish()
end)

RevealTheater.OnClientEvent:Connect(function(r)
    local myId = tostring(player.UserId)
    local mine = r.results and r.results[myId]
    if mine and mine.result == "LOSS" then
        fateBound = true
    end
    if r.whiffed and r.whiffed[myId] then
        toast("⏳ TOO LATE — your throw didn't count this round")
    end
    publish()
end)

FateResolvedEvt.OnClientEvent:Connect(function(userId)
    if userId == tostring(player.UserId) then
        fateBound = false
        publish()
    end
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    currentRoundId = info.roundId
    if info.tape and #info.tape > 0 then
        tape = info.tape -- authoritative World-Throw history, every phase change
    end
    if phase == "ACTIVE" and info.phase ~= "ACTIVE" then
        roundEnded(roundCouldThrow, myPick ~= nil)
    end
    phase = info.phase
    if info.phase == "ACTIVE" then
        myPick = nil
        roundCouldThrow = not (fateBound or wallet.unresolvedWin)
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
        pendingReveal = nil -- the drum respins; last round's reveal has already been shown
        drumAtRest = false
    else
        lockoutAt = nil
    end
    publish()
end)

RevealResult.OnClientEvent:Connect(function(r)
    local result: string
    if r.result == "WIN" then
        result = `🏆 WIN! World threw {r.worldThrow}`
    elseif r.result == "SAFE" then
        result = `🛡 SAFE — world matched your {r.pick}`
    elseif r.result == "LOSS" then
        result = `💥 LOSS — world threw {r.worldThrow}`
    else
        result = `World threw {r.worldThrow}`
    end
    -- One line, not two. The old status bar and the old prose ticker each carried half of this;
    -- a toast is transient, and two of them back to back would occupy a third of the round.
    local headline = `{result} — R {r.distribution.R}% · P {r.distribution.P}% · S {r.distribution.S}%`
    -- The revealing round == the one RoundUpdate last named (REVEAL phase).
    pendingReveal = { headline = headline, roundId = currentRoundId, result = r.result }
    maybeShowReveal() -- only shows if the drum is already at rest
    task.delay(REVEAL_SAFETY, function()
        if pendingReveal and pendingReveal.headline == headline then
            drumAtRest = true -- safety: never strand a result if the cue dropped
            maybeShowReveal()
        end
    end)
end)

ProfileUpdate.OnClientEvent:Connect(function(p)
    wallet.totalPoints = p.totalPoints
    wallet.pointsAtStake = p.pointsAtStake
    wallet.currentStreak = p.currentStreak
    wallet.unresolvedWin = p.unresolvedWin == true
    publish()
end)

-- The HUD's heartbeat: the countdown is derived from a local deadline, so it has to be pushed
-- rather than waited for. `roundCouldThrow` is sticky across the round — a player who was free to
-- throw at any point in it did not have the round taken from them.
task.spawn(function()
    while true do
        if phase == "ACTIVE" and not (fateBound or wallet.unresolvedWin) then
            roundCouldThrow = true
        end
        publish()
        task.wait(TICK)
    end
end)
