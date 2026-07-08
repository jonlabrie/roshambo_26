# Roshambo Perch Favoriting — Design (sub-project D, increment 5.2)

**Status:** design approved in brainstorm (2026-07-07); pre-planning. Closes out D.5 (perch preference). Roblox client + server wiring; one pure Lune-tested helper; no PWA, no server schema change.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** D.5.1 persisted a per-player ordered preference (`padPreferences: [siteId]`) and made `SiteCoordinator:onJoin` honor it (preferred perches first, within size tier), plus the `GET` fold and `PUT /players/:id/preferences` route. But nothing lets a player *set* the preference in-world — it was seeded via curl for the gate. D.5.2 adds the in-world mechanism: a walk-up prompt on each perch to favorite/un-favorite it, persisted through the existing `PUT`. Assignment itself is unchanged (D.5.1).

## Problem

The preference exists in the data model and drives assignment, but is unreachable by players. We need an in-world way to curate the favorite list: walk up to any perch, thumb it up (or down to remove), and have that persist so the next join sends the player to their top available favorite.

## Decisions (from brainstorm)

- **Prefer-only.** Thumbs up = add the siteId to `padPreferences`; pressing again = remove it. No "avoid" concept, so **no server schema change** — D.5.1's model is sufficient.
- **Walk-up ProximityPrompt on each perch.** First `ProximityPrompt` pattern in the codebase (reusable later for familiars/bell). A prompt sits on every materialized teahouse (occupied or dormant).
- **Client-created prompts.** A server-created prompt is one shared instance whose label can't differ per player; each **client** creates its own prompts so the label reflects *that* player's favorited state.
- **Feedback = label flip + toast.** The prompt flips `♡ Favorite this perch` ↔ `♥ Favorited ✓`, and a transient on-screen toast confirms and teaches the join-time effect ("★ Mossy Prow favorited — you'll spawn here next time it's free").
- **Favoriting affects the next join only** — no live re-assignment mid-session (consistent with D.5.1's join-only model).

## Non-goals (later)

- **Avoid list / thumbs-down-as-avoid** — a separate increment if ever wanted (needs a new schema field).
- **PWA preference UI** — the PWA is a separate product; out of scope.
- **Persistent in-world favorite markers** (glowing ♥ / tinted lantern visible at range) — considered and deferred; the toast + prompt label are the v1 feedback.
- **Reordering the preference list from the client** — the list order is edit-append order; explicit priority reordering is future.
- **D.6 migration** (the 14 legacy perches) — separate increment; D.5.2 works against whatever sites `PadSites` registers.

## Architecture

Five touches. The only unit-testable logic is a pure toggle helper; everything else is Studio/visual-gate (Roblox datatypes / remotes / UI), as with prior Roblox increments.

### 1. Pure toggle helper — `roblox/src/shared/PreferenceEditor.luau` (new, Lune-tested)

```
togglePreference(list: {string}, siteId: string, maxEntries: number) -> ({string}, boolean)
```
Returns the new list and whether the site is now favorited. If `siteId` is present → remove it (favorited=false). If absent → append it, deduped (favorited=true), unless the list is already at `maxEntries` (server cap is 32) in which case return the list unchanged with favorited=false. Pure, no Roblox types → Lune spec.

### 2. `NetworkClient:setPreferences` — `roblox/src/server/NetworkClient.luau`

```
function NetworkClient.setPreferences(self, robloxUserId: string, padPreferences: {string}): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/preferences`, { padPreferences = padPreferences })
end
```
Mirrors `postBank`/`postThrows`. The `PUT /preferences` route + validation already exist (D.5.1).

### 3. Server wiring — `roblox/src/server/main.server.luau`

- **Per-player preference cache:** `local playerPrefs: { [string]: { string } } = {}`. In the D.5 `PlayerAdded` handler (the one that calls `getTeahouses`/`onJoin`, ~line 384), after the fetch set `playerPrefs[userId] = res.data.padPreferences or {}` and push a **`PreferenceState`** event to that player's client with the list. Clear it in `PlayerRemoving`.
- **`SetPadPreference` (RemoteEvent, client→server):** `OnServerEvent(player, siteId)` → guard that `siteId` is a registered site (`PadSites[siteId] ~= nil`); `local newList, favorited = PreferenceEditor.togglePreference(playerPrefs[userId], siteId, 32)`; store it; `net:setPreferences(userId, newList)` (best-effort — on failure, `warn` and roll the cache back so client/server don't diverge); push **`PreferenceState`** back to the client with `{ padPreferences = newList, changed = siteId, favorited = favorited, name = PadSites[siteId].displayName or siteId }`.
- **`PreferenceState` (RemoteEvent, server→client):** carries the full list (for labeling every prompt) plus, on a toggle echo, the `changed`/`favorited`/`name` fields (for the toast). At join it's sent with just `{ padPreferences = list }`.

### 4. Client controller — `roblox/src/client/PerchPreferenceController.client.luau` (new)

- Holds the player's current `padPreferences` (a set), updated from `PreferenceState`.
- Watches `workspace` for `MaterializedSite_<siteId>` folders (`ChildAdded` + initial sweep — use the async-safe pattern, cf. the client replication-race note: wait for the folder's `Structure`). For each, parse `siteId` from the folder name, pick an anchor (an `Attachment` at the structure's base / its `PrimaryPart`), and create one `ProximityPrompt` (`ActionText` from the current favorited state, `ObjectText` = the perch's display context, a sensible `MaxActivationDistance`).
- `ProximityPrompt.Triggered` → fire `SetPadPreference(siteId)`.
- On `PreferenceState`: refresh every prompt's label from the new list; if `changed` is present, show the **toast** (a transient `ScreenGui` banner: "★ {name} favorited — you'll spawn here next time it's free" / "{name} removed from favorites").

### 5. Remotes contract — `roblox/default.project.json`

Add to `RoshamboRemotes`: `"SetPadPreference": { "$className": "RemoteEvent" }` and `"PreferenceState": { "$className": "RemoteEvent" }`.

### 6. Perch names — `roblox/src/server/PadSites.luau`

Add an optional `displayName` to each site entry (e.g. T02 = "Overlook", T06 = "Mossy Prow", T04 = "Creekside"). Server includes it in the `PreferenceState` toggle echo; the toast falls back to the siteId if a site has no name.

## Data flow

```
join: getTeahouses (fold) -> playerPrefs[uid]=list -> PreferenceState{list} -> client labels all prompts
favorite: walk up -> prompt Triggered -> SetPadPreference(siteId)
        -> server togglePreference + setPreferences(PUT persist)
        -> PreferenceState{list, changed, favorited, name}
        -> client flips that prompt's label + shows toast
next join: onJoin reads the persisted padPreferences -> assigns top available favorite (D.5.1)
```

## Testing

- **Lune** (`PreferenceEditor.spec`): add an absent id (appended, favorited=true); toggle a present id (removed, favorited=false); dedup (adding a present id via a list with a dup stays single); cap (at 32 entries, adding a new id returns the list unchanged, favorited=false); order preserved on append.
- **Server route** already covered by D.5.1's Vitest (`PUT /preferences`, `GET` fold). No new server tests.
- **Gate (Studio, against Atlas `roshambo-dev`):** join → walk up to a dormant perch → prompt shows `♡ Favorite this perch` → press → label flips to `♥ Favorited ✓` + toast; `curl` (or Atlas UI) confirms `padPreferences` now contains that siteId in `roshambo-dev`; press again → removed (label + persistence revert); rejoin owning a fitting size → `[D.5] … claimed <favorited siteId>` (closes the loop with D.5.1 assignment). One attempt, then stop for review.

## v1 deliverables

1. `roblox/src/shared/PreferenceEditor.luau` + `roblox/tests/PreferenceEditor.spec.luau` — pure toggle helper (TDD, Lune).
2. `roblox/src/server/NetworkClient.luau` — `setPreferences` PUT method.
3. `roblox/default.project.json` — `SetPadPreference` + `PreferenceState` remotes.
4. `roblox/src/server/PadSites.luau` — optional `displayName` per site.
5. `roblox/src/server/main.server.luau` — `playerPrefs` cache, join-time `PreferenceState` push, `SetPadPreference` handler (toggle + persist + echo), `PlayerRemoving` cleanup.
6. `roblox/src/client/PerchPreferenceController.client.luau` — per-perch prompts, label state, toast, `SetPadPreference`/`PreferenceState` wiring.

## Build order

Pure first: `PreferenceEditor` (TDD, Lune) → `NetworkClient:setPreferences` → remotes contract + `PadSites.displayName` → `main.server` wiring (cache + handler + push) → `PerchPreferenceController` (prompts + toast) → Studio gate → stop for user review. stylua + selene green throughout.
