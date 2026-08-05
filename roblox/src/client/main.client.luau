--!strict
-- Play-loop WIRING. Since the play-HUD redesign this file builds NO UI at all: every
-- `Instance.new` moved to HudController (the minimal HUD). What stays is the seam between the
-- remotes and the renderers, because it is the part that is subtle rather than decorative:
--   • the authoritative World-Throw tape and the per-round personal WIN/SAFE/LOSS badges,
--   • the DRUM-REST SPOILER GATE (see `visibleTape` / `maybeShowReveal`), which holds the tape
--     tile and the headline until the wheel stops turning — and then THE REVEAL BEAT, which holds
--     the tile a while longer still, so the ring's glyph gets the moment to itself,
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
--              openSeconds = number?, worldThrow = string?, worldThrowFading = boolean?,
--              profileSeen = boolean }
--            `tape` is spoiler-gated here, so the controller paints it as given. `worldThrow` is
--            the world's throw for the round the drum has FINISHED revealing, or nil.
--            `worldThrowFading` is this file saying the beat's hold is over and the glyph should
--            be on its way out — HudController owns the animation, this is only the cue.
--            `profileSeen` is whether the wallet in `inputs` is the server's answer or the
--            placeholder zeros this script starts with.
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
local RevealBeat = require(shared:WaitForChild("RevealBeat"))
local DrumStep = require(shared:WaitForChild("DrumStep"))
local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))

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
local BANK_TOAST_FAILOPEN_SECONDS = 1 -- see pendingBankToast: a missing OnboardingController ack
-- must never permanently silence the bank toast

-- THE REVEAL-SAFETY FALLBACK, armed from the STRIKE (`gongHit`) — see DrumStep for the derivation
-- and for why it used to be a flat 3s armed from RevealResult arriving, and why that flat 3s was
-- beating the drum on EVERY round rather than on the rare dropped-cue round it was written for.
local REVEAL_SAFETY = DrumStep.SAFETY_AFTER_STRIKE_SECONDS
local REVEAL_SAFETY_STALLED = DrumStep.SAFETY_AFTER_STRIKE_STALLED_SECONDS
-- Slack on top of the strike's own lead, covering the client's phase-poll lag (the observed
-- transitions run ~1s behind the nominal boundaries). Only ever makes the missed-strike backstop
-- LATER, never earlier.
local STRIKE_LEAD_SLACK = 1
-- How far ahead of a reveal that has ALREADY arrived a legitimate `gongHit` can still be. The
-- reveal no longer lands early: the world throw is decided at the END of LOCK, so a LOCK-phase
-- fetch (RoundCoordinator's `_fetchRevealIfDue` accepts LOCK as well as REVEAL) always 404s, and the
-- payload lands after REVEAL opens, not before it — while the strike is scheduled LockSec into
-- LOCK, with `gongHit` at the END of the shu-moku's swing.
--
-- SO THE `LockSec` TERM BELOW IS NOW HEADROOM, NOT A MEASUREMENT. It sized the gap back when the
-- reveal could arrive a whole TALLY ahead of the strike; today the real lead is only the swing.
-- It is KEPT because every error here must fail LATE — a window too wide merely accepts a
-- `gongHit` it would have accepted anyway, while one too narrow rejects a legitimate strike and
-- strands the round's reveal. Do not "simplify" it away.
-- Read from the live schedule so a server retune of LOCK carries — FindFirstChild, never
-- WaitForChild, because the HUD must not block on the arena's config folder.
local function strikeLeadSeconds(): number
    local cfg = ReplicatedStorage:FindFirstChild("RoundScheduleConfig")
    local lock = if cfg then cfg:GetAttribute("LockSec") else nil
    return (if typeof(lock) == "number" then lock else 2) + DrumStep.STRIKE_SWING_SECONDS + STRIKE_LEAD_SLACK
end

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
-- `maybeShowReveal` and cleared when OPEN reopens, so the ring (HudController) inherits the
-- SAME drum-rest spoiler gate the tape does rather than a second one of its own.
local revealedWorldThrow: string? = nil

-- THE REVEAL BEAT (2026-08-04). The glyph in the ring, the result splash and the new tape tile all
-- used to arrive in the same frame, and the smallest of the three — the glyph — lost, which is why
-- it read as missing even while it was rendering. They are separated in time now, every step
-- measured from the drum coming fully to rest (the numbers live in `RevealBeat`, shared with
-- HudController because both files have to agree about them):
--   0                        the glyph appears in the ring, and the splash fires
--   HOLD_SECONDS             the glyph begins to fade (`worldThrowFading`, animated over there)
--   TAPE_DELAY_SECONDS       the glyph is gone, and ONLY THEN does the tape tile land
--
-- `beatGen` is a generation counter — the same shape `plateGen` uses in HudController. Every beat
-- increments it and each scheduled step captures the value, so a superseded beat's `task.delay`
-- is discarded rather than firing late over a newer round.
local beatGen = 0
-- Published as `aux.worldThrowFading`.
local worldThrowFading = false
-- THE BEAT IN FLIGHT, and the whole reason this record exists: the tape tile is the round's
-- PERMANENT record, and one lost to a timing edge leaves a hole in the tape that no later round
-- repairs. If the next round opens mid-beat, the beat collapses and the tile must land AT ONCE —
-- and the collapse cannot go back to `pendingReveal` for it, because `maybeShowReveal` nils that
-- the instant the beat starts, so the collapse would find nil, drop the tile silently, and no gate
-- would notice. Set when the beat starts; cleared by `landTape`, whether it completed or collapsed.
local beatInFlight: { roundId: string?, result: string? }? = nil

-- The tape half of the reveal: badge the round and un-gate its entry in `visibleTape`. Clearing the
-- flight record is what makes this idempotent, so the beat's own scheduled landing and a collapse
-- racing it can never BOTH emit the tile — and neither can skip it.
local function landTape()
    local b = beatInFlight
    if not b then
        return
    end
    beatInFlight = nil
    if b.roundId then
        if b.result then
            badgeById[b.roundId] = b.result
        end
        revealedRoundId = b.roundId
    end
end

-- THE ROUND'S PHASE, from two sources that are NOT interchangeable.
--
-- `phase` is the EFFECTIVE phase — what the HUD renders and what HudModel reads. Since
-- 2026-08-04 it normally comes from the PUBLISHED TIMELINE (`refreshClock` below: RoundMetronome
-- fed from RoundScheduleConfig, on the GetServerTimeNow clock every client already shares — the
-- same schedule the bell's cam has always run on). The timeline knows a boundary at the instant
-- it happens; RoundUpdate only learns of one when the Roblox game server's 1-1.25s poll notices,
-- which is the second the ring used to appear and disappear late by.
--
-- `serverPhase` is the last phase RoundUpdate reported, and it is not vestigial. It has three
-- jobs. It is the FALLBACK when no schedule has landed; it is what THROWS OPEN ON, in agreement
-- with the timeline (`throwPhase` below — a timeline that leads may open throws before the server
-- has a round to take them, and the tap would be swallowed by this handler's own reset); and it is
-- the phase the round-ended edge is measured on —
-- that edge is about the SERVER's round closing, so re-keying it to a local clock that
-- deliberately leads the server would fire it early, or (worse) never, because by the time
-- RoundUpdate said LOCK the effective phase would already have left OPEN and the edge would
-- have passed unobserved.
local phase = ""
local serverPhase = ""
-- The timeline's last phase, sampled by `refreshClock` on the 10Hz heartbeat. nil until a
-- schedule lands, which is exactly the "no schedule, no local clock" state — and the one flag
-- that says whether the timeline or the poll owns `lockoutAt` at this instant.
local localPhase: string? = nil
-- THE MOMENT PICKS CLOSE, on the os.clock() timeline (see `secondsLeft`). Derived from the
-- published schedule when there is one and carried by RoundUpdate's `secondsToLockout` when
-- there is not.
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
-- Set by a back-out, cleared when OPEN reopens. A player who withdrew has answered the
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

-- THE PUBLISHED TIMELINE. RoundScheduleConfig carries the round's absolute schedule on the
-- GetServerTimeNow clock; RoundMetronome is the pure, slew-not-snap reader of it, and this file
-- is its second consumer.
--
-- HammerController reads the SAME configuration with the SAME attribute names and the SAME
-- defaults (its `pullSchedule`) — two files reading one schedule must not disagree about what its
-- attributes are called, and this block is a deliberate mirror of that one, not an independent
-- reading. They are two literal copies today; a shared reader is worth extracting, but that is a
-- change to HammerController as well and belongs in its own diff.
--
-- WaitForChild, but OFF THE MAIN THREAD. The config folder is created by main.server.luau at
-- runtime, and this file must not hold up wiring its remote handlers waiting for it — a blocked
-- top level would miss the first RoundUpdate outright. Until the folder lands, `metronome:read`
-- returns nil and the HUD runs on RoundUpdate exactly as it did before this change.
local metronome = RoundMetronome.new()
-- OPEN's full length, published to the HUD as `aux.openSeconds` — THE RING'S DENOMINATOR.
-- The ring used to measure its own span as the largest countdown it had seen since OPEN opened,
-- because when that code was written the round's length genuinely was not on the wire. It is now
-- (`OpenSec`, below), and measuring it was wrong for every player who joined mid-round: their
-- first sample WAS the maximum, so the ring read 100% full whatever the real remainder — a player
-- arriving with 20s left saw a full ring drain over 20s. The digits were right the whole time,
-- because they print `secondsLeft` and never touch the span.
-- Stays nil until the schedule replicates; the HUD keeps the old observed-max behaviour until then.
local openSeconds: number? = nil
task.spawn(function()
    local scheduleConfig = ReplicatedStorage:WaitForChild("RoundScheduleConfig")
    local function pullSchedule()
        local strikeAt = scheduleConfig:GetAttribute("StrikeAtServerTime")
        local periodSec = scheduleConfig:GetAttribute("PeriodSec")
        if typeof(strikeAt) ~= "number" or typeof(periodSec) ~= "number" then
            return
        end
        local openSec = (scheduleConfig:GetAttribute("OpenSec") :: number?) or 51
        openSeconds = openSec
        metronome:setSchedule({
            roundId = scheduleConfig:GetAttribute("RoundId") :: string?,
            strikeAt = strikeAt,
            periodSec = periodSec,
            openSec = openSec,
            lockSec = (scheduleConfig:GetAttribute("LockSec") :: number?) or 2,
            -- Fallbacks mirror the server's DEFAULT phase durations (server/src/index.ts, now
            -- env-overridable); only used until the first schedule attributes replicate, but a
            -- stale one is a wrong schedule.
            revealSec = (scheduleConfig:GetAttribute("RevealSec") :: number?) or 7,
        }, workspace:GetServerTimeNow())
    end
    -- StrikeAtServerTime is written LAST on the server, so one changed-signal on it pulls a
    -- coherent schedule.
    scheduleConfig:GetAttributeChangedSignal("StrikeAtServerTime"):Connect(pullSchedule)
    pullSchedule()
end)

-- The ONE writer of `phase`, `localPhase` and (when the timeline has a schedule) `lockoutAt`:
-- called from the 10Hz heartbeat at the bottom of this file, and again the moment RoundUpdate
-- lands.
--
-- TWO CLOCKS MEET IN THIS FUNCTION AND THEY MUST NOT BE MIXED UP.
--   • `metronome:read` is fed `workspace:GetServerTimeNow()`, never os.clock() or tick(). The
--     schedule is published on that timeline (main.server.luau's onSchedule converts into it).
--   • `reading.lockoutIn` is a DURATION — seconds from that instant until picks close — and a
--     duration belongs to no timeline at all. That is what makes the line below safe: adding it
--     to os.clock() yields a deadline on the SAME clock `secondsLeft` subtracts from. Storing a
--     GetServerTimeNow instant in `lockoutAt` while `secondsLeft` compared against os.clock()
--     would put the countdown out by however long the machine had been up — a wrong number with
--     no visible cause. The two clocks are read one line apart, so the conversion costs nothing.
--
-- NO SCHEDULE, NO LOCAL CLOCK. `read()` returns nil until a schedule has landed: a client that
-- just joined, or one whose config never replicates. There is nothing local to fall back on and
-- inventing a start instant would be worse than the lag, so `phase` reverts to whatever
-- RoundUpdate last said and `lockoutAt` is left exactly as RoundUpdate set it — which is
-- precisely the behaviour this file had before the timeline existed.
local function refreshClock()
    local reading = metronome:read(workspace:GetServerTimeNow())
    localPhase = if reading then reading.phase else nil
    phase = localPhase or serverPhase
    if reading then
        -- Outside OPEN there is no lockout to count down to, and `lockoutAt = nil` is how this
        -- file has always said so (`timerKnown`, and the ring, both read it that way).
        lockoutAt = if reading.phase == "OPEN" then os.clock() + reading.lockoutIn else nil
    end
end

-- The clock may not have synced when OPEN opens (secondsToLockout arrives nil), and lockoutAt is
-- only ever assigned at that transition — so a nil there stays nil for the whole round. The old HUD
-- let the player throw anyway and so do we: report a nominal countdown comfortably above the
-- escalation threshold, so throws stay enabled and the alarm stays quiet. But the RING must not
-- fake a span it does not have: a constant would pin it full and motionless while throws kept
-- working past the real lockout. `timerKnown` tells the HUD to hide it instead.
local UNSYNCED_SECONDS = 30

-- ⚠ SECONDS TO THE LOCKOUT. NOT to the end of OPEN, and NOT to the end of the round. HudModel
-- spends this one number three ways — the ring's display, `throwsEnabledFor` (`secondsLeft > 0`)
-- and `sendAtLockout` (`> 0.5`) — so redefining it as anything longer leaves throws open past the
-- moment RoundCoordinator stops accepting them and fires the held pick too late to be counted.
-- That was tried on 2026-08-04 (582abfe) and reverted: every held pick was silently discarded.
--
-- The 2026-08-04 change is only that `lockoutAt` now comes from the published timeline when there
-- is one (`refreshClock`) rather than from the poll's `secondsToLockout`. The formula and the
-- meaning are untouched, and both sides of the subtraction are on os.clock().
local function secondsLeft(): number
    if phase ~= "OPEN" then
        return 0
    end
    if not lockoutAt then
        return UNSYNCED_SECONDS
    end
    return math.max(0, lockoutAt - os.clock())
end

-- SPOILER GATE. If the newest tape entry is the round `revealedRoundId` has not caught up to,
-- hold it back. Painting it early gives away the world's throw while the drum is still turning.
-- The test is unchanged by the reveal beat, but what it now holds the tile back FOR has changed:
-- `revealedRoundId` no longer advances at drum rest, it advances at the END of the beat, so this
-- is what keeps the tile off the tape while the ring's glyph has its moment.
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

-- ⚠ THROWS MAY OPEN LATE. THEY MAY NEVER OPEN EARLY.
--
-- This is the phase HudModel is handed, and it is deliberately NOT always the effective `phase`
-- the rest of the HUD runs on. `phase` comes from the published timeline, so it LEADS RoundUpdate
-- by however long the Roblox game server's 1-1.25s poll takes to notice a boundary. Leading is the
-- whole point for anything that is merely drawn. It is the wrong thing for OPENING THROWS, and the
-- reason is not on this line — it is in the RoundUpdate handler below: the poll's OPEN report is
-- ALSO what resets the round's pick state. A tap taken between the local OPEN and the server's
-- is written into `chosen`, and then `chosen = nil` a fraction of a second later. The glyph lights
-- and goes dark, nothing reaches the wire, and the player is told nothing. Nobody reports that
-- fault; everybody feels it.
--
-- So the two sources must AGREE before throws open, and disagreement fails SHUT. Losing 200ms of
-- a 51s window is invisible. A swallowed first tap is not.
--
-- THIS WILL LOOK REDUNDANT TO THE NEXT READER. `phase` is already `localPhase or serverPhase`, so
-- the eye reads "local says OPEN, therefore phase is OPEN, therefore why ask serverPhase at
-- all?" — and that reading is exactly the case being rejected. Simplifying this to `return phase`
-- restores the swallow, and no automated gate in this repo will catch it: nothing loads a
-- `.client.luau`.
--
-- ROUND IDENTITY IS CARRIED BY THE PHASE REPORT, NOT COMPARED AS AN ID. `serverPhase == "OPEN"`
-- is per-round by construction — it is set from the same RoundUpdate whose OPEN branch resets
-- this round's pick state, so agreement means that reset has already happened. Comparing round ids
-- instead would be worse: RoundScheduleConfig's RoundId is an ATTRIBUTE and RoundUpdate is a
-- RemoteEvent, and those two have no replication ordering, so the comparison would invent
-- disagreement rather than detect it (RoundMetronome's Reading carries no round id at all). And
-- "both say OPEN" cannot name two different rounds: the metronome hard re-anchors past
-- SLEW_TOLERANCE, so the timeline is never a whole period out.
--
-- IT CANNOT WITHHOLD THE HELD PICK'S ONE TRIP TO THE WIRE, and that is a property of
-- HudModel.sendAtLockout rather than a hope: for a pick that is chosen and unsent, an OPEN phase
-- returns nil while time remains, and ANY non-OPEN phase returns the pick at once. Substituting
-- non-OPEN for OPEN — the only substitution this function makes — can therefore turn a nil
-- into the pick, never the pick into a nil. The lockout send is unreachable from here. (It is not
-- moved earlier in practice either: the only window this changes is one in which the server is not
-- in OPEN, and by then the previous round's pick has already gone — `sent` is true — or there
-- never was one.)
local function throwPhase(): string
    if localPhase == "OPEN" and serverPhase ~= "OPEN" then
        -- The timeline has opened a round the server has not. Report the server's phase, so the
        -- gate stays shut until the poll catches up.
        return serverPhase
    end
    return phase
end

-- One HudModel.Inputs, built in one place. The tap handler and the lockout send both have to ask
-- the model questions about the CURRENT state, and a second hand-assembled copy of this table is
-- exactly how a field ends up set in one and forgotten in the other.
--
-- The `phase` here is `throwPhase()`, not the effective `phase` — see above. This table is also
-- what goes out on EventBus.HudState, so HudController's ring latches on the gated phase too and
-- appears when throws do rather than up to a poll ahead of them. That is a consequence, not the
-- goal; decoupling the two needs a second field on HudModel.Inputs and a HudController edit.
local function buildInputs(): any
    return {
        phase = throwPhase(),
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
        -- OPEN's full length, straight off the published schedule — the ring's denominator. nil
        -- until the schedule replicates. See the declaration above for what measuring it cost.
        openSeconds = openSeconds,
        -- The world's throw for the round the drum has FINISHED revealing, or nil. Set at drum rest
        -- and cleared once the beat's fade has run, so the ring can never spoil the wheel mid-spin
        -- and never carries a glyph into the next round either.
        worldThrow = revealedWorldThrow,
        -- The beat's hold is over and the glyph should be on its way out. Render-only: HudController
        -- owns the tween (latched on the symbol/fading pair — this republishes at 10Hz).
        worldThrowFading = worldThrowFading,
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

-- The result splash AND the new tape tile wait for the drum to stop turning (the drumRest cue),
-- so the throw is not spoiled mid-spin. The splash (SplashController) owns naming the personal
-- result now — the old toast folded the vote distribution into the same headline it built here,
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
-- THE DRUM'S OWN STALL CONDITION, MIRRORED — not guessed at. DrumController spins on for up to
-- DrumStep.STALL_MAX_SECONDS when the World Throw has not reached it by the end of the spin, and it
-- reads that throw off RevealTheater. This flag is set from the SAME remote on the SAME client (the
-- handler further down), so at the strike it says exactly what DrumController's `latestWorldThrow`
-- says — which is what lets the fallback below pick the short window instead of always padding by
-- the full stall. Cleared when OPEN reopens, matching DrumController consuming it on landing.
local worldThrowInHand = false
-- Whether this round's strike has been seen yet. Cleared when OPEN reopens; read by the
-- missed-strike backstop in the RevealResult handler.
local strikeSeen = false

local function maybeShowReveal()
    if not drumAtRest then
        return
    end
    if pendingReveal then
        local p = pendingReveal
        pendingReveal = nil
        -- Task 9: stash the round detail for the ledger's LAST ROUND band. Unconditional (not
        -- gated on `p.roundId`, unlike the tape tile's badge) so it updates for every revealed
        -- round this client sees, participant or spectator alike. Immediate, not part of the beat:
        -- the ledger is a separate screen, so there is no spoiler risk, and the rule is satisfied
        -- anyway because the drum has stopped.
        lastRound = {
            worldThrow = p.worldThrow,
            pick = p.pick,
            result = p.result,
            distribution = p.distribution,
            totalPlayers = p.totalPlayers,
        }
        -- THE BEAT STARTS HERE. The ring gets the glyph now; the TAPE TILE WAITS — see the beat
        -- block above for the timings and for why the tile's round is held in its own record.
        --
        -- `landTape()` first, defensively: nothing should be able to deliver a second reveal
        -- without an OPEN in between (which collapses the beat), but if one ever did, the round
        -- still in flight would have its record overwritten on the next line, and a dropped tile is
        -- the one failure here that never repairs itself.
        landTape()
        beatGen += 1
        local gen = beatGen
        beatInFlight = { roundId = p.roundId, result = p.result }
        revealedWorldThrow = p.worldThrow
        worldThrowFading = false
        task.delay(RevealBeat.HOLD_SECONDS, function()
            if gen ~= beatGen then
                return -- superseded: a newer beat, or a collapse, owns the ring now
            end
            worldThrowFading = true
            publish()
        end)
        task.delay(RevealBeat.TAPE_DELAY_SECONDS, function()
            if gen ~= beatGen then
                return -- superseded; the collapse has already released the tile
            end
            landTape()
            revealedWorldThrow = nil -- the glyph has finished going; the ring is a clock again
            worldThrowFading = false
            publish()
        end)
        -- Onboarding beat 3 waits for the SAME drum-rest gate the beat above starts from, not for
        -- RevealResult arriving. WIN implies the exact world throw (the one your pick beats), so firing this
        -- the instant RevealResult lands — before the drum has stopped spinning — would spoil the
        -- wheel early, exactly what the drum-rest gate exists to prevent. Fires on every WIN, not
        -- just the session's first — `resolved.win` (only set once OnboardShown confirms "shown"
        -- or "alreadySeen") is what stops the retries, so a WIN dropped for stacking gets another
        -- chance at the player's next one instead of being marked taught-forever for nothing.
        --
        -- DELIBERATELY NOT DEDUPED against the splash fired below, even though both can show on
        -- the SAME first-win tick. This is not the bank case (which grew dedup machinery because
        -- the toast and the beat said the literal same sentence in the same screen region): the
        -- splash CELEBRATES ("YOU WIN! / streak ×1 — pot is now 1") and the beat TEACHES ("You
        -- won. Take it, or ride it — a win triples your pot."), they sit in different regions, and
        -- the splash is non-Active so it steals no taps from the card. Complementary, not
        -- duplicated — do not add dedup machinery here.
        if not resolved.win and profileSeen and p.result == "WIN" then
            EventBus.Onboard:Fire("win", knownSeenBeats)
        end
        -- THE SPLASH INHERITS THIS SAME GATE rather than building a second one — it is fired here,
        -- never from RevealResult directly, so it can never land ~3s early and spoil the wheel.
        -- `p.result` is nil whenever this player had no throw counted this round (a spectator, or
        -- a whiff), so the splash cannot appear for a round the player did not throw in either.
        if p.result then
            EventBus.Splash:Fire({
                result = p.result,
                streak = wallet.currentStreak,
                pot = wallet.pointsAtStake,
                forfeited = p.forfeited,
            })
        end
        publish()
        -- The ledger reads `lastRound` from EventBus.LedgerState, not the HudState `publish()`
        -- above — without this call the panel would keep showing the PREVIOUS round's detail
        -- until the next ProfileUpdate happened to fire publishLedger() again (a bank, or this
        -- player's own next reveal), which for a spectator round might never come.
        publishLedger()
    end
end

-- RELEASE A REVEAL WHOSE `drumRest` NEVER CAME. The fallback has to exist — a dropped cue must not
-- strand a result — but its timing is the whole problem, because a fallback that fires early breaks
-- THE RULE (the drum is authoritative; nothing may reflect the world's throw until it is fully at
-- rest) on every round instead of protecting a rare one. Callers pass a window derived from the
-- choreography in DrumStep and measured from an event the drum's own timing is measured from.
--
-- The round is pinned at arming time so a stale timer can never release a NEWER round's reveal
-- early: by then `pendingReveal` is either nil (OPEN clears it) or a different round's.
local function armRevealSafety(afterSeconds: number)
    local roundId = currentRoundId
    task.delay(afterSeconds, function()
        if pendingReveal and pendingReveal.roundId == roundId then
            drumAtRest = true -- safety: never strand a result if the cue dropped
            maybeShowReveal()
        end
    end)
end

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        drumAtRest = true
        maybeShowReveal()
    elseif cue.kind == "gongHit" then
        -- THE STRIKE — the instant everything the drum does is measured from, which is why the
        -- fallback is armed HERE and not from RevealResult arriving. The world throw is decided
        -- at the END of LOCK, so a LOCK-phase fetch (RoundCoordinator's `_fetchRevealIfDue`
        -- accepts LOCK as well as REVEAL) always 404s — the reveal cannot land before the strike,
        -- only poll-jittered 0-1.25s AFTER it. A window measured from its arrival would still be
        -- measured from an event with no fixed relationship to the rest it is meant to sit behind.
        strikeSeen = true
        armRevealSafety(if worldThrowInHand then REVEAL_SAFETY else REVEAL_SAFETY_STALLED)
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
    -- The arena-wide reveal carries the World Throw, and this is the remote DrumController takes its
    -- own copy from — so noting its arrival here is exactly DrumController's stall condition, read
    -- off the same event on the same client. The reveal-safety fallback picks its window from this.
    worldThrowInHand = true
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
    -- MEASURED ON `serverPhase`, NOT on the effective `phase`. This edge is "the server's round
    -- has closed", and the effective phase is now the local timeline's, which leads the server by
    -- up to the length of its poll — so against `phase` the edge would already have passed by the
    -- time this fires and `roundEnded` would never be called at all, silently breaking the
    -- escalation's consecutive-miss backoff. `serverPhase` still holds the PREVIOUS report here.
    if serverPhase == "OPEN" and info.phase ~= "OPEN" then
        -- A STANDING CHOICE COUNTS AS PLAYED. The lockout normally sends it half a second
        -- before this fires; a choice made inside that last sliver must not be scored as an
        -- ignored round, because three of those start the escalation nagging someone who is
        -- demonstrably playing.
        roundEnded(roundCouldThrow, chosen ~= nil)
    end
    serverPhase = info.phase
    refreshClock() -- resample the timeline for this instant, so `localPhase` is current below
    -- RECONCILE, DO NOT FIGHT. The server is right about the phase it just named, so take it; the
    -- next heartbeat (one TICK, 100ms) re-reads the timeline. That is deliberately a NUDGE and not
    -- a latch: disagreement is the NORMAL state for the second a poll takes to notice a boundary —
    -- the timeline leading the remote is the entire point — so a correction that HELD until the
    -- two agreed would hand the round straight back to the poll and undo the change. Nothing here
    -- rewrites the schedule either: RoundMetronome owns the slewing that makes the two converge
    -- for real, and it already does it (setSchedule / SLEW_RATE).
    phase = info.phase
    if info.phase == "OPEN" then
        chosen = nil
        undoPrompt = nil
        undoPromptAt = nil
        sent = false
        declinedThisRound = false
        roundCouldThrow = true
        -- THE POLL'S LOCKOUT IS THE FALLBACK NOW, not the source. `localPhase == nil` is exactly
        -- "refreshClock has no schedule and will not be touching `lockoutAt`" — so this fills it
        -- in for a client whose RoundScheduleConfig has not replicated (or never does), and stays
        -- out of the way otherwise rather than overwriting the timeline's figure with a value the
        -- poll computed up to a second ago and having the next tick undo it.
        if localPhase == nil then
            lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
        end
        pendingReveal = nil -- the drum respins; last round's reveal has already been shown
        drumAtRest = false
        -- Both fallback inputs are per-round and reset with the round, matching DrumController:
        -- it consumes its own World Throw on landing, and its next strike is this round's.
        worldThrowInHand = false
        strikeSeen = false
        -- THE BEAT IS DELIBERATELY NOT COLLAPSED HERE (owner's ruling 2026-08-04, re-derived
        -- 2026-08-05 when REVEAL grew to 7s). This used to release the tape, clear the ring and
        -- invalidate the generation, on the reasoning that "the ring must not carry last round's
        -- glyph into this one" — and that reasoning cost the whole feature: against a 3s REVEAL it
        -- cut the glyph off almost the instant it appeared.
        --
        -- REVEAL is 7s now and the beat NOMINALLY FITS: rest at DrumStep.SETTLE_SECONDS 3.45, tape
        -- at 6.85, OPEN at 7.0. So a reader checking the arithmetic will find no reason for this
        -- and may delete it. THE REASON IS THE STALL. SETTLE_SECONDS is the unstalled chain only;
        -- when the World Throw is late the drum waits and rest lands past 3.45, spending the whole
        -- 0.15s of margin. Since stage 3 the throw arrives AFTER the strike rather than ~2s before
        -- it, so that is the common case — collapsing here would cut the glyph off on exactly the
        -- rounds whose timing is already worst. RevealBeat.spec pins both halves.
        --
        -- When it does run across: the glyph holds and fades over the first seconds of the new
        -- round, and the ring hands back to a countdown already part-way down. Its own
        -- `task.delay`s are wall-clock and always fire, so it completes on its own; and if a NEXT
        -- reveal ever arrived mid-beat, `maybeShowReveal` already releases the older tile
        -- defensively before overwriting the flight record, so the tape tile is still never lost.
        --
        -- `pendingReveal`, `drumAtRest` and the fallback inputs above ARE still reset — those are
        -- about the next round's gate, not about the beat that is still playing out.
    else
        lockoutAt = nil
    end
    publish()
end)

RevealResult.OnClientEvent:Connect(function(r)
    -- The revealing round == the one RoundUpdate last named (REVEAL phase). Captured to a local so
    -- the missed-strike backstop below still identifies THIS reveal even if `currentRoundId` has
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
    -- THE BACKSTOP FOR A MISSED STRIKE. The fallback is armed on `gongHit`, so a `gongHit` that
    -- never arrives arms nothing and the result would sit here until OPEN swept it away unseen.
    -- Nothing is armed if the strike has already been seen — that round's window is running and
    -- this must not undercut it. Otherwise wait out the longest a legitimate strike can still be
    -- ahead of a reveal that has already landed, and if it has STILL not arrived, take it as lost
    -- and release: a strike that never came means a drum that never spun and never will, so there
    -- is no turning drum left to spoil.
    if not strikeSeen then
        local leadSeconds = strikeLeadSeconds()
        task.delay(leadSeconds, function()
            if strikeSeen then
                return -- the strike was merely late; its own window owns this round
            end
            if pendingReveal and pendingReveal.roundId == roundId then
                drumAtRest = true
                maybeShowReveal()
            end
        end)
    end
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
        -- FIRST, before anything reads `phase` or `secondsLeft()` this tick: resample the
        -- published timeline. This loop is the phase's clock now — nothing pushes it.
        refreshClock()
        if phase == "OPEN" then
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
