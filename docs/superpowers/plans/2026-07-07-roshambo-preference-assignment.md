# Roshambo Preference-Aware Assignment Implementation Plan (sub-project D, increment 5.1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist a per-player ordered site preference and make `SiteCoordinator:onJoin` claim preferred perches first *within* each size tier, without ever trading away size.

**Architecture:** Server (Node/Express/Mongoose/Vitest) gains a `padPreferences: [String]` field on `User`, a `validatePadPreferences` helper mirroring `validateLoadout`, a fold of the preference array into the existing teahouses GET, and a new `PUT /preferences` route. The pure Lune-tested `SiteCoordinator` gains a preference arg and an `orderedSiteIds` helper that reorders its site scan; the size loop stays primary. `main.server` reads the preference at join and passes it through, and D.4's F2 (pcall the applier post-rebuild) is folded in. No client UI (that is D.5.2).

**Tech Stack:** TypeScript/Express/Mongoose/Vitest (server); Luau/`--!strict`/Lune bespoke harness (Roblox shared); stylua + selene lint gates for `roblox/`.

**Design doc:** `docs/superpowers/specs/2026-07-07-roshambo-preference-assignment-design.md` (commit `7732266`).

## Global Constraints

- **Size stays primary.** Preference only reorders sites *within* a single `SizeClasses.order` tier. A preferred smaller-max site must never win over a larger owned size that fits some site. (D.3/D.4 decision.)
- **`SiteCoordinator` is pure** (no Roblox datatypes) and stays Lune-testable. Task 4 is the only Roblox task with automated tests; Tasks 5–7 are Studio/visual-gate only.
- **Preference is join-only.** `vacantActions` and `onLeave` are unchanged.
- **Unknown/stale preference ids are ignored**, filtered to `self._padIds`. A `nil`/absent preference reproduces D.4 behavior exactly (registration order).
- **Validation values are exact:** `padPreferences` must be an array; `<= 32` entries; every entry a string of length `<= 32`. Error code `BAD_REQUEST` on any violation (matches the route convention).
- **REST auth:** every `/api/v1` route is behind `requireApiKey` (`X-API-Key`) + `resolveUser`, mirroring the teahouses routes. Preference routes take `:robloxUserId`.
- **stylua + selene must stay green** on `roblox/` (`stylua --check src tests tools` + `selene src tools`; selene fails CI on warnings too).
- **Commit trailers:** every commit ends with the `Co-Authored-By: Claude Opus 4.8 (1M context)` and `Claude-Session:` trailers used across this branch.

---

### Task 1: `padPreferences` field on the `User` model

**Files:**
- Modify: `server/src/models/User.ts` (add to `IUser` + `UserSchema`)
- Test: `server/src/models/models.test.ts` (add one `it`)

**Interfaces:**
- Consumes: nothing.
- Produces: `IUser.padPreferences: string[]` (Mongoose default `[]`); readable/writable on a `User` document.

- [ ] **Step 1: Write the failing test**

Add inside the existing `describe('schema additions', ...)` block in `server/src/models/models.test.ts`:

```ts
    it('User.padPreferences defaults to an empty array and round-trips', async () => {
        const fresh = await User.create({ deviceId: 'devPrefs' });
        expect(fresh.padPreferences).toEqual([]);
        const set = await User.create({ deviceId: 'devPrefs2', padPreferences: ['T06', 'T02'] });
        expect(set.padPreferences).toEqual(['T06', 'T02']);
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd server && npx vitest run src/models/models.test.ts`
Expected: FAIL — the new `it` errors (`padPreferences` is `undefined`, not `[]`).

- [ ] **Step 3: Add the field**

In `server/src/models/User.ts`, add to the `IUser` interface (after `teahouses: Map<string, unknown>;`):

```ts
    padPreferences: string[];
```

And to `UserSchema` (after the `teahouses` line):

```ts
    padPreferences: { type: [String], default: [] },
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd server && npx vitest run src/models/models.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/models/User.ts server/src/models/models.test.ts
git commit -m "feat(server): User.padPreferences field (sub-project D, increment 5.1)"
```

---

### Task 2: `validatePadPreferences` helper

**Files:**
- Modify: `server/src/loadout.ts` (add helper + constants; keep it co-located with the other validators)
- Test: `server/src/loadout.test.ts` (add a `describe`)

**Interfaces:**
- Consumes: the `Check` type already defined in `loadout.ts` (`{ ok: true } | { ok: false; error: string }`).
- Produces: `validatePadPreferences(value: unknown): Check`, plus exported constants `MAX_PREFERENCES = 32`, `MAX_PREFERENCE_LEN = 32`. Route code (Task 3) calls it and maps `!ok` to `400 { error: 'BAD_REQUEST' }`.

- [ ] **Step 1: Write the failing test**

Add to `server/src/loadout.test.ts` (it already imports from `./loadout`; extend the import and add the block):

```ts
import { validatePadPreferences } from './loadout';

describe('validatePadPreferences', () => {
    it('accepts an array of short strings, and an empty array', () => {
        expect(validatePadPreferences([]).ok).toBe(true);
        expect(validatePadPreferences(['T06', 'T02']).ok).toBe(true);
    });
    it('rejects a non-array', () => {
        expect(validatePadPreferences('T06').ok).toBe(false);
        expect(validatePadPreferences(null).ok).toBe(false);
        expect(validatePadPreferences({ 0: 'T06' }).ok).toBe(false);
    });
    it('rejects more than 32 entries', () => {
        expect(validatePadPreferences(Array.from({ length: 33 }, (_, i) => `T${i}`)).ok).toBe(false);
    });
    it('rejects a non-string entry', () => {
        expect(validatePadPreferences(['T06', 42]).ok).toBe(false);
    });
    it('rejects an entry longer than 32 chars', () => {
        expect(validatePadPreferences(['x'.repeat(33)]).ok).toBe(false);
    });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd server && npx vitest run src/loadout.test.ts`
Expected: FAIL — `validatePadPreferences` is not exported (import/reference error).

- [ ] **Step 3: Implement the helper**

Append to `server/src/loadout.ts` (after `validateSizeClass`):

```ts
export const MAX_PREFERENCES = 32;
export const MAX_PREFERENCE_LEN = 32;

export function validatePadPreferences(value: unknown): Check {
    if (!Array.isArray(value)) {
        return { ok: false, error: 'BAD_REQUEST' };
    }
    if (value.length > MAX_PREFERENCES) {
        return { ok: false, error: 'BAD_REQUEST' };
    }
    for (const entry of value) {
        if (typeof entry !== 'string' || entry.length === 0 || entry.length > MAX_PREFERENCE_LEN) {
            return { ok: false, error: 'BAD_REQUEST' };
        }
    }
    return { ok: true };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd server && npx vitest run src/loadout.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/loadout.ts server/src/loadout.test.ts
git commit -m "feat(server): validatePadPreferences helper (sub-project D, increment 5.1)"
```

---

### Task 3: teahouses GET fold + `PUT /preferences` route

**Files:**
- Modify: `server/src/routes/apiV1.ts` (fold `padPreferences` into the teahouses GET; add the PUT route; extend the `../loadout` import)
- Test: `server/src/routes/apiV1.test.ts` (update the one GET-shape assertion; add a `describe('preferences persistence', ...)`)

**Interfaces:**
- Consumes: `validatePadPreferences` (Task 2), `resolveUser`, `requireApiKey`, `IUser.padPreferences` (Task 1).
- Produces: `GET /players/:robloxUserId/teahouses` → `{ teahouses, padPreferences }`; `PUT /players/:robloxUserId/preferences` body `{ padPreferences: string[] }` → `200 { padPreferences }` or `400 { error: 'BAD_REQUEST' }`.

- [ ] **Step 1: Update the existing GET-shape test (it will now fail)**

In `server/src/routes/apiV1.test.ts`, inside `describe('teahouses persistence', ...)`, the wanderer test currently asserts `toEqual({ teahouses: {} })`. Change that assertion to include the folded array:

```ts
            expect(res.body).toEqual({ teahouses: {}, padPreferences: [] });
```

- [ ] **Step 2: Write the failing preferences tests**

Add a new sibling `describe` (after the `teahouses persistence` block) in `server/src/routes/apiV1.test.ts`:

```ts
    describe('preferences persistence', () => {
        it('PUT then GET teahouses returns padPreferences', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: ['T06', 'T02'] }).expect(200);
            const res = await request(app).get('/api/v1/players/roblox-1/teahouses')
                .set('X-API-Key', API_KEY).expect(200);
            expect(res.body.padPreferences).toEqual(['T06', 'T02']);
        });

        it('PUT echoes the stored preferences', async () => {
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: ['T04'] }).expect(200);
            expect(res.body).toEqual({ padPreferences: ['T04'] });
        });

        it('400 on a non-array / oversize / non-string body', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: 'T06' }).expect(400);
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: [42] }).expect(400);
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY)
                .send({ padPreferences: Array.from({ length: 33 }, (_, i) => `T${i}`) }).expect(400);
        });

        it('401 without the API key', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/roblox-1/preferences').send({ padPreferences: [] }).expect(401);
        });
    });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: FAIL — the GET-shape assertion fails (no `padPreferences` key yet) and all four preferences tests fail (route 404s).

- [ ] **Step 4: Fold the array into the GET and add the PUT route**

In `server/src/routes/apiV1.ts`, extend the loadout import:

```ts
import { validateLoadout, validateSizeClass, validatePadPreferences } from '../loadout';
```

In the teahouses GET handler, replace the response line:

```ts
            const teahouses = user.teahouses ? Object.fromEntries(user.teahouses as Map<string, unknown>) : {};
            res.json({ teahouses, padPreferences: user.padPreferences ?? [] });
```

Add the new route immediately after the `PUT /players/:robloxUserId/teahouses/:sizeClass` handler:

```ts
    router.put('/players/:robloxUserId/preferences', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const padPreferences = req.body?.padPreferences;
            const check = validatePadPreferences(padPreferences);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.padPreferences = padPreferences as string[];
            await user.save();
            res.json({ padPreferences: user.padPreferences });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: PASS (updated GET-shape test + four preferences tests).

- [ ] **Step 6: Run the full server suite (fold-through regression check)**

Run: `cd server && npm test`
Expected: PASS — confirms no other test depended on the old `{ teahouses }`-only GET shape.

- [ ] **Step 7: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): fold padPreferences into teahouses GET + PUT /preferences (sub-project D, increment 5.1)"
```

---

### Task 4: `SiteCoordinator` preference-ordered site scan

**Files:**
- Modify: `roblox/src/shared/SiteCoordinator.luau` (add `orderedSiteIds` local + a `preferences` param on `onJoin`)
- Test: `roblox/tests/SiteCoordinator.spec.luau` (add a `describe` for preference ordering)

**Interfaces:**
- Consumes: existing `PadRegistry` (`get`/`claim`), `SizeClasses` (`order`, `fitsWithin`, `scale`, `footprintFor`), `VacantState.resolve`. Test helper `spec(id, maxSize?)` and `coord(specs)` already exist in the spec file.
- Produces: `onJoin(playerId: string, ownedTeahouses: { [string]: any }?, preferences: { string }?): Action?` — same `Action` shape as D.4; when `preferences` is `nil`/absent, behavior is byte-identical to D.4.

- [ ] **Step 1: Write the failing tests**

Add to `roblox/tests/SiteCoordinator.spec.luau` a new `describe` block (place it after the existing `describe("SiteCoordinator.onJoin", ...)`). Sites are registered T02(L)-first so registration-order would otherwise pick T02:

```lua
describe("SiteCoordinator.onJoin preference", function()
    local function sites()
        return { spec("T02", "L"), spec("T06", "M"), spec("T04", "S") }
    end
    local OWNED_MS = { M = LOADOUT, S = LOADOUT }

    test("a preferred site is claimed first within the fitting size tier", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS, { "T06" })
        expect((a :: any).padId).toBe("T06")
        expect((a :: any).sizeClass).toBe("M")
    end)

    test("size stays primary: preference never trades away a larger owned size", function()
        local c = coord(sites())
        -- owns only L; prefers the M-max site T06, which cannot fit L
        local a = c:onJoin("p1", { L = LOADOUT }, { "T06" })
        expect((a :: any).padId).toBe("T02")
        expect((a :: any).sizeClass).toBe("L")
    end)

    test("nil preference reproduces registration order", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS, nil)
        -- M is the biggest owned; T06 is the only M-max site (T02 is L-max and fits M too);
        -- registration order tries T02 first, which fits M -> T02.
        expect((a :: any).padId).toBe("T02")
    end)

    test("a stale/unregistered preference id is ignored", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS, { "NOPE", "T06" })
        expect((a :: any).padId).toBe("T06")
    end)

    test("a duplicate preferred id does not double-place or error", function()
        local c = coord(sites())
        local a = c:onJoin("p1", OWNED_MS, { "T06", "T06" })
        expect((a :: any).padId).toBe("T06")
    end)
end)
```

Note the third test: with owned `{M,S}`, the biggest owned size is M. Both T02(L-max) and T06(M-max) fit M; registration order tries T02 first → T02. The preference test flips that to T06. This is exactly the "preference reorders within a tier" behavior.

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `roblox/`): `lune run tests/run`
Expected: FAIL — `onJoin` ignores the third arg, so the preference tests that expect `T06` get `T02`.

- [ ] **Step 3: Add `orderedSiteIds` and thread the preference through `onJoin`**

In `roblox/src/shared/SiteCoordinator.luau`, add a local helper above `onJoin` (after `dormantOf`):

```lua
-- Sites to scan for this join: preferred ids (in preference order, deduped, filtered
-- to registered ids) first, then the remaining registered ids in registration order.
function SiteCoordinator:_orderedSiteIds(preferences: { string }?): { string }
    if preferences == nil then
        return self._padIds
    end
    local registered: { [string]: boolean } = {}
    for _, id in self._padIds do
        registered[id] = true
    end
    local ordered: { string } = {}
    local taken: { [string]: boolean } = {}
    for _, id in preferences do
        if registered[id] and not taken[id] then
            taken[id] = true
            table.insert(ordered, id)
        end
    end
    for _, id in self._padIds do
        if not taken[id] then
            table.insert(ordered, id)
        end
    end
    return ordered
end
```

Change the `onJoin` signature and its inner scan loop:

```lua
function SiteCoordinator:onJoin(
    playerId: string,
    ownedTeahouses: { [string]: any }?,
    preferences: { string }?
): Action?
    if self._held[playerId] ~= nil then
        return nil
    end
    if ownedTeahouses == nil then
        return nil
    end
    local order = self:_orderedSiteIds(preferences)
    for _, size in SizeClasses.order do -- L, M, S (biggest first)
        local loadout = ownedTeahouses[size]
        if loadout ~= nil then
            for _, id in order do -- preferred-first within this size tier
                local rec = self._registry:get(id)
                if rec and rec.occupant == nil and SizeClasses.fitsWithin(size, rec.spec.maxSize) then
                    self._registry:claim(id, playerId)
                    self._held[playerId] = id
                    return {
                        padId = id,
                        spec = rec.spec,
                        treatment = VacantState.resolve(playerId, loadout, rec.spec.vacantForm),
                        scale = SizeClasses.scale[size],
                        sizeClass = size,
                        footprint = SizeClasses.footprintFor(size),
                    }
                end
            end
        end
    end
    return nil
end
```

Update the module header comment (lines 5–7) so it mentions preference ordering: after "biggest-first." add "Within a size tier, a player's preferred site ids (passed to onJoin) are scanned first."

- [ ] **Step 4: Run the tests to verify they pass**

Run (from `roblox/`): `lune run tests/run`
Expected: PASS — all new preference tests and every pre-existing `SiteCoordinator` test (the `nil`-preference path is unchanged).

- [ ] **Step 5: Lint**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: no diffs, no selene errors/warnings.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SiteCoordinator.luau roblox/tests/SiteCoordinator.spec.luau
git commit -m "feat(roblox): preference-ordered site scan in SiteCoordinator (sub-project D, increment 5.1)"
```

---

### Task 5: F2 — pcall the applier's post-rebuild

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau` (wrap the `PadBuilder.build(...)` block in `pcall`)

**Interfaces:**
- Consumes: existing `self._padBuilder.build`, `self._padOpsNew`. Studio-only (Roblox datatypes) → no Lune test; correctness is proven by the Task 7 gate (a normal materialization still builds posts) and by inspection.
- Produces: no signature change; a throwing post-rebuild now `warn`s and continues instead of aborting `apply` (so it can't blank the site or halt the startup `vacantActions` loop).

- [ ] **Step 1: Wrap the post-rebuild in pcall**

In `roblox/src/server/TreatmentApplier.luau`, replace the `if footprint ~= nil then ... end` block (currently the un-pcall'd `self._padBuilder.build(...)` call around lines 98–104):

```lua
    if footprint ~= nil then
        local mountCF = CFrame.new(table.unpack(spec.mountCF))
        local okPosts, postErr = pcall(function()
            self._padBuilder.build(
                { mountCF = spec.mountCF, hand = spec.hand, footprint = footprint },
                self._padOpsNew(mountCF, folder)
            )
        end)
        if not okPosts then
            -- degraded, not fatal: the structure is already built; a missing post set must not
            -- blank the site or abort the caller's vacantActions loop (F2).
            warn(`[D.5] post rebuild failed for {padId}: {postErr}`)
        end
    end
```

- [ ] **Step 2: Lint (this file is Studio-only; lint is the local gate)**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: no diffs, no selene errors/warnings.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/TreatmentApplier.luau
git commit -m "fix(roblox): pcall applier post-rebuild so a post failure can't blank a site (D.4 F2)"
```

---

### Task 6: `main.server` wiring — read and pass the preference

**Files:**
- Modify: `roblox/src/server/main.server.luau` (the D.4 `PlayerAdded` block near line 384)

**Interfaces:**
- Consumes: `net:getTeahouses` now returns a body carrying `padPreferences` (Task 3 fold); `siteCoordinator:onJoin` now takes a third arg (Task 4).
- Produces: no new interface; behavior gains preference-aware placement. Studio-only → proven by the Task 7 gate.

- [ ] **Step 1: Read the preference and pass it to onJoin**

In `roblox/src/server/main.server.luau`, in the D.4 `PlayerAdded` handler (line ~384), after the `local owned = ...` line, add the preference read and thread it into `onJoin`:

```lua
        local owned = if res.ok then res.data.teahouses or {} else nil
        local prefs = if res.ok then res.data.padPreferences else nil
        local action = siteCoordinator:onJoin(tostring(player.UserId), owned, prefs)
```

Update the claim print (line ~402) to the D.5 tag so the gate can grep it:

```lua
            print(`[D.5] {player.UserId} claimed {action.padId} @ {tostring(action.sizeClass)}`)
```

Leave the `IsDescendantOf` race guard, `onLeave` release, and `PlayerRemoving` handler untouched.

- [ ] **Step 2: Lint**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: no diffs, no selene errors/warnings.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): pass padPreferences into onJoin (sub-project D, increment 5.1)"
```

---

### Task 7: Seed + visual gate (systems, minimal visual)

**Files:** none committed (gate only). This task proves the end-to-end path in Studio.

**Interfaces:** Consumes everything above. This is the "one attempt, then stop for user review" gate mandated by the working preferences.

- [ ] **Step 1: Seed the local player's preference**

Against the local docker server (the same one D.1–D.4 used), PUT the local player's owned teahouses to `{M, S}` (drop L so preference is observable — with an L owned, biggest-first always picks the only L-site T02 and preference cannot show), and set `padPreferences=["T06"]`. Use the local player's `robloxUserId` (the UserId Studio reports for the test avatar). Example (substitute `<UID>` and the local server base URL + `API_KEY`):

```bash
curl -s -X PUT "$BASE/api/v1/players/<UID>/teahouses/M" -H "X-API-Key: $API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"loadout":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}'
curl -s -X PUT "$BASE/api/v1/players/<UID>/teahouses/S" -H "X-API-Key: $API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"loadout":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}'
# ensure no L is owned; if a prior gate left one, DELETE/overwrite is out of scope — reseed a fresh player or clear the doc
curl -s -X PUT "$BASE/api/v1/players/<UID>/preferences" -H "X-API-Key: $API_KEY" \
  -H 'Content-Type: application/json' -d '{"padPreferences":["T06"]}'
# verify the fold
curl -s "$BASE/api/v1/players/<UID>/teahouses" -H "X-API-Key: $API_KEY"
# expect: {"teahouses":{"M":{...},"S":{...}},"padPreferences":["T06"]}
```

- [ ] **Step 2: Play and check the console**

Enter Play in Studio (or `start_stop_play` via MCP). In the server console expect one line:

```
[D.5] <UID> claimed T06 @ M
```

i.e. the preferred M-max site `T06` is claimed at size M — **not** the registration-first `T02`.

- [ ] **Step 3: Confirm the materialized state**

Via MCP `execute_luau` (Server datamodel), confirm `MaterializedSite_T06` holds the lit player Structure while `MaterializedSite_T02` stays dormant (shuttered). One check, e.g. read each folder's `Structure` presence + a lit marker (PointLight enabled) — matching how the D.4 gate confirmed lit-vs-dormant.

- [ ] **Step 4: Stop and hand off**

Per the working preferences: make this ONE attempt, then STOP and ask the user to look. Do not self-judge and iterate. Report the console line + the folder state and request the user's gate approval before the final whole-branch review.

---

## Self-Review notes (author)

- **Spec coverage:** field (T1) ✓; validator (T2) ✓; GET fold + PUT (T3) ✓; `SiteCoordinator` preference scan + `orderedSiteIds` (T4) ✓; F2 (T5) ✓; `main.server` wiring (T6) ✓; seed gate (T7) ✓. `NetworkClient` unchanged (its `getTeahouses` returns the whole body, so `padPreferences` rides through — no task needed, matches spec §Architecture).
- **Fold-through risk:** the teahouses GET shape changes from `{ teahouses }` to `{ teahouses, padPreferences }`. The only test asserting the exact object was the wanderer `toEqual({ teahouses: {} })` (T3 Step 1 updates it); `npm test` in T3 Step 6 catches any other consumer. The Roblox side reads `res.data.padPreferences` defensively (`if res.ok then ... else nil`), and D.4's `res.data.teahouses` accessor is unaffected.
- **Size-primary invariant** is pinned by T4's "size stays primary" test (owns L, prefers T06 → still T02@L).
- **Naming consistency:** `padPreferences` (server field + JSON key), `preferences` (Luau `onJoin` arg), `_orderedSiteIds` (Luau method), `validatePadPreferences` — used identically across tasks.
- **Error code:** `BAD_REQUEST` used for every validation failure, matching the route convention (not a bespoke code).
