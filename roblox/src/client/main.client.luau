--!strict
-- Play-loop WIRING. Since the play-HUD redesign this file builds NO UI at all: every
-- `Instance.new` moved to HudController (the minimal HUD). What stays is the seam between the
-- remotes and the renderers, because it is the part that is subtle rather than decorative:
--   • the authoritative World-Throw tape and the per-round personal WIN/SAFE/LOSS badges,
--   • the DRUM SPOILER GATE, now two gates (see `visibleTape` / `maybeShowSplash` /
--     `maybeShowReveal`): the player's own result releases as the drum SETTLES, everything
--     naming the world's throw waits until the wheel actually stops turning,
--   • the pick itself — held here as `chosen` until the lockout (`HudModel.sendAtLockout`), the
--     one point it goes over the wire,
--   • the HudModel session — the escalation's consecutive-miss backoff.
--
-- FATES ARE PARKED (2026-08-03). The rock drop, the avatar grow and ACCEPT YOUR FATE are all
-- off: the client stopped surfacing the wait (Task 5) and the server stopped summoning it
-- (Task 13, at EffectRegistry.LOSS and the reveal handler). A LOSS now simply forfeits the pot
-- and says so on the drum.
--
-- The machinery underneath (ChoreographyMachine, EffectSelector, TheaterController) is intact by
-- design and keeps driving the WIN, SAFE and BANK effects. See the spec's §5 for the seam.
--
-- It publishes all of that on `EventBus.HudState:Fire(inputs, aux)`:
--   inputs : a HudModel.Inputs — the controller calls HudModel.view(inputs, aux.session)
--   aux    : { session = HudModel.Session, tape = { { worldThrow, result? } }, timerKnown = boolean,
--              worldThrow = string? }
-- and takes picks back on `EventBus.HudPick`. Transient notices go out on `EventBus.Toast`.
--
-- The MAXIMAL panel gets its own channel, `EventBus.LedgerState`, fired both when ProfileUpdate
-- lands AND at every drum-rest reveal (Task 9): the nine persisted counters, the live wallet,
-- bestStreak, the two HUD preferences (escalationPrompts, resultSplash), and `lastRound` — the
-- LAST ROUND band's detail (worldThrow, pick, result, distribution, totalPlayers), nil until this
-- client has seen its first reveal. Its controls come back on `EventBus.HudPreference` and go out
-- on `SetHudPreference` — one remote for every preference, never one per switch.
--
-- BANK THESE (the pot indicator's only button) comes back on `EventBus.HudBank` and goes out on
-- the long-standing BankRequest remote. There is no RISK counterpart and nothing to "resolve":
-- riding is throwing again, and the server clears unresolvedWin at the next settlement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HudModel = require(shared:WaitForChild("HudModel"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local SetHudPreference = remotes:WaitForChild("SetHudPreference") :: RemoteEvent
local RequestLedger = remotes:WaitForChild("RequestLedger") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent

local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer

local TAPE_N = 5 -- how many tape entries the HUD can show
local TICK = 0.1 -- HudState cadence; the round timer is a depleting ring, so keep it smooth
local REVEAL_SAFETY = 3 -- seconds before a dropped drumRest cue is assumed lost
local BANK_TOAST_FAILOPEN_SECONDS = 1 -- see pendingBankToast: a missing OnboardingController ack
-- must never permanently silence the bank toast

-- The tape renders DIRECTLY from the authoritative World-Throw tape (newest-first, deduped, each
-- entry carrying a round id), carried by both RoundUpdate (every phase) and BoardData (on join +
-- every 30s). Rendering from the tape — rather than accumulating client-side — means it seeds the
-- instant either arrives and can never duplicate. Personal badges are keyed by round id and set
-- when the local drum finishes revealing that round.
local tape: { { id: string, worldThrow: string } } = {}
local badgeById: { [string]: string } = {}
local currentRoundId: string? = nil -- the round in play (from RoundUpdate)
local revealedRoundId: string? = nil -- the latest round our drum has finished
-- The world's throw for the round `revealedRoundId` names, or nil. Set alongside it in
-- `maybeShowReveal` and cleared when ACTIVE reopens, so the ring (HudController) inherits the
-- SAME drum-rest spoiler gate the tape does rather than a second one of its own.
local revealedWorldThrow: string? = nil

local phase = ""
local lockoutAt: number? = nil
local roundCouldThrow = false

local wallet =
    { totalPoints = 0, pointsAtStake = 0, currentStreak = 0, bestStreak = 0, unresolvedWin = false }

-- Carried by ProfileUpdate. ON until the first one lands, which is the profile's own default.
local escalationPrompts = true
local resultSplash = true

-- THE ROUND'S PICK STATE. `chosen` is the player's commitment and `sent` is the wire's, and
-- they are separate on purpose: the pick is held here until the lockout (HudModel.sendAtLockout)
-- because ThrowBuffer is upsert-only, so sending on the first tap would make backing out a lie.
local chosen: string? = nil
local undoPrompt: string? = nil
local undoPromptAt: number? = nil
local sent = false
-- Set by a back-out, cleared when ACTIVE reopens. A player who withdrew has answered the
-- question the escalation asks, so it must not ask again this round.
local declinedThisRound = false

-- The nine persisted ledger counters, carried by ProfileUpdate. The maximal panel is the only
-- reader; the minimal HUD never sees them.
local counters: { [string]: number }? = nil

-- The ledger's LAST ROUND band (spec §3): the same five fields the toast used to carry, minus
-- `forfeited` (the splash's own). Set once per round, in `maybeShowReveal`, at the SAME drum-rest
-- gate `pendingReveal` observes — never read `pendingReveal` itself outside that function, since
-- it is nil'd out the instant `maybeShowReveal` runs. UNLIKE `pendingReveal`, this PERSISTS across
-- rounds, so `publishLedger`'s payload still has something to show between reveals. nil only
-- until the FIRST round this client has seen revealed, so a fresh join hides the band rather than
-- showing zeros to someone who just arrived. Declared here (well before `pendingReveal`, which is
-- built for the same reveal) because `publishLedger` below closes over it, and Luau closures can
-- only capture a local already in scope at the point the capturing function is defined.
local lastRound: {
    worldThrow: string,
    pick: string?,
    result: string?,
    distribution: any?,
    totalPlayers: number?,
}? =
    nil

-- The onboarding beats the profile already carries, carried by ProfileUpdate. Passed alongside
-- every EventBus.Onboard fire so OnboardingController can seed (and keep current) its local
-- "already seen" list — see the fires below. Empty until the first ProfileUpdate lands.
local knownSeenBeats: { string } = {}

-- NO BEAT FIRES BEFORE THE PROFILE HAS ANSWERED. `knownSeenBeats` starting empty does not mean the
-- player has dismissed nothing; it means nobody has said yet. Firing into that emptiness re-shows a
-- card someone dismissed months ago, and `OnboardShown` LATCHES it, so it never self-corrects.
--
-- Two ways that happens, and this one flag closes both:
--   • TIMING. `join` goes out on the first RoundUpdate, and ProfileUpdate waits on the server's
--     `GET /players` round trip. Usually the fetch wins; a phase boundary landing inside it does
--     not.
--   • A FAILED JOIN FETCH, which is deterministic. ProfileUpdate is NOT only fired after that
--     fetch — the server also fires it from every reveal ("local") and every reconciliation
--     ("reconciled"), which run regardless. What those carry is a seenBeats the server does not
--     actually know. The server now sends nil rather than `{}` for that (see fireProfile), and this
--     flag is set only on a real list, so an "I don't know" no longer reads as "nothing seen".
--
-- Costs nothing in the normal case: every beat fires on a repeating occasion (join re-fires each
-- RoundUpdate, throwsUnlocked on each round's rising edge, win on each win), so the first one after
-- the profile lands shows the card. If the profile never answers, the session teaches nothing and
-- the player recovers by opening the ledger, whose refresh repairs the server's cache. A first-timer
-- missing their cards for one session beats a veteran being re-taught the entire game, latched.
local profileSeen = false

-- Whether each beat's event still needs firing. NOT the same as "has the event happened yet" —
-- a round-1 review caught that mistake: latching the moment an event is FIRED (rather than once
-- OnboardingController confirms it actually SHOWED a card) meant a beat dropped for stacking
-- (e.g. the player banks their first pot without dismissing the still-up "win" card) was marked
-- consumed forever, having taught the player nothing. `resolved[event]` is instead driven by
-- `EventBus.OnboardShown`'s echo (see below): true once the controller reports "shown" or
-- "alreadySeen" (nothing left to teach), and left false on "dropped" so the next natural
-- occurrence of that event (next round's throwsUnlocked, the next win, the next bank) retries.
-- `{ [string]: boolean }`, not the inferred fixed-shape record: `resolved[event]` is indexed
-- dynamically by whatever string `EventBus.OnboardShown` echoes back, and under `--!strict` a
-- fixed-shape table has no `[string]` indexer — an event name that wasn't one of the four
-- literal keys below would silently CREATE a new field rather than being caught.
local resolved: { [string]: boolean } = { join = false, throwsUnlocked = false, win = false, bank = false }

-- Edge-detector for `throwsUnlocked`: without it, firing on every publish() tick (10Hz) while
-- throws stay enabled across a whole round would ask the controller ten times a second for no
-- reason — `OnboardingBeats.next` is cheap but not THAT cheap to call. Fires once per RISING edge
-- (the moment throws newly become enabled), which is exactly "the first time" per round.
local wasThrowsEnabled = false

-- The confirmation-in-flight for a bank toast — see the ProfileUpdate handler and the
-- EventBus.OnboardShown listener below. BindableEvents are deferred in this engine, so "did the
-- beat 4 card just take this bank's spot" cannot be decided synchronously at the point the bank
-- lands; the toast is decided when the answer comes back instead.
local pendingBankToast: string? = nil

local session = HudModel.newSession()

-- couldThrow mirrors the server's own refusal conditions: a round the player was refused is not
-- a round they ignored.
local function roundEnded(couldThrow: boolean, picked: boolean)
    session = HudModel.onRoundEnded(session, { couldThrow = couldThrow, picked = picked })
end

-- The clock may not have synced when ACTIVE opens (secondsToLockout arrives nil), and lockoutAt is
-- only ever assigned at that transition — so a nil there stays nil for the whole round. The old HUD
-- let the player throw anyway and so do we: report a nominal countdown comfortably above the
-- escalation threshold, so throws stay enabled and the alarm stays quiet. But the RING must not
-- fake a span it does not have: a constant would pin it full and motionless while throws kept
-- working past the real lockout. `timerKnown` tells the HUD to hide it instead.
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

-- One HudModel.Inputs, built in one place. The tap handler and the lockout send both have to ask
-- the model questions about the CURRENT state, and a second hand-assembled copy of this table is
-- exactly how a field ends up set in one and forgotten in the other.
local function buildInputs(): any
    return {
        phase = phase,
        secondsLeft = secondsLeft(),
        pointsAtStake = wallet.pointsAtStake,
        currentStreak = wallet.currentStreak,
        totalPoints = wallet.totalPoints,
        unresolvedWin = wallet.unresolvedWin,
        escalationPrompts = escalationPrompts,
        chosen = chosen,
        undoPrompt = undoPrompt,
        sent = sent,
        declinedThisRound = declinedThisRound,
    }
end

local function publish()
    local inputs = buildInputs()
    -- Onboarding beat 2: the RISING EDGE of throws becoming enabled — once per round, not once
    -- per session. HudModel.view is the single source of truth for the enabled rule (phase, pick
    -- already made) — re-deriving it here from the raw flags would be a second copy
    -- of a rule that already lives in one place. Firing on every rising edge (rather than "the
    -- first time ever", latched at fire time) is what lets a dropped occurrence — the join card
    -- was still up when throws first unlocked — retry on the very next round instead of the beat
    -- most first-timers need most simply never firing again this session.
    local nowThrowsEnabled = HudModel.view(inputs, session).throwsEnabled
    if not resolved.throwsUnlocked and profileSeen and nowThrowsEnabled and not wasThrowsEnabled then
        EventBus.Onboard:Fire("throwsUnlocked", knownSeenBeats)
    end
    wasThrowsEnabled = nowThrowsEnabled
    EventBus.HudState:Fire(inputs, {
        session = session,
        tape = visibleTape(),
        -- Render-only, so it stays out of HudModel: false means we never got a lockout for this
        -- round and the ring has no real span to deplete against.
        timerKnown = lockoutAt ~= nil,
        -- The world's throw for the round the drum has FINISHED revealing, or nil. Gated by the
        -- same `revealedRoundId` the tape is, so the ring cannot spoil the wheel mid-spin.
        worldThrow = revealedWorldThrow,
        -- Render-only, the same class of fact as `timerKnown`: whether the server's join fetch has
        -- actually answered with this player's profile, or the wallet above is still the placeholder
        -- zeros this script starts with. HudController seeds its counters on the first render this is
        -- true rather than counting to the balance from those zeros — see `seedCounter` there. It is
        -- NOT a HudModel input: nothing in `HudModel.view` derives anything from it.
        profileSeen = profileSeen,
    })
end

-- The maximal panel's whole input. Fired only on ProfileUpdate, because everything in it changes
-- only there — unlike HudState, which is a 10Hz heartbeat for a depleting ring.
--
-- Deliberately NOT gated on `counters` being present. This is the panel's ONLY channel, so an early
-- return here would take the live hero band, best streak and the preference switch down with the
-- counters — none of which are counters. A nil simply leaves the renderer's zeros in place.
local function publishLedger()
    EventBus.LedgerState:Fire({
        counters = counters,
        live = { pot = wallet.pointsAtStake, streak = wallet.currentStreak, points = wallet.totalPoints },
        bestStreak = wallet.bestStreak,
        escalationPrompts = escalationPrompts,
        resultSplash = resultSplash,
        lastRound = lastRound,
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

-- The tape tile waits for the drum to stop turning (the drumRest cue) and the result splash for
-- the drum to commit to its detent (drumSettling, ~0.36-0.51s earlier), so neither spoils the throw
-- mid-spin. NOT nil'd by the splash: `maybeShowSplash` only reads this record, because the tape
-- tile still needs it afterwards. The splash (SplashController) owns naming the personal result
-- now — the old toast folded the vote distribution into the same headline it built here,
-- but that headline is gone; `distribution`/`totalPlayers`/`pick` are captured anyway (`pick`
-- unused by the splash) because Task 9's ledger LAST ROUND band needs the same crowd-split,
-- player-count and personal-throw data the toast used to carry.
local pendingReveal: {
    roundId: string?,
    result: string?,
    worldThrow: string,
    pick: string?,
    distribution: any?,
    totalPlayers: number?,
    -- The pot as it stood before a LOSS cleared it. nil until the ProfileUpdate("local") handler
    -- below fills it in — see that handler's comment for why this is the one place it can be read.
    forfeited: number?,
}? =
    nil
local drumAtRest = false

-- Two gates, not one. The SPLASH — the player's own result — releases on `drumSettling`, which
-- DrumController fires the first frame the drum is within half a facet of home — 0.36-0.51s before
-- it stops, varying with the travel the lander picked. Everything else (the tape badge, the ledger's LAST ROUND band, the
-- first-win onboarding beat) stays on `drumRest`, because those name the WORLD's throw and
-- releasing them early is the spoiler this gate exists to prevent.
local drumSettling = false
local splashDone = false

local function maybeShowSplash()
    if not drumSettling or splashDone then
        return
    end
    local p = pendingReveal
    -- `p.result` is nil whenever this player had no throw counted this round (a spectator, or a
    -- whiff), so the splash cannot appear for a round the player did not throw in.
    if not p or not p.result then
        return
    end
    splashDone = true
    EventBus.Splash:Fire({
        result = p.result,
        streak = wallet.currentStreak,
        pot = wallet.pointsAtStake,
        forfeited = p.forfeited,
    })
end

local function maybeShowReveal()
    maybeShowSplash() -- drumRest implies settling, so a dropped cue still releases the splash here
    if not drumAtRest then
        return
    end
    if pendingReveal then
        local p = pendingReveal
        pendingReveal = nil
        -- Task 9: stash the round detail for the ledger's LAST ROUND band. Unconditional (not
        -- gated on `p.roundId`, unlike the badge below) so it updates for every revealed round
        -- this client sees, participant or spectator alike.
        lastRound = {
            worldThrow = p.worldThrow,
            pick = p.pick,
            result = p.result,
            distribution = p.distribution,
            totalPlayers = p.totalPlayers,
        }
        -- Badge this round by id and un-gate it in the tape now the drum's at rest.
        if p.roundId then
            if p.result then
                badgeById[p.roundId] = p.result
            end
            revealedRoundId = p.roundId
            revealedWorldThrow = p.worldThrow
        end
        -- Onboarding beat 3 waits for the SAME gate as the badge above, not for RevealResult
        -- arriving. WIN implies the exact world throw (the one your pick beats), so firing this
        -- the instant RevealResult lands — before the drum has stopped spinning — would spoil the
        -- wheel early, exactly what the drum-rest gate exists to prevent. Fires on every WIN, not
        -- just the session's first — `resolved.win` (only set once OnboardShown confirms "shown"
        -- or "alreadySeen") is what stops the retries, so a WIN dropped for stacking gets another
        -- chance at the player's next one instead of being marked taught-forever for nothing.
        --
        -- DELIBERATELY NOT DEDUPED against the splash, even though on a first win both are on
        -- screen together (the splash arrives ~0.7s ahead now, and outlives that). This is not
        -- the bank case (which grew dedup machinery because
        -- the toast and the beat said the literal same sentence in the same screen region): the
        -- splash CELEBRATES ("YOU WIN! / streak ×1 — pot is now 1") and the beat TEACHES ("You
        -- won. Take it, or ride it — a win triples your pot."), they sit in different regions, and
        -- the splash is non-Active so it steals no taps from the card. Complementary, not
        -- duplicated — do not add dedup machinery here.
        if not resolved.win and profileSeen and p.result == "WIN" then
            EventBus.Onboard:Fire("win", knownSeenBeats)
        end
        -- THE SPLASH NO LONGER SHARES THIS GATE. It releases on the earlier `drumSettling` cue —
        -- see `maybeShowSplash` above, called on this function's first line, which is its FALLBACK
        -- rather than its normal path. What stays here is everything that names the WORLD's throw.
        publish()
        -- The ledger reads `lastRound` from EventBus.LedgerState, not the HudState `publish()`
        -- above — without this call the panel would keep showing the PREVIOUS round's detail
        -- until the next ProfileUpdate happened to fire publishLedger() again (a bank, or this
        -- player's own next reveal), which for a spectator round might never come.
        publishLedger()
    end
end

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumSettling" then
        drumSettling = true
        maybeShowSplash()
    elseif cue.kind == "drumRest" then
        drumSettling = true -- drumRest implies it, even if that cue was dropped
        drumAtRest = true
        maybeShowReveal()
    end
end)

-- The one place a pick leaves this client, and it happens ONCE per round at the lockout.
-- `sent` is set before the fire, not after: a re-entrant heartbeat tick must not be able to
-- send the same pick twice.
local function sendPick(value: string)
    sent = true
    SubmitPick:FireServer(value)
    publish()
end

-- HudController fires this on every accepted tap; the MODEL decides what the tap means
-- (HudModel.tapAction) and what the state becomes (HudModel.applyTap). The controller
-- re-derives neither.
--
-- NOTHING HERE TALKS TO THE SERVER. Choosing, prompting and clearing are all local; the pick
-- goes over the wire in the heartbeat below, at the lockout.
EventBus.HudPick.Event:Connect(function(value: string)
    local action = HudModel.tapAction(buildInputs(), value)
    if action == "ignore" then
        return
    end
    local nextState = HudModel.applyTap({ chosen = chosen, undoPrompt = undoPrompt }, action, value)
    chosen = nextState.chosen
    undoPrompt = nextState.undoPrompt
    undoPromptAt = if undoPrompt then os.clock() else nil
    if action == "clear" then
        declinedThisRound = true
    end
    publish()
end)

-- The escalation overlay's own tap. A dismissal is not a decline in spirit, but the escalation
-- rule only cares that the player answered — HudModel.applyTap's "back out" branch already reads
-- `declinedThisRound` to mean "silenced for the round" (Task 2 widened the comment, not the
-- field), so this reuses it rather than adding a second flag the model would also have to check.
EventBus.DismissEscalation.Event:Connect(function()
    declinedThisRound = true
    publish()
end)

-- No optimistic wallet edit: the pot indicator clears when ProfileUpdate lands with the banked
-- wallet, and guessing here would flash the pot to 0 and back if the request failed.
EventBus.HudBank.Event:Connect(function()
    BankRequest:FireServer()
end)

-- The ledger's preferences footer. One remote carries every HUD preference (and, from Task 13, the
-- seen-beat writes) — there is deliberately not a second one per switch.
--
-- Applied LOCALLY as well as sent. The switch's own paint is optimistic in LedgerController, and the
-- echo reconciles a write that did not land.
--
-- BOTH `publish()` AND `publishLedger()` — `escalationPrompts` only needs the former (nothing
-- outside the ledger reads it live), but `resultSplash` is read by SplashController from
-- `EventBus.LedgerState`, the channel `publishLedger()` fires, not `EventBus.HudState`. Without
-- this a toggle here would only take effect once something else happened to call
-- `publishLedger()` next (today that is `ProfileUpdate`, which coincidentally lands before the
-- next drum rest — but a coincidence is not a guarantee).
EventBus.HudPreference.Event:Connect(function(body)
    if type(body) == "table" then
        if type(body.escalationPrompts) == "boolean" then
            escalationPrompts = body.escalationPrompts
        end
        if type(body.resultSplash) == "boolean" then
            resultSplash = body.resultSplash
        end
        publish()
        publishLedger()
    end
    SetHudPreference:FireServer(body)
end)

-- OnboardingController's echo of what actually happened to the beat this file just asked it to
-- show — see the `resolved` comment above. "dropped" (another card was already up) is the one
-- outcome that must NOT resolve the event, so the next natural occurrence gets to try again.
EventBus.OnboardShown.Event:Connect(function(event: string, outcome: string)
    if outcome ~= "dropped" then
        resolved[event] = true
    end
    if event == "bank" and pendingBankToast then
        local line = pendingBankToast
        pendingBankToast = nil
        if outcome ~= "shown" then
            -- Either dropped (no card appeared this time, so the amount still needs saying) or
            -- alreadySeen (nothing was ever going to show) — both mean the toast is the only
            -- thing that told the player anything about this bank, so it must not be skipped.
            toast(line)
        end
    end
end)

-- OpenLedger has two listeners: LedgerController shows the panel, and this asks the server to
-- re-read the nine lifetime counters from the authoritative profile. They are never accumulated
-- locally — an optimistic lifetime total can only drift upward and would read LOWER after a rejoin —
-- so opening the panel is what refreshes them. The panel paints its last-known figures immediately
-- and snaps to the authoritative ones when the ProfileUpdate echo lands a moment later.
EventBus.OpenLedger.Event:Connect(function()
    RequestLedger:FireServer()
end)

RevealTheater.OnClientEvent:Connect(function(r)
    local myId = tostring(player.UserId)
    if r.whiffed and r.whiffed[myId] then
        toast("⏳ TOO LATE — your throw didn't count this round")
        -- and stop lighting the glyph: leaving it chosen would keep the tile illuminated
        -- through REVEAL as though it had counted, contradicting the toast.
        chosen = nil
        undoPrompt = nil
        undoPromptAt = nil
    end
    publish()
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    -- Onboarding beat 1: "the arena is live" per the design intent, not tied to any particular
    -- phase. Fires on every RoundUpdate until `resolved.join` — in practice this resolves on the
    -- first call once the profile has landed (nothing can be up before this client's first Onboard
    -- fire ever), but gating on the confirmation rather than latching at fire time keeps this
    -- consistent with the other three and costs nothing. `profileSeen` is the guard all four beats
    -- share: firing with a `knownSeenBeats` nobody has filled in re-shows a dismissed card and
    -- latches it (see above).
    if not resolved.join and profileSeen then
        EventBus.Onboard:Fire("join", knownSeenBeats)
    end
    currentRoundId = info.roundId
    if info.tape and #info.tape > 0 then
        tape = info.tape -- authoritative World-Throw history, every phase change
    end
    if phase == "ACTIVE" and info.phase ~= "ACTIVE" then
        -- A STANDING CHOICE COUNTS AS PLAYED. The lockout normally sends it half a second
        -- before this fires; a choice made inside that last sliver must not be scored as an
        -- ignored round, because three of those start the escalation nagging someone who is
        -- demonstrably playing.
        roundEnded(roundCouldThrow, chosen ~= nil)
    end
    phase = info.phase
    if info.phase == "ACTIVE" then
        chosen = nil
        undoPrompt = nil
        undoPromptAt = nil
        sent = false
        declinedThisRound = false
        roundCouldThrow = true
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
        pendingReveal = nil -- the drum respins; last round's reveal has already been shown
        drumAtRest = false
        drumSettling = false
        -- PER ROUND, not per reveal: without this reset the second round of a session, and every
        -- round after it, would never splash.
        splashDone = false
        revealedWorldThrow = nil -- the ring must not carry last round's glyph into this one
    else
        lockoutAt = nil
    end
    publish()
end)

RevealResult.OnClientEvent:Connect(function(r)
    -- The revealing round == the one RoundUpdate last named (REVEAL phase). Captured to a local so
    -- the REVEAL_SAFETY fallback below still identifies THIS reveal even if `currentRoundId` has
    -- moved on by the time it fires.
    local roundId = currentRoundId
    -- No toast built here any more (spec §2 — the splash owns results, fired from the drum-rest
    -- gate in `maybeShowReveal`). `distribution`/`totalPlayers` are stashed anyway: they are the
    -- crowd split and player count the old toast headline used to carry, and Task 9's ledger LAST
    -- ROUND band needs the same data.
    pendingReveal = {
        roundId = roundId,
        result = r.result,
        worldThrow = r.worldThrow,
        pick = r.pick,
        distribution = r.distribution,
        totalPlayers = r.totalPlayers,
    }
    maybeShowReveal() -- only shows if the drum is already at rest
    task.delay(REVEAL_SAFETY, function()
        if pendingReveal and pendingReveal.roundId == roundId then
            -- safety: never strand a result if the cues dropped. BOTH flags, so neither half is
            -- left behind — a splash that never appears is far worse than one that appears early.
            drumSettling = true
            drumAtRest = true
            maybeShowReveal()
        end
    end)
end)

ProfileUpdate.OnClientEvent:Connect(function(p)
    -- Read BEFORE the wallet is overwritten: /bank moves the whole pot, so the pot we were holding
    -- is exactly what was banked. The maximal panel's feed is personal-only, and a bank with no line
    -- in it would be the one personal event the scrollback missed.
    local bankedNow = if p.source == "banked" then wallet.pointsAtStake else 0

    -- SAME TRICK, for the splash's LOSS consequence line: `p.source == "local"` is the ONE
    -- ProfileUpdate a reveal fires (main.server.luau's onReveal, right after RevealResult, same
    -- tick, same client — so `pendingReveal` set by the RevealResult handler above is always this
    -- SAME round's, never stale). `wallet.pointsAtStake` here is still the PRE-reveal pot — the
    -- one this LOSS is about to clear — so it is exactly the "forfeited" figure, read the one
    -- instant it is available. Guarded on `pendingReveal.result == "LOSS"` so a WIN's tripled pot
    -- or a SAFE's preserved one is never mistaken for a forfeiture.
    if p.source == "local" and pendingReveal and pendingReveal.result == "LOSS" then
        pendingReveal.forfeited = wallet.pointsAtStake
    end

    wallet.totalPoints = p.totalPoints
    wallet.pointsAtStake = p.pointsAtStake
    wallet.currentStreak = p.currentStreak
    wallet.bestStreak = p.bestStreak or wallet.bestStreak
    wallet.unresolvedWin = p.unresolvedWin == true
    if type(p.escalationPrompts) == "boolean" then
        escalationPrompts = p.escalationPrompts
    end
    if type(p.resultSplash) == "boolean" then
        resultSplash = p.resultSplash
    end
    if type(p.counters) == "table" then
        counters = p.counters
    end
    if type(p.seenBeats) == "table" then
        knownSeenBeats = p.seenBeats
        -- ONLY here. An absent seenBeats is the server saying it does not know (its join fetch
        -- failed); an EMPTY list is the server saying this player has dismissed nothing, which is a
        -- real answer about a real first-timer. Latching on the former is what re-taught veterans.
        profileSeen = true
    end
    if bankedNow > 0 then
        -- Onboarding beat 4's copy ("Banked. That's yours to keep.") says almost exactly what the
        -- bank toast says. The card shows at the `wallet` anchor (OnboardingController — the same
        -- spot as `throwArea`/`potIndicator`, above the bank+throws+tape cluster); the toast itself
        -- is top-centre (HudController). Different screen regions, but showing both on someone's
        -- FIRST bank would still say the same thing twice at the same moment.
        --
        -- Once beat 4 is `resolved` (it has either shown once already, or was already seen coming
        -- in) it can never show again, so the toast is unconditional and immediate — the common
        -- case for every returning player and every bank after their first.
        --
        -- Otherwise, whether THIS bank is the one the card takes cannot be decided here: it
        -- depends on whether some other card (e.g. beat 3's, still up from the same win) is
        -- already occupying the slot, which only OnboardingController knows, and BindableEvents in
        -- this engine are DEFERRED — `EventBus.Onboard:Fire` does not run OnboardingController's
        -- handler synchronously, so there is nothing to read back yet at this line. Stash the line
        -- and let the `EventBus.OnboardShown` listener below decide once the answer is in.
        -- `not profileSeen` takes the SAME branch as `resolved.bank`, and that is load-bearing: the
        -- beat is suppressed when the profile has not answered, so the toast must be the thing that
        -- speaks. Routing it through the pending-ack path instead would hand the line to a card that
        -- is never going to be asked for, and the bank would land in silence. The seenBeats block
        -- above runs first, so a ProfileUpdate that carries a real list has already latched.
        if resolved.bank or not profileSeen then
            toast(`💰 BANKED {bankedNow} — that's yours to keep`)
        else
            local line = `💰 BANKED {bankedNow} — that's yours to keep`
            pendingBankToast = line
            EventBus.Onboard:Fire("bank", knownSeenBeats)
            -- FAIL OPEN. If OnboardingController never acks — dead, not yet connected, or errored
            -- somewhere in its require/WaitForChild block before it ever reaches its
            -- EventBus.Onboard:Connect — `pendingBankToast` would strand forever, and because
            -- `resolved.bank` also never latches, EVERY subsequent bank would go silent too, not
            -- just this one. A missing onboarding controller must never silence banking. Under
            -- normal operation the ack lands on the next resumption (BindableEvents are deferred,
            -- not synchronous, but not slow), so this is a no-op almost always — `line` is
            -- compared by identity-of-value to the CURRENT pending toast so it never clobbers a
            -- newer one this delay wasn't for.
            task.delay(BANK_TOAST_FAILOPEN_SECONDS, function()
                if pendingBankToast == line then
                    pendingBankToast = nil
                    toast(line)
                end
            end)
        end
    end
    publishLedger()
    publish()
end)

-- The HUD's heartbeat: the countdown is derived from a local deadline, so it has to be pushed
-- rather than waited for. `roundCouldThrow` is sticky across the round — a player who was free to
-- throw at any point in it did not have the round taken from them.
task.spawn(function()
    while true do
        if phase == "ACTIVE" then
            roundCouldThrow = true
        end
        -- An unanswered UNDO? ages out. Both outcomes of expiry are safe: it restores
        -- exactly the state before the stray tap.
        if HudModel.undoPromptExpired(undoPromptAt, os.clock()) then
            undoPrompt = nil
            undoPromptAt = nil
        end
        -- THE PICK'S ONE TRIP TO THE WIRE. The model decides when; this loop is simply the only
        -- thing watching the countdown, at 10Hz — close enough to the half-second boundary that
        -- the pick still makes the lockout.
        local send = HudModel.sendAtLockout(buildInputs())
        if send then
            sendPick(send)
        end
        publish()
        task.wait(TICK)
    end
end)
