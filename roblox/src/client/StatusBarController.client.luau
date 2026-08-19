--!strict
-- Two thin bars under every player's nameplate: GRADE and RANK.
--
-- ⚠ THEY ARE DIFFERENT THINGS AND THE DISTINCTION IS THE POINT (owner, 2026-08-18). Japan keeps
-- them apart and so do we:
--
--   GRADE (段位) — a count of milestones. What you have DONE. Permanent, never falls, available
--                 from a player's first evening. Everyone has one.
--   RANK  (番付) — where you stand among the qualified this week. How you are PLAYING. Volatile,
--                 and ABSENT for anyone under 360 throws rather than shown empty.
--
-- Grade counts milestones, so it measures accumulation rather than skill; rank is the one that
-- says how you are actually doing. Showing only grade would quietly present tenure as attainment,
-- which is the trap the dan/kyu naming already flirts with.
--
-- ⚠ WHY UNDER THE NAME AND NOT ON A SHOULDER. Measured in the live place: nameplates are ON
-- (NameDisplayDistance 100, DisplayDistanceType Viewer), so the space directly above every head is
-- already spoken for — but HealthDisplayType is DisplayWhenDamaged and nothing in this game does
-- damage, so the health-bar slot beneath the name is free. That is exactly where a player expects
-- a status bar, and it costs no new real estate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FamiliarRoster = remotes:WaitForChild("FamiliarRoster") :: RemoteEvent

local GRADES = 15 -- the ladder's length: 10th kyu .. 5th dan
local BAR_W, BAR_H = 62, 5
local GAP = 2
-- Sits just under the nameplate. GUESS — the plate's own offset is engine-side and not readable,
-- so this wants a look rather than arithmetic.
local DROP = 1.55
local FADE_DISTANCE = 70 -- past this the bars are unreadable anyway and just cost draw calls

local GRADE_FILL = Color3.fromRGB(214, 196, 140) -- aged ivory: permanent, quiet
local RANK_FILL = Color3.fromRGB(206, 122, 74) -- shu: volatile, warm, the one that moves
local TRACK = Color3.fromRGB(28, 26, 24)

type Bars = { gui: BillboardGui, grade: Frame, rank: Frame, rankRow: Frame }

local bars: { [string]: Bars } = {}
local roster: { [string]: any } = {}

local function build(head: BasePart): Bars
    local gui = Instance.new("BillboardGui")
    gui.Name = "RoshamboStatus"
    gui.Size = UDim2.fromOffset(BAR_W, BAR_H * 2 + GAP)
    gui.StudsOffsetWorldSpace = Vector3.new(0, DROP, 0)
    gui.AlwaysOnTop = false -- it is scenery, not a HUD: it must sit behind the world it is in
    gui.MaxDistance = FADE_DISTANCE
    gui.Parent = head

    local function row(y: number, fill: Color3): (Frame, Frame)
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, 0, 0, BAR_H)
        track.Position = UDim2.fromOffset(0, y)
        track.BackgroundColor3 = TRACK
        track.BackgroundTransparency = 0.35
        track.BorderSizePixel = 0
        track.Parent = gui
        local bar = Instance.new("Frame")
        bar.Size = UDim2.fromScale(0, 1)
        bar.BackgroundColor3 = fill
        bar.BorderSizePixel = 0
        bar.Parent = track
        return track, bar
    end

    local _, grade = row(0, GRADE_FILL)
    local rankRow, rank = row(BAR_H + GAP, RANK_FILL)
    return { gui = gui, grade = grade, rank = rank, rankRow = rankRow }
end

local function apply(userId: string)
    local b = bars[userId]
    local e = roster[userId]
    if not b then
        return
    end
    if not e then
        b.gui.Enabled = false
        return
    end
    b.gui.Enabled = workspace:GetAttribute("RoshamboStatusBars") ~= false
    local grade = tonumber(e.grade) or 0
    b.grade.Size = UDim2.fromScale(math.clamp(grade / GRADES, 0, 1), 1)

    -- RANK IS ABSENT, NOT EMPTY, when unqualified. A zero-length bar reads as "bottom of the
    -- sheet"; no bar at all reads as "not on the sheet", which is the truth.
    local rank, of = tonumber(e.rank), tonumber(e.of)
    if rank and of and of > 0 then
        b.rankRow.Visible = true
        -- 1st of 22 fills; last of 22 shows a sliver rather than nothing, so being ranked at all
        -- still reads as different from being unranked.
        local share = if of > 1 then 1 - (rank - 1) / (of - 1) else 1
        b.rank.Size = UDim2.fromScale(0.08 + 0.92 * math.clamp(share, 0, 1), 1)
    else
        b.rankRow.Visible = false
    end
end

local function attach(player: Player)
    local function onCharacter(ch: Model)
        local head = ch:WaitForChild("Head", 10) :: BasePart?
        if not head then
            return
        end
        local existing = bars[tostring(player.UserId)]
        if existing then
            existing.gui:Destroy()
        end
        bars[tostring(player.UserId)] = build(head)
        apply(tostring(player.UserId))
    end
    if player.Character then
        onCharacter(player.Character)
    end
    player.CharacterAdded:Connect(onCharacter)
end

for _, p in Players:GetPlayers() do
    attach(p)
end
Players.PlayerAdded:Connect(attach)
Players.PlayerRemoving:Connect(function(player)
    local b = bars[tostring(player.UserId)]
    if b then
        b.gui:Destroy()
        bars[tostring(player.UserId)] = nil
    end
end)

FamiliarRoster.OnClientEvent:Connect(function(next_: { [string]: any })
    roster = next_ or {}
    for userId in bars do
        apply(userId)
    end
end)

-- ===== THE PREFERENCE =====
-- Off is a legitimate taste, and a different one from the two switches beside it: those hide
-- things about YOU, this hides information about OTHER PEOPLE floating in your view. Read from a
-- Workspace attribute rather than the bus because this is a separate LocalScript with no other
-- reason to talk to main.client.luau — the same trick the Stats room's live-tuning knobs use.
--
-- ⚠ ABSENT MEANS ON, matching HudPrefs.fromProfile: no migration was run, so a player whose row
-- predates the field must see the feature rather than silently lose it.
local function applyPreference()
    local on = workspace:GetAttribute("RoshamboStatusBars") ~= false
    for _, b in bars do
        b.gui.Enabled = on
    end
end

workspace:GetAttributeChangedSignal("RoshamboStatusBars"):Connect(applyPreference)
