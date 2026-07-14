# B3 — Teahouse Management UI + Display Size — Design

Consolidate the three scattered walk-up interactions (Favorite, back door, buy/upgrade) behind a
single persistent HUD panel — the "storefront + management" hub that finally makes the shipped
Piece B economy legible — and add one new mechanic: a **display-size cap** so a player can *show* a
smaller deck and/or teahouse than they own, freeing perch space for future decoration items.

Sub-project 3 of Piece B (after B1 player back door, B2 size economy). Builds on the B1/B2 spine
(pure editors, occupant-gated remotes, `/api/v1` persistence, `EconomyState`/`PreferenceState`/
`BackDoorState` echoes, `SiteCoordinator` → `resolveBuilt` → `TreatmentApplier` live rebuild).

## Why

B1 and B2 shipped real mechanics but exposed them as three unrelated world prompts on three keys
(E favorite, F back door, G buy/upgrade), with the upgrade prompt forced to *alternate* deck↔teahouse
because a single prompt can only offer one thing. Nothing shows a player their points, what they own,
what a next tier costs, or the shape of the two ladders. B3 replaces that with one HUD panel that
presents the whole economy at once, and keeps only the genuinely *location-tied* acts in the world.

The display-size cap is the first payoff of "the deck is a yard": you can pay up the ladders but
choose to present a small teahouse (or none) on a big deck, reserving the footprint for decorations
(koi pond, garden, feeders) that a later sub-project will sell.

## Interaction model & entry points

**Primary: a persistent HUD button** (bottom corner, torii/teahouse glyph) opens the **Teahouse
panel** from anywhere. It hosts everything that is an *inventory or preference* op — those work
regardless of where the player stands, because the server rebuilds their claimed perch on change.

**World proximity prompts shrink to the two truly location-tied acts, plus favorite-add:**
- **Vacant pad the player stands on** → "Buy S deck & claim this perch." Claiming targets *this*
  pad, so the *first* deck purchase is inherently in-world (kept on `EconomyController`).
- **The player's own teahouse back bays** → the back-door add/move/remove picker (choosing a
  physical bay; kept on `BackDoorController`, unchanged).
- **Any perch, walk-up** → "Favorite this perch" *add* toggle (kept on `PerchPreferenceController`,
  unchanged). The panel is where favorites are *reviewed/removed*.

The old alternating deck↔teahouse *upgrade* prompt is **removed** — the panel shows both ladders at
once. E/F/G collapse to: one HUD button + (claim / back-door / favorite-add) world prompts.

## The Teahouse panel (HUD hub)

A single scrolling panel, zen palette (matching the existing toast styling), stacked sections:

1. **Header** — points balance; current perch label ("Perch: T05" or "No perch yet").
2. **Upgrades (storefront)** — the two ladders, each rung showing state:
   - **Deck** S·M·L — owned rungs ✓ up to `maxDeckSize`; the next rung shows price + **Buy**
     (disabled if unaffordable); higher rungs greyed.
   - **Teahouse** S·M·L — same, but rungs above `maxDeckSize` are locked with a "needs a bigger
     deck" hint (`teahouse ≤ deck`).
   - **First-deck caveat:** buying the very first `deck:S` also *claims a pad*, so it stays a world
     prompt. Until the player owns a deck, this section renders the ladders as a *preview* with a
     "Claim a free perch to begin" pointer. Every upgrade *after* the first is buyable here.
   - Read-only line: "Back door: bay 2 — manage at your teahouse" (reflects state; edited in-world).
3. **Display size** — two selectors (Section below): Deck S·M·L, Teahouse None·S·M·L. Hidden/
   disabled until the player owns a teahouse (deck selector until they own a deck).
4. **Favorites** — the player's favorited perches as a short list with a ✕ to remove each; helper
   line "Favorite a perch by walking up to it."

The panel is fed entirely by the existing state echoes (extended, below) — no new read endpoint.

## Display size — independent deck + teahouse visual caps

Both are **display-only** caps: the player still *owns* the bigger size (they paid for it); they
choose to *show* smaller, purely visual and reversible anytime. The freed footprint on the perch is
canvas for future decoration items.

- **Deck display:** `S·M·L`, enabled up to owned `maxDeckSize`. **No "none"** — a deck is needed to
  stand on / anchor the claim. A displayed-S deck uses that size's *authored* deck placement, so it
  still touches its access point.
- **Teahouse display:** `None·S·M·L`, enabled up to the owned teahouse **and** never larger than the
  *displayed* deck (`teahouse ≤ deck` holds for displayed sizes, so a small deck also shrinks the
  teahouse options).

**Data + logic:**
- Two persisted fields: `User.deckDisplay: 'S'|'M'|'L'|null` and
  `User.teahouseDisplay: 'none'|'S'|'M'|'L'|null` (`null` = biggest owned = today's behavior).
- `SizeClasses.resolveBuilt(maxDeckSize, teahouseSizes, perchMax, deckDisplay?, teahouseDisplay?)`
  applies both as caps *after* the existing deck/perch caps:
  - `builtDeck = min(maxDeckSize, deckDisplay ?? maxDeckSize)` then capped by `perchMax`.
  - `builtTeahouse = nil` if `teahouseDisplay == 'none'`, else
    `min(ownedMaxTeahouse, teahouseDisplay ?? ownedMaxTeahouse, builtDeck)` capped by `perchMax`.
  - A display value only ever *shrinks* the result; it can never show a size the player doesn't own
    (a display larger than owned is clamped to owned).
- New remote `SetDisplay {deckDisplay?, teahouseDisplay?}` → occupant-gated server handler →
  `net:postDisplay` → persist → update the `playerEconomy` stash → `resolveBuilt` → `applier:apply`
  live rebuild → `EconomyState` echo. Same shape as the B2 purchase path.

## Architecture & data flow

Reuses the B1/B2 spine; new pieces are small and mostly client-side.

**Pure logic (new, Lune-tested):**
- `SizeClasses.resolveBuilt` gains the two display-cap args above (existing tests keep the
  no-display behavior; new tests cover each cap, `'none'`, clamp-to-owned, and `teahouse ≤ displayed
  deck`).
- `TeahouseMenuModel.luau` — a pure `viewModel(economyState) → { deckLadder, teahouseLadder,
  displayOptions, favorites, affordability, gating }`. All "which rung owned / next price / can I
  afford / is this tier locked by my deck / which display sizes are enabled" logic lives here,
  tested; the GUI only renders it. Keeps the panel controller thin.

**Server (TS, `/api/v1`):**
- `User.deckDisplay` + `User.teahouseDisplay` fields (schema, enum-validated, default `null`).
- `GET /economy` superset adds both display fields.
- `POST /economy/display` — validates the values against owned sizes (display ≤ owned; teahouse ≤
  displayed deck; `'none'` allowed only for teahouse), persists, returns the updated economy.
  Mirrors `POST /purchase`.

**Roblox server (`main.server.luau`):** a `SetDisplay` RemoteEvent handler (occupant-gated, presence-
guarded after the HTTP yield like `SetBackDoor`/the B2 purchase handler) → `net:postDisplay` → update
`playerEconomy` stash → `resolveBuilt` → `applier:apply` → `EconomyState` echo now carrying the
display fields. `NetworkClient` gains `postDisplay`.

**Client refactor (the bulk of the work):**
- **New** `TeahouseController.client.luau` — the HUD button + panel; subscribes to
  `EconomyState`/`PreferenceState`/`BackDoorState`; renders `TeahouseMenuModel`; fires
  `RequestPurchase` (reuse), `SetDisplay` (new), `SetPadPreference` (reuse — for *remove* favorite).
- **`EconomyController`** — drop the alternating deck↔teahouse *upgrade* prompt; **keep** the
  vacant-pad buy-to-claim world prompt.
- **`PerchPreferenceController`** — unchanged (walk-up add-favorite).
- **`BackDoorController`** — unchanged (at-your-teahouse bay picker).

## Testing & verification

- **Server (Vitest):** `User` display fields default/validate; `POST /economy/display` persists +
  rejects invalid (display > owned, teahouse > displayed deck, `'none'` on deck); `GET /economy`
  returns the fields.
- **Luau (Lune):** `resolveBuilt` display caps (each dimension, `'none'`, clamp-to-owned,
  `teahouse ≤ displayed deck`, `null` = unchanged); `TeahouseMenuModel.viewModel` (owned marks, next
  price, affordability gating, teahouse-locked-by-deck, enabled display options, favorites list).
- **Not Lune-testable (Roblox datatypes) → visual gate:** the HUD button + panel render and drive;
  the panel controller's wiring to remotes. Gate walks: open panel; buy a deck/teahouse upgrade and
  see the rebuild + points debit; set deck display S and teahouse display None and see the perch
  rebuild; remove a favorite; confirm the first-deck preview state for a non-owner and that
  claiming still works in-world.

## Non-goals / deferred

- **Decoration catalog** (koi pond, gardens, feeders that fill the freed perch space) — a later
  sub-project; B3 only *creates* the free space via display caps.
- **Familiars, spectacle sinks (fireworks/lanterns), point sources** — out.
- **Multi-perch ownership / per-perch display prefs** — display is a single global pair of caps
  (the player builds at one claimed perch at a time); revisit if multi-perch ownership lands.
- **Moving the back-door editor into the panel** — stays in-world (needs the physical teahouse); the
  panel only *reflects* its state.
- **Remote (from-anywhere) claiming or back-door editing** — claiming and the bay picker stay
  location-tied.
- **Robux / dual currency** — points-only v1 per the metagame spec.

## Open decisions (resolved in brainstorm)

- **Scope:** UI consolidation **+** the display-size toggle (not UI-only).
- **Entry point:** persistent HUD button is primary; world prompts shrink to claim + back-door +
  favorite-add.
- **Favorite:** add-in-world (walk-up toggle), review/remove-in-HUD.
- **Display size:** applies to **both** deck and teahouse, independently, as visual caps; deck floor
  is `S`, teahouse floor is `None`; still `teahouse ≤ displayed deck`.
- **First deck:** buying `deck:S` stays a world buy-to-claim (it targets a specific pad); all later
  upgrades are buyable in the HUD panel.
