# Perch Favoriting Implementation Plan (sub-project D, increment 5.2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player favorite/un-favorite a perch in-world via a walk-up ProximityPrompt, persisting the choice through D.5.1's `PUT /preferences` so the next join sends them to their top available favorite.

**Architecture:** A pure `PreferenceEditor.togglePreference` helper (Lune-tested); a `NetworkClient:setPreferences` PUT (Lune-tested); two new RemoteEvents (`SetPadPreference` client→server, `PreferenceState` server→client); server-side per-player prefs cache + toggle handler in `main.server`; a new client `PerchPreferenceController` that puts a prompt on every materialized perch and shows a label flip + toast. No server schema change (D.5.1's `padPreferences` model suffices).

**Tech Stack:** Luau `--!strict`; Lune bespoke harness (`tests/`, auto-discovers `*.spec.luau`); Rojo (`default.project.json` owns the remotes + `src/` tree); stylua + selene gates. Local server on Atlas `roshambo-dev`.

**Spec:** `docs/superpowers/specs/2026-07-07-roshambo-perch-favoriting-design.md` (commit `39088d3`).

## Global Constraints

- **Prefer-only, no schema change.** Favoriting appends a `siteId` to `padPreferences`; un-favoriting removes it. The server route + validator (`≤32` entries) already exist from D.5.1 — do not add server fields.
- **Client-created prompts.** Prompts are made on each client (per-player labels), never on the server.
- **Favoriting affects the next join only** — no live re-assignment mid-session.
- **Cap = 32**, matching D.5.1's `validatePadPreferences`. `togglePreference` takes the cap as a parameter; `main.server` passes `32`.
- **Prompt label strings (exact):** favorited → `♥ Favorited ✓`; not favorited → `♡ Favorite this perch`.
- **Persist-failure safety:** if the `setPreferences` PUT fails, roll the server cache back and echo the unchanged list to the client (no toast) so client and server never diverge.
- **stylua + selene stay green** (`stylua --check src tests tools` + `selene src tools`; selene fails on warnings too).
- **Commit trailers** on every commit:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ
  ```

---

### Task 1: `PreferenceEditor.togglePreference` (pure, Lune-tested)

**Files:**
- Create: `roblox/src/shared/PreferenceEditor.luau`
- Test: `roblox/tests/PreferenceEditor.spec.luau`

**Interfaces:**
- Produces: `PreferenceEditor.togglePreference(list: {string}, siteId: string, maxEntries: number) -> ({string}, boolean)` — returns `(newList, favorited)`.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/PreferenceEditor.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local PreferenceEditor = require("../src/shared/PreferenceEditor")
local describe, test, expect = harness.describe, harness.test, harness.expect
local toggle = PreferenceEditor.togglePreference

describe("PreferenceEditor.togglePreference", function()
    test("appends an absent site (favorited=true), order preserved", function()
        local out, fav = toggle({ "T02" }, "T06", 32)
        expect(#out).toBe(2)
        expect(out[1]).toBe("T02")
        expect(out[2]).toBe("T06")
        expect(fav).toBe(true)
    end)

    test("removes a present site (favorited=false), order preserved", function()
        local out, fav = toggle({ "T02", "T06", "T04" }, "T06", 32)
        expect(#out).toBe(2)
        expect(out[1]).toBe("T02")
        expect(out[2]).toBe("T04")
        expect(fav).toBe(false)
    end)

    test("appended lists do not duplicate; toggling again removes", function()
        local out = toggle({ "T02" }, "T06", 32)
        local out2, fav2 = toggle(out, "T02", 32) -- T02 present -> removed
        expect(#out2).toBe(1)
        expect(out2[1]).toBe("T06")
        expect(fav2).toBe(false)
    end)

    test("at the cap, adding a new site is a no-op (favorited=false)", function()
        local full = {}
        for i = 1, 32 do
            full[i] = "S" .. i
        end
        local out, fav = toggle(full, "NEW", 32)
        expect(#out).toBe(32)
        expect(fav).toBe(false)
    end)

    test("removing works even when at the cap", function()
        local full = {}
        for i = 1, 32 do
            full[i] = "S" .. i
        end
        local out, fav = toggle(full, "S1", 32)
        expect(#out).toBe(31)
        expect(fav).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run (from `roblox/`): `lune run tests/run`
Expected: FAIL — `PreferenceEditor` module doesn't exist.

- [ ] **Step 3: Implement the helper**

Create `roblox/src/shared/PreferenceEditor.luau`:

```lua
--!strict
-- Pure list editor for a player's ordered perch preference (padPreferences).
-- Favoriting appends a siteId (deduped, capped); un-favoriting removes it. No Roblox
-- types -> Lune-tested. The server persists the result via NetworkClient:setPreferences.
local PreferenceEditor = {}

-- Returns (newList, favorited). siteId present -> removed (favorited=false).
-- siteId absent -> appended, deduped (favorited=true), unless already at maxEntries
-- (then the original list is returned unchanged, favorited=false).
function PreferenceEditor.togglePreference(
    list: { string },
    siteId: string,
    maxEntries: number
): ({ string }, boolean)
    local out: { string } = {}
    local found = false
    for _, id in list do
        if id == siteId then
            found = true
        else
            table.insert(out, id)
        end
    end
    if found then
        return out, false
    end
    if #out >= maxEntries then
        return list, false
    end
    table.insert(out, siteId)
    return out, true
end

return PreferenceEditor
```

- [ ] **Step 4: Run the test to verify it passes**

Run (from `roblox/`): `lune run tests/run`
Expected: PASS (all 5 new tests + the full existing suite).

- [ ] **Step 5: Lint**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: no diffs, no errors/warnings.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/PreferenceEditor.luau roblox/tests/PreferenceEditor.spec.luau
git commit -m "feat(roblox): pure PreferenceEditor.togglePreference (sub-project D, increment 5.2)"
```

---

### Task 2: `NetworkClient:setPreferences` (Lune-tested)

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau` (add method after `getTeahouses`, before `return NetworkClient`)
- Test: `roblox/tests/NetworkClient.spec.luau` (add a `describe` block)

**Interfaces:**
- Consumes: the existing `_request(self, method, path, bodyTable?)`.
- Produces: `NetworkClient:setPreferences(robloxUserId: string, padPreferences: {string}) -> Result` → `PUT /api/v1/players/{id}/preferences` with body `{ padPreferences = padPreferences }`.

- [ ] **Step 1: Write the failing test**

Add to `roblox/tests/NetworkClient.spec.luau` (it already has `makeDeps`, `CONFIG`, `serde`, `describe/test/expect`):

```lua
describe("NetworkClient.setPreferences", function()
    test("PUTs the list to /preferences and returns the echo", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"padPreferences":["T06"]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setPreferences("9", { "T06" })
        expect(res.ok).toBe(true)
        expect(res.data.padPreferences[1]).toBe("T06")
        expect(f.calls[1].method).toBe("PUT")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/preferences")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.padPreferences[1]).toBe("T06")
    end)

    test("surfaces a 400 BAD_REQUEST fail-fast", function()
        local f = makeDeps({ { ok = true, statusCode = 400, body = '{"error":"BAD_REQUEST"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setPreferences("9", { "T06" })
        expect(res.ok).toBe(false)
        expect(res.error).toBe("BAD_REQUEST")
        expect(#f.calls).toBe(1)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run (from `roblox/`): `lune run tests/run`
Expected: FAIL — `setPreferences` is nil.

- [ ] **Step 3: Implement the method**

In `roblox/src/server/NetworkClient.luau`, add after `getTeahouses` (line ~130):

```lua
function NetworkClient.setPreferences(self: any, robloxUserId: string, padPreferences: { string }): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/preferences`, { padPreferences = padPreferences })
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run (from `roblox/`): `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(roblox): NetworkClient:setPreferences PUT (sub-project D, increment 5.2)"
```

---

### Task 3: Remotes contract + perch display names

**Files:**
- Modify: `roblox/default.project.json` (add two RemoteEvents to `RoshamboRemotes`)
- Modify: `roblox/src/server/PadSites.luau` (add `displayName` per site)

**Interfaces:**
- Produces: `RoshamboRemotes.SetPadPreference` (RemoteEvent), `RoshamboRemotes.PreferenceState` (RemoteEvent); `PadSites[id].displayName: string?`.

- [ ] **Step 1: Add the remotes**

In `roblox/default.project.json`, the `RoshamboRemotes` block currently ends:
```json
                "BoardData": { "$className": "RemoteEvent" }
```
Change it to add the two new events (note the comma after `BoardData`):
```json
                "BoardData": { "$className": "RemoteEvent" },
                "SetPadPreference": { "$className": "RemoteEvent" },
                "PreferenceState": { "$className": "RemoteEvent" }
```

- [ ] **Step 2: Add display names to `PadSites`**

In `roblox/src/server/PadSites.luau`, add a `displayName` field to each of the three site tables. Insert it right after the `id` line for each:
- `T02` → `displayName = "Overlook",`
- `T06` → `displayName = "Mossy Prow",`
- `T04` → `displayName = "Creekside",`

Example for T02:
```lua
    ["T02"] = {
        id = "T02",
        displayName = "Overlook",
        mountCF = { -142.2818, 173.0035, 70.2984, 0.9754, 0, 0.2204, 0, 1, 0, -0.2204, 0, 0.9754 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
```

- [ ] **Step 3: Validate JSON + lint**

Run (from `roblox/`):
```bash
node -e "JSON.parse(require('fs').readFileSync('default.project.json','utf8')); console.log('json ok')"
stylua src tests && stylua --check src tests tools && selene src tools
```
Expected: `json ok`; lint clean.

- [ ] **Step 4: Commit**

```bash
git add roblox/default.project.json roblox/src/server/PadSites.luau
git commit -m "feat(roblox): SetPadPreference/PreferenceState remotes + perch displayNames (sub-project D, increment 5.2)"
```

---

### Task 4: Server wiring — prefs cache, join push, toggle handler

**Files:**
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `PreferenceEditor.togglePreference` (Task 1), `net:setPreferences` (Task 2), the two remotes + `PadSites[id].displayName` (Task 3), the existing `PadSites`, `net`, and the D.5 `PlayerAdded`/`PlayerRemoving` handlers.
- Produces: at join, a `PreferenceState` push to the joining client; on `SetPadPreference`, a toggle + persist + `PreferenceState` echo. Studio-runtime — no Lune test; proven by the Task 6 gate.

- [ ] **Step 1: Add requires + remote refs**

In `roblox/src/server/main.server.luau`, after the existing shared requires (near line 17), add:
```lua
local PreferenceEditor = require(shared:WaitForChild("PreferenceEditor"))
```
After the `BoardData` remote line (line 27), add:
```lua
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent
```

- [ ] **Step 2: Add the per-player prefs cache**

Immediately before the D.5 `local siteCoordinator = SiteCoordinator.new(...)` line (~362), add:
```lua
local playerPrefs: { [string]: { string } } = {}
local PREF_CAP = 32
```

- [ ] **Step 3: Cache prefs + push `PreferenceState` at join**

In the D.5 `PlayerAdded` handler (the `task.spawn` block at ~384), replace the body from `local prefs = ...` through the end of the `if action then ... end` with:
```lua
        local prefs = if res.ok then res.data.padPreferences else nil
        local uid = tostring(player.UserId)
        playerPrefs[uid] = prefs or {}
        local action = siteCoordinator:onJoin(uid, owned, prefs)
        if action then
            -- getTeahouses yields; if the player left mid-call, PlayerRemoving's onLeave
            -- already ran as a no-op (nothing was held yet). Release the just-claimed pad
            -- so it doesn't leak lit for a departed player (and _held doesn't go stale).
            if not player:IsDescendantOf(Players) then
                local rel = siteCoordinator:onLeave(uid)
                if rel then
                    applier:apply(rel.padId, rel.spec, rel.treatment, rel.scale, rel.footprint)
                end
                playerPrefs[uid] = nil
                return
            end
            applier:apply(action.padId, action.spec, action.treatment, action.scale, action.footprint)
            print(`[D.5] {player.UserId} claimed {action.padId} @ {tostring(action.sizeClass)}`)
        end
        if player:IsDescendantOf(Players) then
            PreferenceState:FireClient(player, { padPreferences = playerPrefs[uid] })
        end
```

- [ ] **Step 4: Add the `SetPadPreference` handler**

After the D.5 `PlayerRemoving` handler (the block ending at ~414), add:
```lua
SetPadPreference.OnServerEvent:Connect(function(player, siteId)
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
            PreferenceState:FireClient(player, { padPreferences = current }) -- revert client, no toast
        end
        return
    end
    if player:IsDescendantOf(Players) then
        PreferenceState:FireClient(player, {
            padPreferences = newList,
            changed = siteId,
            favorited = favorited,
            name = PadSites[siteId].displayName or siteId,
        })
    end
end)
```

- [ ] **Step 5: Clean up the cache on leave**

In the existing D.5 `PlayerRemoving` handler (~408), add `playerPrefs[tostring(player.UserId)] = nil` as the first line inside the connect callback (before `local action = siteCoordinator:onLeave(...)`).

- [ ] **Step 6: Lint (Studio-only file; the linter is the local gate)**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): server prefs cache + SetPadPreference toggle/persist + PreferenceState push (sub-project D, increment 5.2)"
```

---

### Task 5: Client `PerchPreferenceController`

**Files:**
- Create: `roblox/src/client/PerchPreferenceController.client.luau`

**Interfaces:**
- Consumes: `RoshamboRemotes.SetPadPreference` / `PreferenceState` (Task 3), the server folders `workspace.TeahouseSites.MaterializedSite_<siteId>` (built by the applier), and the server pushes from Task 4.
- Produces: a per-perch `ProximityPrompt` labeled per-player, a toast banner, and `SetPadPreference` fires on trigger. Studio-runtime — no Lune test; proven by the Task 6 gate.

- [ ] **Step 1: Create the controller**

Create `roblox/src/client/PerchPreferenceController.client.luau`:

```lua
--!strict
-- Per-player perch favoriting. Puts a ProximityPrompt on every materialized teahouse
-- (workspace.TeahouseSites.MaterializedSite_<siteId>), labeled from this player's
-- padPreferences (pushed via PreferenceState). Triggering toggles the favorite:
-- SetPadPreference -> server persists -> PreferenceState echo -> label flip + toast.
-- Favoriting affects the NEXT join's assignment, not the current session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent

local FAV_LABEL = "♥ Favorited ✓"
local UNFAV_LABEL = "♡ Favorite this perch"

local favored: { [string]: boolean } = {} -- siteId -> favorited
local prompts: { [string]: ProximityPrompt } = {} -- siteId -> its prompt

local function labelFor(siteId: string): string
    return if favored[siteId] then FAV_LABEL else UNFAV_LABEL
end

local function refreshPrompts()
    for siteId, prompt in prompts do
        prompt.ActionText = labelFor(siteId)
    end
end

-- Transient toast banner.
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "PerchToast"
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.Parent = player:WaitForChild("PlayerGui")

local function showToast(text: string)
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 0.08, 0)
    label.Size = UDim2.new(0, 520, 0, 44)
    label.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
    label.BackgroundTransparency = 0.15
    label.TextColor3 = Color3.fromRGB(240, 228, 205)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Text = text
    label.Parent = toastGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label
    task.spawn(function()
        task.wait(2.5)
        local fade = TweenService:Create(label, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 })
        fade:Play()
        fade.Completed:Wait()
        label:Destroy()
    end)
end

local function anchorPart(structure: Instance): BasePart?
    if structure:IsA("Model") and structure.PrimaryPart then
        return structure.PrimaryPart
    end
    local deck = structure:FindFirstChild("Deck", true)
    if deck and deck:IsA("BasePart") then
        return deck
    end
    return structure:FindFirstChildWhichIsA("BasePart", true)
end

local function ensurePrompt(folder: Instance)
    local siteId = folder.Name:match("^MaterializedSite_(.+)$")
    if not siteId or prompts[siteId] then
        return
    end
    task.spawn(function()
        local structure = folder:WaitForChild("Structure", 15)
        if not structure then
            return
        end
        local anchor = anchorPart(structure)
        if not anchor then
            return
        end
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = labelFor(siteId)
        prompt.ObjectText = "Perch"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.MaxActivationDistance = 16
        prompt.RequiresLineOfSight = false
        prompt.Parent = anchor
        prompt.Triggered:Connect(function()
            SetPadPreference:FireServer(siteId)
        end)
        prompts[siteId] = prompt
    end)
end

local sitesFolder = workspace:WaitForChild("TeahouseSites")
for _, f in sitesFolder:GetChildren() do
    ensurePrompt(f)
end
sitesFolder.ChildAdded:Connect(ensurePrompt)

PreferenceState.OnClientEvent:Connect(function(payload)
    favored = {}
    for _, id in payload.padPreferences do
        favored[id] = true
    end
    refreshPrompts()
    if payload.changed then
        local name = payload.name or payload.changed
        if payload.favorited then
            showToast(`★ {name} favorited — you'll spawn here next time it's free`)
        else
            showToast(`{name} removed from favorites`)
        end
    end
end)
```

- [ ] **Step 2: Lint**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: no diffs, no errors/warnings.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/client/PerchPreferenceController.client.luau
git commit -m "feat(roblox): PerchPreferenceController prompts + toast (sub-project D, increment 5.2)"
```

---

### Task 6: Studio gate (visual, against Atlas `roshambo-dev`)

**Files:** none committed (gate only).

**Interfaces:** consumes everything above. One attempt, then stop for user review.

- [ ] **Step 1: Bring the local server up (Atlas `roshambo-dev`)**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26 && docker compose up -d --build server
docker logs roshambo-server 2>&1 | grep "Target Database"   # expect …/roshambo-dev
```

- [ ] **Step 2: Sync the new files + remotes into the place**

The new client/shared/server scripts and the two remotes live in the Rojo tree (`src/` + `default.project.json`), so a Rojo sync brings them into the place. Have the user run `rojo serve` (from `roblox/`) and Connect the Rojo plugin in Studio, or rebuild the place. Confirm `ReplicatedStorage.RoshamboRemotes.SetPadPreference` and `PreferenceState` exist and `StarterPlayerScripts.RoshamboClient.PerchPreferenceController` is present.

- [ ] **Step 3: Favorite a perch and observe the flip + toast**

Enter Play. Position the character near a materialized perch (walk, or teleport the character via MCP `execute_luau` to just outside a `MaterializedSite_*` structure). Approach → the ProximityPrompt reads `♡ Favorite this perch`. Trigger it (hold E). Expected: label flips to `♥ Favorited ✓`, and a toast reads `★ <name> favorited — you'll spawn here next time it's free`. Server console shows no `setPreferences failed` warning.

- [ ] **Step 4: Confirm persistence in `roshambo-dev`**

```bash
KEY=$(grep -m1 '^API_KEY=' server/.env | cut -d= -f2-)
curl -s "localhost:3001/api/v1/players/<UserId>/teahouses" -H "X-API-Key: $KEY"; echo
# expect padPreferences to now contain the favorited siteId
```

- [ ] **Step 5: Un-favorite (toggle back)**

Trigger the same prompt again → label returns to `♡ Favorite this perch`, toast reads `<name> removed from favorites`, and the curl from Step 4 shows the siteId gone.

- [ ] **Step 6: Close the loop with D.5.1 assignment**

Re-favorite the perch. Seed the player to own a size that fits it (via `PUT /teahouses/<size>` if not already), then stop + re-enter Play. Expected server console: `[D.5] <UserId> claimed <favorited siteId> @ <size>` — the favorited perch is chosen on join.

- [ ] **Step 7: Stop and hand off**

One attempt at the gate, then STOP and ask the user to review (per working preferences — do not self-judge and iterate). Report the flip/toast, the persistence curl, and the assignment line.

---

## Self-Review

**1. Spec coverage:** toggle helper (T1) ✓; `setPreferences` (T2) ✓; remotes + displayName (T3) ✓; server cache/handler/push (T4) ✓; client prompts + toast (T5) ✓; gate (T6) ✓. No server schema change (correct — prefer-only).

**2. Placeholder scan:** `<UserId>`, `<name>`, `<size>`, `<favorited siteId>` are runtime/per-run values with named sources, not gaps.

**3. Type/name consistency:** `togglePreference(list, siteId, maxEntries) -> (newList, favorited)` used identically in T1 and T4; `PREF_CAP = 32` matches the D.5.1 validator; the `PreferenceState` payload shape (`padPreferences` always; `changed`/`favorited`/`name` on echo) is produced in T4 and consumed in T5 field-for-field; prompt label strings (`♥ Favorited ✓` / `♡ Favorite this perch`) are identical in T5 and the Global Constraints; folder name pattern `MaterializedSite_<siteId>` matches the applier's `MaterializedSite_ .. padId`.

**4. Persist-failure path** (T4) rolls back the cache and echoes the unchanged list with no `changed` field, so T5 shows no toast and labels stay correct — client/server never diverge.

## Execution Handoff

**"Plan complete and saved to `docs/superpowers/plans/2026-07-07-roshambo-perch-favoriting.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh implementer per task, review between tasks. Tasks 1–2 are Lune-TDD; 3–5 are lint-gated Studio code; 6 is the visual gate I run.

**2. Inline Execution** — tasks in this session with checkpoints.

**Which approach?"**
