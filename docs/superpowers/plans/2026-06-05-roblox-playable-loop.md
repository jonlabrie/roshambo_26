# Roblox Playable Loop Implementation Plan (Milestone 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Roblox players can actually play: pick R/P/S during ACTIVE, picks delta-flush to `/api/v1/throws` per spec §4 (5s cadence / 10-pick / final flush at the T₀−2s lockout), the reveal is computed locally via the mirrored GameRules, authoritative results reconcile in deferred fashion, points show in leaderstats, and a Bank button cashes the pot.

**Architecture:** Same dual-runtime discipline as milestone 2 — all logic lives in injected, cross-runtime modules TDD'd under Lune; `main.server.luau` and a new `main.client.luau` are the only Roblox-runtime files. Client ↔ Roblox-server via RemoteEvents; Roblox-server ↔ Node via the extended NetworkClient. Spec: `docs/superpowers/specs/2026-06-05-roblox-client-design.md` §4 (protocol), §6 (picking), milestone 3 of §11.

**Tech Stack:** Luau (Lune-tested), Rojo, RemoteEvents, leaderstats. Backend contract: `server/src/routes/apiV1.ts` (live; local stack for dev).

**Conventions:** Run from `roblox/` with `export PATH="$HOME/.rokit/bin:$PATH"`. Tests: `lune run tests/run` (currently **46 passing**). Every task: verify branch `feature/roblox-playable` with `git branch --show-current` before committing; never check out a bare SHA. After implementing each task also run `stylua --check src tests` (auto-fix with `stylua src tests`, re-run tests) and `selene src`.

---

## File Structure

```
roblox/src/server/NetworkClient.luau    MODIFY: generalize _get → _request; add postThrows,
                                        getInstanceResults, getPlayer, postBank; deps gains jsonEncode
roblox/src/server/ThrowBuffer.luau      CREATE: per-round pick collection + delta/flush tracking (pure)
roblox/src/shared/PlayerProfiles.luau   CREATE: wallet cache + optimistic local-result math (pure)
roblox/src/server/RoundCoordinator.luau MODIFY: v2 — pick acceptance w/ lockout, flush policy,
                                        local reveal results, deferred reconciliation, callbacks
roblox/src/server/main.server.luau      MODIFY: composition v2 — players, leaderstats, RemoteEvents
roblox/src/client/main.client.luau      CREATE: pick UI, countdown, result display, bank button
roblox/default.project.json             MODIFY: RoshamboRemotes folder (5 RemoteEvents) +
                                        StarterPlayerScripts mapping for src/client
roblox/tests/NetworkClient.spec.luau    MODIFY: +7 tests
roblox/tests/ThrowBuffer.spec.luau      CREATE: 7 tests
roblox/tests/PlayerProfiles.spec.luau   CREATE: 5 tests
roblox/tests/RoundCoordinator.spec.luau MODIFY: makeFakes gains new deps; +8 tests
CLAUDE.md                               MODIFY: notes (final task)
```

**RemoteEvents contract** (`ReplicatedStorage.RoshamboRemotes`, instances declared in the Rojo project):
- `SubmitPick` (client→server): `(throw: "R"|"P"|"S")` — re-picks allowed until lockout
- `BankRequest` (client→server): `()`
- `RoundUpdate` (server→all): `{roundId, phase, roundCount, secondsToLockout: number?}`
- `RevealResult` (server→per-client): `{worldThrow, distribution, totalPlayers, pick: string?, result: string?}` (`pick`/`result` nil if that player didn't play)
- `ProfileUpdate` (server→per-client): `{totalPoints, pointsAtStake, currentStreak, stakingStreak, bestStreak, source: "sync"|"local"|"reconciled"|"banked"}`

---

### Task 1: NetworkClient v2 — POST support + the four M3 endpoints

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau`
- Test: `roblox/tests/NetworkClient.spec.luau` (append)

- [ ] **Step 1: Extend the fake in the spec file.** In `makeDeps`, the `deps` table gains `jsonEncode` and the recorded calls gain method/body. Replace the existing `request = function(...)` recorder and add `jsonEncode` so the fake table becomes:

```lua
            request = function(req: { Url: string, Method: string, Headers: { [string]: string }, Body: string? }): Resp
                table.insert(calls, { url = req.Url, method = req.Method, headers = req.Headers, body = req.Body })
                i += 1
                return script[math.min(i, #script)]
            end,
            jsonEncode = function(t: any): string
                return serde.encode("json", t)
            end,
```

(Existing tests only read `calls[n].url`/`.headers`, so they keep passing.)

- [ ] **Step 2: Append the failing tests** (new describe blocks at the end of the file):

```lua
describe("NetworkClient.postThrows", function()
    test("POSTs the encoded batch with content-type and returns the 202 body", function()
        local f = makeDeps({ { ok = true, statusCode = 202, body = '{"accepted":2,"rejected":[]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postThrows({
            instanceId = "job-1",
            roundId = "r1",
            seq = 1,
            throws = { { robloxUserId = "9", throw = "R" } },
        })
        expect(res.ok).toBe(true)
        expect(res.data.accepted).toBe(2)
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/throws")
        expect(f.calls[1].headers["Content-Type"]).toBe("application/json")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.seq).toBe(1)
        expect(sent.throws[1].robloxUserId).toBe("9")
    end)

    test("409 fails fast with the decoded server error (no retry burn)", function()
        local f = makeDeps({ { ok = true, statusCode = 409, body = '{"error":"PICKS_CLOSED"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postThrows({ instanceId = "j", roundId = "r", seq = 1, throws = {} })
        expect(res.ok).toBe(false)
        expect(res.status).toBe(409)
        expect(res.error).toBe("PICKS_CLOSED")
        expect(#f.calls).toBe(1)
    end)

    test("transport failure retries POSTs like GETs", function()
        local f = makeDeps({ { ok = false }, { ok = true, statusCode = 202, body = '{"accepted":0,"rejected":[]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        expect(net:postThrows({ instanceId = "j", roundId = "r", seq = 1, throws = {} }).ok).toBe(true)
        expect(#f.calls).toBe(2)
    end)
end)

describe("NetworkClient.getInstanceResults", function()
    test("hits the per-instance results path; 404 maps to notReady", function()
        local f = makeDeps({ { ok = true, statusCode = 404, body = '{"error":"RESULTS_NOT_READY"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getInstanceResults("job-1", "r9")
        expect(res.notReady).toBe(true)
        expect(f.calls[1].url).toBe("http://x/api/v1/instances/job-1/rounds/r9/results")
    end)
end)

describe("NetworkClient.getPlayer", function()
    test("plain fetch and country-recording variant", function()
        local f = makeDeps({
            { ok = true, statusCode = 200, body = '{"robloxUserId":"9","totalPoints":5}' },
            { ok = true, statusCode = 200, body = '{"robloxUserId":"9","totalPoints":5}' },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        expect(net:getPlayer("9").data.totalPoints).toBe(5)
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9")
        net:getPlayer("9", "US")
        expect(f.calls[2].url).toBe("http://x/api/v1/players/9?country=US")
    end)
end)

describe("NetworkClient.postBank", function()
    test("banks and returns the wallet", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"totalPoints":14,"pointsAtStake":0}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postBank("9")
        expect(res.data.totalPoints).toBe(14)
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.robloxUserId).toBe("9")
    end)

    test("409 NOTHING_STAKED fails fast with the decoded error", function()
        local f = makeDeps({ { ok = true, statusCode = 409, body = '{"error":"NOTHING_STAKED"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postBank("9")
        expect(res.ok).toBe(false)
        expect(res.error).toBe("NOTHING_STAKED")
        expect(#f.calls).toBe(1)
    end)
end)
```

- [ ] **Step 3: Run to verify the 7 new tests fail** — `lune run tests/run` → failures (methods missing / Deps lacks jsonEncode).

- [ ] **Step 4: Rework `roblox/src/server/NetworkClient.luau`.** Add `jsonEncode: (t: any) -> string` to the `Deps` type. Replace `_get` with a generalized `_request` and keep thin public methods:

```lua
function NetworkClient._request(self: any, method: string, path: string, bodyTable: any?): Result
    local d: Deps = self._deps
    local headers: { [string]: string } = { ["X-API-Key"] = self._key }
    local bodyStr: string? = nil
    if bodyTable ~= nil then
        headers["Content-Type"] = "application/json"
        bodyStr = d.jsonEncode(bodyTable)
    end
    for attempt = 1, self._maxAttempts do
        local sentAt = d.now()
        local resp = d.request({ Url = self._base .. path, Method = method, Headers = headers, Body = bodyStr })
        local receivedAt = d.now()
        if resp.ok and resp.statusCode then
            local code = resp.statusCode
            if code >= 200 and code < 300 then
                local decodeOk, decoded = pcall(d.jsonDecode, resp.body or "null")
                if not decodeOk then
                    return { ok = false, status = code, error = "DECODE_FAILED" }
                end
                return {
                    ok = true,
                    data = decoded,
                    status = code,
                    rttMs = receivedAt - sentAt,
                    localReceiveMs = receivedAt,
                }
            end
            if code == 404 then
                return { ok = false, notReady = true, status = code }
            end
            if code < 500 then
                -- 4xx: fail fast. Surface the server's error string when the body has one
                -- (409 ROUND_MISMATCH / PICKS_CLOSED / NOTHING_STAKED are protocol signals).
                local decodeOk, decoded = pcall(d.jsonDecode, resp.body or "null")
                local serverError = if decodeOk and type(decoded) == "table" then decoded.error else nil
                return { ok = false, status = code, error = serverError or ("HTTP_" .. tostring(code)), data = if decodeOk then decoded else nil }
            end
        end
        if attempt < self._maxAttempts then
            d.sleep(backoffSeconds(attempt, d.random))
        end
    end
    return { ok = false, error = "TRANSPORT_FAILED" }
end

function NetworkClient.getState(self: any): Result
    return self:_request("GET", "/api/v1/state")
end

function NetworkClient.getRoundResult(self: any, roundId: string): Result
    return self:_request("GET", `/api/v1/rounds/{roundId}/result`)
end

function NetworkClient.postThrows(self: any, batch: any): Result
    return self:_request("POST", "/api/v1/throws", batch)
end

function NetworkClient.getInstanceResults(self: any, instanceId: string, roundId: string): Result
    return self:_request("GET", `/api/v1/instances/{instanceId}/rounds/{roundId}/results`)
end

function NetworkClient.getPlayer(self: any, robloxUserId: string, country: string?): Result
    local path = `/api/v1/players/{robloxUserId}`
    if country then
        path ..= `?country={country}`
    end
    return self:_request("GET", path)
end

function NetworkClient.postBank(self: any, robloxUserId: string): Result
    return self:_request("POST", "/api/v1/bank", { robloxUserId = robloxUserId })
end
```

NOTE the behavior change to the existing 401 test: it asserted `res.status == 401` only — still satisfied (`error` becomes "UNAUTHORIZED" from the decoded body rather than "HTTP_401"; the existing test does not assert `error`, verify and leave it).

- [ ] **Step 5: Run** — `lune run tests/run` → `53 passed` (46 + 7). Lint/format clean.

- [ ] **Step 6: Commit** — `git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau && git commit -m "feat(roblox): NetworkClient v2 - throws, instance results, player, bank endpoints"`

### Task 2: ThrowBuffer (pure)

**Files:**
- Create: `roblox/src/server/ThrowBuffer.luau`
- Test: `roblox/tests/ThrowBuffer.spec.luau`

- [ ] **Step 1: Write the failing test `roblox/tests/ThrowBuffer.spec.luau`:**

```lua
--!strict
local harness = require("./harness")
local ThrowBuffer = require("../src/server/ThrowBuffer")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ThrowBuffer", function()
    test("collects picks and reports unflushed count", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("10", "P")
        expect(b:unflushedCount()).toBe(2)
    end)

    test("re-pick overwrites and counts once", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("9", "S")
        expect(b:unflushedCount()).toBe(1)
        expect(b:picks()["9"]).toBe("S")
    end)

    test("takeDelta returns unflushed picks and marks them flushed", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("10", "P")
        local delta = b:takeDelta()
        expect(#delta).toBe(2)
        expect(b:unflushedCount()).toBe(0)
        -- picks remain known for local reveal calc
        expect(b:picks()["9"]).toBe("R")
    end)

    test("a re-pick after flush is dirty again (next delta carries it)", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:takeDelta()
        b:setPick("9", "P")
        local delta = b:takeDelta()
        expect(#delta).toBe(1)
        expect(delta[1].robloxUserId).toBe("9")
        expect(delta[1].throw).toBe("P")
    end)

    test("requeue marks entries unflushed unless a newer pick superseded them", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:setPick("10", "P")
        local delta = b:takeDelta()
        b:setPick("10", "S") -- newer pick while the flush was in flight
        b:requeue(delta)
        local redo = b:takeDelta()
        -- "9" requeued with R; "10" keeps its NEWER value S (already dirty), not the stale P
        local byId = {}
        for _, t in redo do
            byId[t.robloxUserId] = t.throw
        end
        expect(byId["9"]).toBe("R")
        expect(byId["10"]).toBe("S")
    end)

    test("clearRound wipes everything", function()
        local b = ThrowBuffer.new()
        b:setPick("9", "R")
        b:clearRound()
        expect(b:unflushedCount()).toBe(0)
        expect(b:picks()["9"]).toBeNil()
    end)

    test("takeDelta on empty buffer returns an empty array", function()
        local b = ThrowBuffer.new()
        expect(#b:takeDelta()).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**, then **create `roblox/src/server/ThrowBuffer.luau`:**

```lua
--!strict
-- Per-round pick collection with delta-flush tracking (spec §4: delta-only
-- batches). Pure: no I/O, no Roblox globals. The coordinator owns flush
-- timing; this module owns what's in each delta.
local ThrowBuffer = {}
ThrowBuffer.__index = ThrowBuffer

export type Entry = { robloxUserId: string, throw: string }

function ThrowBuffer.new()
    return setmetatable({
        _picks = {} :: { [string]: string },
        _dirty = {} :: { [string]: boolean },
    }, ThrowBuffer)
end

function ThrowBuffer.setPick(self: any, robloxUserId: string, throwValue: string)
    self._picks[robloxUserId] = throwValue
    self._dirty[robloxUserId] = true
end

function ThrowBuffer.unflushedCount(self: any): number
    local n = 0
    for _ in self._dirty do
        n += 1
    end
    return n
end

function ThrowBuffer.takeDelta(self: any): { Entry }
    local delta: { Entry } = {}
    for userId in self._dirty do
        table.insert(delta, { robloxUserId = userId, throw = self._picks[userId] })
    end
    self._dirty = {}
    return delta
end

-- Put a failed flush back. A pick made AFTER takeDelta is already dirty with a
-- newer value; don't clobber it with the stale in-flight one.
function ThrowBuffer.requeue(self: any, delta: { Entry })
    for _, entry in delta do
        if not self._dirty[entry.robloxUserId] then
            self._picks[entry.robloxUserId] = entry.throw
            self._dirty[entry.robloxUserId] = true
        end
    end
end

function ThrowBuffer.picks(self: any): { [string]: string }
    return self._picks
end

function ThrowBuffer.clearRound(self: any)
    self._picks = {}
    self._dirty = {}
end

return ThrowBuffer
```

- [ ] **Step 3: Run** — `lune run tests/run` → `60 passed`. Lint/format clean.

- [ ] **Step 4: Commit** — `git add roblox/src/server/ThrowBuffer.luau roblox/tests/ThrowBuffer.spec.luau && git commit -m "feat(roblox): ThrowBuffer - delta-only pick batches with safe requeue"`

### Task 3: PlayerProfiles (pure)

**Files:**
- Create: `roblox/src/shared/PlayerProfiles.luau`
- Test: `roblox/tests/PlayerProfiles.spec.luau`

- [ ] **Step 1: Write the failing test:**

```lua
--!strict
local harness = require("./harness")
local GameRules = require("../src/shared/GameRules")
local PlayerProfiles = require("../src/shared/PlayerProfiles")
local describe, test, expect = harness.describe, harness.test, harness.expect

local SERVER_ROW = { totalPoints = 5, pointsAtStake = 9, currentStreak = 2, stakingStreak = 2, bestStreak = 4 }

describe("PlayerProfiles", function()
    test("applyServer stores and get returns the wallet", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        expect(p:get("9")).toEqual(SERVER_ROW)
        expect(p:get("nope")).toBeNil()
    end)

    test("local WIN grows the pot optimistically and bumps streaks", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        p:applyLocalResult("9", "WIN")
        expect(p:get("9")).toEqual({ totalPoints = 5, pointsAtStake = 27, currentStreak = 3, stakingStreak = 3, bestStreak = 4 })
    end)

    test("local SAFE preserves pot, resets streaks", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        p:applyLocalResult("9", "SAFE")
        expect(p:get("9")).toEqual({ totalPoints = 5, pointsAtStake = 9, currentStreak = 0, stakingStreak = 0, bestStreak = 4 })
    end)

    test("local LOSS forfeits pot, resets streaks", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", SERVER_ROW)
        p:applyLocalResult("9", "LOSS")
        expect(p:get("9")).toEqual({ totalPoints = 5, pointsAtStake = 0, currentStreak = 0, stakingStreak = 0, bestStreak = 4 })
    end)

    test("bestStreak rises with a new local high; unknown user is a no-op", function()
        local p = PlayerProfiles.new(GameRules)
        p:applyServer("9", { totalPoints = 0, pointsAtStake = 0, currentStreak = 4, stakingStreak = 4, bestStreak = 4 })
        p:applyLocalResult("9", "WIN")
        expect(p:get("9").bestStreak).toBe(5)
        p:applyLocalResult("ghost", "WIN") -- must not error
        expect(p:get("ghost")).toBeNil()
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**, then **create `roblox/src/shared/PlayerProfiles.luau`:**

```lua
--!strict
-- Wallet cache for players in this instance. Local results are OPTIMISTIC
-- (theater); the deferred reconciliation rows from /instances/.../results are
-- authoritative and overwrite via applyServer (spec §4).
local PlayerProfiles = {}
PlayerProfiles.__index = PlayerProfiles

export type Row = {
    totalPoints: number,
    pointsAtStake: number,
    currentStreak: number,
    stakingStreak: number,
    bestStreak: number,
}

function PlayerProfiles.new(rules: any)
    return setmetatable({ _rules = rules, _rows = {} :: { [string]: Row } }, PlayerProfiles)
end

function PlayerProfiles.applyServer(self: any, userId: string, row: Row)
    self._rows[userId] = {
        totalPoints = row.totalPoints,
        pointsAtStake = row.pointsAtStake,
        currentStreak = row.currentStreak,
        stakingStreak = row.stakingStreak,
        bestStreak = row.bestStreak,
    }
end

function PlayerProfiles.applyLocalResult(self: any, userId: string, result: string)
    local row = self._rows[userId]
    if not row then
        return
    end
    row.pointsAtStake = self._rules.nextPot(row.pointsAtStake, result)
    row.currentStreak = self._rules.nextStreak(row.currentStreak, result)
    row.stakingStreak = self._rules.nextStreak(row.stakingStreak, result)
    row.bestStreak = math.max(row.bestStreak, row.currentStreak)
end

function PlayerProfiles.get(self: any, userId: string): Row?
    return self._rows[userId]
end

return PlayerProfiles
```

- [ ] **Step 3: Run** — `lune run tests/run` → `65 passed`. Lint/format clean.

- [ ] **Step 4: Commit** — `git add roblox/src/shared/PlayerProfiles.luau roblox/tests/PlayerProfiles.spec.luau && git commit -m "feat(roblox): PlayerProfiles - optimistic wallet cache with authoritative overwrite"`

### Task 4: RoundCoordinator v2 — picks, flushing, reveal, reconciliation

**Files:**
- Modify: `roblox/src/server/RoundCoordinator.luau`
- Test: `roblox/tests/RoundCoordinator.spec.luau`

The v2 deps grow to `{net, clock, buffer, rules, log, random, now, instanceId, callbacks?}`. The 6 existing tests stay (their `makeFakes` gains the new deps); 8 new tests pin M3 behavior.

- [ ] **Step 1: Rework the spec file's fakes and append tests.** Replace `makeFakes` with:

```lua
local ThrowBuffer = require("../src/server/ThrowBuffer")
local GameRules = require("../src/shared/GameRules")

local function makeFakes(states: { any }, results: { any }, opts: { nows: { number }?, instanceResults: { any }? })
    local logs: { string } = {}
    local postCalls: { any } = {}
    local instanceCalls: { any } = {}
    local stateIdx, resultIdx, instanceIdx = 0, 0, 0
    local nowIdx = 0
    local nows = opts and opts.nows
    local instanceResults = opts and opts.instanceResults or {}
    local clockSamples = 0
    return {
        logs = logs,
        postCalls = postCalls,
        instanceCalls = instanceCalls,
        net = {
            getState = function(_self): any
                stateIdx = math.min(stateIdx + 1, #states)
                return states[stateIdx]
            end,
            getRoundResult = function(_self, _roundId: string): any
                resultIdx = math.min(resultIdx + 1, #results)
                return results[resultIdx]
            end,
            postThrows = function(_self, batch: any): any
                table.insert(postCalls, batch)
                return { ok = true, data = { accepted = #batch.throws, rejected = {} } }
            end,
            getInstanceResults = function(_self, instanceId: string, roundId: string): any
                table.insert(instanceCalls, { instanceId = instanceId, roundId = roundId })
                instanceIdx = math.min(instanceIdx + 1, math.max(#instanceResults, 1))
                return instanceResults[instanceIdx] or { ok = true, data = {} }
            end,
        },
        clock = {
            addSample = function(_self, _st, _rtt, _lr)
                clockSamples += 1
            end,
            hasSync = function(_self)
                return true
            end,
            toLocalTime = function(_self, serverMs: number)
                return serverMs -- identity: tests use one epoch for both clocks
            end,
            samples = function()
                return clockSamples
            end,
        },
        now = function(): number
            if nows then
                nowIdx = math.min(nowIdx + 1, #nows)
                return nows[nowIdx]
            end
            return 0
        end,
        log = function(msg: string)
            table.insert(logs, msg)
        end,
        random = function()
            return 0
        end,
    }
end

local function makeCoordinator(f: any, callbacks: any?)
    return RoundCoordinator.new({
        net = f.net :: any,
        clock = f.clock :: any,
        buffer = ThrowBuffer.new(),
        rules = GameRules,
        log = f.log,
        random = f.random,
        now = f.now,
        instanceId = "job-T",
        callbacks = callbacks,
    })
end
```

Update each of the 6 existing tests to construct via `makeCoordinator(f)` instead of `RoundCoordinator.new({...})` (their state/result scripts and assertions are unchanged). `okState` gains an explicit `phaseEndsAt` argument with default:

```lua
local function okState(roundId: string, phase: string, roundCount: number, phaseEndsAt: number?)
    return {
        ok = true,
        data = { roundId = roundId, phase = phase, roundCount = roundCount, serverTime = 1, phaseEndsAt = phaseEndsAt or 100000 },
        rttMs = 10,
        localReceiveMs = 1,
    }
end
```

Then append:

```lua
describe("RoundCoordinator v2 picks + flush", function()
    test("accepts a pick during ACTIVE before lockout; rejects after lockout", function()
        -- phaseEndsAt 30000 -> lockout 28000. The nows queue feeds submitPick's
        -- lockout checks (pollOnce consumes no now() when there are no picks):
        -- first submit sees 0 (< 28000, accepted), second sees 29000 (locked).
        local f = makeFakes({ okState("r1", "ACTIVE", 7, 30000) }, {}, { nows = { 0, 29000 } })
        local c = makeCoordinator(f)
        c:pollOnce()
        local ok1 = c:submitPick("9", "R")
        expect(ok1).toBe(true)
        local ok2, reason = c:submitPick("9", "P")
        expect(ok2).toBe(false)
        expect(reason).toBe("LOCKED")
    end)

    test("rejects picks outside ACTIVE and invalid throws", function()
        local f = makeFakes({ okState("r1", "TALLY", 7) }, { { ok = false, notReady = true } })
        local c = makeCoordinator(f)
        c:pollOnce()
        local ok, reason = c:submitPick("9", "R")
        expect(ok).toBe(false)
        expect(reason).toBe("PICKS_CLOSED")
        local ok2, reason2 = c:submitPick("9", "X")
        expect(ok2).toBe(false)
        expect(reason2).toBe("BAD_THROW")
    end)

    test("flushes on the 5s cadence with incrementing seq", function()
        -- now() consumption: submitPick takes 0; the next poll's flush check takes
        -- 1000 (becomes the cadence baseline, no flush); the last takes 6500
        -- (5.5s elapsed -> flush). Polls with zero unflushed picks consume no now().
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7, 99000), okState("r1", "ACTIVE", 7, 99000), okState("r1", "ACTIVE", 7, 99000) },
            {},
            { nows = { 0, 1000, 6500 } }
        )
        local c = makeCoordinator(f)
        c:pollOnce() -- no picks: consumes no now()
        c:submitPick("9", "R") -- now=0
        c:pollOnce() -- now=1000: becomes baseline -> no flush
        expect(#f.postCalls).toBe(0)
        c:pollOnce() -- now=6500: 5.5s since baseline -> flush
        expect(#f.postCalls).toBe(1)
        expect(f.postCalls[1].seq).toBe(1)
        expect(f.postCalls[1].roundId).toBe("r1")
        expect(f.postCalls[1].instanceId).toBe("job-T")
        expect(f.postCalls[1].throws[1].robloxUserId).toBe("9")
    end)

    test("flushes immediately when 10 picks accumulate", function()
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7, 99000), okState("r1", "ACTIVE", 7, 99000) },
            {},
            { nows = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1000 } }
        )
        local c = makeCoordinator(f)
        c:pollOnce()
        for i = 1, 10 do
            c:submitPick(tostring(i), "R")
        end
        c:pollOnce() -- only ~1s elapsed but 10 picks -> flush
        expect(#f.postCalls).toBe(1)
        expect(#f.postCalls[1].throws).toBe(10)
    end)

    test("final flush fires once past lockout even under the 5s cadence", function()
        -- lockout = 10000-2000 = 8000. submitPick sees 4000; next poll's flush
        -- check sees 4500 (baseline, no flush); last poll sees 8100 >= lockout -> flush.
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7, 10000), okState("r1", "ACTIVE", 7, 10000), okState("r1", "ACTIVE", 7, 10000) },
            {},
            { nows = { 4000, 4500, 8100 } }
        )
        local c = makeCoordinator(f)
        c:pollOnce() -- no picks: consumes no now()
        c:submitPick("9", "R") -- now=4000
        c:pollOnce() -- now=4500: baseline, 1 pick, before lockout -> no flush
        expect(#f.postCalls).toBe(0)
        c:pollOnce() -- now=8100 >= lockout 8000 -> final flush
        expect(#f.postCalls).toBe(1)
    end)

    test("transport-failed flush requeues the delta for the next poll", function()
        -- submitPick sees 0; flush-check nows: 1000 (baseline), 7000 (flush 1, fails,
        -- baseline moves to 7000), 13000 (flush 2 succeeds with the requeued pick).
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7, 99000), okState("r1", "ACTIVE", 7, 99000), okState("r1", "ACTIVE", 7, 99000) },
            {},
            { nows = { 0, 1000, 7000, 13000 } }
        )
        f.net.postThrows = function(_self, batch: any): any
            table.insert(f.postCalls, batch)
            if #f.postCalls == 1 then
                return { ok = false, error = "TRANSPORT_FAILED" }
            end
            return { ok = true, data = { accepted = #batch.throws, rejected = {} } }
        end
        local c = makeCoordinator(f)
        c:pollOnce() -- no picks: consumes no now()
        c:submitPick("9", "R")
        c:pollOnce() -- baseline, no flush
        c:pollOnce() -- flush 1 fails -> requeue
        c:pollOnce() -- flush 2 retries the same pick with a higher seq
        expect(#f.postCalls).toBe(2)
        expect(f.postCalls[2].throws[1].robloxUserId).toBe("9")
        expect(f.postCalls[2].seq).toBe(2)
    end)
end)

describe("RoundCoordinator v2 reveal + reconciliation", function()
    test("reveal computes per-player local results and fires onReveal once", function()
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7, 99000), okState("r1", "TALLY", 7), okState("r1", "REVEAL", 7) },
            { { ok = true, data = { worldThrow = "S", distribution = { R = 50, P = 50, S = 0 }, totalPlayers = 2 } } },
            { nows = { 0, 1, 2, 1000, 2000 } }
        )
        local reveals: { any } = {}
        local c = makeCoordinator(f, {
            onReveal = function(r: any)
                table.insert(reveals, r)
            end,
        })
        c:pollOnce()
        c:submitPick("9", "R") -- beats S -> WIN
        c:submitPick("10", "P") -- loses to S -> LOSS
        c:pollOnce() -- TALLY: result fetched, reveal fired
        c:pollOnce() -- REVEAL: no second fire
        expect(#reveals).toBe(1)
        expect(reveals[1].worldThrow).toBe("S")
        expect(reveals[1].results["9"].result).toBe("WIN")
        expect(reveals[1].results["9"].pick).toBe("R")
        expect(reveals[1].results["10"].result).toBe("LOSS")
    end)

    test("reconciliation fetches instance results on the next ACTIVE and passes rows through", function()
        local rows = { { robloxUserId = "9", result = "WIN", totalPoints = 0, pot = 1, streak = 1 } }
        local f = makeFakes(
            {
                okState("r1", "ACTIVE", 7, 99000),
                okState("r1", "REVEAL", 7),
                okState("r2", "ACTIVE", 8, 99000),
            },
            { { ok = true, data = { worldThrow = "S", distribution = { R = 100, P = 0, S = 0 }, totalPlayers = 1 } } },
            { nows = { 0, 1, 1000, 2000, 3000 }, instanceResults = { { ok = true, data = rows } } }
        )
        local reconciled: { any } = {}
        local c = makeCoordinator(f, {
            onReconciled = function(r: any)
                table.insert(reconciled, r)
            end,
        })
        c:pollOnce()
        c:submitPick("9", "R")
        c:pollOnce() -- REVEAL for r1
        c:pollOnce() -- r2 ACTIVE: reconciliation for r1 fires
        expect(#f.instanceCalls).toBe(1)
        expect(f.instanceCalls[1].roundId).toBe("r1")
        expect(#reconciled).toBe(1)
        expect(reconciled[1][1].robloxUserId).toBe("9")
    end)
end)
```

- [ ] **Step 2: Run to verify the new tests fail** (constructor signature + missing methods).

- [ ] **Step 3: Rewrite `roblox/src/server/RoundCoordinator.luau`:**

```lua
--!strict
-- Orchestrates the playable loop on a Roblox game server: polls /state, accepts
-- picks until the T0-2s lockout (spec §4), delta-flushes throws (5s cadence /
-- 10-pick / final flush), computes the local reveal from mirrored GameRules,
-- and reconciles authoritative per-player results on the next ACTIVE.
local RoundCoordinator = {}
RoundCoordinator.__index = RoundCoordinator

local LOCKOUT_BEFORE_END_MS = 2000
local FLUSH_INTERVAL_MS = 5000
local FLUSH_PICK_THRESHOLD = 10

export type Callbacks = {
    onRound: ((info: any) -> ())?,
    onReveal: ((reveal: any) -> ())?,
    onReconciled: ((rows: any) -> ())?,
}

export type Deps = {
    net: any, -- getState, getRoundResult, postThrows, getInstanceResults
    clock: any, -- addSample, hasSync, toLocalTime
    buffer: any, -- ThrowBuffer-shaped
    rules: any, -- GameRules-shaped (calculateResult)
    log: (msg: string) -> (),
    random: () -> number,
    now: () -> number, -- local epoch ms
    instanceId: string,
    callbacks: Callbacks?,
}

local VALID_THROWS = { R = true, P = true, S = true }

function RoundCoordinator.new(deps: Deps)
    return setmetatable({
        _deps = deps,
        _roundId = nil :: string?,
        _phase = nil :: string?,
        _roundCount = 0,
        _resultLogged = false,
        _lockoutAtMs = nil :: number?,
        _seq = 0,
        _lastFlushMs = nil :: number?,
        _picksClosed = false,
        _pendingReconcileRoundId = nil :: string?,
    }, RoundCoordinator)
end

-- Returns (accepted, reason?). Reasons: PICKS_CLOSED | LOCKED | BAD_THROW.
function RoundCoordinator.submitPick(self: any, userId: string, throwValue: string): (boolean, string?)
    if self._phase ~= "ACTIVE" or self._picksClosed then
        return false, "PICKS_CLOSED"
    end
    if not VALID_THROWS[throwValue] then
        return false, "BAD_THROW"
    end
    if self._lockoutAtMs and self._deps.now() >= self._lockoutAtMs then
        return false, "LOCKED"
    end
    self._deps.buffer:setPick(userId, throwValue)
    return true
end

function RoundCoordinator._flush(self: any)
    local d: Deps = self._deps
    local delta = d.buffer:takeDelta()
    if #delta == 0 then
        return
    end
    self._seq += 1
    local res = d.net:postThrows({
        instanceId = d.instanceId,
        roundId = self._roundId,
        seq = self._seq,
        throws = delta,
    })
    if res.ok then
        return
    end
    if res.error == "PICKS_CLOSED" or res.error == "ROUND_MISMATCH" then
        -- Whiff: these picks didn't make the round. Never invent results (spec §9).
        self._picksClosed = true
        d.log(`[FLUSH] {#delta} pick(s) whiffed: {res.error}`)
    else
        d.buffer:requeue(delta)
        d.log(`[FLUSH] failed ({res.error or res.status}), requeued {#delta} pick(s)`)
    end
end

function RoundCoordinator._maybeFlush(self: any)
    local d: Deps = self._deps
    if self._phase ~= "ACTIVE" or self._picksClosed then
        return
    end
    local unflushed = d.buffer:unflushedCount()
    if unflushed == 0 then
        return
    end
    local nowMs = d.now()
    if self._lastFlushMs == nil then
        -- First sighting of picks this round: start the cadence clock; don't
        -- flush a player's pick the instant it lands (it may still change).
        self._lastFlushMs = nowMs
    end
    local elapsed = nowMs - self._lastFlushMs
    local pastLockout = self._lockoutAtMs ~= nil and nowMs >= self._lockoutAtMs
    if elapsed >= FLUSH_INTERVAL_MS or unflushed >= FLUSH_PICK_THRESHOLD or pastLockout then
        self._lastFlushMs = nowMs
        self:_flush()
    end
end

function RoundCoordinator._fetchRevealIfDue(self: any, state: any)
    local d: Deps = self._deps
    if not (state.phase == "TALLY" or state.phase == "REVEAL") or self._resultLogged then
        return
    end
    local result = d.net:getRoundResult(self._roundId)
    if not result.ok then
        if not result.notReady then
            d.log(`[RESULT] fetch failed: {result.error or result.status}`)
        end
        return -- latch stays open; next poll retries
    end
    self._resultLogged = true
    local r = result.data
    d.log(
        `[ROUND {self._roundCount}] WORLD THROW: {r.worldThrow}`
            .. ` | R {r.distribution.R}% P {r.distribution.P}% S {r.distribution.S}%`
            .. ` | players {r.totalPlayers}`
    )
    local results: { [string]: any } = {}
    for userId, pick in d.buffer:picks() do
        results[userId] = { pick = pick, result = d.rules.calculateResult(pick, r.worldThrow) }
    end
    if d.callbacks and d.callbacks.onReveal then
        d.callbacks.onReveal({
            roundId = self._roundId,
            worldThrow = r.worldThrow,
            distribution = r.distribution,
            totalPlayers = r.totalPlayers,
            results = results,
        })
    end
end

function RoundCoordinator._reconcileIfDue(self: any)
    local d: Deps = self._deps
    if not self._pendingReconcileRoundId or self._phase ~= "ACTIVE" then
        return
    end
    local res = d.net:getInstanceResults(d.instanceId, self._pendingReconcileRoundId)
    if res.ok then
        d.log(`[RECON] round {self._pendingReconcileRoundId}: {#res.data} row(s)`)
        if d.callbacks and d.callbacks.onReconciled then
            d.callbacks.onReconciled(res.data)
        end
        self._pendingReconcileRoundId = nil
    elseif not res.notReady then
        d.log(`[RECON] failed for {self._pendingReconcileRoundId}: {res.error or res.status}`)
        self._pendingReconcileRoundId = nil -- hard failure: don't retry forever
    end
end

function RoundCoordinator.pollOnce(self: any): number
    local d: Deps = self._deps
    local res = d.net:getState()
    if not res.ok then
        d.log(`[NET] state failed: {res.error or res.status}`)
        return 3
    end

    local state = res.data
    d.clock:addSample(state.serverTime, res.rttMs, res.localReceiveMs)

    if state.roundId ~= self._roundId then
        if self._roundId and next(d.buffer:picks()) ~= nil then
            self._pendingReconcileRoundId = self._roundId
        end
        d.buffer:clearRound()
        self._roundId = state.roundId
        self._roundCount = state.roundCount
        self._phase = nil
        self._resultLogged = false
        self._lockoutAtMs = nil
        self._seq = 0
        self._lastFlushMs = nil
        self._picksClosed = false
    end

    if state.phase == "ACTIVE" and d.clock:hasSync() then
        self._lockoutAtMs = d.clock:toLocalTime(state.phaseEndsAt) - LOCKOUT_BEFORE_END_MS
    end

    if state.phase ~= self._phase then
        self._phase = state.phase
        d.log(`[ROUND {self._roundCount}] {self._roundId} {state.phase}`)
        if d.callbacks and d.callbacks.onRound then
            local secondsToLockout: number? = nil
            if state.phase == "ACTIVE" and self._lockoutAtMs then
                secondsToLockout = math.max(0, (self._lockoutAtMs - d.now()) / 1000)
            end
            d.callbacks.onRound({
                roundId = self._roundId,
                phase = state.phase,
                roundCount = self._roundCount,
                secondsToLockout = secondsToLockout,
            })
        end
    end

    self:_maybeFlush()
    self:_fetchRevealIfDue(state)
    self:_reconcileIfDue()

    return 1 + d.random() * 0.25
end

return RoundCoordinator
```

- [ ] **Step 4: Run** — `lune run tests/run` → `73 passed` (65 + 8; the 6 pre-existing coordinator tests still green). Lint/format clean.

- [ ] **Step 5: Commit** — `git add roblox/src/server/RoundCoordinator.luau roblox/tests/RoundCoordinator.spec.luau && git commit -m "feat(roblox): RoundCoordinator v2 - picks, lockout, delta flushing, local reveal, reconciliation"`

### Task 5: Rojo remotes + main.server v2

**Files:**
- Modify: `roblox/default.project.json`
- Modify: `roblox/src/server/main.server.luau`

- [ ] **Step 1: Add to `roblox/default.project.json`** inside `"ReplicatedStorage"` (sibling of `RoshamboShared`) and a new `StarterPlayer` node at tree level:

```json
        "ReplicatedStorage": {
            "RoshamboShared": { "$path": "src/shared" },
            "RoshamboRemotes": {
                "$className": "Folder",
                "SubmitPick": { "$className": "RemoteEvent" },
                "BankRequest": { "$className": "RemoteEvent" },
                "RoundUpdate": { "$className": "RemoteEvent" },
                "RevealResult": { "$className": "RemoteEvent" },
                "ProfileUpdate": { "$className": "RemoteEvent" }
            }
        },
        "StarterPlayer": {
            "$className": "StarterPlayer",
            "StarterPlayerScripts": {
                "$className": "StarterPlayerScripts",
                "RoshamboClient": { "$path": "src/client" }
            }
        },
```

- [ ] **Step 2: Rewrite `roblox/src/server/main.server.luau`:**

```lua
--!strict
-- Composition root: wires Roblox services into the runtime-agnostic modules.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))
local RoundCoordinator = require(script.Parent:WaitForChild("RoundCoordinator"))
local ThrowBuffer = require(script.Parent:WaitForChild("ThrowBuffer"))
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local RoundClock = require(shared:WaitForChild("RoundClock"))
local GameRules = require(shared:WaitForChild("GameRules"))
local PlayerProfiles = require(shared:WaitForChild("PlayerProfiles"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent

local secretsModule = script.Parent:FindFirstChild("SecretsLocal") or script.Parent:WaitForChild("SecretsExample")
local config = require(secretsModule) :: { baseUrl: string, apiKey: string }

local deps = {
    request = function(req)
        local ok, resp = pcall(function()
            return HttpService:RequestAsync({
                Url = req.Url,
                Method = req.Method,
                Headers = req.Headers,
                Body = req.Body,
            })
        end)
        if not ok then
            warn(`[NET] transport error: {resp}`)
            return { ok = false }
        end
        return { ok = true, statusCode = resp.StatusCode, body = resp.Body }
    end,
    jsonDecode = function(s: string)
        return HttpService:JSONDecode(s)
    end,
    jsonEncode = function(t: any)
        return HttpService:JSONEncode(t)
    end,
    sleep = function(seconds: number)
        task.wait(seconds)
    end,
    now = function()
        return DateTime.now().UnixTimestampMillis
    end,
    random = function()
        return math.random()
    end,
}

local net = NetworkClient.new({ baseUrl = config.baseUrl, apiKey = config.apiKey }, deps)
local clock = RoundClock.new()
local profiles = PlayerProfiles.new(GameRules)

local function leaderstatsFor(player: Player): Folder?
    return player:FindFirstChild("leaderstats") :: Folder?
end

local function pushStats(player: Player)
    local row = profiles:get(tostring(player.UserId))
    local stats = leaderstatsFor(player)
    if not row or not stats then
        return
    end
    ;(stats:FindFirstChild("Points") :: IntValue).Value = row.totalPoints
    ;(stats:FindFirstChild("Pot") :: IntValue).Value = row.pointsAtStake
    ;(stats:FindFirstChild("Streak") :: IntValue).Value = row.currentStreak
end

local function fireProfile(player: Player, source: string)
    local row = profiles:get(tostring(player.UserId))
    if row then
        ProfileUpdate:FireClient(player, {
            totalPoints = row.totalPoints,
            pointsAtStake = row.pointsAtStake,
            currentStreak = row.currentStreak,
            stakingStreak = row.stakingStreak,
            bestStreak = row.bestStreak,
            source = source,
        })
    end
end

local function playerByUserId(userId: string): Player?
    for _, p in Players:GetPlayers() do
        if tostring(p.UserId) == userId then
            return p
        end
    end
    return nil
end

local coordinator = RoundCoordinator.new({
    net = net,
    clock = clock,
    buffer = ThrowBuffer.new(),
    rules = GameRules,
    log = print,
    random = math.random,
    now = deps.now,
    instanceId = if game.JobId ~= "" then game.JobId else "studio-local",
    callbacks = {
        onRound = function(info)
            RoundUpdate:FireAllClients(info)
        end,
        onReveal = function(reveal)
            for _, player in Players:GetPlayers() do
                local mine = reveal.results[tostring(player.UserId)]
                RevealResult:FireClient(player, {
                    worldThrow = reveal.worldThrow,
                    distribution = reveal.distribution,
                    totalPlayers = reveal.totalPlayers,
                    pick = mine and mine.pick,
                    result = mine and mine.result,
                })
                if mine then
                    profiles:applyLocalResult(tostring(player.UserId), mine.result)
                    pushStats(player)
                    fireProfile(player, "local")
                end
            end
        end,
        onReconciled = function(rows)
            for _, row in rows do
                profiles:applyServer(row.robloxUserId, {
                    totalPoints = row.totalPoints,
                    pointsAtStake = row.pot,
                    currentStreak = row.streak,
                    stakingStreak = row.streak,
                    bestStreak = math.max(row.streak, (profiles:get(row.robloxUserId) or { bestStreak = 0 }).bestStreak),
                })
                local player = playerByUserId(row.robloxUserId)
                if player then
                    pushStats(player)
                    fireProfile(player, "reconciled")
                end
            end
        end,
    },
})

Players.PlayerAdded:Connect(function(player)
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    for _, name in { "Points", "Pot", "Streak" } do
        local v = Instance.new("IntValue")
        v.Name = name
        v.Parent = stats
    end
    stats.Parent = player

    task.spawn(function()
        local country: string? = nil
        pcall(function()
            country = LocalizationService:GetCountryRegionForPlayerAsync(player)
        end)
        local res = net:getPlayer(tostring(player.UserId), country)
        if res.ok then
            profiles:applyServer(tostring(player.UserId), {
                totalPoints = res.data.totalPoints,
                pointsAtStake = res.data.pointsAtStake,
                currentStreak = res.data.currentStreak,
                stakingStreak = res.data.stakingStreak,
                bestStreak = res.data.bestStreak,
            })
            pushStats(player)
            fireProfile(player, "sync")
        else
            warn(`[PROFILE] sync failed for {player.UserId}: {res.error or res.status}`)
        end
    end)
end)

SubmitPick.OnServerEvent:Connect(function(player, throwValue)
    if type(throwValue) ~= "string" then
        return
    end
    local accepted, reason = coordinator:submitPick(tostring(player.UserId), throwValue)
    if not accepted then
        print(`[PICK] {player.Name} rejected: {reason}`)
    end
end)

BankRequest.OnServerEvent:Connect(function(player)
    task.spawn(function()
        local res = net:postBank(tostring(player.UserId))
        if res.ok then
            profiles:applyServer(tostring(player.UserId), {
                totalPoints = res.data.totalPoints,
                pointsAtStake = res.data.pointsAtStake,
                currentStreak = res.data.currentStreak,
                stakingStreak = res.data.stakingStreak,
                bestStreak = (profiles:get(tostring(player.UserId)) or { bestStreak = 0 }).bestStreak,
            })
            pushStats(player)
            fireProfile(player, "banked")
        end
    end)
end)

print(`[ROSHAMBO] playable loop starting against {config.baseUrl}`)
task.spawn(function()
    while true do
        local delay = coordinator:pollOnce()
        task.wait(delay)
    end
end)
```

- [ ] **Step 3: Verify** — `rojo build -o build.rbxl` exits 0; `lune run tests/run` still `73 passed`; `stylua --check src tests`; `selene src` (Player/Instance/IntValue/Folder/RemoteEvent globals must lint clean under std="roblox").

- [ ] **Step 4: Commit** — `git add roblox/default.project.json roblox/src/server/main.server.luau && git commit -m "feat(roblox): remotes contract + server composition v2 - players, leaderstats, bank"`

### Task 6: Client pick UI

**Files:**
- Create: `roblox/src/client/main.client.luau`

Roblox-runtime only (no Lune tests; Task 7's live session is the verification). Functional placeholder visuals — theater is milestone 4.

- [ ] **Step 1: Create `roblox/src/client/main.client.luau`:**

```lua
--!strict
-- Playable-loop UI: phase/countdown, R/P/S pick buttons, reveal text, bank button.
-- Placeholder visuals; arena theater arrives in milestone 4.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local THROWS = { "R", "P", "S" }
local LABELS = { R = "🪨 Rock", P = "📄 Paper", S = "✂️ Scissors" }

local function makeLabel(name: string, pos: UDim2, size: UDim2, textSize: number): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Position = pos
    l.Size = size
    l.AnchorPoint = Vector2.new(0.5, 0)
    l.BackgroundTransparency = 0.4
    l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextSize = textSize
    l.Font = Enum.Font.GothamBold
    l.Parent = gui
    return l
end

local statusLabel = makeLabel("Status", UDim2.new(0.5, 0, 0, 8), UDim2.new(0, 420, 0, 36), 20)
local resultLabel = makeLabel("Result", UDim2.new(0.5, 0, 0.35, 0), UDim2.new(0, 520, 0, 48), 28)
resultLabel.Visible = false
local walletLabel = makeLabel("Wallet", UDim2.new(0.5, 0, 0, 48), UDim2.new(0, 420, 0, 26), 16)
walletLabel.Text = "Points 0 | Pot 0 | Streak 0"

local buttons: { [string]: TextButton } = {}
local myPick: string? = nil
local canPick = false
local lockoutAt: number? = nil -- os.clock() deadline

local function refreshButtons()
    for value, b in buttons do
        if value == myPick then
            b.BackgroundColor3 = Color3.fromRGB(40, 110, 255)
        elseif canPick then
            b.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        else
            b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        end
        b.AutoButtonColor = canPick
    end
end

for i, value in THROWS do
    local b = Instance.new("TextButton")
    b.Name = value
    b.Size = UDim2.new(0, 130, 0, 56)
    b.AnchorPoint = Vector2.new(0.5, 1)
    b.Position = UDim2.new(0.5, (i - 2) * 145, 1, -24)
    b.Text = LABELS[value]
    b.TextSize = 20
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Parent = gui
    b.MouseButton1Click:Connect(function()
        if canPick then
            myPick = value
            refreshButtons()
            SubmitPick:FireServer(value)
        end
    end)
    buttons[value] = b
end

local bankButton = Instance.new("TextButton")
bankButton.Name = "Bank"
bankButton.Size = UDim2.new(0, 160, 0, 44)
bankButton.AnchorPoint = Vector2.new(1, 1)
bankButton.Position = UDim2.new(1, -16, 1, -24)
bankButton.Text = "BANK"
bankButton.TextSize = 18
bankButton.Font = Enum.Font.GothamBold
bankButton.TextColor3 = Color3.fromRGB(20, 20, 20)
bankButton.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
bankButton.Visible = false
bankButton.Parent = gui
bankButton.MouseButton1Click:Connect(function()
    BankRequest:FireServer()
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        canPick = true
        myPick = nil
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
    else
        canPick = false
        lockoutAt = nil
        statusLabel.Text = `Round {info.roundCount} — {info.phase}…`
    end
    refreshButtons()
end)

RevealResult.OnClientEvent:Connect(function(r)
    canPick = false
    refreshButtons()
    local headline: string
    if r.result == "WIN" then
        headline = `🏆 WIN! World threw {r.worldThrow}`
    elseif r.result == "SAFE" then
        headline = `🛡 SAFE — world matched your {r.pick}`
    elseif r.result == "LOSS" then
        headline = `💥 LOSS — world threw {r.worldThrow}`
    else
        headline = `World threw {r.worldThrow}`
    end
    resultLabel.Text = `{headline}  (R {r.distribution.R}% P {r.distribution.P}% S {r.distribution.S}%)`
    resultLabel.Visible = true
    task.delay(4, function()
        resultLabel.Visible = false
    end)
end)

ProfileUpdate.OnClientEvent:Connect(function(p)
    walletLabel.Text = `Points {p.totalPoints} | Pot {p.pointsAtStake} | Streak {p.currentStreak}`
    bankButton.Visible = p.pointsAtStake > 0
    bankButton.Text = `BANK {p.pointsAtStake}`
end)

task.spawn(function()
    while true do
        if canPick and lockoutAt then
            local left = lockoutAt - os.clock()
            if left <= 0 then
                canPick = false
                refreshButtons()
                statusLabel.Text = "Locked — waiting for the world…"
            else
                statusLabel.Text = `Pick now! Locks in {math.ceil(left)}s`
            end
        end
        task.wait(0.25)
    end
end)
```

- [ ] **Step 2: Verify** — `rojo build -o build.rbxl` exits 0; `stylua --check src tests` clean; `selene src` clean; `lune run tests/run` still 73.

- [ ] **Step 3: Commit** — `git add roblox/src/client/ && git commit -m "feat(roblox): pick UI - countdown, R/P/S buttons, reveal text, bank button"`

### Task 7: Live verification (USER-INTERACTIVE — controller hands to the human)

Prereqs: local backend running, `rojo serve` running, HttpEnabled set (edit mode!).

- [ ] Studio: connect Rojo, Play. Expect the new UI (status bar, three buttons, wallet line).
- [ ] During ACTIVE: countdown shows "Locks in Ns"; click a throw → button highlights; re-click another before lockout → switches.
- [ ] TEST_MODE cheat: world cycles R→P→S by roundCount, so you can win on purpose (beat the *next* throw in the cycle).
- [ ] At reveal: result line appears (WIN/SAFE/LOSS + world throw + distribution); Pot/Streak update optimistically; ~a second into the next round the reconciled values arrive (leaderstats should not visibly change if local math matched the server — that's the contract working).
- [ ] After a WIN: BANK button shows the pot; click it → Points absorbs the pot, Pot zeroes.
- [ ] Check the server Output for `[FLUSH]`-free happy path, `[RECON] round X: 1 row(s)` each played round.
- [ ] Also verify in the PWA (http://localhost:5173) that the same rounds tick — both clients in one world.
- [ ] Report any deviation.

### Task 8: Docs

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1:** In the Roblox client architecture section of CLAUDE.md, append: "Milestone 3 adds the playable loop: picks flow client→`SubmitPick` RemoteEvent→`RoundCoordinator:submitPick`→`ThrowBuffer`→delta-flushed to `POST /api/v1/throws` (5s cadence / 10 picks / final flush at the T₀−2s lockout). Reveals are computed locally from the mirrored GameRules and reconciled next round via `GET /instances/.../results` (authoritative overwrite in `PlayerProfiles`). RemoteEvents contract lives in `default.project.json` (`RoshamboRemotes`)."
- [ ] **Step 2:** Commit — `git add CLAUDE.md && git commit -m "docs: milestone 3 playable-loop notes in CLAUDE.md"`

---

## Out of Scope (later milestones)

- Arena theater: grow/anvil/shimmer, pedestals, World Record holo, wind-up emotes (milestone 4)
- DEV/production places, Open Cloud publishing, HttpService:GetSecret (milestone 5)
- Tape/history UI, stats views, character cosmetics

## Verification at the End

```bash
cd roblox && lune run tests/run && stylua --check src tests && selene src && rojo build -o build.rbxl
cd ../server && npm test
```
Expected: 73 Lune tests, 82 server tests, all green; plus Task 7's live playable session and green CI after push.
