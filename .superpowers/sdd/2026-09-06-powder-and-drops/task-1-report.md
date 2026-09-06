# Task 1 report — the powder-eligibility flag (fixture + `fireworks.ts`)

**Commit:** `59d9182d70fd347fc972cc3eb7d1b264bbff5cae` — `feat(powder): powderEligible on every shell state; the ineligible list is a fixture contract (empty today)`
**Branch:** `thread/powder` (worktree `.worktrees/powder`)

## What I implemented

1. **`shared-fixtures/firework-shells.json`** — added `powderIneligibleComment` and
   `powderIneligible: []` after `mortars`, verbatim from the brief. Purely additive; the file
   still parses (`json.load` verified) and both Lune readers only consume `shells`/`mortars`.
2. **`server/src/fireworks.ts`** —
   - `POWDER_INELIGIBLE: ReadonlySet<string>` (empty set) with the brief's comment block, placed
     directly after `REQUIREMENTS`.
   - `isPowderEligible(shellId)` — true only for an id in `SHELL_IDS` that is not in
     `POWDER_INELIGIBLE`; false for unknown ids.
   - `ShellState` gained `powderEligible: boolean`.
   - The old `evaluateShell` body was renamed to a module-private
     `evaluateLaunchable(shellId, count, ctx): Omit<ShellState, 'powderEligible'>`, and
     `evaluateShell` now wraps it:
     `return { ...evaluateLaunchable(...), powderEligible: isPowderEligible(shellId) }`.
     This is the brief's suggested shape: the flag is added on ONE line rather than on each of
     the five return paths, so a future return path cannot forget it.
3. **`server/src/fireworks.test.ts`** — the brief's `describe('the fixture is the powder-eligibility
   contract too', …)` block appended verbatim, plus `POWDER_INELIGIBLE, isPowderEligible` added to
   the import list; the eight existing `toEqual` ShellState literals updated with `powderEligible`
   (`true` for real shells, `false` for the `'nope'` BAD_SHELL case).
4. **`server/src/routes/apiV1.test.ts`** — the two `toEqual` ShellState literals in the
   `/api/v1/players/:id/fireworks` test updated with `powderEligible: true`. See Deviations.

## RED / GREEN evidence

**RED** (after Steps 1–2, before implementation) — `cd server && npx vitest run src/fireworks.test.ts`:

```
 FAIL  src/fireworks.test.ts > … > isPowderEligible: true for every shipped shell today, false for unknown ids
TypeError: isPowderEligible is not a function

 FAIL  src/fireworks.test.ts > … > shellStates carries powderEligible per shell
AssertionError: expected undefined to be true // Object.is equality

 Test Files  1 failed (1)
      Tests  3 failed | 19 passed (22)
```

All three new assertions failed for the right reason (symbol not exported / field absent).

**GREEN** — `cd server && npm test`:

```
 Test Files  29 passed (29)
      Tests  618 passed (618)
   Duration  8.52s
```

`cd server && npx tsc --noEmit` → exit 0, no output.

**Cross-runtime check (not required by the brief, run because I changed a shared fixture):**
`cd roblox && lune run tests/run` → `1892 passed, 0 failed, 1892 total`. The two added JSON keys
are invisible to `roblox/tests/fixtures/fireworkShells.luau`, which asserts only `shells` and
`mortars` and returns only those two.

Both suites and the type-check were re-run against the committed tree; working tree is clean apart
from this untracked `.superpowers/sdd/2026-09-06-powder-and-drops/` directory.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/shared-fixtures/firework-shells.json`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/fireworks.ts`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/fireworks.test.ts`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/server/src/routes/apiV1.test.ts` (deviation, below)

No Luau file was touched. `roblox/src/server/main.server.luau` was never opened.

## Deviations from the brief

**I staged a fourth file, `server/src/routes/apiV1.test.ts`,** where the brief's Step 6 `git add`
names three. The brief's own Step 5 requires it ("Any test that `toEqual`s a `ShellState` literal
now needs `powderEligible` — update those assertions"): that file's `/fireworks` route test
`toEqual`s two ShellState literals, and `toEqual` is exact, so committing `fireworks.ts` without it
would have left HEAD red for the next task in this thread. The change is two added lines, entirely
a consequence of this task, and nothing unrelated was swept in. The commit message is the brief's,
verbatim, including the trailer after a blank line.

## Self-review findings

- **Every return path carries the flag.** Verified structurally, not by inspection: all five
  returns now live in `evaluateLaunchable`, whose return type is `Omit<ShellState,
  'powderEligible'>`, and the single spread in `evaluateShell` is the only producer of a
  `ShellState`. A sixth return path cannot omit the flag.
- **`shellStates` needed no change** — it calls `evaluateShell`, so it inherits the flag.
- **Unknown ids:** `evaluateShell('nope', …)` returns `powderEligible: false` alongside
  `BAD_SHELL`, matching `isPowderEligible`'s unknown-id contract.
- **`isPowderEligible` keys off `SHELL_IDS`, not `REQUIREMENTS`.** Those two are held equal by the
  existing fixture tests, so today there is no difference; `SHELL_IDS` is what the brief specified
  and is the narrower (fixture-asserted) list.
- **Only one runtime consumer:** `server/src/routes/apiV1.ts:364` serialises `shellStates(...)`
  straight into the `/api/v1/players/:id/fireworks` response, so that endpoint now returns
  `powderEligible` per shell. Additive for the Luau clients, which read `count`/`launchable`/
  `reason` by name (`main.client.luau`, `HudController`, `ShopController`) — no exhaustive shape
  check exists on that side. This is presumably what later powder tasks want; flagging it because
  it is a live wire-format change shipped by a task whose title says "fixture + fireworks.ts".
- Runtime code still never imports the JSON — only the test does (`rootDir` is `src/`). House
  pattern preserved.
- No prettier/eslint config governs `server/`, so formatting follows the surrounding file.

## Concerns

1. **`fixtures.powderIneligible` is typed `never[]` while the list is empty.** TypeScript infers
   the element type from the empty JSON array, so in the test `for (const id of
   fixtures.powderIneligible) expect(fixtures.shells).toContain(id)` the loop body is currently
   dead code over a `never`. `tsc --noEmit` is clean and the test passes; the moment a real id is
   added the type widens to `string[]` and the assertion starts doing work. Nothing to fix — worth
   knowing that this particular guard is dormant, not proven, today.
2. **The "empty today" tests are vacuous by construction.** `POWDER_INELIGIBLE equals the fixture
   list` compares two empty arrays, and `isPowderEligible(id) === !POWDER_INELIGIBLE.has(id)` is
   trivially true for every shell while the set is empty. That is the intended design (the pair
   only bites when the first rare shell lands) but it means this task's contract is asserted, not
   yet exercised. The first ineligible shell should arrive with a test that fires one of these.
3. The API response shape change noted above — worth a line in whatever wiki page records the
   `/api/v1/.../fireworks` contract, if a later task in this sub-project does not already do that.
