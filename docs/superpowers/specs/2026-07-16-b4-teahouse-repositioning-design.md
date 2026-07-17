# B4 Teahouse Repositioning — Design

**Piece B, sub-project 4.** Approved in brainstorm 2026-07-16.

## Goal

The player chooses where their teahouse sits on the deck — position and facing — instead of
today's hard-centered `{offset={0,0}, facing="N"}`. Repositioning is the payoff of "the deck is
a yard": a small teahouse on a big deck frees space, and B4 lets the player decide which corner
it parks in and which wall faces the view.

**Interaction (user decision):** an in-world **ghost drag** — a translucent copy of the building
follows the player's aim across the deck, snaps to a 1-stud grid, **R rotates in 90° steps**
(N→E→S→W), click commits, X cancels (Esc is reserved by the Roblox core menu). Entry is a
**"Move teahouse" button in the B3 panel**;
commit is a single click.

## Decisions (brainstorm)

- **Ghost drag** over panel-nudge controls or authored preset spots.
- **90° rotation steps** in-mode (matches `BuildingPlacer`'s 4 cardinal facings; the fit-check
  already swaps footprint extents at 90°/270°). No free rotation.
- **Panel-button entry, click commit** — no walk-up prompt (key crowding: F = back door,
  E = favorite).
- **Per-size persistence in the loadout** — `placement` joins `wallBays` inside each teahouse
  size's loadout. Each size remembers its own spot; display-switching restores it. No new User
  fields or routes.
- **Clamp into bounds** when a saved placement doesn't fit the currently-built combination
  (e.g. deck display shrunk). Build-time only — the stored value never changes; restoring the
  bigger deck restores the exact saved spot. Same philosophy as the B3 display clamp.
- **Client ghost, server-validated commit** (approach 1): the ghost is client-only; the commit
  re-validates on the Roblox server with the same shared pure math, then persists via the
  existing loadout PUT.

## Data model + persistence

`placement = { offset = {dx, dz}, facing = "N"|"E"|"S"|"W" }`, deck-local studs, stored inside
the per-size teahouse loadout.

- `server/src/loadout.ts`: `LOADOUT_KEYS` gains `'placement'`; new `validatePlacement` —
  `offset` is exactly 2 finite numbers, each within ±32 (sanity bound beyond any deck
  half-extent), `facing` in the 4-letter whitelist. Malformed placement rejects the PUT
  (mirrors `validateWallBays`). Rides the existing `PUT /api/v1/players/:id/teahouses/:size`.
- **Absent placement = centered.** Existing loadouts keep today's behavior; no migration.

## Pure logic (Lune-tested)

- **`BuildingPlacer.clamp(buildingFP, deckFP, placement) → Placement`** — new pure sibling of
  `fits()`: per-axis, slide `offset` the minimum distance so the rotation-aware footprint sits
  inside the deck (yaw 90/270 swaps half-extents, as `fits` does). Degenerate case (building
  wider than the deck on an axis) centers that axis. Facing is preserved.
- The hard-coded `CENTERED` at the 4 build call sites (SiteCoordinator starter + `onJoin`,
  `main.server.luau` upgrade rebuild + SetDisplay rebuild) becomes
  `loadout.placement or CENTERED`.
- `TreatmentApplier._buildBuilding`'s current warn-and-skip on an unfit placement becomes
  **clamp, then build**; the warn-skip remains only as a final guard for pathological data.
- 1-stud snapping is client-side UX; the server stores what it clamps (not raw client values).

## Roblox server

New **`SetPlacement`** RemoteEvent (register in `default.project.json`; restart `rojo serve`).
Handler in `main.server.luau`, modeled on `SetDisplay` with the B3-gate lessons applied:

1. **Gate:** `playerEconomy[uid]` exists and `e.claimedPadId ~= nil` (occupant-only).
2. **Resolve the built combination:** `SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes,
   spec.maxSize, e.deckDisplay, e.teahouseDisplay)`. No built teahouse (bare deck) → ignore.
   The placement persists under the **built teahouse size's** loadout — you move what you see.
3. **Server-authoritative validation:** whitelist `facing`; require 2 finite offset numbers;
   `BuildingPlacer.clamp` against `SizeClasses.buildingFootprint(built.teahouseSize)` vs
   `deckFootprint(built.deckSize)`; persist the **clamped** result.
4. **Persist:** merge `placement` into a **clone** of `e.teahouses[size]` (pre-persist clone
   discipline), `net:setTeahouse(uid, size, newLoadout)`.
5. **Post-yield `player:IsDescendantOf(Players)` re-check**, then update **both stashes** —
   `e.teahouses[size]` AND `playerHouse[uid].loadout` (the staleness pair from the B3 gate) —
   rebuild via `applier:apply`, and `echoBackDoor` (the geometry-watch back-door controller
   re-arms F prompts on the new structure regardless of event/replication order).

**Build-site support:** `TreatmentApplier:apply` stamps three attributes on the site folder at
commit (alongside the existing `Occupied`): **`MountCF`** (deck mount CFrame), **`DeckSize`**,
**`TeahouseSize`** (empty string for bare deck). These give the client an authoritative
deck-local frame + footprint keys without exposing the server-only `PadSites`.

## Client

**`MoveController.client.luau` (new)** owns the mode; the B3 `TeahouseController` only gains a
"Move teahouse" button and publishes a request over the client `EventBus` (M4a pub/sub),
carrying `{ padId }` from the EconomyState echo the panel already holds. This keeps the drag
machinery out of the already-large panel controller.

- **Button gating:** new `TeahouseMenuModel` flag **`canMove`** — true iff claimed AND a
  teahouse is actually displayed (owner of only a deck, teahouse display "none", or unclaimed
  → false). Lune-tested beside `needsClaim`.
- **Mode start:** find own site folder (`MaterializedSite_<claimedPadId>` — padId from the
  EconomyState echo the panel already holds) and its `Structure`. Clone it as the **ghost**:
  `CanCollide/CanQuery/CanTouch` off, parts translucent (~0.55). The original building gets
  `LocalTransparencyModifier ≈ 0.7` (client-only fade; other players see no change until
  commit). The ghost **starts at the building's current position and facing** (initial
  deck-local offset/yaw derived from the live structure's pivot vs the `MountCF` attribute),
  so entering and immediately committing is a no-op move.
- **Drag loop (RenderStepped):** camera ray from cursor/touch → raycast filtered to the site
  folder (excluding the ghost itself) →
  hit position → deck-local via the `MountCF` attribute → snap to 1 stud →
  `BuildingPlacer.clamp` (shared module: identical math to the server) → ghost `PivotTo`. The
  ghost is therefore always in a committable spot — no invalid/red state exists. Aim off the
  deck → ghost holds the last valid position.
- **Mode HUD:** a minimal pinned strip — Rotate ⟳ / Confirm ✓ / Cancel ✕ — with R / click /
  X as desktop shortcuts (Esc is reserved by the Roblox core menu; the ✕ button is the primary
  cancel). The buttons make the mode touch-usable on mobile with no extra
  input handling.
- **Commit:** fire `SetPlacement:FireServer({offset={dx,dz}, facing=f})` once, exit the mode
  immediately (restore transparency, destroy the ghost). The server rebuild arriving is the
  confirmation.
- **Cancel / self-cancel:** Cancel restores everything untouched. The mode also exits on
  character death/respawn and on the live structure's `Destroying` (a rebuild landing
  mid-mode).

## Error handling

- Server ignores `SetPlacement` from non-occupants, bare-deck states, or malformed payloads
  (same silent-drop discipline as the sibling handlers; the panel's `canMove` gating makes
  those unreachable through the UI).
- A failed `net:setTeahouse` warns and skips the rebuild (loadout PUT failure — same
  best-effort semantics as the B1 back-door persist), then `echoEconomy` resyncs.
- Unfit stored placements never error at build time: clamp always succeeds for
  building ≤ deck, which `resolveBuilt` guarantees by construction.

## Testing & verification

- **Lune (TDD):** `BuildingPlacer.clamp` — in-bounds no-op; per-axis minimal slide; rotated
  (E/W) footprints; degenerate centering; facing preserved. `TeahouseMenuModel.canMove` —
  claimed+shown true; unclaimed / bare-deck / display-none false.
- **Vitest (TDD):** `validatePlacement` — accepts valid; rejects wrong arity, non-finite,
  out-of-range, bad facing; `placement` accepted in `LOADOUT_KEYS`; unknown keys still reject.
- **Visual gate (not machine-testable):** mode feel (drag/snap/rotate/HUD); commit rebuild
  lands where the ghost stood; per-size memory (park L, display M, park M elsewhere, restore
  L); clamp on display shrink; back-door F prompts re-arm on the moved building; original
  fades only locally.

## Non-goals / deferred

- **Free rotation** (non-cardinal yaw) — `BuildingPlacer` stays 4-facing.
- **Decoration placement** — this mode moves the teahouse only; the decoration catalog is a
  later sub-project (B3 freed the space, B4 frees the layout).
- **Per-pad placement memory** — placement is per teahouse size, not per perch; revisit if
  multi-perch ownership lands.
- **Walk-up entry prompt** — panel button only (key crowding on the teahouse).
- **Collision/walkway rules beyond the deck-bounds fit** — the deck is a yard; parking flush
  against a railing is the player's choice. The back door (B1) covers enclosed access.
