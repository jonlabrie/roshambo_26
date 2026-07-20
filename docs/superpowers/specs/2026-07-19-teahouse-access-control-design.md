# Teahouse Access Control (Piece B) — Design

Approved in brainstorm 2026-07-19.

## Goal

Let a teahouse owner control who may enter their deck, and enforce it physically in-world across
the walk-in route (paths/tunnels). An owner picks one of three access modes — **Public** (anyone),
**Friends** (their Roblox friends), or **Private** (owner + an explicit invite list) — and disallowed
players are stopped by themed threshold gates (felt hard wall) backed by a server region-gate
(authoritative teleport-back). Portal-in needs no change: it only ever lands you on your *own* deck.

## Scope

**In:** the 3-mode per-player access policy + persisted invite list (by userId); username→userId
resolution; per-viewer enforcement via client-rendered themed gates at the deck's open back edge
(derived) and authored tunnel mouths (surveyed); a server region backstop that evicts/bounces
disallowed players; a management UI in the B3 teahouse panel; the per-pad tunnel-gate survey.

**Out (deferred):** guest-pass / portal-to-a-friend's-teahouse (a future portal slice — it will be
governed by the same `canEnter` when built); block/ban lists (this ships allow-lists only);
per-decoration or per-floor access; time-limited passes; final gate ART (placeholder noren/shoji
first, art pass later).

## Key facts this builds on

- **Access only matters while a teahouse is lit (owner present).** On leave, `SiteCoordinator`
  releases the pad and it rebuilds vacant/dormant — nobody's teahouse — so gates only ever exist
  around a currently-occupied deck, and the owner is therefore always online when their gate is up.
- **Walk-in is the only uncontrolled route.** Decks are railed on front/left/right but deliberately
  **open at the back** for path access; portal-in lands you on your own deck only.
- **No collision groups are used yet** and Roblox caps them at ~32, so per-teahouse collision groups
  don't scale. Enforcement is therefore per-client-local parts (each client only answers "is this
  gate solid to me?") plus a server backstop.
- Deck-relative geometry (a fixture placed from `deckCF` + `deckSize`) is an established pattern
  (portal control, `RailBarrier` fall-guard).

## Decisions (brainstorm)

- **3-way mode, Public default:** `public` | `friends` | `private`. The world starts open; a gate is
  the exception, not the rule.
- **Invite by username, persisted by userId.** The owner types a username; the **Roblox server**
  resolves it (`UserService`) and persists the numeric userId. Works for offline players. The
  backend server never sees usernames.
- **Hybrid enforcement:** client-rendered themed threshold gates (the felt hard wall, per-viewer) +
  a server region-gate (authoritative teleport-back backstop).
- **Themed threshold gates + invisible backstop:** visible ZenDojo gates (noren/shoji placeholder) at
  the entry points — the deck's open back edge (derived, universal) and tunnel mouths (authored,
  "where appropriate"); non-threshold approaches (a side jump-in, an exploiter, an eviction) are
  caught by the invisible server backstop.
- **Per-player access** (one claimed pad at a time, like the portal and decorations).
- **Owner is always allowed** (can't self-lock, can't self-invite). Invites dedupe; `MAX_INVITED = 50`.

## Data model

**`User.teahouseAccess: { mode: 'public' | 'friends' | 'private', invited: number[] }`** — default
`{ mode: 'public', invited: [] }`. Per-player. `invited` is a list of Roblox **userIds** (numbers),
never usernames, length ≤ `MAX_INVITED`.

## Pure logic (Lune-tested, Luau)

**`AccessPolicy.canEnter(mode, invited, viewerId, ownerId, isFriend) -> boolean`** — the whole
decision, no Roblox datatypes:
- `viewerId == ownerId` → `true` (owner always in)
- `public` → `true`
- `friends` → `isFriend`
- `private` → `invited` contains `viewerId`
`isFriend` is resolved on the Roblox server (`viewer:IsFriendsWith(ownerId)`) and passed in, so the
rule stays pure.

**`AccessGates.deckBackGate(deckCF12, deckSize) -> { cframe = cframe12, size = {sx, sy, sz} }`** and
**`AccessGates.evictionPoint(deckCF12, deckSize) -> cframe12`** — derive the deck-back gate (a wall
spanning the open back edge, tall enough to seal — distinct from and taller than the deliberately-low
fall-guard) and the eviction target (just outside the back edge, on the path side) from the deck
footprint. Both `cframe`/`cframe12` are 12-number row-major arrays and `size` is a 3-number array, so
the helper is pure (no Roblox datatypes; mirrors `PortalTarget`/portal-control placement math); no
per-pad authoring. Runs **server-side** so the client stays a thin renderer. (The gate is only ever
built for a *blocked* viewer, so it never affects the owner's own use of their deck, e.g. launching
fireworks.)

## Backend server (TS, `/api/v1`)

- `User.teahouseAccess` schema subdoc (mode enum default `public`, invited `[Number]` default `[]`).
- **`validateAccess(payload)`** (new, `loadout.ts`/`economy.ts`): `mode` in the enum; `invited` an
  array of positive-integer userIds, unique, length ≤ `MAX_INVITED`; no extra keys → else
  `BAD_ACCESS`.
- `GET /economy` returns `teahouseAccess`.
- New **`PUT /players/:robloxUserId/access`** — replaces the whole validated payload (same shape
  discipline as `PUT /decorations` / `PUT /preferences`), 400 `BAD_ACCESS` on malformed, no partial
  write.
- The backend never resolves or stores usernames — it only ever sees numeric userIds.

## Roblox server

- `playerEconomy[uid].teahouseAccess` stashed from the join fetch; kept current on
  set-mode/invite/revoke; used in the per-viewer blocked-set computation.
- **Friend resolution:** for a `friends`-mode owner, `viewer:IsFriendsWith(ownerId)` (yields) resolved
  and cached per `(viewerId, ownerId)`; recomputed on viewer join / owner mode change.
- **Blocked-set computation + push:** for each viewer, for each currently-occupied pad, evaluate
  `AccessPolicy.canEnter`; when `false`, the pad is blocked. The server computes each blocked pad's
  gate specs — the derived deck-back gate (`AccessGates.deckBackGate`) + any authored tunnel gates
  (`PadSites[padId].accessGates`) — and pushes **`AccessBlocked { blocked: {{ padId, gates: {{cframe12, size}} }} }`**
  to that viewer only (invite lists never leave the server). Recompute + re-push triggers: an owner's
  `SetAccess`/`InviteUser`/`RevokeUser`, a pad claimed/released (occupied set changes), a viewer join.
- **New remotes** (register in `default.project.json`); the three client→server ones are on the
  HandlerQueue (per-uid), owner/occupant-gated (`e ~= nil and e.claimedPadId ~= nil`), with the
  post-yield `player:IsDescendantOf(Players)` re-check the decoration handlers use (`UserService` +
  the PUT both yield):
  - **`SetAccess { mode }`** — validate mode, update stash, PUT, recompute+push all viewers, echo `AccessState`.
  - **`InviteUser { username }`** — `UserService:GetUserIdFromNameAsync(username)`; on success add the
    userId (dedupe, enforce `MAX_INVITED`), PUT, recompute+push, echo `AccessState`; a bad/nonexistent
    name or full list → failure toast, no write.
  - **`RevokeUser { userId }`** — remove, PUT, recompute+push, echo `AccessState`.
  - **`AccessState { mode, invited: {{ userId, name }} }`** (server→owner) — feeds the panel; the
    server resolves each stored userId back to a display name (`UserService`) and **filters it through
    the existing `filterExternalName` path** before sending.
  - **`AccessBlocked { blocked }`** (server→each client) — drives the client gates (above).
- **`NetworkClient.setAccess(robloxUserId, { mode, invited })`** → `PUT /players/{id}/access`.
- **Server backstop:** watch each occupied deck's region (deck footprint → world AABB) on a short
  timer; any player inside for whom `canEnter` is `false` is `PivotTo`'d to `AccessGates.evictionPoint`.
  Owner + allowed guests are never moved. This one mechanism covers side jump-ins, exploiters who
  nulled a local gate, and **eviction** when a mode flips to Private or an invite is revoked.

## Client

- **`AccessGateController` (new client controller):** on `AccessBlocked`, (re)build client-**local**
  gate parts for each blocked pad from the pushed `gates` specs — anchored, `CanCollide = true` for
  the LocalPlayer only (client-local parts, so no collision-group limit), placeholder noren/shoji
  art. Keyed by padId so a re-push replaces cleanly; a pad no longer in the payload has its gate
  removed (owner left, or the viewer became allowed → walk straight in). The controller is a thin
  renderer — all geometry is computed server-side and sent as specs.
- **Panel Access section** in `TeahouseController` (owner-only, on the claimed pad): a 3-way mode
  toggle (Public / Friends / Private, styled like the display rows); when Private, an expanded
  username text field + **Invite** button + a scrollable invitee list (resolved name + revoke ×).
  Fires `SetAccess` / `InviteUser` / `RevokeUser`; renders from the `AccessState` echo. The list
  stores userIds but shows names (server-resolved, one-directional).

## Tunnel-gate survey (authoring)

- **`PadSites[padId].accessGates: {{ cframe12, size }}`** — an optional per-pad list (most pads 0 or
  1), the tunnel-mouth gate placements, authored only where a tunnel is the access ("where
  appropriate"). The universal deck-back gate + backstop enforce access without them; tunnel gates
  are the earlier-bounce chokepoint.
- **`tools/studio/surveyAccessGates.luau`** — a draggable-slab survey tool (like the deck-placement
  survey): drag a slab into each tunnel mouth, bake its CFrame + size into `PadSites[padId].accessGates`.

## Error handling

- Malformed access payload on the PUT → `BAD_ACCESS` (400), no partial write.
- Unknown/unresolvable username → toast, no write (list unchanged).
- Invite over cap / duplicate → toast / silent dedupe, no write.
- Non-owner / non-occupant firing a mutating remote → ignored (occupant gate, like the decoration
  handlers).
- A viewer already on a deck when the owner locks it / revokes them → bounced by the backstop next
  tick (no separate path).
- Owner offline → pad dormant/vacant, no gates, no backstop region.

## Testing & verification

- **Lune:** `AccessPolicy.canEnter` truth table (owner/public/friends±friend/private±invited);
  `AccessGates.deckBackGate` + `evictionPoint` geometry (spans the back edge; eviction sits outside
  it); the panel Access view-model (mode/invitee rendering, owner-only gating).
- **Vitest:** `validateAccess` (mode enum, userId array, cap, dedupe, extra key, malformed);
  `PUT /access` persists + rejects malformed; `GET /economy` returns `teahouseAccess`.
- **Visual gate:** set Private → a second player bounces at the deck-back gate and (if they jump the
  side) is bounced by the backstop; set Friends → a friend auto-passes, a non-friend is stopped;
  invite-by-username lets a named player in (online/offline); revoke evicts them; the tunnel-mouth
  gate stops a blocked player at the tunnel; the owner and allowed guests always pass.

## Non-goals / deferred

- **Guest-pass / portal to a friend's teahouse** — a future portal slice; it will be governed by
  `AccessPolicy.canEnter` when built (the seam is already here).
- **Block/ban lists** (deny specific players) — this ships allow-lists only.
- **Per-decoration / per-floor / time-limited access** — out of scope.
- **Gate art** — placeholder noren/shoji now; the themed art pass comes later.
