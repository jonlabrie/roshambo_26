# Deck Decoration Framework (Piece B) — Design

Approved in brainstorm 2026-07-19. First sub-project of the decoration catalog.

## Goal

Let a deck owner buy decorative props (a stone lantern, water basin, potted bonsai, wooden bench)
and freely place them on their deck to fill the yard the display-size caps freed. This is the
**placed-prop framework** — the load-bearing foundation every later flex decoration builds on — not
the whole catalog. Ships buy → ghost-drag place → in-world move/remove, with props persisted
per-deck and auto-hidden when a larger teahouse would enclose them.

## Scope

**In:** deck-anchored, freely-placed, purely-decorative props (no behavior); buy/place/move/remove;
per-deck persistence; auto-hide under the built teahouse. Four launch props (placeholder art).

**Out (separate future sub-projects, already decomposed):** the swap-decoration economy
(colorScheme/shoji/etc. skins); **teahouse-anchored** props (need named anchor slots the S/M/L
prefabs must publish); banner/noren/maku **slot content** and the flex economies that fill them;
all **flex behaviors** (gardens attracting butterflies, planting, banners displaying). The
framework leaves seams for these but builds none of them.

## Decisions (brainstorm)

- **Free placement via ghost-drag**, reusing B4's `MoveController` machinery (not curated slots, not
  auto-placement).
- **Buy-per-placement**: each prop added is its own purchase + placement; a deck holds a flat LIST
  of instances. Points sink scales with what you place; no own-a-type-spam.
- **Clamp to the deck, allow overlaps.** The only hard placement rule is the footprint stays on the
  deck. Overlapping the teahouse or other props is allowed; props are **non-collidable** (walk
  through, like the portal control) so overlap is visual-only and harmless.
- **Auto-hide under the teahouse.** A decoration whose footprint intersects the *built* teahouse is
  not rendered (but stays persisted); it reappears when the teahouse shrinks/moves off it. This is
  the B3 display-clamp philosophy applied to decorations — stored placement never changes, rendering
  adapts — and it gives "display small to show your garden" real teeth.
- **In-world Move/Remove prompts** on each prop (owner-only), not a panel list.
- **Stable per-instance `id`** (not array index) for referencing instances across the client/server
  view skew.
- **No refund on remove** (buy-per-placement is a sink; discarding discards the spend).
- **Cap `MAX_DECORATIONS = 24`** per deck (gate-tunable), server-enforced.
- **Four launch props:** `ishidoro` (stone lantern), `tsukubai` (water basin), `bonsai` (potted
  plant), `bench` (wooden seat) — distinct footprints; placeholder geometry, art pass later.

## Data model

**`User.deckDecorations: Array<{ id: number, propId: string, offset: [number, number], facing: 'N'|'E'|'S'|'W' }>`**
— a flat per-player (= per-deck; one claimed pad at a time) list. Deck-level, independent of the
teahouse size shown, so it renders on any deck (even a bare deck with no teahouse). `id` is a
server-assigned stable identifier (monotonic: `max(existing ids) + 1`, starting at 1). `offset` is
deck-local studs; `facing` the 4 cardinals (matches `BuildingPlacer`).

**Catalog, split across the two codebases** (same pattern as deck/teahouse prices + the character
catalog; keep the propId sets in sync — the known TS↔Luau drift caveat):
- **TS** `economy.ts`: `PRICES.decoration: { ishidoro, tsukubai, bonsai, bench }` (flat prices,
  placeholders) — the valid-propId set + prices for purchase validation.
- **Luau** `DecorationCatalog.luau` (new shared): `propId → { footprint: {minX,maxX,minZ,maxZ}, ... }`
  + a placeholder builder per propId (distinct footprints; non-collidable parts). What Roblox needs
  to clamp placement and materialize the prop.

## Pure logic (Lune-tested)

**`DecorationLayout.resolve(deckFP, teahouseFP, decorations) → { { id, propId, offset, facing, visible } }`**
(an ordered list preserving input order) — the testable meat:
- For each decoration, clamp its `offset` to `deckFP` using the propId's rotation-aware footprint
  (reuse `BuildingPlacer.clamp`/footprint-swap).
- Set `visible = false` when the clamped, rotation-aware footprint overlaps `teahouseFP` (a
  deck-local AABB overlap; `teahouseFP` = the built teahouse's placed footprint in deck-local space,
  or `nil` for a bare deck → nothing hidden).
- Stored placement is never mutated; `resolve` returns render data only.

**`DecorationCatalog`**: pure lookups (`footprint(propId)`, `has(propId)`, `ids()`); the builder that
makes Roblox parts is Roblox-only (not Lune-covered).

## Server (TS)

- `PRICES` gains `decoration`; `EconomyState` gains `deckDecorationCount?: number` (populated by
  `readEconomy` from `user.deckDecorations.length`). `validatePurchase("decoration:<propId>")`:
  requires a claimed deck (`maxDeckSize !== null`), rejects an unknown propId (`BAD_ITEM`), rejects
  when `deckDecorationCount >= MAX_DECORATIONS` (`DECOR_CAP`), then the points check.
- **The purchase route is the id authority.** On a valid `decoration:<propId>` buy it charges via
  `applyPurchase`, appends `{ id: max(existing ids)+1, propId, offset:[0,0], facing:"N" }` to
  `user.deckDecorations`, saves, and returns the appended instance (`{id, propId, offset, facing}`)
  in the response. The Roblox server updates its stash from that and enters placement on the new id.
  (Server-assigned id + server-side cap check, both before the charge commits.)
- `User.deckDecorations` field (schema, default `[]`).
- `GET /economy` returns `deckDecorations` + `catalog.decoration`.
- `PUT /players/:robloxUserId/decorations` — replaces the whole list with a validated payload
  (same shape as `setPreferences`): each entry `{id, propId, offset, facing}` — propId in catalog,
  offset 2 finite numbers within range, facing whitelisted, ids unique, length ≤ `MAX_DECORATIONS`.
  New `validateDecorations` in `loadout.ts`/`economy.ts`.

## Roblox server

- `playerEconomy[uid].deckDecorations` stashed from the join fetch + kept current on
  buy/place/remove; threaded into the **treatment** (like `portalOwned`) at every `applier:apply`
  owner site; added to the `EconomyState` echo.
- **`TreatmentApplier`**: after building the deck + teahouse, compute the built teahouse's deck-local
  footprint, call `DecorationLayout.resolve`, and build **only the `visible`** props via
  `DecorationCatalog`'s builder at their clamped placements, tagging each `Decoration` with
  attributes `id` + `padId`. Staged with the deck (transactional), non-collidable, survives rebuilds.
- New remotes (register in `default.project.json`), both **on the HandlerQueue** (per-uid,
  HTTP-yielding), occupant/presence-guarded like `SetPlacement`:
  - **`SetDecorationPlacement{ id, offset, facing }`** — server clamps against `deckFootprint` + the
    propId footprint (authoritative), updates that instance in the stash, PUTs the list, rebuilds
    the pad, echoes.
  - **`SetDecorationRemove{ id }`** — removes the instance, PUTs, rebuilds, echoes. No refund.
  - The **buy** reuses `RequestPurchase{ item = "decoration:<propId>" }` (already queued); on
    success the server appends a fresh-id instance at a default `{offset={0,0}, facing="N"}`, and the
    echo/response carries the new id so the client can enter placement for it.

## Client

- **Generalize `MoveController`** from "move the teahouse" to "move any placement-bearing target."
  A target descriptor `{ ghost (model or built-from-catalog), footprint, initialOffset, initialFacing,
  commit(offset, facing) }`. The **teahouse** entry is unchanged behavior (ghost the `Structure`,
  commit → `SetPlacement`). The **decoration** entry ghosts the specific prop, uses the catalog
  footprint, and commits → `SetDecorationPlacement{ id, ... }`. The shared ghost-drag core
  (deck-plane raycast, 1-stud snap, rotate, clamp, HUD) is written once. **Constraint:** the
  teahouse-move path must stay behavior-equivalent — it becomes one caller of the generalized core,
  not a rewrite.
- **Panel:** a Decorations catalog section in the B3 `TeahouseController` — the four props with
  price/affordability (view-model gains the decoration buyables), buy fires
  `RequestPurchase{item="decoration:<propId>"}`. On the buy echo (carrying the new id), the client
  enters ghost-drag on that instance. Cancel leaves it at the default center (reposition later).
- **`DecorationController` (new client controller, mirrors `BackDoorController`)**: watches the
  `Decoration` tag; for each prop whose `padId` attribute matches the client's own `claimedPadId`,
  adds two ProximityPrompts — **Move** (enters ghost-drag locally) and **Remove**
  (`SetDecorationRemove:FireServer(id)`). Owner-only via the padId filter (your yard; visitors can't
  rearrange).

## Error handling

- Purchase over cap → `DECOR_CAP` (400), surfaced by the existing purchase failure resync.
- Placement/remove for an unknown id (stale client view) → server no-op (the id isn't in the list).
- `SetDecorationPlacement` for a non-occupant / no-claim → ignored (occupant gate, like `SetPlacement`).
- Bare deck / no teahouse → `teahouseFP` nil, nothing auto-hidden.
- Malformed decoration payload on the PUT → rejected (`BAD_DECORATION`), no partial write.

## Testing & verification

- **Lune:** `DecorationLayout.resolve` (clamp to deck; auto-hide when overlapping the teahouse
  footprint incl. rotated props; bare-deck = all visible; overlap-vs-touch boundary);
  `DecorationCatalog` lookups; `TeahouseMenuModel` decoration buyables (affordable/owned-cap gating).
- **Vitest:** `validatePurchase("decoration:<propId>")` (unknown propId, cap, price, needs-deck);
  `validateDecorations` (shape, cap, unique ids, ranges); `GET /economy` returns the list +
  `catalog.decoration`; `PUT /decorations` persists + rejects malformed.
- **Visual gate:** catalog buy → ghost-drag place a prop; four props place with distinct footprints;
  in-world Move/Remove; **auto-hide** — place props in the open yard under a small teahouse display,
  then display a larger teahouse and watch the covered props vanish, shrink back and watch them
  return; cap enforcement; props survive display/size/move rebuilds; the teahouse move still works
  unchanged (the generalized `MoveController` regression check).

## Non-goals / deferred

- **Swap decorations** (skinning colorScheme/shoji/tatami/flags/wallArt) — a separate sub-project;
  the data layer already exists, it needs an ownership model + UI, orthogonal to this framework.
- **Teahouse-anchored props** — need the S/M/L prefabs to publish named anchor slots; deferred.
- **Slot content** (banners/noren/maku in curated locations) + their flex economies — deferred; the
  slot mechanism reuses this framework's patterns but isn't built here.
- **Flex behaviors** (attract butterflies, planting, banner display), **collidable/sittable props**,
  **partial refunds**, **multi-pad decoration memory** — all deferred.
- **Art pass** on the four props + any decoration VFX — placeholders now.
