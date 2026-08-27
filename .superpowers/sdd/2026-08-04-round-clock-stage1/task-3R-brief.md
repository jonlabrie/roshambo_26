### Task 3R: Throws open late, never early

**Files:**
- Modify: `roblox/src/client/main.client.luau`

**Context:** This stage inverts a failure mode, which is why it gets its own diff.

The phase used to arrive **late**, so throws opened late and a player quietly lost a second. Derived
locally it can arrive **early** if the clock or schedule is off — and a pick made before the
server's round has opened is buffered against a round that has not started. The server's own guards
(`RoundCoordinator:submitPick`, the API's phase gate) mean it cannot corrupt a result, but it can
swallow a player's first tap: the fault nobody reports and everybody feels.

- [ ] **Step 1: Require agreement before opening**

Throws open only when the locally-derived phase says `ACTIVE` **and** the last `RoundUpdate` has
confirmed the same round. Write it so disagreement fails **shut**. Losing 200ms of throwing time is
invisible; a swallowed first tap is not.

Comment the reasoning — the condition will look redundant and invite simplification.

- [ ] **Step 2: Trace and report each case**

1. local ACTIVE, `RoundUpdate` confirms the same round → open
2. local ACTIVE, `RoundUpdate` still on the previous round → shut
3. local ACTIVE early by 500ms → opens 500ms late, never early
4. no schedule at all → identical to today
5. the lockout arrives → closes, unchanged
6. `sendAtLockout` still fires inside the server's window → **the pick reaches the wire**

Case 6 is the one that was broken before and must be stated explicitly.

- [ ] **Step 3: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/main.client.luau
git commit -m "fix(roblox): a local clock may open throws late, never early"
```
