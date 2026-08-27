# B3 gate fix: mid-session back-door prompt arming

## Bug recap

Two-layer bug diagnosed in the B3 visual gate: a player who acquires their teahouse
mid-session (buy-to-claim a deck, then buy a teahouse via the HUD) never gets the F-key
back-door `ProximityPrompt`s.

- **Layer 1 (server):** `BackDoorState:FireClient` only fired at join and at the
  `SetBackDoor` echo — not at the three sites that rebuild `playerHouse[uid]` mid-session.
- **Layer 2 (client):** even if re-fired, `bindBays`' dedupe (`if prompts[i] == nil`) would
  treat destroyed prompts (killed by the rebuild's `Structure` teardown) as still bound and
  skip re-creating them on the new structure.

## Server change — `roblox/src/server/main.server.luau`

Added a local helper `echoBackDoor(player, uid)`, placed at line 428 — immediately after
`echoEconomy` (line 408-426) and before `local siteCoordinator = ...` (originally line 428,
now line 442). This is after both `playerHouse` (declared line 390) and `BackDoorState`
(declared line 34) are in scope, and before the first call site.

```lua
local function echoBackDoor(player: Player, uid: string)
    local house = playerHouse[uid]
    if house ~= nil and player:IsDescendantOf(Players) then
        BackDoorState:FireClient(player, {
            padId = house.padId,
            backDoorIndex = BackDoorEditor.backDoorIndex(house.loadout.wallBays),
        })
    end
end
```

Mirrors the exact payload shape of the join-path fire (original ~line 509) and the
`SetBackDoor` echo (~line 597), including passing `loadout.wallBays` (not the raw bays list)
to `BackDoorEditor.backDoorIndex`.

Call sites added, each immediately after the site's `playerHouse[uid]` set/nil block, no new
yields introduced (all three are already past their handler's post-yield presence re-check):

1. **`RequestPurchase` buy-to-claim branch** — line 690 (was ~665-674 in the pre-fix
   line numbering), inside `if action ~= nil and action.padId == claimPadId then`, right
   after the `if action.teahouse ~= nil and action.teahouse.loadout ~= nil then ... else
   playerHouse[uid] = nil end` block.
2. **`RequestPurchase` upgrade rebuild** — line 741 (was ~714-724), inside the
   `elseif e.claimedPadId ~= nil then` / `if built then` branch, right after the
   `playerHouse[uid]` set/nil block.
3. **`SetDisplay` handler rebuild** — line 800 (was ~772-782), right after its
   `playerHouse[uid]` set/nil block, inside `if built then`.

All three calls are harmless no-ops when `playerHouse[uid]` was just nil'd (bare deck / no
loadout) — `echoBackDoor`'s own guard handles that, matching the spec.

## Client change — `roblox/src/client/BackDoorController.client.luau`

`bindBays` now sweeps the `prompts` cache at its top, dropping any entry whose prompt has
been destroyed/unparented (`prompt.Parent == nil`) before running the existing
`if prompts[i] == nil then` dedupe:

```lua
local function bindBays(structure: Instance)
    for i, prompt in prompts do
        if prompt.Parent == nil then
            prompts[i] = nil
        end
    end
    for _, child in structure:GetChildren() do
        ...
```

This makes rebinding rebuild-safe: a mid-session rebuild destroys the old `Structure` (and
every prompt anchored inside it via `TreatmentApplier`), so the sweep clears those dead
entries and the unchanged dedupe loop below re-creates fresh prompts anchored to the NEW
structure's bays. The alive case (a plain `SetBackDoor` echo re-entering with the same live
structure) is untouched — those prompts still have a parent, survive the sweep, and the
dedupe still skips re-creating them, so no duplicate prompts.

Header comment (top of file) updated to note `BackDoorState` also fires after live rebuilds
(purchase/display), not just join/edit, and that prompts are re-bound because rebuilds
destroy the old structure. A second comment was added directly above `bindBays` explaining
the sweep's purpose.

## Verification

```
$ cd roblox && lune run tests/run
407 passed, 0 failed, 407 total

$ cd roblox && stylua --check src tests
(clean, exit 0)

$ cd roblox && selene src
Results:
0 errors
0 warnings
0 parse errors
```

No Lune test changes were made or needed — per the task, these two files aren't Lune-covered;
the 407-test suite is the regression net and stayed green throughout.

## Commit

One commit, both files:

`fix(roblox): arm back-door prompts after mid-session rebuilds (B3 gate)`
