# Task 1 Report: The catalog carries shell and mortar prices

## What changed

**`server/src/routes/apiV1.test.ts`**
- Added `import { SHELL_IDS } from '../fireworks';` alongside the existing imports (the file
  previously had no import from `../fireworks`).
- Added two tests inside the existing `describe('fireworks', ...)` block, at the end (after
  "buys a mortar tube, and tubes are linear"):
  - `'the economy catalog carries shell and mortar prices'` — asserts
    `GET /api/v1/players/907/economy` returns `catalog.fireworks` and `catalog.mortars` matching
    the exact values from `SHELL_PRICES` / `MORTAR_PRICES`.
  - `'every sellable shell has a catalogued price'` — asserts every id in `SHELL_IDS` has a
    `number` price in `catalog.fireworks` (the regression gate: a shell added to `SHELL_IDS` but
    not priced would render in the shop with a blank price).

**`server/src/routes/apiV1.ts`**
- Changed the import line from
  `import { shellStates, SHELL_IDS, LaunchContext } from '../fireworks';`
  to
  `import { shellStates, SHELL_IDS, LaunchContext, SHELL_PRICES, MORTAR_PRICES } from '../fireworks';`
  (per the ambiguity resolution given: this is the one pre-existing import from `../fireworks`
  in this file, extended in place — no second import line added).
- In the `/players/:robloxUserId/economy` route, replaced `catalog: PRICES,` with:
  ```ts
  // The client is told PRICES, never requirements. Shells and mortars live in
  // fireworks.ts rather than economy.ts, so they have to be spliced in here — the
  // alternative is a second copy of every price in the Roblox client.
  catalog: { ...PRICES, fireworks: SHELL_PRICES, mortars: MORTAR_PRICES },
  ```

No other files were touched. `server/src/fireworks.ts` has a zero-line diff after the mutation
step below was reverted (verified with `git diff --stat`).

## Test output before implementation (Step 2)

Ran `npx vitest run src/routes/apiV1.test.ts` from `server/` after adding the test file changes
but before touching `apiV1.ts`:

```
 ❯ src/routes/apiV1.test.ts (57 tests | 2 failed) 1293ms
       × the economy catalog carries shell and mortar prices 10ms
       × every sellable shell has a catalogued price 6ms

 FAIL  src/routes/apiV1.test.ts > /api/v1 > fireworks > the economy catalog carries shell and mortar prices
AssertionError: expected undefined to deeply equal { firecracker: 1, peony: 3, …(2) }
- Expected: { "firecracker": 1, "ishibana": 6, "peony": 3, "willow": 4 }
+ Received: undefined
    at src/routes/apiV1.test.ts:669:48 (res.body.catalog.fireworks)

 FAIL  src/routes/apiV1.test.ts > /api/v1 > fireworks > every sellable shell has a catalogued price
TypeError: Cannot read properties of undefined (reading 'firecracker')
    at src/routes/apiV1.test.ts:691:48

 Test Files  1 failed (1)
      Tests  2 failed | 55 passed (57)
```

Matches the brief's expectation: `catalog.fireworks` is `undefined`.

## Test output after implementation (Step 4)

Ran `npx vitest run src/routes/apiV1.test.ts` again after the `apiV1.ts` change:

```
 Test Files  1 passed (1)
      Tests  57 passed (57)
   Duration  1.62s
```

Both new tests pass, all 55 pre-existing tests in the file still pass.

## Mutation-verification step (Step 5)

Temporarily deleted the `ishibana: 6,` line from `SHELL_PRICES` in `server/src/fireworks.ts`,
then re-ran `npx vitest run src/routes/apiV1.test.ts`:

```
 FAIL  src/routes/apiV1.test.ts > /api/v1 > fireworks > the economy catalog carries shell and mortar prices
AssertionError: expected { firecracker: 1, peony: 3, willow: 4 } to deeply equal { firecracker: 1, peony: 3, …(2) }
- Expected: { "firecracker": 1, "ishibana": 6, "peony": 3, "willow": 4 }
+ Received: { "firecracker": 1, "peony": 3, "willow": 4 }

 FAIL  src/routes/apiV1.test.ts > /api/v1 > fireworks > every sellable shell has a catalogued price
AssertionError: expected 'undefined' to be 'number'
Expected: "number"
Received: "undefined"

 Test Files  1 failed (1)
      Tests  2 failed | 55 passed (57)
```

Both new tests failed as expected — in particular the "every sellable shell has a catalogued
price" gate is not decoration: it caught the missing shell on its own, independent of the exact
literal-values test. The `ishibana: 6,` line was then restored immediately; `git diff --stat
server/src/fireworks.ts` after restoration shows no diff, confirming the file is back to its
original state.

## Full suite + build (Step 6)

```
cd server && npm test
 Test Files  14 passed (14)
      Tests  251 passed (251)

cd server && npm run build
> server@1.0.0 build
> tsc
(clean exit, no output)
```

## Commit

```
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): the economy catalog carries shell and mortar prices"
```

Commit: `2fd502d2b267864e1aba6a0f6f94c95dc90ef3ad` on branch `m4b-zendojo-art-pass`.
2 files changed, 41 insertions(+), 2 deletions(-).

## Anything that surprised me

Nothing surprised me — the brief's pre-resolved ambiguity (extend the one existing
`../fireworks` import in `apiV1.ts` rather than adding a second) matched exactly what was in the
file, and every step's expected output matched what actually ran. The mutation step confirmed
the second test ("every sellable shell has a catalogued price") is the one doing real gate work;
the first test (exact-values) would also have caught this particular mutation, but the second is
what protects against a *future* shell being added to `SHELL_IDS` without a matching price entry,
which the exact-values test would not catch (it hardcodes only the four current ids).
