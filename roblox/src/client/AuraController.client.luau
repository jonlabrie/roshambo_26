--!strict
-- A whole-body glow for a player on a run of consecutive wins.
--
-- ⚠ WHY THIS AND NOT A BADGE. Four worn answers were rejected before it: plumage on the familiar
-- (too small to read at arena distance), the worn sashimono ("a bit on the nose for an experience
-- meant to be social"), a HUD sashimono (the martial read is in the SHAPE, so it follows the banner
-- wherever it goes), and any worn crest at all -- a Chinese-themed area is planned and the AVATAR
-- TRAVELS, so nothing on a body may be culturally specific. A glow is culture-neutral and, crucially,
-- RARE: about a third of players win a round, so a 3-streak is ~1 in 27. The arena is dark most of
-- the time, which is exactly the axis the banner failed on.
--
-- ⚠ POOLED, NEVER CHURNED. Measured 2026-08-25: creating 50 Highlights costs 3.09 ms and destroying
-- 50 costs 0.49 ms, while 100 `Enabled` flips cost 0.12 ms -- Roblox rebuilds geometry on add and
-- remove. Every SAFE and every LOSS ends a streak, so this toggles constantly by nature.
--
-- ⚠ The Highlight cap is 255 per client and overflow is SILENT (300 created in the live place, zero
-- warnings). One per present player stays far inside it. A Highlight parked OUTSIDE Workspace still
-- counts, so leavers are destroyed rather than stashed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local StreakAura = require(shared:WaitForChild("StreakAura"))
local HudPrefs = require(shared:WaitForChild("HudPrefs"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FamiliarRoster = remotes:WaitForChild("FamiliarRoster") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent

local LOCAL = Players.LocalPlayer

-- Amber at the floor, hot at saturation. ⚠ Colour is the THIRD channel -- fill carries the signal
-- and outline supports it, so a colourblind player reads the aura from those two alone.
local HUE_COOL, HUE_HOT = 0.11, 0.02

type Row = {
    highlight: Highlight,
    attachment: Attachment?,
    emitter: ParticleEmitter?,
    emberPending: boolean,
    streak: number,
    visibility: string,
}

local rows: { [number]: Row } = {}
-- The VIEWER's own preference. Absent means on, matching HudPrefs everywhere else.
local viewerWantsAuras = true

-- ⚠ `IsFriendsWith` IS A YIELDING WEB CALL. Called per frame, or per round for fifty players, it
-- would hammer the friends endpoint and stall the client. Resolved ONCE per subject and cached for
-- the session; an in-flight or failed lookup counts as NOT a friend, because failing closed is the
-- only correct direction for a privacy gate.
local friendCache: { [number]: boolean } = {}
local friendPending: { [number]: boolean } = {}

local function isFriend(userId: number): boolean
    if LOCAL and userId == LOCAL.UserId then
        return true
    end
    local known = friendCache[userId]
    if known ~= nil then
        return known
    end
    if not friendPending[userId] then
        friendPending[userId] = true
        task.spawn(function()
            local ok, result = pcall(function()
                return LOCAL:IsFriendsWith(userId)
            end)
            friendCache[userId] = ok and result == true
            friendPending[userId] = nil
        end)
    end
    return false -- fail closed while the lookup is in flight
end

-- Forward-declared: `apply` self-heals a missing emitter by calling this, and this in turn calls
-- `apply` once the wait resolves. Neither can come first.
local attachEmbers: (Player, Model) -> ()

local function apply(userId: number, row: Row)
    local h = row.highlight
    local show = StreakAura.shows({
        streak = row.streak,
        visibility = row.visibility,
        isSelf = LOCAL ~= nil and userId == LOCAL.UserId,
        isFriend = isFriend(userId),
        viewerWantsAuras = viewerWantsAuras,
        force = nil, -- ⚠ no caller sets this yet; see the note at the foot of this file
    })
    if not show then
        h.Enabled = false
        if row.emitter then
            row.emitter.Enabled = false
        end
        return
    end
    local fill, outline, heat = StreakAura.poseFor(row.streak)
    local tint = Color3.fromHSV(HUE_COOL + (HUE_HOT - HUE_COOL) * heat, 0.85, 1)
    h.FillTransparency = fill
    -- ⚠ THE RIM PULSES, and its TEMPO carries the streak. Brightness cannot be read off a lone
    -- player -- the owner could not tell the levels apart in the singular -- but a beat can be
    -- counted. `pulse` returns 0..1, and a fainter rim is a HIGHER transparency, so it subtracts.
    local beat = StreakAura.pulse(os.clock(), row.streak)
    h.OutlineTransparency = math.clamp(outline - (1 - outline) * 0.45 * beat, 0, 1)
    h.FillColor = tint
    h.OutlineColor = tint
    h.Enabled = true

    -- ⚠ THE PARTICLES ARE THE SIGNAL NOW. A Highlight alone read as an editor selection washing the
    -- avatar out ("not very compelling", owner) -- and rate is countable where transparency is not.
    --
    -- ⚠ SELF-HEALING, because losing the emitter loses the whole effect silently. If the row is lit
    -- and has no emitter, ask again -- the character may have finished loading after the first
    -- attempt, or been replaced by a respawn mid-wait. Guarded by `emberPending`, so a lit row asks
    -- once rather than spawning a waiter every frame.
    local emitter = row.emitter
    if not emitter then
        local character = row.highlight.Adornee
        if character and character:IsA("Model") then
            attachEmbers(Players:GetPlayerByUserId(userId) or LOCAL, character)
        end
    end
    if emitter then
        emitter.Rate = StreakAura.emitRate(row.streak)
        emitter.Color = ColorSequence.new(tint)
        emitter.Enabled = true
    end
end

local function rowFor(player: Player): Row
    local existing = rows[player.UserId]
    if existing then
        return existing
    end
    local h = Instance.new("Highlight")
    h.Name = "StreakAura"
    -- Occluded, not AlwaysOnTop: a wall should hide it, like any other thing in the world. An
    -- always-visible glow through geometry would be a wallhack for "who is winning".
    h.DepthMode = Enum.HighlightDepthMode.Occluded
    h.Enabled = false
    local row: Row = {
        highlight = h,
        attachment = nil,
        emitter = nil,
        emberPending = false,
        streak = 0,
        visibility = StreakAura.VISIBILITY.PUBLIC,
    }
    rows[player.UserId] = row
    return row
end

-- ⚠ POOLED LIKE THE HIGHLIGHT, for the same measured reason: toggling `Enabled` is far cheaper
-- than creating, and a streak ends on every SAFE and every LOSS. The emitter rides an Attachment on
-- the root part so it follows the avatar without parenting anything to a limb that may be swapped.
local function buildEmitter(): ParticleEmitter
    local e = Instance.new("ParticleEmitter")
    e.Name = "StreakAuraEmbers"
    -- No Texture set: the engine default always exists, where a hardcoded rbxasset id is a guess
    -- that fails silently as an invisible emitter.
    e.Rate = 0
    e.Lifetime = NumberRange.new(0.9, 1.5)
    e.Speed = NumberRange.new(3, 6)
    -- ⚠ WIDE. A narrow cone from a single point is a thin jet, not an aura. This fans the embers
    -- out around the legs so they rise past the whole silhouette.
    e.SpreadAngle = Vector2.new(55, 55)
    e.EmissionDirection = Enum.NormalId.Top
    e.Acceleration = Vector3.new(0, 8, 0) -- embers RISE; falling ones would read as damage
    -- ⚠ LOCKED TO THE PART. Without this, particles are left in WORLD space: a walking player
    -- strews them behind and the effect reads as exhaust rather than as an aura that is theirs.
    -- Owner saw exactly that -- "emitting from the avatar's ass".
    e.LockedToPart = true
    -- ⚠ THREE TIMES THE ORIGINAL SIZE. At 0.18 they were invisible at any distance a player
    -- actually stands ("particles are small", owner).
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(0.6, 0.35),
        NumberSequenceKeypoint.new(1, 0),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.LightEmission = 0.85
    e.Enabled = false
    return e
end

-- ⚠ EMIT FROM THE FEET, NOT FROM INSIDE THE TORSO, and this is the whole bug the owner reported.
-- The first version sat the attachment at HumanoidRootPart + (0, -0.5, 0) -- which is INSIDE the
-- body -- so particles spawned occluded by the avatar's own geometry. Standing still they were
-- invisible; walking left them behind, which is why they looked like they came from behind and
-- below. Measured per character rather than hardcoded: `HipHeight` is the distance from the root
-- part's BOTTOM to the ground, and it differs across R6, R15 and scaled bodies.
local function footOffset(character: Model): number
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not root then
        return -3
    end
    local hip = if humanoid then humanoid.HipHeight else 2
    return -(root.Size.Y / 2 + hip) + 0.15 -- a touch above the ground, not buried in it
end

-- ⚠ `CharacterAdded` FIRES BEFORE THE PARTS ARE ALL THERE, and this cost the whole particle
-- effect. The Highlight adorns the MODEL, so it attached fine and looked like everything worked --
-- but the emitter needs `HumanoidRootPart`, a plain `FindFirstChild` returned nil, the `if` was
-- silently skipped, and nothing ever retried. Result: an aura that lit but never emitted a single
-- particle (owner, 2026-08-26: "no particles at all"). Waiting is the fix, and it must be off the
-- caller's thread because `adorn` runs from a signal handler and from the startup sweep.
function attachEmbers(player: Player, character: Model)
    local existing = rows[player.UserId]
    if existing and existing.emberPending then
        return -- one waiter at a time; the self-heal below can ask on any frame
    end
    if existing then
        existing.emberPending = true
    end
    task.spawn(function()
        local root = character:WaitForChild("HumanoidRootPart", 15) :: BasePart?
        local row = rows[player.UserId]
        if row then
            row.emberPending = false
        end
        -- the character may have been replaced, or the player left, while we waited
        if not root or not row or row.highlight.Adornee ~= character then
            return
        end
        local a = row.attachment or Instance.new("Attachment")
        a.Name = "StreakAuraOrigin"
        a.Position = Vector3.new(0, footOffset(character), 0)
        a.Parent = root
        local e = row.emitter or buildEmitter()
        e.Parent = a
        row.attachment, row.emitter = a, e
        apply(player.UserId, row) -- re-apply: the row may already be lit and waiting for an emitter
    end)
end

local function adorn(player: Player, character: Model)
    local row = rowFor(player)
    row.highlight.Adornee = character
    row.highlight.Parent = character
    attachEmbers(player, character)
    apply(player.UserId, row)
end

local function track(player: Player)
    if player.Character then
        adorn(player, player.Character)
    end
    -- ⚠ A RESPAWN REPLACES THE CHARACTER and orphans the adornee, leaving a glow on nothing.
    player.CharacterAdded:Connect(function(character)
        adorn(player, character)
    end)
end

for _, p in Players:GetPlayers() do
    track(p)
end
Players.PlayerAdded:Connect(track)

Players.PlayerRemoving:Connect(function(player)
    local row = rows[player.UserId]
    if row then
        row.highlight:Destroy() -- ⚠ a Highlight outside Workspace STILL counts toward the 255 cap
        if row.emitter then
            row.emitter:Destroy()
        end
        if row.attachment then
            row.attachment:Destroy()
        end
        rows[player.UserId] = nil
    end
    friendCache[player.UserId] = nil
    friendPending[player.UserId] = nil
end)

local function refreshAll()
    for _, player in Players:GetPlayers() do
        local row = rows[player.UserId]
        if row then
            apply(player.UserId, row)
        end
    end
end

-- The VIEWER's own switch. `statusBars` is the existing "do not draw other people's status over
-- their heads on MY screen" preference, and an aura is that same kind of thing, so it rides it
-- rather than inventing a second control for the same intent.
-- ⚠ THE PAYLOAD IS FLAT. `fireProfile` fires the profile fields at the top level, NOT nested under
-- a `data` key the way the HTTP responses it is built from are. Reading `payload.data` here would
-- have silently never matched, and the viewer's off-switch would simply never have worked.
ProfileUpdate.OnClientEvent:Connect(function(payload: any)
    if type(payload) ~= "table" then
        return
    end
    viewerWantsAuras = HudPrefs.fromProfile(payload).statusBars
    refreshAll()
end)

-- AUTHORITATIVE. Trails reality by a round -- reconciliation lands on the next OPEN -- so the
-- reveal handler below runs ahead of it and this corrects.
FamiliarRoster.OnClientEvent:Connect(function(roster: { [string]: any })
    if type(roster) ~= "table" then
        return
    end
    for _, player in Players:GetPlayers() do
        local entry = roster[tostring(player.UserId)]
        if entry then
            local row = rowFor(player)
            if type(entry.currentStreak) == "number" then
                row.streak = entry.currentStreak
            end
            if StreakAura.isVisibility(entry.auraVisibility) then
                row.visibility = entry.auraVisibility
            end
            apply(player.UserId, row)
        end
    end
end)

-- OPTIMISTIC. `RevealTheater` already carries every player's result, so the glow reacts on the same
-- beat as the reveal instead of a round later.
--
-- ⚠ AND IT NO LONGER NEEDS TO SEE BANKING. The aura tracks currentStreak, which a bank does not
-- reset -- so the optimistic value (increment on WIN, zero on anything else) and the authoritative
-- one now agree on what they mean. Under the old stakingStreak reading, a banker over-glowed for a
-- round; that whole discrepancy is gone with the metric it came from.
RevealTheater.OnClientEvent:Connect(function(payload: any)
    local results = if type(payload) == "table" then payload.results else nil
    if type(results) ~= "table" then
        return
    end
    for _, player in Players:GetPlayers() do
        local mine = results[tostring(player.UserId)]
        if type(mine) == "table" then
            local row = rowFor(player)
            row.streak = if mine.result == "WIN" then row.streak + 1 else 0
            apply(player.UserId, row)
        end
    end
end)

-- ⚠ NOTHING SETS `force` YET, AND THAT IS DELIBERATE. `StreakAura.shows` accepts HIDE, SHOW and
-- SHOW_EVEN_IF_HIDDEN, and the rules are written and tested -- but the POLICY (which moments earn
-- an override) is the owner's to set, and inventing one here would be inventing a moment nobody
-- asked for. The obvious first use is a client-side HIDE cap when too many players glow at once on
-- a phone; the number that should trigger it is unmeasured. See the plan's amendment.

-- ⚠ THE PULSE NEEDS A CLOCK, and this loop is the only per-frame cost in the file. It re-applies
-- only rows whose glow is currently on, and does nothing at all when the arena is dark -- which,
-- even with the floor at 2, is most of the time.
RunService.Heartbeat:Connect(function()
    for _, player in Players:GetPlayers() do
        local row = rows[player.UserId]
        if row and row.highlight.Enabled then
            apply(player.UserId, row)
        end
    end
end)
