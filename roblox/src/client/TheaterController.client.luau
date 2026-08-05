--!strict
-- Executes choreography cues: builds the cue schedule from RevealTheater and
-- phase changes, fires them onto the EventBus, and plays the simple
-- placeholder consequence effects (petals, umbrella). Fates are handled by
-- FateController; UI toasts by main.client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Choreo = require(shared:WaitForChild("ChoreographyMachine"))
local DrumStep = require(shared:WaitForChild("DrumStep"))
local EffectRegistry = require(shared:WaitForChild("EffectRegistry"))
local EffectSelector = require(shared:WaitForChild("EffectSelector"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local selector = EffectSelector.new(EffectRegistry, { random = math.random })

local function characterOf(userId: string): Model?
    for _, p in Players:GetPlayers() do
        if tostring(p.UserId) == userId then
            return p.Character
        end
    end
    return nil
end

local function petals(character: Model)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 217, 138))
    emitter.Lifetime = NumberRange.new(1, 1.8)
    emitter.Speed = NumberRange.new(4, 7)
    emitter.Rate = 0
    emitter.Parent = head
    emitter:Emit(30)
    task.delay(2.5, function()
        emitter:Destroy()
    end)
end

local function umbrella(character: Model)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end
    local canopy = Instance.new("Part")
    canopy.Shape = Enum.PartType.Cylinder
    canopy.Anchored = true
    canopy.CanCollide = false
    canopy.Color = Color3.fromRGB(179, 74, 58)
    canopy.Size = Vector3.new(0.4, 0.5, 0.5)
    canopy.CFrame = head.CFrame * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90))
    canopy.Parent = workspace
    TweenService:Create(canopy, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.new(0.4, 6, 6) })
        :Play()
    task.delay(2, function()
        TweenService
            :Create(canopy, TweenInfo.new(0.3), { Size = Vector3.new(0.4, 0.5, 0.5), Transparency = 1 })
            :Play()
        task.delay(0.35, function()
            canopy:Destroy()
        end)
    end)
end

local function execute(cue: any)
    EventBus.Cue:Fire(cue)
    if cue.kind == "consequence" then
        local character = characterOf(cue.userId)
        if not character then
            return
        end
        if cue.effect == "growPetals" then
            petals(character) -- the grow itself is server-side (replicated scale)
        elseif cue.effect == "umbrellaPop" then
            umbrella(character)
        end
        -- fate* effects are consumed by FateController via the same Cue event
    end
end

-- ===== THE DRUM-REST GATE =====
-- RevealTheater lands about three seconds BEFORE the throw drum finishes turning, so scheduling the
-- choreography off its arrival gave the round away while the wheel was still spinning: the petals
-- (and the server's avatar grow alongside them) fired on a player whose result was not yet on the
-- drum. main.client.luau and LanternController already hold their reveal and paint on the `drumRest`
-- cue (fired by DrumController when the glide settles); this is the same treatment.
--
-- The cue offsets stay RELATIVE — `Choreo.revealCues` returns `atMs` measured from the start of the
-- choreography, and the schedule is built at flush time so the whole sequence simply starts later
-- with its internal timing intact. Building it early and subtracting would have been the way to
-- shift it.

-- THE SAFETY THAT COVERS A DROPPED `drumRest`, and why its timing is not a local literal any more.
-- It used to be `REVEAL_SAFETY = 3`, armed from RevealTheater ARRIVING — the same defect
-- main.client.luau carried, in the same shape, for the same reason: 3 is unrelated to the
-- choreography (the drum rests DrumStep.SETTLE_SECONDS = 3.45s after the STRIKE) and RevealTheater's
-- arrival is unrelated to the strike (the reveal can land a whole tally before it, because
-- RoundCoordinator:_fetchRevealIfDue accepts TALLY as well as REVEAL). Instrumented on the HUD side,
-- the equivalent timer won on three consecutive rounds — so this safety has been routinely firing
-- the petals and the umbrella while the drum was still gliding onto its detent, which is the exact
-- spoiler the gate above exists to prevent.
--
-- It is armed from `gongHit` now and sized from DrumStep, so the numbers derive from the
-- choreography in ONE place rather than being re-guessed per file. The tracking below is
-- deliberately a duplicate of main.client.luau's rather than a new shared client module — read that
-- file's version alongside this one; if a third consumer ever wants it, THEN extract it.
local pendingReveal: any = nil
local drumAtRest = false
-- This round's strike, `os.clock()` at `gongHit`, nil until it lands. Doubles as "has the strike
-- been seen", which the missed-strike backstop reads. Cleared when ACTIVE reopens.
local strikeAt: number? = nil
-- Was the World Throw still missing when the strike landed? That is DrumController's stall
-- condition, and this file receives RevealTheater — the very remote that controller takes its throw
-- from — so this is its state read off the same event, not a guess at it. Conservative by a hair:
-- DrumController does not actually commit to stalling until the end of the spin, so a throw that
-- lands just after the strike is treated as a stall here and merely widens the window.
local strikeStalled = false
-- Slack on top of the strike's own lead, covering the client's phase-poll lag. Only ever makes the
-- missed-strike backstop LATER, never earlier.
local STRIKE_LEAD_SLACK = 1
-- How far ahead of a reveal that has ALREADY arrived a legitimate `gongHit` can still be: the strike
-- is scheduled TallySec after ACTIVE ends, with `gongHit` at the END of the shu-moku's swing. Read
-- off the live schedule so a server retune of TALLY carries — FindFirstChild, never WaitForChild,
-- so this controller cannot hang on the arena's config folder. (Mirrors main.client.luau.)
local function strikeLeadSeconds(): number
    local cfg = ReplicatedStorage:FindFirstChild("RoundScheduleConfig")
    local tally = if cfg then cfg:GetAttribute("TallySec") else nil
    return (if typeof(tally) == "number" then tally else 2)
        + DrumStep.STRIKE_SWING_SECONDS
        + STRIKE_LEAD_SLACK
end

local function runReveal(reveal: any)
    local cues = Choreo.revealCues(reveal, {
        staggerMaxMs = 600,
        random = math.random,
        selectEffect = function(slot, ctx)
            return selector:select(slot, ctx)
        end,
    })
    for _, cue in cues do
        task.delay(cue.atMs / 1000, execute, cue)
    end
end

local function maybeRunReveal()
    if pendingReveal and drumAtRest then
        local reveal = pendingReveal
        pendingReveal = nil
        runReveal(reveal)
    end
end

-- CHOREOGRAPHY THAT NEVER PLAYS IS WORSE THAN CHOREOGRAPHY THAT PLAYS EARLY — but early is what was
-- actually happening, so this arms behind the drum instead of ahead of it. Called from BOTH the
-- strike and the reveal, and arms only once both are in hand: the strike gives it a clock the drum's
-- own timing is measured from, and the reveal gives it the payload IDENTITY to compare against, so
-- an older round's timer can never flush a newer round's choreography. Whichever arrives second does
-- the arming; the first call is a no-op.
local function armSafety()
    local reveal = pendingReveal
    local t0 = strikeAt
    if not reveal or not t0 then
        return
    end
    local window = if strikeStalled
        then DrumStep.SAFETY_AFTER_STRIKE_STALLED_SECONDS
        else DrumStep.SAFETY_AFTER_STRIKE_SECONDS
    -- Measured from the strike, not from now: a reveal that lands after the strike has already
    -- burned part of the window, and re-starting the clock here would push the safety out by
    -- however late it was.
    task.delay(math.max(0, t0 + window - os.clock()), function()
        if pendingReveal == reveal then
            drumAtRest = true
            maybeRunReveal()
        end
    end)
end

RoundUpdate.OnClientEvent:Connect(function(info)
    for _, kind in Choreo.phaseCues(info.phase) do
        EventBus.Cue:Fire({ kind = kind })
    end
    if info.phase == "ACTIVE" then
        -- The drum respins for the new round, so last round's rest no longer counts as this one's,
        -- and this round's strike has not landed yet.
        --
        -- `pendingReveal` is STILL deliberately not cleared here, but the old reason for it has
        -- gone: it used to be that REVEAL was ~3s and so was the safety, so this boundary and that
        -- timer raced. The safety no longer runs on a REVEAL-length clock — it runs from the strike,
        -- normally landing ~6.4s into a 7s gap, comfortably inside it. What survives is the
        -- STALLED window: when the World Throw is late the drum itself does not rest until after
        -- this boundary, so the safety cannot either, and clearing here would drop that round's
        -- choreography outright. Late is the tradeoff this file has always chosen over never.
        drumAtRest = false
        strikeAt = nil
        strikeStalled = false
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        drumAtRest = true
        maybeRunReveal()
    elseif cue.kind == "gongHit" then
        -- THE STRIKE. Everything the drum does is measured from here, which is why the safety is
        -- too. Whether the drum can stall is decided by whether its World Throw is already in hand
        -- at this instant — and `pendingReveal` holds exactly the payload that carries it.
        strikeAt = os.clock()
        strikeStalled = pendingReveal == nil
        armSafety()
    end
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    pendingReveal = reveal
    maybeRunReveal() -- only runs if the drum has already settled
    armSafety() -- a no-op if the strike has not landed yet; that call will arm it
    -- THE BACKSTOP FOR A MISSED STRIKE. The safety is armed on `gongHit`, so a `gongHit` that never
    -- arrives arms nothing and the choreography never plays — the one outcome this file rates worse
    -- than playing it early. Nothing is armed if the strike has already been seen, so this cannot
    -- undercut the window that is running. Otherwise wait out the longest a legitimate strike can
    -- still be ahead of a reveal that has already landed, and if it has STILL not arrived, take it
    -- as lost and run: a strike that never came means a drum that never spun and never will, so
    -- there is no turning drum left to spoil. Same IDENTITY comparison as before, so an older
    -- round's timer never flushes a newer round's payload.
    if not strikeAt then
        task.delay(strikeLeadSeconds(), function()
            if strikeAt then
                return -- the strike was merely late; its own window owns this round
            end
            if pendingReveal == reveal then
                drumAtRest = true
                maybeRunReveal()
            end
        end)
    end
end)
