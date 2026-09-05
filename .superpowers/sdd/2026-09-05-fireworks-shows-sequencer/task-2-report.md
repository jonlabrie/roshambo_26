# Task 2 report — The Luau twin, `ShowPlan.luau`

**Status:** complete. Commit `f1488c83848b1b97365e314ebef8db28e3f1dc0c` — *feat(shows): ShowPlan.luau -- the Luau validator, held to the same fixture as the server*, on `thread/shows`.

## Implemented

Three files, exactly the three the brief names:

- `roblox/tests/fixtures/shows.luau` — reads `../shared-fixtures/shows.json` via `@lune/fs` + `@lune/serde`, the same pattern as `fireworkShells.luau`. Nothing transcribed: a case added on the server side is a case here the next time tests run. Asserts `limits`, `stages` and a non-empty `cases` are present.
- `roblox/src/shared/ShowPlan.luau` — `LIMITS`, `DECK_SLOTS`, `PROVING_SLOTS`, `validate`, `tally`, `knownShellSet`. Pure; no Roblox globals; `shellMortar` and `knownShells` come in by injection (the module never reads the fixture at runtime).
- `roblox/tests/ShowPlan.spec.luau` — the 16 fixture cases in a loop, plus the constants-equal-the-fixture assertions, plus six tests for behaviour JSON cannot express.

### The five rules the fixture cannot express

1. **Precedence per cue** — `BAD_CUE → NEGATIVE_TIME → CUES_OUT_OF_ORDER → BAD_SLOT → BAD_SHELL → TIER_MISMATCH`, with `EMPTY`/`TOO_MANY_CUES` before the loop and `TOO_LONG` after. Kept as the brief wrote it, matching `server/src/shows.ts` line for line. The non-finite test proves one ordering edge directly: `-math.huge` returns `BAD_CUE`, not `NEGATIVE_TIME`.
2. **Slot lookup + shape check** — implemented as a single `shaped` predicate (`"none"` / `"any"` / `string.sub(accepts, 1, 7) == "mortar:"`), so a missing key *and* a value outside the grammar are both `BAD_SLOT`. This is the one place I departed from the brief's literal code, which only checked `accepts == nil`; the task instructions call for the shape check, and without it a typo'd tier in a stage table would silently degrade to "accepts everything" here while the TypeScript side rejected it. Covered by a new test with a stage table of `{ deck = "mortars" }`.
3. **Finite `t_ms`** — `isCue` rejects NaN and ±`math.huge`, mirroring `Number.isFinite`. Non-integer times (1.5) are accepted on both sides. New test.
4. **`TOO_LONG` is strict `>`** — a show ending exactly at `maxDurationS * 1000` is legal. New test asserts both sides of the boundary.
5. **Non-table input is `EMPTY`** — `nil` and `"nope"` (the brief's test, kept).

## TDD evidence

**RED** — spec and fixture reader written first, no implementation:

```
$ cd roblox && lune run tests/run 2>&1 | head -6
error requiring module "../src/shared/ShowPlan": could not resolve child component "ShowPlan"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
    Script '__mlua_require', Line 13
    Script '/…/roblox/tests/ShowPlan.spec', Line 9
[Stack End]
```

**GREEN** — after writing `ShowPlan.luau`:

```
$ cd roblox && lune run tests/run 2>&1 | tail -1
1871 passed, 0 failed, 1871 total
```

1847 before, 1871 after — the 24 new tests are 2 constants + 16 fixture cases + 5 extra-rule + 1 tally.

**Mutation check** — the module-missing red proves the spec runs, but not that the three hand-written rule tests bite, so I mutated the implementation three ways and confirmed each fails exactly one test:

| Mutation | Result |
| --- | --- |
| `last > …` → `last >= …` | `FAIL … TOO_LONG is strict: a show ending exactly at the limit is legal` (1870/1) |
| drop the `~= math.huge` guard | `FAIL … a non-finite t_ms is a BAD_CUE, not a time error` (1870/1) |
| shape check → `type(accepts) == "string"` | `FAIL … a slot whose stage value is not a legal shape is BAD_SLOT` (1870/1) |

Restored after each; final run 1871/0.

**Format and lint** — the brief's gate, run from `roblox/`:

```
$ lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools
1871 passed, 0 failed, 1871 total
Results:
0 errors
0 warnings
0 parse errors
```

Note for whoever runs this next: `stylua` needed **two** passes to reach a fixed point on the spec — the first pass collapsed a call, the second re-wrapped a table argument, and `--check` failed in between. Running `stylua src tests tools` twice is the fix; it touched no file outside the three committed (`git status` after: only the untracked SDD directory).

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/shows/roblox/tests/fixtures/shows.luau` (new)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/shows/roblox/src/shared/ShowPlan.luau` (new)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/shows/roblox/tests/ShowPlan.spec.luau` (new)

## Self-review

- **Rule-for-rule against `server/src/shows.ts`**: read it before writing, and diffed the two by eye afterwards. Same error names, same order, same zero-based `cue` index, same `"any"` fallthrough, same `tally`. The signature differs deliberately — TypeScript closes over `SHELL_IDS`/`REQUIREMENTS`, Luau takes `shellMortar` and `knownShells` as parameters, per the brief's interface and this codebase's injection convention.
- **The constants are transcribed, and the spec is what stops them drifting**: `LIMITS`, `DECK_SLOTS`, `PROVING_SLOTS` are literals (the Roblox runtime cannot read `shared-fixtures/`), asserted equal to the fixture by `toEqual`. Add a slot to the JSON without adding it here and CI says so.
- **The `"toString"` fixture case passes trivially in Luau** (no inherited keys), which is why the shape-check test exists: it is the case that actually exercises the branch the TypeScript comment was written about.
- **`ipairs` vs `Array.isArray`**: `ipairs` stops at the first nil, so a sparse array would validate a prefix and pass. JSON decoding never produces holes, and the wire format is JSON on both sides, so this is unreachable in practice — noted rather than defended against.

## Concerns

- **`stylua` is not idempotent on this spec file** (see above). Harmless, but a CI job that runs `stylua --check` after a single `stylua` pass would flake. Worth knowing if the show work adds more long call chains.
- **`validate` does not check that `stage` itself is a table.** Passing `nil` as the stage errors rather than returning a `Check`. The TypeScript twin has the same shape (it would throw on `Object.prototype.hasOwnProperty.call(undefined, …)`), so the two agree — but neither is defensive there, and the caller in the next task should not hand it a stage it has not resolved.
- **Nothing consumes `ShowPlan` yet.** It is a validated island until the console/sequencer task wires it up; the only proof it agrees with the server is the shared fixture, which is the point, but the two validators have not yet been run against one another on a real payload.
