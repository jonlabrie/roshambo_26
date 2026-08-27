# Hanabiya shop — review fix round 1

Six findings from the whole-branch review, all fixed in one commit on top of `aa5dec8`.

## 1. CRITICAL — buying a shell wiped the session's deck/portal state

`RequestPurchase` in `roblox/src/server/main.server.luau` adopted the purchase response's
`maxDeckSize`/`portalOwned` unconditionally, but the `firework:`/`mortar:` branch of
`server/src/routes/apiV1.ts` `/purchase` returns only `{ item, totalPoints, shellId, count }`.
Both fields therefore went nil/false for the rest of the session: buy-to-claim prompts came back
on owned perches and then failed, the home portal stopped opening, and `recomputeAllAccess()`
dropped the pad from `occupied` so a friends-only deck opened to everyone — an access check that
fails OPEN. A relog healed it, so it would have read as an intermittent ghost.

**Fixed** by adding an early return for `firework:`/`mortar:` immediately BEFORE
`e.maxDeckSize = res.data.maxDeckSize`, modelled on the `decoration:` branch above it and carrying
a comment that names the hazard. It leaves `e.maxDeckSize`, `e.portalOwned` and `e.teahouses`
untouched, calls `pushFireworkState(player)` (nil-guarded) and `echoEconomy(player, uid)`, then
returns.

Task 2's trailing `pushFireworkState` call (after `echoEconomy`, before `recomputeAllAccess()`)
became unreachable for these items and was **removed**, so there is exactly one push per purchase.

Second bug closed for free: `mortar:` used to fall through into the "live-rebuild the claimed pad"
branch, destroying and rebuilding the owner's deck and teahouse for a purchase that changes neither.

## 2. IMPORTANT — every shop purchase failure was silent; the mortar ladder was the case that failed

`roblox/src/client/ShopController.client.luau` derived a row's liveness from affordability alone and
left dimmed rows clickable. 250 points and no `mortar:S` lit "Medium mortar — 250 pts"; tapping it
returned `BAD_TIER_ORDER` and nothing on screen changed.

**Fixed** without letting the client evaluate a requirement:

- **Shells** now render the server's own verdict, which `FireworkState` was already sending and the
  panel was ignoring: `shells[id].launchable` and `shells[id].reason`. A new `REASON_COPY` map turns
  the symbol into copy (same contract HudController's picker uses, unmapped symbols falling back to
  themselves). `NONE_HELD` is suppressed in the shop because the row already prints "you hold 0".
  Shell rows stay live on affordability — a shell is buyable whether or not it can fire yet.
- **Mortars**: the tier rule is not on the wire, so the row is rendered from the `mortars` list the
  server already sends. Owned tiers say "owned"; an unowned tier whose predecessor is absent from
  that list says "N pts   needs the small mortar first" and is not live. The only client-side
  knowledge is `MORTAR_ORDER`, used solely to NAME the tier below (new `MORTAR_BELOW`, derived once
  from it) — presentation order, not the rule.
- **Un-tappable when dim**: `Row` gained a `live` field written by `paint()`, and the click handler
  returns early when it is false. Dimming is now a promise the button keeps.

The file header's "IT EVALUATES NOTHING" claim was already false (it evaluated affordability) and
would have been more false after this change; it was rewritten to state what is actually true —
no requirement is evaluated here, and `MORTAR_ORDER` is the one piece of local knowledge.

## 3. IMPORTANT — a price-less panel could still spend real points

`economyCatalog` is only ever set from a successful `getEconomy`; if that fetch fails, `echoEconomy`
sends `catalog = nil`, `prices` stays `{}`, every row reads "…" forever — and the rows stayed
clickable, so a tap spent real points against a real balance.

**Fixed** client-side only: `Row` gained `priceKnown` (also written by `paint()`), and the click
handler refuses to fire `ShopPurchase` when it is false. A button that cannot tell you the price
must not spend your points.

## 4. MINOR — jumping inside the shop closed the panel

`roblox/tools/builders/Machiya.luau` built the `Threshold` trigger volume 4.9 studs tall from
`FLOOR` (113.10 → 118.00). A standing HumanoidRootPart sits ≈116.1 and a default jump adds ≈7, so
the panel blinked off mid-air.

**Fixed** by raising the height to 14 (`TH_H`), base still on `FLOOR`, top at 127.10 — about 4 studs
clear of the ≈123.1 jump apex. It costs nothing to be generous: the volume is invisible,
non-colliding and non-querying, so its height is not geometry.

`roblox/assets/Hanabiya.model.json` regenerated via `lune run tools/genmodels`; the only diff in the
whole `assets/` tree is the Threshold's `CFrame` Y (115.55 → 120.1) and `Size` Y (4.9 → 14).

Task 4's spec test pinned the Threshold's Z inset and its flags, not its height, so no existing
assertion needed changing. A new test was added to `roblox/tests/Machiya.spec.luau` that pins the
volume's base to `FLOOR` and asserts its top clears `FLOOR + 10` — the regression itself, guarded.

## 5. MINOR — a missing model failed silently

The `ShopThreshold` tagging block no-opped with no log when `RoshamboStage.Hanabiya` or its
`Threshold` was absent — the exact state of a place that has not been re-synced from Rojo, and
indistinguishable from a working shop nobody can open.

**Fixed** with two `warn`s naming precisely what was missing: one for the absent model (mentioning
the likely re-sync cause), one for a model present without its `Threshold` child.

## Gates

All run from a clean tree before committing.

| Gate | Result |
| --- | --- |
| `roblox/`: `lune run tests/run` | 1071 passed, 0 failed (was 1070 + the new Threshold-height test) |
| `roblox/`: `stylua --check src tests tools` | clean, no diff |
| `roblox/`: `selene src tools` | 0 errors, 0 warnings, 0 parse errors |
| `roblox/`: `lune run tools/genmodels` + `git status` | only `assets/Hanabiya.model.json` changed |
| `server/`: `npm test` | 14 files, 251 tests passed |
| `server/`: `npm run build` | tsc clean |

## Files touched

- `roblox/src/server/main.server.luau` — findings 1 and 5
- `roblox/src/client/ShopController.client.luau` — findings 2 and 3
- `roblox/tools/builders/Machiya.luau` — finding 4
- `roblox/tests/Machiya.spec.luau` — finding 4 (new assertion)
- `roblox/assets/Hanabiya.model.json` — regenerated
