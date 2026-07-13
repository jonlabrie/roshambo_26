# B1 — Player Back Door (design)

**Piece B, sub-project 1.** The first slice of the ZenDojo teahouse economy /
customization layer: let a player add (or remove) a **back door** on the teahouse
they currently occupy. It is the smallest end-to-end edit→persist→render loop over
the SP1 modular-bay machinery, and it is what finally drives that machinery in
production (today `loadout.wallBays` is always `nil`, so every wall renders its
default and the modular-bay feature is dormant).

## Why this first

The teahouse *machinery* is done (Piece A pad/deck separation; SP1 modular
`solid | shoji | door` bays with sliding shoji + pocket doors; per-size deck
placement). What is missing is any way for a player to *change* their teahouse and
have it *earned/persisted*. B1 is the narrowest vertical slice that exercises the
whole chain — client edit → server authority → persistence → live re-render — while
solving a concrete need: on tight perches (e.g. T05) an L teahouse leaves no room to
walk around the sides, so the player needs a door out the back.

Two gaps B1 must close, both pre-existing:

1. `server/src/loadout.ts` `validateLoadout` **rejects `wallBays`** as `UNKNOWN_KEY`.
   Until it is whitelisted (with real structural validation), `loadout.wallBays` can
   never be persisted, so the runtime always resolves default bays.
2. There is **no client path** to edit any loadout field. Favoriting
   (`padPreferences`) is the only interaction that persists anything today.

## Non-goals (explicitly deferred)

- **Side-exit / front doors.** v1 is back-wall-only. Side and front door bays wait
  for the general customization editor (B3).
- **General customization** (colorScheme, shoji/tatami textures, flags, arbitrary
  `wallBays`) — that is B3.
- **Economy / points.** A back door is functional access and is **free**; earning
  and gating are B2.
- **Teahouse repositioning** on roomy decks — B4.
- **New geometry behind the wall.** The door opens onto the back strip of the deck
  that already exists (the teahouse is centered on its deck).
- **Multiple simultaneous back doors.** One door slot (see below).

## Behavior

- **Surface:** a `ProximityPrompt` on each of the **3 back bays**
  (`Bay_back_1`, `Bay_back_2`, `Bay_back_3`) of the teahouse the **local player
  currently occupies**. No prompt on other players' teahouses, and none on the
  front/side bays.
- **One door slot:** triggering a back bay's prompt makes *that* bay a `door` and
  reverts any previously-doored back bay — at most one back door at a time.
  Triggering the currently-doored bay again removes the door (that bay returns to
  `solid`).
- **Live + persistent:** the edit re-renders the occupied structure immediately
  (the door opens; the player can walk through onto the back of the deck) **and**
  persists to that size's `wallBays` so the door is present the next time the player
  spawns onto a perch with that size.
- **Per-size:** the edit persists to the loadout of the **currently-occupied size**
  only. A player who owns both an M and an L and adds a door to their L does not
  change their M — they are different buildings with independent loadouts.
- **Free:** no points cost.

## Architecture

Server-authoritative, mirroring the existing favoriting flow
(`PerchPreferenceController` + `SetPadPreference`/`PreferenceState` + server
persistence). The client only *requests*; the server validates occupancy, applies
the live re-render on the replicated model, and persists.

### Data flow

```
player triggers Bay_back_i prompt (their own occupied teahouse)
  client  BackDoorController  --SetBackDoor{ bayIndex = i }-->  Roblox server
  server:
    1. occupant check: firer == _held owner of that pad?  (else ignore)
    2. range check: 1 <= i <= backBayCount               (else ignore)
       backBayCount = # of "back" bays from readManifest(Structure) (not hardcoded)
    3. newWallBays = BackDoorEditor.setBackDoor(currentWallBays, i, backBayCount)
    4. merge newWallBays into the occupied SIZE's loadout (in-memory stash)
    5. live re-render: applyBays(Structure,
         WallBays.resolve(readManifest(Structure).bays, newWallBays))
    6. persist: net PUT /players/:id/teahouses/:size  { loadout }
    7. echo: BackDoorState{ padId, backDoorIndex }  --> firer
  client  BackDoorController  relabels prompts (active bay = "Remove door")
```

The live re-render works because `StructureOps.applyBays` only **shows/hides** each
bay's `Solid`/`Shoji`/`Door` variant (via `Transparency` + `CanCollide`); the
variants persist as direct children of the built `Structure` model, so re-applying
is cheap and needs no rebuild. Because the server mutates the replicated model, all
clients see the door.

### Components

| Component | File | Kind | Responsibility |
|---|---|---|---|
| `BackDoorEditor` | `roblox/src/shared/BackDoorEditor.luau` | pure, Lune-tested | one-door-slot logic: `setBackDoor(wallBays, index?, backBayCount) → newWallBays` |
| `BackDoorController` | `roblox/src/client/BackDoorController.client.luau` | client | attach/relabel back-bay prompts on the occupied Structure; fire `SetBackDoor` |
| Remotes | `roblox/default.project.json` (`RoshamboRemotes`) | contract | `SetBackDoor` (RemoteEvent, C→S), `BackDoorState` (RemoteEvent, S→C) |
| Server wiring | `roblox/src/server/main.server.luau` | server | loadout stash; `SetBackDoor` handler; occupant/range checks; live `applyBays`; persist; echo `BackDoorState` on claim + after edit |
| Loadout validation | `server/src/loadout.ts` | server (Node) | whitelist `wallBays`; add `validateWallBays` |

### `BackDoorEditor.setBackDoor`

Pure. Given the current `wallBays` map (or `nil`), a chosen back-bay `index` (or
`nil` to clear), and the back bay count:

- Produces a **dense** `back` list of length `backBayCount` (e.g.
  `{ "solid", "door", "solid" }`) so it serializes as a JSON array, not a sparse
  object. `back` default is `solid`, matching `WallBays.defaultState("back")`.
- If `index == nil`, or `index` equals the bay that is currently the back door
  (toggle-off), the `back` key is dropped from the returned map (falls back to
  all-`solid` defaults).
- Other sides in the map are passed through unchanged (B1 only touches `back`).
- Returns a **new** map (does not mutate the input).

Signature:

```lua
function BackDoorEditor.setBackDoor(
    wallBays: WallBays.Map?,   -- current map (may be nil)
    index: number?,            -- chosen back bay, or nil to clear
    backBayCount: number       -- number of back bays (3)
): WallBays.Map
```

Note `index` is assumed in range; the **server** performs the `1..backBayCount`
range check before calling (an out-of-range index is a rejected request, not an
editor concern). The editor's own tests still cover clamping behavior for safety.

### Remotes

- `SetBackDoor` (RemoteEvent, client→server): payload `{ bayIndex: number }`. The
  server derives the pad and size from the firer's held claim — the client never
  names the pad or size.
- `BackDoorState` (RemoteEvent, server→client): payload
  `{ padId: string, backDoorIndex: number? }` where `backDoorIndex` is the bay
  currently doored (or `nil`/absent for no back door). Sent to the owning player on
  claim and after each successful edit. The client uses `padId` to locate the
  occupied Structure and `backDoorIndex` to label prompts.

### Server (Roblox) changes

- **Loadout stash:** a per-player table (parallel to `playerPrefs`) holding the
  loadouts fetched at join (`res.data.teahouses`) plus the occupied size, so an edit
  can merge `wallBays` without re-fetching. Cleared on `PlayerRemoving`.
- **`SetBackDoor.OnServerEvent`:** occupant check (`_held`/held owner), range check,
  `BackDoorEditor.setBackDoor`, merge, live `applyBays` on the occupied
  `Structure`, persist via `net` PUT, echo `BackDoorState`.
- **Claim echo:** where `onJoin` succeeds and the teahouse is built, compute the
  initial `backDoorIndex` from the built loadout's `wallBays.back` and fire
  `BackDoorState` to the player (alongside the existing `PreferenceState` fire).

### Server (Node) changes — `server/src/loadout.ts`

- Add `'wallBays'` to `LOADOUT_KEYS`.
- Add `validateWallBays(value)`:
  - `value` must be an object (not array/null).
  - Each key must be a known side. The known-sides set must equal the prefab's
    authored `Side` attribute values — **confirm the exact strings against
    `roblox/tools/studio/captureTeahouseBase.luau` / the prefab before implementing**
    (expected `front`, `back`, and the two side names; `WallBays.defaultState` only
    special-cases `front`). Validation whitelists exactly those.
  - Each value must be an array whose entries are all in `solid | shoji | door`.
  - Each side list length ≤ `MAX_BAYS_PER_SIDE = 8` (a generous cap; the prefab has
    at most 3 bays on any side) to bound the persisted payload.
- `validateLoadout` calls `validateWallBays(obj.wallBays)` when `wallBays` is present
  and returns its error (e.g. `BAD_WALLBAYS`) on failure. Absence is valid.

## Interfaces this consumes (already exist)

- `StructureOps.applyBays(model, bays)` and `StructureOps.readManifest(model)`
  (`roblox/src/server/StructureOps.luau`).
- `WallBays.resolve(available, map?)`, `WallBays.Map`, `WallBays.STATES`
  (`roblox/src/shared/WallBays.luau`).
- `net:getTeahouses(userId)` and a PUT counterpart (`/api/v1` teahouses routes;
  add a `setTeahouse`/`putTeahouse` client method on `NetworkClient` if one does not
  already exist).
- `MaterializedSite_<padId>.Structure` with direct-child `Bay_back_<i>` models
  (built by the structure builder on claim).

## Error handling (F2/F4: non-fatal, never crash the round loop)

- Firer is not the pad occupant → ignore the request (no state change, no echo).
- `bayIndex` out of `1..backBayCount` → ignore.
- Occupied `Structure` or its back bays not found (streaming/race) → skip the live
  re-render; the persisted `wallBays` still saves, so the door appears on the next
  build. Warn, do not error.
- `Door` variant missing on a bay → `applyBays` already warns and keeps the authored
  default (existing behavior).
- Persist PUT fails → the live door already applied this session; log a warning. The
  edit is not lost for the session; it is lost for next join. (Acceptable for v1;
  a retry is out of scope.)

## Testing

- **Vitest** (`server/`): `validateWallBays` accepts valid maps and rejects a bad
  state, a non-array side value, an unknown side key, and an over-length list;
  `validateLoadout` now accepts a loadout carrying a valid `wallBays` and rejects one
  with an invalid `wallBays`.
- **Lune** (`roblox/`): `BackDoorEditor.setBackDoor` — sets a door at an index
  (dense output, correct length, `door` at index, `solid` elsewhere); moves the door
  when a different index is chosen; toggles off when the active index is re-chosen or
  `index` is `nil` (drops `back`); passes other sides through unchanged; does not
  mutate the input.
- **Visual gate** (Studio): claim a teahouse, trigger a back-bay prompt, confirm the
  door opens live and is walkable; rejoin and confirm the door persists; confirm no
  prompt appears on another player's teahouse. (Manual, per sub-project D
  convention.)

## Open decisions (resolved)

- **Whole-loadout PUT vs. narrow endpoint:** reuse `PUT /teahouses/:sizeClass`
  (whole-loadout replace) with an in-memory merge — no new REST surface.
- **Back-wall-only in v1:** yes; side/front doors are B3.
- **Apply timing:** live re-render now **and** persist for next join.
- **Bay choice:** player picks which back bay (per-bay prompts), one door slot.
