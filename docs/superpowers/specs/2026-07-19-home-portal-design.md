# Home Portal (MVP) — Design

**Piece B.** Approved in brainstorm 2026-07-19. Grew out of "spawn at my teahouse."

## Goal

Let a perch owner skip the long walk between the arena and their teahouse by installing a
**home portal** — a purchased upgrade linking their own deck ↔ the arena. Two fixed, visible
endpoints: an always-open **Arena Portal** near spawn that sends you to your own deck, and a
**deck portal control** on your railing that you interact with to open a portal and step through
to the arena. Also fold in the leftover-`DevChannelSpawn` cleanup so everyone reliably arrives at
`ArenaSpawn`.

This is the deliberately-limited first slice of a larger portal vision (buyable, one-per-floor,
friend-visiting). It is scoped to **your own** home↔arena only; guest passes and multi-destination
are explicitly deferred (see Non-goals) but the teleport core is built forward-compatible for them.

## Design principle (the constraint this respects)

Free point-to-point teleport would hollow out the valley/paths, which are intended as a
secondary arena for visual flexes (banners, fireworks). So portals are **limited, not a travel
graph**: the MVP has exactly two endpoints and moves you only between your home and the public
arena — the one commute everyone makes constantly. Non-buyers still walk. Local traversal of the
valley (to reach flex spots and each other) is untouched.

## Decisions (brainstorm)

- **Teleport action, not a spawn-location change.** Everyone spawns at the arena; the portal is a
  thing you use, so the character is already loaded when it triggers — no deferred-load / join-timing
  complexity.
- **Purchased point-sink**, sold through the existing `RequestPurchase` spine as item `"portal"`.
  One-time boolean (`portalOwned`); one portal per player for now (per-floor multiplicity waits for
  teahouse floors, which don't exist yet).
- **Physical, asymmetric endpoints.** Arena end: an always-open, always-visible portal structure —
  walk into it → go to your own deck. Deck end: a control fixture on the railing — interact ("Open
  portal") → a passable portal opens → step through → arena. (You *open* the deck portal; the arena
  portal is always open.)
- **Deck → arena is open to anyone on the deck.** It only sends you to the *public* arena, so it is
  not a privileged action; the deck control's mere existence means the owner bought it, and sharing
  it with visitors is a social upside. **Arena → a deck** is the personal direction (sends *you* to
  *your own* home); it is where the deferred guest-pass system will later hook in.
- **Placeholder art**, functional-first, art pass later — matching the project's build rhythm.

## Economy (server, TS)

- **`EconomyState`** (`server/src/economy.ts:9`) gains `portalOwned: boolean`.
- **`PRICES`** gains a flat `portal` price (placeholder, e.g. `500`) — not a size ladder.
- **`validatePurchase(state, "portal")`** — handled as a branch *before* the deck/teahouse split:
  requires `state.maxDeckSize !== null` (you need a deck for the control to attach to; a bare-deck
  owner qualifies), rejects with `ALREADY_OWNED` if `state.portalOwned`, then the standard points
  check. Returns `{ ok: true, cost }`.
- **`applyPurchase(state, "portal")`** sets `next.portalOwned = true`, subtracts the cost.
- **`User`** (`server/src/models/User.ts`) gains `portalOwned: { type: Boolean, default: false }`.
- **`GET /economy`** (`apiV1.ts` `readEconomy`) returns `portalOwned`; the purchase route already
  runs `validate`/`apply` generically — it persists `user.portalOwned` from the applied state and
  echoes it. Because the buy flows through `RequestPurchase`, it is already serialized by the
  HandlerQueue.
- **Purchase UI** is a row in the **B3 Teahouse panel** (`TeahouseController` + `TeahouseMenuModel`):
  a "Home Portal" buyable — price, affordability, owned-check — firing `RequestPurchase { item = "portal" }`.
  Gated like the other buyables (claimed owner). No new remote.

## Roblox server

**Threading `portalOwned` into the build.** `playerEconomy[uid]` gains `portalOwned`, set from the
join `getEconomy` and from the purchase response. It threads into the **treatment** table (like
`lit`) at *every* `applier:apply` site (join, buy-to-claim, upgrade rebuild, SetDisplay rebuild,
SetPlacement rebuild) as `portalOwned = e.portalOwned`. A portal purchase runs the existing
upgrade-branch rebuild so the control materializes immediately.

**`TreatmentApplier`** — after staging the deck + building, if `treatment.portalOwned` is true, it
builds the **deck portal control** fixture at a fixed deck-relative railing spot and tags it
`PortalControl` (with a `padId` attribute). Placeholder geometry; it reappears on every rebuild
because it is part of the build. Not built for vacant/dormant treatments (no owner).

**`PortalController` (new server module)** — keeps the portal wiring out of the already-large
`main.server.luau`:
- Builds the **Arena Portal** structure at a configured CFrame near `ArenaSpawn` on startup
  (runtime build, placeholder art, no place edit / no committed asset). It carries a passable
  trigger part; a character entering fires a server `Touched` handler → if that player owns a
  portal and has a claimed perch, `PivotTo` them to their deck landing (per-character debounce so
  it doesn't re-fire while standing in it).
- Watches (`CollectionService`) for `PortalControl` fixtures and wires each one's ProximityPrompt
  (persistent tagged-instance watcher, the geometry-race-safe pattern). Prompt "Open portal" is
  usable by **anyone** on the deck (no owner-check): Triggered → open a passable portal threshold
  (VFX placeholder) beside the control, active ~12s or until used; a character entering the open
  threshold is `PivotTo`'d to the **arena landing** (beside the arena portal, not inside its
  trigger), then the threshold closes. Auto-closes if unused.
- Reads the in-memory stash for eligibility/target (`playerEconomy[uid].claimedPadId`,
  `portalOwned`, built deck size). Both teleport handlers are pure teleports (no DB write) →
  **not** on the HandlerQueue.

**Teleport safety.** Server-side `character:PivotTo(targetCF)`; guard character exists + humanoid
alive. Owned decks are already materialized server-side, so destination geometry streams in around
the arriving character. Arrival landings are placed *beside* triggers (not inside) to avoid
instant bounce-back; re-entry debounce as a backstop.

**`DevChannelSpawn` cleanup (folded in).** A startup routine disables any `SpawnLocation` whose name
is not `ArenaSpawn` and ensures `ArenaSpawn.Enabled = true`. Code-only, self-healing (a future stray
spawn is neutralized too), no place edit — `DevChannelSpawn` is place-only, so runtime-disabling it
is the robust fix.

## Pure logic (Lune-tested)

**`PortalTarget` (new shared module):**
- `PortalTarget.deckLanding(deckCF12: { number }, deckSize: string): { number }` — composes the
  deck datum CFrame (`PadSites[padId].deckPlacements[deckSize]`) with a size-aware local offset to a
  walkable standing spot on the deck surface, facing the view. Returns 12-number CFrame components.
  The offset constants are gate-tuned; the test asserts the composition math (given a known
  `deckCF12` + offset, the returned components), not the magic numbers.
- `PortalTarget.ARENA_LANDING: { number }` — the fixed arrival CFrame beside the arena portal (a
  constant, gate-tuned).
- **Forward-compat:** the deck landing resolves from a `(deckCF12, deckSize)` pair, i.e. from a pad —
  a future guest pass supplies a *friend's* pad and gets the same resolution. The arena portal's
  "send home" is written as "send to a resolved destination," so a destination becomes a parameter
  later without reworking the teleport core.

## Error handling

- Buying a portal you already own → `ALREADY_OWNED` (400); buying without a deck → the deck-required
  error; insufficient points → `INSUFFICIENT_POINTS`. All surfaced by the existing purchase failure
  path (warn + `echoEconomy` resync), unchanged.
- Arena portal touched by a non-owner (no portal / no claim) → no-op (a landmark advertising the
  upgrade, like dormant teahouses advertise perches).
- Deck control opened but not stepped through in the window → threshold auto-closes; no teleport.
- Teleport with a missing/dead character → guarded no-op.

## Testing & verification

- **Vitest:** `validatePurchase`/`applyPurchase` for `"portal"` (needs-deck gate, `ALREADY_OWNED`
  double-buy, points spend); `User.portalOwned` default; `GET /economy` returns it.
- **Lune:** `PortalTarget.deckLanding` composition + `ARENA_LANDING` shape; `TeahouseMenuModel`
  portal-buyable flag (owned / affordable / gating).
- **Visual gate (not machine-testable):** buy via the panel and see the control appear on the
  railing; the control survives display/size/move rebuilds; open the deck portal and step through to
  the arena; walk into the arena portal and land on your deck; a non-owner gets a no-op at the arena
  portal but *can* use a deck control they're standing on; players reliably spawn at `ArenaSpawn`
  (DevChannelSpawn gone). Placeholder art acceptable; an art pass on both portal structures follows.

## Non-goals / deferred

- **Guest passes / visiting a friend's teahouse** — the next sub-project ("portal visiting / guest
  access"); overlaps the [[teahouse-access-control-backlog]] and needs its own brainstorm
  (target-player selection, grant persistence, one-time vs multi-use, revoke). The teleport core is
  built forward-compatible for it.
- **Multi-destination portals / a destination interface** — deferred with passes; MVP is home↔arena
  only.
- **Teahouse floors / one-portal-per-floor** — floors don't exist; MVP is one portal per player.
- **The fireworks-battle / valley-as-secondary-arena flex layer** — a separate large design area
  (competitive spectacle) the portal philosophy protects but does not build.
- **Art pass** on the arena portal + deck control + open-threshold VFX — functional placeholders
  now, art later.
- **Cross-server / friend graph** — none of this crosses server instances or needs a social graph in
  the MVP.
