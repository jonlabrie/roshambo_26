# Roshambo Loadout Persistence — Design (sub-project C)

**Status:** design approved in brainstorm (2026-07-05); pre-planning. First increment of sub-project C — server-side persistence of a player's teahouse loadouts. Vitest-tested, no Studio.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** persists A's structure loadouts (`{baseStyle, colorScheme, shoji, tatami, flags, …}`) so a player's customized teahouses survive sessions and materialize (via D) on whatever pad `PadRegistry.claimVacantFor` assigns. Extends the existing `/api/v1` REST surface (`server/src/routes/apiV1.ts`, `X-API-Key`-gated) and the `User` model. Realizes the [meta-game](2026-07-04-roshambo-metagame-design.md) "personal teahouses" pillar (points-only, server-authoritative).

## Problem

Players customize and (later) earn teahouses; those must persist server-side, not in Roblox DataStores (per the meta-game plumbing decision — one Node server + Mongo). A player owns a **set** of teahouses across footprint/size classes (S/M/L): the runtime materializes the size that fits the assigned pad, falling back to a smaller one when the large pads are taken or a neighborhood constrains the footprint. This increment stores and retrieves that set.

## Goals

- Persist a per-player **map of teahouse loadouts keyed by size class** on the `User` doc.
- `GET`/`PUT` `/api/v1` endpoints, `X-API-Key`-gated, keyed via `resolveUser({robloxUserId})`.
- Light validation (the caller is the trusted Roblox game server; the server is a persistence layer, not the loadout authority).
- Vitest-tested, following existing `apiV1` patterns.

## Non-goals (other sub-projects)

- **Ownership / earning gates** (can this player equip this item / has it earned this size?) — sub-project **E** (economy). This increment stores whatever loadout the trusted caller sends.
- **Matching** (pick which owned size materializes on which pad) — sub-project **D** / a generalization of B.4's `claimVacantFor` (currently single-footprint). C only stores the set.
- **Size-class definitions** (what S/M/L are, footprint ranges, neighborhood rules) — tier/pad classification, resolved with A's structure tiers and the pad survey.
- Deep loadout typing / validating component ids against the catalog (the catalog is A's, on the Roblox side).

## Architecture

### Model — `teahouses` on `User`

Add to `server/src/models/User.ts` (`IUser` + `UserSchema`):

```
teahouses: Map<string, Loadout>   // key = size-class id (e.g. "S"/"M"/"L"), default {} (a wanderer owns none)
```

Mongoose `Map` (`{ type: Map, of: Schema.Types.Mixed, default: {} }`) for dynamic keys with change tracking. A `Loadout` value is stored as-is (A's `{baseStyle, colorScheme?, shoji?, tatami?, flags?, wallArt?}`), light-validated at the route (below), not schema-typed.

### Endpoints (added to `createApiV1`, after `/players/:robloxUserId`)

```
GET /api/v1/players/:robloxUserId/teahouses
  -> 200 { teahouses: { [sizeClass]: Loadout } }   ({} for a wanderer)
  Cache-Control: no-store. resolveUser upsert; 500 RESOLVE_FAILED on null.

PUT /api/v1/players/:robloxUserId/teahouses/:sizeClass
  body { loadout: Loadout }
  -> 200 { sizeClass, loadout }   (the stored loadout)
  -> 400 BAD_REQUEST on validation failure.
  resolveUser upsert; sets user.teahouses[sizeClass] = loadout; persists.
```

Both reuse `requireApiKey` (already applied to the whole router) and `resolveUser({ robloxUserId: req.params.robloxUserId })`.

### Validation (light; `400 BAD_REQUEST` on any failure)

- `sizeClass`: a non-empty string, `<= 16` chars; the player's map may hold at most **8** classes (reject a PUT that would create a 9th new key).
- `loadout`: a plain object; serialized size `<= 4096` bytes; `loadout.baseStyle` is a non-empty string; every top-level key is in the whitelist `{ baseStyle, colorScheme, shoji, tatami, flags, wallArt }` (reject unknown keys). Values are **not** deep-validated (ownership/shape authority is elsewhere).

A small pure `validateLoadout(loadout)` / `validateSizeClass(sizeClass, existingCount)` helper (unit-testable independent of Express/Mongo) does this; the route calls it and maps failure to `400`.

## Testing (Vitest)

Following `server/src/routes/apiV1.test.ts` (supertest against `createApiV1`, mocked/omitted Mongo via the existing test harness) + `models.test.ts`:
- **Round-trip:** `PUT .../teahouses/M { loadout }` then `GET .../teahouses` → `{ teahouses: { M: loadout } }`.
- **Wanderer:** `GET` for a fresh user → `{ teahouses: {} }`.
- **Multiple sizes:** PUT S, M, L → GET returns all three.
- **Overwrite:** PUT M twice → GET reflects the second.
- **Validation (`400`):** non-object loadout; oversize (> 4 KB); missing/empty `baseStyle`; unknown top-level key; empty/oversize `sizeClass`; the 9th distinct size class.
- **Auth:** a request without the API key → `401` (existing `requireApiKey`).
- **`validateLoadout`/`validateSizeClass`** unit tests for each rule.

## v1 deliverables

1. `teahouses` field on `server/src/models/User.ts` (+ `models.test.ts` coverage).
2. A validation helper (`server/src/loadout.ts` or inline in the route module) + its unit tests.
3. `GET`/`PUT` teahouse endpoints in `server/src/routes/apiV1.ts` + `apiV1.test.ts` coverage.

## Build order

Add the `teahouses` model field → TDD the validation helper → TDD the `GET` endpoint (wanderer + populated) → TDD the `PUT` endpoint (round-trip, overwrite, validation `400`s) → commit.
