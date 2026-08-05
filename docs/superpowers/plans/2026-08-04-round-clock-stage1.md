# Round Structure Stage 1 — the HUD reads the clock, not the poll

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase changes and the countdown reach players on schedule instead of ~2s late, by reading the round's published timeline rather than waiting for a poll to notice.

**Architecture:** The timeline already exists. `RoundScheduleConfig` (in `ReplicatedStorage`) carries the round's absolute schedule on the `GetServerTimeNow` clock, and `RoundMetronome` is a pure, slew-not-snap reader of it — but it only yields the bell cam's angle, and only `HammerController` consumes it. This stage teaches it the phase and moves the HUD's round state onto it, leaving `RoundUpdate` as the corrector rather than the driver.

**Tech Stack:** Luau, Rojo, Lune test harness.

**Spec:** `docs/superpowers/specs/2026-08-04-round-structure-design.md` §3 and §4 stage 1.

**Scope:** Stage 1 only. It changes **no wire format, no phase names, and no server code.** Stages 2–4 (push transport, the OPEN/LOCK/REVEAL restructure, the ceremony) get their own plans.

## Global Constraints

- **No automated gate loads any client file.** `lune run tests/run` never loads a `.client.luau`; `selene` does not resolve cross-module field types; `stylua` only formats. Reading is the gate. And **a property's value is not a rendered pixel, and a green suite is not a working round** — both mistakes have already cost this project a full round of work.
- **`src/shared` modules hold no Roblox globals** — no `Instance`, `Enum`, `task`, `os`, `workspace`, `game`. `RoundMetronome` is pure and clock-agnostic (callers pass `now` in seconds) and must stay that way; that is what lets it be tested at all.
- **The server stays authoritative.** This stage changes only *when the client learns* a phase it would have learned anyway. If the local timeline and the server ever disagree, the server wins.
- **Throws must never open locally before they open on the server.** See Task 3 — this is the one way this stage could cost a player a round.
- Every local declared above its first use; a forward reference resolves to a nil global.
- selene fails on warnings.
- Gates green: from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox` run `lune run tests/run`, `stylua --check src tests tools`, `selene src tools`.
- Use **absolute paths** in every Bash call; the working directory persists between calls.

---

### Task 1: The metronome knows what phase it is

**Files:**
- Modify: `roblox/src/shared/RoundMetronome.luau`
- Test: `roblox/tests/RoundMetronome.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Task 2: two new fields on `Reading` —
  - `phase: string` — `"ACTIVE"` | `"TALLY"` | `"REVEAL"`
  - `secondsLeft: number` — seconds until the next phase boundary
- Everything already on `Reading` (`drawP`, `camAngle`, `omega`, `periodSec`, `prevStrikeAt`, `nextStrikeAt`) is unchanged. `HammerController` must keep working untouched.

**Context:** `read()` already computes everything needed. It derives `roundStart` (the strike, less `activeSec + tallySec`, snapped into the current period) and `drawP` (position through the period, 0–1). The phase is that position measured against the three durations. This is arithmetic the module already does; it just doesn't report it.

The phase layout within a period, measured from `roundStart`:

```
[0, activeSec)                          ACTIVE
[activeSec, activeSec+tallySec)         TALLY
[activeSec+tallySec, periodSec)         REVEAL     <- the strike is at its first instant
```

- [ ] **Step 1: Write the failing tests**

Add to `roblox/tests/RoundMetronome.spec.luau`. Follow the file's existing style for constructing a metronome and setting a schedule.

```lua
describe("RoundMetronome — the phase, read off the same timeline as the cam", function()
    -- A 27s round: 20 active, 2 tally, 5 reveal, with the strike at the first
    -- instant of REVEAL (activeSec + tallySec into the period), which is how
    -- RoundCoordinator publishes it.
    local function m27()
        local m = RoundMetronome.new()
        m:setSchedule({
            roundId = "r1",
            strikeAt = 1000,
            periodSec = 27,
            activeSec = 20,
            tallySec = 2,
            revealSec = 5,
        }, 1000)
        return m
    end

    test("the strike instant is the first instant of REVEAL", function()
        -- This is the anchor the whole timeline hangs off. If it drifts, every
        -- phase boundary drifts with it.
        expect(m27():read(1000).phase).toBe("REVEAL")
    end)

    test("it walks the period in order", function()
        local m = m27()
        local roundStart = 1000 - 22 -- strike less (active + tally)
        expect(m:read(roundStart).phase).toBe("ACTIVE")
        expect(m:read(roundStart + 19.9).phase).toBe("ACTIVE")
        expect(m:read(roundStart + 20).phase).toBe("TALLY")
        expect(m:read(roundStart + 21.9).phase).toBe("TALLY")
        expect(m:read(roundStart + 22).phase).toBe("REVEAL")
        expect(m:read(roundStart + 26.9).phase).toBe("REVEAL")
    end)

    test("boundaries are half-open — a phase owns its start, not its end", function()
        -- Closed-closed would make one instant belong to two phases, and whichever
        -- the caller sampled first would win. That is the kind of ambiguity that
        -- shows up once an hour and is never reproducible.
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart + 20).phase).toBe("TALLY")
        expect(m:read(roundStart + 22).phase).toBe("REVEAL")
        expect(m:read(roundStart + 27).phase).toBe("ACTIVE") -- the next round
    end)

    test("it repeats every period, forwards and backwards", function()
        local m = m27()
        local roundStart = 1000 - 22
        for _, k in { -3, -1, 0, 1, 5 } do
            local base = roundStart + k * 27
            expect(m:read(base + 1).phase).toBe("ACTIVE")
            expect(m:read(base + 21).phase).toBe("TALLY")
            expect(m:read(base + 23).phase).toBe("REVEAL")
        end
    end)

    test("secondsLeft counts down to the NEXT boundary, not the round's end", function()
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart).secondsLeft).toBeCloseTo(20, 0.001)
        expect(m:read(roundStart + 19).secondsLeft).toBeCloseTo(1, 0.001)
        expect(m:read(roundStart + 20).secondsLeft).toBeCloseTo(2, 0.001) -- TALLY's whole length
        expect(m:read(roundStart + 22).secondsLeft).toBeCloseTo(5, 0.001) -- REVEAL's
    end)

    test("secondsLeft is never negative and never exceeds its phase", function()
        local m = m27()
        local roundStart = 1000 - 22
        for i = 0, 270 do
            local r = m:read(roundStart + i / 10)
            expect(r.secondsLeft >= 0).toBe(true)
            expect(r.secondsLeft <= 20).toBe(true)
        end
    end)

    test("no schedule, no phase", function()
        -- read() already returns nil before a schedule lands; the new fields must
        -- not tempt a caller into treating an unsynced client as being mid-round.
        expect(RoundMetronome.new():read(100)).toBeNil()
    end)
end)
```

- [ ] **Step 2: Run and watch them fail**

`cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox && lune run tests/run`
Expected: FAIL — `phase` and `secondsLeft` are nil.

- [ ] **Step 3: Implement**

In `read()`, after `roundStart` and `drawP` are computed, derive the phase from the elapsed position and return the two new fields. Add them to the `Reading` type.

```lua
    -- THE PHASE, off the same timeline as the cam above — not a second source of
    -- truth. `elapsed` is where `now` sits inside the round that contains it, so
    -- the phase is that position measured against the three durations.
    --
    -- HALF-OPEN boundaries: a phase owns its start instant and not its end. Closed
    -- intervals would make the boundary belong to two phases at once, and whichever
    -- a caller sampled first would win.
    local elapsed = now - roundStart
    local activeEnd = self._activeSec
    local tallyEnd = activeEnd + self._tallySec
    local phase, phaseEndsAt
    if elapsed < activeEnd then
        phase, phaseEndsAt = "ACTIVE", activeEnd
    elseif elapsed < tallyEnd then
        phase, phaseEndsAt = "TALLY", tallyEnd
    else
        phase, phaseEndsAt = "REVEAL", period
    end
```

and return `phase = phase, secondsLeft = math.max(0, phaseEndsAt - elapsed)`.

Read the existing locals before writing this — `roundStart`, `period` and the stored `_activeSec` / `_tallySec` are all already in scope in `read()`. Do not recompute them.

- [ ] **Step 4: Run, then prove the tests bite**

`lune run tests/run` — expected: PASS.

Then mutate and confirm failures, restoring after each:
1. change `elapsed < activeEnd` to `elapsed <= activeEnd` → the half-open test must fail
2. return `period - elapsed` for `secondsLeft` in every branch (the round's end rather than the phase's) → the countdown test must fail
3. swap the `ACTIVE` and `REVEAL` labels → the walk test must fail

Quote the real failure output. **If any mutation does not fail, that test is decoration — say so rather than moving on.**

- [ ] **Step 5: Confirm nothing regressed for the bell**

`HammerController` reads `drawP`, `camAngle`, `omega` and the strike instants. Confirm none of those computations changed and that every pre-existing test in the spec file still passes untouched.

- [ ] **Step 6: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RoundMetronome.luau roblox/tests/RoundMetronome.spec.luau
git commit -m "feat(roblox): the round's timeline can say what phase it is"
```

---

### Task 2: The HUD's clock comes from the timeline

**Files:**
- Modify: `roblox/src/client/main.client.luau`

**Interfaces:**
- Consumes: `Reading.phase` and `Reading.secondsLeft` from Task 1; `RoundScheduleConfig` from `ReplicatedStorage`.
- Produces: nothing new on the wire.

**Context:** `main.client.luau` currently takes `phase` and the countdown from the `RoundUpdate` remote, which the Roblox server fires when its 1–1.25s poll *notices* a change. That is the ~2s lag — a fresh countdown reads 18 instead of 20.

`RoundScheduleConfig` lives in `ReplicatedStorage` and carries the schedule on the `GetServerTimeNow` timeline, which is already synchronised across Roblox clients. `HammerController` reads it exactly this way (`ReplicatedStorage:WaitForChild("RoundScheduleConfig")`) — copy that pattern.

**`RoundUpdate` does not go away.** It remains authoritative for round identity and as the correction when the local timeline is wrong or absent. This task changes which of the two drives the countdown.

- [ ] **Step 1: Build the local timeline**

Add a `RoundMetronome` instance fed from `RoundScheduleConfig`'s attributes, refreshed on `AttributeChanged`. Mirror `HammerController`'s reading of the same attributes — including its defaults — so the two cannot disagree about the schedule they are both reading.

**Do not duplicate the attribute names as literals in a second place if `HammerController` already names them;** if extracting them is more than a few lines, note it in your report rather than doing it here.

- [ ] **Step 2: Drive phase and secondsLeft from the reading**

Replace the `RoundUpdate`-sourced `phase` and the `secondsLeft()` helper with values read from `metronome:read(workspace:GetServerTimeNow())` on the existing heartbeat.

**Three rules, all load-bearing:**

1. **No schedule, no local clock.** `read()` returns nil until a schedule lands. In that state fall back to exactly today's behaviour — the last `RoundUpdate` — so a client that joins mid-round, or whose schedule never arrives, degrades to what it does now rather than to a blank HUD.
2. **`RoundUpdate` still wins on identity.** Round id, and anything derived from the server's own view of the round, keep coming from the remote. Only the phase and the countdown move.
3. **Reconcile, do not fight.** When `RoundUpdate` reports a phase the local timeline disagrees with, the server is right: take its phase and let the metronome's own slew pull the timeline back. Do not snap the schedule from inside this file — `RoundMetronome` owns slewing and already does it.

- [ ] **Step 3: The standing check for client files**

Nothing loads this file. Verify by reading:

1. Every `Reading.X` read resolves to a field Task 1 actually returns. Name them.
2. `workspace:GetServerTimeNow()` is the clock passed to `read()` — **not** `os.clock()` or `tick()`. The schedule is published on the `GetServerTimeNow` timeline and mixing clocks would put the phase off by however long the server has been up.
3. Every new local is declared above its first use.
4. The nil-reading fallback path is reachable and correct — trace a client joining mid-round.
5. Nothing else that used to read `info.phase` was left reading a now-stale local.

- [ ] **Step 4: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/main.client.luau
git commit -m "feat(roblox): the countdown starts at twenty"
```

---

### Task 3: Throws cannot open before the server's round does

**Files:**
- Modify: `roblox/src/client/main.client.luau` (the throw gate)

**Interfaces:**
- Consumes: Task 2's locally-derived phase.
- Produces: nothing.

**Context:** This is the one way this stage could cost a player a round, and it deserves its own task rather than a line in the previous one.

The HUD's throw buttons are enabled on `phase == "ACTIVE"`. Until now that phase arrived *late*, so the buttons opened late and a player simply lost a couple of seconds. With a local timeline the phase can now arrive **early** if the client's clock or schedule is off — and a pick made before the server's round has opened is buffered against a round id that has not started, where it is either rejected or, worse, attributed to the previous round.

The server has its own guards (`RoundCoordinator:submitPick`, and the API's phase gate), so this cannot corrupt a result. But it can silently swallow a player's first tap, which is exactly the kind of fault nobody reports and everybody feels.

- [ ] **Step 1: Gate the throw window on agreement**

Enable throws only when the locally-derived phase says `ACTIVE` **and** the last `RoundUpdate` has not contradicted it — i.e. the client has server confirmation that the round it is about to throw into is the one that is open.

Write the condition so the failure mode is *late*, never *early*: if the two sources disagree, throws stay closed until they agree. Losing 200ms of throwing time is invisible; a swallowed first tap is not.

Comment it with that reasoning. The next person will see a redundant-looking condition and be tempted to simplify it.

- [ ] **Step 2: Confirm the lockout is unaffected**

`secondsToLockout` is computed on the Roblox **server** from its own synced clock and sent in `RoundUpdate`. It is not derived from the metronome and must not become so in this stage. Confirm the lockout path is untouched, and that the throw gate still closes at the lockout exactly as it does today.

- [ ] **Step 3: The standing check, and trace the hazard**

State explicitly what happens in each case:
1. local timeline says ACTIVE, `RoundUpdate` has confirmed the same round — throws open
2. local says ACTIVE, `RoundUpdate` still reports the previous round — throws stay shut
3. local says ACTIVE early by 500ms — throws open 500ms late, not early
4. no schedule at all — behaviour identical to today
5. the lockout arrives — throws close, unchanged

- [ ] **Step 4: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/main.client.luau
git commit -m "fix(roblox): a local clock may open throws late, never early"
```

---

## After the last task

Hand back for the owner's Studio gate. What needs eyes:

- **Does a fresh countdown start at 20?** That is the whole stage in one observation. 18 means the HUD is still on the poll.
- Do the phase changes land on the bell rather than a beat after it? The bell is already clock-scheduled, so the two should now agree — if the countdown hits 0 visibly before or after the bell, the timeline and the strike anchor disagree.
- Are throws available for the full window, and do they still close at the lockout?
- A client joining **mid-round** — does the HUD behave, or is there a blank beat before the schedule lands?

**Do not push without telling the owner** — every push to `m4b-zendojo-art-pass` auto-deploys the dev App Runner service under any live Studio session.

**Not in this stage:** the world-throw push, the OPEN/LOCK/REVEAL restructure, and the reveal ceremony. Each gets its own plan against the same spec.
