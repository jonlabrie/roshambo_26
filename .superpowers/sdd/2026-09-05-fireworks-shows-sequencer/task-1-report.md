# Task 1 report — the show fixture and the TypeScript validator

**Status:** DONE_WITH_CONCERNS (concerns are all forward-looking notes for Task 2's Luau twin;
nothing in this task is left undone.)
**Commit:** `674add4` — `feat(shows): the show grammar as a shared fixture, and its TypeScript validator`
**Branch:** `thread/shows` (worktree `.worktrees/shows`)

## What I implemented

Exactly the brief, verbatim, in its three files:

- `shared-fixtures/shows.json` — the show grammar: `limits` (`maxCues` 120, `maxDurationS` 300),
  two `stages` (`deck` = hand + three mortar tiers; `proving` = six `any` public tubes) and 15
  named cases covering the five ok shapes and every error code except `TOO_MANY_CUES`, which each
  side's test generates rather than writing out 121 cues.
- `server/src/shows.ts` — `Cue` / `ShowInput` / `StageSlots` / `ShowError` / `ShowCheck` types,
  `SHOW_LIMITS` and `DECK_STAGE` as **literals**, `shellMortar`, `validateShow`, `tallyShells`.
  It imports only `SHELL_IDS` and `REQUIREMENTS` from `./fireworks` — no fixture import at
  runtime, per the controller ruling (`rootDir: ./src`, container built from `server/` alone).
- `server/src/shows.test.ts` — imports both JSON fixtures directly (the `fireworks.test.ts`
  pattern), asserts `SHOW_LIMITS` / `DECK_STAGE` equal the fixture, loops every fixture case, and
  adds the generated `TOO_MANY_CUES` boundary, the non-array `EMPTY` cases, and the helpers.

## TDD evidence

**RED** — `cd server && npx vitest run src/shows.test.ts` (fixture and test written, no module):

```
 FAIL  src/shows.test.ts [ src/shows.test.ts ]
Error: Cannot find module './shows' imported from .../server/src/shows.test.ts
 ❯ src/shows.test.ts:4:1
      4| import { validateShow, tallyShells, shellMortar, SHOW_LIMITS, DECK_STA…

 Test Files  1 failed (1)
      Tests  no tests
```

**GREEN** — same command after writing `server/src/shows.ts`:

```
 Test Files  1 passed (1)
      Tests  22 passed (22)
```

**Whole suite + type-check** — `cd server && npm test && npx tsc --noEmit`:

```
 Test Files  29 passed (29)
      Tests  606 passed (606)
   Duration  9.06s
=====TSC=====
tsc clean
```

## Files changed

- `shared-fixtures/shows.json` (new)
- `server/src/shows.ts` (new)
- `server/src/shows.test.ts` (new)

Nothing else was touched. No CI job enumerates `shared-fixtures/` by name — both
`server-ci.yml` and `roblox-ci.yml` already trigger on `shared-fixtures/**`, so the new fixture
is inside both gates the moment Task 2 reads it from Lune.

## Self-review findings

Things I checked and found correct:

- `TOO_LONG` is evaluated after the loop against `last`, which is the maximum `t_ms` because the
  ordering check already ran. The fixture's case (`0`, `300001`) is one millisecond past
  `maxDurationS * 1000`, so the boundary is `>`, not `>=` — a show ending exactly at 300000 ms is
  legal. The Luau twin must use the same comparison.
- `Number.isFinite` in `isCue` rejects `NaN` and `Infinity` as `BAD_CUE` before they can reach the
  ordering or duration checks (an `Infinity` cue would otherwise pass ordering and then trip
  `TOO_LONG`, reporting the wrong error and no cue index).
- The `TOO_MANY_CUES` boundary test asserts both sides of it — 121 rejected, the first 120
  accepted — so an off-by-one in either direction fails.
- `tallyShells` uses `?? 0` rather than `||`, so it cannot be fooled by a `0` count.
- Equal `t_ms` is explicitly legal (`<` not `<=` in the ordering check), which is what makes the
  volley case pass; that is the single most likely place for the Luau twin to drift.

## Concerns

1. **Error precedence is real behaviour that the fixture does not pin.** `validateShow` checks, per
   cue, in this order: `BAD_CUE` → `NEGATIVE_TIME` → `CUES_OUT_OF_ORDER` → `BAD_SLOT` →
   `BAD_SHELL` → `TIER_MISMATCH`. Every fixture case is singly-faulty, so a cue that is *both*
   badly slotted and badly shelled (`{ slot: 'mortar:XL', shellId: 'moonshot' }`) would be
   `BAD_SLOT` here and could be `BAD_SHELL` in Luau without any test noticing. Also cross-cue:
   the whole-show `TOO_MANY_CUES` is checked before any per-cue fault, and `TOO_LONG` after all of
   them. If Task 2 wants that pinned, the cheapest fix is two multi-fault cases added to the
   fixture — which is a fixture change both sides then run, exactly as intended.
2. **A stage whose slot value is neither `none`, `any`, nor `mortar:*` silently accepts every
   shell** (it fails the `'none'` test and the `startsWith('mortar:')` test, so no tier check
   runs). Stage definitions are server-side data, not player input, so this is not an exploit
   today — but when stages become data (later tasks), a typo in a slot's tier degrades to "public
   tube" rather than erroring. A `BAD_STAGE` code or a startup assertion over stage values would
   close it; it is out of this brief's scope.
3. `ShowInput` is exported but not yet consumed by anything — it exists for the later tasks'
   payload shape. Its `fuel: 'inventory' | 'powder'` field is unvalidated here by design;
   whichever task accepts a show over the wire owns that check.

---

# Fix pass — review finding: `stage[c.slot]` hits `Object.prototype`

Commit `5de8444` — `fix(shows): a prototype-named slot is BAD_SLOT, not a TypeError`.

## The defect

`server/src/shows.ts:44` read the slot with a plain index, so `slot: "toString"` (or
`constructor`, `__proto__`, `hasOwnProperty`, `valueOf`) resolved to an inherited value that is
not `undefined`. The `BAD_SLOT` guard therefore passed, and line 49's `accepts.startsWith` threw
`TypeError` on a function. `validateShow` exists to *return* an error for hostile input, so a
throw is a contract break — and it was cross-language drift the fixture could not express: a Luau
table has no inherited string keys, so the twin already returned `BAD_SLOT`.

## What changed

- `shared-fixtures/shows.json:19` — new case, after "unknown slot":
  `"a slot named after an Object.prototype member is just an unknown slot"` — deck stage, one cue
  `{ t_ms: 0, slot: "toString", shellId: "firecracker" }`, expecting `BAD_SLOT` at cue 0. Both
  validators run it, so the Luau twin is held to the same answer for free.
- `server/src/shows.ts:44-51` — the lookup is now own-property (`Object.prototype.hasOwnProperty.call`),
  and the value must be one of the three shapes the grammar defines:

  ```ts
  const accepts = Object.prototype.hasOwnProperty.call(stage, c.slot) ? stage[c.slot] : undefined;
  if (accepts !== 'none' && accepts !== 'any' && !(typeof accepts === 'string' && accepts.startsWith('mortar:'))) {
      return { ok: false, error: 'BAD_SLOT', cue: i };
  }
  ```

  The shape check also closes Concern 2 of the original report: a stage slot whose value is a
  typo'd tier no longer degrades to "accepts anything" — it is a bad slot. Every other rule and
  the per-cue error precedence (`BAD_CUE` → `NEGATIVE_TIME` → `CUES_OUT_OF_ORDER` → `BAD_SLOT` →
  `BAD_SHELL` → `TIER_MISMATCH`) are untouched; `accepts` is a narrowed string by line 56, so the
  later `startsWith` is safe by types, not by luck.

## RED (fixture case added, implementation unchanged)

```
$ cd server && npx vitest run src/shows.test.ts
 ❯ src/shows.test.ts (23 tests | 1 failed) 8ms
     × a slot named after an Object.prototype member is just an unknown slot 2ms

 FAIL  src/shows.test.ts > validateShow — every fixture case > a slot named after an Object.prototype member is just an unknown slot
TypeError: accepts.startsWith is not a function
 ❯ validateShow src/shows.ts:49:21

 Test Files  1 failed (1)
      Tests  1 failed | 22 passed (23)
```

## GREEN

```
$ cd server && npx vitest run src/shows.test.ts && npm test && npx tsc --noEmit
 Test Files  1 passed (1)
      Tests  23 passed (23)

 Test Files  29 passed (29)
      Tests  607 passed (607)
   Duration  8.39s

tsc clean (no output)
```

## Concerns

Concerns 1 (error precedence unpinned by the fixture) and 3 (`ShowInput.fuel` unvalidated) from the
original report stand as written. Concern 2 is now closed in TypeScript only — **Task 2's Luau twin
must reject a non-`none`/`any`/`mortar:*` slot value as `BAD_SLOT` too**, since no fixture case can
express a malformed *stage* (the fixture's stages are all well-formed by construction); only the
prototype-member case is shared, and Luau passes that one for a different reason.
