### Task 5: Playback in the game server — extract the launch helpers, add `RequestShowGo`

**Files:**
- Modify: `roblox/default.project.json` (the `RoshamboRemotes` block, next to `RequestProvingFire`)
- Modify: `roblox/src/server/main.server.luau` (the `RequestFireworkLaunch` handler ~1545–1655 and new code beside it)

No Lune test can load `main.server.luau`; this task is verified in Studio (Step 6) and its pure parts were tested in Tasks 2–3. **Refactor behaviour-preservingly**: the single-shell path must produce byte-identical payloads after the extraction.

**Interfaces:**
- Consumes: `ShowPlan.validate/DECK_SLOTS/knownShellSet`, `ShowPlayer.schedule/timeline/delaysFrom`, `net:postShowReserve`, existing `deckSiteFor`, `muzzleOriginFor`, `LaunchSites.isValid`, `MortarPlacement.SHELL_MORTAR`, `BoostLuck`, `handlerQueue`, `pushFireworkState`, `FireworkCatalog`.
- Produces:
  - RemoteEvent `RequestShowGo` (client → server): `(show: { stageId, fuel, cues, title? })`
  - three local helpers in `main.server.luau`: `rollBoost(uid, shellId): boolean?`, `broadcastLaunch(fields)`, `playShow(stageKey: string, ownerUid: string, byLabel: string, cues, originFor: (cue) -> (Vector3?, Vector3?, number?), showId: string)`

- [ ] **Step 1: Add the remotes**

In `roblox/default.project.json`, after `"RequestProvingFire": { "$className": "RemoteEvent" },` add:

```json
                "RequestShowGo": { "$className": "RemoteEvent" },
                "RequestProvingShow": { "$className": "RemoteEvent" },
```

(`RequestProvingShow` is wired in Task 6; declaring both now keeps the contract edit in one place.)

- [ ] **Step 2: Extract the boost roll and the broadcast from the single-shell handler**

In `main.server.luau`, immediately above `RequestFireworkLaunch.OnServerEvent:Connect(...)`, add:

```lua
-- THE PITY RAMP, shared by every launch path (owner, 2026-09-06; math in BoostLuck): roll this
-- shell's luck against a per-player per-shell miss streak and return the VERDICT. Streaks are
-- session-lived by design. Extracted 2026-09 so a show's cues get the same bounded drought as a
-- hand launch — a show is not a way around the ramp, nor a way to be cheated by it.
local function rollBoost(uid: string, shellId: string): boolean?
    local baseChance = BoostLuck.baseChance(FireworkCatalog.RECIPES[shellId])
    if not baseChance then
        return nil
    end
    local streaks = boostMisses[uid] or {}
    boostMisses[uid] = streaks
    local verdict, newMisses = BoostLuck.roll(baseChance, streaks[shellId] or 0, math.random())
    streaks[shellId] = newMisses
    return verdict
end

-- ONE broadcast shape for every path (hand launch, proving, shows). `showId` is additive; clients
-- that do not know it ignore it. Field types are the contract FireworkController checks.
local function broadcastLaunch(fields: {
    shellId: string,
    origin: Vector3,
    heading: Vector3?,
    by: string,
    boosted: boolean?,
    apexHeight: number?,
    showId: string?,
})
    FireworkLaunched:FireAllClients({
        shellId = fields.shellId,
        origin = fields.origin,
        heading = fields.heading and { x = fields.heading.X, y = fields.heading.Y, z = fields.heading.Z } or nil,
        seed = math.random(1, 2 ^ 31 - 1),
        by = fields.by,
        boosted = fields.boosted,
        apexHeight = fields.apexHeight,
        showId = fields.showId,
    })
end
```

Then, inside the existing `RequestFireworkLaunch` handler, replace the pity-ramp block and the `FireworkLaunched:FireAllClients({...})` call with:

```lua
        local boosted = rollBoost(uid, shellId)
        broadcastLaunch({
            shellId = shellId,
            origin = origin,
            heading = heading,
            by = uid,
            boosted = boosted,
            apexHeight = publicApex,
        })
```

Nothing else in that handler changes. (The `heading` variable there is already a `Vector3?`; `publicApex` a `number?`.)

- [ ] **Step 3: Add the runner and the `RequestShowGo` handler**

Directly below the `RequestFireworkLaunch` handler, add:

```lua
-- ===== SHOWS (spec 2026-09-05-fireworks-show-system-design §2) =====
-- The server owns playback: a reserved show plays to the end on the server's clock whether or
-- not its owner is still here, and every client sees the same cues at the same moments. One show
-- per stage at a time; a second go on a busy stage queues behind it (ShowPlayer.schedule).
local RequestShowGo = remotes:WaitForChild("RequestShowGo") :: RemoteEvent
local ShowPlan = require(shared:WaitForChild("ShowPlan"))
local ShowPlayer = require(shared:WaitForChild("ShowPlayer"))
-- Every shell the client can draw: the catalogue's recipe keys (there is no separate id list on
-- this side; the fixture test asserts RECIPES covers every server id).
local KNOWN_SHELLS: { [string]: boolean } = {}
for id in FireworkCatalog.RECIPES do
    KNOWN_SHELLS[id] = true
end

local stageBusyUntilMs: { [string]: number } = {}

local function nowMs(): number
    return os.clock() * 1000
end

-- Play `cues` on `stageKey`. `originFor(cue)` resolves a cue's slot to (origin, heading, apex) at
-- FIRE time; a nil origin skips that cue with a warning rather than firing from nowhere.
local function playShow(
    stageKey: string,
    ownerUid: string,
    byLabel: string,
    cues: { ShowPlan.Cue },
    originFor: (ShowPlan.Cue) -> (Vector3?, Vector3?, number?),
    showId: string
)
    local sched = ShowPlayer.schedule(stageBusyUntilMs[stageKey], nowMs(), cues)
    stageBusyUntilMs[stageKey] = sched.endAtMs
    local timeline = ShowPlayer.timeline(cues, sched.startAtMs)
    local delays = ShowPlayer.delaysFrom(nowMs(), timeline)
    print(`[SHOW] {showId} on {stageKey} by {byLabel}: {#cues} cues, starts in {math.floor(delays[1] * 10) / 10}s`)
    for i, entry in timeline do
        task.delay(delays[i], function()
            local origin, heading, apex = originFor(entry.cue)
            if origin == nil then
                warn(`[SHOW] {showId} cue {entry.index} ({entry.cue.shellId} @ {entry.cue.slot}) had no origin; skipped`)
                return
            end
            broadcastLaunch({
                shellId = entry.cue.shellId,
                origin = origin,
                heading = heading,
                by = byLabel,
                boosted = rollBoost(ownerUid, entry.cue.shellId),
                apexHeight = apex,
                showId = showId,
            })
        end)
    end
end

-- A player's show from their OWN deck: validate (same rule the backend applies), reserve (debit
-- everything or nothing), then play. Origins are resolved per cue at fire time from the deck's
-- mortar placements; a hand cue launches from where the player stood when they pressed go, so a
-- show outlives the player walking away.
RequestShowGo.OnServerEvent:Connect(function(player, show)
    if typeof(show) ~= "table" or typeof(show.cues) ~= "table" then
        return
    end
    local uid = tostring(player.UserId)
    handlerQueue:run(uid, function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root then
            return
        end
        local deck = deckSiteFor(uid)
        if deck == nil then
            return -- no deck, no stage (the client should not have offered go)
        end
        local pos = root.Position
        if not LaunchSites.isValid({ x = pos.X, y = pos.Y, z = pos.Z }, { deck }, uid) then
            return
        end
        local check = ShowPlan.validate(show.cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, KNOWN_SHELLS)
        if not check.ok then
            warn(`[SHOW] {uid} rejected: {check.error} cue {tostring(check.cue)}`)
            return
        end
        local body = { stageId = `deck:{uid}`, fuel = "inventory", cues = show.cues, title = show.title }
        local res = net:postShowReserve(uid, body)
        if not res.ok then
            -- Result carries `status` and `error` (and `data` when the body parsed) -- see NetworkClient.Result.
            warn(`[SHOW] {uid} reserve failed: {tostring(res.status)} {tostring(res.error)} {tostring(res.data and res.data.error)}`)
            if pushFireworkState then
                pushFireworkState(player)
            end
            return
        end
        if pushFireworkState then
            pushFireworkState(player) -- their counts just dropped by the whole show
        end
        local showId = tostring((res.data and res.data.reservationId) or `local-{math.random(1, 1e9)}`)
        local handFrame = root.CFrame
        local function originFor(cue: ShowPlan.Cue): (Vector3?, Vector3?, number?)
            if cue.slot == "hand" then
                return handFrame:PointToWorldSpace(Vector3.new(1.2, 0.6, -0.8)), nil, nil
            end
            local o, h = muzzleOriginFor(uid, Vector3.new(deck.pos.x, deck.pos.y, deck.pos.z), deck, cue.shellId)
            return o, h, nil
        end
        playShow(`deck:{uid}`, uid, uid, show.cues, originFor, showId)
    end)
end)
```

Names verified against the file at plan time: shared modules are required as `require(shared:WaitForChild("Name"))` (line ~56); `FireworkCatalog` exposes `RECIPES` only; `NetworkClient.Result` is `{ ok, data?, status?, error?, notReady?, rttMs? }`; `boostMisses` is the per-uid streak table at line ~822.

- [ ] **Step 4: Format, lint, and run the Luau suite**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run 2>&1 | tail -3`
Expected: clean and green (the suite does not load `main.server.luau`, but stylua/selene do).

- [ ] **Step 5: Commit**

```bash
git add roblox/default.project.json roblox/src/server/main.server.luau
git commit -m "feat(shows): server-owned playback -- RequestShowGo validates, reserves, then plays a deck show through the shared launch broadcast; boost roll and broadcast extracted

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Studio check (the implementer runs this if Studio is available; otherwise it is the first item of Task 7's gate)**

With Rojo serving into the open place and the dev backend live: from a deck you own, in the server command bar, run

```lua
game.ReplicatedStorage.RoshamboRemotes.RequestShowGo:FireServer(...)
```

is client-side only, so instead run from the **client** command bar (Play Solo, switch to client):

```lua
game:GetService("ReplicatedStorage").RoshamboRemotes.RequestShowGo:FireServer({ stageId = "", fuel = "inventory", cues = {
  { t_ms = 0, slot = "hand", shellId = "firecracker" },
  { t_ms = 1500, slot = "mortar:S", shellId = "peony" },
  { t_ms = 3000, slot = "hand", shellId = "firecracker" },
} })
```

Expected: the output shows one `[SHOW] … 3 cues` line; three launches at 0, 1.5 and 3 s; the shell counts on the HUD drop by the whole show immediately; a second identical go while the first plays starts after the first's tail. A hand-only launch still works exactly as before (regression check of the extraction).

---

