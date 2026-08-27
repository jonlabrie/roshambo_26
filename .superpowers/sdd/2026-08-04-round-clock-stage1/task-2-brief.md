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

