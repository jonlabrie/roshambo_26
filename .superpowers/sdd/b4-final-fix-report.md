# B4 final review — must-fix fixes

Three findings from B4's whole-branch review, fixed in one commit.

## Item 1+2 — `roblox/src/server/main.server.luau`, `SetPlacement.OnServerEvent` handler

File: `roblox/src/server/main.server.luau:838-919` (handler as a whole); post-yield section
rewritten at what is now lines 891-919 (was 891-901 pre-fix).

### Race A — SetBackDoor clobbered during the HTTP yield

Before: the handler cloned `e.teahouses[size]` into `newLoadout` **before** the
`net:setTeahouse` HTTP yield (line 883, unchanged), then after the yield wrote that same
pre-yield `newLoadout` back into `e.teahouses[size]` (old line 895: `e.teahouses[size] =
newLoadout`). If a `SetBackDoor` edit landed on `e.teahouses[size]` during the yield (mutating
`wallBays`), this post-yield write silently overwrote it with the stale pre-yield snapshot —
the door edit was lost even though it had already been persisted server-side moments earlier.

Fix (new lines 894-901): after the existing `player:IsDescendantOf(Players)` re-check, guard
that `e.teahouses[size]` is still present, then build `fresh` by cloning the **current**
(post-yield) stash and merging only the `placement` field onto it:

```lua
local fresh = table.clone(e.teahouses[size])
fresh.placement = clamped
e.teahouses[size] = fresh
```

Any `wallBays`/other fields written by a concurrent `SetBackDoor` are on the object being
cloned here, so they survive. `clamped` (computed pre-yield, server-authoritative, doesn't
depend on stash contents) is still what gets applied as the placement.

### Race B — SetDisplay landing mid-yield stamps a stale size

Before: the post-yield rebuild reused the pre-yield `built` (from `SizeClasses.resolveBuilt`,
computed before the `net:setTeahouse` yield at old line 866-867). If a `SetDisplay` call
landed and completed during the yield (changing `e.deckDisplay`/`e.teahouseDisplay`), the
combination that's "standing" after that could differ from `built` — yet the handler would
still rebuild using the stale `built.deckSize` and stamp `playerHouse[uid]` with the stale
`size`, potentially rendering/registering the wrong size class.

Fix (new lines 902-913): recompute `builtNow` from the **current** `e.teahouses` (via a
fresh `teaSizesNow` scan) and current `e.deckDisplay`/`e.teahouseDisplay`, then bail if the
size we just moved (`size`, captured pre-yield) is no longer the one standing:

```lua
local builtNow =
    SizeClasses.resolveBuilt(e.maxDeckSize, teaSizesNow, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
if builtNow == nil or builtNow.teahouseSize ~= size then
    return -- persisted + stash-merged; the standing build belongs to a newer state
end
```

The rebuild that follows (new lines 914-917) is sourced entirely from post-yield values:
`teahouse = { size = size, loadout = fresh, placement = clamped }`, `treatment = { kind =
"structure", loadout = fresh, lit = true }`, `applier:apply(e.claimedPadId, spec, treatment,
builtNow.deckSize, teahouse)`, `playerHouse[uid] = { padId = e.claimedPadId, size = size,
loadout = fresh }`, `echoBackDoor(player, uid)`. No reference to the pre-yield `newLoadout`
or `built` remains in the post-yield path.

The pre-yield section (occupant gate, payload validation, `resolveBuilt`, nil-guard, clamp,
clone into `newLoadout`, `net:setTeahouse` call) is untouched.

## Item 3 — `roblox/src/client/MoveController.client.luau`

Added `local disabledPrompts: { ProximityPrompt } = {}` to the mode-state block
(after `hud`, line ~35).

In `enter()`, immediately after `fadeOriginal(structure :: Model, 0.7)` (was line 220, now
~220-226): walk the original structure's descendants and disable any `ProximityPrompt` that
was `Enabled == true`, recording it:

```lua
for _, d in (structure :: Model):GetDescendants() do
    if d:IsA("ProximityPrompt") and d.Enabled then
        d.Enabled = false
        table.insert(disabledPrompts, d)
    end
end
```

Only prompts that were enabled get touched/recorded, so BackDoorController's deliberately-
disabled one-door-slot prompts are left alone and won't get incorrectly re-enabled on exit.

In `exit()`, immediately after `fadeOriginal(original, 0)` (was line 121, now ~123-131):
restore exactly the prompts this instance disabled, then clear the list:

```lua
for _, prompt in disabledPrompts do
    if prompt.Parent ~= nil then
        prompt.Enabled = true
    end
end
disabledPrompts = {}
```

The `prompt.Parent ~= nil` guard covers the commit path, where the structure (and its
prompts) is destroyed by the server rebuild shortly after `exit()` runs — no error setting
`Enabled` on an about-to-be-destroyed instance, and no re-enable attempted on an already-gone
instance either way, since the check is on the prompt itself.

Header comment (lines 1-6) updated to mention prompt suppression during move mode.

## How the two races are closed

- **SetBackDoor-during-yield race**: closed by never writing the pre-yield loadout snapshot
  back into the stash. The post-yield merge starts from whatever is in `e.teahouses[size]`
  *now*, so a concurrent `SetBackDoor`'s `wallBays` change is preserved; only `placement` is
  overlaid on top of it.
- **SetDisplay-during-yield race**: closed by recomputing `resolveBuilt` post-yield from
  current `e.teahouses`/`e.deckDisplay`/`e.teahouseDisplay` and only proceeding with the
  rebuild if the moved size (`size`) is still what's standing. If a `SetDisplay` swapped in a
  different standing size during the yield, that display-change's own rebuild already
  reflects the correct (pre-move) placement for the newly-standing size, and this handler
  bails out rather than clobbering it with a rebuild sourced from stale data.
- **Client-side entry path for Race A** (mid-drag F press hitting the still-live back-door
  prompt on the faded original) is independently closed by Item 3: the original's prompts are
  disabled for the duration of move mode and restored on exit/cancel, so the SetBackDoor path
  can't even be triggered while a placement drag is in flight.

## Test output

```
$ cd roblox && lune run tests/run
427 passed, 0 failed, 427 total

$ stylua --check src tests
(no output — clean)

$ selene src
Results:
0 errors
0 warnings
0 parse errors
```

Neither `main.server.luau` nor `MoveController.client.luau` is Lune-covered (both are
Roblox-runtime entry points that WaitForChild/connect to live services), so the 427-test
suite is the regression net for shared modules (`SizeClasses`, `BuildingPlacer`, `GameRules`,
etc.) that these handlers call into — it stayed green, confirming no shared-module contract
was broken. stylua/selene confirm formatting/lint cleanliness of the new code.
