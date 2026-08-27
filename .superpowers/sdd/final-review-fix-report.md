# Final review fix report (B3 whole-branch review, must-fix items)

## Finding 1 — `playerHouse[uid]` staleness across live rebuilds

File: `roblox/src/server/main.server.luau`

### Site A — `RequestPurchase` upgrade rebuild (`elseif e.claimedPadId ~= nil` branch)

Location: inside the `if built then ... end` block, immediately after
`applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)` (now ~line 713).

Added:
```lua
if built.teahouseSize ~= nil then
    playerHouse[uid] = {
        padId = e.claimedPadId,
        size = built.teahouseSize,
        loadout = teaLoadout,
    }
else
    playerHouse[uid] = nil -- bare deck: no live loadout to edit
end
```
`teaLoadout` (already computed a few lines above as `e.teahouses[built.teahouseSize]`) is
guaranteed non-nil whenever `built.teahouseSize` is non-nil, because `built.teahouseSize`
is always one of the keys enumerated into `teaSizes` from `e.teahouses` a few lines earlier —
so this mirrors the join-path shape (`padId`/`size`/`loadout`) exactly with no extra nil-guard
needed.

### Site B — `SetDisplay` handler rebuild

Location: same pattern, immediately after
`applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)` (now ~line 771).
Identical fix applied (same shape, same reasoning — this path can send
`teahouseDisplay = "none"`, which produces `built.teahouseSize == nil`, i.e. the case the
finding calls out for going to `playerHouse[uid] = nil`).

### Buy-to-claim branch (the "Also CHECK" item)

Location: `RequestPurchase`'s `if isBuyToClaim and claimPadId then ... end` branch, the
`if action ~= nil and action.padId == claimPadId then` success path (now ~line 660-676).

**Verdict: it was NOT already correct — fixed.**

Investigated `SiteCoordinator.onJoin` (`roblox/src/shared/SiteCoordinator.luau`): it requires
`economy.maxDeckSize ~= nil` to return an action at all ("not an owner (owns no deck) -> no
auto-claim"), and its `teahouseSizes` are drawn from whatever `economy.teahouses` already
contains — it is not restricted to the item just purchased.

`isBuyToClaim` is gated on `e.claimedPadId == nil and kindPre == "deck"`, i.e. the current
purchase is specifically a `deck:*` item bought by someone who has never claimed a pad. That
does not mean they own no *teahouse* — a player can legally buy `teahouse:S` (or any size)
before ever owning a deck, since teahouse and deck purchases are independent economy calls.
In that scenario:
1. Player buys `teahouse:S` while `claimedPadId == nil` → `e.teahouses.S` exists, no pad, no
   `playerHouse[uid]` entry (nil, correctly).
2. Player later buys `deck:M` (buy-to-claim path) → `e.maxDeckSize` becomes non-nil,
   `siteCoordinator:onJoin` now succeeds and can return `action.teahouse` built from the
   already-owned `teahouses.S` (capped by the new deck/perch/display), i.e. a **live teahouse
   structure gets built right here**, but before this fix `playerHouse[uid]` was never set —
   the back door would stay permanently inert for that structure until the player's next
   join (when the normal join-path sync would finally catch up).

Confirmed the pre-purchase invariant `claimedPadId == nil ⟹ playerHouse[uid] == nil` holds
(both are reset together on `PlayerRemoving` and only ever populated together on the
`PlayerAdded` join path), so the fix only needed to *add* the sync, mirroring the join path's
own conditional (`action.teahouse ~= nil and action.teahouse.loadout ~= nil`) verbatim:

```lua
if action.teahouse ~= nil and action.teahouse.loadout ~= nil then
    playerHouse[uid] = {
        padId = action.padId,
        size = action.teahouse.size,
        loadout = action.teahouse.loadout,
    }
else
    playerHouse[uid] = nil
end
```

Scope note: none of the three fixes proactively re-fire `BackDoorState` to the client. The
finding's fix is specifically about server-side `playerHouse[uid]` bookkeeping ("so the
back-door picker goes properly inert" — i.e. the *next* `SetBackDoor` request is judged
against the correct/nil state), not about pushing a fresh bay-count UI to the client on
every rebuild. Left as-is to keep the change scoped to the reviewed finding.

## Finding 2 — doc-only, `SizeClasses.luau`

`resolveBuilt`'s doc comment (was ~line 65-66) extended to describe the two optional display
args: they only ever shrink what's built (deck floor via `deckDisplay`; `teahouseDisplay ==
"none"` forces a bare deck; passing `nil` for both reproduces pre-B3 behavior — biggest owned,
perch-capped).

## Finding 3 — doc-only, `SiteCoordinator.luau`

File header (lines 1-12) extended with one line noting the passed economy may also carry
`deckDisplay`/`teahouseDisplay` (B3), which `resolveBuilt` applies as a further, owner-chosen
clamp that only ever shrinks (never grows past owned/perch-capped).

## Verification

```
cd roblox && stylua --check src tests   # clean, no output
cd roblox && selene src                 # 0 errors, 0 warnings, 0 parse errors
cd roblox && lune run tests/run         # 407 passed, 0 failed, 407 total
```

All three files (`roblox/src/server/main.server.luau`,
`roblox/src/shared/SizeClasses.luau`, `roblox/src/shared/SiteCoordinator.luau`) committed
together in one commit.
