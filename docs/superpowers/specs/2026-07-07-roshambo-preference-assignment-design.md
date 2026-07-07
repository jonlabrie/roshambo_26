# Roshambo Preference-Aware Assignment — Design (sub-project D, increment 5.1)

**Status:** design approved in brainstorm (2026-07-07); pre-planning. First increment of D.5 (perch preference). Server (Vitest) + pure `SiteCoordinator` (Lune); no client UI yet.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** D.4 gave a joining player the largest owned size that fits a vacant *site*, biggest-first, scanning sites in registration order. D.5.1 makes that scan honor a **persisted per-player site preference**: within each size tier, the player's preferred perches are tried first. The thumbs-up/down UI that *sets* the preference is **D.5.2**; here the preference is stored server-side (same Mongo home as `teahouses`, C.1) and seeded for testing.

## Problem

The ephemeral pool assigns whichever fitting site comes first in registration order. Players want their **favorite perches**. A player's preference is an ordered list of site ids; on join, the size-cap scan should prefer higher-ranked sites — but only *within* the chosen size tier, so preference never trades away size (size stays primary, per the D.3/D.4 decision). Preference must persist per-player and be readable at join.

## Goals

- Persist `padPreferences: [siteId]` (ordered) on the `User` doc; expose it via REST (folded into the teahouses GET; a dedicated PUT to set it).
- `SiteCoordinator:onJoin` honors the preference: within each size tier, preferred sites first (preference order), then the rest (registration order).
- Fold in D.4's **F2** fix (pcall the applier's post-rebuild).
- Proven by Vitest + Lune + a seed-driven console/server gate (no UI).

## Non-goals (later)

- **Thumbs up/down UI** to set preference in-world — **D.5.2**.
- **F3 dead-code cleanup** (`PadRegistry.claimVacantFor`/`fits`/`claimVacant`/`findVacant`, `SizeClasses.nativeSize`) — a separate cleanup increment.
- **Preference editing from the client** (`NetworkClient` PUT) — D.5.2; here the game server only *reads* preference at join, and it's seeded via curl for the gate.
- Cross-server preference sync beyond the shared Mongo doc; per-neighborhood preference weighting.

## Architecture

Three thin touches; `NetworkClient` is unchanged (its `getTeahouses` returns the whole decoded body, so `res.data.padPreferences` rides through the fold).

### 1. Server — `padPreferences` on `User` + REST

- `server/src/models/User.ts`: add `padPreferences: { type: [String], default: [] }` to `IUser` + `UserSchema`.
- `GET /api/v1/players/:robloxUserId/teahouses` (`routes/apiV1.ts`): return `{ teahouses, padPreferences }` (the array, `[]` for a fresh user) instead of `{ teahouses }`.
- **New** `PUT /api/v1/players/:robloxUserId/preferences`, body `{ padPreferences: [string] }` → light-validate → `user.padPreferences = padPreferences` → persist → `200 { padPreferences }`. `X-API-Key` + `resolveUser`, mirroring the teahouses PUT.
- **Validation** (`400 BAD_REQUEST`): `padPreferences` is an array; `<= 32` entries; every entry a string `<= 32` chars. A small pure helper `validatePadPreferences(value)` (unit-testable), like `validateLoadout`.

### 2. `SiteCoordinator:onJoin` — preference-ordered site scan

Signature gains a third arg: `onJoin(playerId, ownedTeahouses, preferences?: {string})`. A pure helper orders the sites for this join:

```
orderedSiteIds(preferences) ->
    preferred = [ id for id in preferences if id is in self._padIds ]  (dedup, preference order)
    rest      = [ id for id in self._padIds if id not in preferred ]   (registration order)
    return preferred ++ rest
```

`onJoin` iterates `orderedSiteIds(preferences)` (instead of raw `self._padIds`) *inside* each `SizeClasses.order` size tier; the first vacant site with `fitsWithin(size, rec.spec.maxSize)` claims. Everything else (biggest-first size loop, `registry:get`/`:claim`, `Action` shape, double-join/wanderer guards) is unchanged. Stale/other-server preference ids are ignored (filtered to `_padIds`). `nil`/absent preference → registration order (D.4 behavior, unchanged). `vacantActions`/`onLeave` are untouched (preference is join-only).

### 3. `main.server` wiring + F2

- `PlayerAdded`: `local owned = if res.ok then res.data.teahouses or {} else nil`; add `local prefs = if res.ok then res.data.padPreferences else nil`; `siteCoordinator:onJoin(tostring(player.UserId), owned, prefs)`.
- **F2:** in `TreatmentApplier:apply`, wrap the post-rebuild (`PadBuilder.build(...)`) in `pcall`; on failure `warn` and continue (the structure is already parented; a missing post set is degraded, not fatal), so a throw can't blank the site or abort the startup `vacantActions` loop.

## Testing

- **Vitest** (`server/`): `validatePadPreferences` unit rules; `PUT .../preferences` round-trip (PUT then GET `teahouses` returns `padPreferences`); default `[]` for a fresh user; `400` on non-array / >32 entries / non-string / oversize entry; the teahouses GET returns both `teahouses` and `padPreferences`.
- **Lune** (`SiteCoordinator.spec`): preference reorders within a tier (owns {M,S}; sites `T02`=L, `T06`=M, `T04`=S registered T02-first; prefer `["T06"]` → claims **T06** at M, not T02); **size stays primary** (owns {L}; prefer `["T06"]` → still claims the L site `T02`, since T06 can't fit L); empty/nil preference → registration-order (unchanged); stale preference id (not registered) is ignored; `orderedSiteIds` dedups a preferred id that's also in `_padIds`.
- **Gate (systems, minimal visual):** seed the local player to own **{M, S}** and `padPreferences = ["T06"]`; Play → console `[D.5] … claimed T06 @ M` and a server-side check confirming `MaterializedSite_T06` is the claimed (lit) one while `T02` stays dormant. One attempt, then stop.

## v1 deliverables

1. `server/src/models/User.ts` — `padPreferences` field (+ `models.test.ts`).
2. `server/src/preferences.ts` (or inline) — `validatePadPreferences` helper (+ unit tests).
3. `server/src/routes/apiV1.ts` — teahouses GET returns `padPreferences`; new `PUT /preferences` (+ `apiV1.test.ts`).
4. `roblox/src/shared/SiteCoordinator.luau` — `onJoin(playerId, owned, preferences?)` + `orderedSiteIds` (+ `SiteCoordinator.spec` additions).
5. `roblox/src/server/TreatmentApplier.luau` — F2 pcall around the post-rebuild.
6. `roblox/src/server/main.server.luau` — read `padPreferences`, pass to `onJoin`.

## Build order

Server: `padPreferences` field → `validatePadPreferences` (TDD) → GET returns it + PUT (TDD, Vitest) → then Roblox: `SiteCoordinator` preference scan (TDD, Lune) → F2 pcall (Studio) → wire `main.server` → seed {M,S}+["T06"] + gate → stop for user review.
