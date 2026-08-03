--!strict
-- Play-loop WIRING. Since the play-HUD redesign this file builds NO UI at all: every
-- `Instance.new` moved to HudController (the minimal HUD). What stays is the seam between the
-- remotes and the renderers, because it is the part that is subtle rather than decorative:
--   • the authoritative World-Throw tape and the per-round personal WIN/SAFE/LOSS badges,
--   • the DRUM-REST SPOILER GATE (see `visibleTape` / `maybeShowReveal`) — which now holds the FATE
--     as well as the tape and the headline,
--   • the confirm-a-throw selection (`selectedThrow`), whose rule lives in HudModel,
--   • the HudModel session — the escalation's consecutive-miss backoff,
--   • the optimistic local pick.
--
-- It publishes all of that on `EventBus.HudState:Fire(inputs, aux)`:
--   inputs : a HudModel.Inputs — the controller calls HudModel.view(inputs, aux.session)
--   aux    : { session = HudModel.Session, tape = { { worldThrow, result? } }, pick = string?,
--             timerKnown = boolean }
-- and takes picks back on `EventBus.HudPick`. Transient notices go out on `EventBus.Toast`.
--
-- The MAXIMAL panel gets its own channel, `EventBus.LedgerState`, fired only when ProfileUpdate
-- lands: the nine persisted counters, the live wallet, bestStreak and the two HUD preferences. Its
-- controls come back on `EventBus.HudPreference` and go out on `SetHudPreference` — one remote for
-- every preference, never one per switch.
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
local FateResolvedEvt = remotes:WaitForChild("FateResolved") :: RemoteEvent
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent

local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer

local TAPE_N = 5 -- how many tape entries the HUD can show
local TICK = 0.1 -- HudState cadence; the round timer is a depleting hairline, so keep it smooth
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

local phase = ""
local lockoutAt: number? = nil
local fateBound = false
local myPick: string? = nil
local roundCouldThrow = false

local wallet =
    { totalPoints = 0, pointsAtStake = 0, currentStreak = 0, bestStreak = 0, unresolvedWin = false }

-- Carried by ProfileUpdate. ON until the first one lands, which is the profile's own default.
local escalationPrompts = true
local confirmThrows = true

-- The glyph tapped but NOT yet thrown, while a pot is riding — see HudModel.tapAction. It lives here
-- rather than in HudController because this file is what turns a tap into a pick on the wire, and
-- because the auto-commit at lockout needs the countdown, which is derived here.
local selectedThrow: string? = nil

-- The nine persisted ledger counters, carried by ProfileUpdate. The maximal panel is the only
-- reader; the minimal HUD never sees them.
local counters: { [string]: number }? = nil

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
-- escalation threshold, so throws stay enabled and the alarm stays quiet. But the HAIRLINE must not
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

-- One HudModel.Inputs, built in one place. The tap handler and the lockout auto-commit both have to
-- ask the model questions about the CURRENT state, and a second hand-assembled copy of this table is
-- exactly how a field ends up set in one and forgotten in the other.
local function buildInputs(): any
    return {
        phase = phase,
        secondsLeft = secondsLeft(),
        pointsAtStake = wallet.pointsAtStake,
        currentStreak = wallet.currentStreak,
        totalPoints = wallet.totalPoints,
        unresolvedWin = wallet.unresolvedWin,
        fateBound = fateBound,
        pickedThisRound = myPick ~= nil,
        escalationPrompts = escalationPrompts,
        confirmThrows = confirmThrows,
        selectedThrow = selectedThrow,
    }
end

local function publish()
    local inputs = buildInputs()
    -- Onboarding beat 2: the RISING EDGE of throws becoming enabled — once per round, not once
    -- per session. HudModel.view is the single source of truth for the enabled rule (fate-bound,
    -- phase, pick already made) — re-deriving it here from the raw flags would be a second copy
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
        pick = myPick,
        -- Render-only, so it stays out of HudModel: false means we never got a lockout for this
        -- round and the hairline has no real span to deplete against.
        timerKnown = lockoutAt ~= nil,
    })
end

-- The maximal panel's whole input. Fired only on ProfileUpdate, because everything in it changes
-- only there — unlike HudState, which is a 10Hz heartbeat for a depleting hairline.
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
        confirmThrows = confirmThrows,
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

-- THE FATE WAITS FOR THE DRUM TOO. `fateBound` is what HudModel turns into the ACCEPT YOUR FATE
-- slot, so setting it the instant RevealTheater lands put an unambiguous "you lost" on screen while
-- the wheel was still turning — and a loss names the world's throw by implication. Same gate as the
-- toast and the tape tile, same REVEAL_SAFETY fallback, deliberately NOT a parallel mechanism.
--
-- It is held SEPARATELY from `pendingReveal` rather than folded into it because the two arrive on
-- different remotes (RevealTheater is arena-wide, RevealResult is per-player) with no ordering
-- guarantee between them: a fate parked inside `pendingReveal` would be dropped on any round where
-- the arena-wide event lost the race, and a fate that never lands leaves a player with no way out.
local pendingFate = false

local function maybeShowReveal()
    if not drumAtRest then
        return
    end
    if pendingFate then
        pendingFate = false
        fateBound = true
        -- A pick tapped in the sliver between the round reopening and the drum settling was already
        -- refused by the server (its fate gate is not client-timed), so stop lighting it — the same
        -- reasoning as the whiff branch in the RevealTheater handler.
        myPick = nil
        selectedThrow = nil -- a fate refuses the pick, so there is nothing left to confirm
        publish()
    end
    if pendingReveal then
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
        -- Onboarding beat 3 waits for the SAME gate as the toast/badge above, not for RevealResult
        -- arriving. WIN implies the exact world throw (the one your pick beats), so firing this
        -- the instant RevealResult lands — before the drum has stopped spinning — would spoil the
        -- wheel early, exactly what the drum-rest gate exists to prevent. Fires on every WIN, not
        -- just the session's first — `resolved.win` (only set once OnboardShown confirms "shown"
        -- or "alreadySeen") is what stops the retries, so a WIN dropped for stacking gets another
        -- chance at the player's next one instead of being marked taught-forever for nothing.
        if not resolved.win and profileSeen and p.result == "WIN" then
            EventBus.Onboard:Fire("win", knownSeenBeats)
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

-- The one place a pick leaves this client. Both the tap that commits and the lockout auto-commit go
-- through it, so neither can forget to clear the selection or to publish.
local function commitPick(value: string)
    -- The selection SURVIVES the commit. It is what a release (below) falls back to, and holding it
    -- is what makes "no tap can ever leave nothing selected" true: the lockout's auto-commit always
    -- has a glyph to send. Clearing it here — as this used to — would mean a released confirmation
    -- had nothing to fall back to.
    selectedThrow = value
    -- Optimistic: the tile lights the moment it is tapped. The server is what actually refuses a
    -- pick (fate-bound, past the lockout).
    myPick = value
    SubmitPick:FireServer(value)
    publish()
end

-- HudController fires this on EVERY accepted tap; the MODEL decides whether the tap throws, only
-- selects, or takes a confirmation back (HudModel.tapAction). The controller does not re-derive that
-- rule, and there is no second EventBus channel for "selected" — a select is just a publish with
-- `selectedThrow` set.
--
-- ONLY "commit" TALKS TO THE SERVER. Selecting and releasing are entirely local; a later commit
-- overwrites whatever the server last received, because the throw buffer upserts per player under a
-- seq guard.
EventBus.HudPick.Event:Connect(function(value: string)
    local action = HudModel.tapAction(buildInputs(), value)
    if action == "commit" then
        commitPick(value)
    elseif action == "select" then
        -- Moving the selection releases any confirmation with it: the player is now standing on a
        -- different glyph, and leaving `myPick` set would light one tile while claiming another.
        selectedThrow = value
        myPick = nil
        publish()
    elseif action == "release" then
        -- CONFIRMED -> selected. The glyph stays chosen and stays lit; only the commitment goes.
        myPick = nil
        publish()
    end
end)

-- No optimistic wallet edit: the pot indicator clears when ProfileUpdate lands with the banked
-- wallet, and guessing here would flash the pot to 0 and back if the request failed.
EventBus.HudBank.Event:Connect(function()
    BankRequest:FireServer()
end)

-- The ledger's preferences footer, and the confirm strip's "don't ask again". One remote carries
-- every HUD preference (and, from Task 13, the seen-beat writes) — there is deliberately not a
-- second one per switch.
--
-- Applied LOCALLY as well as sent. The switch's own paint is optimistic in LedgerController, but
-- `confirmThrows` is a RULE input, not a decoration: waiting for the ProfileUpdate echo would leave
-- the very next tap still asking for a confirmation the player has just switched off. The echo
-- reconciles a write that did not land, exactly as it does for the switch.
EventBus.HudPreference.Event:Connect(function(body)
    if type(body) == "table" then
        if type(body.escalationPrompts) == "boolean" then
            escalationPrompts = body.escalationPrompts
        end
        if type(body.confirmThrows) == "boolean" then
            confirmThrows = body.confirmThrows
        end
        publish()
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
    local mine = r.results and r.results[myId]
    if mine and mine.result == "LOSS" then
        -- HELD, not applied — see `pendingFate`. `maybeShowReveal` releases it on `drumRest`, and
        -- the safety below releases it if that cue never arrives. The identity guard is `pendingFate`
        -- itself: it is cleared the moment the fate lands, so a stale timer finds nothing to do.
        pendingFate = true
        maybeShowReveal() -- only lands if the drum is already at rest
        task.delay(REVEAL_SAFETY, function()
            if pendingFate then
                drumAtRest = true -- safety: never strand a fate if the cue dropped
                maybeShowReveal()
            end
        end)
    end
    if r.whiffed and r.whiffed[myId] then
        toast("⏳ TOO LATE — your throw didn't count this round")
        -- and stop lighting the tile they tapped: leaving myPick set would keep it illuminated
        -- through REVEAL as though it had counted, contradicting the toast.
        myPick = nil
        -- The SELECTION goes too, and it must. Since a commit now leaves it standing, a whiff that
        -- cleared only `myPick` would leave `autoCommit`'s past-ACTIVE branch looking at an
        -- uncommitted selection and re-firing the very pick the server has just refused.
        selectedThrow = nil
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
        -- A STANDING SELECTION COUNTS AS PICKED. The lockout's auto-commit normally converts it half
        -- a second before this fires, but a player who released their confirmation inside that last
        -- sliver would otherwise be scored as having ignored the round — and three of those start
        -- the escalation nagging someone who is demonstrably playing.
        roundEnded(roundCouldThrow, myPick ~= nil or selectedThrow ~= nil)
    end
    phase = info.phase
    if info.phase == "ACTIVE" then
        myPick = nil
        -- Belt and braces: the heartbeat's auto-commit consumes a pending selection well before the
        -- next round opens (TALLY + REVEAL is 5s), and a fate clears it too. This catches anything
        -- that somehow survived, so a stale glyph from last round can never be lit into this one.
        selectedThrow = nil
        -- `pendingFate` counts as bound. The fate is applied on `drumRest`, which lands a moment
        -- INTO this round, so reading `fateBound` alone here would mark a round the player is about
        -- to be held out of as one they could have thrown in — and the escalation's backoff would
        -- score it as an ignored round.
        roundCouldThrow = not fateBound and not pendingFate
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
        pendingReveal = nil -- the drum respins; last round's reveal has already been shown
        -- pendingFate is deliberately NOT cleared here, for the same reason pendingReveal is not
        -- cleared by the safety timer: dropping it would strand a player fate-bound on the server
        -- with no ACCEPT YOUR FATE button. It always resolves within REVEAL_SAFETY.
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
    -- Read BEFORE the wallet is overwritten: /bank moves the whole pot, so the pot we were holding
    -- is exactly what was banked. The maximal panel's feed is personal-only, and a bank with no line
    -- in it would be the one personal event the scrollback missed.
    local bankedNow = if p.source == "banked" then wallet.pointsAtStake else 0

    wallet.totalPoints = p.totalPoints
    wallet.pointsAtStake = p.pointsAtStake
    wallet.currentStreak = p.currentStreak
    wallet.bestStreak = p.bestStreak or wallet.bestStreak
    wallet.unresolvedWin = p.unresolvedWin == true
    if type(p.escalationPrompts) == "boolean" then
        escalationPrompts = p.escalationPrompts
    end
    if type(p.confirmThrows) == "boolean" then
        confirmThrows = p.confirmThrows
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
        -- bank toast says, anchored right below the plate — the same screen region the toast
        -- itself occupies. Showing both on someone's FIRST bank would say it twice, in the same
        -- spot, at the same moment.
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
        if phase == "ACTIVE" and not fateBound and not pendingFate then
            roundCouldThrow = true
        end
        -- THE UNCONFIRMED SELECTION IS THROWN RATHER THAN LOST. The model decides when (see
        -- HudModel.autoCommit); this loop is simply the only thing watching the countdown, at 10Hz —
        -- close enough to the half-second boundary that the pick still makes the lockout.
        local auto = HudModel.autoCommit(buildInputs())
        if auto then
            commitPick(auto)
        end
        publish()
        task.wait(TICK)
    end
end)
