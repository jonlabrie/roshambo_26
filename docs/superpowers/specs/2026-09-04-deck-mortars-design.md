# Deck Mortars — Design

**Date:** 2026-09-04
**Status:** Approved in conversation (owner, 2026-09-04)
**Program context:** Fireworks distribution thread. Follows the kiku promotion, which exposed
the launch-origin placeholder: deck launches originated 6 studs above the player's own head
(owner: "I heard it launch from my deck and saw some debris, but where did it launch from
exactly?").

## Purpose

A player who owns mortars should see them ON their deck and watch their shells fly FROM them.
Two rulings shape everything:

- **Default-first** (owner): "players shouldn't have to know how to place a mortar on their
  deck before they can use it" — owning a mortar puts it at a sensible default spot
  immediately; placement is depth for players who care, learned through the decoration
  system they already know.
- **One tube per owned tier** (owner choice): S, M and L each render as their own tube,
  default-staggered along the deck's canyon-facing front edge — the deck shows the arsenal
  growing. **Gear is exempt from the 24-decoration cap.**

## 1. Persistence (backend — ships with a dev-backend deploy)

- `User.mortarPlacements: { [mortarId]: { offset: [number, number], facing: Facing } }` —
  deck-local, same coordinate/facing conventions as `DeckDecoration`. Absent key = default
  position; nothing to migrate.
- `PUT /players/:robloxUserId/mortar-placements` mirroring the decorations route: validates
  known mortar ids (`MORTAR_IDS` from `fireworks.ts`), numeric offsets, and that the player
  owns each mortar being placed. Full-list replace, like decorations.
- The economy/fireworks GET payloads gain `mortarPlacements` so the Studio server can render
  and compute launch origins.

## 2. Defaults (`roblox/src/shared/MortarPlacement.luau`, pure, Lune-tested)

`MortarPlacement.resolve(deckBounds, ownedMortars, stored, teahouseFP?) → { [mortarId]:
{ x: number, z: number, facing: Facing } }`

- Defaults sit along the **front edge** (the canyon-facing side; deck placements are
  view-oriented, so "front" is a fixed local direction), S/M/L left to right with even
  spacing, inset ~1 stud from the edge.
- Stored placements override defaults per mortar; both are clamped to deck bounds the way
  `DecorationLayout` clamps props (stored value never mutated — only what renders adapts).
- Mortars are FUNCTIONAL, so unlike decorations they never hide under the built teahouse:
  a default (or stored) spot overlapped by the teahouse footprint is nudged to the nearest
  clear front-edge position instead.

## 3. Render (Roblox side)

- Tube geometry per tier reuses the proving-range mortar look at deck scale: metal cylinder
  on a small timber base — S/M/L at 2"/4"/6"-bore proportions (`1 stud = 1 foot`), built by
  a `DecorationCatalog`-style placeholder builder (art pass later).
- Rendered and re-rendered by the same machinery that draws decorations (live rebuild on
  placement change, tagged models, prompts overlaid by the framework — not by the tube).
- Every player's mortars are visible to every visitor, like decorations.

## 4. Launch origin (Studio server)

- In `RequestFireworkLaunch`, when the launch validates at the player's OWN deck site and
  the shell's requirement is `{ kind = 'gear' }`: origin = the **muzzle of the required
  tier's tube** (deck CFrame ∘ mortar's deck-local offset, + tube height). A peony leaves
  the S tube, a willow the M, a kiku the S — physically honest, and a mortar upgrade
  visibly relocates where shells fly from.
- `firecracker` (requirement `none`) stays hand-launched from the player — it is the shell
  you hold.
- Launches at PUBLIC sites (Overlook, bridge, falls dock) are unchanged in this design.
- The muzzle flash and trail machinery need no changes — they key off `payload.origin`.

## 5. Placement UX (back-door editor)

- Mortars appear in the back-door editor as movable gear: the decoration drag flow, but
  they cannot be removed, sold, or stored — owning a mortar means it lives on the deck.
  Move and rotate only.
- Server-side validation on the PUT mirrors decorations (bounds clamp philosophy: accept
  and clamp at render rather than reject).
- Cap display (`MAX_DECORATIONS = 24`) ignores mortars.

## 6. Tests

- `MortarPlacement.spec.luau` (Lune): default stagger on the front edge; stored override;
  clamping; teahouse-overlap nudge; unknown/unowned mortars ignored.
- Server (Vitest): PUT round-trip, validation (unknown id, unowned mortar, malformed
  offsets), payload carriage in the GET.
- Launch-origin math: pure portion (deck CFrame ∘ offset → world muzzle) extracted into a
  Lune-testable helper rather than living inline in `main.server.luau`.

## Non-goals

- Public-site mortar visuals (the Overlook etc. keep the current invisible origin).
- Mortar art pass (placeholder builders now, like decorations).
- Multiple mortars of the same tier, mortar trading/removal.
- Aiming/tilting mortars (origin only; trajectory stays the engine's).
