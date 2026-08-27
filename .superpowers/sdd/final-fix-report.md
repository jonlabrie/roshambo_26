# Final whole-feature review fixes — teahouse access control

**Status:** COMPLETE. All 3 fixes applied, verified, and committed.

**Commit:** `7d36e59` — "fix(roblox): re-push access gates on mid-session claim + display resize"
(branch `m4b-zendojo-art-pass`, 1 file changed, 8 insertions(+), 1 deletion(-))

## Scope confirmation

Read `roblox/src/server/main.server.luau` top-down around the relevant sections before editing.
- `local function recomputeAllAccess()` — defined at line 608.
- `local function pushAccessState(player: Player, uid: string, notice: string?)` — defined at line 670.
- `RequestPurchase.OnServerEvent:Connect(...)` handler — originally started at line 868 (well after both function defs).
- `SetDisplay.OnServerEvent:Connect(...)` handler — originally started at line 1038 (well after both function defs).

Both `recomputeAllAccess` and `pushAccessState` are file-scope `local function`s defined
before either handler, so both handlers had them in scope. No forward-reference issues.

## The 3 edits

### Fix 1 — RequestPurchase: re-push after claim/upgrade-rebuild
Landed immediately after the handler's terminal `echoEconomy(player, uid)` (originally at
line 1034), immediately before the callback's closing `end)`:

```lua
        echoEconomy(player, uid)
        -- re-push access gates: a mid-session claim or size upgrade changes occupancy/deck geometry
        recomputeAllAccess()
    end)
end)
```

### Fix 2 — SetDisplay: re-push after display-size rebuild
Landed immediately after the handler's terminal `echoEconomy(player, uid)` (originally at
line 1108), immediately before the callback's closing `end)`:

```lua
        echoEconomy(player, uid)
        -- re-push access gates: display resize changes deck footprint -> gate geometry
        recomputeAllAccess()
    end)
end)
```

### Fix 3 — pushAccessState: move presence recheck to guard the FireClient yield-consumer
Original top guard combined the cheap check with `IsDescendantOf` before the yielding
`resolveName` loop, so it didn't guard against the player leaving during that yield. Changed to:

```lua
local function pushAccessState(player: Player, uid: string, notice: string?)
    local e = playerEconomy[uid]
    if e == nil or e.teahouseAccess == nil then
        return
    end
    local invited = {}
    for _, id in e.teahouseAccess.invited do
        table.insert(invited, { userId = id, name = resolveName(id) })
    end
    if not player:IsDescendantOf(Players) then
        return
    end
    AccessState:FireClient(player, { mode = e.teahouseAccess.mode, invited = invited, notice = notice })
end
```

This mirrors the post-yield `IsDescendantOf` discipline already used by SetAccess/InviteUser/RevokeUser.

## Verification (run from `roblox/`)

1. `lune run tests/run`
   Result: **472 passed, 0 failed, 472 total.** (Two `[WARN]` lines are expected output from
   `HandlerQueue.spec` intentionally exercising queue-full/handler-error paths — not failures.)

2. `rojo build -o /tmp/ac-finalfix-check.rbxl`
   Result: **Succeeded** — "Building project 'roshambo-roblox'" / "Built project to
   ac-finalfix-check.rbxl", exit 0. Confirms the edited runtime file parses.

3. `stylua --check src tests && selene src`
   Result: **Clean.** stylua exit 0 (no reformat needed); selene reported "0 errors, 0 warnings,
   0 parse errors", exit 0.

## Deviations

None. Both `echoEconomy` insertion points and the `pushAccessState` guard restructuring
matched the review's description exactly once read in context; no ambiguity encountered.

## Concerns

None outstanding. This is a visual-desync fix only — the server region backstop was already
authoritative and unaffected by these changes. No other files were touched; `git diff --stat`
and the commit both confirm only `roblox/src/server/main.server.luau` changed.

Note: this report file previously held content from an earlier, unrelated fix task
(decoration buy/ghost-drag decoupling) — it has been overwritten with this task's report.
