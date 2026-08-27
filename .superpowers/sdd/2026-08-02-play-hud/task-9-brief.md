### Task 9: The win gate on the Roblox server

Add the `ResolveWin` remote, gate `SubmitPick` on it, carry `unresolvedWin` through
`PlayerProfiles`, and call the new endpoint.

**Files:**
- Modify: `roblox/default.project.json:11-38` (remotes folder)
- Modify: `roblox/src/shared/PlayerProfiles.luau:8-27`
- Modify: `roblox/src/server/NetworkClient.luau` (add `postResolveWin`)
- Modify: `roblox/src/server/main.server.luau:361-392`
- Test: `roblox/tests/PlayerProfiles.spec.luau` (extend if present, else create)

**Interfaces:**
- Consumes: `POST /resolve-win` from Task 4.
- Produces: `RoshamboRemotes.ResolveWin` RemoteEvent, client→server, one argument `"risk" | "bank"`.
- Produces: `RoshamboRemotes.SetHudPreference` RemoteEvent, client→server, one table argument
  `{ escalationPrompts: boolean? , seenBeat: string? }`. **Both** Task 12's preference switch and
  Task 13's beat-seen write go through this one remote — do not add a second. It is declared here
  because this is the task that owns `default.project.json`'s remotes folder.
- Produces: `PlayerProfiles.Row` gains `unresolvedWin: boolean`.
- Produces: `NetworkClient:postResolveWin(robloxUserId: string, choice: string)` and
  `NetworkClient:putHudPreference(robloxUserId: string, body: { [string]: any })`.

- [ ] **Step 1: Write the failing test**

```luau
-- add to roblox/tests/PlayerProfiles.spec.luau
describe("PlayerProfiles — the win gate", function()
    test("applyServer carries unresolvedWin", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("u1", {
            totalPoints = 100, pointsAtStake = 27, currentStreak = 3,
            stakingStreak = 3, bestStreak = 6, unresolvedWin = true,
        })
        expect(p:get("u1").unresolvedWin).toBe(true)
    end)

    test("a local WIN raises the gate optimistically", function()
        -- the theater reveals before the server reconciles; the overlay must appear with the win
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("u1", {
            totalPoints = 100, pointsAtStake = 9, currentStreak = 1,
            stakingStreak = 1, bestStreak = 1, unresolvedWin = false,
        })
        p:applyLocalResult("u1", "WIN")
        expect(p:get("u1").unresolvedWin).toBe(true)
    end)

    test("a local LOSS clears it — nothing left to decide", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("u1", {
            totalPoints = 100, pointsAtStake = 9, currentStreak = 1,
            stakingStreak = 1, bestStreak = 1, unresolvedWin = true,
        })
        p:applyLocalResult("u1", "LOSS")
        expect(p:get("u1").unresolvedWin).toBe(false)
    end)

    test("a missing field defaults to unbound", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("u1", {
            totalPoints = 0, pointsAtStake = 0, currentStreak = 0,
            stakingStreak = 0, bestStreak = 0,
        } :: any)
        expect(p:get("u1").unresolvedWin).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run` → FAIL, `unresolvedWin` is nil.

- [ ] **Step 3: Extend `PlayerProfiles`**

Add `unresolvedWin: boolean` to `Row`, then:

```luau
function PlayerProfiles.applyServer(self: any, userId: string, row: Row)
    self._rows[userId] = {
        totalPoints = row.totalPoints,
        pointsAtStake = row.pointsAtStake,
        currentStreak = row.currentStreak,
        stakingStreak = row.stakingStreak,
        bestStreak = row.bestStreak,
        unresolvedWin = row.unresolvedWin or false,
    }
end
```

and in `applyLocalResult`, after the existing streak lines:

```lua
    -- A WIN binds the player until they answer; a LOSS or SAFE leaves nothing to decide. Applied
    -- optimistically so the choice overlay appears with the theater, then overwritten by the
    -- authoritative reconciliation like every other field here.
    row.unresolvedWin = result == "WIN"
```

- [ ] **Step 4: Declare the remote**

In `default.project.json`, inside `RoshamboRemotes`, after `"BankRequest"`:

```json
                "ResolveWin": { "$className": "RemoteEvent" },
                "SetHudPreference": { "$className": "RemoteEvent" },
```

`SetHudPreference` carries both the escalation switch (Task 12) and the beat-seen write
(Task 13). One remote, because both are writes to the same profile preference route and a second
remote would be two things to keep in step for no gain.

- [ ] **Step 5: Add `postResolveWin` to `NetworkClient`**

Mirror the existing `postBank` exactly — same auth header, same error handling, same return
shape. Read `postBank` first and follow it; do not invent a new convention.

```luau
function NetworkClient.postResolveWin(self: any, robloxUserId: string, choice: string)
    return self:_post("/resolve-win", { robloxUserId = robloxUserId, choice = choice })
end
```

(Adjust to whatever `postBank`'s actual internal helper is named.)

- [ ] **Step 6: Gate `SubmitPick` and handle `ResolveWin`**

In `main.server.luau`, extend the existing rejection block at `:365`:

```luau
    if fates:isBound(tostring(player.UserId)) then
        print(`[PICK] {player.Name} rejected: FATE_BOUND`)
        return
    end
    -- A WIN binds the player until they answer RISK or BANK. Server-authoritative: the client
    -- dims the buttons and paints the choice over them, but this is what actually refuses.
    local prof = profiles:get(tostring(player.UserId))
    if prof and prof.unresolvedWin then
        print(`[PICK] {player.Name} rejected: WIN_BOUND`)
        return
    end
```

Then add the handler beside `BankRequest`, reusing the same `handlerQueue` so a player's
resolve and bank can never interleave:

```luau
local ResolveWin = remotes:WaitForChild("ResolveWin") :: RemoteEvent

ResolveWin.OnServerEvent:Connect(function(player, choice)
    if choice ~= "risk" and choice ~= "bank" then
        return
    end
    handlerQueue:run(tostring(player.UserId), function()
        local res = net:postResolveWin(tostring(player.UserId), choice)
        if res.ok then
            profiles:applyServer(tostring(player.UserId), {
                totalPoints = res.data.totalPoints,
                pointsAtStake = res.data.pointsAtStake,
                currentStreak = res.data.currentStreak,
                stakingStreak = res.data.stakingStreak,
                bestStreak = (profiles:get(tostring(player.UserId)) or { bestStreak = 0 }).bestStreak,
                unresolvedWin = res.data.unresolvedWin,
            })
            pushStats(player)
            fireProfile(player, if choice == "bank" then "banked" else "risked")
        else
            -- A successful postResolveWin is the ONLY in-session path that clears the gate:
            -- onReconciled deliberately passes unresolvedWin through, and applyLocalResult
            -- cannot run for a gated player because they cannot throw. So a dropped request
            -- here leaves the player unable to play, and a silent failure makes that lockout
            -- undiagnosable. Mirrors the [PROFILE] sync warn above.
            warn(`[RESOLVE] {player.Name} failed ({choice}): {res.error or res.status}`)
        end
    end)
end)
```

`BankRequest` has the same silent-`if res.ok` shape and is deliberately left alone: a failed
bank is not self-locking, so the precedent does not carry.

Add the preference handler beside it. It is fire-and-forget — nothing on screen waits for it, so
it does not need the `handlerQueue`:

```luau
local SetHudPreference = remotes:WaitForChild("SetHudPreference") :: RemoteEvent

SetHudPreference.OnServerEvent:Connect(function(player, body)
    if type(body) ~= "table" then
        return
    end
    local payload: { [string]: any } = {}
    if type(body.escalationPrompts) == "boolean" then
        payload.escalationPrompts = body.escalationPrompts
    end
    if type(body.seenBeat) == "string" then
        payload.seenBeat = body.seenBeat
    end
    if next(payload) == nil then
        return
    end
    task.spawn(function()
        net:putHudPreference(tostring(player.UserId), payload)
    end)
end)
```

Also add `unresolvedWin` to the `ProfileUpdate` payload in `fireProfile` (around `:226`) so the
client learns the gate state, and to the two other `profiles:applyServer` call sites at `:309`
and `:346`/`:381` — read each before editing and pass through whatever the server returned,
defaulting to the row's current value where the response does not carry it.

- [ ] **Step 7: Run the tests and gates**

```bash
lune run tests/run
stylua --check src tests tools && selene src tools
```

- [ ] **Step 8: Commit**

```bash
git add roblox/default.project.json roblox/src/shared/PlayerProfiles.luau roblox/src/server/NetworkClient.luau roblox/src/server/main.server.luau roblox/tests/PlayerProfiles.spec.luau
git commit -m "feat(roblox): win-bound gate — ResolveWin remote and server-side SubmitPick refusal"
```

---

