# Streak Aura Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a whole-body glow on any player currently riding a staked win-streak of 3 or more.

**Architecture:** three pieces, matching how `BirdFlight`/`BirdController` already split. A pure
Lune-tested module owns the thresholds and returns plain numbers; a client controller owns a pool
of `Highlight` instances and toggles `Enabled`; the server adds one field to an existing broadcast.
Streaks are derived **optimistically** on the client from the reveal everyone already receives, then
**overwritten** by the authoritative value when the roster carries it — the same optimistic-then-
reconciled pattern the familiar already uses for round results.

**Tech Stack:** Luau, Rojo, Lune test harness (`lune run tests/run`), stylua + selene.

**Spec:** `docs/superpowers/specs/2026-08-25-streak-aura-design.md`

## Global Constraints

- **TDD.** Failing test first, then implementation. Then break the code deliberately and confirm
  the right test fails — three assertions written in this repo on 2026-08-25 passed against the
  very implementations they were meant to replace, and only mutation found them.
- ⚠ **`src/shared` modules that are Lune-tested MUST NAME NO ROBLOX TYPE.** No `Color3`, no
  `Vector3`, no `CFrame`, no `Instance`. `Kamon` broke the entire test run at require time by
  taking a `Color3`; the renderer had to be split into `KamonDraw`. `StreakAura` returns numbers
  only; the controller converts.
- ⚠ **Client-side only for anything the player must SEE.** Server-built parts are subject to
  `StreamingEnabled` and may never reach the screen. `Workspace.Familiars` does not exist on the
  server at all, which is why familiars work.
- ⚠ **Never create/destroy `Highlight`s per state change.** Measured 2026-08-25: create 50 =
  3.09 ms, destroy 50 = 0.49 ms, toggle 100 `Enabled` flips = 0.12 ms. Roblox rebuilds geometry on
  add/remove. Pool per player; toggle thereafter.
- ⚠ **The Highlight cap is 255 per client and overflow is SILENT** — 300 were created in the live
  place with zero warnings. One per present player stays far inside it; do not adorn anything else.
- **Colour is never the primary channel.** Fill transparency first, outline second, colour last.
  Kid-first on phones; colourblind players must not lose the signal.
- Run `stylua --check src tests tools && selene src tools` before every commit. selene fails on
  warnings.

---

### Task 1: `StreakAura` — the pure threshold module

**Files:**
- Create: `roblox/src/shared/StreakAura.luau`
- Test: `roblox/tests/StreakAura.spec.luau`

**Interfaces:**
- Produces: `StreakAura.MIN_STREAK: number`, `StreakAura.visible(streak: number): boolean`,
  `StreakAura.poseFor(streak: number): (number, number, number)` returning
  `(fillTransparency, outlineTransparency, heat)` where `heat` is 0..1 and the CONTROLLER maps it
  to a colour. All three returns are plain numbers — see the Global Constraint on Roblox types.

- [ ] **Step 1: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local StreakAura = require("../src/shared/StreakAura")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("StreakAura", function()
    test("nothing glows below the floor -- a common streak is noise, not a flex", function()
        -- ⚠ Roughly a third of players win any given round, so a 1- or 2-streak is ordinary. The
        -- whole reason an aura works where a worn banner did not is that it is RARE: a 3-streak is
        -- about 1 in 27. Lower the floor and it becomes the thing it was meant to avoid.
        for s = -3, StreakAura.MIN_STREAK - 1 do
            expect(StreakAura.visible(s)).toBe(false)
        end
        expect(StreakAura.visible(StreakAura.MIN_STREAK)).toBe(true)
        expect(StreakAura.visible(99)).toBe(true)
    end)

    test("a deeper streak glows HARDER, and never inverts", function()
        local prevFill, prevOutline = 2, 2
        for s = StreakAura.MIN_STREAK, 12 do
            local fill, outline, heat = StreakAura.poseFor(s)
            expect(fill <= prevFill).toBe(true) -- transparency FALLS as the streak deepens
            expect(outline <= prevOutline).toBe(true)
            expect(heat >= 0 and heat <= 1).toBe(true)
            prevFill, prevOutline = fill, outline
        end
    end)

    test("the glow SATURATES rather than running away", function()
        -- A 12-streak and a 30-streak look the same. Without this an improbable run would white
        -- out the screen for everyone near it.
        local f12, o12, h12 = StreakAura.poseFor(12)
        local f30, o30, h30 = StreakAura.poseFor(30)
        expect(f12).toBe(f30)
        expect(o12).toBe(o30)
        expect(h12).toBe(h30)
        expect(h12).toBe(1)
    end)

    test("every value stays inside the range Roblox will accept", function()
        for s = -5, 40 do
            local fill, outline, heat = StreakAura.poseFor(s)
            expect(fill >= 0 and fill <= 1).toBe(true)
            expect(outline >= 0 and outline <= 1).toBe(true)
            expect(heat >= 0 and heat <= 1).toBe(true)
        end
    end)

    test("below the floor the pose is FULLY transparent, not merely faint", function()
        -- The controller also gates on visible(), but a pose that leaked a faint glow would make
        -- the two disagree, and the failure would look like a rendering bug rather than a rule.
        local fill, outline = StreakAura.poseFor(0)
        expect(fill).toBe(1)
        expect(outline).toBe(1)
    end)
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd roblox && lune run tests/run`
Expected: 5 failures, all `attempt to index nil` / `attempt to call a nil value` — the module does
not exist yet.

- [ ] **Step 3: Write the module**

```lua
--!strict
-- How hard a player glows for the win-streak they currently have MONEY ON.
--
-- ⚠ PURE, AND IT NAMES NO ROBLOX TYPE. This file is Lune-tested, and a `Color3` here breaks the
-- entire test run at require time -- that is exactly what happened to `Kamon`, whose renderer had
-- to be split out into `KamonDraw`. `heat` is a number; the controller turns it into a colour.
--
-- ⚠ RARITY IS THE DESIGN. About a third of players win any given round, so a 3-streak is roughly
-- 1 in 27 and a 5-streak 1 in 240: the arena is dark most of the time and the glow is scarce
-- exactly when it is impressive. A worn banner failed because everyone wore one at once. Lowering
-- MIN_STREAK turns this back into that.
local StreakAura = {}

StreakAura.MIN_STREAK = 3
local SATURATE_AT = 8 -- a 12-streak and a 30-streak look the same

-- Endpoints, floor -> saturated. Fill carries the signal; outline supports it; heat is decoration.
local FILL_NEAR, FILL_FAR = 0.85, 0.55
local OUTLINE_NEAR, OUTLINE_FAR = 0.6, 0.15

function StreakAura.visible(streak: number): boolean
    return streak >= StreakAura.MIN_STREAK
end

-- Fill transparency, outline transparency, and heat (0..1) for a streak.
function StreakAura.poseFor(streak: number): (number, number, number)
    if not StreakAura.visible(streak) then
        return 1, 1, 0
    end
    local span = math.max(1, SATURATE_AT - StreakAura.MIN_STREAK)
    local heat = math.clamp((streak - StreakAura.MIN_STREAK) / span, 0, 1)
    return FILL_NEAR + (FILL_FAR - FILL_NEAR) * heat,
        OUTLINE_NEAR + (OUTLINE_FAR - OUTLINE_NEAR) * heat,
        heat
end

return StreakAura
```

- [ ] **Step 4: Run the tests**

Run: `cd roblox && lune run tests/run`
Expected: all pass.

- [ ] **Step 5: Mutate, to prove the tests bite**

Make each change, run the suite, confirm at least one test fails, then revert:
1. `StreakAura.MIN_STREAK = 1` → the rarity test must fail.
2. Delete the `SATURATE_AT` clamp (use the raw ratio) → the saturation test must fail.
3. Swap `FILL_NEAR`/`FILL_FAR` → the monotonic test must fail.

- [ ] **Step 6: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/src/shared/StreakAura.luau roblox/tests/StreakAura.spec.luau
git commit -m "feat(roblox): StreakAura — how hard a staked streak glows"
```

---

### Task 2: put `stakingStreak` on the familiar roster

**Files:**
- Modify: `roblox/src/server/main.server.luau` (roster writes at ~508, ~890; reconciliation at ~455)

**Interfaces:**
- Consumes: `row.streak` from `onReconciled`, `res.data.stakingStreak` from the join call.
- Produces: `familiarRoster[userId].stakingStreak: number?` — absent means "not known yet", which
  the client treats as 0.

⚠ **Why this is authoritative-but-late, and why that is acceptable here.** `onReconciled` fires on
the NEXT round's OPEN, so the roster's streak trails reality by one round. Task 3 covers the gap
optimistically. Do not try to close it by making the aura wait for the roster — a glow that lingers
a round after a loss is a lie, and worse than one that starts a beat late.

- [ ] **Step 1: Add the field at join**

In the `familiarRoster[tostring(player.UserId)] = { ... }` literal near line 508, add:

```lua
                stakingStreak = res.data.stakingStreak,
```

- [ ] **Step 2: Update it on reconciliation**

Inside `onReconciled`, after the existing `profiles:applyServer(...)` call and before
`local player = playerByUserId(row.robloxUserId)`, add:

```lua
                -- The roster is what every client sees of every OTHER player, so the aura needs
                -- the streak here rather than on the per-player profile. Merge, never replace:
                -- the entry also carries grade/gradeName/band/rank set elsewhere.
                local rosterEntry = familiarRoster[row.robloxUserId]
                if rosterEntry then
                    rosterEntry.stakingStreak = row.streak
                end
```

Then, after the `for` loop that walks `rows` and before `end,` closing `onReconciled`, add a single
broadcast:

```lua
            -- ONE push for the whole batch. Pushing inside the loop sends the full roster once per
            -- reconciled player, which at fifty players is fifty broadcasts of the same table.
            pushFamiliarRoster()
```

- [ ] **Step 3: Verify by inspection in a running place**

Start Play. In the command bar (**Client** context — server-side reads will not show what a client
sees), run:

```lua
local r = game:GetService("ReplicatedStorage").RoshamboRemotes.FamiliarRoster
print("watching roster for stakingStreak…")
r.OnClientEvent:Connect(function(t)
    for uid, e in t do
        print(uid, "grade=", e.grade, "stakingStreak=", e.stakingStreak)
    end
end)
```

Expected: after the first reconciliation, entries carry a `stakingStreak` number.
⚠ Both environments run `TEST_MODE`, so the World Throw cycles R→P→S — a streak is achievable by
picking the winner of the cycle, which is the easiest way to produce a non-zero value to look at.

- [ ] **Step 4: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): the roster carries stakingStreak, so clients can see each other's runs"
```

---

### Task 3: `AuraController` — the pooled glow

**Files:**
- Create: `roblox/src/client/AuraController.client.luau`

**Interfaces:**
- Consumes: `StreakAura.visible`, `StreakAura.poseFor`, the `FamiliarRoster` RemoteEvent
  (`stakingStreak`), and the `RevealTheater` RemoteEvent (`results`, a map of userId →
  `{ pick, result }`).
- Produces: nothing other pieces read.

⚠ **No Rojo change is needed.** `src/client` maps to
`StarterPlayer.StarterPlayerScripts.RoshamboClient`, so a new `.client.luau` file inside it syncs
on save. A `rojo serve` restart is only required for new entries in `default.project.json`.

- [ ] **Step 1: Write the controller**

```lua
--!strict
-- A whole-body glow for a player riding a STAKED win streak.
--
-- ⚠ WHY THIS AND NOT A BADGE. Four worn answers were rejected before this one: plumage on the
-- familiar (too small to read at arena distance), the worn sashimono ("a bit on the nose for an
-- experience meant to be social"), a HUD sashimono (the martial read is in the SHAPE, so it
-- follows), and any worn crest at all -- a Chinese-themed area is planned and the AVATAR TRAVELS,
-- so nothing on a body may be culturally specific. A glow is culture-neutral and, crucially, RARE:
-- about a third of players win a round, so a 3-streak is ~1 in 27. The arena is dark most of the
-- time, which is the axis the banner failed on.
--
-- ⚠ POOLED, NEVER CHURNED. Measured 2026-08-25: creating 50 Highlights costs 3.09 ms and destroying
-- 50 costs 0.49 ms, while 100 `Enabled` flips cost 0.12 ms -- Roblox rebuilds geometry on add and
-- remove. Every SAFE and every LOSS ends a streak, so this toggles constantly by nature.
--
-- ⚠ The Highlight cap is 255 per client and overflow is SILENT (300 created in the live place, zero
-- warnings). One per present player stays far inside it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local StreakAura = require(shared:WaitForChild("StreakAura"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FamiliarRoster = remotes:WaitForChild("FamiliarRoster") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

-- Amber at the floor, hot at saturation. Colour is the THIRD channel: fill carries the signal,
-- outline supports it, and a colourblind player must still read the aura from those two alone.
local HUE_COOL, HUE_HOT = 0.11, 0.02

type Row = { highlight: Highlight, streak: number }
local rows: { [number]: Row } = {}

local function apply(row: Row)
    local h = row.highlight
    if not StreakAura.visible(row.streak) then
        h.Enabled = false
        return
    end
    local fill, outline, heat = StreakAura.poseFor(row.streak)
    h.FillTransparency = fill
    h.OutlineTransparency = outline
    h.FillColor = Color3.fromHSV(HUE_COOL + (HUE_HOT - HUE_COOL) * heat, 0.85, 1)
    h.OutlineColor = h.FillColor
    h.Enabled = true
end

local function rowFor(player: Player): Row
    local existing = rows[player.UserId]
    if existing then
        return existing
    end
    local h = Instance.new("Highlight")
    h.Name = "StreakAura"
    h.DepthMode = Enum.HighlightDepthMode.Occluded -- a wall should hide it, like any world effect
    h.Enabled = false
    h.Parent = ReplicatedStorage -- reparented to the character below; never left un-adorned
    local row: Row = { highlight = h, streak = 0 }
    rows[player.UserId] = row
    return row
end

local function adorn(player: Player, character: Model)
    local row = rowFor(player)
    row.highlight.Adornee = character
    row.highlight.Parent = character
    apply(row)
end

local function track(player: Player)
    if player.Character then
        adorn(player, player.Character)
    end
    -- ⚠ A RESPAWN REPLACES THE CHARACTER and orphans the adornee, leaving a glow on a corpse.
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
        row.highlight:Destroy() -- ⚠ a Highlight outside Workspace STILL counts toward the cap
        rows[player.UserId] = nil
    end
end)

-- AUTHORITATIVE. Trails reality by a round (reconciliation lands on the next OPEN), so the reveal
-- handler below runs ahead of it and this corrects.
FamiliarRoster.OnClientEvent:Connect(function(roster: { [string]: any })
    for _, player in Players:GetPlayers() do
        local entry = roster and roster[tostring(player.UserId)]
        if entry and type(entry.stakingStreak) == "number" then
            local row = rowFor(player)
            row.streak = entry.stakingStreak
            apply(row)
        end
    end
end)

-- OPTIMISTIC. `RevealTheater` already carries every player's result, so the glow can react on the
-- same beat as the reveal instead of a round later.
--
-- ⚠ IT CANNOT SEE BANKING. Banking resets stakingStreak and is not in this payload, so a player who
-- banks keeps glowing until the next reconciliation corrects them -- one round of over-glow, and
-- the deliberate price of not lingering a round after a LOSS, which would be a lie.
RevealTheater.OnClientEvent:Connect(function(payload: any)
    local results = payload and payload.results
    if type(results) ~= "table" then
        return
    end
    for _, player in Players:GetPlayers() do
        local mine = results[tostring(player.UserId)]
        if mine then
            local row = rowFor(player)
            row.streak = if mine.result == "WIN" then row.streak + 1 else 0
            apply(row)
        end
    end
end)
```

- [ ] **Step 2: Verify it renders, and that the pool does not churn**

Start Play. In the command bar (**Client** context), run:

```lua
local n, enabled = 0, 0
for _, d in workspace:GetDescendants() do
    if d:IsA("Highlight") and d.Name == "StreakAura" then
        n += 1
        if d.Enabled then enabled += 1 end
    end
end
print(("StreakAura highlights: %d, enabled: %d"):format(n, enabled))
```

Expected: `n` equals the number of present players and does **not** grow as rounds pass — that is
the pool doing its job. `enabled` is 0 until someone reaches a 3-streak.

- [ ] **Step 3: Force a glow without waiting for a real streak**

```lua
for _, d in workspace:GetDescendants() do
    if d:IsA("Highlight") and d.Name == "StreakAura" then
        d.FillTransparency, d.OutlineTransparency, d.Enabled = 0.55, 0.15, true
    end
end
```

This is the saturated end of the range. Look at it on an avatar and judge whether the endpoints
need moving — the numbers in `StreakAura` are a starting point to argue down, not a spec.

- [ ] **Step 4: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run
git add roblox/src/client/AuraController.client.luau
git commit -m "feat(roblox): a staked streak makes you glow"
```

---

### Task 4: owner gate, then record it

**Files:**
- Modify: `docs/wiki/world/familiars.md` (or a new `docs/wiki/world/status-display.md` if the
  section outgrows the familiar page — grade, unlocks and auras are one system and the familiar
  page is already long)
- Modify: `docs/wiki/log.md`
- Modify: `docs/wiki/program/friends-family-baseline.md` — item 6

- [ ] **Step 1: Put it in front of the owner**

⚠ Do NOT record an as-built before this. Show it, take the verdict, and treat the thresholds as
opening positions. Specific things to ask about, because they are the ones most likely to be wrong:
the floor of 3, the saturated endpoints, and whether the glow fights the familiar's own WIN
reaction (the bird rises on a win; the aura is a different clock, and they may or may not read as
one thing).

- [ ] **Step 2: Record the outcome**

Follow `docs/wiki/schema.md`: as-built on `world/`, chronology in `log.md`, status only under
`program/`. Supersede rather than append. If the owner rejects it, that is a `drop` entry naming
the reason — the reason is what stops it being re-proposed, as the sashimono chain shows.

- [ ] **Step 3: Commit and push**

```bash
node tools/wiki/lint.mjs   # expect 0 errors
git add docs/wiki && git commit -m "docs(wiki): the streak aura, gated"
git push origin main
```

## Notes for whoever executes this

- **`TEST_MODE` makes streaks fake.** Both environments run the deterministic R→P→S cycle, so a
  streak rewards memorising the cycle rather than reading the crowd. Useful for producing a glow to
  look at; useless as evidence the signal means anything.
- **Performance at fifty players is unmeasured.** The cap is fine and toggling is cheap; the cost of
  ~10 simultaneously enabled Highlights on the A13 is not known. If the aura ships and the floor is
  later lowered, measure first.
- **The leader halo is out of scope and deferred on correctness, not effort** — it would crown
  whoever tops a board that still ranks on points-per-throw behind a floor derived for win rate.
  See the spec's Out of Scope section.
