# Task 6 report: the shop panel

## Status: DONE

Commit: `aa5dec8c9c482528a84f56bf1a7b594e24b70977`

## What was done

- `roblox/src/client/EventBus.luau`: added `"ShopPurchase"` to `NAMES`, right after `"HudFireworkLaunch"`, with the comment specified in the brief.
- `roblox/src/server/main.server.luau`: added the threshold-tagging `do...end` block at file scope, placed after the existing spawn-location self-heal loop (line ~137) and before `local deps = {`. Confirmed before editing that `CollectionService` was already a local (line 54, from the fireworks referee) and `stage` was already bound (line 120, `workspace:WaitForChild("RoshamboStage")`) — used both as-is, added no duplicate locals.
- `roblox/src/client/ShopController.client.luau`: created, matching the brief's Step 3 code **with one deviation**: removed the unused `local INK = Color3.fromRGB(60, 45, 28)` constant. As given verbatim, it is never referenced anywhere in the file (only `INK_CREAM` is used for text color), and `selene` fails with `unused_variable` on it, which violates the task's own zero-warnings gate. Everything else in the controller is verbatim from the brief, including the `ZIndexBehavior = Enum.ZIndexBehavior.Sibling` line and the tag-based threshold lookup with the `GetInstanceAddedSignal` replication-race handler.

## Gate results (run from `roblox/`)

- `lune run tests/run` → **1070 passed, 0 failed, 1070 total** (two harmless `[WARN]` lines from an unrelated pre-existing HandlerQueue queue-overflow test scenario, not related to this task).
- `stylua --check src tests tools` → clean, exit 0.
- `selene src tools` → **0 errors, 0 warnings, 0 parse errors**.

Summary: tests pass, lint clean, zero warnings.

## Step 5 leak check — verbatim output

Command:
```
grep -rnE "= *(1|3|4|6|40|250|1000) *$|NEEDS_MORTAR|lastWorldThrow" src/client/ShopController.client.luau
```

Output (NOT empty — 8 lines):
```
src/client/ShopController.client.luau:74:stroke.Thickness = 1
src/client/ShopController.client.luau:81:title.BackgroundTransparency = 1
src/client/ShopController.client.luau:92:balance.BackgroundTransparency = 1
src/client/ShopController.client.luau:102:list.BackgroundTransparency = 1
src/client/ShopController.client.luau:129:    t.BackgroundTransparency = 1
src/client/ShopController.client.luau:140:    s.BackgroundTransparency = 1
src/client/ShopController.client.luau:157:        order += 1
src/client/ShopController.client.luau:161:        order += 1
```

Every hit is the substring `= 1` at end of line, matched by the `(1|...)` alternative of the pattern. Verified with `grep -noE "= *(1|3|4|6|40|250|1000) *$"` that all 8 matches are literally `= 1`. None are `NEEDS_MORTAR` or `lastWorldThrow`, and none are the price literals 3, 4, 6, 40, 250, or 1000. Manually confirmed each source line: they are cosmetic UI properties (`UIStroke.Thickness = 1`, `TextLabel/Frame.BackgroundTransparency = 1`) and a `LayoutOrder` loop counter (`order += 1`), not shop prices or requirement comparisons. No literal price or affordability/requirement logic exists anywhere in the file — `prices`, `mortarPrices`, `points`, `shells`, and `ownedMortars` are all populated exclusively from `EconomyState`/`FireworkState` server payloads, and the only comparisons against them (`points >= price`, `price == nil`, `ownedMortars[key]`) are display-only (dimming a row), not gates on the actual purchase — the purchase itself is an unconditional `RequestPurchase:FireServer({ item = item })` on click, for the server to accept or refuse.

Conclusion: the pattern as given is imprecise (it fires on any line ending in `= 1`, `= 3`, etc., regardless of context) but no actual leak is present in this file.

## What "tested" does NOT mean here

`lune run tests/run` exercises only the pure Lune-loadable modules (`ShopThreshold.luau` and the rest of `shared/`). It does not load `ShopController.client.luau` or the edited block in `main.server.luau` — no harness in this repo loads a `.client.luau` or the server entrypoint. Green tests + clean lint prove the change didn't break existing pure-module coverage and is syntactically/stylistically sound; they prove nothing about whether the panel actually opens, renders correctly, or reacts to `EconomyState`/`FireworkState`/threshold-crossing at runtime in Studio.

## Concerns

1. **Deviation from verbatim brief**: removed the unused `INK` local (see above). This is a correctness-preserving, gate-required change — no other line was altered from the brief's Step 3 code.
2. **Step 5 grep is a blunt instrument**: as documented above, it produces non-empty output on totally unrelated `= 1` occurrences. Future authors relying on "no output" as a pass/fail signal should know this pattern needs manual triage, not just an exit-code check.
3. **No runtime verification performed or claimed.** Whether the panel actually opens on stepping into 花火屋, whether the tag replicates as expected, and whether the purchase flow round-trips through the server were not and could not be verified by this task's tooling. That needs a Studio/Play-mode check.
