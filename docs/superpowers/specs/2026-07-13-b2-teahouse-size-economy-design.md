# B2 — Teahouse Size Economy (design)

**Piece B, sub-project 2.** Make deck and teahouse **size** into earned, purchased items:
a player banks points, buys deck tiers and teahouse tiers (S → M → L), and the perch they
claim materializes at the sizes they own — instead of today's pad-default size. This is the
economy floor the rest of Piece B (decoration catalog, customization UI) builds on.

## Why this, why now

Piece A + per-size deck placement + SP1 + B1 gave us the machinery: perches, per-size decks,
modular teahouses, live rebuilds. But **size is not yet earned** — `SiteCoordinator` derives the
deck size from the pad spec (`deckSize or maxSize`, currently always `L`) and the teahouse from
whatever `teahouses` map a player happens to have. There is no way to *buy* a bigger deck or
teahouse. B2 turns size into the first real Roblox point sink ("earn your bigger teahouse"),
which is the whole point of the metagame per
`docs/superpowers/specs/2026-07-04-roshambo-metagame-design.md` ("structural tiers as
big-denomination sinks").

## Scope (decided in brainstorm)

**In:** the deck/teahouse **size** economy only — buying deck tiers and teahouse tiers with
points, `teahouse ≤ deck` gating, and sourcing built size from player inventory.

**Out (each its own later sub-project):** the furniture/decoration catalog; familiars, koi,
lanterns, dusk; pad-prestige/eligibility unlocks; the **PWA/Roblox wallet split** (B2 reuses the
existing shared `totalPoints`); a rich **store-menu UI** (B2 uses walk-up prompts); **multi-home**
(owning claimed perches at several sites at once — one claimed perch per session stands).

## Economy model

### Currency
Reuse the existing shared **`totalPoints`** balance (earned by banking pots via `bankPot`;
already read/written by the Roblox game through `/api/v1`). No new wallet. Spending is
**server-authoritative**: Roblox client → game server → `/api/v1` purchase endpoint; the client
never computes balances (metagame spec, "Server-authoritative spending").

### What you own
- **Decks:** a single **`maxDeckSize`** tier on the `User` (`'S' | 'M' | 'L' | null`; `null` =
  owns no deck = not yet an owner). Owning a tier lets you build **that size or any smaller**
  ("own multiple decks" = build any size ≤ your tier).
- **Teahouses:** the existing **`teahouses` map** — a size you own is a present key (each with
  its own B1 loadout). Your max teahouse = the biggest key (or none if the map is empty).

Decks and teahouses are **independent**: you can own a deck with **no** teahouse (bare deck,
"just hang on the deck").

### What you can buy (linear ladder, spend `totalPoints`)
| Item id | Grants | Requires (all must hold) |
|---|---|---|
| `deck:S` | `maxDeckSize = 'S'` | own no deck (`maxDeckSize == null`) — **the gateway** |
| `deck:M` | `maxDeckSize = 'M'` | own `deck:S` |
| `deck:L` | `maxDeckSize = 'L'` | own `deck:M` |
| `teahouse:S` | `teahouses['S'] = default loadout` | own `deck:S`+ (deck ≥ S) |
| `teahouse:M` | `teahouses['M'] = default loadout` | own `teahouse:S` **and** `deck:M`+ |
| `teahouse:L` | `teahouses['L'] = default loadout` | own `teahouse:M` **and** `deck:L` |

Both ladders are **linear** (each tier requires the one below). Teahouse tiers additionally
require a deck of at least that size (`teahouse ≤ deck`). A purchase that fails any requirement
(unaffordable, out-of-order, deck too small) is rejected with a specific error and no state
change.

### What gets built at a claimed perch (auto-biggest)
Given the player's `maxDeckSize`, `teahouses` keys, and the perch's `maxSize`:
- `builtDeck = min(maxDeckSize, perch.maxSize)` — where size order is `S < M < L`. If
  `maxDeckSize == null`, the player is **not an owner** and does not auto-claim.
- `builtTeahouse = min(maxTeahouse, builtDeck)`, or **none** (bare deck) if the `teahouses` map
  is empty.

This is a pure resolver (`min` over the size order) — Lune-testable, and the single place the
"own an L deck but only an S house → L deck + S house" behavior lives.

## Interaction (walk-up; a store menu is deferred to B3)

Reuses the `ProximityPrompt` pattern already used by Favorite (`PerchPreferenceController`) and
the B1 back door (`BackDoorController`).

- **Non-owner** (`maxDeckSize == null`): a **gate-post prompt at each vacant pad** →
  *"Buy S deck & claim here — N pts."* Triggering it purchases `deck:S`, **claims that pad**,
  and materializes the bare S deck. This is the walk-up claim ritual and the gateway sink. (If
  the player can't afford it, the prompt shows the price and does nothing on trigger.)
- **Owner at their claimed perch:** a prompt on their own deck/teahouse offers the **next
  available upgrade(s)** — the next deck tier and/or the next teahouse tier, with prices.
  Purchasing **live-rebuilds** the structure at the new size in place (the same
  stage-and-swap `TreatmentApplier.apply` the game already runs on claim). Requirements that
  aren't met (e.g. teahouse blocked by deck size) surface as prompt text, not a purchase.

Owners still **auto-claim** their preferred fitting perch on join (existing `onJoin`); the
walk-up path is for a non-owner's first purchase and for upgrades. (Reconciling auto-claim vs.
pure walk-up claiming is an existing behavior, out of B2 scope.)

## Architecture

### Components
| Component | File | Kind | Responsibility |
|---|---|---|---|
| Purchase rules | `server/src/economy.ts` (new) | pure, Vitest | item catalog + prices + `validatePurchase(user, item)` + `applyPurchase(user, item)` (afford / linear / `teahouse≤deck` / grant / deduct) |
| User field | `server/src/models/User.ts` | schema | add `maxDeckSize: 'S'|'M'|'L'|null` (default `null`) |
| REST | `server/src/routes/apiV1.ts` | server (Node) | `GET …/economy` (balance + `maxDeckSize` + owned teahouse sizes + catalog/prices); `POST …/purchase {item}` (validated spend, returns new state) |
| Size resolver | `roblox/src/shared/SizeLadder.luau` (new) | pure, Lune | `order` (`S<M<L`), `min(a,b)`, `resolveBuilt(maxDeckSize, teahouseSizes, perchMax) → {deckSize, teahouseSize?}`, `nextTier(current)` |
| Claim wiring | `roblox/src/shared/SiteCoordinator.luau` | pure, Lune | source `deckSize` from `maxDeckSize` (via `SizeLadder.resolveBuilt`), not the pad default; a deck-only owner (no teahouse) still claims a bare deck |
| Network | `roblox/src/server/NetworkClient.luau` | server | `getEconomy(userId)`, `postPurchase(userId, item)` |
| Purchase UI | `roblox/src/client/EconomyController.client.luau` (new) | client | vacant-pad "buy & claim" prompts + owner "upgrade" prompts; fires purchase remote; relabels from echoed economy state |
| Server handler | `roblox/src/server/main.server.luau` | server | purchase remote handler: call `net:postPurchase`, on success update the `playerHouse`/economy stash + `applier:apply` the new sizes live; echo economy state |
| Remotes | `roblox/default.project.json` | contract | `RequestPurchase` (C→S `{item, padId?}`), `EconomyState` (S→C `{totalPoints, maxDeckSize, teahouseSizes, catalog}`) |
| Prices source | server `economy.ts`, fetched by client via `GET …/economy` | — | **single source of truth = server**; the client displays fetched prices, never hardcodes them |

### Data flow (upgrade at your perch)
```
player triggers "Upgrade deck → M (N pts)" prompt
  client EconomyController --RequestPurchase{item="deck:M"}--> server
  server:
    1. call net:postPurchase(uid, "deck:M")
       → /api/v1 POST purchase → economy.validatePurchase (afford + linear + gate)
         → on ok: deduct totalPoints, set maxDeckSize="M", save → returns new state
    2. on ok: update the player's economy stash; recompute built sizes
       (SizeLadder.resolveBuilt) and applier:apply(padId, ..., newDeckSize, newTeahouse)
       → live stage-and-swap rebuild at the bigger size
    3. echo EconomyState to the player
  client relabels prompts (new balance, next available upgrade)
```
Buy-to-claim (non-owner at a vacant pad) is the same, with `item="deck:S"` and a claim of that
`padId` before the build.

## Pricing
Placeholder **tunable constants** in `economy.ts` (e.g. `PRICES = { deck: {S,M,L}, teahouse:
{S,M,L} }`), exposed via `GET …/economy` so the client shows them. Real tuning is deferred per
the metagame spec ("tuned against real banked-pot distributions"). Initial placeholder bands (to
be tuned, not load-bearing): `deck:S` cheap (a few banked pots), teahouse/M/L climbing into the
hundreds — set concretely in the plan.

## Testing
- **Vitest** (`server/economy.test.ts`): `validatePurchase`/`applyPurchase` — gateway S with
  null deck; reject `deck:M` without S; reject `deck:L` skipping M; reject `teahouse:M` without M
  deck; reject unaffordable; accept valid chain and assert `totalPoints` deducted + tier granted;
  reject unknown item id.
- **Lune** (`roblox/tests/SizeLadder.spec.luau`): `min`/order; `resolveBuilt` (deck capped by
  perch; teahouse capped by deck; empty teahouses → bare deck; null deck → not an owner);
  `nextTier`.
- **Lune** (`SiteCoordinator.spec`): a deck-only owner (no teahouse) claims a bare deck; sizes
  come from `maxDeckSize`, not the pad default.
- **Visual gate** (Studio): as a non-owner, walk to a vacant pad → buy S deck → claim + bare
  deck; buy S teahouse → live-builds; buy M deck then M teahouse → live-rebuilds bigger; confirm
  unaffordable/blocked prompts don't purchase; confirm balance deducts.

## Error handling (F2/F4: non-fatal)
Unaffordable / out-of-order / deck-too-small / unknown item → `POST purchase` returns a specific
4xx error; the Roblox handler warns and leaves state unchanged (no live rebuild, prompt
unchanged). A failed live rebuild leaves the prior structure standing (existing
`TreatmentApplier` stage-and-swap). A purchase that persists but whose echo/rebuild races a
leave is reconciled on next join (economy is authoritative in Mongo).

## Open decisions (resolved in brainstorm)
- **Scope:** size economy only.
- **Wallet:** reuse shared `totalPoints`; PWA/Roblox split deferred.
- **Ownership:** two linear max-size ladders (deck tier + teahouse map), auto-build biggest.
- **Bundle:** none — decks and teahouses are independent purchases; a bare deck is buyable;
  `teahouse ≤ deck`.
- **Starter:** nothing free; `deck:S` is the earned gateway.
- **Ladder:** linear (S → M → L).
- **Interaction:** walk-up prompts (buy-to-claim at a vacant pad; upgrade at your perch with live
  rebuild); store menu deferred to B3.
- **Prices:** server-owned tunable constants, fetched by the client.
