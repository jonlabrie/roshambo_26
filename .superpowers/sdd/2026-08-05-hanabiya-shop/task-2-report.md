# Task 2 report: buying a shell refreshes the count

## Anchor found

`RequestPurchase.OnServerEvent:Connect(function(player, payload) ... end)` starts at
`roblox/src/server/main.server.luau:1353`. The success path's `echoEconomy(player, uid)`
call — the one that runs at the end of the handler, immediately before
`recomputeAllAccess()` and the two closing `end)`s — was at line **1519**:

```lua
        echoEconomy(player, uid)
        -- re-push access gates: a mid-session claim or size upgrade changes occupancy/deck geometry
        recomputeAllAccess()
    end)
end)
```

(There are other `echoEconomy(player, uid)` calls inside this same handler at lines 1376,
1384, and 1412, but those all sit on early-return error/short-circuit paths, not the
handler's terminal success path — the brief's "the handler ends its success path with an
`echoEconomy(player, uid)` call" identifies line 1519.)

## Item local

The handler's existing local holding the requested item string is named `item`, bound at
line 1360:

```lua
local item = if typeof(payload) == "table" then payload.item else nil
```

No second local was introduced; the inserted code reads this existing `item`.

## Inserted code

Immediately after the line-1519 `echoEconomy(player, uid)` call, before
`recomputeAllAccess()`:

```lua
        echoEconomy(player, uid)
        -- Buying a shell changes a COUNT, and the count lives in FireworkState, not
        -- EconomyState. Without this the balance drops and the picker keeps reading the old
        -- number until the next reveal happens to push state for its own reasons — which
        -- reads as the purchase having failed.
        if typeof(item) == "string" and (item:sub(1, 9) == "firework:" or item:sub(1, 7) == "mortar:") then
            if pushFireworkState then
                pushFireworkState(player)
            end
        end
        -- re-push access gates: a mid-session claim or size upgrade changes occupancy/deck geometry
        recomputeAllAccess()
```

`pushFireworkState` is the forward-declared local (`local pushFireworkState: ((Player) -> ())? = nil`
at line 323, assigned at line 827); the `if pushFireworkState then` guard is required by its
optional type and was kept as instructed, not stripped as "defensive noise."

This is the only change in the file — one guarded call added, no other lines touched, no
new locals.

## Lint output

```
$ stylua src tests tools && stylua --check src tests tools && selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

Clean — stylua made no formatting changes (the inserted block was already correctly
formatted), the `--check` re-run confirmed no diff, and selene reported zero
errors/warnings across `src` and `tools`.

## Test output

```
$ lune run tests/run
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: .../roblox/tests/HandlerQueue.spec:80: boom

1048 passed, 0 failed, 1048 total
```

All 1048 tests pass. The two `[WARN]` lines are expected output from
`HandlerQueue.spec` deliberately exercising a full-queue drop and a handler-error path —
not failures, and not related to this change.

## What this does NOT prove

No harness in this repo loads `main.server.luau`, so `lune run tests/run` never touches
the `RequestPurchase` handler or `pushFireworkState` at all. The green run proves this
change did not regress any of the pure modules under test (`GameRules`, `HandlerQueue`,
etc.) — it proves **nothing** about whether buying a firework or mortar actually causes
the picker's count to refresh in a live client. That behaviour (balance drops AND the
picker's count updates immediately after a `firework:`/`mortar:` purchase, without waiting
for the next reveal) is unverified and is a **Studio-gate item**.

## Commit

```
git add roblox/src/server/main.server.luau
git commit -m "fix(roblox): buying a shell refreshes the count, not just the balance"
```
