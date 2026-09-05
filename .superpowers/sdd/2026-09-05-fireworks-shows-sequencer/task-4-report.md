# Task 4 report — the reserve endpoint and its NetworkClient call

**Status:** complete. Commit `5823fe5` — `feat(shows): POST /shows/reserve debits a whole show in one conditional update, or nothing; NetworkClient.postShowReserve`

## Implemented

### `POST /api/v1/players/:robloxUserId/shows/reserve` (`server/src/routes/apiV1.ts`, inserted directly after `POST .../fireworks/spend`)

Order of gates, cheapest and least destructive first:

1. `BAD_SHOW` (400) — `req.body.show` is not a non-null object.
2. `FUEL_UNSUPPORTED` (400) — any `fuel` other than `'inventory'` (powder is sub-project A).
3. `BAD_STAGE` (400) — `stageId !== 'deck:<robloxUserId of the path>'`; a player may only reserve for their own deck.
4. `validateShow(show.cues, DECK_STAGE)` (400) — the shared grammar's code, with `cue` only when the validator supplied one.
5. `resolveUser` (404 `RESOLVE_FAILED` on failure).
6. `MORTAR_MISSING` (409, with `slot`) — a `mortar:` cue slot the player does not own. **Checked before the debit**, so a show that could never launch takes no shells.
7. The debit: `tallyShells(cues)` becomes ONE `findOneAndUpdate` whose filter carries `fireworks.<id>: { $gte: n }` for every distinct shell and whose update carries the matching `$inc: -n`. Nothing matched → 409 `{ error: 'INSUFFICIENT', needed, held }` and **no document was touched**; matched → 200 `{ reservationId, stageId, cues, debited, remaining }` with `remaining` read off the `{ new: true }` document.

The dotted filter/update keys are safe: every `shellId` reaching the tally has already been checked against `SHELL_IDS` by `validateShow` (`BAD_SHELL`), so no caller-controlled path can be spliced into the query.

Imports added: `import { validateShow, tallyShells, DECK_STAGE, Cue } from '../shows';` — `shellMortar` was named in the brief's import list but the route never calls it (`validateShow` already enforces the shell↔tier rule), so per the brief's own note it was dropped rather than left unused.

### `NetworkClient.postShowReserve` (`roblox/src/server/NetworkClient.luau`, after `postFireworkSpend`, keeping the two fireworks-spend calls adjacent)

```lua
function NetworkClient.postShowReserve(self: any, robloxUserId: string, show: any): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/shows/reserve`, { show = show })
end
```

Both 409s surface as ordinary failed `Result`s through the existing `_request` fail-fast path (no retry burn on 4xx).

## RED / GREEN evidence

### Server — RED (route absent)

```
$ cd server && npx vitest run src/routes/apiV1.test.ts -t "shows/reserve"
FAIL  src/routes/apiV1.test.ts > ... > CONCURRENT RESERVES CANNOT OVERSPEND — one conditional update per reservation
AssertionError: expected [ 404, 404 ] to deeply equal [ 200, 409 ]
 Test Files  1 failed (1)
      Tests  5 failed | 82 skipped (87)
```

All five failures were 404s (route not mounted), as expected.

### Server — GREEN

```
$ cd server && npx vitest run src/routes/apiV1.test.ts -t "shows/reserve"
 Test Files  1 passed (1)
      Tests  5 passed | 82 skipped (87)

$ cd server && npm test
 Test Files  29 passed (29)
      Tests  612 passed (612)

$ cd server && npx tsc --noEmit
TSC OK
```

No route-count or mount-order test objected to the new route.

### Luau — RED

```
$ cd roblox && lune run tests/run 2>&1 | tail -3
FAIL  NetworkClient.postShowReserve > POSTs the show under { show = ... } to the player's reserve route
      .../roblox/tests/NetworkClient.spec:522: attempt to call missing method 'postShowReserve' of table
1879 passed, 1 failed, 1880 total
```

### Luau — GREEN + lint

```
$ cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools
1880 passed, 0 failed, 1880 total
Results:
0 errors
0 warnings
0 parse errors
```

(`stylua --check` printed nothing = clean. On the first attempt it rejected the appended spec block for tab indentation; the file — and this repo's Luau — uses 4 spaces. Reindented, and the same style was used for the NetworkClient function.)

## Files changed (4, all staged in the one commit)

- `server/src/routes/apiV1.ts` — +1 import line, +57 route lines
- `server/src/routes/apiV1.test.ts` — +86, the five tests appended inside `describe('fireworks', …)`
- `roblox/src/server/NetworkClient.luau` — +7
- `roblox/tests/NetworkClient.spec.luau` — +19

## Self-review

- **All-or-nothing is genuinely atomic.** The debit is a single `findOneAndUpdate`; there is no read-then-write window, and the `INSUFFICIENT` test asserts the *other* shells in the tally were untouched, not merely that the response was 409.
- **The concurrency test is the real gate.** Two simultaneous one-firecracker reserves against a stock of 1 resolve to exactly `[200, 409]` and leave the count at 0.
- **Ordering matters and is tested.** `MORTAR_MISSING` precedes the debit; the malformed-input test re-reads the user afterwards to prove nothing was spent on any of the five rejection paths.
- **`held` in the `INSUFFICIENT` body is the pre-update read**, so under a losing race it can be a hair stale (it reports what the caller had when the request started, not after the winner's debit). It is diagnostic, not authoritative; the client's source of truth stays `GET /fireworks`.
- **Route placement** puts it inside the API-key-gated `/api/v1` router alongside `fireworks/spend`, so it inherits `requireApiKey`.
- `resolveUser` upserts, as it does for every other player route here — a reserve for an unseen robloxId mints the user rather than 404ing. Consistent with the file, not new behaviour.

## Concerns

1. **`reservationId` is `Math.random().toString(36).slice(2, 12)`** (as the brief specifies). It is not persisted anywhere yet — nothing redeems a reservation — so it currently functions as a correlation token only. Two caveats for whoever consumes it next: it is not collision-proof, and in a vanishingly rare case (`Math.random()` landing on a value with a very short base-36 expansion, e.g. exactly `0.5`) it can be shorter than the 6 characters the test's regex demands. If a later task makes the id load-bearing, it should become a real unique id (`crypto.randomUUID()` or a Mongo `_id`) and be stored with the debit so a reservation can be refunded or expired.
2. **A reservation debits with no refund path.** If the show never plays — the player disconnects, the stage is taken, the server restarts — the shells are gone. Whatever task owns playback should either persist the reservation so it can be voided or make the debit happen at the moment the sequencer accepts the show.
3. **`held` staleness** as noted above, if a client ever renders those numbers directly rather than re-fetching.
